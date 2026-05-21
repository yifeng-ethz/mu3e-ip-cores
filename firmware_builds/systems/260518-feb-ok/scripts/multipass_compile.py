#!/usr/bin/env python3
"""Multi-pass vcom/vlog driver for Quartus-generated sim trees.

Quartus 18.1's msim_setup.tcl `com` proc evaluates each vcom/vlog line in
a fixed source order. For VHDL designs whose dependencies are not
strictly bottom-up in that order (the qsys-generate emitter doesn't
topo-sort by `use work.<pkg>` or `entity work.<unit>`), the whole `com`
aborts on the first dependency miss.

This driver:

  1. Sources msim_setup.tcl in a setup-only Questa pass to create the
     library directories and run `dev_com` (which compiles the stock
     altera_ver / lpm_ver / altera_mf_ver / arriav_ver libs once).
  2. Parses msim_setup.tcl's `alias com {...}` block to extract every
     vcom/vlog line as (compiler, opts, file, lib).
  3. Runs each line in a subprocess; on failure, queues the file for a
     later pass. Loops until either all compiled or no progress in the
     last pass.
  4. Compiles the TB sources into `work`.
  5. Builds the elab vsim command from msim_setup.tcl's `alias elab`
     block (preserves the full per-IP -L list) and runs it.

Designed for the wrapper-only tb_int. NO leaf-IP source files are added
beyond what msim_setup.tcl already declares (plus the synth-backfilled
files patched in by qsys_generate_recursive.py --no-backfill OFF).
"""
from __future__ import annotations

import argparse
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

# ----------------------------------------------------------------------
# Parsers
# ----------------------------------------------------------------------
VCOM_LINE_RE = re.compile(
    r"""^\s*eval\s+vcom\s+
        \$USER_DEFINED_VHDL_COMPILE_OPTIONS\s+
        \$USER_DEFINED_COMPILE_OPTIONS\s+
        "(?P<file>\$QSYS_SIMDIR/[^"]+)"
        (?:\s+-work\s+(?P<lib>\S+))?""",
    re.VERBOSE,
)
VLOG_LINE_RE = re.compile(
    r"""^\s*eval\s+vlog\s+
        # qsys-generate emits SystemVerilog leaves as `vlog -sv ...`;
        # tolerate any literal flags (e.g. -sv, +define+X) BEFORE the
        # $USER_DEFINED_* placeholders. Without this, every `vlog -sv`
        # line was silently dropped and its module never compiled,
        # surfacing later as a vsim "Module is not defined" error.
        (?P<preflags>(?:[-+]\S+\s+)*)
        \$USER_DEFINED_VERILOG_COMPILE_OPTIONS\s+
        \$USER_DEFINED_COMPILE_OPTIONS\s+
        "(?P<file>\$QSYS_SIMDIR/[^"]+)"
        (?:\s+-work\s+(?P<lib>\S+))?""",
    re.VERBOSE,
)
VLIB_VMAP_RE = re.compile(
    r"^\s*(?:ensure_lib\s+(?P<libdir>\S+)|vmap\s+(?P<libname>\S+)\s+(?P<libpath>\S+))",
)
ELAB_VSIM_RE = re.compile(
    r"eval\s+vsim\s+(.*?)\s+\$TOP_LEVEL_NAME",
    re.DOTALL,
)


def parse_msim_setup(path: Path) -> Dict[str, object]:
    text = path.read_text()
    # com section
    m = re.search(r"alias com \{(.*?)^\}\s*$", text, re.MULTILINE | re.DOTALL)
    com_body = m.group(1) if m else ""
    vcom_entries: List[Tuple[str, str]] = []   # (file_expr, lib)
    vlog_entries: List[Tuple[str, str]] = []
    for line in com_body.splitlines():
        m1 = VCOM_LINE_RE.match(line)
        if m1:
            vcom_entries.append((m1.group("file"), m1.group("lib") or "work"))
            continue
        m2 = VLOG_LINE_RE.match(line)
        if m2:
            vlog_entries.append((m2.group("file"), m2.group("lib") or "work"))
            continue
    # libraries
    libs: List[Tuple[str, str]] = []  # (libname, libpath)
    prev_libdir: Optional[str] = None
    for line in text.splitlines():
        m = VLIB_VMAP_RE.match(line)
        if not m:
            continue
        if m.group("libdir"):
            prev_libdir = m.group("libdir")
        elif m.group("libname"):
            libs.append((m.group("libname"), m.group("libpath")))
    # elab opts
    m = ELAB_VSIM_RE.search(text)
    elab_opts = m.group(1) if m else ""
    return {
        "vcom": vcom_entries,
        "vlog": vlog_entries,
        "libs": libs,
        "elab_opts": elab_opts,
    }


def expand_qsys_simdir(s: str, qsys_simdir: Path) -> str:
    return s.replace("$QSYS_SIMDIR", str(qsys_simdir))


# ----------------------------------------------------------------------
# Compile driver
# ----------------------------------------------------------------------
def run_setup_pass(questa: Path, msim_setup: Path, run_dir: Path,
                   modelsim_ini: Path, vhdl_opts: str) -> int:
    """Source msim_setup.tcl + dev_com via a one-shot Questa invocation,
    so libraries are created and stock altera_ver / lpm_ver / etc. are
    compiled. We then drive `com` ourselves in multi-pass mode."""
    do = run_dir / "setup.do"
    do.write_text(
        f"set QSYS_SIMDIR \"{msim_setup.parents[1].resolve()}\"\n"
        f"set USER_DEFINED_VHDL_COMPILE_OPTIONS \"{vhdl_opts}\"\n"
        f"source \"{msim_setup}\"\n"
        f"dev_com\n"
        f"quit -f\n"
    )
    log = run_dir / "setup.log"
    with log.open("wb") as lf:
        proc = subprocess.run(
            [str(questa), "-c", "-modelsimini", str(modelsim_ini), "-do", str(do)],
            stdout=lf, stderr=subprocess.STDOUT, cwd=run_dir,
        )
    return proc.returncode


def vcom_one(vcom_bin: Path, modelsim_ini: Path, file_path: Path,
             lib: str, vhdl_opts: List[str], log_handle,
             run_dir: Path) -> int:
    cmd = [str(vcom_bin), "-modelsimini", str(modelsim_ini),
           *vhdl_opts, "-work", lib, str(file_path)]
    log_handle.write(("\n+ " + " ".join(cmd) + "\n").encode())
    log_handle.flush()
    proc = subprocess.run(cmd, stdout=log_handle, stderr=subprocess.STDOUT,
                          cwd=str(run_dir))
    return proc.returncode


def vlog_one(vlog_bin: Path, modelsim_ini: Path, file_path: Path,
             lib: str, vlog_opts: List[str], log_handle,
             run_dir: Path) -> int:
    # .v files are plain Verilog; some Quartus IPs (e.g. line_code_decoder_8b10b)
    # use SV keywords (do, return, ...) as identifiers, so -sv would break them.
    # Force -sv only for .sv files.
    opts = list(vlog_opts)
    if file_path.suffix == ".v":
        opts = [o for o in opts if o != "-sv"]
    cmd = [str(vlog_bin), "-modelsimini", str(modelsim_ini),
           *opts, "-work", lib, str(file_path)]
    log_handle.write(("\n+ " + " ".join(cmd) + "\n").encode())
    log_handle.flush()
    proc = subprocess.run(cmd, stdout=log_handle, stderr=subprocess.STDOUT,
                          cwd=str(run_dir))
    return proc.returncode


def multipass_compile(parsed: Dict[str, object], qsys_simdir: Path,
                       run_dir: Path, vcom_bin: Path, vlog_bin: Path,
                       modelsim_ini: Path, vhdl_opts: List[str],
                       vlog_opts: List[str],
                       skip_basenames: Optional[Set[str]] = None) -> Tuple[List, List]:
    """Iterate vcom/vlog over the file list with retry on failure. Verilog
    files are compiled first (their order is usually fine and they have
    no `use` deps); VHDL files are retried until convergence.
    Returns (failures, attempts_per_pass).

    skip_basenames: source basenames to drop from the compile list. Used to
    exclude STALE generated leftovers that qsys-generate did not delete when
    the .qsys removed the corresponding instance (e.g. a 0-output run_control_mux
    after the run-control network was made readyless). Such a file is NOT in the
    DUT (it is not instantiated in the top .v) but is still listed in
    msim_setup.tcl; compiling it can fail and would otherwise abort elaboration.
    Skipping it does not alter the DUT."""
    skip_basenames = skip_basenames or set()
    vlog_pending: List[Tuple[Path, str]] = [
        (Path(expand_qsys_simdir(f, qsys_simdir)), lib)
        for (f, lib) in parsed["vlog"]
        if Path(expand_qsys_simdir(f, qsys_simdir)).name not in skip_basenames
    ]
    vcom_pending: List[Tuple[Path, str]] = [
        (Path(expand_qsys_simdir(f, qsys_simdir)), lib)
        for (f, lib) in parsed["vcom"]
        if Path(expand_qsys_simdir(f, qsys_simdir)).name not in skip_basenames
    ]
    log_path = run_dir / "multipass_compile.log"
    attempts: List[Tuple[int, int]] = []
    with log_path.open("ab") as lf:
        # --- Pass 1: Verilog/SV (no use-clauses) ---
        lf.write(b"\n# === Verilog/SV single pass ===\n")
        v_fail: List[Tuple[Path, str]] = []
        for fp, lib in vlog_pending:
            if not fp.exists():
                lf.write(f"# SKIP-missing {fp}\n".encode())
                continue
            rc = vlog_one(vlog_bin, modelsim_ini, fp, lib, vlog_opts, lf, run_dir)
            if rc != 0:
                v_fail.append((fp, lib))
        if v_fail:
            lf.write(f"# Verilog pass: {len(v_fail)} failures, retrying once\n".encode())
            v_fail2: List[Tuple[Path, str]] = []
            for fp, lib in v_fail:
                rc = vlog_one(vlog_bin, modelsim_ini, fp, lib, vlog_opts, lf, run_dir)
                if rc != 0:
                    v_fail2.append((fp, lib))
            v_fail = v_fail2
        # --- Pass 2..N: VHDL multi-pass ---
        pending = list(vcom_pending)
        pass_no = 0
        while pending:
            pass_no += 1
            lf.write(f"\n# === VHDL pass {pass_no}: {len(pending)} pending ===\n".encode())
            next_pending: List[Tuple[Path, str]] = []
            for fp, lib in pending:
                if not fp.exists():
                    lf.write(f"# SKIP-missing {fp}\n".encode())
                    continue
                rc = vcom_one(vcom_bin, modelsim_ini, fp, lib, vhdl_opts, lf, run_dir)
                if rc != 0:
                    next_pending.append((fp, lib))
            attempts.append((pass_no, len(pending) - len(next_pending)))
            if len(next_pending) == len(pending):
                lf.write(f"# VHDL convergence: no progress, "
                         f"{len(next_pending)} still failing\n".encode())
                break
            pending = next_pending
        return (pending + v_fail, attempts)


def run_elab(parsed: Dict[str, object], qsys_simdir: Path, run_dir: Path,
             vsim_bin: Path, modelsim_ini: Path, tb_top: str,
             user_elab_opts: str) -> int:
    """Run elab using msim_setup.tcl's -L list, plus user-supplied
    -voptargs / suppress switches."""
    elab_opts = parsed["elab_opts"]
    # The captured opts already include $ELAB_OPTIONS $USER_DEFINED_ELAB_OPTIONS
    # placeholders. Substitute USER_DEFINED_ELAB_OPTIONS to our string and
    # drop ELAB_OPTIONS (msim_setup sets it empty).
    elab_opts = elab_opts.replace("$ELAB_OPTIONS", "")
    elab_opts = elab_opts.replace("$USER_DEFINED_ELAB_OPTIONS",
                                   user_elab_opts)
    # Optional vsim plusargs forwarded from the environment so a focused
    # diagnostic pass can shrink the slow S3/S5 windows (e.g.
    # EXTRA_PLUSARGS="+S3_CYCLES=2000 +S5_CYCLES=2000") without mutating the
    # committed regression localparam defaults.
    extra_plusargs = os.environ.get("EXTRA_PLUSARGS", "").strip()
    cmd = (f"{vsim_bin} -c -modelsimini {modelsim_ini} -t ps "
           f"{elab_opts} {tb_top} {extra_plusargs} -do "
           "\"quietly set NumericStdNoWarnings 1; "
           "quietly set StdArithNoWarnings 1; "
           "run -all; quit -f\"")
    log_path = run_dir / "elab.log"
    print(f"[multipass] elab: {tb_top}")
    with log_path.open("ab") as lf:
        proc = subprocess.run(cmd, shell=True, stdout=lf,
                              stderr=subprocess.STDOUT, cwd=run_dir)
    return proc.returncode


# ----------------------------------------------------------------------
# CLI
# ----------------------------------------------------------------------
def parse_args(argv: List[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--msim-setup", required=True,
                   help="path to msim_setup.tcl from qsys-generate")
    p.add_argument("--run-dir", required=True,
                   help="run/work directory")
    p.add_argument("--tb-sv", action="append", required=True,
                   help="SV/V testbench file(s) to compile into work (-tb-sv X --tb-sv Y)")
    p.add_argument("--tb-top", required=True,
                   help="TB top module name")
    p.add_argument("--questa-home",
                   default=os.environ.get("QUESTA_HOME",
                                          "/data1/questaone_sim-2026.1_1/questasim"))
    p.add_argument("--vhdl-opt", action="append", default=["-2008"],
                   help="extra vcom option (repeatable)")
    p.add_argument("--vlog-opt", action="append", default=["-sv"],
                   help="extra vlog option (repeatable)")
    p.add_argument("--elab-opts",
                   default="-voptargs=+acc -suppress 19 -suppress 3009 -suppress 3473",
                   help="vsim user-elab opts")
    p.add_argument("--no-elab", action="store_true")
    p.add_argument("--skip-file", action="append", default=[],
                   help="source basename to drop from the compile list "
                        "(stale generated leftover not in the DUT; repeatable)")
    return p.parse_args(argv)


def main(argv: List[str]) -> int:
    args = parse_args(argv)
    msim_setup = Path(args.msim_setup).resolve()
    qsys_simdir = msim_setup.parents[1].resolve()  # .../simulation
    run_dir = Path(args.run_dir).resolve()
    run_dir.mkdir(parents=True, exist_ok=True)
    questa_home = Path(args.questa_home)
    vcom_bin = questa_home / "linux_x86_64" / "vcom"
    vlog_bin = questa_home / "linux_x86_64" / "vlog"
    vsim_bin = questa_home / "linux_x86_64" / "vsim"
    modelsim_ini = run_dir / "modelsim.ini"
    if not modelsim_ini.exists():
        src_ini = questa_home / "modelsim.ini"
        modelsim_ini.write_text(src_ini.read_text())
        modelsim_ini.chmod(0o644)

    # License env
    for k in ("LM_LICENSE_FILE", "MGLS_LICENSE_FILE", "SALT_LICENSE_SERVER"):
        os.environ.setdefault(k, "8161@lic-mentor.ethz.ch")

    print(f"[multipass] parsing {msim_setup}")
    parsed = parse_msim_setup(msim_setup)
    print(f"[multipass]   {len(parsed['vcom'])} vcom + "
          f"{len(parsed['vlog'])} vlog + {len(parsed['libs'])} libs")

    print(f"[multipass] setup pass: dev_com + vlib/vmap via msim_setup.tcl")
    rc = run_setup_pass(vsim_bin, msim_setup, run_dir, modelsim_ini,
                        " ".join(args.vhdl_opt))
    if rc != 0:
        print(f"FATAL: setup pass exit {rc} (see {run_dir/'setup.log'})",
              file=sys.stderr)
        return rc

    print(f"[multipass] multi-pass compile begin")
    t0 = time.time()
    skip_basenames = set(args.skip_file)
    if skip_basenames:
        print(f"[multipass] skipping stale leftover file(s): "
              f"{', '.join(sorted(skip_basenames))}")
    failures, attempts = multipass_compile(
        parsed, qsys_simdir, run_dir, vcom_bin, vlog_bin, modelsim_ini,
        args.vhdl_opt, args.vlog_opt, skip_basenames,
    )
    dt = time.time() - t0
    print(f"[multipass] compile wall: {dt:.1f}s, passes: {len(attempts)}")
    for pn, made in attempts:
        print(f"   pass {pn}: {made} files compiled")
    if failures:
        print(f"[multipass] {len(failures)} files failed to compile:",
              file=sys.stderr)
        for fp, lib in failures:
            print(f"   {fp.name}  (lib={lib})", file=sys.stderr)
        print(f"   see {run_dir/'multipass_compile.log'}", file=sys.stderr)
        return 1

    # Compile TB sources into work
    print(f"[multipass] compiling TB into work")
    with (run_dir / "multipass_compile.log").open("ab") as lf:
        lf.write(b"\n# === TB compile ===\n")
        for tb in args.tb_sv:
            tbp = Path(tb).resolve()
            rc = vlog_one(vlog_bin, modelsim_ini, tbp, "work", args.vlog_opt, lf, run_dir)
            if rc != 0:
                print(f"FATAL: vlog {tbp} failed", file=sys.stderr)
                return rc

    if args.no_elab:
        print("[multipass] --no-elab: stopping before elab")
        return 0

    rc = run_elab(parsed, qsys_simdir, run_dir, vsim_bin, modelsim_ini,
                   args.tb_top, args.elab_opts)
    if rc != 0:
        print(f"[multipass] elab/sim exit {rc}", file=sys.stderr)
        return rc
    print(f"[multipass] elab/sim OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

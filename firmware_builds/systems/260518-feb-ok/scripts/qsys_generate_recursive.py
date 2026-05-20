#!/usr/bin/env python3
"""Recursive qsys-generate driver.

Quartus 18.1 CLI `qsys-generate --simulation` is non-recursive: it emits
the top-level wrapper + direct-child leaf IPs, but leaves nested
subsystems and stock-IP compositions un-flattened. The Qsys GUI walks the
full hierarchy. This tool reproduces the GUI behaviour from the CLI:

  1. Build a kind -> source-qsys-file map from the project's qsys
     catalogue (quartus_systems/*.qsys, generated/qsys/*.qsys,
     <build>/qsys_tcl-driven outputs).
  2. From a seed top (e.g. scifi_datapath_system_v4) walk every
     <module kind="X"> declaration; any X that resolves to a project
     .qsys file is enqueued.
  3. Stock-IP compositions (kind starts with `altera_` and a
     stand-alone .qsys file does not exist) are emitted on the fly as
     tiny wrapper .qsys files containing a single instance; this is
     the only way the CLI flattens them into their constituent leaves
     (timing_adapter, channel_adapter, st_jtag_interface,
     packets_to_master, bytes_to_packets, packets_to_bytes, sc_fifo).
  4. Run qsys-generate --simulation in parallel via ThreadPoolExecutor.

Idempotent: skips outputs that are newer than their input .qsys (use
`--clean` to force rebuild).

This tool deliberately limits itself to the build context it lives in
(its working dir == this build's `scripts/`). All paths are derived
relative to that location; no implicit cwd assumptions.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import os
import re
import shutil
import subprocess
import sys
import textwrap
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

# ----------------------------------------------------------------------
# Project layout constants (relative to this script)
# ----------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent          # .../260518-feb-ok/scripts
SYSTEM_DIR = SCRIPT_DIR.parent                        # .../260518-feb-ok
GEN_QSYS_DIR = SYSTEM_DIR / "generated" / "qsys"
GEN_SIM_DIR = SYSTEM_DIR / "generated" / "simulation"
GEN_SYN_DIR = SYSTEM_DIR / "generated" / "synthesis"
QSYS_TCL_DIR = SYSTEM_DIR / "qsys_tcl"
QSYS_SEARCH_PATH_SH = QSYS_TCL_DIR / "script" / "qsys_search_path.sh"

# default repo root: 4 levels up from this file
REPO_ROOT = SYSTEM_DIR.parents[2]                     # .../mu3e_ip_cores_main_20260518

QUARTUS_ROOTDIR = Path(os.environ.get(
    "QUARTUS_ROOTDIR", "/data1/intelFPGA/18.1/quartus"))
QSYS_GENERATE = QUARTUS_ROOTDIR / "sopc_builder" / "bin" / "qsys-generate"

FPGA_FAMILY = "Arria V"
FPGA_PART = "5AGXBA7D4F31C5"

# ----------------------------------------------------------------------
# Some leaf IPs in this design declare only QUARTUS_SYNTH filesets and no
# SIM_VHDL/SIM_VERILOG fileset, so qsys-generate --simulation errors with
# "<ip> does not support generation for Verilog Simulation". These are
# proper user IPs whose .vhd RTL is perfectly valid for sim; the fix is
# either to extend their hw.tcl (separate IP commit) or to backfill from
# the matching synth tree, which Quartus DOES populate fully.
# We list these here so we can:
#   (a) tolerate the corresponding qsys-generate failure without aborting
#       the entire recursive run, and
#   (b) include their submodules/ files in the synth-backfill pass.
IPS_NEEDING_SYNTH_BACKFILL = {
    "feb_frame_assembly",
    "mutrig_injector_multiheader",
}

# Tolerated qsys-generate error pattern: an IP missing SIM filesets only
# stops emission of that subtree, the parent msim_setup.tcl is still
# written (we observed Quartus produce a partial submodules/ and a valid
# mentor/msim_setup.tcl in this case). The synth-tree backfill fills the
# gap.
SIM_FILESET_MISSING_RE = re.compile(
    r"Error:\s+\S+:\s+\S+\s+does not support generation for Verilog Simulation",
    re.MULTILINE,
)

# ----------------------------------------------------------------------
# Search paths
# ----------------------------------------------------------------------
def collect_search_paths(repo_root: Path) -> str:
    """Invoke qsys_search_path.sh and capture SEARCH_PATHS."""
    cmd = textwrap.dedent(f"""
        set -e
        export MU3E_IP_CORES_ROOT="{repo_root}"
        export SYSTEM_DIR="{SYSTEM_DIR}"
        source "{QSYS_SEARCH_PATH_SH}"
        qsys_collect_active_search_paths "$MU3E_IP_CORES_ROOT"
        printf '%s' "$SEARCH_PATHS"
    """)
    res = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, check=True)
    return res.stdout.strip()

# ----------------------------------------------------------------------
# kind -> qsys path map
# ----------------------------------------------------------------------
def build_kind_to_qsys(repo_root: Path) -> Dict[str, Path]:
    """Scan project tree for .qsys files. Filename stem is the kind."""
    candidates: List[Path] = []
    candidates += sorted((repo_root / "quartus_systems").glob("*.qsys"))
    if GEN_QSYS_DIR.exists():
        candidates += sorted(GEN_QSYS_DIR.glob("*.qsys"))
    # Ignore deprecated/snapshot copies.
    out: Dict[str, Path] = {}
    for p in candidates:
        if "deprecated" in p.parts or "snapshot" in p.name.lower():
            continue
        if "trash_bin" in p.parts:
            continue
        # GEN_QSYS_DIR copies win over the upstream catalog copy
        # (they are the build-time materialised version).
        if p.stem in out and "generated" in p.parts:
            out[p.stem] = p
        else:
            out.setdefault(p.stem, p)
    return out

def kinds_in(qsys_path: Path) -> List[Tuple[str, str]]:
    """Return list of (instance_name, kind) for each <module> in qsys_path."""
    try:
        root = ET.parse(qsys_path).getroot()
    except ET.ParseError as e:
        print(f"WARN: cannot parse {qsys_path}: {e}", file=sys.stderr)
        return []
    out: List[Tuple[str, str]] = []
    for mod in root.iter("module"):
        name = mod.get("name", "")
        kind = mod.get("kind", "")
        if name and kind:
            out.append((name, kind))
    return out

def get_module_params(qsys_path: Path, instance_name: str) -> Dict[str, str]:
    """Return parameter name -> value for a given <module> instance."""
    root = ET.parse(qsys_path).getroot()
    for mod in root.iter("module"):
        if mod.get("name") == instance_name:
            params = {}
            for p in mod.iter("parameter"):
                pname = p.get("name", "")
                pval = p.get("value", "")
                if pname:
                    params[pname] = pval
            return params
    return {}

# ----------------------------------------------------------------------
# Synth-tree backfill
# ----------------------------------------------------------------------
def synth_submodules_dir(kind: str) -> Path:
    return GEN_SYN_DIR / kind / "synthesis" / "submodules"

def sim_submodules_dir(kind: str, out_root: Path) -> Path:
    return out_root / kind / "simulation" / "submodules"

def backfill_from_synth(kind: str, out_root: Path) -> Tuple[int, int, int]:
    """For every HDL file (.v/.sv/.vhd/.vhdl) anywhere under the synth
    tree of `kind`:
      - if not present in the sim submodules tree, hard-link it across;
      - if present AND the filename starts with `kind` followed by `_`
        (i.e. it is a Quartus-generated parent-prefixed wrapper), and
        the synth and sim copies differ, OVERWRITE the sim copy with
        the synth one. Justification: qsys-generate --simulation emits
        per-instance wrappers that reference further-prefixed wrappers
        that don't exist (compositions like mu3e_lvds_controller),
        while qsys-generate --synthesis flattens compositions inline
        and produces a self-contained wrapper. The synth wrapper is
        functionally identical for simulation - it's RTL all the way
        down, no synthesis-only directives.
    Returns (added, overwritten, total_synth_files)."""
    synth_top = GEN_SYN_DIR / kind / "synthesis"
    if not synth_top.is_dir():
        return (0, 0, 0)
    dst = sim_submodules_dir(kind, out_root)
    dst.mkdir(parents=True, exist_ok=True)
    hdl_suffixes = {".v", ".sv", ".vhd", ".vhdl"}
    wrapper_prefix = f"{kind}_"
    # The sim tree's own top wrapper lives at simulation/<kind>.v (Verilog).
    # The synth tree emits the SAME module as <kind>.vhd. Backfilling the
    # synth VHDL copy would create a duplicate definition of the top module
    # in a different language, and Questa may bind the stale synth copy
    # instead of the fresh sim one. So we exclude any synth file whose stem
    # collides with a sim file under a different HDL extension.
    sim_top_dir = out_root / kind / "simulation"
    sim_stems_by_other_ext: Set[str] = set()
    for scan_dir in (sim_top_dir, dst):
        if scan_dir.is_dir():
            for sfp in scan_dir.iterdir():
                if sfp.is_file() and sfp.suffix.lower() in hdl_suffixes:
                    sim_stems_by_other_ext.add((sfp.stem, sfp.suffix.lower()))
    added = 0
    overwritten = 0
    total = 0
    for sf in synth_top.rglob("*"):
        if not sf.is_file():
            continue
        if sf.suffix.lower() not in hdl_suffixes:
            continue
        # Skip language-variant collisions: sim already has this module
        # under a different HDL extension (e.g. sim <kind>.v vs synth
        # <kind>.vhd). Backfilling would duplicate the module definition.
        collide = any(stem == sf.stem and ext != sf.suffix.lower()
                      for (stem, ext) in sim_stems_by_other_ext)
        if collide:
            continue
        total += 1
        df = dst / sf.name
        existed = df.exists()
        if existed:
            # Already present (often a stale hardlink from a prior run that
            # survived --clear-output-directory, or the sim's own copy).
            # If it already points at the SAME synth inode, leave it.
            try:
                if df.stat().st_ino == sf.stat().st_ino:
                    continue
            except OSError:
                pass
            # Otherwise refresh it from synth unconditionally: the synth tree
            # is the authoritative recursive flatten (it inlines compositions
            # like mu3e_lvds_controller that the sim emitter leaves as broken
            # parent-prefixed sub-wrappers). Idempotent re-link.
            if df.stat().st_mode & 0o200 == 0:
                df.chmod(df.stat().st_mode | 0o200)
            df.unlink()
        try:
            os.link(sf, df)
        except OSError:
            shutil.copy2(sf, df)
        if existed:
            overwritten += 1
        else:
            added += 1
    return (added, overwritten, total)

def patch_msim_setup_with_backfilled(kind: str, added_files: List[Path],
                                      out_root: Path) -> int:
    """Add a vlog/vcom line for each backfilled file to the per-kind
    msim_setup.tcl, into the default `work` library (qsys-generate did
    not declare a per-IP library for these). Inserted just before the
    `# ---` separator that marks the end of the file list, so dev_com /
    com pick them up. Returns count of inserted lines."""
    if not added_files:
        return 0
    setup = out_root / kind / "simulation" / "mentor" / "msim_setup.tcl"
    if not setup.exists():
        return 0
    text = setup.read_text()
    inserts: List[str] = []
    for f in added_files:
        rel = f"submodules/{f.name}"
        if f.suffix in (".sv", ".v"):
            inserts.append(
                f'  eval  vlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS '
                f'$USER_DEFINED_COMPILE_OPTIONS '
                f'"$QSYS_SIMDIR/{rel}"  -work work'
            )
        elif f.suffix in (".vhd", ".vhdl"):
            inserts.append(
                f'  eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS '
                f'$USER_DEFINED_COMPILE_OPTIONS '
                f'"$QSYS_SIMDIR/{rel}"  -work work'
            )
    if not inserts:
        return 0
    block = "\n".join(inserts) + "\n"
    # Insert just before the `}` that closes the `alias com {`.
    # Robust pattern: find "alias com {" then the matching closing brace
    # line (a `}` alone on a line) and inject before it.
    m = re.search(r"^alias com \{", text, re.MULTILINE)
    if not m:
        return 0
    close_match = re.search(r"^\}\s*$", text[m.end():], re.MULTILINE)
    if not close_match:
        return 0
    inject_at = m.end() + close_match.start()
    new_text = text[:inject_at] + block + text[inject_at:]
    if setup.stat().st_mode & 0o200 == 0:
        setup.chmod(setup.stat().st_mode | 0o200)
    setup.write_text(new_text)
    return len(inserts)

# ----------------------------------------------------------------------
# Collision + composition reconciliation (post-backfill)
# ----------------------------------------------------------------------
#
# Two structural defects in the Quartus 18.1 CLI sim emitter survive
# qsys-generate + synth backfill and must be reconciled before the sim
# tree is compilable. Both are pure harness-mechanics fixes: no RTL is
# authored, and the substituted sources are Quartus-emitted RTL that the
# board synth flow already builds.
#
#  (A) Nested-subsystem wrapper collision.
#      For a nested Qsys subsystem instance (hit_stack_subsystem_N,
#      mutrig_datapath_subsystem_N), the sim emitter writes a parent-
#      prefixed Verilog wrapper <kind>_<inst>.v that instantiates further
#      parent-prefixed CHILD wrappers (..._ring_buffer_cam_0,
#      ..._feb_frame_assembly_0, ..._mutrig_frame_deassembly_0) which the
#      CLI never emits. The --synthesis flow instead flattens the SAME
#      wrapper as <kind>_<inst>.vhd that binds the BARE leaf modules
#      (ring_buffer_cam, feb_frame_assembly, frame_rcv_ip) which ARE
#      present and compiled. The backfill drops the synth .vhd into
#      submodules/ but its language-variant-collision guard then refuses
#      to add it to the compile list because the broken .v sibling is
#      already there. Net: the broken .v compiles into its per-IP
#      library (which the elab -L list references) and shadows nothing
#      compilable; vsim binds it and reports the child wrappers missing.
#      Fix: for every <stem>.v / <stem>.vhd pair under the top sim
#      submodules dir, rewrite the .v vlog line in msim_setup.tcl to a
#      vcom line on the .vhd, KEEPING the same -work library so the elab
#      -L binding is preserved. The self-contained synth .vhd then
#      defines the wrapper.
#
#  (B) Composed-IP (mu3e_lvds_controller) wrapper has no compilable
#      flatten in the scifi tree.
#      The scifi --synthesis AND --simulation flows both emit
#      scifi_datapath_system_v4_mu3e_lvds_controller_0.v as the indirect
#      form that instantiates ..._phy / ..._core sub-wrappers that no CLI
#      path ever generates. The feb_system_v4 board --synthesis flow
#      emits the SAME IP, same instance params, IDENTICAL port list, as a
#      SELF-CONTAINED wrapper that directly instantiates the real
#      altera_lvds_rx_28nm + mu3e_lvds_controller_phy_adapter modules
#      (both already present in the scifi sim submodules). Fix: copy the
#      board wrapper into the scifi sim submodules, rename its module to
#      the scifi name, and compile THAT in place of the broken .v (same
#      -work library).

# Composed IPs whose scifi sim/synth wrapper is the broken _phy/_core
# indirect form; the working self-contained wrapper is emitted by the
# board (feb_system_v4) synth flow. Map: scifi-wrapper-stem -> board
# synth file that defines the identical-port self-contained wrapper.
COMPOSED_IP_BOARD_WRAPPER = {
    "scifi_datapath_system_v4_mu3e_lvds_controller_0": (
        "feb_system_v4",
        "feb_system_v4_data_path_subsystem_mu3e_lvds_controller_0",
    ),
}

# (C) Bare-entity-needs-prefixed-alias.
# Some leaf IPs declare only a QUARTUS_SYNTH fileset and no SIM fileset
# (feb_frame_assembly, mutrig_injector_multiheader, mutrig_reset_controller
# -> see IPS_NEEDING_SYNTH_BACKFILL). For those, qsys-generate never emits
# the per-instance parent-prefixed wrapper (e.g.
# scifi_datapath_system_v4_mutrig_injector_0) that the top wrapper
# instantiates -- only the bare entity (mutrig_injector_multiheader) is
# backfilled from synth. The board (feb_system_v4) parent instantiates the
# BARE entity directly, confirming the prefixed name is a pure 1:1 rename
# with identical port names and the entity's default generics (the scifi
# parent passes no generic overrides). Reconcile by materialising a copy of
# the bare VHDL with the entity/architecture renamed to the prefixed name
# and compiling it into `work`. This is a mechanical module-name alias, not
# RTL authoring -- the body is the verbatim Quartus-emitted entity.
# Map: prefixed-module-name -> bare-source-stem (file under submodules/).
BARE_ENTITY_PREFIXED_ALIAS = {
    "scifi_datapath_system_v4_mutrig_injector_0":
        "mutrig_injector_multiheader",
    "scifi_datapath_system_v4_mutrig_reset_controller_0":
        "mutrig_reset_controller",
}


def _msim_setup_for(kind: str, out_root: Path) -> Path:
    return out_root / kind / "simulation" / "mentor" / "msim_setup.tcl"


def _extract_instance_params(parent_text: str, module_name: str) -> Dict[str, str]:
    """Parse the parameter overrides the parent passes to its first
    instantiation of `module_name`: `module_name #( .P (v), ... ) inst (`.
    Returns {PARAM: decimal_value} for plain decimal values only (the
    version-stamp fields we re-stamp are all decimal)."""
    m = re.search(re.escape(module_name) + r"\s*#\((?P<body>.*?)\)\s*\w+\s*\(",
                  parent_text, re.DOTALL)
    if not m:
        return {}
    params: Dict[str, str] = {}
    for pm in re.finditer(r"\.(\w+)\s*\(\s*(\d+)\s*\)", m.group("body")):
        params[pm.group(1)] = pm.group(2)
    return params


def reconcile_top_sim_tree(top_kind: str, out_root: Path) -> Dict[str, int]:
    """Apply defects (A) and (B) to the TOP system's sim tree. Returns a
    small stats dict. Idempotent: re-running detects already-patched
    lines and skips them."""
    sub_dir = sim_submodules_dir(top_kind, out_root)
    setup = _msim_setup_for(top_kind, out_root)
    stats = {"collision_swapped": 0, "lvds_swapped": 0, "bare_aliased": 0}
    if not setup.exists() or not sub_dir.is_dir():
        return stats
    if setup.stat().st_mode & 0o200 == 0:
        setup.chmod(setup.stat().st_mode | 0o200)
    text = setup.read_text()

    # --- (B) LVDS / composed-IP wrapper swap (do first so the .v that
    #     would otherwise be matched as a collision in (A) is already
    #     handled) -------------------------------------------------------
    for scifi_stem, (board_kind, board_stem) in COMPOSED_IP_BOARD_WRAPPER.items():
        broken_v = sub_dir / f"{scifi_stem}.v"
        board_src = (GEN_SYN_DIR / board_kind / "synthesis" / "submodules"
                     / f"{board_stem}.v")
        if not broken_v.exists() or not board_src.exists():
            continue
        # Materialise the renamed self-contained wrapper next to the
        # broken one, under the scifi name + a marker suffix so it does
        # not itself collide.
        fixed = sub_dir / f"{scifi_stem}__boardflat.v"
        src_text = board_src.read_text()
        src_text = src_text.replace(board_stem, scifi_stem)
        # The board wrapper carries a Quartus version-stamp guard
        # (`if (BUILD != <n>) ... instantiated_with_wrong_parameters_...`)
        # that fires when the parent's parameter OVERRIDES differ from the
        # constants the board wrapper was generated against. The scifi
        # parent instantiates the SAME IP with the SAME functional params
        # but a different generation stamp (BUILD/VERSION_PATCH/
        # VERSION_DATE). Re-stamp the guard constants to the parent's
        # actual override values so the guard stays live for a genuine
        # mismatch but does not trip on the (functionally identical)
        # cross-tree borrow. Stamp fields are pure metadata; they gate no
        # logic.
        top_v = out_root / top_kind / "simulation" / f"{top_kind}.v"
        if top_v.exists():
            parent_params = _extract_instance_params(top_v.read_text(),
                                                     scifi_stem)
            for pname in ("BUILD", "VERSION_PATCH", "VERSION_DATE",
                          "VERSION_MINOR", "VERSION_MAJOR", "INSTANCE_ID"):
                if pname not in parent_params:
                    continue
                pval = parent_params[pname]
                src_text = re.sub(
                    r"(if\s*\(\s*" + re.escape(pname) + r"\s*!=\s*)\d+(\s*\))",
                    r"\g<1>" + pval + r"\g<2>",
                    src_text,
                )
        if fixed.exists() and fixed.stat().st_mode & 0o200 == 0:
            fixed.chmod(fixed.stat().st_mode | 0o200)
        fixed.write_text(src_text)
        # Rewrite the broken .v vlog line to point at the fixed file,
        # keeping the same -work library.
        pat = re.compile(
            r'^([^\n]*vlog[^\n]*"\$QSYS_SIMDIR/submodules/)'
            + re.escape(f"{scifi_stem}.v")
            + r'("[^\n]*)$',
            re.MULTILINE,
        )
        new_text, n = pat.subn(
            r"\1" + f"{scifi_stem}__boardflat.v" + r"\2", text)
        if n:
            text = new_text
            stats["lvds_swapped"] += 1

    # --- (C) Bare-entity prefixed alias: materialise renamed copy + add
    #     a vcom line into the `com` block -------------------------------
    alias_inserts: List[str] = []
    for prefixed, bare_stem in BARE_ENTITY_PREFIXED_ALIAS.items():
        bare_file = sub_dir / f"{bare_stem}.vhd"
        if not bare_file.is_file():
            continue
        alias_file = sub_dir / f"{prefixed}__alias.vhd"
        body = bare_file.read_text()
        # Rename only the declaration sites (whole-word). The bare entity
        # name appears solely in `entity X`, `architecture .. of X`,
        # `end entity X;` / `end X;`, and a header comment -- never as a
        # signal -- so a whole-word global replace is safe here.
        body = re.sub(r"\b" + re.escape(bare_stem) + r"\b", prefixed, body)
        if alias_file.exists() and alias_file.stat().st_mode & 0o200 == 0:
            alias_file.chmod(alias_file.stat().st_mode | 0o200)
        alias_file.write_text(body)
        marker = f"{prefixed}__alias.vhd"
        if marker not in text:
            alias_inserts.append(
                f'  eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS '
                f'$USER_DEFINED_COMPILE_OPTIONS '
                f'"$QSYS_SIMDIR/submodules/{marker}"  -work work'
            )
        stats["bare_aliased"] += 1
    if alias_inserts:
        m = re.search(r"^alias com \{", text, re.MULTILINE)
        if m:
            close = re.search(r"^\}\s*$", text[m.end():], re.MULTILINE)
            if close:
                at = m.end() + close.start()
                text = text[:at] + "\n".join(alias_inserts) + "\n" + text[at:]

    # --- (A) Nested-subsystem wrapper collision: .v -> .vhd swap --------
    hdl = {".v", ".sv", ".vhd", ".vhdl"}
    stems_v = {p.stem for p in sub_dir.iterdir()
               if p.is_file() and p.suffix == ".v"}
    stems_vhd = {p.stem for p in sub_dir.iterdir()
                 if p.is_file() and p.suffix == ".vhd"}
    collisions = sorted(stems_v & stems_vhd)
    for stem in collisions:
        # vlog line on <stem>.v -> vcom line on <stem>.vhd, same -work lib.
        pat = re.compile(
            r'^\s*eval\s+vlog\s+\$USER_DEFINED_VERILOG_COMPILE_OPTIONS\s+'
            r'\$USER_DEFINED_COMPILE_OPTIONS\s+'
            r'"\$QSYS_SIMDIR/submodules/' + re.escape(f"{stem}.v") + r'"\s*'
            r'(?:-work\s+(?P<lib>\S+))?\s*$',
            re.MULTILINE,
        )
        m = pat.search(text)
        if not m:
            continue
        lib = m.group("lib") or "work"
        replacement = (
            f'  eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS '
            f'$USER_DEFINED_COMPILE_OPTIONS '
            f'"$QSYS_SIMDIR/submodules/{stem}.vhd"  -work {lib}'
        )
        text = text[:m.start()] + replacement + text[m.end():]
        stats["collision_swapped"] += 1

    setup.write_text(text)
    return stats


# ----------------------------------------------------------------------
# Recursion
# ----------------------------------------------------------------------
def discover_subsystems(top_kind: str,
                        kind_to_qsys: Dict[str, Path]) -> Dict[str, Path]:
    """BFS the qsys hierarchy. Returns kind -> qsys_path for every
    user-defined subsystem we want to generate (top included).
    Stock-IP compositions (altera_jtag_avalon_master etc.) are NOT
    enqueued here because their per-instance module names are
    parent-prefixed; their internals are recovered via synth-tree
    backfill instead."""
    queue: List[str] = [top_kind]
    out: Dict[str, Path] = {}
    while queue:
        k = queue.pop(0)
        if k in out or k not in kind_to_qsys:
            continue
        qpath = kind_to_qsys[k]
        out[k] = qpath
        for _inst, child_kind in kinds_in(qpath):
            if child_kind in kind_to_qsys and child_kind not in out:
                queue.append(child_kind)
    return out

# ----------------------------------------------------------------------
# Runner
# ----------------------------------------------------------------------
def needs_regen(qsys_path: Path, out_dir: Path) -> bool:
    """Idempotency check. True if out_dir is missing or older than qsys."""
    setup = out_dir / "simulation" / "mentor" / "msim_setup.tcl"
    if not setup.exists():
        return True
    return qsys_path.stat().st_mtime > setup.stat().st_mtime

def run_qsys_generate(kind: str,
                      qsys_path: Path,
                      out_root: Path,
                      search_paths: str,
                      family: str,
                      part: str,
                      log_dir: Path,
                      timeout: int = 600) -> Tuple[str, int, Path, float, bool]:
    """Run qsys-generate --simulation. Returns
       (kind, exit, log_path, wall, tolerated_partial)
    where tolerated_partial=True means qsys-generate exited non-zero but
    only because some downstream IP omitted its SIM fileset; the parent
    msim_setup.tcl was still produced and the synth-tree backfill will
    fill the gap. Such cases are NOT counted as failures."""
    out_dir = out_root / kind
    log_path = log_dir / f"{kind}.log"
    log_dir.mkdir(parents=True, exist_ok=True)
    if out_dir.exists():
        for p in out_dir.rglob("*"):
            try:
                p.chmod(p.stat().st_mode | 0o200)
            except OSError:
                pass
    cmd = [
        str(QSYS_GENERATE), str(qsys_path),
        "--simulation=VERILOG",
        "--allow-mixed-language-simulation",
        f"--output-directory={out_dir}",
        "--clear-output-directory",
        f"--family={family}",
        f"--part={part}",
        f"--search-path={search_paths},$",
    ]
    env = os.environ.copy()
    env["QSYS_DEBUG_LEVEL"] = "2"
    env["MU3E_IP_CORES_ROOT"] = str(REPO_ROOT)
    env["SYSTEM_DIR"] = str(SYSTEM_DIR)
    env.setdefault(
        "PATH",
        f"{QUARTUS_ROOTDIR}/bin:{QUARTUS_ROOTDIR}/sopc_builder/bin:{env.get('PATH','')}",
    )
    t0 = time.time()
    with log_path.open("wb") as lf:
        lf.write(f"# qsys-generate-recursive: {kind}\n# cmd: {' '.join(cmd)}\n".encode())
        proc = subprocess.run(cmd, stdout=lf, stderr=subprocess.STDOUT,
                              env=env, timeout=timeout)
    dt = time.time() - t0
    tolerated = False
    if proc.returncode != 0:
        log_text = log_path.read_text(errors="ignore")
        setup_tcl = out_dir / "simulation" / "mentor" / "msim_setup.tcl"
        if SIM_FILESET_MISSING_RE.search(log_text) and setup_tcl.exists():
            tolerated = True
    return (kind, proc.returncode, log_path, dt, tolerated)

# ----------------------------------------------------------------------
# CLI
# ----------------------------------------------------------------------
def parse_args(argv: List[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--top", required=True,
                   help="Top-level kind (e.g. scifi_datapath_system_v4)")
    p.add_argument("--jobs", "-j", type=int, default=8,
                   help="Parallel qsys-generate workers (default: 8)")
    p.add_argument("--family", default=FPGA_FAMILY)
    p.add_argument("--part", default=FPGA_PART)
    p.add_argument("--out-root", default=str(GEN_SIM_DIR),
                   help=f"Output root (default: {GEN_SIM_DIR})")
    p.add_argument("--log-dir", default=str(SYSTEM_DIR / "scripts" / ".recursive_logs"),
                   help="Where to write per-subsystem logs")
    p.add_argument("--clean", action="store_true",
                   help="Force regeneration of every subsystem")
    p.add_argument("--dry-run", action="store_true",
                   help="Print plan only, don't run qsys-generate")
    p.add_argument("--no-backfill", action="store_true",
                   help="Skip the synth-tree backfill pass")
    return p.parse_args(argv)

def main(argv: List[str]) -> int:
    args = parse_args(argv)
    out_root = Path(args.out_root)
    log_dir = Path(args.log_dir)

    print(f"[recursive] system dir: {SYSTEM_DIR}")
    print(f"[recursive] repo root:  {REPO_ROOT}")
    print(f"[recursive] top kind:   {args.top}")

    print("[recursive] collecting search paths ...", end="", flush=True)
    search_paths = collect_search_paths(REPO_ROOT)
    n_sp = len(search_paths.split(",")) if search_paths else 0
    print(f" {n_sp} paths")

    print("[recursive] building kind -> qsys map ...", end="", flush=True)
    kind_to_qsys = build_kind_to_qsys(REPO_ROOT)
    print(f" {len(kind_to_qsys)} project qsys files")

    if args.top not in kind_to_qsys:
        print(f"FATAL: top kind '{args.top}' has no .qsys in catalog",
              file=sys.stderr)
        print("       candidates: " + ", ".join(sorted(kind_to_qsys)[:20]),
              file=sys.stderr)
        return 2

    print("[recursive] discovering subsystems via XML walk ...")
    subsystems = discover_subsystems(args.top, kind_to_qsys)
    print(f"[recursive] {len(subsystems)} subsystems to generate:")
    for k, p in sorted(subsystems.items()):
        marker = "T" if k == args.top else "U"
        rel = p.relative_to(REPO_ROOT) if str(p).startswith(str(REPO_ROOT)) else p
        print(f"   [{marker}] {k:<48s}  {rel}")

    if args.dry_run:
        print("[recursive] --dry-run: stopping before qsys-generate")
        return 0

    work: List[Tuple[str, Path]] = []
    skipped: List[str] = []
    for k, p in sorted(subsystems.items()):
        out_dir = out_root / k
        if not args.clean and not needs_regen(p, out_dir):
            skipped.append(k)
        else:
            work.append((k, p))
    if skipped:
        print(f"[recursive] {len(skipped)} up-to-date: {', '.join(skipped)}")

    succeeded: List[str] = list(skipped)
    tolerated: List[str] = []
    failures: List[Tuple[str, Path]] = []

    if not work and args.no_backfill:
        print("[recursive] nothing to do")
        return 0
    if not work:
        print("[recursive] qsys-generate skipped; backfill pass only")
    else:
        print(f"[recursive] {len(work)} need regen; running with -j{args.jobs}")

    t_start = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as ex:
        futures = {
            ex.submit(run_qsys_generate, k, p, out_root, search_paths,
                      args.family, args.part, log_dir): k
            for k, p in work
        }
        for fut in concurrent.futures.as_completed(futures):
            kind = futures[fut]
            try:
                k, rc, log_path, dt, partial = fut.result()
            except Exception as e:
                print(f"  [FAIL] {kind}: exception {e}")
                failures.append((kind, log_dir / f"{kind}.log"))
                continue
            if rc == 0:
                status = "OK   "
                succeeded.append(k)
            elif partial:
                status = "PART "
                tolerated.append(k)
            else:
                status = "FAIL "
                failures.append((k, log_path))
            print(f"  [{status}] {k:<48s}  {dt:6.1f}s   log={log_path}")
    t_total = time.time() - t_start
    print(f"[recursive] qsys-generate wall: {t_total:.1f}s "
          f"(OK={len(succeeded)} PART={len(tolerated)} FAIL={len(failures)})")

    if failures:
        print(f"[recursive] {len(failures)} hard failures:", file=sys.stderr)
        for k, log in failures:
            print(f"   {k}  ->  {log}", file=sys.stderr)
        return 1

    # --- Synth-tree backfill --------------------------------------------------
    if not args.no_backfill:
        print("[recursive] synth-tree backfill (filling sim gaps from synth) ...")
        all_kinds = succeeded + tolerated
        for k in sorted(all_kinds):
            synth_top = GEN_SYN_DIR / k / "synthesis"
            if not synth_top.is_dir():
                print(f"   [{k}] no synth tree at {synth_top} - skipped")
                continue
            added, overwritten, total = backfill_from_synth(k, out_root)
            # ALWAYS (re)patch msim_setup based on current dst contents, not
            # only when files were freshly added. qsys-generate emits a clean
            # msim_setup with no backfill lines; if a prior backfill's files
            # survived --clear-output-directory, added==0 yet those files
            # still need their vcom/vlog lines re-injected into the fresh
            # msim_setup, or they exist on disk but never compile.
            hdl_ext = (".sv", ".v", ".vhd", ".vhdl")
            src_names = {sf.name
                         for sf in synth_top.rglob("*")
                         if sf.is_file() and sf.suffix.lower() in hdl_ext}
            dst = sim_submodules_dir(k, out_root)
            sim_top_dir = out_root / k / "simulation"
            # Exclude language-variant collisions (sim <kind>.v vs synth
            # <kind>.vhd) from the compile list.
            sim_variants: Set[Tuple[str, str]] = set()
            for scan_dir in (sim_top_dir, dst):
                if scan_dir.is_dir():
                    for sfp in scan_dir.iterdir():
                        if sfp.is_file() and sfp.suffix.lower() in hdl_ext:
                            sim_variants.add((sfp.stem, sfp.suffix.lower()))
            cand: List[Path] = []
            for df in dst.iterdir():
                if not (df.is_file() and df.suffix.lower() in hdl_ext):
                    continue
                if df.name not in src_names:
                    continue
                collide = any(stem == df.stem and ext != df.suffix.lower()
                              for (stem, ext) in sim_variants)
                if collide:
                    continue
                cand.append(df)
            setup = out_root / k / "simulation" / "mentor" / "msim_setup.tcl"
            inserted = 0
            if setup.exists():
                setup_text = setup.read_text()
                keep = [f for f in cand if f.name not in setup_text]
                inserted = patch_msim_setup_with_backfilled(k, keep, out_root)
            print(f"   [{k}] +{added}/{total} files, "
                  f"override={overwritten}, "
                  f"+{inserted} vlog/vcom lines into msim_setup.tcl")

        # --- Top-tree reconciliation (collision .v->.vhd, composed-IP
        #     board-wrapper swap). Only the seed top has a wrapper TB
        #     compiled against it, so reconcile only that tree. ----------
        rec = reconcile_top_sim_tree(args.top, out_root)
        print(f"[recursive] reconcile {args.top}: "
              f"{rec['collision_swapped']} collision .v->.vhd swaps, "
              f"{rec['lvds_swapped']} composed-IP board-wrapper swaps, "
              f"{rec['bare_aliased']} bare-entity prefixed aliases")
    print("[recursive] done")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

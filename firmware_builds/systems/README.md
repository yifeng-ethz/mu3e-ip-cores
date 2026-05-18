# `firmware_builds/systems/` - dated Mu3e firmware system builds

Each subdirectory is one dated firmware build that targets a specific Mu3e
board (FEB SciFi v3, SWB A10, ...). The layout of every dated system follows
the **System Folder Contract** owned by
`~/.codex/skills/rtl-file-structure-organization/SKILL.md` (thin Claude
pointer at `~/.claude/skills/rtl-file-structure/SKILL.md`).

Quick contract reminder (read the skill for the authoritative version):

```text
<system>/
  .gitignore
  README.md
  doc/                            # human-authored docs; BUG_HISTORY.md at the top
    BUG_HISTORY.md                # MANDATORY system-level bug ledger (see below)
    deprecated/                   # archived sweep / phase docs
  qsys_tcl/                       # pure .tcl that INFERS qsys connectivity
    script/                       # paired Sh/Py wrappers + parameter-only .tcl
  generated/                      # do-not-edit (chmod a-w on files)
    qsys/                         # .qsys, .sopcinfo, .html/.xml/.cmp/.rpt
    synthesis/<name>/             # qsys-generate --synthesis output (DEBUG_LEVEL=0)
    simulation/<name>/            # qsys-generate --simulation output (DEBUG_LEVEL=2)
  script/                         # other scripts (categorized subdirs)
    board/                        # on-board runners
    signaltap/                    # SignalTap .stp + generators + analysis
    report/                       # report_*.tcl
  syn/                            # Quartus project; top.qpf/qsf/qip live here per board
    board_projects/<board>/Makefile  # the build driver (see Make-targets contract)
  tb_int/
    trash_bin/                    # large logs / *.vcd / transcripts overflow
  trash_bin/                      # everything regeneratable / archival
```

## BUG_HISTORY.md - mandatory at every system root's `doc/`

Every dated system MUST carry `doc/BUG_HISTORY.md` at the system-doc level
(not only `tb_int/doc/BUG_HISTORY.md`). It is the system-level ledger of bugs
shipped or fixed by this build.

The format mirrors the FEB and SWB exemplars
(`260518-feb-ok/doc/BUG_HISTORY.md`, `260518-swb-ok/doc/BUG_HISTORY.md`):
class/severity legend, an index table, per-bug sections with
First seen, Symptom, Root cause, Fix, Reproduction, Evidence, Residuals.

`rtl-doc-style` lint applies (see `~/.codex/skills/rtl-doc-style/SKILL.md`).

## Make-targets contract - every board's `syn/board_projects/<board>/Makefile`

Every board's Makefile MUST expose the following user-facing targets. They
may be no-op placeholders the day a system is first cut, but the names and
semantics are fixed so a user can switch between systems without re-learning.

### Build targets

- `make help` - print every target and the resolved paths.
- `make qsys-from-tcl` - step 1: run `qsys_tcl/*.tcl` (and paired script/
  wrappers) to emit `generated/qsys/*.qsys` + `*.sopcinfo`.
- `make qsys-syn` - step 2a: `qsys-generate --synthesis` (DEBUG_LEVEL=0) into
  `generated/synthesis/<name>/`.
- `make qsys-gen` - step 2b: `qsys-generate --simulation` (DEBUG_LEVEL=2)
  into `generated/simulation/<name>/`.
- `make qsys` - step 1 + (optional) qsys-patch + step 2a + step 2b.
- `make app` - Nios SW BSP + main.cpp.
- `make flow_map` - Quartus `analysis_and_synthesis` (no fit).
- `make flow` - Quartus full compile (`map + fit + sta + asm`) -> `output_files/top.sof`.
- `make clean-trash` - mv build outputs to `<system>/trash_bin/build_<stamp>/`.
  Never `rm`, per CLAUDE.md hard rules.

### Simulation targets - `make sim-<case>`

Each tb_int scenario or named simulation gets one `sim-<case>` target.
Examples: `sim-upload_backpressure`, `sim-feb_swb_corun`, `sim-hist_dualport`.
The target runs the scenario under Questa One 2026.1 against the
`generated/simulation/<system>/` HDL tree (NOT a behavioral spec model) and
deposits the transcript under `tb_int/<case>/REPORT/`. Large `.log`,
`.vcd`, `vsim.wlf`, and `transcript` files overflow to `tb_int/trash_bin/`.

Placeholder is allowed; when a case is not wired yet the recipe should print
the intended invocation and exit non-zero so the user knows to wire it.

### On-board test targets - `make test-<case>`

Each on-board test scenario gets one `test-<case>` target that invokes a
Python or Tcl driver under `script/board/`. Examples:
`test-low_rate_hist`, `test-sc_smoke`, `test-mutrig_config`.

**Hard rules for every `test-<case>` script** (the Makefile is just a wrapper,
the discipline belongs to the script):

1. **Discover the register map at runtime from the sopcinfo or .qsys**. Do
   not hardcode CSR base addresses; load
   `generated/qsys/<system>.sopcinfo` (or the matching `.qsys`) and look up
   the slave's `baseAddress` for every IP you talk to. The sopcinfo is the
   source of truth for the address map for THIS firmware image.

2. **Use the IP's `.svd` as the CSR field-layout guide**. Every IP under
   `mu3e-ip-cores/<ip>/doc/` (or `misc/<ip>/doc/`) ships a `.svd` file that
   names every register, every bit field, and every reset value. Resolve
   field offsets and widths from the SVD, not from `mudaq_registers.h` or any
   other host-side cached header (those drift out of sync with the firmware -
   see `MEMORY.md` "SWB PLL register diagnosis" for a prior incident).

3. **On startup, read every on-board IP's `VERSION_MAJOR / VERSION_MINOR /
   VERSION_PATCH / BUILD / VERSION_DATE` from the IP's CSR** and compare
   against the sopcinfo's recorded version. If any IP's on-board readback
   does not match the sopcinfo expectation, the script MUST emit a clear
   `VERSION MISMATCH` warning that names the IP, the expected version, and
   the observed version - and continue (so a partial-mismatch run still
   produces evidence). Failing silently here was the root cause of past
   firmware-vs-host-driver drift incidents.

4. **Serialize SWB ring access via `~/.local/bin/swb_ring_lock`** when the
   script reaches the SWB SC ring (memory entry `SWB ring lock`).

5. **Use `sc_tool` for SWB / FEB SC reads**, never the deprecated
   `test_slowcontrol`. The sopcinfo's `baseAddress` for each FEB slave is in
   Qsys byte units; `sc_tool` takes the word address (`byte_addr / 4`) -
   that conversion happens in the runner, not in the user input
   (memory entry `sc_tool Address Encoding (sc_hub v2)`).

6. **Wait 20 s after `quartus_pgm`** before issuing any SC / SC-ring command
   (memory entry `FEB post-program 20s settle`).

7. **Output evidence**: each `test-<case>` run emits a markdown summary
   under `<system>/sweep_evidence/<case>/<stamp>/summary.md` (moved later
   into `trash_bin/sweep_evidence/<case>/...` once superseded), plus a
   labeled JSON sidecar for downstream plotting.

Skeleton (Python):

```python
#!/usr/bin/env python3
"""Generic on-board test driver template.

Usage: python3 script/board/test_<case>.py --sopcinfo generated/qsys/<system>.sopcinfo \\
                                            --svd-dir <repo>/misc/<ip>/doc \\
                                            --link 2
"""
import argparse, json, pathlib, subprocess, sys

def load_sopcinfo(path):
    # parse .sopcinfo XML to {slave_name: (base_byte, span_byte, ip_kind, ip_version)}
    raise NotImplementedError("TODO: parse sopcinfo for runtime address map")

def load_svd(svd_path):
    # parse CMSIS-SVD into {register_name: (offset, width, fields[])}
    raise NotImplementedError("TODO: parse SVD for register field layout")

def read_ip_version_via_sc(link, base_word, regs):
    # use sc_tool via swb_ring_lock; resolve VERSION_* fields from SVD
    raise NotImplementedError("TODO: read VERSION_MAJOR/MINOR/PATCH/BUILD/DATE")

def check_versions(sopcinfo, observed):
    mismatches = []
    for ip, expected in sopcinfo.items():
        seen = observed.get(ip)
        if seen != expected:
            mismatches.append((ip, expected, seen))
    if mismatches:
        print("WARNING: VERSION MISMATCH between sopcinfo and on-board IPs:",
              file=sys.stderr)
        for ip, exp, seen in mismatches:
            print(f"  {ip}: sopcinfo={exp}  on_board={seen}", file=sys.stderr)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sopcinfo", required=True)
    ap.add_argument("--svd-dir", required=True)
    ap.add_argument("--link", type=int, required=True)
    args = ap.parse_args()
    sopcinfo = load_sopcinfo(args.sopcinfo)
    # 1. settle window (FEB only): the caller is expected to have waited 20 s
    # 2. version checkup
    observed = {ip: read_ip_version_via_sc(args.link, base_byte // 4,
                                            load_svd(f"{args.svd_dir}/{ip_kind}.svd"))
                for ip, (base_byte, _span, ip_kind, _ver) in sopcinfo.items()}
    check_versions({ip: ver for ip, (_b, _s, _k, ver) in sopcinfo.items()},
                   observed)
    # 3. case-specific stimulus / readback ...

if __name__ == "__main__":
    main()
```

When a `test-<case>` is not yet wired, the Makefile recipe should print:
```
[test-<case>] PLACEHOLDER - wire script/board/test_<case>.py per
              firmware_builds/systems/README.md  "Make-targets contract"
exit 1
```
so the user is reminded that this case has not been implemented yet.

## Dated systems cut from origin/main, daily

Per the daily-worktree convention
([memory `daily-worktree-convention`]), cut a fresh
`mu3e_ip_cores_main_<YYYYMMDD>` worktree from `origin/main` at the start of
each work day. The system layouts above stay under that worktree's
`firmware_builds/systems/` tree.

The current canonical dated systems are:

| System | Board | Builds on | Notes |
|---|---|---|---|
| `260518-feb-ok/`  | FEB SciFi v3 (`fe_scifi_feb_v3`) | `arb_hit_type0` IP v26.6.5.0518 | SC fix + hist v3 + RDMA credit + PCIe app fix folded in |
| `260518-swb-ok/`  | SWB A10 (`swb_a10`)  | `ordered_priority_queue_native_sv_fixed4` v26.5.0.430 | RDMA credit + PCIe app fix folded in |

Older `v3_pretest-260511-*` and `swb/rdma_pretest-260511` systems remain as
the source-of-truth template + golden-pair archive, but new work is cut
under the dated `<YYMMDD>-<scope>-<status>/` form.

# tb_int/scifi_v4_wrapper - REAL integration TB for scifi_datapath_system_v4

This harness implements the lessons-learned rule from BUG-027-I (see
`firmware_builds/systems/260518-feb-ok/doc/LESSONS_LEARNT_BUG027.md` and
auto-memory `feedback_tb_int_must_compile_qsys_wrapper.md`):

- **DUT is the qsys subsystem wrapper** `scifi_datapath_system_v4` -
  not the bare `histogram_statistics_v2` IP, not `mts_preprocessor`,
  not anything internal to the subsystem.
- **No leaf IP source files in the vcom list.** Only
  `generated/simulation/scifi_datapath_system_v4/simulation/scifi_datapath_system_v4.v`
  and its co-located `submodules/` directory.
- **No driver inside the DUT.** The TB drives only the wrapper's entity
  port list. No SystemVerilog hierarchical reference like
  `dut.u_inner.something` is allowed. The harness `tb_top.sv` and the
  vcom file list together define the integration surface.
- **Observability is wrapper-boundary only.** Status registers come
  through `avmm_port`. Debug conduits (e.g. `hit_meta`) only when the
  wrapper exports them.

## Why this exists

`firmware_builds/systems/260518-feb-ok/tb_int/hist_v3/` exists and even
has a Type1 source-select scenario, but its run script picks the **leaf
IP RTL** from `generated/.../submodules/` and instantiates
`histogram_statistics_v2` directly. That bare-IP shape made BUG-027-I
(`asi_type1_up_ready` stripped from the wrapper) invisible to sim, and
it shipped to silicon. The new `scifi_v4_wrapper/` harness fixes the
structural gap.

## Status

**SKELETON, not yet runnable.** The wrapper entity has 43 ports across
~10 logical interfaces (avmm_clk/rst, avmm_port, hit_type3, inject_*,
lvds_outclock/pll, monitor_*, mutrig_reset, osc_clock, xcvr156_clock,
counter_sclr, run-control). Wiring all of them in a sim harness is a
multi-day effort and needs the wrapper interface to stabilise first
(the v4 cut is still in flux on the emulator side and on the Region B
SC-hub address layout). This README sets the rules; the harness body
will land in a follow-up commit once the integration test plan is
agreed.

## File layout (planned)

| File | Role |
|---|---|
| `tb_scifi_v4_wrapper.sv` | tb_top instantiating `scifi_datapath_system_v4 dut` and only the wrapper boundary signals |
| `run_scifi_v4_wrapper.sh` | vlib/vmap/vcom/vlog/vsim sequence; vcom file list contains the wrapper `.v` + everything under `submodules/`; NO standalone hist / MTSP / arb file |
| `sequences/` | Driver tasks that operate only on wrapper-boundary nets (avmm_port writes for CSR config, runctl AvST source toggles, etc.) |
| `monitors/` | Wrapper-boundary monitors only (hist bin readback via avmm_port, hit_type3 stream sink, etc.) |
| `REPORT/` | Per-run CSV + summary (gitignored) |

## Mechanical guards (queued)

A `scripts/check_tb_int_wrapper_only.py` is queued for next session:

```
# Pseudocode
1. find tb_int/*/run_*.sh files.
2. For each, parse the vcom file list.
3. FAIL if any vcom path is a leaf IP source file (e.g. matches
   histogram_statistics/, mts_preprocessor/, arb_hit_type0/) outside
   of generated/simulation/.../submodules/.
4. FAIL if any tb_top in that dir contains `<leaf_ip_name> #` or
   `<leaf_ip_name> u_`.
5. WARN on hierarchical references `dut\.\w+\.\w+\.` in the TB sources.
```

This is the mechanical gate that the user's auto-memory rule
`feedback_tb_int_must_compile_qsys_wrapper.md` calls for. Once the
gate is in CI, no future tb_int can regress to the bare-IP shape.

## Companion docs

- `firmware_builds/systems/260518-feb-ok/doc/LESSONS_LEARNT_BUG027.md`
- `firmware_builds/systems/260518-feb-ok/doc/BUG_HISTORY.md` (BUG-027-I)
- `~/.claude/projects/-home-yifeng-packages-mu3e-ip-dev/memory/feedback_tb_int_must_compile_qsys_wrapper.md`

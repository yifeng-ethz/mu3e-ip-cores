# Implementation Status — gts-unify (BUG-012) + integration-sim enablement (2026-05-29)

## ✅ RESULT: gts-unify FIXED + SILICON-VALIDATED (2026-05-29)
FEB programmed with the post-fix SOF (checksum 0x1D038C3A). On silicon, `source=TYPE1_UP`/
`in_port=FILL` delay-mode: the per-SYNC ~2^20 slide is ELIMINATED. Pre-fix centers across
SYNCs: -1028096/+39024/-71680/+678912 (spread ~750000). Post-fix: bounded near zero
(fine centers 768/480/-2000/1984, within +/-~2k cyc) — ~400x reduction. Residual ~1520c
width = emulator background frame-phase spread (not the bug). Logged as BUG-012-R in
doc/BUG_HISTORY.md. Compile: 0 errors, worst setup slack +0.359 ns.


Continuation of `FINDINGS_20260528_hist_delay_rootcause.md`. Root cause (confirmed):
the histogram delay-mode `gts_8n` and the MTS reconstructed timestamp are zeroed by
**independent** SYNC handlers → random per-SYNC offset (~2^20 cyc; measured centers
−1028096 / +39024 / −71680 / +678912 across SYNCs) → `delay` slides out of the bin
window. Fix = MTS exports its `counter_gts_8n` co-sampled with the emission ts; the
histogram subtracts that bank-matched arrival GTS instead of its own counter.

## Change 2 (injector gate) — DROPPED
Unit sim (`/tmp/tb_inject_repro/`) proved the trigger engine already launches a lone
idle inject with inject-time `tcc_anchor` (ts_a = inject-cycle value). The
`inject_pulse && engine_occupied` gate is NOT the bug → relaxing it is a no-op. User
approved dropping it.

## Change 1 (gts-unify) — IMPLEMENTED + UNIT-VALIDATED ✅

| File | Edit | Version |
|---|---|---|
| `mutrig_timestamp_processor/mts_processor.vhd` | new output `coe_hit_arrival_gts_8n`, latched = `counter_gts_8n` on the `coe_hit_type1_ts` emit beat; reset defaults | hdr 26.3.14 |
| `mutrig_timestamp_processor/mts_processor_hw.tcl` | `hit_arrival_gts` conduit (Output 48); VERSION 26.3.13→14, BUILD 529, DATE 20260529 | 26.3.14 |
| `histogram_statistics/rtl/histogram_statistics_v2.vhd` | new inputs `asi_type1_{up,down}_gts`; `port_arrival_gts(0)` mux by source_select; delay key `gts_value => port_arrival_gts(idx)`; **removed** dead `gts_8n` / `gts_counter_clear` / `runctl_reset_hold` island | hdr 26.4.3 |
| `histogram_statistics/histogram_statistics_v2_hw.tcl` | `type1_{up,down}_gts` sink conduits (Input 48); VERSION 26.4.2→3, BUILD 529, DATE 20260529 | 26.4.3 |
| `histogram_statistics/tb/tb_histogram_statistics_v2.sv` | drive `type1_{up,down}_gts` arrival input (blackbox); `inject_delay_hit_exact` uses a fixed arrival base instead of probing the deleted `dut.gts_8n` | — |

**Gates GREEN:** hist `B12_delay_mode_48b_sideband` → 2 PASS / 0 FAIL; MTS
`run_math/term/rearm/asic_id` → all PASS; MTS Questa static screen → Lint Error(0),
CDC Violations(0), RDC Violation(0).

## DECISION (2026-05-29): integration sim via debug-pair (--synthesis), not --simulation

`generate_qsys_debug_pair.sh:339-346` generates BOTH trees with `qsys-generate
--synthesis=VHDL` (the "simulation" tree is just `--synthesis` at DEBUG_LEVEL=2 into a
separate dir). `--synthesis` flattens compositions inline → emits ALL per-instance
parameterized wrappers AND needs no SIM filesets → it sidesteps every blocker the
newer `run_scifi_v4_wrapper.sh` (`--simulation`) hit. On Quartus 18.1 CLI the
`--simulation` path is a dead end for composed systems (never emits the parameterized
wrappers; the GUI does, the CLI doesn't). **Use the debug-pair.** The sim tree is then
faithful to the compile (both `--synthesis`; only DEBUG_LEVEL differs, and the
gts/delay path is not debug-gated).

**The 8 SIM-fileset additions I made were therefore REVERTED** (kept only the actual
fix: mts 26.3.14 + hist 26.4.3). The `run_scifi_v4_wrapper.sh` `--clean` fix is left in
place as a correct improvement but is not on the chosen path.

## Integration-sim enablement — superseded by the debug-pair decision (below kept for record)

To run the cross-IP `scifi_datapath_system_v4` integration TB before the ~50min
compile, the sim tree must generate. Findings + work done:

- **8 IPs given SIM filesets** (they only had QUARTUS_SYNTH → `qsys-generate
  --simulation` aborted one-at-a-time): `mutrig_injector_multiheader` (26.1.3),
  `mutrig_reset_controller`, `feb_frame_assembly`, `ring_buffer_cam` (SIM_VERILOG),
  `altera_lvds_rx_28nm`, `ip_8b10b_decoder`, `mu3e_lvds_controller_phy_adapter`
  (SIM_VERILOG), `lvds_rx_controller_pro` (SIM_VHDL via its `my_generate` callback).
- **`run_scifi_v4_wrapper.sh`**: wired `--clean` into `FORCE_QSYS_GEN` (the tool keyed
  idempotency on `.qsys` mtime, so hw.tcl edits were ignored without `--clean`).
- Result: `qsys-generate` now **OK=3 / PART=0** (was PART=2); elab errors **78 → 12**.

**Remaining blocker (4 modules):** the CLI sim flow emits the bare entities but not
the per-instance *parameterized* wrappers `scifi_datapath_system_v4_mts_preprocessor_0/1`,
`..._hit_stack_subsystem_0_feb_frame_assembly_0`,
`..._mutrig_datapath_subsystem_0_mutrig_frame_deassembly_0`. The mts_0/1 board-synth
equivalents are **stale** (no `hit_arrival_gts` port); frame_assembly/deassembly have
no board wrapper to borrow. AND the cross-IP conduit re-wire that validates the fix
must be added **inside the nested `data_path_subsystem` composition** of
`feb_system_v4.qsys` (no standalone scifi qsys; `qsys-script add_connection` does not
cleanly reach nested compositions; build provenance is patch-tcl-from-Tcl).

So a faithful POST-FIX integration sim needs: (a) hand-authored/adapted 4 wrappers
incl. the new port, (b) the nested-composition conduit re-wire, (c) fresh
feb_system_v4 synth wrappers (not stale). This is entangled with the integration build.

## Qsys re-wire — APPLIED to the canonical scifi qsys ✅
Added two `<connection kind="conduit">` blocks to
`mu3e-ip-cores/quartus_systems/scifi_datapath_system_v4.qsys` (the canonical
data_path_subsystem definition; the build resolves it via search path):
- `mts_preprocessor_0.hit_arrival_gts` → `histogram_statistics_0.type1_up_gts`
- `mts_preprocessor_1.hit_arrival_gts` → `histogram_statistics_0.type1_down_gts`
Byte-identical in structure to the existing `hit_type1_ts → type1_{up,down}_ts`
connections (verified). Interface names match the bumped hw.tcl (mts hit_arrival_gts
26.3.14; hist type1_{up,down}_gts 26.4.3). `make qsys-syn` re-reads this qsys + the
updated hw.tcls from the search path, so NO full qsys-from-tcl regen is needed (per
the skip-qsys-from-tcl rule). The standalone patch tcl
`qsys_tcl/patch_scifi_datapath_v4_hist_arrival_gts.tcl` is also kept for reproducibility.

## (historical) earlier re-wire notes
Patch authored: `qsys_tcl/patch_scifi_datapath_v4_hist_arrival_gts.tcl` (mirrors the
hist_type1_extended precedent). It connects, inside `scifi_datapath_system_v4`:
- `mts_preprocessor_0.hit_arrival_gts` → `histogram_statistics_0.type1_up_gts` (conduit)
- `mts_preprocessor_1.hit_arrival_gts` → `histogram_statistics_0.type1_down_gts` (conduit)

**Build-flow facts (syn/board_projects/fe_scifi_feb_v3/Makefile):**
- `QSYS_NAMES = arb_hit_type0_supercore scifi_datapath_system_v4 feb_system_v4`.
- `make qsys-from-tcl` (step 1) regenerates `generated/qsys/*.qsys` from `qsys_tcl/`.
- The `apply_*` patchers are run MANUALLY in a specific order (the Makefile's
  `qsys-patch` target is a NO-OP placeholder; legacy `apply_*_qsys.sh` wrappers
  encoded the per-file load/patch/save context). This manual patch ORDER is the
  one piece needing the build owner's knowledge.
- `make qsys-syn` (2a) = qsys-generate --synthesis; `make flow` = qsys + app.
- `generated/qsys/` currently holds ONLY `feb_system_v4.qsys` (26 KB composed top);
  `scifi_datapath_system_v4.qsys` is regenerated by qsys-from-tcl (not present now).

## qsys-syn DONE — re-wire validated at integration level ✅ (2026-05-29 11:21)
`make qsys-syn` regenerated `generated/synthesis/feb_system_v4/` cleanly
("qsys-generate succeeded", 206 modules). The regen pulled the edited IPs (mts 26.3.14
with `coe_hit_arrival_gts_8n`; hist 26.4.3 with `asi_type1_{up,down}_gts`) AND the
re-wire — confirmed in `feb_system_v4_data_path_subsystem.vhd`:
```
mts_preprocessor_0:coe_hit_arrival_gts_8n -> histogram_statistics_0:asi_type1_up_gts
mts_preprocessor_1:coe_hit_arrival_gts_8n -> histogram_statistics_0:asi_type1_down_gts
```
This is the integration-level conduit-wiring check (Quartus would have errored on a
mismatch) — PASSED. The synthesis tree is ready for the bitstream compile. NOTE: run the
compile DIRECTLY (`quartus_sh --flow compile top -c top`), NOT `make flow` (which re-runs
qsys-from-tcl and would re-compose from scratch). Per the skip-qsys-from-tcl rule.

**Remaining sequence to land the fix on silicon:**
1. `make qsys-from-tcl` → regenerate subsystem qsys (with the bumped IP versions:
   mts 26.3.14, hist 26.4.3, injector 26.1.3 — all ≥ Apr-27 floor).
2. Apply the `apply_*` patch chain IN ORDER, plus the new
   `patch_scifi_datapath_v4_hist_arrival_gts.tcl`, to
   `generated/qsys/scifi_datapath_system_v4.qsys`.
3. `make qsys-syn` (Quartus errors here if the conduit names/widths mismatch — this
   is the integration-level wiring check the standalone sim can't give).
4. `quartus_sh --flow compile` (~50 min). Confirm STA at target.
5. Program FEB (20 s settle, LVDS re-train, MuTRiG reconfigure), then on-board:
   set hist `source=TYPE1_UP`, FILL in_port (bank ts path), inject + read delay-mode
   bins. EXPECT: delay distribution bounded + REPRODUCIBLE across SYNCs (no per-SYNC
   ~2^20 slide); centered near the MTS pipeline latency. Slope vs header_delay if
   using the injector single fixed-phase hit.
6. Log BUG-012 in `doc/BUG_HISTORY.md` with the directed repro at both tb levels.

NOTE: re-running qsys-from-tcl risks the documented apr27 search-path pollution; pass
explicit `--search-path` whitelisting active IP dirs and EXCLUDING old
`firmware_builds/systems/system_2026*` (see memory `feedback_qsys_apr27_pollution`).

## Artifacts
- Logs: `/tmp/feb_bug012_plots/scifi_v4_*.log`, `mts_static_screen.log`.
- Inject repro TB: `/tmp/tb_inject_repro/`.

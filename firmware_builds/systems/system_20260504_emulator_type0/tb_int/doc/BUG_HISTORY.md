# BUG_HISTORY.md - system_20260504_emulator_type0 tb_int DV bug ledger

Class legend:
- `R` = RTL / generated-system integration bug
- `H` = harness / testcase / reporting bug

Severity legend:
- `soft error` = the issue corrupts a diagnostic or bounded observation without changing synthesized datapath behavior
- `hard stuck error` = the issue can suppress a datapath component, wedge run-control progress, or create a false loss signature that blocks closure
- `non-datapath-refactor` = observability, documentation, or reporting work with no direct datapath effect

Encounterability legend:
- practical severity is `severity x encounterability`
- nominal integration operation = legal 100 kHz/channel traffic, software-paced run-control commands, and no forced pathological stalls
- `common (...)` = readily hit in nominal integration simulation
- `occasional (...)` = legal in nominal simulation but dependent on traffic/run alignment
- `rare (...)` = legal but usually requires long runtime or unlucky alignment
- `corner-only (...)` = requires a non-nominal stress or diagnostic profile
- `directed-only (...)` = requires a targeted reproducer or reporting-only flow

Fix status detail contract for active entries and future updates:
- `state` = fixed / open / partial plus the current verification gate
- `mechanism` = how the implemented repair changes RTL, Qsys Tcl, or harness behavior
- `before_fix_outcome` and `after_fix_outcome` = concise evidence showing what changed
- `potential_hazard` = whether the fix is permanent or still needs broader regression evidence

Historical formal note:
- this ledger starts on `2026-05-06` for the integration `tb_int/doc` tree at
  `/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_hit_type0_mux_20260504/firmware_builds/systems/system_20260504_emulator_type0/tb_int`
- generated Qsys RTL is evidence for integration debug but not an authored
  source; fixes must land in Qsys Tcl or maintained IP sources before
  regeneration

## Index

| bug_id | class | severity | encounterability | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| [BUG-001-H](#bug-001-h-prof-int-002-bound-only-one-hit-stack-and-one-feb-egress) | H | hard stuck error | `common (8-lane PROF-INT-002 observation)` | fixed in harness; compile/run evidence pending | PROF-INT-002 short run on `2026-05-05` | 9a2d526c | PROF-INT-002 observed only 4 of 8 rbCAM egresses and one FEB egress, producing false `POST=64` / `FEB=52` loss signatures. |
| [BUG-002-R](#bug-002-r-qsys-run-control-slot-reuse-disconnected-mts-preprocessor-1) | R | hard stuck error | `common (lower 4 lanes in full8lane generated system)` | fixed in Qsys Tcl; regeneration/compile evidence pending | generated RTL audit on `2026-05-06` | 9a2d526c | `mutrig_frame_deassembly_0.ctrl` reused run-control splitter out12 and left `mts_preprocessor_1.run_ctrl` unconnected. |
| [BUG-003-R](#bug-003-r-histogram-ingress-bridge-backpressured-primary-pre-rbcam-stream) | R | hard stuck error | `common (pre-rbCAM histogram selected)` | fixed in IP source and Qsys Tcl; integration rerun pending | PROF-INT-002 diagnostic on `2026-05-06` | 586b3a0 | `histogram_ingress_bridge` let the diagnostic histogram sink deassert primary pre-rbCAM ready, suppressing MTS egress into rbCAM. |
| [BUG-004-R](#bug-004-r-readyless-hit-stack-run-control-was-materialized-through-command-fifos) | R | hard stuck error | `common (software-paced run-control in generated hit-stack subsystem)` | fixed in Qsys Tcl and harness diagnostics; regeneration/compile evidence pending | PROF-INT-002 short run on `2026-05-06` | 9a2d526c | Readyless hit-stack run-control was converted through command FIFOs that waited for local slave ready, so rbCAM GO asserted but rbCAM FSMs did not enter RUNNING. |
| [BUG-005-R](#bug-005-r-registered-emulator-ticket-offer-replayed-one-cycle-after-accept) | R | hard stuck error | `common (header-sync source injection with ready asserted)` | fixed in IP source; phase sweep passed | PROF-INT-002 pre-rbCAM two-channel diagnostic on `2026-05-06` | 1849caa | `frontend_trigger_engine` replayed one accepted signal ticket, so one two-channel injection produced four hits instead of two. |
| [BUG-006-H](#bug-006-h-prof-int-002-non-asic0-header-sync-used-asic0-only-controls-and-lane-identity) | H | hard stuck error | `directed-only (non-ASIC0 header-sync source validation)` | fixed in harness; ASIC1-7 sweep passed | PROF-INT-002 ASIC1 pre-rbCAM diagnostic on `2026-05-06` | pending | Non-ASIC0 header-sync validation was blocked by ASIC0-only source controls, arb CSR setup, and scoreboard lane identity. |
| [BUG-007-R](#bug-007-r-direct-emulator-source-does-not-produce-mutrig-injector-headerinfo) | R | hard stuck error | `directed-only (RTL-injector header-sync validation with direct emulator source)` | open RTL patch; simulation shim validated | PROF-INT-002 RTL-injector phase-sweep setup on `2026-05-06` | pending | The direct emulator source does not drive the FDA/headerinfo valid stream that `mutrig_injector_0` uses for CSR-controlled header-sync delay, so emulator-only RTL-injector scans need a temporary harness shim until the RTL/integration path is repaired. |
| [BUG-008-R](#bug-008-r-unconnected-inject-aux-pulse-poisoned-injector-fanout) | R | hard stuck error | `directed-only (RTL-injector path using generated fanout)` | open Qsys tie-off; harness force validated | PROF-INT-002 RTL-injector smoke on `2026-05-06` | pending | `full8lane_type0_system` left `data_path_subsystem.inject_aux_pulse` unconnected, so `pulse_fanout8` ORed the real injector pulse with `X` and suppressed emulator hits in simulation. |
| [BUG-009-H](#bug-009-h-full8-full32-header-sync-burst-sweep-has-ambiguous-direct-emulator-identity) | H | hard stuck error | `directed-only (multi-active direct-emulator header-sync burst reference)` | open blocker; plot guard added | PROF-INT-002 full8/full32 burst sweep on `2026-05-06` | pending | Full8/full32 direct-emulator header-sync burst sweeps cannot be accepted as golden pre-rbCAM latency plots because the current monitor identity aliases multi-active direct-emulator hits and the generated path drops most Stage-A offers before pre-rbCAM. |
| [BUG-010-H](#bug-010-h-direct-emulator-evidence-was-being-treated-like-virtual-mutrig-golden-evidence) | H | soft error | `directed-only (source-model comparison and golden reference reporting)` | partial contract documented; RTL/scoreboard upgrade in progress | PROF-INT-002 source comparison on `2026-05-06` | pending | The direct FPGA emulator, tagged virtual MuTRiG source model, and physical MuTRiG ASIC were not separated in tb_int evidence tags, making rate/header-sync agreement look stronger than the underlying source model justified. |
| [BUG-011-H](#bug-011-h-tagged-mutrig-frame-generator-bound-to-generated-system-crc) | H | hard stuck error | `directed-only (virtual MuTRiG source simulation)` | fixed in Makefile library isolation; compile passed | PROF-INT-002 virtual MuTRiG smoke on `2026-05-06` | pending | The tagged MuTRiG frame generator component-bound to the generated-system `crc16_8` entity with a different port list, preventing virtual MuTRiG simulation elaboration. |
| [BUG-012-H](#bug-012-h-pre-rbcam-source-validation-enforced-downstream-sva-scope) | H | soft error | `directed-only (pre-rbCAM-only source-validation runs)` | fixed in assertion scope control; virtual MuTRiG burst sweep passed | PROF-INT-002 virtual MuTRiG smoke on `2026-05-06` | pending | Pre-rbCAM-only source-validation runs still enforced post-rbCAM/FEB SVA windows, so downstream residuals polluted a source-stage latency contract. |
| [BUG-013-H](#bug-013-h-dual-uvm-sidecar-lineage-was-not-bound-for-all-source-modes) | H | hard stuck error | `common (DEBUG_LEVEL=2 sidecar lineage closure)` | partial; dual UVM harness fixed, generated-system refresh pending | PROF-INT-002 DEBUG_LEVEL=2 sidecar smoke on `2026-05-06` | pending | tb_int had a nominal latency path but no fully independent sidecar-source path for every source mode, so OoO sidecar lineage could be inactive or stale while latency plots still exported normally. |
| [BUG-014-R](#bug-014-r-debug-sidecar-bank-bridge-gated-lineage-on-unconnected-endofrun) | R | hard stuck error | `common (DEBUG_LEVEL=2 full8lane generated simulation)` | fixed in IP source and regenerated Qsys sim RTL; full downstream closure pending | PROF-INT-002 virtual MuTRiG sidecar rerun on `2026-05-06` | pending | `debug_hit_sidecar_bank_bridge` gated sidecar-valid/read-accept on an optional `endofrun` input that the generated full8lane system left open, suppressing source IDs at pre-rbCAM. |
| [BUG-015-H](#bug-015-h-dislin-latency-renderer-dropped-out-of-display-stage-records) | H | soft error | `directed-only (post-rbCAM/FEB latency plotting with outliers)` | fixed in plotting script; regenerated 10/100 kHz all-stage plot exposes blocker | PROF-INT-002 post-rbCAM/FEB plot generation on `2026-05-06` | pending | The DISLIN renderer counted only bins inside the display range, so post-rbCAM/FEB records outside the DV_PLAN aperture could be reported as zero total instead of out-of-window hits. |
| [BUG-016-H](#bug-016-h-short-run-control-gap-made-rbcam-look-like-it-rejected-in-window-hits) | H | hard stuck error | `directed-only (post-rbCAM debug run-control override)` | fixed in harness guard; post-rbCAM rerun passed | PROF-INT-002 post-rbCAM ASIC0 100 kHz debug on `2026-05-07` | pending | A 1000-cycle debug run-control gap advanced RUNNING while rbCAM was still flushing, so hits accepted at pre-rbCAM were delayed until termination and looked like rbCAM rejection. |
| [BUG-017-H](#bug-017-h-virtual-mutrig-periodic-hits-used-hit-count-as-timestamp) | H | hard stuck error | `common (virtual MuTRiG post-rbCAM periodic validation)` | fixed in harness; post-rbCAM sweep passed | PROF-INT-002 virtual MuTRiG post-rbCAM 10 kHz on `2026-05-07` | ec5b6ebb | The virtual MuTRiG periodic source stamped hit T coarse from a local hit counter instead of the generated MuTRiG timebase, creating false rbCAM timestamp-window drops. |

## 2026-05-06

### BUG-001-H: PROF-INT-002 bound only one hit-stack and one FEB egress

- First seen in:
  - PROF-INT-002 bounded short run on `2026-05-05`
  - scoreboard summary `A=352 PRE=256 POST=64 FEB=52`, `stable_closed=52/352`
- Symptom:
  - post-rbCAM and FEB-egress counts were far below Stage-A/pre-rbCAM counts
  - latency plots outside the expected post-rbCAM/FEB apertures looked like datapath loss even though lower-stack taps were not bound
- Root cause:
  - `tb_int_env` had only four rbCAM tap slots and one FEB-egress slot
  - `prof_int_002_full_pipeline_top.sv` configured only `hit_stack_subsystem_0` pre/post rbCAM taps and only the upper FEB egress
  - optional monitor slots were fatal, preventing aggregate monitor arrays from sharing a generic single-tap smoke top
- Fix status:
  - state:
    fixed in harness; `make comp_uvm` / PROF compile evidence pending
  - mechanism:
    `tb_int_env` now instantiates eight pre-rbCAM monitors, eight post-rbCAM monitors, and two FEB-egress monitors; optional unbound slots are disabled instead of fatal; PROF-INT-002 binds both hit-stack subsystems and both FEB egresses
  - before_fix_outcome:
    the scoreboard reported false post-rbCAM/FEB residuals and could not distinguish a real datapath loss from an observation tap miss
  - after_fix_outcome:
    pending current compile and rerun; the harness now emits `PROF_INT_002_MON_BIND` with Stage-A/pre/post/FEB activity bits and MTS0/1 status bits during RUNNING
  - potential_hazard:
    permanent for the full8lane wrapper path; future generated-system wrappers must keep aggregate monitor-slot counts aligned with active hit-stack/FEB instances

### BUG-002-R: Qsys run-control slot reuse disconnected `mts_preprocessor_1`

- First seen in:
  - generated RTL audit on `2026-05-06` while following the PROF-INT-002 diagnostic order
- Symptom:
  - generated `full8lane_type0_system_data_path_subsystem.v` connected `mts_preprocessor_1.asi_ctrl_data/valid/ready` to empty ports
  - lower-stack MTS output could remain silent even when the lower emulators and hit-stack monitors were otherwise bound
- Root cause:
  - the Qsys Tcl follow-up for removing the intermediate type0 run-control splitter reused `run_control_splitter.out12` for `mutrig_frame_deassembly_0.ctrl`
  - in the reference full8lane topology out12 belongs to `mts_preprocessor_1.run_ctrl`, so the generated system silently dropped the lower MTS run-control input
- Fix status:
  - state:
    fixed in `build_full8lane_system.tcl`; regeneration/compile evidence pending
  - mechanism:
    the top-level run-control splitter stays at the Intel 18.1 16-output limit; out12 feeds a new two-output readyless splitter whose out0 drives `mts_preprocessor_1.run_ctrl` and whose out1 drives `mutrig_frame_deassembly_0.ctrl`
  - before_fix_outcome:
    the generated RTL showed `mts_preprocessor_1` run-control ports unconnected and out12 feeding `mutrig_frame_deassembly_0.ctrl`
  - after_fix_outcome:
    pending Qsys regeneration and no-STP/STP compile evidence
  - potential_hazard:
    low after regeneration because the fix restores the reference fanout slot assignment instead of adding a simulation-only force

### BUG-003-R: histogram ingress bridge backpressured primary pre-rbCAM stream

- First seen in:
  - PROF-INT-002 short diagnostic on `2026-05-06` after aggregate monitor and MTS1 run-control fixes
  - command:
    `make run_prof_int_002_full_pipeline_100khz_per_channel_test PROF_INT_002_RUN_CYCLES=20000 PROF_INT_002_DRAIN_CYCLES=1024 PROF_INT_002_RUNCTL_CPP_GAP_CYCLES=1000 PROF_INT_002_RUNCTL_SETTLE_TIMEOUT_CYCLES=20000 SEED=2`
- Symptom:
  - `PROF_INT_002_MTS_CSR` reported both MTS preprocessors RUNNING with no discard increments
  - `PROF_INT_002_RBCAM_CSR` reported all rbCAM GO bits asserted
  - `PROF_INT_002_COUNTERS` showed `mux_mts=320`, `mts_out=0`, `hisb_pre=0`, and rbCAM push/pop counters all zero
- Root cause:
  - the generated system placed `histogram_ingress_bridge` on the pre-rbCAM primary stream
  - when CSR selected the pre histogram tap, the bridge tied `asi_pre_ready` to the histogram sink readiness, allowing the diagnostic histogram path to backpressure the primary MTS-to-rbCAM datapath
- Fix status:
  - state:
    fixed in `histogram_statistics` source commit `586b3a0` and `build_full8lane_system.tcl`; PROF integration rerun pending
  - mechanism:
    `histogram_ingress_bridge` v26.0.5 now drives the primary pre stream ready from the downstream rbCAM path and treats the histogram pre tap as lossy when the histogram sink is not ready; the Qsys Tcl pins the regenerated full8lane datapath to this bridge version
  - before_fix_outcome:
    legal low-rate traffic could stop before rbCAM even though run control and GO were asserted
  - after_fix_outcome:
    standalone `tb_histogram_ingress_bridge` directed regression passes and Qsys regeneration emits bridge v26.0.5; PROF-INT-002 rerun pending
  - potential_hazard:
    low after integration rerun because the fix removes diagnostic-path backpressure from the primary datapath contract

### BUG-004-R: readyless hit-stack run-control was materialized through command FIFOs

- First seen in:
  - PROF-INT-002 short diagnostic on `2026-05-06` after aggregate monitor, MTS1 run-control, and histogram bridge fixes
  - command:
    `make run_prof_int_002_full_pipeline_100khz_per_channel_test PROF_INT_002_RUN_CYCLES=20000 PROF_INT_002_DRAIN_CYCLES=1024 SEED=2`
- Symptom:
  - `PROF_INT_002_MTS_CSR` reported both MTS preprocessors RUNNING
  - `PROF_INT_002_RBCAM_CSR` reported all rbCAM GO bits asserted, but `run_state_running=00000000` and direct `dbg_run_state_code={9,9,9,9,9,9,9,9}`
  - `PROF_INT_002_COUNTERS` after drain showed traffic reached the pre-rbCAM splitter (`mts_out=30`, `hisb_pre=30`, `ds={30,30,30,30,0,0,0,0}`), while `rb_hit=0` and `feb_hit=0`
  - scoreboard summary was `A=384 stable_A=384 PRE=120 POST=0 FEB=0 closed=0 stable_closed=0`
- Root cause:
  - the Qsys Tcl helper that made the hit-stack run-control splitter readyless also inserted `run_control_cmd_fifo_0..5`
  - those FIFOs waited on the downstream local ready signals before forwarding the command to rbCAM/FEB consumers
  - the rbCAM/FEB run-control VHDL decodes `asi_ctrl_valid` directly; local ready is an acknowledgement/diagnostic surface, not a permission to backpressure software run-state commands
- Fix status:
  - state:
    fixed in `build_full8lane_system.tcl` and harness diagnostics; regeneration/compile evidence pending
  - mechanism:
    the readyless hit-stack Qsys copy now only sets `run_control_splitter_0.USE_READY=0` and keeps direct splitter outputs to `ring_buffer_cam_0..3.run_control`, `feb_frame_assembly_0.ctrl_datapath`, and `run_ctrl_cdc_d2x.in`; PROF-INT-002 no longer references the removed command FIFOs and logs broadcast valid vectors plus CSR state instead of ready acceptance
  - before_fix_outcome:
    all rbCAM instances had GO set but remained outside RUNNING, so the apparent post-rbCAM/FEB loss was a generated run-control gating bug rather than a monitor-only issue
  - after_fix_outcome:
    pending Qsys regeneration, PROF compile, and bounded PROF-INT-002 rerun
  - potential_hazard:
    low after regeneration because the fix removes the generated backpressure element and restores the intended readyless broadcast contract; a future packet-based ACK path must be explicit and backward-merged rather than implemented as forward-stream ready

### BUG-005-R: registered emulator ticket offer replayed one cycle after accept

- First seen in:
  - PROF-INT-002 ASIC0/two-channel pre-rbCAM header-sync diagnostic on `2026-05-06`
  - command:
    `make -C firmware_builds/systems/system_20260504_emulator_type0/tb_int run_prof_int_002_pre_rbcam_latency PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE=header_sync PROF_INT_002_PRE_RBCAM_INJECT_PHASE_CYCLES=100 PROF_INT_002_PRE_RBCAM_INJECT_PULSE_COUNT=4 PROF_INT_002_PRE_RBCAM_RUN_CYCLES=50000 PROF_INT_002_PRE_RBCAM_DRAIN_CYCLES=4096`
- Symptom:
  - four header-sync injection pulses with `TB_INT_HIT_CHANNEL_LOW=0` and `TB_INT_HIT_CHANNEL_HIGH=1` produced 16 pre-rbCAM rows instead of the expected 8
  - `lane_hit_count[0]` advanced by four per pulse, proving the duplicate was in the emulator source RTL rather than a pre-rbCAM monitor double-count
  - phase-100 latency still formed a narrow peak near 821-825 cycles, so the count bug could have hidden behind apparently sane latency shape
- Root cause:
  - `frontend_trigger_engine.sv` registered `sig_offer_valid_q` directly from `dispatch_found`
  - the accepted pending bit was cleared in the same clocked block using the registered lane, so `dispatch_found` still observed the old `pending_mask` for one cycle
  - with downstream `sig_offer_ready` asserted, the same ticket was presented and accepted twice before the pending bit disappeared
- Fix status:
  - state:
    fixed in `emulator_mutrig/rtl/frontend/frontend_trigger_engine.sv`; generated simulation copies patched for the current tb_int evidence run; RTL fix commit `1849caa` is pushed in `emulator_mutrig`
  - mechanism:
    the registered ready/valid stage now holds while not ready, drops `sig_offer_valid_q` for one cycle after a successful accept, and only reloads from `pending_mask` after the clear has taken effect
  - before_fix_outcome:
    `pre_rbcam_records.csv` had 16 data rows for four two-channel pulses
  - after_fix_outcome:
    focused rerun `prof_int_002_pre_rbcam_header_sync_phase100_diag_after_offer_fix` passes with 8 data rows, unique channels `{0,1}`, and analyzer latency `min=821`, `p50=821.5`, `max=822` cycles. The 128-pulse header-sync phase sweep passes phases 100 through 900 with 256 pre-rbCAM rows per phase. Phases 100..800 are narrow peaks at `821.5, 721.5, 621.5, 521.5, 421.5, 321.5, 221.5, 121.5` cycles, matching `910 - phase + 11.5` cycles. Phase 900 is the expected frame-edge split: bins at 21 cycles (1 hit), 25 cycles (127 hits), and 929 cycles (128 hits).
  - potential_hazard:
    low after the phase sweep and IP commit because the repair restores a standard one-accept-per-valid ready/valid contract; regenerated Qsys RTL must be refreshed from the IP source before synthesis sign-off

### BUG-006-H: PROF-INT-002 non-ASIC0 header-sync used ASIC0-only controls and lane identity

- First seen in:
  - PROF-INT-002 ASIC1/two-channel pre-rbCAM header-sync diagnostic on `2026-05-06`
  - command:
    `make -C firmware_builds/systems/system_20260504_emulator_type0/tb_int run_prof_int_002_pre_rbcam_latency PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE=header_sync PROF_INT_002_PRE_RBCAM_ACTIVE_LANE_MASK=2 PROF_INT_002_PRE_RBCAM_INJECT_PHASE_CYCLES=100 PROF_INT_002_PRE_RBCAM_INJECT_PULSE_COUNT=4 PROF_INT_002_PRE_RBCAM_RUN_CYCLES=50000 PROF_INT_002_PRE_RBCAM_DRAIN_CYCLES=4096 PROF_INT_002_RUNCTL_CPP_GAP_CYCLES=1000`
- Symptom:
  - non-ASIC0 header-sync source validation did not produce loadable pre-rbCAM latency rows even though the generated datapath produced the expected pre-rbCAM beats
  - the diagnostic trace showed Stage-A observations on physical lane 1 while the downstream pre-rbCAM monitor reported lane 0, yielding `A->PRE matched/missing/ghost=0/8/8`
  - before the active-lane CSR fix, only arb lane 0 was programmed to emulator mode, so non-ASIC0 runs could silently select the wrong source path
- Root cause:
  - the pre-rbCAM make target hardcoded `TB_INT_ACTIVE_LANE_MASK=1` and only configured the arb0 CSR aperture
  - the header-sync pulse driver waited on the old ASIC0-only serialized `lane_frame_start[0]` signal instead of the common generated-emulator `frame_start_req` boundary used when `BYTE_STREAM_ENABLE=0`
  - the Stage-A monitor reported the selected physical Qsys emulator lane, while the pre-rbCAM monitor used the hit_type1 ASIC payload field as the scoreboard lane; in direct internal-emulator profiling this payload field was not a reliable physical-source selector for single-active non-ASIC0 runs
- Fix status:
  - state:
    fixed in harness; ASIC1-7 phase-100 sweep passed
  - mechanism:
    `prof_int_002.mk` now exposes active-lane count/mask plusargs and adds an ASIC1-7 phase-100 target; `prof_int_002_full_pipeline_top.sv` programs every active arb CSR lane to emulator mode, drives pulses into the selected active emulator lane, waits on the common generated-emulator frame boundary, and maps single-active `header_sync` pre-rbCAM scoreboard lane identity to the active physical source lane
  - before_fix_outcome:
    the ASIC1 four-pulse diagnostic exported no loadable pre-rbCAM latency rows and reported `A->PRE matched/missing/ghost=0/8/8`
  - after_fix_outcome:
    the ASIC1 four-pulse rerun `prof_int_002_pre_rbcam_header_sync_asic1_phase100_diag4_lane_remap` passes with 8 pre-rbCAM rows, `A->PRE matched/missing/ghost=8/0/0`, and analyzer latency `min=822`, `p50=822.5`, `max=823` cycles. The full ASIC1-7 individual phase-100 sweep passes all seven 128-pulse runs with 256 rows per ASIC, `A->PRE matched/missing/ghost=256/0/0` for every ASIC, and aggregate analyzer min/p05/p50/p95/max = `821/821/822/823/823` cycles. The DISLIN-style evidence renderer covers the pre-rbCAM latency range `[-1000, 3096]` cycles and the 8-ASIC channel-rate range `0..255`.
  - potential_hazard:
    this fix is scoped to single-active direct-emulator source-validation runs; multi-lane and real-LVDS runs must keep using the physical monitor binding appropriate to their source boundary and must not infer a real external ASIC lane from this harness-only remap

### BUG-007-R: direct emulator source does not produce `mutrig_injector` headerinfo

- First seen in:
  - PROF-INT-002 RTL-injector ASIC0/two-channel phase-sweep setup on `2026-05-06`
  - planned command family:
    `make -C firmware_builds/systems/system_20260504_emulator_type0/tb_int run_prof_int_002_pre_rbcam_header_sync_phase_sweep_100_900_rtl_injector`
- Symptom:
  - the generated full8lane system contains the real `mutrig_injector_0` CSR-controlled header-sync path, and its output fans out to every `emulator_mutrig_N.coe_inject_pulse`
  - direct emulator source mode exposes the emulator `frame_start_req` boundary used by the existing harness, but it does not drive the `mutrig_frame_deassembly_N_headerinfo_valid/channel/data` stream consumed by `mutrig_injector_0`
  - a pure emulator-only CSR scan of injector mode 1 would therefore produce no delayed injector pulse unless the harness temporarily synthesizes a headerinfo match
- Root cause:
  - the real MuTRiG/LVDS path produces headerinfo through `mutrig_frame_deassembly`, while the direct internal emulator path bypasses that deassembly boundary
  - `mutrig_injector_multiheader` intentionally keys mode-1 injection from headerinfo, so direct emulator profiling currently lacks the same header-valid contract as the real source path
- Fix status:
  - state:
    open RTL/integration patch; simulation shim validated
  - mechanism:
    the temporary PROF-INT-002 harness shim force-drives a virtual MuTRiG headerinfo-valid pulse at a 910-cycle short-frame interval, phase-locked to the emulator `frame_start_req`, and programs the real `mutrig_injector_0` CSR delay/mode registers. The injector delay FSM and fanout path remain real RTL; the durable fix should make the direct emulator or Qsys integration produce an authored headerinfo-valid stream equivalent to the real MuTRiG/FDA path instead of relying on a hierarchical force.
  - before_fix_outcome:
    the existing header-sync phase scan bypassed `mutrig_injector_0` entirely by delaying in the testbench and forcing `emulator_mutrig_N.coe_inject_pulse`
  - after_fix_outcome:
    PROF-INT-002 RTL-injector ASIC0/two-channel phase sweep `prof_int_002_pre_rbcam_header_sync_rtlinj_phase[1-9]00` passed on `2026-05-06` with 256 pre-rbCAM rows per phase, aggregate 2304 rows, and DISLIN contract sheets under `tb_int/reports/prof_int_002_pre_rbcam_header_sync_rtlinj_phase_sweep_dislin/`. Analyzer medians were phase100=818.5, phase200=718.5, phase300=618.5, phase400=518.5, phase500=418.5, phase600=318.5, phase700=218.5, phase800=118.5, and phase900=928.5 cycles, matching the 910-cycle modulo-frame latency model. The later authored RTL patch must be revalidated with the same 100..900-cycle ASIC0/two-channel contract sheet.
  - potential_hazard:
    medium for emulator-source golden-reference work because a harness-generated headerinfo match can validate the injector delay FSM but cannot prove the final real-source/emulator-source headerinfo equivalence; low for real-MuTRiG runs where FDA headerinfo is naturally present

### BUG-008-R: unconnected `inject_aux_pulse` poisoned injector fanout

- First seen in:
  - PROF-INT-002 RTL-injector ASIC0/two-channel smoke on `2026-05-06`
  - command:
    `make -C firmware_builds/systems/system_20260504_emulator_type0/tb_int run_prof_int_002_pre_rbcam_latency PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE=header_sync PROF_INT_002_PRE_RBCAM_INJECT_DRIVER=rtl_injector PROF_INT_002_PRE_RBCAM_INJECT_PHASE_CYCLES=100 PROF_INT_002_PRE_RBCAM_INJECT_PULSE_COUNT=4`
- Symptom:
  - the real `mutrig_injector_0` was CSR-programmed and the virtual headerinfo shim emitted four headers, but `lane_hits=0`, `A=0`, and `PRE=0`
  - debug prints showed the generated fanout output and emulator injector input as `X`, while the injector raw pulse path was otherwise reachable
- Root cause:
  - `full8lane_type0_system.v` instantiates `data_path_subsystem` with `.inject_aux_pulse()` unconnected
  - `pulse_fanout8` computes `merged_inject_pulse = coe_inject_pulse | coe_aux_inject_pulse`, so the unconnected auxiliary conduit poisons the generated injector fanout in simulation
- Fix status:
  - state:
    open Qsys tie-off; harness force validated
  - mechanism:
    the PROF-INT-002 harness now forces `u_dut.data_path_subsystem.inject_aux_pulse = 1'b0` for the RTL-injector scan. The authored Qsys Tcl should tie the unused auxiliary injector conduit to ground, or expose and drive it explicitly, so generated simulation and synthesis do not depend on a hierarchical force.
  - before_fix_outcome:
    four virtual headers produced no Stage-A/pre-rbCAM rows and the analyzer failed with no valid latency rows
  - after_fix_outcome:
    focused rerun `prof_int_002_pre_rbcam_header_sync_rtlinj_phase100_diag4_tie_aux` produced 8 pre-rbCAM rows for four headers and two channels, with analyzer latency `min=818`, `p50=818.5`, `max=819` cycles. The full RTL-injector ASIC0/two-channel sweep then produced 256 rows per phase across phase100..phase900, confirming that the forced low auxiliary injector input restores deterministic fanout behavior for the simulation shim.
  - potential_hazard:
    medium until the Qsys tie-off is authored because any generated-system path using the injector fanout can inherit simulation `X` behavior from the unconnected auxiliary input; low for the temporary PROF-INT-002 shim after the explicit force

### BUG-009-H: full8/full32 header-sync burst sweep has ambiguous direct-emulator identity

- First seen in:
  - PROF-INT-002 full8/full32 pre-rbCAM header-sync burst sweep at phase 100 on `2026-05-06`
  - command family:
    `make -C firmware_builds/systems/system_20260504_emulator_type0/tb_int plot_prof_int_002_pre_rbcam_header_sync_full8ch_burst_sweep_phase100 PROF_INT_002_RUNCTL_CPP_GAP_CYCLES=1000 PROF_INT_002_RUNCTL_SETTLE_TIMEOUT_CYCLES=20000`
- Symptom:
  - burst1 requested 128 frames x 1 pulse/frame x 8 ASICs x 32 channels = 32768 Stage-A offers, but the run ended with `A=32768 PRE=6656 POST=1096 FEB=1634`
  - burst2 requested 65536 Stage-A offers and ended with `A=65536 PRE=5632 POST=774 FEB=1640`
  - the Stage-A -> pre-rbCAM ledger reported large residuals (`6656/26112/0` matched/missing/ghost for burst1 and `5632/59904/0` for burst2), while MTS input counters saw all offered hits
  - debug rows showed repeated pre-rbCAM payloads with an ASIC field of zero across multiple physical taps; attempted tap-based remapping can make a small smoke test look balanced but fabricates identity and produces negative latencies once drops or repeated buckets appear
- Root cause:
  - the current direct-emulator Stage-A monitor observes a source-internal boundary and assigns physical Qsys lane identity, while the downstream pre-rbCAM monitor sees hit_type1 payload identity after generated-system processing
  - in multi-active direct-emulator header-sync mode, the `(lane, channel, t_fine)` FIFO-ledger buckets are not unique enough to recover lineage after most Stage-A offers do not reach pre-rbCAM
  - this is a harness/source-model blocker for the all-active golden-reference sheet; it does not invalidate the single-active ASIC0 and ASIC1-7 phase-100 source checks, which keep one physical lane active and therefore avoid the multi-source alias
- Fix status:
  - state:
    open blocker; report target fails closed
  - mechanism:
    PROF-INT-002 now supports frame-counted header-sync burst injection with configurable burst multiplicity and 10-cycle pulse spacing, but `run_prof_int_002_pre_rbcam_header_sync_full8ch_burst_sweep_phase100` rejects each burst unless `pre_rbcam_records.csv` contains exactly `128 * burst_count * 8 * 32` rows. The multi-active pre-rbCAM monitor keeps using the on-wire payload lane instead of a tap-number substitute, so the harness does not hide the identity collapse.
  - before_fix_outcome:
    the sweep could continue into analysis/plotting even after burst1 and burst2 failed the expected pre-rbCAM row count by large margins
  - after_fix_outcome:
    the sweep is blocked before histogram analysis or DISLIN rendering whenever the observed pre-rbCAM row count is not exact; no full8/full32 header-sync burst plot is accepted as golden evidence yet
  - potential_hazard:
    high until a durable identity source is selected. Acceptable fixes include probing the actual generated hit_type0 source boundary with preserved ASIC identity, repairing the direct-emulator generated path so downstream payload identity matches the active source, or moving the golden reference to the real MuTRiG/LVDS/FDA path where headerinfo and source identity are naturally present.

### BUG-010-H: direct emulator evidence was being treated like virtual MuTRiG golden evidence

- First seen in:
  - PROF-INT-002 source comparison discussion on `2026-05-06`
  - rate-mode comparison between direct emulator, tagged virtual MuTRiG source model, and physical MuTRiG measurements
- Symptom:
  - direct-emulator rate-mode latency shapes matched the tagged virtual MuTRiG and real ASIC evidence well enough to be useful, but the reporting did not clearly distinguish the three source classes
  - all-active header-sync work then exposed that the direct emulator lacks a trustworthy per-hit source identity in the current generated-system observation path
- Root cause:
  - tb_int treated generated `emulator_mutrig` evidence and virtual MuTRiG source-code evidence as the same kind of MuTRiG reference
  - the direct emulator is an FPGA/on-board-test compromise, while the tagged virtual MuTRiG repository is the simulation golden source model and the real MuTRiG is the physical ASIC
  - DEBUG_LEVEL metadata was not yet a formal datapath/testbench contract, so the scoreboard had no authoritative OoO lineage channel for multi-source debug
- Fix status:
  - state:
    partial; source-model contract documented and IP DEBUG_LEVEL upgrade in progress
  - mechanism:
    `DV_PLAN.md` now records the three source evidence classes and the cumulative DEBUG_LEVEL contract: 0 is nominal synthesizable payload, 1 adds FIFO fill-level observability, and 2 adds per-hit debug metadata for simulation lineage while retaining the no-debug monitor path as a payload cross-check
  - before_fix_outcome:
    a generated-emulator plot could be interpreted as virtual-MuTRiG golden evidence even when the test path bypassed the real LVDS/FDA source boundary and did not preserve source identity under multi-active traffic
  - after_fix_outcome:
    pending regenerated DEBUG_LEVEL=2 tb_int runs using the tagged virtual MuTRiG and direct emulator as separately tagged sources, with rate-mode and header-sync four-panel contact sheets at pre-rbCAM
  - potential_hazard:
    medium until the DEBUG_LEVEL=2 metadata path and dual monitor scoreboard are compiled and rerun; low afterward if reports explicitly label source class and reject plots whose debug/no-debug counts disagree

### BUG-011-H: tagged MuTRiG frame generator bound to generated-system CRC

- First seen in:
  - PROF-INT-002 virtual MuTRiG header-sync smoke on `2026-05-06`
  - command:
    `make -C firmware_builds/systems/system_20260504_emulator_type0/tb_int run_prof_int_002_pre_rbcam_latency PROF_INT_002_SOURCE=virtual_mutrig PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE=header_sync PROF_INT_002_PRE_RBCAM_INJECT_FRAME_COUNT=16 PROF_INT_002_PRE_RBCAM_INJECT_BURST_COUNT=1`
- Symptom:
  - Questa failed before UVM runtime with `Bad default binding for component instance "u_crc16_8: crc16_8"`
  - the selected entity was `work_tb_int.crc16_8`, which lacks the tagged MuTRiG frame-generator port `o_crc_8`
- Root cause:
  - the tagged virtual MuTRiG VHDL was compiled into the same work library as the generated full8lane system
  - both source trees define a `crc16_8` design unit with incompatible interfaces, so VHDL default binding selected the wrong entity for `frame_generator.vhd`
- Fix status:
  - state:
    fixed in Makefile library isolation; PROF-INT-002 compile passed after the change
  - mechanism:
    the tagged virtual MuTRiG packages, FIFO dependency, frame generator, CRC, and `raw_mutrig_frame_top` now compile into a dedicated `mutrig_raw` library. PROF-INT-002 `vsim` commands add `-L mutrig_raw`, keeping the generated-system work library unchanged while letting the virtual MuTRiG source elaborate against its matching CRC entity.
  - before_fix_outcome:
    the virtual MuTRiG smoke failed during optimization and produced no Stage-A or pre-rbCAM records
  - after_fix_outcome:
    the next virtual MuTRiG smoke elaborated and ran; it logged `PROF_INT_002_SOURCE source=virtual_mutrig`, programmed the active arb lane to REAL mode, and produced 16 Stage-A hits matched to 16 pre-rbCAM hits
  - potential_hazard:
    low while the raw source remains isolated in `mutrig_raw`; medium if later code moves golden MuTRiG units back into the generated-system work library

### BUG-012-H: pre-rbCAM source validation enforced downstream SVA scope

- First seen in:
  - PROF-INT-002 virtual MuTRiG header-sync smoke on `2026-05-06`
  - first functional assertion failure:
    `post_rbcam_drop: Pre-RbCAM hit missed Post-RbCAM 3000-cycle window`
- Symptom:
  - the virtual MuTRiG source produced clean Stage-A -> pre-rbCAM evidence (`A->PRE matched/missing/ghost=16/0/0`) but the transcript accumulated post-rbCAM SVA `$error` messages
  - the run target was a pre-rbCAM source-validation case, so the downstream residuals were useful diagnostics but not part of the contract being measured
- Root cause:
  - `tb_int_assertions` always enabled the pre-rbCAM -> post-rbCAM and post-rbCAM -> FEB-egress guardrails
  - PROF-INT-002 had no runtime scope tag distinguishing pre-rbCAM source validation from a full pipeline latency run
- Fix status:
  - state:
    fixed in assertion scope control; virtual MuTRiG burst sweep passed
  - mechanism:
    `tb_int_assertions` now has explicit `enable_post_rbcam_checks` and `enable_feb_egress_checks` inputs. PROF-INT-002 accepts `TB_INT_LATENCY_SCOPE=full|pre_rbcam`; the pre-rbCAM make target passes `pre_rbcam`, leaving Stage-A -> pre-rbCAM checks active while disabling downstream SVA guardrails. The scoreboard still reports downstream residual counts separately.
  - before_fix_outcome:
    a pre-rbCAM-only source-validation smoke emitted 17 simulator errors while still producing a valid `pre_rbcam_records.csv` and analyzer row count
  - after_fix_outcome:
    `plot_prof_int_002_pre_rbcam_virtual_mutrig_header_sync_burst_sweep_phase100` passed with `TB_INT_LATENCY_SCOPE=pre_rbcam`. Burst counts `1, 2, 5, 7` produced exactly `128, 256, 640, 896` pre-rbCAM rows and Stage-A -> pre-rbCAM matched/missing/ghost counts of `128/0/0`, `256/0/0`, `640/0/0`, and `896/0/0`. The analyzer reported min/p05/p50/p95/max latencies of `837/837/837/837/837`, `830/830/833.5/837/837`, `811/811/824/837/837`, and `798/798/817/837/837` cycles. The post-rbCAM/FEB SVA errors were suppressed for this source-stage scope while the scoreboard continued to report downstream residuals as warnings.
  - residual_downstream_counts:
    burst1 reported `PRE->POST=64/64/0` and `POST->FEB=64/0/124`; burst2 reported `123/133/0` and `123/0/160`; burst5 reported `346/294/0` and `346/0/218`; burst7 reported `479/417/0` and `479/0/171`. These are not waived for full-pipeline closure; they are explicitly out of scope for the pre-rbCAM virtual-source contract.
  - potential_hazard:
    low for pre-rbCAM source-validation evidence because downstream residuals remain visible in the scoreboard; high for full-pipeline closure if any run uses `pre_rbcam` scope while claiming post-rbCAM or FEB-egress latency closure

### BUG-013-H: dual UVM sidecar lineage was not bound for all source modes

- First seen in:
  - PROF-INT-002 DEBUG_LEVEL=2 sidecar smoke on `2026-05-06`
  - scoreboard summary from `prof_int_002_debug_sidecar_smoke`: `debug_obs A/SRC/PRE/POST/FEB=6/322/322/322/262` with `debug_residuals SRC->PRE=0/322/322`
- Symptom:
  - the nominal FIFO-key path exported a valid pre-rbCAM latency CSV and the UVM run passed, but the sidecar ledger did not match source IDs into pre-rbCAM
  - `virtual_mutrig` left the new `debug_source` analysis path inactive, so the tagged virtual MuTRiG source path did not have the same dual analysis structure as the virtual MuTRiG smoke reference
  - stale generated full8lane simulation RTL could still use an older `arb_hit_type0` sidecar-valid contract even after the maintained RTL/Qsys Tcl had been fixed
- Root cause:
  - the initial tb_int scoreboard upgrade split nominal FIFO-key scoring from DEBUG_LEVEL=2 sidecar-ID scoring, but it only bound `debug_source` to the generated direct-emulator sidecar output
  - the virtual MuTRiG reference runs a debug-rich primary DUT and a no-debug shadow DUT from the same stimulus; tb_int needs the equivalent at the analysis boundary because it cannot instantiate a second generated Qsys DUT without changing the integration target
  - `arb_hit_type0` did not preserve a metadata-valid bit through its source FIFOs, so selected sidecar IDs could be asserted from stale or zero payloads when the generated system was not refreshed from the fixed IP source
- Fix status:
  - state:
    partial; dual UVM harness fixed, generated-system refresh pending
  - mechanism:
    `per_bucket_ledger_scoreboard` now has a separate `debug_source_imp` and reconciles `debug_source -> pre-rbCAM -> post-rbCAM -> FEB` by DEBUG_LEVEL=2 sidecar ID while keeping latency CSV export on the nominal FIFO-key model. PROF-INT-002 binds `debug_source` to direct-emulator hit metadata in `emu_direct` mode and to `mutrig_frame_deassembly_0` hit metadata in `virtual_mutrig` mode. `arb_hit_type0` v26.4.1 stores metadata-valid beside metadata payload in each source FIFO, and Qsys Tcl pins the fixed arb/sidecar bridge versions.
  - before_fix_outcome:
    a run could produce sensible pre-rbCAM plots while the sidecar path was inactive or reported complete `SRC->PRE` mismatch; this blocked using the scoreboard as an OoO model for multi-source drop localization
  - after_fix_outcome:
    `make -C firmware_builds/systems/system_20260504_emulator_type0/tb_int run_prof_int_002_pre_rbcam_latency PROF_INT_002_SOURCE=virtual_mutrig PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE=header_sync PROF_INT_002_PRE_RBCAM_INJECT_FRAME_COUNT=16 PROF_INT_002_PRE_RBCAM_INJECT_BURST_COUNT=1 PROF_INT_002_PRE_RBCAM_CASE=prof_int_002_pre_rbcam_virtual_mutrig_smoke` passed with `UVM_ERROR=0`, `UVM_FATAL=0`, and a 16-row pre-rbCAM delta latency at 837 cycles. The run confirmed the new source label and debug-source tap are active (`debug_obs SRC/PRE=16/16`) but still reported stale generated-system sidecar mismatch (`debug_residuals SRC->PRE=0/16/16`), so full DEBUG_LEVEL=2 OoO closure remains blocked on regenerating the generated full8lane simulation RTL from the fixed Qsys Tcl/IP versions.
  - potential_hazard:
    medium until the generated full8lane simulation RTL is regenerated from the fixed Qsys Tcl/IP versions. The source-tree fix is the required durable repair; generated `synthesis/` RTL remains evidence and must not be treated as authored source.

### BUG-014-R: debug sidecar bank bridge gated lineage on unconnected `endofrun`

- First seen in:
  - PROF-INT-002 virtual MuTRiG DEBUG_LEVEL=2 sidecar rerun on `2026-05-06`
  - command family:
    `make -C firmware_builds/systems/system_20260504_emulator_type0/tb_int run_prof_int_002_pre_rbcam_latency PROF_INT_002_SOURCE=virtual_mutrig PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE=periodic`
- Symptom:
  - before the bridge fix, the debug-source ledger saw source IDs but pre-rbCAM records carried local MTS fallback IDs, so `debug_residuals SRC->PRE` showed no useful source-ID closure
  - after Qsys regeneration, the generated full8lane wrapper still leaves `.asi_hit_type0_endofrun()` open on the bridge instance, proving this input cannot be part of the sidecar-valid contract in the current system
- Root cause:
  - `debug_hit_sidecar_bank_bridge` treated `asi_hit_type0_endofrun` as a required qualifier for `coe_hit_type0_sidecar_valid` and per-bank read accept
  - the upstream generated type0 mux stream has no matching end-of-run sideband, so the optional conduit is open in the generated full8lane system and suppresses or poisons sidecar metadata even while the hit payload handshake succeeds
- Fix status:
  - state:
    fixed in `misc/debug_hit_sidecar_bank_bridge` and regenerated full8lane DEBUG_LEVEL=2 simulation RTL; full downstream closure remains blocked by post-rbCAM/FEB residuals
  - mechanism:
    bridge v26.0.2 removes the optional end-of-run gate from sidecar-valid and sidecar FIFO read-accept, making metadata advance on the same hit payload valid/ready contract as the authored stream. `build_full8lane_system.tcl` pins `debug_hit_sidecar_bank_bridge_version` to `26.0.2.0506`, and `FULL8LANE_DEBUG_LEVEL=2 ./script/regen_full8lane_system.sh` refreshes the generated simulation RTL.
  - before_fix_outcome:
    virtual-MuTRiG periodic sidecar runs could not match source IDs into pre-rbCAM even though nominal pre-rbCAM payload records existed
  - after_fix_outcome:
    the 1 ms ASIC0/full32 10 kHz/channel virtual-MuTRiG checkpoint passed the pre-rbCAM strict scoreboard with `SRC->PRE=304/0/0`, `A->PRE=304/0/0`, `UVM_ERROR=0`, and a 304-row `pre_rbcam_records.csv`. The 100 kHz/channel checkpoint still reports `SRC->PRE=1048/2047/0`, which is now a real throughput/drain or configuration blocker rather than a sidecar-ID ghosting artifact.
  - potential_hazard:
    low for Stage-A -> pre-rbCAM lineage after regeneration; medium for full-pipeline closure because downstream post-rbCAM/FEB sidecar and datapath behavior still have residuals that must be fixed or locally explained before using those plots as signoff evidence

### BUG-015-H: DISLIN latency renderer dropped out-of-display stage records

- First seen in:
  - PROF-INT-002 post-rbCAM/FEB plot generation on `2026-05-06`
  - command:
    `python3 script/plot_tb_int_latency_dislin.py --sim-root sim --cases prof_int_002_pre_rbcam_periodic_asic0_full32_virtual_mutrig_010k_1ms --out-dir reports/prof_int_002_pipeline_periodic_asic0_full32_virtual_mutrig_010k_1ms_dislin`
- Symptom:
  - `closed_records.csv` had 105 scoreboard-closed rows for the 10 kHz/channel checkpoint, but the post-rbCAM and FEB-egress panels reported total zero because all stage latencies were above the fixed display ranges
  - this hid the actual blocker: the generated post-rbCAM/FEB timestamps were out of the DV_PLAN apertures instead of absent from the scoreboard export
- Root cause:
  - `plot_tb_int_latency_dislin.py` computed `Hist.total` from the sum of displayed bins after applying the stage `xlim`
  - rows outside the plot range were removed before the in-window/out-window accounting, so clipping changed the quantitative report
- Fix status:
  - state:
    fixed in plotting script; regenerated all-stage 10/100 kHz contact sheet exposes the post-rbCAM/FEB blocker
  - mechanism:
    the renderer now keeps raw row count, raw DV-window count, and below/above-display clipping counts separate from displayed bin count. The footer and `latency_summary.csv` report `display_count`, `below_xlim_count`, and `above_xlim_count` so empty panels remain quantitative evidence.
  - before_fix_outcome:
    post-rbCAM/FEB panels could be misread as no matched records, even though the scoreboard exported rows with out-of-aperture timestamps
  - after_fix_outcome:
    `reports/prof_int_002_pipeline_periodic_asic0_full32_virtual_mutrig_010k_100k_1ms_dislin/latency_summary.csv` reports, for 10 kHz/channel, post-rbCAM `total=105 display_count=0 above_xlim=105 out_window=105`, and for 100 kHz/channel, post-rbCAM `total=364 display_count=0 above_xlim=364 out_window=364`; FEB-egress has the same all-above-window signature. This is a visible blocker, not a plotting artifact.
  - potential_hazard:
    low after the renderer fix; any future per-stage plot with all hits outside the display aperture now reports raw out-of-window counts instead of silently dropping them

## 2026-05-07

### BUG-016-H: short run-control gap made rbCAM look like it rejected in-window hits

- First seen in:
  - PROF-INT-002 post-rbCAM ASIC0/channel0 100 kHz emulator debug on `2026-05-07`
  - command:
    `make -C firmware_builds/systems/system_20260504_emulator_type0/tb_int run_prof_int_002_pre_rbcam_latency PROF_INT_002_SOURCE=emu_direct PROF_INT_002_PRE_RBCAM_LATENCY_SCOPE=post_rbcam PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE=periodic PROF_INT_002_PRE_RBCAM_RUN_CYCLES=125000 PROF_INT_002_PRE_RBCAM_DRAIN_CYCLES=65536 PROF_INT_002_RUNCTL_CPP_GAP_CYCLES=1000 PROF_INT_002_HIT_RATE_Q16=52 PROF_INT_002_PRE_RBCAM_ACTIVE_LANE_COUNT=1 PROF_INT_002_PRE_RBCAM_ACTIVE_LANE_MASK=1 PROF_INT_002_PRE_RBCAM_CHANNEL_LOW=0 PROF_INT_002_PRE_RBCAM_CHANNEL_HIGH=0`
- Symptom:
  - the pre-rbCAM latency analyzer reported 98 rows with a fixed 17-cycle Stage-A to pre-rbCAM latency
  - scoreboard closure was `PRE->POST=47/52/0`, and `rb_hit=47` after drain
  - rbCAM ingress tracing showed all 99 unique pre hits asserted `split_accept`, `lane_match`, and `deassembly_wrreq`, proving the beats were not rejected at the rbCAM stream input
  - all `push_write_grant` events occurred during `TERMINATING`; during the entire RUNNING window the rbCAM pop engine trace sat in `FLUSHING`
- Root cause:
  - the debug command overrode the DV-plan software-scale run-control gap from 125000 cycles to 1000 cycles
  - readyless run-control broadcasts cannot be backpressured by rbCAM local ready, so RUNNING can be observed by the state register before the internal flush has completed if the testbench drives adjacent commands too quickly
  - hits that are within the 0..2000-cycle pre-rbCAM latency window are still blocked from the CAM/side-RAM write path while the rbCAM memory arbiter is granting the flush routine
- Fix status:
  - state:
    fixed in harness guard; post-rbCAM rerun passed
  - mechanism:
    recursive PROF-INT-002 sweep targets no longer force 1000-cycle run-control gaps, and the top-level PROF controller raises a UVM error if `full` or `post_rbcam` latency scope is run with `TB_INT_RUNCTL_CPP_GAP_CYCLES < 125000`
  - before_fix_outcome:
    the short-gap run reported `PRE->POST=47/52/0`, `stable_missing PRE->POST=51`, `rb_hit=47`, and push-write grant delays from about 4k to 127k cycles after pre-rbCAM acceptance
  - after_fix_outcome:
    rerun `prof_int_002_post_rbcam_periodic_asic0_ch0_emulator_100k_1ms_gap1ms_ingress_trace` observed the required 125000-cycle `RUN_PREPARE_to_SYNC`, `SYNC_to_RUNNING`, and `TERMINATING_to_IDLE` gaps. It passed with `UVM_ERROR=0`, `PRE->POST=99/0/0`, `rb_hit=99`, and rbCAM push-write grant delays of 2..39 cycles after pre-rbCAM acceptance.
  - potential_hazard:
    low for post-rbCAM/FEB PROF-INT-002 closure after the guard because any future sub-ms command-gap run now fails before being accepted as latency evidence; pre-rbCAM-only source checks may still intentionally use shorter gaps only if they do not claim downstream closure

### BUG-017-H: virtual MuTRiG periodic hits used hit count as timestamp

- First seen in:
  - PROF-INT-002 virtual MuTRiG post-rbCAM 10 kHz ASIC0/channel0 rate run on `2026-05-07`
  - case:
    `prof_int_002_post_rbcam_periodic_asic0_ch0_virtual_mutrig_010k_1ms_gap1ms_20260507`
- Symptom:
  - the Stage-A to pre-rbCAM transport latency was a fixed 17 cycles for all nine hits
  - the post-rbCAM scoreboard still reported `A=9 PRE=9 POST=7` and `PRE->POST=7/2/0`
  - `mts_latency_trace.csv` showed the two missing hits with timestamp delays `-2146` and `-3814` cycles, so rbCAM was filtering by timestamp-window interpretation rather than losing accepted stream beats
- Root cause:
  - the tb_int virtual MuTRiG periodic source built raw hit words with `virtual_mutrig0_source_hit_count[14:0]` as T coarse
  - this local count was not phase-locked to the generated MuTRiG timebase used by the rest of the integration system
  - legal low-rate stimulus could therefore reach pre-rbCAM with an in-window transport delay but an out-of-window hit timestamp
- Fix status:
  - state:
    fixed in harness; emulator and virtual MuTRiG post-rbCAM rate sweep passed
  - mechanism:
    `prof_int_002_full_pipeline_top.sv` now stamps virtual raw-hit words from `data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.tcc_lfsr`, keeping the virtual source timestamp on the same generated MuTRiG timebase as the integration run
  - before_fix_outcome:
    the virtual MuTRiG 10 kHz post-rbCAM run failed strict zero residual with `PRE->POST=7/2/0` and `UVM_ERROR=1`
  - after_fix_outcome:
    reruns `prof_int_002_post_rbcam_periodic_asic0_ch0_virtual_mutrig_{010k,100k,500k,1000k}_1ms_gap1ms_tccfix_20260507` all passed with `UVM_ERROR=0` and strict `PRE->POST` residuals of `9/0/0`, `99/0/0`, `497/0/0`, and `991/0/0`. The matching emulator runs at 10 kHz, 100 kHz, 500 kHz, and 1 MHz also passed with `PRE->POST=9/0/0`, `99/0/0`, `500/0/0`, and `1000/0/0`.
  - potential_hazard:
    low for the current ASIC0/channel0 periodic post-rbCAM validation; medium for future virtual-source upgrades unless the tagged virtual MuTRiG source exposes an authored timestamp anchor instead of relying on a hierarchical generated-emulator timebase tap

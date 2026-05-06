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

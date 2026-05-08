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
| [BUG-018-R](#bug-018-r-sv-rbcam-deassembly-fifo-depth-did-not-match-vhdl-scfifo_w40d256) | R | hard stuck error | `occasional (1 MHz/channel full32 post-rbCAM stress)` | fixed in SV source; full rate sweep passed | PROF-INT-002 newest-SV 1 MHz post-rbCAM run on `2026-05-08` | pending | SV rbCAM deassembly FIFO depth was 64 while the VHDL reference uses `scfifo_w40d256`, letting generated fanout drop two owning-copy hits when one rbCAM instance backpressured. |
| [BUG-019-R](#bug-019-r-feb-scifi-hit_type3-contract-mismatch-at-swb-opq-corun) | R | hard stuck error | `common (FEB SciFi hit_type3 through SWB OPQ merge)` | partial; direct corun passed | FEB/SWB corun architecture audit and `run_swb_corun` on `2026-05-08` | 833b204c/e7f29d8 | FEB/SWB corun exposed a protocol assumption on subheader hit-count width and a MuSiP OPQ egress header rewrite that could make SciFi/MuTRiG traffic parse or pack under the wrong detector contract. |
| [BUG-020-R](#bug-020-r-swb-scifi-dma-timestamp-packing-dropped-the-odd-frame-bit) | R | hard stuck error | `common (FEB SciFi hits in odd 2048-tick frame buckets)` | fixed in MuSiP; trace checker committed | FEB/SWB trace debug on `2026-05-08` | f1344f2b/39947ff | Trace-level FEB/SWB corun showed hits reached DMA in the right count but several odd-frame hits carried the wrong absolute timestamp because MuSiP packed SciFi time using the old 256-subheader layout. |
| [BUG-021-H](#bug-021-h-feb-swb-corun-emitted-future-timestamped-hits-before-hit-timebase) | H | soft error | `directed-only (FEB/SWB lifetime plotting)` | fixed in harness; lifetime rerun passed | FEB/SWB lifetime plot on `2026-05-08` | 90f6c58c | The corun packet writer serialized future timestamped hits at line rate before their MuTRiG hit timestamp, so lifetime plots showed negative FEB-egress and OPQ-ingress delays even though payload matching passed. |
| [BUG-022-R](#bug-022-r-swb-opq-native-lane-credit-drops-under-feb-all-channel-100khz-corun) | R | hard stuck error | `common (one FEB, lane0 all-channel 100 kHz, lane1 empty legal frames)` | fixed for scoped no-bottleneck corun; 1024-depth overload retained as diagnostic | FEB/SWB all-channel 1 ms corun on `2026-05-08` | 8a353a0/6359a10/90f6c58c | Native OPQ stayed at the 1024-entry lane FIFO default because wrapper depth macros were not passed into the monolithic core; the scoped 8192-depth lossless run now delivers all 3200 hits with zero OPQ drop counters. |
| [BUG-023-H](#bug-023-h-feb-swb-lifetime-plot-used-local-source-marker-for-rbcam-panels) | H | soft error | `directed-only (FEB/SWB lifetime plotting and review)` | fixed in analyzer/plotter; rerender passed | FEB/SWB lifetime plot review on `2026-05-08` | 7c748870 | The corun lifetime plot treated synthetic pre/post-rbCAM source markers as true rbCAM lifetime evidence and described lifetime as local source-marker time instead of the carried hit GTS/debug timestamp contract. |
| [BUG-024-H](#bug-024-h-feb-swb-rbcam-plot-imported-lossy-reference-as-no-drop-evidence) | H | hard stuck error | `directed-only (FEB/SWB rbCAM reference plotting and review)` | fixed in analyzer reference guard; rerender passed | FEB/SWB far pre-rbCAM peak trace debug on `2026-05-08` | 8378d7d6 | The rbCAM top-panel plot imported a drop-containing pre-rbCAM reference run and had no health gate, so a stale 84k-cycle peak was shown as if it were no-drop rbCAM evidence. |
| [BUG-025-R](#bug-025-r-swb-direct-dma-packer-dropped-eop-partial-hit-groups) | R | hard stuck error | `occasional (legal FEB frames whose hit count is not divisible by four)` | fixed in MuSiP direct packer; periodic and Poisson all-ASIC reruns passed | FEB/SWB Poisson all-ASIC 1 ms corun on `2026-05-08` | 9d1c7c5/f478c95a | The SWB direct 64-to-256 DMA packer did not safely flush partial EOP groups, so legal frames with `frame_hits mod 4 = 1` could lose the final hit group before DMA. |
| [BUG-026-H](#bug-026-h-feb-swb-pre-rbcam-panel-used-post-mutrig-transport-as-golden-lifetime) | H | soft error | `directed-only (FEB/SWB lifetime plotting review)` | fixed in analyzer virtual-MuTRiG model; periodic and Poisson plots overwritten | FEB/SWB lifetime plot review on `2026-05-09` | e2cca629 | The pre-rbCAM panel used the clean full-FEB 17-cycle post-MuTRiG transport marker as the lifetime shape, so the plot collapsed instead of showing the virtual-MuTRiG short-frame wait and serializer profile. |

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

## 2026-05-08

### BUG-018-R: SV rbCAM deassembly FIFO depth did not match VHDL `scfifo_w40d256`

- First seen in:
  - PROF-INT-002 newest-SV post-rbCAM ASIC0/full32 1 MHz/channel run on `2026-05-08`
  - case:
    `prof_int_002_post_rbcam_periodic_asic0_full32_emu_direct_1000k_1ms_gap1ms_20260507`
- Symptom:
  - the fixed DEBUG-rich monitors showed `A=32032`, `PRE=128126`, `POST=32030`, and `FEB=32030`
  - payload residuals and DEBUG residuals both localized the loss to `PRE->POST=32030/2/0`
  - the two missing hits were channels 30 and 31 at the same T-coarse key; non-owning fanout copies observed them, but the owning rbCAM copy had `split_ready=0`, `deassembly_full=1`, and no `deassembly_wrreq`
- Root cause:
  - the SV rbCAM core used `DEASM_DEPTH_CONST=64`
  - the VHDL reference path instantiates `scfifo_w40d256`, and the generated Qsys fanout cannot make all rbCAM branch accepts atomic when one owning copy deasserts ready
  - at the 1 MHz/channel full32 stress point, the 64-word SV deassembly FIFO could become full while the VHDL-depth reference still has enough elasticity
- Fix status:
  - state:
    fixed in SV source and validated in tb_int; standalone synthesis/resource closure still tracked separately
  - mechanism:
    `ring_buffer_cam_core.sv` now sets `DEASM_DEPTH_CONST=256`, matching the VHDL `scfifo_w40d256` ingress buffer depth. The tb_int fill trace now samples `resident_fill_level` directly, and the deassembly FIFO plot metadata records the 256-word depth.
  - before_fix_outcome:
    the 1 MHz/channel run reported `PRE->POST=32030/2/0`, `debug_residuals PRE->POST=32030/2/0`, and one UVM warning from post-termination residual reporting
  - after_fix_outcome:
    the refreshed four-rate newest-SV DEBUG2 sweep passed at `010k`, `100k`, `500k`, and `1000k` with zero payload residuals and zero DEBUG residuals. Counts were `A/POST/FEB=288/288/288`, `3168/3168/3168`, `16000/16000/16000`, and `32032/32032/32032`. The total closed hit count was `51,488/51,488`, all four `drops.csv` files had header-only row count, and the 1 MHz deassembly FIFO peak was `66/256` with zero full samples.
  - potential_hazard:
    low for the current tb_int post-rbCAM emulator profile because the stress sweep and 15-hit trace sanity check passed. Resource/timing impact of the deeper SV FIFO must remain visible in the standalone Quartus resource comparison because the FIFO-depth parity change is intentional and may affect memory inference.

### BUG-019-R: FEB SciFi hit_type3 contract mismatch at SWB OPQ corun

- First seen in:
  - FEB/SWB corun architecture audit on `2026-05-08`
  - direct corun `make run_swb_corun QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim` from `tb_int/feb_swb_corun`
- Symptom:
  - native-SV OPQ decodes the FEB subheader hit count as `[23:8]`, while the FEB SciFi hit_type3 frame contract only owns `[15:8]`
  - before the MuSiP fix, FEB ingress produced SciFi preambles such as `0xe00000bc`, but OPQ egress returned `0xe80000bc`, causing downstream DMA packing to treat MuTRiG/SciFi hits as MuPix-shaped hits
- Root cause:
  - the cross-repo stream contract was not explicit enough at the OPQ boundary: the current corun must keep subheader `[23:16]` zero until FEB and OPQ agree on the hit-count field width
  - MuSiP `ingress_egress_adaptor.vhd` also forced every OPQ egress K28.5 preamble to `MUPIX_HEADER_ID` instead of preserving the detector id
- Fix status:
  - state:
    partial; the direct low-rate contract corun passes, and the MuSiP header rewrite is fixed, but the subheader hit-count width still needs an explicit protocol alignment or assertion on real FEB egress
  - mechanism:
    `feb_swb_corun_plain_tb.sv` drives FEB-style 128-subheader frames on lanes 0 and 1, masks lanes 2 and 3, normalizes subheader `[23:16]` to zero, and scoreboards ASIC0/channel0 100 kHz hits through OPQ/DMA. MuSiP commit `e7f29d8` preserves known detector headers on OPQ egress.
  - before_fix_outcome:
    the first direct corun showed SciFi ingress rewritten to MuPix at OPQ egress and reported DMA missing/ghost hits
  - after_fix_outcome:
    the direct corun passes with `FEB_SWB_CORUN_PLAIN_PASS expected_hits=12 dma_payload_words=3 opq_beats=66`; summary reports `expected_hits=12`, `actual_hits=12`, `missing_hits=0`, `ghost_hits=0`, `end_of_event_count=1`, `fifo_overflow=0x0`, and `fifo_underflow=0x0`
  - potential_hazard:
    medium until a real FEB egress trace or an RTL assertion proves subheader `[23:16]` is always zero, or the FEB/OPQ protocol is updated so both sides document the same hit-count width
- Runtime / coverage context:
  - active SWB mask is `0x3`, with lanes 0 and 1 driven and lanes 2 and 3 idle/masked
  - lane 0 carries virtual MuTRiG ASIC0/channel0 hits at 100 kHz; lane 1 emits legal empty FEB frames
  - generated reports live under `tb_int/feb_swb_corun/report/` and are intentionally ignored by git
- Commit:
  - FEB direct corun: `833b204c`
  - MuSiP header fix: `e7f29d8`

### BUG-020-R: SWB SciFi DMA timestamp packing dropped the odd-frame bit

- First seen in:
  - FEB/SWB trace-level corun `make run_swb_corun QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim` from `tb_int/feb_swb_corun` on `2026-05-08`
  - first analyzer result before the MuSiP fix: `TRACE_DEBUG_FAIL hits=12 pass_hits=7 issues=5`
- Symptom:
  - the direct corun could drive the correct number of virtual MuTRiG ASIC0/channel0 hits through OPQ and DMA, but DMA timestamps for hit ids `2`, `3`, `5`, `6`, and `9` landed in the wrong absolute frame bucket
  - the failure was specifically visible on odd 2048-tick FEB frame bases; hit id `2` belonged to frame `1`, subheader `28`, bucket `2496..2511`, and absolute timestamp `2500`
- Root cause:
  - MuSiP `musip_mux_4_1.vhd` still packed SciFi/TILE DMA time as `ts_high[22:0]`, `ts_low[15:12]`, `subheader[7:0]`, and the hit timestamp nibble
  - the promoted FEB/SWB OPQ contract uses `N_SHD=128`, so the correct split is `ts_low[15:11]` plus `subheader[6:0]`; the old split dropped `ts_low[11]` and aliased odd 2048-tick frame bases
- Fix status:
  - state:
    fixed in MuSiP commit `39947ff`; FEB trace checker committed in `f1344f2b`
  - mechanism:
    MuSiP now packs and models SciFi/TILE DMA timestamps with the 128-subheader split, and the FEB corun now runs `scripts/analyze_feb_swb_trace.py` after the pass banner to verify per-hit lane, ASIC, channel, hit id, debug metadata, OPQ frame bucket, and DMA absolute timestamp
  - before_fix_outcome:
    trace-level analyzer reported five DMA absolute timestamp failures while hit count reached the expected 12
  - after_fix_outcome:
    `TRACE_DEBUG_PASS hits=12 channel=0 asic=0`; summary reports `expected_ingress_hits=12`, `opq_hits=12`, `dma_hits=12`, `pass_hits=12`, `fail_hits=0`, `ghost_opq_hits=0`, `ghost_dma_hits=0`, and `issue_count=0`
  - potential_hazard:
    low for the promoted `N_SHD=128` FEB/SWB profile; any future 256-subheader OPQ variant must be verified as a separate frame-format profile instead of sharing this packer expectation
- Runtime / coverage context:
  - active SWB mask is `0x3`, with lanes 0 and 1 driven and lanes 2 and 3 idle/masked
  - lane 0 carries virtual MuTRiG ASIC0/channel0 hits at 100 kHz; lane 1 emits legal empty FEB frames
  - reports live under `tb_int/feb_swb_corun/report/` and are intentionally ignored by git; the persistent evidence is the analyzer script plus the committed run command and summaries above
  - MuSiP bypass discriminator `make -C tb_int/cases/basic/plain run-smoke QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim USE_MERGE=0` passes, while the plain `USE_MERGE=1` smoke still observes zero payload words; the focused FEB/SWB OPQ corun remains the passing contract test for this bug
- Commit:
  - FEB trace checker: `f1344f2b`
  - MuSiP timestamp fix: `39947ff`

### BUG-021-H: FEB/SWB corun emitted future timestamped hits before hit timebase

- First seen in:
  - FEB/SWB lifetime plot rerun on `2026-05-08`
  - command:
    `make run_swb_corun QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim` from `tb_int/feb_swb_corun`
- Symptom:
  - payload and DEBUG trace matching still passed with `TRACE_DEBUG_PASS hits=384 channels=0..31 asic=0`
  - lifetime-at-checkpoint plotting reported negative FEB-egress and OPQ-ingress lifetimes, with FEB egress spanning `-1503.500..83.500` 8 ns cycles before the fix
  - the first sample at `hit_ts=0` was positive, but the next 100 kHz sample at `hit_ts=1250` cycles egressed around simulation cycle 241, proving the TB emitted a future timestamped hit before its source bucket time
- Root cause:
  - `feb_swb_corun_plain_tb.sv` serialized each FEB frame at line rate and then waited for the next frame boundary
  - this kept frame start spacing legal but allowed sparse non-empty subheaders inside a frame to be transmitted before the corresponding MuTRiG hit timestamp
  - the old transport-delay plot hid this because it only measured differences between downstream checkpoints
- Fix status:
  - state:
    fixed in harness; post-fix lifetime rerun passed
  - mechanism:
    the FEB lane driver now preserves the source hit timestamp as the generation-time reference used by the lifetime analyzer and emits the FEB frame after a two-frame store-forward delay, so sparse in-frame hits cannot egress before their MuTRiG birth time
  - before_fix_outcome:
    `feb_swb_lifetime_hist_stats.csv` showed negative source-relative lifetimes for FEB egress and OPQ ingress while the payload scoreboard still passed
  - after_fix_outcome:
    rerun `make run_swb_corun QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim OPQ_SOURCE_MODE=native_sv_signoff RUN_WINDOW_8NS=125000 HIT_PERIOD_8NS=1250` passed with `FEB_SWB_CORUN_PLAIN_PASS expected_hits=3200 dma_payload_words=800 opq_beats=3666`, `TRACE_DEBUG_PASS hits=3200 channels=0..31 asic=0`, and `LIFETIME_DISLIN_PASS`. The lifetime stats are non-negative and source-relative: FEB egress `2386.500..4172.500` cycles, OPQ ingress `2387.750..4173.750` cycles, OPQ egress `5596.750..95154.750` cycles, and DMA `5601.750..95158.250` cycles.
  - potential_hazard:
    low after rerun because the fix changes only the stimulus frame schedule; it does not relax the OPQ/DMA payload, bucket, or DEBUG metadata checks
- Commit:
  - FEB corun harness/analyzer: `90f6c58c`

### BUG-022-R: SWB OPQ native lane-credit drops under FEB all-channel 100 kHz corun

- First seen in:
  - FEB/SWB all-channel corun on `2026-05-08`
  - command:
    `make clean && make run_swb_corun QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim OPQ_SOURCE_MODE=native_sv_signoff OPQ_TICKET_FIFO_DEPTH=4096 RUN_WINDOW_8NS=125000 HIT_PERIOD_8NS=1250`
- Symptom:
  - the direct corun generated 3200 virtual MuTRiG ASIC0 hits, and all 3200 reached source, synthetic pre/post-rbCAM, FEB egress, and OPQ ingress checkpoints
  - OPQ egress and DMA delivered only 2816 hits; missing hits were 12 complete timestamp samples of 32 channels each
  - `report/feb_swb_range_validation.csv` passes every checkpoint range, so the plot-scale issue was not a small-stage timing bug
- Root cause:
  - the first all-channel no-loss attempt raised `OPQ_TICKET_FIFO_DEPTH` to 4096 but left the effective lane FIFO at the native default because `ordered_priority_queue_dut_sv` defined `OPQ_LANE_FIFO_DEPTH` and `OPQ_HANDLE_FIFO_DEPTH` locally without passing them into `ordered_priority_queue_monolithic_sv`
  - OPQ native frame service is slower than FEB frame ingress for this finite two-lane FEB profile: `mean ingress_iat=2047.885` cycles, `mean service_iat=3547.705` cycles, `rho=1.732` in the original 1024-depth diagnostic profile
  - `report/feb_swb_opq_queue_model.csv` matches the measured OPQ frame wait with zero recurrence residual and shows the wait growing from `2727.5` to `94216.5` 8 ns cycles
  - native OPQ controlled counters localize the loss to lane0 lane-credit drops: `credit_lane_drop_shd=12`, `credit_lane_drop_hit=384`; ticket, mask, handle, and frame-table drops are all zero
- Fix status:
  - state:
    fixed for the scoped finite-burst no-bottleneck corun; the 1024-depth overload remains a diagnostic profile, not the maintained contract run
  - mechanism:
    the OPQ native SV wrappers now pass `LANE_FIFO_DEPTH`, `HANDLE_FIFO_DEPTH`, and `DEBUG_LV` into the monolithic core, `opq_sources.mk` provisions the corun with 8192-entry lane and ticket FIFOs and `OPQ_DEBUG_LEVEL=2`, and the analyzer treats any nonzero OPQ drop counter as a hard failure under the scoped no-bottleneck assumption. The analyzer also writes source-relative lifetime stats, `feb_swb_range_validation.csv`, `feb_swb_tunnel_scoreboard.csv`, `feb_swb_factual_scoreboard.csv`, and `feb_swb_opq_queue_model.csv`; DISLIN renders both lifetime and OPQ queue plots.
  - before_fix_outcome:
    the all-channel plot made OPQ egress look nonsensical because small fixed checkpoints and a growing OPQ queue were shown as one unmodeled lifetime distribution
  - after_fix_outcome:
    latest scoped run reports `pass_hits=3200`, `fail_hits=0`, `opq_drop_counter_total=0`, `range_validation_failures=0`, `tunnel_scoreboard_failures=0`, `debug_pass=3200`, `factual_pass=3200`, and `opq_queue_model_residual_max_abs_cycles=0.000`. OPQ remains a finite-burst queued stage with `opq_utilization_mean=1.726`, `opq_queue_wait_min_cycles=2727.500`, and `opq_queue_wait_max_cycles=91906.500`, but no hit is lost before DMA.
  - potential_hazard:
    medium: the scoped corun proves a finite 1 ms, 100 kHz/channel burst with enough OPQ buffering and drain time; it is not an infinite steady-state throughput proof because the measured service interval remains longer than the ingress frame interval. Reusing a 1024-entry lane FIFO or disallowing post-run drain must be treated as a separate controlled-overload profile.
- Runtime / coverage context:
  - one FEB is modeled with lanes 0 and 1 enabled; lanes 2 and 3 are masked
  - lane 0 carries ASIC0 channels 0..31 at 100 kHz/channel for 1 ms; lane 1 emits legal empty FEB frames
  - source/pre/post/FEB/OPQ-ingress/OPQ-egress/DMA counts are all 3200 hits in the scoped run
  - generated evidence lives under `tb_int/feb_swb_corun/report/` and is regenerated by the corun target
- Commit:
  - packet_scheduler OPQ depth/debug fix: `8a353a0`
  - parent `mu3e-ip-cores` submodule bump: `25f51b2`
  - MuSiP OPQ corun configuration: `6359a10`
  - FEB corun harness/analyzer: `90f6c58c`

### BUG-023-H: FEB/SWB lifetime plot used local source marker for rbCAM panels

- First seen in:
  - FEB/SWB lifetime plot review on `2026-05-08`
  - user comparison against the full-FEB pre-rbCAM direct and post-rbCAM DEBUG timestamp-age plots
- Symptom:
  - the top two panels in `feb_swb_lifetime_hist.png` collapsed at zero cycles, unlike the full-FEB pre/post rbCAM reference distributions
  - the plot subtitle defined lifetime as `checkpoint_time - virtual_mutrig_generation_time`, which is weaker than the actual hit contract because the source marker is a local TB observation
- Root cause:
  - `scripts/analyze_feb_swb_trace.py` subtracted the source trace row time when calculating lifetime columns
  - `feb_swb_corun_plain_tb.sv` writes pre/post rbCAM rows as synthetic lineage markers because the direct corun bypasses the real rbCAM; treating those rows as true rbCAM latency evidence made the plot look valid while proving the wrong thing
- Fix status:
  - state:
    fixed in analyzer/plotter; rerender passed
  - mechanism:
    the analyzer now defines lifetime origin as the carried hit GTS reconstructed from the FEB frame bucket, DMA timestamp, MuTRiG lower timestamp bits, and DEBUG `ps/ts/hit_id` tags.  The DISLIN lifetime renderer imports the full-FEB 100 kHz/channel ASIC0 full32 pre/post rbCAM reference traces for the top two panels, keeps every panel on one shared x-axis, and marks per-checkpoint bounds with green lines.
  - before_fix_outcome:
    pre/post rbCAM appeared as exact zero-lifetime populations even though the reference pre-rbCAM distribution is mostly outside `[0,2000]` cycles and the post-rbCAM DEBUG age is tightly inside `[2000,2200)` cycles
  - after_fix_outcome:
    rerun analyzer reports `TRACE_DEBUG_PASS hits=3200 channels=0..31 asic=0`, `rbcam_reference_issue_count=0`, pre-rbCAM reference `count=13728`, `min/p50/p95/max=73/84930/85373/85415` cycles, and post-rbCAM reference `count=3136`, `min/p50/max=2001/2070/2139` cycles.  DISLIN rerender reports zero warnings for `report/feb_swb_lifetime_hist.png` and `report/feb_swb_lifetime_hist.pdf`.
  - potential_hazard:
    low for datapath behavior because the bug is reporting-only; medium for review evidence because an incorrect lifetime origin can hide a missing DEBUG timestamp propagation contract
- Runtime / coverage context:
  - the corun still uses lane0 ASIC0 channels 0..31 at 100 kHz/channel for 1 ms and lane1 legal empty FEB frames
  - source, FEB egress, OPQ ingress, OPQ egress, and DMA factual scoreboards remain the datapath conservation proof; the imported rbCAM panels are reference evidence for the full FEB path that the direct corun does not instantiate
- Commit:
  - analyzer/plotter/reporting fix: `7c748870`

### BUG-024-H: FEB/SWB rbCAM plot imported lossy reference as no-drop evidence

- First seen in:
  - FEB/SWB far pre-rbCAM peak trace debug on `2026-05-08`
  - user review of `tb_int/feb_swb_corun/report/feb_swb_lifetime_hist.png`
- Symptom:
  - the direct FEB/SWB corun itself was lossless with `source_generation_hits=3200`, `expected_feb_hits=3200`, `opq_ingress_hits=3200`, `opq_egress_hits=3200`, `dma_hits=3200`, `opq_drop_counter_total=0`, and `issue_count=0`
  - the imported pre-rbCAM reference panel still showed a far peak around 84k cycles, with `count=13728`, `min/p50/p95/max=73/84930/85373/85415` cycles, and only 1088 hits inside `[0,2000]`
  - the old reference transcript showed actual residual loss: `A=15872 PRE=13728 POST=13041 FEB=10921`, with `A->PRE missing=2144`, `PRE->POST missing=687`, and `POST->FEB missing=2134`
  - the old reference `drops.csv` had 4965 rows, so the plotted tail was not valid no-drop evidence
- Root cause:
  - `scripts/analyze_feb_swb_trace.py` imported `prof_int_002_pre_rbcam_periodic_asic0_full32_100k` as the pre-rbCAM reference without checking whether that run conserved hits
  - the analyzer also used a separate post-rbCAM reference case, so the two top panels did not necessarily share one clean full-FEB run-control and drain contract
  - there was no hard gate on reference `drops.csv`, `counter_agreement.csv`, transcript `UVM_ERROR`, or missing/ghost residuals before emitting `feb_swb_rbcam_reference_trace.csv`
- Fix status:
  - state:
    fixed in analyzer reference guard; rerender passed
  - mechanism:
    the analyzer now imports both top panels from the clean `feb_egress_queueing_20260508/prof_int_002_feb_egress_periodic_asic0_full32_emu_direct_100k_1ms_gap1ms_20260508` case.  It validates that `drops.csv` is empty, all counter-agreement rows have `available=1` and `agree=1`, the transcript reports `UVM_ERROR=0`, and every reported missing/ghost residual is zero.  These reference-health issues now extend the analyzer failure list and are written to `feb_swb_rbcam_reference_health.csv`.
  - before_fix_outcome:
    a lossy reference with thousands of missing hits could be plotted with `rbcam_reference_issue_count=0`, making the pre-rbCAM tail look like a mathematical latency result instead of a stale run-control/drop artifact
  - after_fix_outcome:
    rerun `python3 scripts/analyze_feb_swb_trace.py --trace-dir report --expected-hit-period-8ns 1250 --opq-log report/run_swb_corun.log --assume-opq-lossless` passes with `TRACE_DEBUG_PASS hits=3200 channels=0..31 asic=0`, `rbcam_reference_issue_count=0`, and `rbcam_reference_health_issue_count=0`.  The accepted rbCAM reference reports pre-rbCAM `count=3136`, `min/p50/p95/max=17/17/17/17` cycles and post-rbCAM `count=3136`, `min/p50/p95/max=2001/2070/2128/2139` cycles.  DISLIN rerender passes with zero warnings for the PNG/PDF lifetime and OPQ queue plots.
  - potential_hazard:
    low after this guard because a future stale or lossy rbCAM reference will fail the analyzer instead of silently producing review evidence; the direct corun still uses synthetic pre/post markers and must not be treated as a real rbCAM implementation
- Runtime / coverage context:
  - one FEB is modeled with lanes 0 and 1 enabled; lanes 2 and 3 are masked
  - lane 0 carries ASIC0 channels 0..31 at 100 kHz/channel for 1 ms; lane 1 emits legal empty FEB frames
  - source/pre/post/FEB/OPQ-ingress/OPQ-egress/DMA counts are all 3200 hits in the maintained direct corun
- Commit:
  - analyzer/reference guard fix: `8378d7d6`

### BUG-025-R: SWB direct DMA packer dropped EOP partial hit groups

- First seen in:
  - FEB/SWB Poisson iid all-ASIC corun on `2026-05-08`
  - command:
    `make run_swb_corun_poisson QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim OPQ_SOURCE_MODE=native_sv_signoff OPQ_LANE_FIFO_DEPTH=65536 OPQ_TICKET_FIFO_DEPTH=65536 ASIC_COUNT=8 RUN_WINDOW_8NS=125000 HIT_PERIOD_8NS=1250 POISSON_SEED=20260508`
- Symptom:
  - Poisson mode generated 25629 legal virtual MuTRiG hits across ASIC0..7 channels 0..31
  - native OPQ reported `ft_wr_hit=25629`, `ft_rd_hit=25629`, and all OPQ drop counters at zero
  - before the final MuSiP fix, DMA missed exactly the final partial hit group of frames whose hit count left a one-hit EOP remainder after 4-hit packing
  - the expected DMA payload word count is per-frame `sum(ceil(frame_hits / 4))`; for the accepted Poisson seed this is 6431 words, not `ceil(total_hits / 4)` as one global packet
- Root cause:
  - MuSiP `musip_mux_4_1.vhd` direct mode packs four 64-bit SciFi/TILE hit words into one 256-bit DMA word
  - the original packer emitted only complete 4-hit groups and did not flush a zero-filled partial 256-bit word at EOP
  - the first repair flushed the partial group in the same cycle class as a preceding full word for `4N+1` frames
  - downstream `mux_4_1_256` has a one-entry valid buffer per lane and assumes no back-to-back valid beats from one lane, so the partial EOP beat could be overwritten
- Fix status:
  - state:
    fixed in MuSiP direct packer and validated in the FEB/SWB direct corun; broader SWB regression still pending
  - mechanism:
    `musip_mux_4_1.vhd` now records a `flush_256_pending` bit per link, zero-fills unused 64-bit slots at EOP, and emits the partial 256-bit word one cycle later.  The FEB/SWB harness now computes expected DMA words as a sum over frames so partial words are required by the scoreboard instead of hidden by total-hit rounding.
  - before_fix_outcome:
    the Poisson all-ASIC run had OPQ conservation but DMA under-counted legal partial frames; the missing groups localized to frames with `frame_hits mod 4 = 1`
  - after_fix_outcome:
    periodic rerun passes with `expected_hits=25600`, `expected_dma_words=6400`, `dma_payload_words=6400`, `actual_hits=25600`, `missing_hits=0`, `ghost_hits=0`, and `TRACE_DEBUG_PASS hits=25600 channels=0..31 asics=0..7`. Poisson rerun with seed `20260508` passes with `expected_hits=25629`, `expected_dma_words=6431`, `dma_payload_words=6431`, `actual_hits=25629`, `missing_hits=0`, `ghost_hits=0`, and `TRACE_DEBUG_PASS hits=25629 channels=0..31 asics=0..7`. Both runs report zero OPQ controlled drops and `LIFETIME_DISLIN_PASS`.
  - potential_hazard:
    medium until a broader MuSiP regression covers every direct-mode detector contract; low for this FEB/SWB finite-burst corun because periodic and Poisson all-ASIC runs now prove OPQ and DMA conservation with partial frames enabled
- Runtime / coverage context:
  - one FEB is modeled with lanes 0 and 1 enabled; lanes 2 and 3 are masked
  - lane 0 carries ASIC0..7 channels 0..31 at 100 kHz/channel for 1 ms; lane 1 emits legal empty FEB frames
  - periodic plot lives under `tb_int/feb_swb_corun/report/feb_swb_lifetime_hist.png`
  - Poisson comparison plot lives under `tb_int/feb_swb_corun/report_poisson/feb_swb_lifetime_hist.png`
- Commit:
  - MuSiP direct packer fix: 9d1c7c5
  - FEB/SWB all-ASIC Poisson harness and docs: f478c95a

## 2026-05-09

### BUG-026-H: FEB/SWB pre-rbCAM panel used post-MuTRiG transport as golden lifetime

- First seen in:
  - FEB/SWB lifetime plot review on `2026-05-09`
  - user comparison against the MuTRiG Digital RTL LVDS latency contact sheet
- Symptom:
  - the maintained periodic and Poisson FEB/SWB coruns both conserved all hits through DMA, but the pre-rbCAM lifetime panel was a delta-like 17-cycle spike
  - the panel therefore disagreed with the virtual MuTRiG golden model, where source-to-pre-rbCAM lifetime includes short-frame wait plus the per-frame serializer slot before the fixed pre-rbCAM transport
- Root cause:
  - `scripts/analyze_feb_swb_trace.py` reused the clean full-FEB rbCAM pre-rbCAM reference for the top panel
  - that reference measures only the local decoded-ingress to pre-rbCAM transport after MuTRiG frame generation/deassembly has already occurred
  - the plot consequently dropped the virtual MuTRiG lifetime terms `M_h - t_h` and `s(q)`
- Fix status:
  - state:
    fixed in analyzer virtual-MuTRiG model; periodic and Poisson plots overwritten
  - mechanism:
    the analyzer now builds the plotted pre-rbCAM reference from the direct corun source ledger using `I=910` cycles, `s(q)=9+7*floor(q/2)+3*(q mod 2)`, and a calibrated `L_pre=18` cycle fixed transport.  The post-rbCAM top panel still imports the clean full-FEB DEBUG-age reference.
  - before_fix_outcome:
    periodic and Poisson pre-rbCAM plotted `min/p05/p50/p95/max=17/17/17/17/17` cycles, hiding the virtual MuTRiG source lifetime profile
  - after_fix_outcome:
    rerun analyzer and DISLIN renderer pass for both maintained reports.  Periodic all-ASIC 1 ms reports pre-rbCAM virtual-MuTRiG `min/p05/p50/p95/max=27/125/536/946/1044` cycles; Poisson seed `20260508` reports `67/148/524/892/938` cycles.  Both runs remain `TRACE_DEBUG_PASS`, zero OPQ drops, zero missing hits, and zero ghost hits.
  - potential_hazard:
    low for datapath behavior because this is reporting-only; medium for review evidence if future plots mix local transport markers and source-to-checkpoint lifetime without naming the origin
- Runtime / coverage context:
  - one FEB is modeled with lanes 0 and 1 enabled; lanes 2 and 3 are masked
  - lane 0 carries ASIC0..7 channels 0..31 at 100 kHz/channel for 1 ms
  - overwritten periodic plots live under `tb_int/feb_swb_corun/report/`
  - overwritten Poisson plots live under `tb_int/feb_swb_corun/report_poisson/`
- Commit:
  - analyzer/model/plot documentation fix: e2cca629

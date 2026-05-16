# BUG_HISTORY.md - v3_pretest-260511 tb_int DV bug ledger

Class legend:
- `R` = RTL / DUT integration bug
- `H` = harness / testcase / reporting bug

Severity legend:
- `soft error` = the bad packet/data flushes through the stream and does not leave the later datapath stuck
- `hard stuck error` = the bug poisons later packet handling and typically needs a functional reset / fresh restart to recover
- `non-datapath-refactor` = observability, reporting, harness, or naming/accounting consistency work with no direct packet-contract effect

Encounterability legend:
- practical severity is `severity x encounterability`, so the index must say how likely a reader is to hit the bug in normal use rather than only when it first appeared in one simulation log
- nominal datapath operation = legal traffic, routine FEB SciFi bring-up, and no forced error injection or artificially pathological stalls
- nominal control-path operation = routine bring-up / CSR program / readback / clear-counter sequences
- `common (...)` = readily hit in nominal operation
- `occasional (...)` = hit in nominal operation without heroic setup, but not in every short run
- `rare (...)` = legal in nominal operation, but usually needs long runtime or unlucky alignment
- `corner-only (...)` = requires a legal but non-nominal stress or corner profile
- `directed-only (...)` = requires targeted error injection, formal/probe flow, reporting-only flow, or another non-operational stimulus

Fix status detail contract for active entries and future updates:
- `state` = fixed / open / partial plus the current verification gate
- `mechanism` = how the implemented repair changes the RTL, integration, or harness behavior
- `before_fix_outcome` and `after_fix_outcome` = concise evidence showing what changed
- `potential_hazard` = whether the fix looks permanent or is still provisional / profile-limited
- `review decision` = explicit review state; use `pending / not run` until that review has actually happened

Historical formal note:
- This ledger starts with the v3_pretest-260511 tb_int harness bring-up on 2026-05-11.
- Historical standalone IP formal notes remain in the source IP repositories.

## Index

| bug_id | class | severity | encounterability | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| [BUG-001-R](#bug-001-r-rdma-upload-boundary-not-applicable-to-v3-pretest-feb-only-tb-int) | R | non-datapath-refactor | `directed-only (scope correction / task split)` | redesignated / not-applicable for FEB-only tb_int | `B065` structural preflight | `pending` | v3_pretest-260511 FEB-only tb_int correctly binds the legacy upload_pkt_mux path; RDMA cosim is task #48. |
| [BUG-002-R](#bug-002-r-master-mutrig_datapath_system_v3qsys-pinned-mutrig_frame_deassembly-at-26100506-after-ip-side-rc-readyless-fix) | R | hard stuck error | `common (routine run-control bring-up)` | fixed / follow-up build gated | on-board Phase 4 retest | `pending` | stale mutrig_frame_deassembly pin kept a ready-capable run-control sink in the datapath. |
| [BUG-003-R](#bug-003-r-top-run_control_splitter-ready-gating-blocks-feb-v3-emulator-and-histogram-hits) | R | hard stuck error | `common (routine emulator and histogram bring-up)` | fixed / qsys regenerated | live hist zero capture + `RC_EMUL_BLOCKED` | `pending` | top FEB V3 run_control_splitter used ready backpressure, so unused/readyless fanout ports collapsed RUNNING broadcast and left hist bins at zero. |
| [BUG-004-R](#bug-004-r-decoded-lane-multiplexer-keeps-real-lvds-idle-on-the-emulator-histogram-path) | R | hard stuck error | `common (routine emulator-driven histogram bring-up)` | fixed / board retest pending | live hist zero capture after readyless run-control fix | `pending` | decoded-lane fan-in allowed always-valid real LVDS idle traffic to dominate the emulator source path, hiding directed emulator hits from rbCAM and hist. |
| [BUG-005-R](#bug-005-r-emulator-csr-address-width-wraps-high-status-and-control-offsets) | R | hard stuck error | `common (routine emulator CSR program / readback)` | fixed / board retest pending | live source-mux capture + manual SC readback | `pending` | emulator CSR instances kept a 4-bit address generic while the parent map exposed larger windows, so high offsets wrapped to low config/UID registers. |
| [BUG-006-R](#bug-006-r-readyless-mts-run_prepare-rearm-loss-keeps-fresh-live-captures-empty) | R | hard stuck error | `common (fresh histogram readback / CSR counter runs)` | fixed in sim / board retest still failing | live hist zero capture after source-mux and emulator CSR fixes | `pending` | MTS rearm fix is present in the programmed tree, but live source-mux-to-frame-parser closure is still blocked by zero downstream counters and a timing-violating FEB build. |
| [BUG-007-R](#bug-007-r-qsys-catalog-shadowing-and-optional-streams-block-feb-v3-gui-open) | R | non-datapath-refactor | `common (FEB v3 Platform Designer open/generate)` | fixed / qsys-generate green | FEB v3 Qsys GUI reported 121 errors on 2026-05-15 | this commit | Qsys search-path shadowing selected the wrong MuTRiG frame-deassembly package surface and optional streams stayed enabled in production-disabled configurations. |
| [BUG-008-H](#bug-008-h-source-mux-frame-cosim-interval-rollover-clears-total_hits-during-long-drain) | H | non-datapath-refactor | `corner-only (long-drain cosim profiles with drain > 10000 cycles)` | fixed / long-drain cosim green | `high_3m_q256` exploratory cosim | `pending` | The cosim programmed histogram interval as `run_cycles + 10000`, so longer drains could roll the interval and clear `TOTAL_HITS` before CSR readback. |
| [BUG-009-H](#bug-009-h-synthesis_debug-dut-manifest-has-debug2-sources-but-generated-rtl-still-debug0) | H | non-datapath-refactor | `common (real-DUT debug tb_int with synthesis_debug)` | open / manifest guard blocks sim | `check_qsys_dut_manifest QSYS_DUT_VARIANT=synthesis_debug` | `pending` | The copied debug Qsys source tree carries DEBUG=2, but generated `synthesis_debug/` RTL still has DEBUG/DEBUG_LEVEL/DEBUG_LV generics at 0, so the real-DUT waveform run is intentionally blocked. |
| [BUG-010-H](#bug-010-h-focused-stp-frame-capture-has-sop-eop-shape-but-not-decodable-data-datak-contract) | H | non-datapath-refactor | `directed-only (old focused SignalTap export without data/datak contract probes)` | open / recapture required | focused STP contract decode + OPQ replay on 2026-05-16 | `pending` | The old focused STP capture shows 517 valid frame-shaped samples but exports data as zero and lacks datak, so the strict Mu3e checker and replay fail instead of proving delivered hits. |
| [BUG-011-H](#bug-011-h-live-feb-frame-counters-advance-but-swb-opq-ingress-remains-idle) | H | hard stuck error | `common (live FEB-to-SWB hit-flow bring-up)` | fixed / OPQ ingress restored; host capture fixed by BUG-013-H | live programmed STP firmware on 2026-05-16 | `pending` | SciFi OPQ mode wrote `SWB_LINK_MASK_SCIFI=0x4`, but `swb_block` gated OPQ with the generic mask, leaving `mask_n=0`; the selected-mask fix restores logical lane-2 OPQ ingress. |
| [BUG-012-H](#bug-012-h-mu3e-frame-checker-missed-broken-packet-length-and-subframe-beat-counts) | H | non-datapath-refactor | `directed-only (malformed STP/replay contract validation)` | fixed / sim and STP negative gates pass | FEB frame-after-assembly STP decode on 2026-05-16 | `pending` | The Mu3e checker now rejects nonconsecutive subheaders, per-subheader hit-count mismatch, frame length mismatch, and cross-frame packet/page discontinuity. |
| [BUG-013-H](#bug-013-h-short-lived-board-helpers-clear-swb-dma-enable-during-capture) | H | hard stuck error | `common (host DMA capture with rc_tool/sc_tool traffic)` | fixed / 5 s board capture nonzero | post-BUG-011 host capture retest on 2026-05-16 | `pending` | Short-lived board helpers can clear `DMA_REGISTER_W[0]` while `dma_tool` is alive, so the capture process must own and reassert the DMA enable bit. |

## 2026-05-11

No active DUT bug remains from the original BUG-001-R observation; it is redesignated below.

### BUG-002-R: master mutrig_datapath_system_v3.qsys pinned mutrig_frame_deassembly at 26.1.0.0506 after IP-side rc-readyless fix
- First seen in:
  - on-board Phase 4 retest under SOF v3_pretest-260511-phase4-fix-260511, commit `ac7543dd` (TEST: Phase 4 postfix-1 retest on phase4-fix SOF confirms FAIL)
- Symptom:
  - RC_RUNNING one-hot reaches run_control_splitter.in0 but does not propagate past the auto-inserted altera_avalon_st_timing_adapter on the splitter fan-out
  - downstream sinks (mutrig_datapath_subsystem_X.run_ctrl) remain in pre-RUN behaviour despite the runctl_mgmt_host hub already asserting RUNNING
- Root cause:
  - master quartus_systems/mutrig_datapath_system_v3.qsys pinned mutrig_frame_deassembly_0 at version 26.1.0.0506
  - submodule pointer moved to mutrig_frame_deassembly @ 779f920 = 26.2.0.0511 in commit `93ce227c`, which strips asi_ctrl_ready on the ctrl sink
  - qsys-generate honored the explicit pin and kept regenerating the pre-rc-readyless ctrl handshake, so a timing_adapter still sat on the rc fan-out for the affected sub-tree
- Fix status:
  - state:
    - fixed in this commit (master qsys instance bumped to 26.2.0.0511); the build / qsys-generate gate happens in the follow-up v3_pretest-260511-rc-readyless-260511 build dir
  - mechanism:
    - bump master quartus_systems/mutrig_datapath_system_v3.qsys component header 3.0.0.0511 -> 3.0.1.0511 and the mutrig_frame_deassembly_0 instance kind version 26.1.0.0506 -> 26.2.0.0511
    - bump quartus_systems/feb_system_v3.qsys and quartus_systems/scifi_datapath_system_v3{,_pipe,_lat4}.qsys 3.0.2.0511 -> 3.0.3.0511 with the 6-sink USE_READY=0 closure note in the description
  - before_fix_outcome:
    - Phase 4 retest on the on-board SOF saw RC_RUNNING stall at the splitter fan-out (commit `ac7543dd`)
  - after_fix_outcome:
    - qsys-generate gate is staged for the next build dir; the closure evidence (zero timing_adapter on run_control_splitter fan-out) will be appended to this entry after the rc-readyless rebuild
  - potential_hazard:
    - low while the instance pin matches the live IP version; any future mutrig_frame_deassembly bump must drag the qsys instance kind version forward in the same commit
  - review decision:
    - pending / not run

## 2026-05-14

### BUG-003-R: top run_control_splitter ready-gating blocks FEB V3 emulator and histogram hits
- First seen in:
  - live histogram sideband capture `firmware_builds/systems/v3_pretest-260511/reports/hw_hist_sideband_20260514_225655`, where pre/post mode0 and delay readbacks reported `TOTAL_HITS=0`, `hist bin sum=0`, and rbCAM push/pop/fill counters stayed at zero despite visible emulator CSR configuration
  - `make run_RC_EMUL_BLOCKED run_RC_EMUL_FIXED SIM_ROOT=sim/iter_20260515_hist_zero` from `firmware_builds/systems/v3_pretest-260511/tb_int`
- Symptom:
  - the FEB run-control host accepted run commands, but the datapath did not enter a hit-producing state for emulator-driven histogram capture
  - the blocked cosim reproduced the live behavior with `TOTAL_HITS=0x00000000`
- Root cause:
  - `quartus_systems/scifi_datapath_system_v3.qsys` configured the top `run_control_splitter` with `USE_READY=1`
  - the generated splitter therefore kept output-ready inputs in the broadcast path; unused outputs and readyless downstream sinks could hold the internal ready reduction low and collapse `out_valid`
  - the source mux, emulator, rbCAM, and histogram path were therefore starved even though run-control commands reached the management host
- Fix status:
  - state:
    - fixed in source Qsys and regenerated FEB V3 Qsys output; full Quartus fit / board retest remains pending
  - mechanism:
    - set `run_control_splitter.USE_READY=0` in `quartus_systems/scifi_datapath_system_v3.qsys` and `quartus_systems/scifi_datapath_system_v3_lat4.qsys`; `scifi_datapath_system_v3_pipe.qsys` already carried the readyless setting
    - bump FEB/datapath Qsys metadata to `3.0.5.514`
    - update `firmware_builds/systems/v3_pretest-260511/script/update_scifi_datapath_v3_histogram_stats.tcl` and `refresh_v3_histogram_parent_binding.tcl` so scripted Qsys refresh preserves the readyless run-control contract
  - before_fix_outcome:
    - `RC_EMUL_BLOCKED` passed only by observing `TOTAL_HITS=0x00000000`, matching the zero-bin hardware capture
  - after_fix_outcome:
    - `RC_EMUL_FIXED` passed with `TOTAL_HITS=0x00000010` after 16 directed emulator hits
    - `QSYS_GENERATE_STAMP=20260514_runctl_readyless_fix firmware_builds/systems/v3_pretest-260511/script/generate_feb_system_v3.sh` exited 0 with `error_count=0`
    - regenerated `feb_system_v3_data_path_subsystem_run_control_splitter.vhd` ties `out0_ready` through `out15_ready` to `'1'` internally and terminates `in0_ready`, removing the splitter-level ready gate
    - `make comp_dut SIM_ROOT=sim/iter_20260515_hist_zero_generated` exited 0 with generated Qsys HDL compile errors at zero
  - potential_hazard:
    - medium until a full FEB Quartus compile and live pre/post histogram retest confirm nonzero bins in mode0 and delay mode
  - review decision:
    - pending / board retest not run

## 2026-05-15

### BUG-004-R: decoded lane multiplexer keeps real LVDS idle on the emulator histogram path
- First seen in:
  - live histogram sideband capture `firmware_builds/systems/v3_pretest-260511/reports/hw_hist_sideband_live_20260515_013924`, where source-mux control selected the emulator path but the previous generated lane fan-in could still admit the always-valid real LVDS lane stream before the histogram/rbCAM chain
  - active generated HDL inspection after `QSYS_GENERATE_STAMP=20260515_source_mux_fix firmware_builds/systems/v3_pretest-260511/script/generate_feb_system_v3.sh`
- Symptom:
  - emulator-driven histogram capture stayed at zero even after the readyless run-control splitter fix
  - source selection needed a single owned source choice per lane so emulator traffic could be isolated from the real FEB lane stream during board bring-up
- Root cause:
  - the decoded-lane path relied on a generic stream multiplexer shape that was unsuitable for a bring-up source override because the real LVDS side can be continuously valid with idle/control words
  - the histogram/rbCAM debug flow needs an explicit static source select between real-lane traffic and emulator traffic, with per-source counters proving which side is being forwarded
- Fix status:
  - state:
    - fixed in source Qsys and regenerated FEB V3 Qsys output; final live histogram retest remains pending after the emulator CSR aperture fix is programmed
  - mechanism:
    - add `mutrig_lane_source_mux` as a static per-lane source selector with CSR-visible UID, select, and real/emulator/selected beat counters
    - update the v3 histogram contract Tcl and parent binding refresh so all active v3 datapath variants instantiate the source muxes and expose them through the SC-hub word map
  - before_fix_outcome:
    - live histogram readback stayed at `TOTAL_HITS=0` and zero nonzero bins during emulator-driven pre/post captures
  - after_fix_outcome:
    - regenerated active wrapper `feb_system_v3_data_path_subsystem.vhd` instantiates `mutrig_lane_source_mux_0` through `mutrig_lane_source_mux_7`
    - `make comp_dut SIM_ROOT=sim/iter_20260515_emu_csr6_source_mux` and `make run_RC_EMUL_BLOCKED run_RC_EMUL_FIXED SIM_ROOT=sim/iter_20260515_emu_csr6_source_mux` both exited 0 after the source-mux and CSR-width regeneration
  - potential_hazard:
    - medium until the newly compiled SOF confirms nonzero source-mux `emu_beats`, `selected_beats`, and histogram bins on hardware
  - review decision:
    - pending / board retest not run

### BUG-005-R: emulator CSR address width wraps high status and control offsets
- First seen in:
  - live histogram sideband capture `firmware_builds/systems/v3_pretest-260511/reports/hw_hist_sideband_live_20260515_013924`, where all source mux UIDs were visible and selected the emulator path but `emu_beats=0` and `selected_beats=0`
  - manual SC-hub word readback of lane-0 emulator CSR window `0x08800` through `0x0881F`, where words at offsets `0x10` through `0x1F` repeated offsets `0x00` through `0x0F`
- Symptom:
  - high-offset emulator CSR/status registers were inaccessible from the live SC path even though the parent address map reserved larger per-lane windows
  - emulator configuration appeared partially visible, but the intended high control/status/counter region aliased back onto low config and UID words
- Root cause:
  - all `emulator_mutrig_qsys_lane` instances in `scifi_datapath_system_v3{,_pipe,_lat4}.qsys` retained `CSR_ADDR_WIDTH=4`
  - the parent SC bridge exposed `0x100` byte windows per lane, but the instance-level address generic decoded only 16 words and wrapped high offsets
- Fix status:
  - state:
    - fixed in source Qsys and regenerated FEB V3 Qsys output; full Quartus compile and board retest are in progress
  - mechanism:
    - add `widen_emulator_csr_apertures` to `firmware_builds/systems/v3_pretest-260511/script/update_scifi_datapath_v3_histogram_stats.tcl`
    - set every v3/v3_pipe/v3_lat4 `emulator_mutrig_*` instance to `CSR_ADDR_WIDTH=6`, matching the exposed SC-hub word aperture used by the live capture script
  - before_fix_outcome:
    - live SC readback showed repeated low-register payload at high offsets and emulator source-mux counters remained at zero during a run
  - after_fix_outcome:
    - `firmware_builds/systems/v3_pretest-260511/script/apply_v3_histogram_stats_contract.sh` and `tclsh firmware_builds/systems/v3_pretest-260511/script/refresh_v3_histogram_parent_binding.tcl` exited 0
    - `QSYS_GENERATE_STAMP=20260515_emu_csr6_source_mux firmware_builds/systems/v3_pretest-260511/script/generate_feb_system_v3.sh` exited 0 with `error_count=0`
    - regenerated active wrapper carries `CSR_ADDR_WIDTH => 6` and `std_logic_vector(5 downto 0)` emulator CSR addresses
    - `make comp_dut SIM_ROOT=sim/iter_20260515_emu_csr6_source_mux` and `make run_RC_EMUL_BLOCKED run_RC_EMUL_FIXED SIM_ROOT=sim/iter_20260515_emu_csr6_source_mux` both exited 0; `RC_EMUL_FIXED` reached `TOTAL_HITS=0x00000010`
  - potential_hazard:
    - medium until the newly compiled SOF proves high-offset emulator CSRs no longer alias and live pre/post histogram captures produce nonzero bins
  - review decision:
    - pending / board retest not run

### BUG-006-R: readyless MTS RUN_PREPARE rearm loss keeps fresh live captures empty
- First seen in:
  - live histogram captures after the source-mux and emulator CSR aperture fixes, where the SC-hub map was readable and emulator/source-mux setup completed but MTS/rbCAM/hist counts still stayed at zero across fresh captures
  - MTS standalone regression after adding a readyless fresh-run rearm check
- Symptom:
  - the board bring-up script could start a new histogram readback run and then a separate fresh CSR counter run, but the downstream hit path did not reliably re-arm
  - this blocked the requested validation flow where histogram bins are read during an active run after at least 1 ms and CSR counters are captured in a later fresh run
- Root cause:
  - FEB v3 Qsys correctly treats the run-control fanout as readyless, so `RUN_PREPARE` cannot be backpressured at the MTS sink
  - the MTS command-capture process still required local `ctrl_ready_comb=1` for all command words
  - a `RUN_PREPARE` beat arriving while MTS was locally flushing or otherwise not ready was discarded, leaving the next `RUNNING` command without a clean fresh-run state
- Fix status:
  - state:
    - fixed in the MTS IP and regenerated FEB v3 Qsys output; full Quartus compile and board retest pending
  - mechanism:
    - bump the MTS IP to `26.3.2.515`
    - decode incoming run-control words before the local ready gate
    - accept `RUN_PREPARE` even when local control ready is low, while preserving the ready gate for the other commands
    - update `update_scifi_datapath_v3_histogram_stats.tcl` so generated source and parent Qsys bindings preserve the MTS patch version
  - before_fix_outcome:
    - repeated live captures could leave `TOTAL_HITS=0`, zero rbCAM push/pop counts, and zero histogram bin sums even with the emulator path selected
  - after_fix_outcome:
    - `make clean compile`, `make run_term`, and `make run_math` pass in `mutrig_timestamp_processor/tb`
    - `QSYS_GENERATE_STAMP=20260515_mts_runprep_rearm firmware_builds/systems/v3_pretest-260511/script/generate_feb_system_v3.sh` exited 0 with `error_count=0`
    - `make comp_dut SIM_ROOT=sim/iter_20260515_mts_runprep_rearm` passed
    - `make run_RC_EMUL_BLOCKED run_RC_EMUL_FIXED SIM_ROOT=sim/iter_20260515_mts_runprep_rearm` passed, with `RC_EMUL_FIXED` reaching `TOTAL_HITS=0x00000010` and scoreboard reconcile `A=16 stable_A=16 PRE=16 POST=16 FEB=16 closed=16 stable_closed=16`
    - board retest after programming `firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10/output_files/top.sof` (checksum `0x31A81F8C`) and `firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3/output_files/top.sof` (checksum `0x15289736`) still showed zero pre/post histogram bins in both mode0 and delay mode:
      `firmware_builds/systems/v3_pretest-260511/reports/hw_hist_sideband_live_20260515_1ms_full_pre_post_mode0_delay_after_program/manifest.json`
    - the retest confirms the live bridge and SC map are reachable and lane-0 emulator/source-mux counters advance (`EMU_SELECTED` nonzero, `LAST_SELECTED=0x0001019C`), but frame-deassembly, MTS, rbCAM, and histogram counters remain zero; next live boundary is source-mux output into frame parser, with SignalTap needed if timing-clean firmware still reproduces it
  - potential_hazard:
    - high until a timing-clean FEB SOF is produced and the source-mux-to-frame-parser live boundary is closed; the loaded 2026-05-15 06:27 FEB build reports setup slack violations (`-1.502 ns` slow 85 C, `-1.385 ns` slow 0 C) on the LVDS datapath clock
  - review decision:
    - pending / board retest run but still failing on hardware

### BUG-007-R: Qsys catalog shadowing and optional streams block FEB v3 GUI open
- First seen in:
  - `quartus_systems/feb_system_v3.qsys` Platform Designer GUI open on 2026-05-15, where the GUI still reported 121 errors after the earlier histogram/sideband Qsys Tcl update.
  - The current top-level target for this task is `quartus_systems/feb_system_v3.qsys`, not the generated copy under `firmware_builds/systems/v3_pretest-260511/syn`.
- Symptom:
  - Platform Designer could open the top-level only with a large error/warning cluster around MuTRiG frame-deassembly and unused optional streams.
  - The generated FEB v3 Qsys path was still sensitive to stale catalog search order and local user-catalog state.
- Root cause:
  - The active Qsys search path could include `mutrig_frame_deassembly/script` even though the IP root also has the real component surface, allowing the script directory to shadow the intended package during catalog resolution.
  - Optional package interfaces stayed enabled when FEB v3 deliberately disabled histogram post forwarding, histogram snooping, MTS debug streams, emulator direct-hit output in byte-stream mode, and the internal frame-deassembly FIFO `almost_empty` status.
- Fix status:
  - state:
    - fixed for GUI open and top-level Qsys generation; remaining warnings are legacy/optional-interface warnings rather than hard errors
  - mechanism:
    - update `qsys_search_path.sh` so script helper directories are skipped when the IP root already provides a component surface
    - make `apply_v3_histogram_stats_contract.sh` reuse the shared active search path, isolated catalog, and a new `update_mutrig_datapath_v3_frame_fifo.tcl` hook
    - refresh the v3 histogram/MTS/emulator package versions and VERSION_GIT instance parameters to the committed submodule tips
    - regenerate `quartus_systems/feb_system_v3.qsys`, `mutrig_datapath_system_v3.qsys`, and the three SciFi datapath variants
  - before_fix_outcome:
    - GUI open still reported 121 errors in the FEB v3 top-level Qsys session.
  - after_fix_outcome:
    - `_JAVA_OPTIONS=-Dsun.java2d.xrender=false -Dsun.java2d.opengl=true qsys-edit quartus_systems/feb_system_v3.qsys` opened on the remote display; `/tmp/qsys_edit_feb_system_v3_top_20260515_114734.log` had no `Error:`, `Warning:`, or exception lines.
    - `qsys-generate quartus_systems/feb_system_v3.qsys --synthesis=VERILOG` exited with status 0, no `Error:` lines, and 82 remaining warnings in `/tmp/qsys_generate_feb_v3_top_20260515_122310.log`.
  - potential_hazard:
    - medium. The GUI/generation blocker is closed, but the live hardware bottleneck remains the source-mux output into frame parser / MuTRiG frame-deassembly boundary once a timing-clean SOF is available.

### BUG-008-H: source mux frame cosim interval rollover clears TOTAL_HITS during long drain
- First seen in:
  - exploratory long cosim `sim_hist_ip_cosim_exploratory_fail_20260515/high_3m_q256/transcript`
- Symptom:
  - `parser_hit_count=374976`, `mts_type1_count=374976`, and `hist_ext0_count=374976`, but histogram CSR `TOTAL_HITS=0`
  - `hist_bank_status=0x00000001`, showing the histogram interval rolled while the bench was draining in-flight hits before CSR readback
- Root cause:
  - the cosim programmed `HIST_CSR_INTERVAL` as `run_cycles + 10000`
  - high-rate long-drain profiles used `DRAIN_CYCLES=16384`, so the programmed interval expired during the drain phase and cleared the live `TOTAL_HITS` register before the final CSR check
- Fix status:
  - state:
    - fixed in the cosim harness
  - mechanism:
    - program `HIST_CSR_INTERVAL` as `run_cycles + drain_cycles + 10000`
    - print `hist_interval_cycles` in the summary so future long-drain evidence proves the interval covers the final CSR readback
  - before_fix_outcome:
    - `high_3m_q256` failed with `hist_total_hits=0` even though the MTS extended stream delivered 374976 hits into the histogram IP
  - after_fix_outcome:
    - `sim_hist_ip_cosim_long_sweep_20260515/high_1m_q256_longdrain/transcript` passed with `hist_interval_cycles=1026384`, `parser_hit_count=124992`, `mts_type1_count=124992`, `hist_ext0_count=124992`, `hist_total_hits=124992`, `hist_dropped_hits=0`
    - `sim_hist_ip_cosim_long_sweep_20260515/high_1m_q384_longdrain/transcript` passed with `hist_interval_cycles=1026384`, `parser_hit_count=187488`, `mts_type1_count=187488`, `hist_ext0_count=187488`, `hist_total_hits=187488`, `hist_dropped_hits=0`
  - potential_hazard:
    - low for the cosim harness; the interval guard now scales with any requested drain length
  - review decision:
    - pending / no code-review commit yet
  - review decision:
    - pending / not run

## 2026-05-16

### BUG-009-H: synthesis_debug DUT manifest has DEBUG=2 sources but generated RTL still DEBUG=0
- First seen in:
  - `QSYS_GENERATE_STAMP=20260516_dual_dut_manifest_dbg02 firmware_builds/systems/v3_pretest-260511/script/generate_feb_system_v3.sh`
  - `make check_qsys_dut_manifest QSYS_DUT_VARIANT=synthesis_debug` from `firmware_builds/systems/v3_pretest-260511/tb_int`
- Symptom:
  - `synthesis/` passes the generated-DUT manifest check, but `synthesis_debug/` fails before the realistic real-DUT run can compile.
  - The guard reports `debug DUT has no generated DEBUG/DEBUG_LEVEL/DEBUG_LV generic set to 2`.
  - Direct RTL inspection shows generated debug VHDL still uses `DEBUG => 0` and `DEBUG_LEVEL => 0` in the control, upload, datapath, and hit-stack submodules.
- Root cause:
  - the copied `qsys_debug_sources/` tree contains the intended DEBUG=2 Qsys parameter edits, but the `qsys-generate` invocation still resolves hierarchical composed systems from the original component/catalog definitions rather than the copied debug Qsys sources.
  - Copying raw `.qsys` files into a debug source directory is therefore not sufficient to force generated debug RTL for composed child systems.
- Fix status:
  - state:
    - open; no bypass is allowed because this is the DUT identity guard that prevents simulation/synthesis drift
  - mechanism:
    - the manifest checker remains a hard pre-sim gate for `QSYS_DUT_VARIANT=synthesis_debug`
    - `run_RC_EMUL_REALISTIC_WAVE BIND_REAL_DUT=1 QSYS_DUT_VARIANT=synthesis_debug` is blocked until Qsys component resolution is corrected
  - before_fix_outcome:
    - normal manifest pass: `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3/synthesis/.qsys_dut_manifest.json`, tree SHA256 `76926ea07c99abaa6d0e3287d342a5e4ba1d4aa15718a130180c6e26fa9bc683`
    - debug manifest fail: `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3/synthesis_debug/.qsys_dut_manifest.json`, generated RTL still has no DEBUG=2 generic
  - after_fix_outcome:
    - pending; the next valid evidence must be a passing debug manifest followed by the realistic real-DUT waveform run
  - potential_hazard:
    - high for debug observability only; a green sim using the wrong generated tree would hide the exact custom RC/data-path bug class under investigation
  - review decision:
    - pending / generator-source resolution not fixed

### BUG-010-H: focused STP frame capture has SOP/EOP shape but not decodable data/datak contract
- First seen in:
  - `tools/run_script/decode_mu3e_stp_vcd.py --profile feb-focused firmware_builds/systems/v3_pretest-260511/reports/stp_swb_frame_structure_20260516_153044/stream_debug_swb_frame.vcd --fail-on-contract-error`
  - `make run_OPQ_FRAME_STP_REPLAY STP_REPLAY_MEM=.../top_upper_replay.mem` from `firmware_builds/systems/swb/rdma_pretest-260511/tb_int`
- Symptom:
  - the old focused STP capture records 517 valid samples with SOP/EOP shape, but the exported `*_data_observed` buses stay `0x00000000` and no datak sideband is present.
  - the offline checker reports contract failure on all decoded focused streams: `inner_upper`, `inner_lower`, and `top_upper` each have 519 Mu3e frame-format errors and 0 decoded hits.
  - the SWB OPQ replay converts `top_upper_replay.mem` into the same monitor contract and fails with `UVM_ERROR : 520`, including `SOP asserted without K28.5` and `ingress replay hits=0 expected at least 1`.
- Root cause:
  - the capture is a frame-structure snapshot, not a packet-contract snapshot: it is useful for valid/ready/SOP/EOP lifetime review, but it does not preserve the 32-bit frame word value or the 4-bit datak/K-symbol provenance required by the Mu3e header/subheader/hit checker.
- Fix status:
  - state:
    - open; recapture required with data and datak taps at the same boundaries before using STP as packet-contract evidence
  - mechanism:
    - `tools/run_script/decode_mu3e_stp_vcd.py` now performs strict Mu3e frame checking, emits all decoded words, writes replay memory for `tb_int`, and can fail on contract errors or zero-downstream boundary drops
    - SWB `tb_int` now includes `tb_int_opq_frame_replay_test` and `make run_OPQ_FRAME_STP_REPLAY` to replay decoded STP words into the same OPQ monitor checker
  - before_fix_outcome:
    - old focused capture could be reviewed visually in GTKWave, but it could not prove header/subheader/hit legality or declared-versus-observed hit counts
  - after_fix_outcome:
    - negative validation artifact: `firmware_builds/systems/v3_pretest-260511/reports/stp_contract_validation_20260516_focused_swb_frame/focused_frame_contract.json`
    - negative replay transcript: `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/sim_stp_replay_negative2/OPQ_FRAME_STP_REPLAY/transcript`
    - positive smoke for the replay-enabled SWB monitor harness: `make run_OPQ_FRAME_TS_SMOKE WORK=work_tb_int_stp_replay_check SIM_ROOT=sim_stp_replay_check` passed
  - potential_hazard:
    - medium; visual STP frame-shape evidence can look healthy while the packet contract is unprovable unless data and datak are captured
  - review decision:
    - pending / full data+datak STP recapture not run

### BUG-011-H: live FEB frame counters advance but SWB OPQ ingress remains idle
- First seen in:
  - `firmware_builds/systems/v3_pretest-260511/reports/hw_program_and_hitflow_20260516_182610/run_tool_opq_90s_retry_link2/debug_daq_summary.json`
  - `firmware_builds/systems/v3_pretest-260511/reports/hw_program_and_hitflow_20260516_182610/swb_stp_active_run_183535/swb_active_run_manual.focused.vcd`
  - `firmware_builds/systems/v3_pretest-260511/reports/hw_program_and_hitflow_20260516_182610/swb_stp_active_run_183535/swb_active_run_manual.decode_summary_active33.json`
- Symptom:
  - the timing-accepted FEB/SWB images program successfully and the FEB SC hub is reachable on link 2 after PCIe recovery.
  - the 90 s OPQ run leaves the host capture at 0 bytes and all SWB RDMA/OPQ counters at 0.
  - FEB counters advance through the custom data path: Type0 ARB ingress/egress, MTS total, rbCAM push/pop, and frame assembly declared/actual hits all match, with frame assembly missing hits at 0.
  - SWB SignalTap with real data/datak sidebands records physical and logical FEB receive lanes as K28.5/idle-like or invalid outside-frame words, with no decoded frames and no masked OPQ input words.
- Root cause:
  - `run_tool --use-opq` in SciFi mode programs `SWB_LINK_MASK_SCIFI`, while leaving `SWB_GENERIC_MASK` at 0.
  - `swb_block` previously drove `mask_n` only from `SWB_GENERIC_MASK_REGISTER_W`, so the OPQ-eligible link was forced to idle even when valid FEB frames reached the SWB logical receiver.
  - The link-2 physical/logical mapping itself is correct for the tested path: top-level `feb_rx(2)` is sourced from raw XCVR physical lane 8 and is gated by `mask_n[2]`.
- Fix status:
  - state:
    - fixed for the receiver-to-OPQ boundary; the separate host DMA/readout follow-up is tracked and fixed as BUG-013-H
  - mechanism:
    - select the live OPQ link mask from `SWB_LINK_MASK_SCIFI_REGISTER_W` whenever `USE_BIT_SCIFI` is set, otherwise keep the legacy generic-mask behavior
    - add preserved `debug_mask_*` signals for generic, SciFi, selected mask, readout state, and selector bits
    - extend the RN.BASIC.001 SWB SignalTap generator to capture all 16 raw XCVR0 RX lanes plus the selected mask signals, logical FEB RX lanes, masked OPQ inputs, and OPQ egress/packer handoff
    - add `SWB_FEB_SCIFI_MASK_REPLAY`, which instantiates the real `swb_block` around the steering/demux path and proves SciFi mask `0x4` passes link 2 while generic-only mask `0x4` does not pass in SciFi mode
  - before_fix_outcome:
    - `SWB_LINK_MASK_SCIFI=0x4`, `0x100`, `0x200`, `0x300`, and `0xF00` all produced 0 DMA bytes and 0 OPQ input words while FEB frame assembly counters advanced
  - after_fix_outcome:
    - post-XCVR SWB corun link-2 steering gate passes: `make run_swb_corun_link2 QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim OPQ_SOURCE_MODE=native_sv_signoff OPQ_LANE_FIFO_DEPTH=65536 OPQ_TICKET_FIFO_DEPTH=65536 OPQ_HANDLE_FIFO_DEPTH=65536 OPQ_PAGE_RAM_DEPTH=65536`
    - link-2 corun evidence: `firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/tb_int/feb_swb_corun/report_link2/link2_steering_check.log` reports `FEB_SWB_LINK2_STEERING_PASS lane=2 expected_hits=256 opq_ingress_hits=256 wr_hit=256 rd_hit=256`, with `opq_drop_counter_total=0`
    - regenerated SWB `rn001_opq_ingress_egress.stp` now captures all 16 raw physical XCVR0 RX output data/datak lanes, then carries the logical FEB RX lanes, masked OPQ inputs, and OPQ egress in the same capture for receiver-to-OPQ correlation
    - `make run_SWB_FEB_SCIFI_MASK_REPLAY SIM_ROOT=sim_swb_scifi_mask_20260516` passes with `scifi_mask=0x4 generic_mask=0x0 before=0 after=135`, `scifi_mask=0x0 generic_mask=0x4 before=135 after=135`, and `generic_mode generic_mask=0x4 before=135 after=270`
    - `make run_SWB_FEB_XCVR_DEMERGER_REPLAY SIM_ROOT=sim_swb_xcvr_replay_20260516_maskfix_demux`, `make run_SWB_FEB_XCVR_STEERING_REPLAY SIM_ROOT=sim_swb_xcvr_replay_20260516_maskfix_uvm`, and SWB `make check` all pass after the mask fix
    - SignalTap node check reports `probes total=1747 found=1747 missing=0 errors=0` in `firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10/rn001_opq_ingress_egress_nodecheck_20260516_mask_xcvr.md`
    - the compiled SWB image programs cleanly and a 5 s link-2 OPQ run writes nonzero SWB counters in `firmware_builds/systems/v3_pretest-260511/reports/hw_program_and_hitflow_20260516_220404_swb_maskfix_xcvr_stp/run_tool_opq_5s_link2_maskfix/debug_daq_summary.json`: `CNT_OPQ_INPUT_W=27488685`, `CNT_BYTES_WRITTEN=3460931`, `CNT_RQE_CONSUMED=58408`, `DMA_ENDEVENT_REGISTER_R=58408`
    - the active SWB SignalTap decode at `firmware_builds/systems/v3_pretest-260511/reports/hw_program_and_hitflow_20260516_220404_swb_maskfix_xcvr_stp/swb_stp_maskfix_active_run_2206/swb_maskfix_active_run.mask_xcvr_opq.summary.json` confirms `debug_mask_generic_w=0x00000000`, `debug_mask_scifi_w=0x00000004`, `debug_selected_link_mask_w=0x00000004`, `mask_n_low=0x4`, live data only on logical FEB lane 2, and OPQ ingress valid only on lane 2
  - potential_hazard:
    - low for the receiver-to-OPQ boundary; host DMA enable ownership is tracked separately under BUG-013-H
  - review decision:
    - pending / code review not run

### BUG-013-H: short-lived board helpers clear SWB DMA enable during capture
- First seen in:
  - `firmware_builds/systems/v3_pretest-260511/reports/hw_program_and_hitflow_20260516_220404_swb_maskfix_xcvr_stp/run_tool_opq_5s_link2_maskfix/debug_daq_summary.json`
  - manual live CSR checks of `DMA_REGISTER_W`, `DMA_STATUS_REGISTER_R`, and `DMA_CNT_WORDS_REGISTER_R` on 2026-05-16.
- Symptom:
  - after BUG-011 restored OPQ ingress, the SWB OPQ/RDMA counters advanced but `capture.bin` remained 0 bytes.
  - `DMA_STATUS_REGISTER_R=0x00000001` matched the DMA engine disabled state, while `DMA_CNT_WORDS_REGISTER_R` and OPQ/RDMA counters showed that the packer side had produced data.
  - `sc_tool --swb write DMA_REGISTER_W 0x1` read back as 1 within the same process, but a later process observed `DMA_REGISTER_W=0`.
  - a raw `/dev/mudaq0` mmap holder reproduced the lifetime bug: it wrote `DMA_REGISTER_W=1`, a separate `sc_tool` could see 1, and the holder later observed the bit cleared.
- Root cause:
  - short-lived board helpers can deactivate the DMA enable while the capture process is still alive.
  - `run_tool` launches `dma_tool` before the run-control sequence, so later `rc_tool` / `sc_tool` invocations can clear `DMA_REGISTER_W[0]` after the initial enable.
  - a one-shot `DMA_REGISTER_W=1` write from `run_tool` is therefore not a stable ownership model for host DMA capture.
- Fix status:
  - state:
    - fixed in `tools/run_script/dma_tool.cpp`; no RTL change or firmware recompile required
  - mechanism:
    - make `dma_tool` assert `DMA_REGISTER_W[0]` when the capture starts
    - keep reasserting the enable bit during the capture lifetime so run-control and slow-control helper exits cannot leave the DMA engine disabled
    - keep the existing shutdown behavior that writes `DMA_REGISTER_W=0` when `dma_tool` exits
  - before_fix_outcome:
    - post-BUG-011 5 s link-2 OPQ run had `CNT_OPQ_INPUT_W=27488685`, `CNT_BYTES_WRITTEN=3460931`, and `DMA_ENDEVENT_REGISTER_R=58408`, but `capture.bin=0`
  - after_fix_outcome:
    - `cmake --build tools/run_script/build --target dma_tool` passes
    - patched `dma_tool` logs repeated `DMA enable asserted: DMA_REGISTER_W 0x0 -> 0x1` during board-helper interference
    - `tools/run_script/run_tool --skip-program --use-opq --swb-link-mask-scifi 4 --feb-link 2 --duration-s 5 --skip-mutrig-config --dump-csrs --output-dir firmware_builds/systems/v3_pretest-260511/reports/hw_program_and_hitflow_20260516_2300_dma_enable_fix/run_tool_opq_5s_link2_dma_enable_fix` writes `capture.bin=106954752` bytes
    - the same run reports `read_words=26738688`, `written_words=26738688`, `bytes_written=106954752`, `CNT_OPQ_INPUT_W=27341414`, `CNT_BYTES_WRITTEN=3442578`, and FEB frame assembly declared/actual hits both `127382784` with `missing_hits=0`
  - potential_hazard:
    - medium for production readout policy: the debug capture process now owns the DMA enable bit while alive, but the broader helper lifetime contract should be cleaned up before relying on mixed helper processes in production DAQ
  - review decision:
    - pending / code review not run

### BUG-012-H: Mu3e frame checker missed broken-packet length and subframe beat counts
- First seen in:
  - `firmware_builds/systems/v3_pretest-260511/reports/feb_stp_frame_after_assembly_20260516_1930/feb_frame_after_assembly_topvalid.vcd`
  - `tools/run_script/decode_mu3e_stp_vcd.py --profile feb .../feb_frame_after_assembly_topvalid.vcd --fail-on-contract-error`
  - `make run_RC_EMUL_REALISTIC_WAVE SIM_ROOT=sim_feb_subheader_checker_20260516_len QSYS_DUT_VARIANT=synthesis`
- Symptom:
  - the live FEB SignalTap capture has one full 517-word SOP/EOP frame after frame assembly, but the subheaders are not monotonic and consecutive.
  - examples from the upper-bank stream include gaps, backward steps, and duplicates in the early subheader sequence: `00,01,02,07,05,06,07,09,0a,0b,0c,0f,0f`.
  - the same frame also violates the declared-length contract at EOP: the upper-bank decode accepted 517 words but the header/subheader declarations imply 2694 words, with 203 seen subheaders versus 256 declared and 307 seen hits versus 2432 declared.
  - before this update, the checker could report packet-format errors but did not make the missing declared hit beats and total packet length an explicit broken-packet failure.
- Root cause:
  - the Mu3e frame-format checker tracked marker order and decoded hit counts, but it did not close each frame with a strict accepted-word count.
  - it also did not require each subheader-declared hit count to be matched by exactly that many accepted hit beats before the next subheader or trailer.
- Fix status:
  - state:
    - fixed in the SystemVerilog checker and mirrored in the offline STP decoder
  - mechanism:
    - add strict subheader monotonic/consecutive checks, including duplicate, backward, and gap diagnostics
    - add per-subheader declared-hit accounting and fail on underflow or overrun
    - add end-of-frame length accounting: expected accepted words are `5 + declared_subheaders + declared_hits + 1`, and the v3 FEB data frame must carry 128 declared subheaders
    - mirror the same checks in `tools/run_script/decode_mu3e_stp_vcd.py` so STP evidence and `tb_int` monitor evidence use the same failure vocabulary
  - before_fix_outcome:
    - malformed STP frames could fail on local marker/sequence symptoms without explicitly proving that the declared subframe and whole-frame beat counts were broken
  - after_fix_outcome:
    - `make run_RC_EMUL_REALISTIC_WAVE SIM_ROOT=sim_feb_subheader_checker_20260516_len QSYS_DUT_VARIANT=synthesis` passes with both upload banks reporting `accepted_words=142 expected_words=142 frame_errors=0`
    - `make run_UPLOAD_MUX_CONTRACT SIM_ROOT=sim_feb_subheader_checker_20260516_len QSYS_DUT_VARIANT=synthesis` passes with `UPLOAD_MUX_CONTRACT_PASS accepted=142 checked=142`, proving the generated upload mux preserves the one-cycle input0 data contract when SC/RC are idle
    - the live STP decode now exits nonzero by design and writes `firmware_builds/systems/v3_pretest-260511/reports/feb_stp_frame_after_assembly_20260516_1930/feb_frame_after_assembly_topvalid.length_contract.decode_summary.json`
    - that negative STP artifact reports both early format errors (`subheader_sequence`, `subframe_declared_hit_count`) and final packet-length errors (`broken_packet_length`, `frame_declared_hit_count`, `subheader_declared_hit_sum`) on the captured frame
    - `make run_RC_EMUL_REALISTIC_LONG_WAVE SIM_ROOT=sim_feb_long_cross_20260516 QSYS_DUT_VARIANT=synthesis` passes a 1.346804 ms run with four frames per upload bank, `packet_count=0..3`, page base `0x00,0x80,0x00,0x80`, `accepted_words=150 expected_words=150` on every frame, and `UVM_ERROR=0`
    - follow-up closure adds a header-derived frame-start timestamp monotonicity gate: `{header_ts_hi, header_ts_lo[31:28], first_subheader_ts, 4'b0}` must not move backward across accepted frames
    - `make run_OFFLINE_CHANNEL_RATE_STUDY` generates 10 kHz, 100 kHz, 500 kHz, and 1 MHz one-random-channel-per-ASIC frame streams, decodes 48-bit hit timestamps from raw words, and fails on nonexact per-channel inter-event intervals or long gaps
  - potential_hazard:
    - low for checker coverage; the remaining hardware root cause is still open under BUG-011-H and needs an upstream frame-assembly input capture
  - review decision:
    - pending / code review not run

## Resolved / Redesignated

### BUG-001-R: RDMA upload boundary not applicable to v3_pretest FEB-only tb_int
- First seen in:
  - `make check_dut_contract` from `firmware_builds/systems/v3_pretest-260511/tb_int`
  - inherited first RDMA-bound datapath case assumption: `B065`
- Symptom:
  - the generated synthesis tree under `syn/feb_system_v3/synthesis/` contains no FEB-side `rdma_subsystem` hierarchy
  - the upload subsystem correctly compiles through the legacy `feb_frame_assembly` plus `upload_pkt_mux` path for this FEB-only build
  - the inherited harness treated the absence of RDMA SQE/CQE signals as a blocking bug
- Root cause:
  - scope error in the prior tb_int brief; RDMA lives on the SWB side and belongs to a separate FEB+SWB cosim effort
  - v3_pretest-260511 FEB-only tb_int must observe `upload_pkt_mux`, matching the Apr 27 reference layout
- Fix status:
  - state:
    - redesignated / not-applicable for FEB-only tb_int
  - mechanism:
    - rebind the FEB-egress monitor to the legacy `upload_pkt_mux` egress and leave RDMA cosim to task #48
  - before_fix_outcome:
    - `tb_int/sim/logs/dut_structural_check.log` recorded the inherited RDMA preflight block
  - after_fix_outcome:
    - `make -C tb_int run_B065` passed with the corrected `upload_pkt_mux` egress binding; scoreboard reconciled `A=16 PRE=16 POST=16 FEB=16 closed=16`
  - potential_hazard:
    - low for FEB-only smoke once the harness excludes RDMA SQE/CQE scaffolding from the active compile path
  - review decision:
    - pending / not run

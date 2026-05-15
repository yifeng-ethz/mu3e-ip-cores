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

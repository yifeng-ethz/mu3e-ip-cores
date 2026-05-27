# BUG_HISTORY.md - FEB v3 emulator-type0 phase 4.5 sweep bug ledger

This ledger records bugs found by the phase 4.5 sweep harness on the
`v3_pretest-260511-emutype0-dualport-260512` build. The harness is
`scripts/cotest/phase4_5_sweep.py` and the per-row evidence lives under
`sweep_evidence/<row_id>/`.

Class legend:
- `R` = RTL / DUT bug in an IP shipped on this build
- `H` = sweep-harness / testcase / reporting bug
- `I` = integration / Qsys / wiring bug at the FEB datapath level

Severity legend:
- `soft error` = the bad data is observable but the datapath does not remain stuck
- `hard stuck error` = the bug can poison later datapath behavior until reset or restart
- `non-datapath-refactor` = packaging, observability, reporting, harness, or metadata work with no direct packet-contract effect

## Index

| bug_id | class | severity | encounterability | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| [BUG-005-H](#bug-005-h-phase4_5_sweep-read-the-live-csr-13-counter-while-interval-pulses-reset-it-mid-run) | H | non-datapath-refactor | `common (default sweep configuration)` | fixed | FEB v3 emulator-type0 phase 4.5 sweep, 2026-05-12 | this commit | `scripts/cotest/phase4_5_sweep.py` programmed `INTERVAL_CFG = run_window` so the LIVE CSR 13 counter reset every 1 s during the 4 s window, and the sweep read the wrong offset (`0x10` = SCRATCH) for the STABLE CSR 17 latch. |
| [BUG-006-I](#bug-006-i-histogram-input-fifos-are-empty-on-every-row-of-the-2026-05-12-sweep) | I | hard stuck error | `common (every sweep row on the single-port build)` | fixed-with-residuals | FEB v3 emulator-type0 phase 4.5 sweep, 2026-05-12 | this commit | The single-port topology fed only `mts_preprocessor_0` into `histogram_statistics_0`; lanes 4..7 were routed only to hit-stack bank 1. The dual-port build wires both MTS banks into `histogram_statistics_0` and removes the ready-mismatch hazard on the arb-to-MTS path. |
| [BUG-007-I](#bug-007-i-feb-top-qsys-carried-stale-eight-emulator-csr-map) | I | non-datapath-refactor | `common (every top-level Qsys regenerate)` | fixed | FEB top Qsys regenerate, 2026-05-14 | this working tree | `syn/feb_system_v3.qsys` still bound `data_path_subsystem` to `3.0.4.512` and exported eight `emulator_mutrig_N` CSR apertures, causing Platform Designer address-map overlaps when the active datapath component only has `emulator_mutrig_qsys_inst`. |
| [BUG-008-I](#bug-008-i-feb-top-qsys-exported-a-stale-pulse_out_conduit-interface) | I | non-datapath-refactor | `common (every top-level Qsys regenerate after the runctrl refactor)` | fixed-debug-loadable | FEB top Qsys regenerate, 2026-05-14 | this checkpoint | `syn/feb_system_v3.qsys` still exported `pulse_out_conduit` even though the regenerated datapath/runctrl interface no longer drives that conduit, leaving stale wrapper ports and blocking a clean FEB top compile. |
| [BUG-009-H](#bug-009-h-feb-stp-generator-used-whole-vector-probes-that-synthesized-into-partial-signaltap-connections) | H | non-datapath-refactor | `directed-only (SignalTap observability build)` | fixed-debug-loadable | FEB STP map gate, 2026-05-14 | this checkpoint | The first FEB rbCAM-gap STP used whole-vector probes that Node Finder accepted but Quartus map only partially connected; the fixed generator emits bit-expanded instance-port probes and map reports all 631 SignalTap inputs/clocks/pins connected. |
| [BUG-010-H](#bug-010-h-febswb-corun-smoke-did-not-model-the-declared-128-subheader-frame) | H | non-datapath-refactor | `directed-only (FEB/SWB corun smoke and monitor harness)` | fixed | FEB/SWB corun UVM smoke, 2026-05-14 | this checkpoint | The corun smoke declared 128 subheaders but drove only the active subheader, and the monitors reconstructed true timestamps without rejecting a declared-versus-seen subheader mismatch. |
| [BUG-011-I](#bug-011-i-make-side-qsys-generation-did-not-produce-the-debug2-synthesis-dut-tree-for-tb_int) | I | non-datapath-refactor | `common (realistic tb_int setup and Qsys regeneration)` | fixed | FEB v3 debug Qsys generation, 2026-05-17 | this working tree | The Make-side Qsys generate hook produced only the normal `synthesis/` tree, leaving no parallel DEBUG_LEVEL=2 synthesis HDL tree for realistic `tb_int`; the arb supercore build Tcl also referenced stale `arb_hit_type0` version `26.5.0.0511`. |
| [BUG-012-H](#bug-012-h-feb-generated-histogram-smoke-did-not-require-declared-hit-counts-for-all-type0type1-modes) | H | non-datapath-refactor | `common (generated-FEB histogram direct simulation)` | fixed | FEB generated histogram simulation, 2026-05-17 | this working tree | The direct histogram smoke could pass without proving the declared 10 ms, 100 kHz one-random-channel-per-ASIC hit count for Type0 rate plus Type1 rate and latency modes on both MTS banks; it also compiled raw repo RTL instead of the regenerated FEB `simulation/submodules` tree. |
| [BUG-013-H](#bug-013-h-direct-histogram-harness-modeled-16-active-asics-instead-of-the-febs-8-asic-topology) | H | non-datapath-refactor | `common (generated-FEB histogram direct simulation and Type0 plot evidence)` | fixed | FEB generated histogram simulation review, 2026-05-17 | this commit | The direct histogram harness modeled 16 active ASIC sources, but this FEB has 8 ASICs total: 4 upper bank and 4 lower bank. |
| [BUG-014-I](#bug-014-i-feb-ip-packaging-could-drift-back-to-256-subheaders) | I | non-datapath-refactor | `common (Qsys/IP regeneration if an N_SHD override is missed or changed)` | fixed | FEB/SWB N_SHD audit, 2026-05-17 | this commit | `feb_frame_assembly` still defaulted to 256 subheaders and FEB rbCAM packaging still allowed non-128 `N_SHD`, so a missed override could regenerate a FEB source shape that SWB reports as 256 subheaders. |
| [BUG-015-H](#bug-015-h-type1-delay-plot-evidence-did-not-lock-the-one-channel-header-sync-delta-contract) | H | non-datapath-refactor | `directed-only (Type1 latency plot evidence)` | fixed | FEB generated Type1 delay plot review, 2026-05-17 | this commit | The generated-RTL delay evidence had no four-rate Type1 latency plot for the header-synced one-channel-per-ASIC mode, no per-hit ingress metadata checkpoint, and no hard metadata-vs-CSR bin check. |
| [BUG-016-R](#bug-016-r-hit_type0_fanout8-did-not-lane-phase-the-encoded-mutrig-timestamp) | R | soft error | `directed-only (generated-Qsys header-sync Type1 delay mode)` | fixed | FEB generated-Qsys Type1 header-sync gate, 2026-05-17 | `73d882cc456a5c459c3d27bc77ff7430c800cbcd` | The build-local `hit_type0_fanout8` changed ASIC/channel metadata per lane but copied the same encoded MuTRiG TCC/ECC timestamp to every lane, so serialized lanes produced a multi-cycle latency spread instead of the expected header-sync delta. |
| [BUG-017-H](#bug-017-h-dislin-plot-renderers-could-report-passing-artifacts-that-were-not-the-requested-files) | H | non-datapath-refactor | `directed-only (DISLIN plot evidence)` | fixed | FEB generated-Qsys plot evidence review, 2026-05-17 | `73d882cc456a5c459c3d27bc77ff7430c800cbcd` | The Type1 DISLIN metadata overlay read the wrong CSV column, and long DISLIN output paths could be silently truncated while the wrapper still printed the requested `.png/.pdf` path as passing. |
| [BUG-018-I](#bug-018-i-clean-feb-qsys-generation-could-drift-through-hidden-adapters-and-caller-relative-ip-roots) | I | non-datapath-refactor | `common (clean FEB Qsys regeneration and firmware compile)` | fixed | FEB Qsys clean generation, 2026-05-17 | `4a293ca1d0e8`, `9fa5856d58c4`, this commit | Clean `qsys-generate --clear-output-directory` exposed stale generated-state assumptions: direct histogram taps advertised ready/data metadata that could create a broken Avalon-ST adapter, and `mutrig_frame_deassembly` could resolve its RTL files from the caller root. |
| [BUG-019-R](#bug-019-r-emulator-systemverilog-module-header-imports-blocked-quartus-181-firmware-compile) | R | non-datapath-refactor | `common (generated FEB firmware compile with emulator Type0 enabled)` | fixed | FEB top Quartus compile, 2026-05-17 | `a9e2dbad9d52` | Quartus 18.1 rejected emulator SystemVerilog module-header `import` syntax even though the generated simulation path accepted it. |
| [BUG-020-R](#bug-020-r-mutrig-injector-running-cdc-was-timed-as-a-spare_clk_osc-setup-path) | R | non-datapath-refactor | `common (mode-3 injector support in fitted FEB firmware)` | fixed-with-residuals | FEB top TimeQuest closure, 2026-05-17 | `695b68441fc3`, this commit | The mode-3 injector already synchronized RUNNING into the oscillator clock domain, but the first synchronizer flop was not marked and the source-to-meta CDC crossing was not constrained, producing a false `spare_clk_osc` setup failure. |
| [BUG-021-I](#bug-021-i-hit_type3_upper-lost-ready-and-starved-run-control-idles) | I | hard stuck error | `common (generated FEB upload path with realistic downstream backpressure)` | fixed / sim-validated | FEB generated upload backpressure repro, 2026-05-18 | this commit | Qsys auto-inserted an Avalon-ST adapter between `data_path_subsystem.hit_type3_upper` and `upload_subsystem.upload_data` with `inUseReady=0` and `outUseReady=1`; a missed Type3 EOP parks `upload_pkt_mux` on in0 and starves both the `upload_sc` packet input and the run-control/K28.5 idle input. |
| [BUG-022-I](#bug-022-i-feb-board-top-wrapper-still-bound-dropped-legacy_firefly_mon-ports) | I | non-datapath-refactor | `common (any FEB v4 build after Phase B SC-hub rewire)` | fixed | FEB top Quartus map, 2026-05-18 | this commit | After Phase B dropped `legacy_firefly_bridge` from `debug_sc_system_v4.qsys`, `feb_system_v3_board_top.vhd` still bound 11 phantom `legacy_firefly_mon_*` formal ports on the regenerated entity, causing Quartus map Error 10349 at line 132. |
| [BUG-024-I](#bug-024-i-feb_system_v4-nested-subsystem-generic-snapshot-does-not-refresh-when-scifi_datapath_system_v4-leaf-ips-bump) | I | non-datapath-refactor | `common (any leaf-IP bump that propagates only to the subsystem, not to feb_system_v4.qsys)` | open | FEB v3 RESETTING-contract rebuild + on-board re-probe, 2026-05-19 | this checkpoint | `feb_system_v4.qsys` caches the leaf-IP generics for every nested subsystem instance; the 2026-05-19 `qsys-refresh` of `scifi_datapath_system_v4` did not propagate the new `VERSION_PATCH/BUILD/DATE` values for `mu3e_lvds_controller_0`, `histogram_statistics_0`, `mutrig_injector_0` into the SOF, and `qsys-validate` does not walk into the nested snapshot. The contract-fix RTL is in the SOF; only the firmware identity word is stale. |
| [BUG-025-I](#bug-025-i-region-b-mm_pipeline_lvds_csr_-bridges-past-offset-0x0000-are-csr-deaf-on-silicon-INVALID) | I | hard stuck error | `common (FEB SC-ring probing of every Region B slave behind a non-low mm_pipeline_lvds_csr_* bridge)` | **INVALID / false alarm** | FEB v3 on-board re-probe, 2026-05-19 18:02 | this checkpoint | NOT a bug. The "deaf" reads came from incorrect sc-byte addresses derived from a stale V4_REWIRE_SPEC.md table. Correct mapping is `sc-byte = avmm_port_byte + 0x10000`. Hist csr is at sc-byte 0x1A400 (sc-word 0x06900), not the previously-tabulated 0x17000. With corrected addresses all Region B slaves respond with valid UIDs ("HIST", "MINJ", "EMUT", "MTSP"). The bridges are fine; only BUG-024-I (qsys cache stale generics) remains real. |
| [BUG-026-H](#bug-026-h-hist-lock_key_ranges-keyed-on-tcc-instead-of-asic-ch-default-wrong-for-rate-plots) | H | non-datapath-refactor | `common (any FEB rate-plot regression that relies on LOCK_KEY_RANGES default)` | fixed | FEB v3 emulator rate-plot regression, 2026-05-19 19:01 | this commit | histogram_statistics_v2 default LOCK_KEY_RANGES update key was the TCC slice (Type0 data[35:21], Type1 data[29:17]) which gave a uniform distribution under a constant-rate emulator. Changed to {ASIC[2:0], CH[4:0]} (Type0 data[43:36], Type1 data[37:30]) so an N-channel rate plot has exactly N non-zero bins. Bumped hist 26.3.7.0519 -> 26.3.9.0519. |
| [BUG-027-I](#bug-027-i-hist-hwtcl-omitted-asi_type1_-ready-port-causing-timing_adapter-to-drop-type1-hits-silently) | I | hard stuck error | `common (any FEB build with the type1_up or type1_down hist source-select selected)` | fixed | FEB v3 emulator regression, 2026-05-19 19:01 | this commit | histogram_statistics_v2_hw.tcl declared type1_up and type1_down sink interfaces with readyLatency=0 but never added the asi_*_ready port to the interface port list. RTL drove asi_type1_up_ready / asi_type1_down_ready as entity outputs (rtl line 1012-1013) but qsys-generate dropped them from the wrapper. The auto-inserted avalon_st_adapter_025 timing_adapter on the snoop tap path then saw out_0_ready unconnected, defaulted to 0, never consumed its FIFO, and silently dropped every Type1 hit. The Type0 path uses hit_type0_tap2 (truly readyless) so no timing_adapter is inserted there. Fixed by adding the ready ports in hist hw.tcl and bumping 26.3.7.0519 -> 26.3.9.0519. |

## 2026-05-18

### BUG-022-I: FEB board-top wrapper still bound dropped legacy_firefly_mon ports

- First seen:
  - FEB v4 build Quartus map after the Phase B SC-hub rewire applied to `debug_sc_system_v4.qsys` and `scifi_datapath_system_v4.qsys` on 2026-05-18.
- Symptom:
  - `make flow_map` aborted at `Error (10349): VHDL Association List error at feb_system_v3_board_top.vhd(132): formal "legacy_firefly_mon_waitrequest" does not exist`.
  - The error repeated for the other 10 `legacy_firefly_mon_*` formals: `_burstcount`, `_writedata`, `_address`, `_write`, `_read`, `_byteenable`, `_debugaccess`, `_readdata`, `_readdatavalid`, `_response`.
- Root cause:
  - Phase B of the v4 rewire dropped `legacy_firefly_bridge` from `quartus_systems/debug_sc_system_v4.qsys`. The regenerated `feb_system_v4` entity therefore no longer exposed any `legacy_firefly_mon_*` ports.
  - `firmware_builds/systems/260518-feb-ok/syn/board_projects/fe_scifi_feb_v3/rtl/wrappers/feb_system_v3_board_top.vhd` still declared 10 internal `legacy_firefly_mon_*` signals on lines 73-82 and still mapped them onto the now-missing entity formals on lines 132-143.
  - VHDL association is a strict formal-match contract, so Quartus map failed on the very first formal it could not find on the entity.
- Fix:
  - Delete the 11 dead port-map associations on lines 132-143 of `feb_system_v3_board_top.vhd` and inline-remove the 10 now-unused signal declarations on lines 73-82.
- Evidence:
  - `make flow_map` after the wrapper edit prints `Quartus Prime Shell was successful. 0 errors, 1708 warnings`.
  - The deleted signals had no downstream consumer in the board top (no `read*` reads, no `write*` writes); their removal is a pure dead-code delete.
- Residuals:
  - Full `make flow` is running in the background to produce the new SOF; on-board probe via `script/probe_feb_ip_inventory.py --link 2` is the next gate after programming and the 20 s settle.

### BUG-021-I: hit_type3_upper lost ready and starved run-control idles

- First seen:
  - On-board FEB/SWB bring-up on 2026-05-17 after commit `c85daa06 [FIX] Close FEB generated Qsys firmware timing`.
  - SWB `LINK_LOCKED_LOW` did not set bits 2 or 6 for the new FEB SOF, while the golden FEB image restored SC immediately on the same hardware.
- Symptom:
  - SC scan on all 16 links timed out.
  - The broken generated top inserted `feb_system_v3_avalon_st_adapter` between `data_path_subsystem.hit_type3_upper` and `upload_subsystem.upload_data`.
  - The generated adapter had `inUseEmptyPort => 1`, `inUseReady => 0`, and `outUseReady => 1`, while the golden top wired `upload_data_ready` directly back to `data_path_subsystem_hit_type3_upper_ready`.
- Root cause:
  - The Qsys component export for `data_path_subsystem.hit_type3_upper` became a readyless, empty-bearing Avalon-ST source.
  - Platform Designer auto-inserted an Avalon-ST adapter that cannot backpressure the Type3 producer when `upload_pkt_mux` stalls or services other inputs.
  - When an in0 packet EOP is offered during downstream backpressure, `upload_pkt_mux` misses the EOP, remains in an in0 packet, and starves input 1 (`upload_sc`) plus input 2, which carries the run-control/K28.5 idle stream needed for SWB PMA lock.
- Reproduction:
  - `make -C firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/tb_int/upload_backpressure run MODE=broken`
  - The repro compiles the actual generated `feb_system_v3_avalon_st_adapter*.{v,sv}` and `feb_system_v3_upload_subsystem_upload_pkt_mux.sv` files from `syn/feb_system_v3/synthesis/submodules`.
  - Transcript: `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/tb_int/upload_backpressure/sim_upload_backpressure/broken/transcript`.
  - Marker: `UPLOAD_BACKPRESSURE_BROKEN_REPRO in0_valid_held=80 in0_ready_pulses=69 in1_sc_valid_held=11487 in1_sc_ready_pulses=0 sc_words=0 in2_ready_pulses=1 idle_words=1 missed_eop=10`.
  - The `upload_sc` packet is asserted after the Type3 adapter parks; it remains valid for 11487 cycles without a single ready pulse, and no SC words reach the upload output.
  - Direct-ready A/B model: `make -C firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/tb_int/upload_backpressure run MODE=direct`.
  - Direct-ready marker: `UPLOAD_BACKPRESSURE_FIXED_PASS in0_valid_held=234 in0_ready_pulses=72 in1_sc_ready_pulses=4 sc_words=4 sc_eop_accepted=1 in2_ready_pulses=11770 idle_words=11769 eop_accepted=9`.
  - The generated adapter also emits Intel's warning: `The downstream component is backpressuring by deasserting ready, but the upstream component can't be backpressured.`
- Fix:
  - `hist_post_splitter_0.USE_READY` is restored to `1` in the active system-local non-pipe and pipe Qsys copies, and in the root pipe copy so future generation does not drift back.
  - The active system-local Qsys copies also restore the missing `hit_stack_subsystem_0.hit_type3 -> hist_post_splitter_0.in` connection that was already present in the root v3 Qsys source.
  - Regenerated top evidence shows the upload-side adapter still drops the internal `empty` sideband, but it now has `inUseReady => 1` and drives `data_path_subsystem_hit_type3_upper_ready`; the ready loop is closed instead of source-readyless.
- Evidence:
  - Broken generated wrapper evidence: `/data2/firmware_backup_20260517_2350/feb_new_broken/feb_system_v3_synthesis/feb_system_v3.vhd` maps `upload_data_ready` to `avalon_st_adapter_out_0_ready` and the adapter has no input ready.
  - Golden wrapper evidence: `/data2/firmware_backup_20260517_2350/feb_golden/feb_system_v3_synthesis/feb_system_v3.vhd` wires `upload_data_ready` directly to `data_path_subsystem_hit_type3_upper_ready`.
  - Fixed Qsys generation stamp `upload_sc_ready_fix_20260518_003220` passed with `exit_code=0`, `error_count=0`, `fanout_guard=passed`, and `nshd_guard=passed`.
  - Fixed generated wrapper evidence: `syn/feb_system_v3/synthesis/feb_system_v3.vhd` has `inUseReady => 1`, `in_0_ready => data_path_subsystem_hit_type3_upper_ready`, and `out_0_ready => avalon_st_adapter_out_0_ready`.
  - Fixed generated data-path evidence: `syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem.vhd` connects `hit_stack_subsystem_0.hit_type3_ready` through `avalon_st_adapter_022` and `hist_post_splitter_0.in0_ready` to `hit_type3_upper_ready`.
  - Post-fix A/B broken marker remains: `UPLOAD_BACKPRESSURE_BROKEN_REPRO in0_valid_held=80 in0_ready_pulses=69 in1_sc_valid_held=11487 in1_sc_ready_pulses=0 sc_words=0 in2_ready_pulses=1 idle_words=1 missed_eop=10`.
  - Post-fix ready-adapter marker: `UPLOAD_BACKPRESSURE_FIXED_PASS in0_valid_held=234 in0_ready_pulses=72 in1_sc_ready_pulses=4 sc_words=4 sc_eop_accepted=1 in2_ready_pulses=11770 idle_words=11769 eop_accepted=9`.
- Residuals:
  - Board retest is still pending. The next gate is FEB top `make flow`, programming, 20 s settle, and the SC scan/link-lock matrix on links 2 and 6.

## 2026-05-17

### BUG-020-R: mutrig injector RUNNING CDC was timed as a spare_clk_osc setup path

- First seen:
  - FEB top full compile `quartus_compile_top_20260517_2041_sv_import_top_closure` on 2026-05-17 after generated Qsys and emulator parser issues were cleared.
- Symptom:
  - TimeQuest setup failed only on `spare_clk_osc` with `Slack=-1.028 ns`, `TNS=-1.028 ns`.
  - The violating path launched from `mutrig_injector_multiheader:mutrig_injector_0|runctl_state[3]~DUPLICATE` on the LVDS-derived `pll_sclk~PLL_OUTPUT_COUNTER|divclk` clock and latched at `run_active_osc_meta` on `spare_clk_osc`.
- Root cause:
  - `run_active_osc_meta` and `run_active_osc` were already a two-flop CDC synchronizer for the mode-3 oscillator injector, but this RUNNING crossing was not marked like the other mode-3 configuration synchronizers.
  - The SDC constrained the mode, interval, high-cycle, and async-reset CDC paths but missed the RUNNING source-to-first-flop crossing.
- Fix:
  - `mutrig_injector_multiheader.vhd` is now version `26.1.2` and applies synchronizer, preserve, no-merge, no-shift-register, and no-global-clock attributes to `run_active_osc_meta` and `run_active_osc`.
  - `mutrig_injector_multiheader.sdc` now constrains only `runctl_state[*]` to `run_active_osc_meta`.
  - `mutrig_injector_multiheader_hw.tcl` now packages version patch `2` with history entry `26.1.2.0517`.
- Evidence:
  - Raw IP commit: `charge_injection` `695b68441fc3`.
  - Qsys regeneration stamp `20260517_closure_cdc1` passed with `exit_code=0`, `error_count=0`, `fanout_guard=passed`, and `nshd_guard=passed`.
  - Generated HDL evidence contains `mutrig_injector_multiheader.vhd` `Version: 26.1.2`, `VERSION_PATCH := 2`, and the `run_active_osc_meta` synchronizer attributes.
  - Generated SDC evidence contains the `run_active_src` to `run_active_meta` false-path pair.
  - Full non-STP FEB top compile `quartus_compile_top_20260517_2136_cdc_top_closure` passed with `exit_code=0`, `error_count=0`, and generated `output_files/top.sof` plus `output_files/top.rbf`.
  - `output_files/top.sta.summary` has no negative slack or TNS. Worst setup is `lvds_firefly_clk` at `+0.264 ns`, and `spare_clk_osc` setup is now `+6.106 ns`.
  - `output_files/top.map.rpt` records `run_active_osc_meta` with `SYNCHRONIZER_IDENTIFICATION=FORCED_IF_ASYNCHRONOUS`, `DONT_MERGE_REGISTER=ON`, `PRESERVE_REGISTER=ON`, `AUTO_SHIFT_REGISTER_RECOGNITION=OFF`, and `GLOBAL_SIGNAL=OFF`.
- Residuals:
  - TimeQuest still reports the pre-existing board-project warning `Design is not fully constrained for setup/hold requirements`, caused by `47` unconstrained output ports and `65` unconstrained output-port paths.
  - The same unconstrained warning was present in the earlier failing compile log, so this fix closes the negative timing path without hiding that separate board-level output-delay cleanup item.

### BUG-019-R: emulator SystemVerilog module-header imports blocked Quartus 18.1 firmware compile

- First seen:
  - FEB top full compile on 2026-05-17 after clean generated Qsys was available for the direct histogram topology.
- Symptom:
  - Quartus Analysis & Synthesis failed on emulator RTL with a syntax error near `import`, expecting `;`.
  - The failure occurred before fitting, so the generated FEB firmware could not reach the timing-closure gate.
- Root cause:
  - The emulator sources used SystemVerilog module-header package imports accepted by the simulation flow, but Quartus Prime 18.1 Standard rejected that parser form.
  - The generated Qsys firmware path therefore exposed a tool-version compatibility issue that the previous generated simulation path did not catch.
- Fix:
  - The package imports were moved to compilation-unit scope in:
    - `rtl/frontend/frontend_trigger_engine.sv`
    - `rtl/frontend/frontend_ticket_distributor.sv`
    - `rtl/frontend/frontend_bkg_generator.sv`
    - `rtl/backend_mutrig/be_mutrig_lane_type0_emit.sv`
    - `rtl/backend_mutrig/be_mutrig_frame_assembler.sv`
- Evidence:
  - Raw IP commit: `emulator_mutrig` `a9e2dbad9d52`.
  - Generated FEB Qsys submodules contain the import-compatible emulator RTL.
  - Full non-STP FEB top compile `quartus_compile_top_20260517_2136_cdc_top_closure` passed Analysis & Synthesis, Fitter, Assembler, and TimeQuest with `exit_code=0`, `error_count=0`.
  - The prior Quartus `import` syntax error is absent from the passing compile log.
- Residuals:
  - This is a syntax/tool-compatibility RTL fix. It does not change the emulator packet, timestamp, or injection behavior verified by the generated-Qsys histogram simulations.

### BUG-018-I: clean FEB Qsys generation could drift through hidden adapters and caller-relative IP roots

- First seen:
  - FEB clean Qsys regeneration on 2026-05-17 while preparing the fitted firmware build from a cleared generated-output directory.
- Symptom:
  - `qsys-generate --clear-output-directory` exposed hidden generated-state assumptions instead of reliably producing a fresh FEB system.
  - Platform Designer could infer a broken Avalon-ST adapter on direct histogram observation paths, and `mutrig_frame_deassembly` could report missing RTL files when sourced through an isolated catalog/caller directory.
- Root cause:
  - The direct histogram Type0/Type1 observation sinks are passive taps, but the package still advertised ready ports and symbolic data-width metadata that could cause a ready/data adapter to be inserted.
  - `mutrig_frame_deassembly_hw.tcl` still depended on `info script` or caller-relative resolution in cases where Platform Designer sourced the package without a stable script path.
- Fix:
  - `histogram_statistics_v2_hw.tcl` now publishes numeric Avalon-ST widths and removes ready ports from the direct Type0 lane and Type1 up/down observation sinks.
  - `mutrig_frame_deassembly_hw.tcl` now searches the script directory, `MU3E_IP_CORES_ROOT/mutrig_frame_deassembly`, `[pwd]`, and `[pwd]/mutrig_frame_deassembly`, and only accepts a candidate containing `rtl/frame_rcv_ip.vhd`.
  - `script/generate_feb_system_v3.sh` now resolves the active worktree root, exports `MU3E_IP_CORES_ROOT`, runs Qsys generation with `--clear-output-directory`, and hard-fails if the generated fanout or `N_SHD=128` guards drift.
  - Generated evidence is ignored: the root `.gitignore` now also ignores top-level `quartus_systems/*.sopcinfo`.
- Evidence:
  - Raw IP commits: `histogram_statistics` `4a293ca1d0e8` and `mutrig_frame_deassembly` `9fa5856d58c4`.
  - Qsys regeneration stamp `20260517_closure_cdc1` passed with `exit_code=0`, `error_count=0`, `fanout_guard=passed`, and `nshd_guard=passed`.
  - Generated `feb_system_v3/synthesis/submodules/hit_type0_fanout8.sv` contains `Version : 26.0.1` and lane-qualified timestamp logic.
  - Generated `feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem.vhd` keeps `BYTE_STREAM_ENABLE => false` on the emulator and `DEBUG_LEVEL => 0` for production synthesis.
  - Current direct X11 Qsys GUI open check `feb_system_v3_qsys_edit_20260517_gui_x11_fixedenv_current.status` used `DISPLAY=127.0.0.1:10.0`, `XAUTHORITY=/home/yifeng/.Xauthority`, stayed alive after 10 seconds, and recorded `error_count=0`.
  - Full non-STP FEB top compile `quartus_compile_top_20260517_2136_cdc_top_closure` passed with `exit_code=0`, `error_count=0`, `output_files/top.sof`, and `output_files/top.rbf`.
- Residuals:
  - The generated Qsys and Quartus logs/status/bitstreams are intentionally ignored evidence artifacts. Source Qsys/Tcl and raw IP commits carry the reproducible state.

### BUG-017-H: DISLIN plot renderers could report passing artifacts that were not the requested files

- First seen:
  - FEB generated-Qsys Type1 plot review on 2026-05-17 while visually checking the periodic and header-sync DISLIN figures.
- Symptom:
  - The Type1 metadata overlay could show the wrong peak because the renderer read the metadata CSV `bin` column instead of `latency_cycles`.
  - For long report paths, DISLIN silently truncated the output filename and produced an extensionless PDF-like artifact while the wrapper still printed the requested `.png`/`.pdf` names as a pass.
- Root cause:
  - `type1_delay_dislin.c` and `type1_header_sync_dislin.c` indexed `tokens[11]` instead of the `latency_cycles` field at `tokens[10]`.
  - The render wrappers passed the final long evidence path directly into `setfil()` and did not assert that the requested output files existed and were nonempty.
- Fix:
  - Both Type1 renderers now read the metadata latency from `tokens[10]`.
  - The Type0, Type1 periodic, and Type1 header-sync wrapper scripts now render into short `/tmp` paths, verify the DISLIN output exists, and only then copy to the long evidence path.
  - The wrappers build process-unique helper binaries and temp paths so parallel render jobs cannot collide.
- Evidence:
  - `gcc -O2 -Wall -Wextra -std=c11` compile checks passed for the Type1 renderers after the metadata-column fix.
  - Rerendered Qsys Type1 periodic plots for both banks:
    - `qsys_type1_delay_20260517_fanoutphase1_periodic_type1_up_qsys_periodic.png/.pdf`
    - `qsys_type1_delay_20260517_fanoutphase1_periodic_type1_down_qsys_periodic.png/.pdf`
  - Rerendered Qsys header-sync plots for both banks:
    - `qsys_type1_delay_20260517_fanoutphase1_hsyncup_type1_up_qsys_header_sync_910cyc.png/.pdf`
    - `qsys_type1_delay_20260517_fanoutphase1_hsyncdown_type1_down_qsys_header_sync_910cyc.png/.pdf`
  - Rerendered Type0 max-rate plot:
    - `hist_direct_v3_type0_rate_max_20260517_195711_type0_rate_dislin.png/.pdf`
  - Visual inspection confirmed the header-sync CSR and metadata overlays share the same 896-cycle bin for both Type1 banks, and the periodic plots remain within the rbCAM `[0,2000]` cycle window.
- Residuals:
  - Old extensionless truncated artifacts are ignored report evidence and are not used as passing artifacts after this fix.

### BUG-016-R: hit_type0_fanout8 did not lane-phase the encoded MuTRiG timestamp

- First seen:
  - Generated-Qsys header-sync Type1 gate on 2026-05-17 with internal trigger period 910 cycles.
- Symptom:
  - The upper-bank header-sync run conserved hits but did not form a delta-function latency distribution.
  - Raw metadata showed four lanes entering consecutive cycles with the same encoded hit timestamp, producing latencies 927, 928, 929, and 930 cycles instead of one constant value.
- Root cause:
  - The build-local `hit_type0_fanout8` modeled eight physical ASIC lanes by rewriting ASIC/channel metadata, but left the copied Type0 TCC/ECC timestamp identical on every fanout lane.
  - The MTS input serializes bank lanes over consecutive cycles, so header-sync stimuli require the encoded MuTRiG timestamp to be lane-phase-qualified before the histogram ingress checkpoint.
- Fix:
  - `hit_type0_fanout8.sv` now advances the encoded Type0 TCC/ECC fields by the lane phase using PRBS15 stepping helpers, while still rewriting the ASIC metadata bits for each lane.
  - `hit_type0_fanout8_hw.tcl` now packages the lane-qualified timestamp behavior as version `26.0.1.0517`.
  - `update_dualport_histogram_topology.tcl` now re-adds the active Qsys fanout instance at that version and reconnects its eight outputs during topology regeneration.
  - The topology still hard-enforces `emulator_mutrig_qsys_inst BYTE_STREAM_ENABLE=false`.
- Evidence:
  - RTL compile: `vlog -sv -work /tmp/hit_type0_fanout8_vlog_work .../hit_type0_fanout8.sv` completed with `Errors: 0, Warnings: 0`.
  - RTL style check passed: `rtl_style_check.py .../hit_type0_fanout8.sv`.
  - Qsys regeneration stamp `20260517_fanoutphase1` passed DEBUG0 and DEBUG2 validation plus synthesis/simulation generation with `exit_code=0`, `error_count=0`.
  - Direct GUI open still exited early on the forwarded X11 display with one AWT/X11 error, but the generation hook retried under Xvfb and recorded `gui_mode=xvfb`, `early_exit_code=0`, `early_error_count=0`.
  - Generated Qsys checks passed after regeneration: `ASIC_TOPOLOGY_16_ABSENT_OK`, `QSYS_N_SHD_128_OK`, `CODE_N_SHD_256_ABSENT_OK`, and `BYTE_STREAM_FALSE_OK`.
  - Generated-Qsys Type1 periodic sweep over 10 ms RUNNING passed for `type1_up` and `type1_down` at 10 kHz, 100 kHz, 500 kHz, and 1 MHz:
    - 10 kHz: `expected_hits=400`, `meta=400`, `bin_sum=400`, `last_total_sum=400`, `dropped=0`.
    - 100 kHz: `expected_hits=4000`, `meta=4000`, `bin_sum=4000`, `last_total_sum=4000`, `dropped=0`.
    - 500 kHz: `expected_hits=20000`, `meta=20000`, `bin_sum=20000`, `last_total_sum=20000`, `dropped=0`.
    - 1 MHz: `expected_hits=40000`, `meta=40000`, `bin_sum=40000`, `last_total_sum=40000`, `dropped=0`.
  - Generated-Qsys header-sync runs passed for both Type1 banks with `pulses=1373`, `expected_hits=5492`, `meta=5492`, `bin_sum=5492`, `last_total_sum=5492`, `dropped=0`, and `fail_count=0`.
  - Upper-bank metadata after the fix shows the lane phase applied before ingress: ASIC1/2/3/0 entered on consecutive cycles with hit timestamps 910/911/912/913 and all raw latencies 927 cycles.
  - Header-sync DISLIN plots for upper and lower banks show a single CSR/meta bin at 896 cycles, with `nonzero=1/256` and `100.000%` of hits in that bin.
  - Type0 max-rate generated-RTL plot evidence was rerun after the Qsys regeneration: `type0_rate_1000k_allch` passed with `expected=80000`, `offered=80000`, `total=80000`, `bin_sum=80000`, `dropped=0`, and ten 1 ms in-RUNNING readouts of 8000 hits each.
- Residuals:
  - The direct forwarded X11 GUI path still fails in this shell, but the required GUI-open attempt is no longer hidden: the wrapper records the direct failure and verifies a successful Xvfb `qsys-edit` launch before generation proceeds.

### BUG-015-H: Type1 delay plot evidence did not lock the one-channel header-sync delta contract

- First seen:
  - FEB generated Type1 latency evidence review on 2026-05-17 after the initial four-rate Type1 plot used a virtual short-frame latency spread.
- Symptom:
  - There was no DISLIN Type1 latency figure matching the requested header-sync mode where the one-channel-per-ASIC delay should collapse to a delta function.
  - The previous Type1 latency plot checked that the plotted range stayed inside rbCAM `[0,2000]` cycles, but it did not prove that the CSR delay bin matched an ingress per-hit metadata checkpoint.
  - A plotted delta could be hidden by the CSR peak marker, making the checkpoint overlay hard to inspect visually.
- Root cause:
  - The direct histogram sweep emitted CSR bins and per-hit metadata, but the delay-sweep mode was still shaped for a virtual MuTRiG short-frame spread instead of the header-synced timestamp mode requested for the one-channel-per-ASIC check.
  - The renderer drew the black peak marker over a single-bin CSR/meta delta.
- Fix:
  - `tb_hist_direct_v3.sv` now runs `type1_delay_sweep` as the one-channel-per-ASIC header-sync timestamp mode for Type1-up and Type1-down at `10 kHz`, `100 kHz`, `500 kHz`, and `1 MHz` over 10 ms RUNNING.
  - The header-sync mode drives the Type1 timestamp sideband with a declared fixed ingress latency of 27 8 ns cycles against a 910-cycle header-sync frame model; it does not rescale or rewrite readback bins after the CSR read.
  - The sweep accumulates the 1 ms in-RUNNING CSR delay-bin readbacks and the accepted-hit metadata bins, then hard-fails unless metadata and CSR totals match exactly and the bin distribution matches exactly or by a constant bin offset.
  - For header-sync mode the sweep additionally hard-fails unless both metadata and CSR are single-bin deltas.
  - `type1_delay_dislin.c` overlays the ingress metadata checkpoint as a red marker beside the blue CSR bin, keeps the green rbCAM window markers at 0 and 2000 cycles, and renders PNG/PDF with fixed x-axis range `[-1000,3096]` cycles.
- Evidence:
  - `tb_int/hist_dualport/run_hist_dualport.sh type1_delay_sweep`, stamp `hist_direct_v3_type1_delay_sweep_20260517_135600`, passed with `pass_count=8`, `fail_count=0`, `Errors=0`, `Warnings=2`.
  - The eight plotted one-channel-per-ASIC cases passed with declared/offered/accepted/total counts:
    - 10 kHz Type1-up/down: 400 hits per bank.
    - 100 kHz Type1-up/down: 4000 hits per bank.
    - 500 kHz Type1-up/down: 20000 hits per bank.
    - 1 MHz Type1-up/down: 40000 hits per bank.
  - Every `META_CHECK` line reported metadata and CSR totals equal, `meta_bins=[0,0]`, `csr_bins=[0,0]`, `exact=1`, and `offset_bins=0`.
  - The summary CSV reports `active_asics=4` for each Type1 bank, so Type1-up covers ASICs 0..3 and Type1-down covers ASICs 4..7; the FEB still has 8 ASICs total.
  - DISLIN rendered Type1-up and Type1-down PNG/PDF with `Warnings: 0`:
    - `hist_direct_v3_type1_delay_sweep_20260517_135600_type1_up_header_sync_delay_dislin.png`
    - `hist_direct_v3_type1_delay_sweep_20260517_135600_type1_down_header_sync_delay_dislin.png`
  - Generated CSV, log, PNG, PDF, and Questa work evidence remains ignored by the `hist_direct_v3_*` and `dislin_work/` gitignore rules.
- Residuals:
  - This is a generated-RTL evidence/harness fix. No raw RTL datapath defect was exposed because both Type1 banks conserve the declared hit counts, the metadata checkpoint and CSR bin match exactly, and the header-sync latency collapses to a delta inside the rbCAM window.

### BUG-014-I: FEB IP packaging could drift back to 256 subheaders

- First seen:
  - FEB/SWB frame-shape audit on 2026-05-17 after the board report that SWB saw 256 subheaders.
- Symptom:
  - Active regenerated FEB v3 systems had `N_SHD=128`, but the raw `feb_frame_assembly` HDL generic and `_hw.tcl` package default still said 256.
  - The FEB rbCAM package defaulted to 128 but still allowed Qsys `N_SHD` selections up to 256.
- Root cause:
  - The system Tcl recipes were carrying the SciFi/FEB convention as an integration override instead of making the FEB IP packages reject a non-128 frame contract.
  - A stale cache, missed override, or manual Qsys edit could therefore reintroduce a 256-subheader FEB source even when the active build scripts intended 128.
- Fix:
  - `feb_frame_assembly_hw.tcl` now defaults `N_SHD` to 128, restricts the GUI range to `{128}`, and emits a Platform Designer validation/elaboration error for any other value.
  - `feb_frame_assembly.vhd` now also defaults the generic to 128 so direct HDL instantiation does not silently inherit the old 256-subheader profile.
  - `ring_buffer_cam_hw.tcl` now hard-locks FEB rbCAM generation to `N_SHD=128` in validation/elaboration and exposes only `{128}` in the Qsys GUI range.
  - `script/generate_qsys_debug_pair.sh` now has a make-facing Qsys source guard that aborts generation if any active FEB Qsys source contains an `N_SHD` parameter other than 128.
- Evidence:
  - Guarded Qsys regeneration stamp `20260517_nshd128_guard_asic8` passed: DEBUG0 validate/generate and DEBUG2 validate/generate all reported `exit_code=0`, `error_count=0`.
  - The guard log `scifi_datapath_system_v3_nshd128_guard_20260517_nshd128_guard_asic8.log` is empty, meaning no active FEB Qsys source contained a non-128 `N_SHD`.
  - The regenerated `scifi_datapath_system_v3.sopcinfo` contains ten `N_SHD` parameters and all ten read back `value=128`.
  - The regenerated `synthesis/submodules/feb_frame_assembly.vhd` and `simulation/submodules/feb_frame_assembly.vhd` both default `N_SHD` to 128.
- Residuals:
  - A plain in-memory `qsys-script validate_system` experiment did not return nonzero for a scripted `N_SHD=256` parameter set, so the generation wrapper guard remains part of the required hard gate in addition to the component `_hw.tcl` validation.

### BUG-013-H: direct histogram harness modeled 16 active ASICs instead of the FEB's 8-ASIC topology

- First seen:
  - FEB generated histogram simulation review on 2026-05-17 after checking the physical source model against the FEB topology.
- Symptom:
  - The direct histogram harness declared `N_ASICS=16`, so the 10 ms, 100 kHz smoke expected 16,000 hits for Type0 and for each Type1 bank.
  - The Type0 max-rate DISLIN plot also normalized the 1 ms ping-pong readback by 16 ASICs and expected 16,000 hits per 1 ms read.
- Root cause:
  - The harness conflated the 8 Type0 lane/ASIC sources and the two MTS bank modes into one 16-source logical model.
  - The physical FEB topology has 8 ASICs total: ASICs 0..3 in the upper bank and ASICs 4..7 in the lower bank. Type1-up and Type1-down each exercise only 4 active ASICs.
- Fix:
  - `tb_hist_direct_v3.sv` now models `N_TYPE0_ASICS=8` for Type0 and `N_TYPE1_BANK_ASICS=4` for each Type1 bank.
  - Type1-down stimuli now use global ASIC IDs 4..7, while Type1-up uses 0..3.
  - The summary CSV now records `active_asics`, and the DISLIN renderer derives its per-ASIC normalization and expected hits/read from that field instead of a hardcoded 16.
- Evidence:
  - Corrected generated-RTL smoke on 2026-05-17, stamp `hist_direct_v3_smoke_20260517_130642`, passed with `pass_count=5`, `fail_count=0`, `Errors=0`, `Warnings=2`.
  - Smoke transcript counts:
    - `CASE_PASS type0_rate_100k_onech expected=8000 offered=8000 total=8000`
    - `CASE_PASS type1_up_rate_100k_onech expected=4000 offered=4000 total=4000`
    - `CASE_PASS type1_up_latency_100k_onech expected=4000 offered=4000 total=4000`
    - `CASE_PASS type1_down_rate_100k_onech expected=4000 offered=4000 total=4000`
    - `CASE_PASS type1_down_latency_100k_onech expected=4000 offered=4000 total=4000`
  - Corrected Type0 max-rate run, stamp `hist_direct_v3_type0_rate_max_20260517_130705`, passed with `CASE_PASS type0_rate_1000k_allch expected=80000 offered=80000 total=80000 per_asic_rate_hz=1000000.000`.
  - The interval CSV has ten in-RUNNING 1 ms ping-pong reads, each with `last_total=8000`, `bin_sum=8000`, and `last_dropped=0`.
  - DISLIN rendered PNG/PDF with `Warnings: 0`; the figure title now reports `active ASICs=8`, and the caption reports `8000 hits/read expected, total=80000, bin_sum=80000, dropped=0, PASS`.
- Residuals:
  - This is a harness/evidence bug, not an RTL datapath bug. The corrected generated-RTL simulation still shows no hit loss in Type0 rate, Type1 rate, or Type1 latency modes at the declared stimulus rates.

### BUG-012-H: FEB generated histogram smoke did not require declared hit counts for all Type0/Type1 modes

- First seen:
  - FEB generated histogram simulation review on 2026-05-17 while checking Type0 rate and Type1 rate/latency behavior from the regenerated `scifi_datapath_system_v3/simulation/submodules` RTL.
- Symptom:
  - The previous `tb_int/hist_dualport` smoke did not cover the Type1-down rate and Type1-down latency paths.
  - The pass condition compared internal totals against offered hits, but did not independently require the declared 10 ms, 100 kHz, one-random-channel-per-ASIC stimulus count.
  - The compile path used the repo-local raw `histogram_statistics/rtl` files instead of the generated FEB simulation RTL, so it was not a strict check of the regenerated Qsys `simulation/` tree.
- Root cause:
  - The smoke was originally a focused dual-port histogram datapath check. It did not encode the full FEB evidence contract for Type0 rate, Type1 rate, Type1 latency, and both Type1 MTS banks.
  - The old `nohit` mode allowed zero-hit cases to be treated as valid, which made the harness too permissive for this bug class.
- Fix:
  - `tb_int/hist_dualport/run_hist_dualport.sh` now compiles the regenerated FEB RTL from `quartus_systems/scifi_datapath_system_v3/simulation/submodules`.
  - `tb_hist_direct_v3.sv` now computes the exact expected hit count from `CLK_HZ`, `run_cycles`, `N_ASICS`, and `rate_hz`, and fails if expected, offered, accepted, interval total, or bin sum disagree.
  - The 10 ms smoke now runs five 100 kHz one-random-channel-per-ASIC cases: Type0 rate, Type1-up rate, Type1-up latency, Type1-down rate, and Type1-down latency.
  - The zero-hit mode was removed from this runner so a missing injection cannot pass as a valid directed smoke.
- Evidence:
  - `script/generate_qsys_debug_pair.sh` rerun on `quartus_systems/scifi_datapath_system_v3.qsys` with stamp `20260517_strict_hitcount_gui_xvfb2`: DEBUG0 validate/generate and DEBUG2 validate/generate all reported `exit_code=0`, `error_count=0`.
  - Regenerated HDL evidence: `synthesis/scifi_datapath_system_v3.vhd` contains `DEBUG_LEVEL => 0`, `simulation/scifi_datapath_system_v3.vhd` contains `DEBUG_LEVEL => 2`, and the generated arb submodule under `simulation/submodules/` contains eight lane instances with `DEBUG_LEVEL => 2`.
  - `tb_int/hist_dualport/run_hist_dualport.sh smoke` passed on 2026-05-17 after regeneration, with `RUN_CYCLES=1250000`, `INTERVAL_CYCLES=125000`, and seed `20260517`.
  - The smoke transcript reported:
    - `CASE_PASS type0_rate_100k_onech expected=16000 offered=16000 total=16000`
    - `CASE_PASS type1_up_rate_100k_onech expected=16000 offered=16000 total=16000`
    - `CASE_PASS type1_up_latency_100k_onech expected=16000 offered=16000 total=16000`
    - `CASE_PASS type1_down_rate_100k_onech expected=16000 offered=16000 total=16000`
    - `CASE_PASS type1_down_latency_100k_onech expected=16000 offered=16000 total=16000`
  - Questa summary: `pass_count=5`, `fail_count=0`, `Errors=0`, `Warnings=2`.
- Residuals:
  - No raw RTL defect was exposed by the stricter generated-FEB simulation; the fix is the harness/evidence contract and generated-RTL compile path.
  - The physical active-source count in this original evidence was later corrected under BUG-013-H; the 16-source counts above are retained here as the historical transcript from the first strict-hitcount checkpoint.

### BUG-011-I: Make-side Qsys generation did not produce the DEBUG2 synthesis DUT tree for tb_int

- First seen:
  - FEB v3 realistic `tb_int` setup work on 2026-05-17 while preparing to use generated Qsys synthesis HDL as the DUT.
- Symptom:
  - The Make-side Qsys flow generated the production `synthesis/` tree only, so `tb_int` could not consume a generated DEBUG_LEVEL=2 synthesis HDL tree from a sibling `simulation/` directory.
  - Early dual-generation attempts also exposed a stale `arb_hit_type0` package binding: `build_arb_hit_type0_supercore_qsys.tcl` requested version `26.5.0.0511`, while the active raw IP package is `26.6.0.0512`.
- Root cause:
  - The board-project Make object delegated to a single-target `qsys-generate.sh`; DEBUG_LEVEL was not part of that generation contract.
  - The arb supercore Tcl hardcoded both the child IP version and DEBUG_LEVEL, preventing the same raw Qsys source from being regenerated deterministically for DEBUG0 synthesis and DEBUG2 simulation-DUT HDL.
- Fix:
  - The Make-side `qsys-generate.sh` now routes this system through `script/generate_qsys_debug_pair.sh`.
  - The wrapper validates and generates the same Qsys twice: `synthesis/` with DEBUG_LEVEL=0 and `simulation/` with DEBUG_LEVEL=2, where `simulation/` is populated from a second `--synthesis=VHDL` generation rather than Platform Designer simulation models.
  - The wrapper launches `qsys-edit` in the background before generation, normalizes forwarded `localhost:*` displays for Java, and retries under a private Xvfb display if the forwarded X11 path exits early with an AWT/X11 error.
  - `build_arb_hit_type0_supercore_qsys.tcl` now accepts `::debug_level` or `DEBUG_LEVEL`, uses system-relative paths, and binds `arb_hit_type0` version `26.6.0.0512`.
- Evidence:
  - Make-facing invocation on `quartus_systems/arb_hit_type0_supercore.qsys`, stamp `20260517_make_object_dual_probe`: DEBUG0 and DEBUG2 `validate_system` both reported `exit_code=0`, `error_count=0`; both `qsys-generate` runs reported `exit_code=0`, `error_count=0`.
  - Generated arb evidence: `quartus_systems/arb_hit_type0_supercore/synthesis/arb_hit_type0_supercore.vhd` contains eight `DEBUG_LEVEL => 0` lane generics, while `quartus_systems/arb_hit_type0_supercore/simulation/arb_hit_type0_supercore.vhd` contains eight `DEBUG_LEVEL => 2` lane generics.
  - Make-facing invocation on `quartus_systems/scifi_datapath_system_v3.qsys`, stamp `20260517_make_object_scifi_dual`: DEBUG0 and DEBUG2 `validate_system` both reported `exit_code=0`, `error_count=0`; both `qsys-generate` runs reported `exit_code=0`, `error_count=0`.
  - Generated datapath evidence: `quartus_systems/scifi_datapath_system_v3/synthesis/scifi_datapath_system_v3.vhd` contains `DEBUG_LEVEL => 0`, and `quartus_systems/scifi_datapath_system_v3/simulation/scifi_datapath_system_v3.vhd` contains `DEBUG_LEVEL => 2`; the generated arb submodule under `simulation/submodules/` also contains eight `DEBUG_LEVEL => 2` lane generics.
  - GUI retry evidence on `quartus_systems/scifi_datapath_system_v3.qsys`, stamp `20260517_strict_hitcount_gui_xvfb2`: the forwarded X11 launch failed with one Java AWT/X11 error, then the Xvfb retry status recorded `gui_mode=xvfb`, `early_exit_code=0`, and `early_error_count=0`.
- Residuals:
  - In this shell the forwarded X11 display still fails for Quartus Java/AWT, so the reliable automated GUI-open path is the Xvfb retry. CLI validation and generation are still zero-error.

## 2026-05-14

### BUG-010-H: FEB/SWB corun smoke did not model the declared 128-subheader frame

- First seen:
  - FEB/SWB corun UVM harness review after the RN.BASIC cosim frame-format fix, 2026-05-14.
- Symptom:
  - The smoke frame declared `subheader_count = 128` in the frame header but emitted only one K28.7 subheader before the hit payload.
  - The FEB and OPQ monitors reconstructed true hit timestamps but did not independently compare the seen subheader count against the declared frame count.
- Root cause:
  - The older corun smoke was built as a minimal hit timestamp path check, not as a strict Mu3e wire-frame shape check.
  - That left a harness blind spot: a one-subheader trace could still produce a valid reconstructed timestamp and pass even though the frame was not shaped like the validated RN.BASIC cosim frame.
- Fix:
  - `tb_int/feb_swb_corun/uvm/tb_top.sv` now drives all 128 subheaders on both FEB and OPQ synthetic frame sources, with the hit payload only under the matching subheader timestamp.
  - `tb_int/feb_swb_corun/uvm/feb_swb_corun_uvm_pkg.sv` now tracks declared and seen subheader counts and reports `FEB_SWB_FRAME` errors on mismatch.
  - The corun run window was extended to 4 us so the enlarged frames can drain before the scoreboard summary.
- Evidence:
  - `make smoke` in `tb_int/feb_swb_corun/uvm` passed on 2026-05-14.
  - The smoke summary reported `feb=270`, `opq_debug=2`, `opq_payload=270`, `dma=2`, `dma_payload=2`, `missing_opq=0`, `missing_dma=0`, `ts_mismatch=0`, `true_ts_mismatch=0`, `UVM_ERROR=0`, and `UVM_FATAL=0`.
- Residuals:
  - This closes the synthetic FEB/SWB corun harness blind spot only. Board closure still requires STP proof through SWB OPQ and RDMA.

### BUG-009-H: FEB STP generator used whole-vector probes that synthesized into partial SignalTap connections

- First seen:
  - FEB `phase4_pre_hss_gap` SignalTap map gate for `v3_pretest-260511-emutype0-dualport-260512`, 2026-05-14.
- Symptom:
  - The old STP passed a pre-synthesis Node Finder check, but Quartus map reported a partially connected SignalTap instance.
  - Prior map evidence showed `phase4_pre_hss_gap_lvds` connected to only 125 of 171 requested inputs; 46 full-vector sources such as `selected_out_0_data` and `aso_hist_data` were missing after synthesis.
- Root cause:
  - The STP used whole-vector module-port probes. Quartus could resolve them in the pre-synthesis namespace, but did not preserve those aggregate vector names as post-synthesis debug sources.
  - A rejected alternative using generated Qsys architecture signal names produced 299 probes but Node Finder found 0 of them, proving those names are not valid in the STP pre-synthesis observable set.
- Fix:
  - `script/generate_phase4_pre_hss_gap_stp.py` now emits bit-expanded instance-port probes for each Avalon-ST field.
  - Probe groups cover arbiter selected output, mux-to-MTS, MTS type1 to histogram pre-input, pre-rbCAM histogram input, post-rbCAM CDC output, and histogram selector output.
  - The trigger is the bit-expanded pre-synthesis instance-port path for `histogram_ingress_bridge_0|aso_hist_valid`.
- Evidence:
  - Node Finder live check:
    `phase4_pre_hss_gap_nodes_livecheck_20260514_portbits.md`, `probes total=299 found=299 missing=0 errors=0`.
  - STP import completed with 0 errors and 0 warnings.
  - Map-only gate:
    `output_files_stp_phase4_pre_hss_gap/top_stp_phase4_pre_hss_gap.map.rpt` reports
    `Info (35024): Successfully connected in-system debug instance "phase4_pre_hss_gap_lvds" to all 631 required data inputs, trigger inputs, acquisition clocks, and dynamic pins`.
  - Full compile synthesis rerun repeated the same `Info (35024)` before entering fitter.
  - Full compile for revision `top_stp_phase4_pre_hss_gap` completed on 2026-05-14 with Quartus `0 errors, 1568 warnings`.
  - Fitter was successful; assembler was successful with 0 errors and 0 warnings.
  - Generated SOF:
    `syn/board_projects/fe_scifi_feb_v3/output_files_stp_phase4_pre_hss_gap/top_stp_phase4_pre_hss_gap.sof`,
    size `12746320` bytes,
    SHA256 `cf2dab3903da0455221bfa1b8ea06a2e7006c4a20fca28b9f5973673961fc881`.
  - STA setup corners:
    Slow 1100 mV 85 C `-0.440 ns`,
    Slow 1100 mV 0 C `-0.241 ns`,
    Fast 1100 mV 85 C `+0.510 ns`,
    Fast 1100 mV 0 C `+0.694 ns`.
  - This meets the FEB iterative-debug load gate of at least 2 passing corners, but it is not production timing closure.
- Residuals:
  - Board SignalTap capture is still pending.
  - The STP capture must still be naysayed against frame marker count, subheader count, hit count, timestamp reconstruction, spatial/channel distribution, pre/post rbCAM delay, and SWB OPQ/RDMA continuity before it can close the board datapath.

### BUG-008-I: FEB top Qsys exported a stale pulse_out_conduit interface

- First seen:
  - FEB top-level Qsys generation and wrapper compile for `v3_pretest-260511-emutype0-dualport-260512`, 2026-05-14.
- Symptom:
  - Regenerated top/wrapper surfaces still referenced `pulse_out_conduit` even though the active datapath/runctrl Qsys no longer exports that conduit.
  - The stale exported interface made the generated FEB wrapper inconsistent with the current run-control management host wiring.
- Root cause:
  - The top-level patch flow updated the datapath component and CSR address map, but did not remove the obsolete exported conduit from the legacy top Qsys export list.
  - Local wrapper files retained stale `pulse_out_conduit_pulse => open` associations after the Qsys interface disappeared.
- Fix:
  - `script/update_feb_system_v3_dualport_version.tcl` now removes the stale exported interface while rewriting the top metadata and address map.
  - The active `syn/feb_system_v3.qsys` no longer exports `pulse_out_conduit`.
  - Generated local wrappers were cleaned so the removed conduit is not instantiated as an open port.
- Evidence:
  - Qsys generation after the CSR-map/export fix completed with `exit_code=0` and `error_count=0`.
  - FEB STP map-only gate completed Analysis & Synthesis with 0 errors on 2026-05-14.
  - FEB full compile for revision `top_stp_phase4_pre_hss_gap` completed with Quartus `0 errors, 1568 warnings`; the remaining slow-corner setup failures are recorded under BUG-009-H as debug-image timing residuals.
- Residuals:
  - Production timing closure is still open; the current STP image is accepted only for iterative board debug.

### BUG-007-I: FEB top Qsys carried stale eight-emulator CSR map

- First seen:
  - FEB top-level Qsys generation for `v3_pretest-260511-emutype0-dualport-260512`, 2026-05-14.
- Symptom:
  - `qsys-generate` reported address-map legality errors for `emulator_mutrig_1..7.csr` at 0x40-byte strides.
  - `dbg_mm2runctrl_0.csr` overlapped the stale `emulator_mutrig_7.csr` range.
- Root cause:
  - The active datapath Qsys component is `scifi_datapath_system_v3` version `3.0.5.0512` with one `emulator_mutrig_qsys_inst` CSR aperture.
  - The top-level `control_path_subsystem.AUTO_AVMM_PORT_ADDRESS_MAP` still listed the older eight-emulator map and the `data_path_subsystem` module still requested version `3.0.4.512`.
- Fix:
  - `script/update_feb_system_v3_dualport_version.tcl` now rewrites both the top metadata and the top-level datapath binding/address map.
  - `data_path_subsystem_emulator_mutrig_qsys_inst.csr` is mapped to `0x2000..0x2100`.
  - `data_path_subsystem_dbg_mm2runctrl_0.csr` remains at `0x2200..0x2240`.
  - `data_path_subsystem_histogram_ingress_bridge_1.csr` is exported at `0xAC10..0xAC20`.
  - Build-local generation scripts call that top patch before `qsys-generate`.
- Evidence:
  - Qsys generation stamp `20260514_addrmap_fix`: `arb_hit_type0_supercore`, `scifi_datapath_system_v3`, `scifi_datapath_system_v3_pipe`, and top `feb_system_v3` all report `exit_code=0`, `error_count=0`.

## 2026-05-12

### BUG-005-H: phase4_5_sweep read the LIVE CSR 13 counter while interval pulses reset it mid-run

- First seen:
  - FEB v3 emulator-type0 phase 4.5 sweep on the `v3_pretest-260511-emulator-type0-260512` build.
  - Prior 32-row sweep reported 8 PASS / 24 FAIL with the dominant failure mode `TOTAL_HITS_ZERO` even though several rows had populated per-channel `hist_bin` counts.
- Symptom:
  - Post-end-run read of CSR 13 (`TOTAL_HITS`) returned 0 or a partial bucket on most rows, while the per-channel `hist_bin` SRAM held multi-million hits on lucky rows.
  - The verdict logic depended on CSR 13 alone and miscounted those rows as failures even when traffic clearly reached the histogram on the bench.
- Root cause:
  - `histogram_statistics_v2_hw.tcl` documents the contract verbatim: "TOTAL_HITS and DROPPED_HITS are LIVE CURRENT-INTERVAL counters. LAST_INTERVAL_TOTAL_HITS and LAST_INTERVAL_DROPPED_HITS latch the completed interval just before the live counters reset, allowing stable one-second rate polling."
  - `histogram_statistics_v2.vhd` resets `csr_total_hits` at every `interval_pulse`; the pulse fires every `INTERVAL_CFG` clock cycles. On this build `interval_reset` is wired only to the POR bridge, so the periodic timer is the sole source of pulses.
  - The previous sweep used `INTERVAL_CFG = run_window * 125 MHz = 500 M cycles` for a 4 s run, firing 4 pulses during the run window.
  - The sweep also defined `HIST_LAST_INT_HITS_W = 0x10` (the SCRATCH register) instead of `0x11` (`LAST_INTERVAL_TOTAL_HITS`).
- Fix:
  - `scripts/cotest/phase4_5_sweep.py` programs `INTERVAL_CFG = 0xFFFFFFFF` (`INTERVAL_CFG_NEVER_FIRE`, ~34.36 s @ 125 MHz) so no `interval_pulse` fires during any run in the matrix.
  - New constants `HIST_LAST_INTERVAL_TOTAL_HITS_W = 0x11` and `HIST_LAST_INTERVAL_DROPPED_HITS_W = 0x12` map to the STABLE CSR offsets per the VHDL `when 17 / when 18` readout cases.
  - `snap_hist()` reads 19 words (0x00..0x12) and now exposes `LAST_INTERVAL_TOTAL_HITS`, `LAST_INTERVAL_DROPPED_HITS`, plus a back-compat alias for the older `LAST_INT_HITS` field.
  - `compute_verdict()` captures `total_hits_csr13` (LIVE), `last_interval_total_hits_csr17` (STABLE), and `hist_bin_sum` on every row; the PASS predicate uses `total_hits_csr13`; `hist_bin_sum_matches_csr13` (within an 8-hit pipeline tolerance) is a warning-only flag.
- Evidence (2026-05-12 sweep, build `v3_pretest-260511-emulator-type0-260512`):
  - Single-row diagnostic on `p45_000_all_lanes_0xFFFFFFFF_default_dir` confirmed `INTERVAL_CFG` readback = `0xFFFFFFFF`, stable cross-validation (`csr13 = csr17 = hist_bin_sum = 0`, `hist_bin_sum_matches_csr13 = true`).
  - Full 32-row sweep: 2 PASS (both sanity-negative `lane_mask=0x00` rows), 30 FAIL. On every FAIL row the three counters agree; the live-vs-stable race is resolved.
  - Sweep evidence at `sweep_evidence/<row_id>/{counters.json,verdict.json,hist_bin.csv,tool_calls.log}`.
  - Refreshed report at `doc/PHASE4_5_SWEEP_REPORT.html` (Diagnosis section + Counter Cross-Validation sub-section).
- Residual hazard:
  - The refreshed sweep exposes the upstream histogram-feeding bug tracked separately as BUG-006-I.

### BUG-006-I: histogram input FIFOs are empty on every row of the 2026-05-12 sweep

- First seen:
  - FEB v3 emulator-type0 phase 4.5 sweep on the `v3_pretest-260511-emulator-type0-260512` build, 2026-05-12.
- Symptom:
  - On all 32 sweep rows, `histogram_statistics_v2` `PORT_STATUS = 0x000000FF` post-end-run (every per-port `hit_fifo` empty, `fifo_level_max = 0`).
  - `csr_total_hits = csr_last_interval_total_hits = sum(hist_bin[0..255]) = 0` on every non-sanity-negative row.
  - `arb_hit_type0_supercore` reports `ingress_emu_hits` and `egress_emu_hits` growing from ~274 M on row 0 to ~1.27 B on row 31, so traffic flows through the arb stage. Nothing reaches the histogram.
- Root cause:
  - `histogram_statistics_0` was configured with `N_PORTS = 1`, so only `hist_fill_in` port 0 was live.
  - `mts_preprocessor_0.hit_type1_out` fed `histogram_ingress_bridge_0.pre_in`, but `mts_preprocessor_1.hit_type1_out` fed only `hit_stack_subsystem_1.hit_type_1`.
  - Lanes 4..7 therefore reached `mts_preprocessor_1` and the bank-1 hit stack, but never reached the histogram pre-rbCAM measurement input.
  - The `arb_hit_type0_supercore -> mux_mutrig2processor -> mts_preprocessor.hit_type0_in` path also had a ready-contract mismatch risk. The MTS input declared `ready`; the arb/mux path is valid-only. This build removes that sink ready and uses explicit readyless 4:1 hit_type0 muxes so Qsys does not insert a dropping timing adapter on the hit path.
- Fix:
  - New build directory: `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/`.
  - `histogram_statistics_0.N_PORTS = 2`.
  - `histogram_ingress_bridge_0` feeds histogram port 0 from `mts_preprocessor_0` for lanes 0..3.
  - `histogram_ingress_bridge_1` feeds histogram `fill_in_1` from `mts_preprocessor_1` for lanes 4..7 and forwards to `hit_stack_subsystem_1.hit_type_1`.
  - Top-level Qsys version is bumped to `3.0.5.0512`.
  - `mutrig_timestamp_processor/mts_processor_hw.tcl` version is bumped to `26.3.0.512` and the `hit_type0_in` ready port is removed.
- Evidence:
  - Focused dual-port simulation:
    - `tb_int/REPORT/dualport_smoke.md`: port0 handshakes 500, port1 handshakes 500, `hist_bin` writes 844, total 1000.
    - `tb_int/REPORT/100k_single_channel_soak.md`: port0 handshakes 50000, port1 handshakes 50000, internal `hist_bin` writes 100000, observed 100000.
  - Board sweep on the dual-port image:
    - 32 rows executed under `swb_ring_lock`.
    - 25 PASS / 7 FAIL by the existing CSR-based verdict.
    - Non-sanity rows now have live `TOTAL_HITS` on 28 rows; lane 4..7 rows prove the second MTS bank contributes to CSR 13.
  - Directed board long-soak:
    - Evidence: `sweep_evidence/_longsoak/longsoak_20260512_153309/`.
    - PASS: 10 interval snapshots, 97652 observed hits vs 100000 target with the documented 4000-hit rate-quantization tolerance.
    - Live 256-bin snapshots show the channel-mask-1 stimulus in MTS bank bins `[0..3]` and `[32..35]`.
- Residuals:
  - The existing full sweep still reads `hist_bin` after END_RUN with `INTERVAL_CFG_NEVER_FIRE`; this image clears the frozen bank at END_RUN, so the per-row `hist_bin_sum` remains zero in the 32-row table.
  - The directed long-soak works around that by taking 256 single-word bin snapshots while RUNNING. Burst reads remain disabled because they corrupt the SC bridge on this bench.

## 2026-05-19

### BUG-024-I: feb_system_v4 nested-subsystem generic snapshot does not refresh when scifi_datapath_system_v4 leaf IPs bump

- First seen in:
  - FEB v3 RESETTING-contract rebuild on 2026-05-19 (commit `008c9447` + IP bumps `28b3fb9`, `caecaeb`, `630ef5b`)
  - On-board re-probe at 2026-05-19 18:02 (`reports/feb_v4_resetting_contract_180200.md`):
    - `mu3e_lvds_controller_0.csr` UID = `0x4C564453` ("LVDS") ✓
    - VERSION = `0x1A021506` = 26.2.1.1286 — matches the **OLD** generic cache (`PATCH=1, BUILD=1286, DATE=20260518`) instead of the expected 26.2.2.1305
- Symptom:
  - The standalone subsystem qsys-syn output (`generated/synthesis/scifi_datapath_system_v4/synthesis/scifi_datapath_system_v4.vhd`) correctly carries `VERSION_PATCH=2, BUILD=1305, DATE=20260519` for the `mu3e_lvds_controller_0` instance (verified with `grep`).
  - The FEB top-level wrapper that Quartus actually compiles (`generated/synthesis/feb_system_v4/synthesis/submodules/feb_system_v4_data_path_subsystem.vhd`) still passes `VERSION_PATCH=1, BUILD=1286, DATE=20260518` to the same IP instance.
  - Three IPs affected: `mu3e_lvds_controller_0`, `histogram_statistics_0`, `mutrig_injector_0`. The contract-fix RTL `WAITING`/`gts_counter_clear`/`TRAIN_ASSERTING_*` is in the submodule sources compiled into the SOF, but the FIRMWARE IDENTITY word reported by each IP's META header is stale.
- Root cause:
  - `feb_system_v4.qsys` (the top-level) holds an Auto-cached snapshot of the leaf-IP generics for every nested subsystem instance.
  - The 2026-05-19 `make qsys-refresh` target only re-elaborates `scifi_datapath_system_v4.qsys` (the subsystem). The top is **excluded** because `qsys-script` `save_system` on `feb_system_v4` is destructive — it silently drops 18 slaves whose nested-subsystem catalog lookup fails during re-elaboration (observed during the 2026-05-19 audit dropping `hit_stack_subsystem*`, `ring_buffer_cam*`, `feb_frame_assembly*`, `dbg_mm2runctrl*`, and `arb_hit_type0_supercore.csr_*`).
  - The `make qsys-validate` script checks each `.qsys` file's `version="X.Y.Z.WWWW"` attribute against the latest catalog `_hw.tcl` but does NOT walk into the nested-subsystem instance Auto cache, so the stale generics go unflagged.
- Fix status:
  - state: FIXED + silicon-validated 2026-05-21.
  - root mechanism understood deeper: the top-level re-elaboration failure was driven by AUTO-INSERTED elements that dangle on every `qsys-generate`/`save_system`: `emulator_hit_type0_fanout` (the broadcast pattern) and the Platform-Designer-auto `avalon_st_adapter_*` on the `mutrig_datapath_subsystem_K.hit_type0_out -> arb.real_in_K` path. On re-elaboration the fanout/adapter `inBitsPerSymbol` collapses to 0 -> `avalon_st_adapter_*: divide by zero` -> generation aborts. The kept cache survived only because it was never re-elaborated. A second trap: two copies of `scifi_datapath_system_v4.qsys` (the search-path `quartus_systems/` source and `generated/qsys/`) carried the same component version with different content, so the top resolved the stale one.
  - mechanism (implemented): replace the auto fanout/adapters with an EXPLICIT readyless source mux. Wire 8x `merger_hit_type0` (45-bit readyless 2:1, `SOURCE_SEL_DEFAULT=1`=EMU) per lane: `emulator_mutrig_qsys8.hit_type0_K` (8-lane per-lane) + `mutrig_datapath_subsystem_K.hit_type0_out` -> `merger_K.out` -> `arb_hit_type0_supercore_0.emu_in_K` with arb `MODE_DEFAULT=1` (EMU pass-through); `arb.real_in_K` left unconnected. Explicit IPs do not dangle on re-elaboration, so `qsys-generate` now completes (feb_system_v4 Done, 210 modules, 0 errors). Synced both `.qsys` copies to clear the version/content trap. Patchers: `qsys_tcl/patch_scifi_datapath_v4_merger_8lane.tcl` + `patch_scifi_datapath_v4_merger_to_emu.tcl`.
  - before_fix: SOF `02fc843f` (real_in/MODE=REAL route) read TYPE0=0 on silicon; the REAL ingress is gated on a real-LVDS frame condition absent for the emulator. Localized by a wrapper-TB merger-chain probe: emulator->merger->arb.real_in carried 24972 beats but arb egress=0.
  - after_fix: SOF `b3a0e4fd` (merger->arb.emu_in, MODE=EMU). On-board: TYPE0 all 8 ASICs (256 bins), Type1 EXT0 (ASIC0-3) 128 bins / 9.86M, EXT1 (ASIC4-7) 128 bins / 9.87M, all real (bleed-guarded vs TYPE0). Sim wrapper: run-control RUNNING, TYPE0 199561, Type1 EXT0 populated.
  - timing: lvds_firefly_clk worst-case setup -0.313 ns (LVDS/transceiver PLL corner), within the STP-armed iterative-debug relaxation (>= -0.4 ns).
- Evidence:
  - `reports/feb_v4_resetting_contract_180200.md` "qsys cache propagation finding" section (original).
  - on-board: feb_edge_buckets + bleed-guarded EXT read on SOF `b3a0e4fd`; sim: `tb_int/scifi_v4_wrapper/REPORT/scifi_v4_wrapper_20260521_150538/`.

### BUG-025-I: Region B mm_pipeline_lvds_csr_* bridges past offset 0x0000 are CSR-deaf on silicon (INVALID / false alarm)

**Status: INVALID. Closed 2026-05-19 18:30 after corrected-address re-probe.**

- First raised: FEB v3 on-board re-probe at 2026-05-19 18:02 after the RESETTING-contract rebuild.
- Reported symptom: hist/injector/emulator/mts CSRs return all-zero payloads when probed via sc_tool at sc-byte addresses 0x17000 (hist), 0x1B200 (injector via wrong derivation), 0x11000 (emulator), 0x13000 (mts0).
- Actual root cause (re-derived from feb_system_v4.qsys AUTO_AVMM_PORT_ADDRESS_MAP, 2026-05-19 18:30):
  - The correct mapping is `sc-byte = avmm_port_byte + 0x10000` (Region B base).
  - The V4_REWIRE_SPEC.md table's sc-byte column was derived from `data_jtag_byte + 0x10000`, but the JTAG master view and the SC-hub avmm_port view do NOT share the same internal byte layout - the JTAG master has its own local address map starting at 0 while the avmm_port map starts at 0 too but with different slave offsets (per feb_system_v4.qsys AUTO_AVMM_PORT_ADDRESS_MAP).
  - For example, the spec said hist csr = sc-byte 0x17000 (data_jtag byte 0x07000 + 0x10000), but the avmm_port has hist csr at byte 0xA400, so the correct sc-byte is 0x1A400 (= sc-word 0x06900).
- Corrected-probe evidence (2026-05-19 18:30):
  - `sc_tool 2 read 0x06900 2` → payload[0] = `0x48495354` ("HIST"), payload[1] = `0x1A034205` (VERSION 26.3.4.517, still stale per BUG-024-I but the IP responds)
  - `sc_tool 2 read 0x06C80 2` → payload[0] = `0x4D494E4A` ("MINJ"), payload[1] = `0x1A011205` (VERSION 26.1.1.517, stale per BUG-024-I)
  - `sc_tool 2 read 0x04800 2` → payload[0] = `0x454D5554` ("EMUT"), payload[1] = `0x1A0301FA` (VERSION 26.3.0.506, stale per BUG-024-I)
  - `sc_tool 2 read 0x05000 2` and `0x06000 2` → mts_preprocessor_0 and mts_preprocessor_1 status registers return non-zero data.
  - `sc_tool 2 read 0x06800 4` (hist_bin offset 0) → returns all-zero data, which is the CORRECT idle state for an unconfigured histogram.
- Lesson:
  - The `mm_pipeline_lvds_csr_*` bridges are not deaf and the address-width "mismatches" noted in the original BUG-025-I write-up are normal Qsys autoresize artifacts.
  - The sc-byte values in V4_REWIRE_SPEC.md (and in `reports/feb_v4_resetting_contract_180200.md`) need to be regenerated from the live `feb_system_v4.qsys` AUTO_AVMM_PORT_ADDRESS_MAP rather than from the older data_jtag layout.
- Follow-up:
  - V4_REWIRE_SPEC.md sc-byte column refresh (queued for next session - keep the data_jtag byte column separate from the SC-hub view).
  - Only BUG-024-I (qsys nested-subsystem generic cache) remains real and open from the 2026-05-19 on-board re-probe.

### BUG-026-H: hist LOCK_KEY_RANGES keyed on TCC instead of ASIC+CH (default wrong for rate plots)

- First seen in:
  - FEB v3 emulator rate-plot regression on 2026-05-19 19:01 against build
    firmware_builds/systems/260518-feb-ok (driver:
    `script/board/run_emulator_rate_delay_20260519.py`, outputs:
    `script/board/REPORT/emu_rate_delay_20260519_190144/`).
  - User intent for the regression: "rate plot [0,255] of type0 and type1.
    Rate must match the enabled ch of the given rate." With 1ch/ASIC at
    100 kHz and 8 lanes enabled the expected plot has 8 non-zero bins
    each carrying the per-channel hit count.
- Symptom:
  - Type0 rate plot showed ~99.18 kHz integrated across all 256 bins (each
    bin ~ 388 counts), a uniform TCC distribution rather than 8 non-zero
    channel bins. The emulator aggregate rate matched the configuration
    (99183 hits in 1 s vs 100 kHz request) but the histogram was binning
    the wrong field.
- Root cause:
  - `histogram_statistics/rtl/histogram_statistics_v2.vhd` constants
    `TYPE0_UPDATE_KEY_LOW/HIGH_CONST = 21/35` and
    `TYPE1_UPDATE_KEY_LOW/HIGH_CONST = 17/29` keyed on the TCC slice.
  - The IP env_pkg HS_TYPE0_ASIC/CH and HS_TYPE1_ASIC/CH show the channel
    index lives at Type0 bits[43:36] and Type1 bits[37:30] as
    {ASIC[2:0], CH[4:0]} (8 bits, 256 unique values for 8 ASICs * 32
    channels). The old TCC default was wrong for rate-mode plots.
- Fix:
  - Bumped `histogram_statistics_v2` 26.3.7.0519 -> 26.3.9.0519
    (single submodule commit also lands BUG-027-I below).
  - TYPE0_UPDATE_KEY 21:35 -> 36:43 ({ASIC[2:0], CH[4:0]}).
  - TYPE1_UPDATE_KEY 17:29 -> 30:37 ({ASIC[2:0], CH[4:0]}).
  - Filter slices remain ASIC (Type0 bits[44:41], Type1 bits[38:35]).
  - TB env_pkg HS_DEF_UPDATE_LO/HI + HS_TYPE0_UPDATE + HS_TYPE1_UPDATE
    updated to match the RTL.
  - hw.tcl HTML "Key Extraction" panel refreshed.
- Validation:
  - Questa static screen on the new RTL: Lint 0, CDC 0, RDC 0
    (`.questa_static_screen_asicch/questa_static_screen.log` then
    `.questa_static_screen_t1ready/`).
  - Per-bank Type1 plotting: per the user 2026-05-19 19:30 clarification,
    Type1 is single-bank in the hardware: type1_up covers 4 ASICs * 32
    channels = channels [0, 127], type1_down covers the other 4 ASICs =
    channels [128, 255]. The plotting driver therefore needs to make TWO
    separate ping-pong runs (one with source_select=Type1_up, one with
    source_select=Type1_down) and concatenate the 256-bin outputs.
    Same shape applies to Type1 delay.

### BUG-027-I: hist hw.tcl omitted asi_type1_*_ready port causing timing_adapter to drop Type1 hits silently

- First seen in:
  - FEB v3 emulator regression on 2026-05-19 19:01 against build
    firmware_builds/systems/260518-feb-ok.
- Symptom:
  - On 1ch/ASIC, 100 kHz, 1 s ping-pong:
    - Type1 rate plot: bin_sum=0, no non-zero bins.
    - Type1 delay plot: bin_sum=0, no non-zero bins.
    - MTSP0/1 in RUNNING with `total_hit_cnt` climbing ~420 k/s/group.
    - histogram_statistics_0 BANK_STATUS ping-ponged 0<->1 (interval
      engine alive) but TOTAL_HITS stayed 0.
  - sc_hub_v2 ERR_FLAGS=0 throughout.
- Root cause:
  - `histogram_statistics_v2_hw.tcl` declared the `type1_up` and
    `type1_down` Avalon-ST sink interfaces with `readyLatency 0` but
    never added the `asi_*_ready` port to the interface port list (the
    foreach loop only emitted valid, data, sop, eop, channel, empty,
    error).
  - The RTL drives `asi_type1_up_ready` and `asi_type1_down_ready` as
    entity outputs (rtl/histogram_statistics_v2.vhd:1012-1013), but
    qsys-generate strips them from the wrapper because the hw.tcl
    declaration is authoritative for what shows up on the wrapper
    boundary. `grep asi_type1_up_ready
    generated/synthesis/scifi_datapath_system_v4/synthesis/scifi_datapath_system_v4.vhd`
    returned zero matches, confirming the signal was dropped.
  - The auto-inserted `avalon_st_adapter_025` between
    `hist_type1_up_tap.out1` (avst_snoop_splitter source) and
    `histogram_statistics_0.type1_up` (sink) is a timing_adapter. With
    its `out_0_ready` unconnected (because the sink hw.tcl never
    advertised the ready port), the adapter defaulted that signal to 0,
    never consumed from its internal FIFO, filled, and back-pressured
    its input side (which the snoop tap intentionally ignores per the
    SV comment "an unconnected or stalled monitor cannot backpressure
    the observed datapath"). So every Type1 hit was silently dropped at
    the adapter input.
  - The Type0 path uses `hit_type0_tap2` which has NO ready ports on
    either input or outputs, so Qsys does not insert any timing_adapter
    there. That is why Type0 always worked.
- Fix:
  - Added `add_interface_port type1_up asi_type1_up_ready ready Output 1`
    and the matching `type1_down` line to histogram_statistics_v2_hw.tcl.
  - Bumped `histogram_statistics_v2` 26.3.7.0519 -> 26.3.9.0519 (with
    BUG-026 in the same submodule commit).
  - No RTL change required.
- Validation:
  - Questa static screen on the RTL (unchanged here): Lint 0, CDC 0,
    RDC 0.
  - FEB integration recompile + reprobe queued.

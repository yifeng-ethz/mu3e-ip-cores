# TEST_PLAN_PHASE5.md — real-MuTRiG bring-up, frame-format signoff, injector closure

**Revision**: 2026-04-29 / draft-8
**Target**: `mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/syn/feb_system_v3_pipe` on FEB SciFi prototype, with the eight live MuTRiG ASICs replacing the 8-lane `emulator_mutrig`. Build is under `firmware_builds/`.
**Host**: teferi (`yifeng@teferi`, `/dev/mudaq0` via SWB on link 2 — see `TEST_PLAN.md` §0)
**Companions**: [`TEST_PLAN.md`](TEST_PLAN.md) Phases 1..4 · [`phase4/TEST_PLAN_BASIC.md`](phase4/TEST_PLAN_BASIC.md) · [`phase4/TEST_PLAN_PUBLISH.md`](phase4/TEST_PLAN_PUBLISH.md)
**Authoring scope**: this document is the live Phase-5 plan and scoreboard. Helper scripts under `../systems/system_20260427_testplanphase5/script/` are allowed to implement read-only audits, address-map extraction, case-catalog validation, and run orchestration; generated `.stp` and report artifacts remain evidence, not the source of the test contract. The live injector boundary precheck is tracked in [`TEST_INJECTOR_PATH.md`](TEST_INJECTOR_PATH.md); it is a gate, not part of the 144-case bucket denominators.

---

## 0. Goal of Phase 5

Phase 5 is the first sign-off on the **real MuTRiG ASIC** end-to-end. Phase 4 closed against the 8-lane `emulator_mutrig` LFSR; Phase 5 reuses the proven datapath and reset/SC plane and exercises the same observation surfaces against eight live MuTRiG ASICs.

The plan is structured as three live stages:

1. **Real-MuTRiG bring-up** (§2) — load each ASIC's known-good configuration via `mutrig_cfg_ctrl_0` (the MuTRiG Controller IP), sweep the per-channel TTH via the on-IP TTH-Scan-Automation (TSA) routine, and confirm every ASIC reports a stable, decoded MuTRiG frame.
2. **Directed verification** (§3) — IP-by-IP cascade SignalTap signoff against the live FEB datapath. Each case in [`TEST_BASIC.md`](TEST_BASIC.md), [`TEST_PROF.md`](TEST_PROF.md), [`TEST_EDGE.md`](TEST_EDGE.md), and [`TEST_ERROR.md`](TEST_ERROR.md) defines a stimulus configuration and the per-IP boundary evidence required to attest hits propagate through the chain. Each bucket has ≥ 144 cases; long-term target is 500–3000 per bucket. Per-IP segment depth is sized per IP (default 1024 × 4 segments; `feb_frame_assembly` defaults to 4096 × 4). One trigger condition per `.stp` instance per Quartus segmented-acquisition manual; multiple SignalTap instances are armed in parallel and aligned post-capture via a shared GTS slice. SWB-side packet receipt is cross-checked against the SWB per-link counter (§3.9) before the SWB-side `.stp` is in place.
3. **Collective verification** (§4) — `histogram_statistics_0` rate / delay PDFs across injector modes, sources, and lane masks. Quick debug iterations may use direct CSR reads through the SC hub; final closure requires a System Console screenshot plus an authentic generated-system `tb_int/` run that produces the same histogram result.

Phase 5 does **not** redo Phase 4 closure on the emulator; Phase 4 is the prerequisite, not part of the Phase 5 evidence.

---

## 1. Prerequisites and references

### 1.1 Hard prerequisites — must be PASS before any Phase-5 case is run

| Prerequisite | Source | Exit criterion |
|---|---|---|
| Phase 1 metadata + bridge audit | [`TEST_PLAN.md`](TEST_PLAN.md) §1 | every UID/version/GIT cross-check passes; `mm_bridge` and `upload_mm_bridge` are reachable end-to-end |
| Phase 2 BIST | [`TEST_PLAN.md`](TEST_PLAN.md) §2 | zero bit-flips across all RW registers and the scratchpad; sc_hub admission/ordering hazards eliminated |
| Phase 3 run-control | [`TEST_PLAN.md`](TEST_PLAN.md) §3 | every reset-link opcode advances the host counter exactly once on both SC and JTAG paths |
| Phase 4 emulator + histogram | [`phase4/TEST_PLAN_BASIC.md`](phase4/TEST_PLAN_BASIC.md) closure contract | TPBH001..TPBH030 pre-gate PASS, TPB000..TPB100 PASS (no residual `OVERFLOW_COUNT`/`DROPPED_HITS`/`UNDERFLOW_COUNT`) |
| Environmental monitors sane | this plan §1.2.1 | `check_environment_monitors.py` returns zero FAIL checks; WARN entries are explained in the report |
| FEB SciFi v3 SOF flashed | this repo `firmware_builds/<feb_scifi_v3_project>/output_files/top.sof` | `script/check_ip_metadata.py` clean |
| SWB SOF flashed from `online_sc` | per `TEST_PLAN.md` §0.2 | `/dev/mudaq0` BAR sane; `sc_tool read 0x00000` returns OK |
| MuTRiG configuration bitstreams reviewed | `/home/yifeng/packages/online_dpv2/online/switching_pc/slowcontrol/mutrig/Mutrig_FEB.cpp` and `toolkits/fe_scifi/` | a known-good 84-word packed cfg stream is available for each MuTRiG3 ASIC variant on the SciFi DAB |

If any prerequisite is open, Phase 5 does not start. Phase 4 closure attestation `TPB100` is the named gate.

Current prerequisite scoreboard:

| Gate | Status | Last evidence | Notes |
|---|---|---|---|
| Environmental monitors sane | `PASS` | [`../systems/system_20260427_testplanphase5/reports/phase5_environment_20260429_nostp_pipe_rebuild.md`](../systems/system_20260427_testplanphase5/reports/phase5_environment_20260429_nostp_pipe_rebuild.md), [`../systems/system_20260427_testplanphase5/reports/phase5_environment_20260429_nostp_pipe_rebuild.json`](../systems/system_20260427_testplanphase5/reports/phase5_environment_20260429_nostp_pipe_rebuild.json), [`../systems/system_20260427_testplanphase5/reports/phase5_environment_20260429_runctl_mts_stage.md`](../systems/system_20260427_testplanphase5/reports/phase5_environment_20260429_runctl_mts_stage.md), [`../systems/system_20260427_testplanphase5/reports/phase5_environment_20260429_runctl_mts_stage.json`](../systems/system_20260427_testplanphase5/reports/phase5_environment_20260429_runctl_mts_stage.json), [`../systems/system_20260427_testplanphase5/reports/phase5_environment_20260428_onewire_dividerfix_retry.md`](../systems/system_20260427_testplanphase5/reports/phase5_environment_20260428_onewire_dividerfix_retry.md) | Rebuilt timing-clean no-STP SOF checksum `0x13C7FEDB` passes the post-flash environmental gate with 62 PASS / 1 WARN / 0 FAIL. OneWire UID `0x4F574D43` is live, all six lines have `sample_valid=1`, temperatures are non-default (`30.375`, `32.938`, `21.625`, `22.062`, `40.188`, `39.750` C), and `crc_err/init_err` stay clear. FF2 matches the expected dangling-module sentinel pattern. The only warning is FF1 VCC raw code `58`, recorded as a monitor-scaling interpretation issue because FF1 temperature and RX optical powers are live. The helper now retries verbose `sc_tool` after quiet-mode packet loss on the noisy secondary ring. |
| OneWire controller unit DV scaffold | `PASS` | [`../../onewire_temp_sense/tb/REPORT/run_20260428_191021`](../../onewire_temp_sense/tb/REPORT/run_20260428_191021), [`../../onewire_temp_sense/tb/REPORT/B131.md`](../../onewire_temp_sense/tb/REPORT/B131.md) | `make regress` passes the implemented 56-case BASIC/EDGE/ERROR/PROF/CROSS slice after adding `B131` for the shared odd/even microsecond divider. Evidence covers the common CSR header (`UID/META/SCRATCH`), six-line DS18B20 model path, intentional valid 0 C on line 0 (`0x00000000`), controller CSR negative-access features, serial-number probing, RC-line waveform modeling, documented DS18B20 model limitations, and the 125 MHz divider regression that blocked the board monitor loop. |
| FEB generated-system `tb_int/` SC smoke | `PASS` | [`../systems/system_20260427_testplanphase5/syn/logs/feb_system_v3_pipe_qsys_generate_20260428_onewire_dividerfix.log`](../systems/system_20260427_testplanphase5/syn/logs/feb_system_v3_pipe_qsys_generate_20260428_onewire_dividerfix.log), [`../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/REPORT/sc/run_sc_smoke.log`](../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/REPORT/sc/run_sc_smoke.log), [`../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/REPORT/sc/run_sc_burst_vs_single.log`](../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/REPORT/sc/run_sc_burst_vs_single.log) | Current regenerated `feb_system_v3_pipe` authentic-Qsys sim passes `SC-001..003`, OneWire UID sweep/burst reads at `0x04400` return `0x4F574D43`, OneWire META single-read returns `0x1A0211AC` (`26.2.1.0428`), histogram UID sweep/burst reads return `0x48495354`, and the burst-vs-single matrix closes 144/144 compare cases. This verifies the divider-fix OneWire controller is present in the generated FEB image and reachable through the same SC boundary used by hardware. |
| Datapath SC bridge audit | `PASS` | [`../systems/system_20260427_testplanphase5/reports/phase5_full_svd_address_map_20260429.json`](../systems/system_20260427_testplanphase5/reports/phase5_full_svd_address_map_20260429.json), [`../systems/system_20260427_testplanphase5/reports/phase5_debug_sc_svd_inventory_20260429.json`](../systems/system_20260427_testplanphase5/reports/phase5_debug_sc_svd_inventory_20260429.json) | After reloading the SWB with the `online_sc` SOF and recovering `/dev/mudaq0`, `check_sc_bridges.py --link 2 --skip-jtag` passed. `histogram_statistics_0.UID` reads `0x48495354`, `histogram_ingress_bridge_0.UID` reads `0x48495342`, all source-mux lane UIDs read `0x4D4C534D`, `dbg_mm2runctrl_0` reads `0x4D325243`, and upload run-control reads `0x52434D48`. Current datapath CSR access is SC-only; see §1.2. |
| Frame-to-histogram SignalTap image | `PASS_DEBUG_ONLY` | [`../systems/system_20260427_testplanphase5/reports/phase5_runctl_mts_stage_hiterr_followup_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_runctl_mts_stage_hiterr_followup_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_frame_hist_mts_histstats_stp_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_frame_hist_mts_histstats_stp_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_real03_mts_input_hiterr_debug_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_real03_mts_input_hiterr_debug_20260429.md), [`../systems/system_20260427_testplanphase5/signaltap/phase5_frame_hist_path.nodes.md`](../systems/system_20260427_testplanphase5/signaltap/phase5_frame_hist_path.nodes.md), [`../systems/system_20260427_testplanphase5/syn/logs/quartus_compile_top_stp_pipe_phase5_frame_hist_mts_tserr_20260429.console.log`](../systems/system_20260427_testplanphase5/syn/logs/quartus_compile_top_stp_pipe_phase5_frame_hist_mts_tserr_20260429.console.log) | The imported frame/MTS/histogram STP compiles and runs: Node Finder found 1180/1180 probes; import succeeded with 0 errors; full compile/program succeeded (`rc=0`, 0 errors, checksum `0x16D84D15`). Runtime captures exported VCDs for MTS0 valid and histogram-statistics valid on real lanes 0/3, plus the matching emulator lane-0 histogram trigger. A runtime input-hiterr trigger localized the earlier intermittent MTS discard to `mutrig_frame_deassembly_0.aso_hit_type0_error[0]` on an ASIC0/channel16 beat before MTS. A fresh runctl/MTS-stage rebuild then programmed checksum `0x145AA92C`; the targeted `aso_hit_type0_error[0]` SignalTap trigger timed out with no recurrence while the paired 12-window runner passed, and a follow-up 40-window SC-only soak also passed. These are debug-only images because STP instrumentation can violate setup (frame/hist image slow 85 C WNS `-0.860 ns`; runctl/MTS-stage image slow 0 C WNS `-0.109 ns`); use the no-STP image for timing signoff. |

Latest v26.1.6 checkpoint overlay:

| Gate | Status | Last evidence | Notes |
|---|---|---|---|
| Histogram v26.1.6 no-STP image and post-flash board gates | `PASS` | [`../systems/system_20260427_testplanphase5/reports/phase5_histv6_real_rate_closure_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_histv6_real_rate_closure_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_environment_histv6_20260429_214050.json`](../systems/system_20260427_testplanphase5/reports/phase5_environment_histv6_20260429_214050.json), [`../systems/system_20260427_testplanphase5/reports/phase5_sc_bridge_histv6_20260429_214107.json`](../systems/system_20260427_testplanphase5/reports/phase5_sc_bridge_histv6_20260429_214107.json) | Programmed checksum `0x13A9CC2D`; compile is timing-clean with slow 85 C setup WNS `+0.454 ns` and all listed TNS `0.000`. Post-flash environment is `62 PASS / 1 WARN / 0 FAIL`; OneWire reads all six non-default temperatures (`30.25`, `31.438`, `21.5`, `21.812`, `40.25`, `40.312` C). SC bridge check passes 7/7 after reset/address/stop-reset priming. |

### 1.2 Authoritative IP and address references (from this repo)

The addresses below are external **`sc_tool` word addresses**. They are derived
from the SC-hub word-addressed bridge base plus the generated Qsys byte offset
divided by four; do not send the raw Qsys byte offsets to `sc_tool`.

| IP / instance | `sc_tool` word address | Source of truth |
|---|---|---|
| `mutrig_cfg_ctrl_0.avmm_csr` (MuTRiG Controller CSR) | `0x0FC04` | [`../../mutrig_controller/mutrig_ctrl.vhd`](../../mutrig_controller/mutrig_ctrl.vhd), [`../../mutrig_controller/mutrig_cfg_ctrl.svd`](../../mutrig_controller/mutrig_cfg_ctrl.svd) |
| `mutrig_cfg_ctrl_0` scratchpad host port (cfg bitstream stage) | aliased into `scratch_pad_ram` at `0x00000` | `TEST_PLAN.md` §1.2; controller's own AVMM host port reads it |
| `mutrig_injector_0.csr` | `0x0AC80` | [`../../charge_injection/rtl/vhdl/mutrig_injector_multiheader.vhd`](../../charge_injection/rtl/vhdl/mutrig_injector_multiheader.vhd), [`../../charge_injection/script/mutrig_injector.svd`](../../charge_injection/script/mutrig_injector.svd) |
| `histogram_statistics_0.csr` | `0x0A900` | [`../../histogram_statistics/histogram_statistics.svd`](../../histogram_statistics/histogram_statistics.svd) |
| `histogram_statistics_0.hist_bin` | `0x0A800` | same |
| `histogram_ingress_bridge_0.csr` | `0x0AB00` | [`../../histogram_statistics/histogram_ingress_bridge.svd`](../../histogram_statistics/histogram_ingress_bridge.svd) |
| `hit_stack_subsystem_0.ring_buffer_cam_0..3.csr` | `0x0AC00`, `0x0AC20`, `0x0AC40`, `0x0AC60` | per AVMM map in `feb_system_v3_pipe.qsys` line 285 |
| `hit_stack_subsystem_1.ring_buffer_cam_0..3.csr` | `0x0AD00`, `0x0AD20`, `0x0AD40`, `0x0AD60` | same map |
| `mutrig_frame_deassembly_0..7.csr` | `0x08240`, `0x08640`, `0x08A40`, `0x08E40`, `0x09240`, `0x09640`, `0x09A40`, `0x09E40` | per AVMM map in `feb_system_v3_pipe.qsys` line 285 |
| `mts_preprocessor_{0,1}.csr` | `0x09000`, `0x0A000` | same map |
| `feb_frame_assembly_{0,1}.csr` | `0x0B400`, `0x0B410` | same map |
| `lvds_rx_controller_pro_0.csr` | `0x08000` | same map |
| `runctl_mgmt_host_0.csr` | `0x0C000`..`0x0C013` | `TEST_PLAN.md` §1.10, §3.1 |
| `onewire_master_controller_0.csr` | `0x04400`..`0x0440A` | [`../../onewire_temp_sense/script/onewire_master_controller.svd`](../../onewire_temp_sense/script/onewire_master_controller.svd) |
| `max10_prog_avmm_0.csr_avmm` | `0x04800`..`0x04803` | [`../../feb_max10_comm/legacy/max10_prog_avmm/max10_prog_avmm.svd`](../../feb_max10_comm/legacy/max10_prog_avmm/max10_prog_avmm.svd) |
| `firefly_xcvr_ctrl_0.firefly` | `0x05000`..`0x0500D` | [`../../firefly_xcvr_i2c_master/firefly_xcvr_ctrl.svd`](../../firefly_xcvr_i2c_master/firefly_xcvr_ctrl.svd) |
| `on_die_temp_sense_ctrl.csr` | `0x05400` | [`../../alt_temp_sense_controller/altera_temp_sense_ctrl.svd`](../../alt_temp_sense_controller/altera_temp_sense_ctrl.svd) |
| `legacy_firefly_bridge.s0` | `0x05800` | bridge reachability only; primary optical monitor is `firefly_xcvr_ctrl_0.firefly` |

As of the 2026-04-29 generated `debug_sc_system_v3.qsys` audit, the headless
`jtag_master.master` is not wired to `mm_bridge.s0`; it cannot access the
datapath slaves in this table. Datapath CSR stimulus must use `sc_tool` word
addresses through the SWB secondary ring. `phase5_injector_jtag_preset.tcl`
now fails fast rather than writing SC byte addresses into an unmapped JTAG
aperture.

The full SC-visible address map, including bridged datapath and upload/run-control leaves, is generated by `../systems/system_20260427_testplanphase5/script/extract_full_svd_map.py`. The script resolves every active Qsys slave to an SVD where one exists and emits register offsets, absolute word addresses, bit fields, reset values, access modes, and descriptions. A Phase-5 map extraction is acceptable only when `missing_svd` is empty.

#### 1.2.1 Environmental monitor sanity gate

Run this gate after every FEB reflash and before any Phase-5 case changes MuTRiG thresholds, injector state, or run-control state:

```bash
../systems/system_20260427_testplanphase5/script/check_environment_monitors.py \
  --link 2 \
  --json-output ../systems/system_20260427_testplanphase5/reports/phase5_environment_$(date +%Y%m%d).json
```

The check is read-only. The helper asserts `STATUS.processor_go=1` for every synthesized 1-Wire DQ line before sampling and waits for the controller monitor loop to settle. It auto-detects the upgraded common-header map by reading `UID=0x4F574D43` at `0x04400`; old flashed images are still decoded as legacy for diagnostic continuity. In the upgraded controller package, `STATUS[26] sample_valid` must assert for each selected DQ line after a full DS18B20 scratchpad read. A persistent `1.0 C` float32 value after those writes is a failure boundary for the 1-Wire data path, not accepted environmental evidence. The helper first uses quiet `sc_tool` transactions and records `sc_transport`; if quiet mode times out or returns an incomplete payload on a noisy secondary ring, it retries the same transaction with verbose `sc_tool` and requires the final parsed response to be `rsp OK`.

| Monitor | Words | Required sanity check |
|---|---|---|
| `onewire_master_controller_0` | upgraded map: `0x04400` UID, `0x04401` META, `0x04402` SCRATCH, `0x04403` CAPABILITY, `0x04404` STATUS, `0x04405`..`0x0440A` sensor float32 temperatures; legacy diagnostic map: `0x04400` capability, `0x04401` status, `0x04402`..`0x04407` temps | at least one DQ line, no sticky CRC/init error, `STATUS[26] sample_valid=1` for every selected line in upgraded images, at least one finite sensor in `[-40, 125] C` and normally within `[5, 85] C`; repeated default-looking `1.0 C` values block Phase 5 |
| `max10_prog_avmm_0` | `0x04800` ID, `0x04801` version, `0x04802` command/data, `0x04803` status | expected ID/version, programmer idle, fault bit clear |
| `firefly_xcvr_ctrl_0` | `0x05000` FF1 temp/status, `0x05001` FF1 VCC/reset, `0x05002`..`0x05005` FF1 RX powers, `0x05006` FF1 alarms, `0x05007` FF2 temp/status, `0x05008` FF2 VCC, `0x05009`..`0x0500C` FF2 RX powers, `0x0500D` FF2 alarms | temperatures non-sentinel and sane, VCC codes non-sentinel and near the module rail, optical-power words not `0xFFFF`; zero power is WARN unless the channel is known dark/unplugged |
| `on_die_temp_sense_ctrl` | `0x05400` signed temperature byte | non-sentinel Arria temperature in `[-20, 110] C` |
| `legacy_firefly_bridge` | `0x05800` one-word reachability probe | WARN-only legacy bridge visibility; do not use it as the optical-health source |

Scoreboard rule: any `FAIL` blocks Phase 5. `WARN` is allowed only with a written explanation in the run report, for example an intentionally dark Firefly RX channel.

### 1.3 Frame-format constants used in §3 trigger expressions

| Symbol | Value | Reference |
|---|---|---|
| `FRAME_INTERVAL_SHORT` (cycles, 125 MHz emulator domain) | `910` | [`../../emulator_mutrig/rtl/emulator_mutrig_pkg.sv`](../../emulator_mutrig/rtl/emulator_mutrig_pkg.sv) |
| `FRAME_INTERVAL_LONG` | `1550` | same |
| K28.0 (frame header / SOP) | data byte `8'h1C`, K-flag → 9-bit `9'h11C` | [`../../emulator_mutrig/rtl/emulator_mutrig_pkg.sv`](../../emulator_mutrig/rtl/emulator_mutrig_pkg.sv) |
| K28.4 (frame trailer / EOP) | data byte `8'h9C`, K-flag → 9-bit `9'h19C` | same |
| K28.5 (idle / inter-frame comma) | data byte `8'hBC`, K-flag → 9-bit `9'h1BC` | same |
| K23.7 (post-hit-stack sub-header) | per `histogram_ingress_bridge_0.STATUS.post_hit_region` | `histogram_ingress_bridge.svd` |

### 1.4 Tools used (in `../systems/system_20260427_testplanphase5/script/`)

| Tool | Phase-5 use |
|---|---|
| `sc_tool` | program the MuTRiG controller (load opcodes, poll status), program injector + histogram + ingress-bridge CSRs, snapshot histogram and counters |
| `rc_tool` | issue CMD_RUN_PREPARE/CMD_SYNC/CMD_START_RUN/CMD_END_RUN to gate the histogram interval and any traffic |
| `run_phase4_emulator.py` | reused as the closure runner skeleton — same SC/RC sequence, but with the per-bucket Phase-5 stimulus described by the §3 bucket files; this plan does **not** rewrite the script |
| `probe_phase4_stage_counters.py` | stage-counter snapshot before/after each Phase-5 case |
| `phase5_case_catalog.py` | validates the four plaintext SignalTap bucket files as the live scoreboard |
| `phase5_run_case.py` | board-run orchestration for cataloged Phase-5 cases |
| `set_mutrig_lane_sources.py` | selects real MuTRiG, emulator, or mixed source per lane before a case |
| `configure_mutrig_from_xml.py` | packs the FE SciFi MuTRiG XML files into the 84-word MuTRiG3 stream, stages the scratchpad, issues `CMD_MUTRIG_ASIC_CFG`, and checks frame-deassembly deltas |
| `run_phase5_injector_datapath_sanity.py` | SC/RC live injector gate for emulator, real, and negative-control source selections |
| `extract_full_svd_map.py` | emits the full SC-visible address map with resolved SVD register/field details |
| `check_environment_monitors.py` | read-only environmental sanity gate for 1-Wire, MAX10, Firefly, on-die temperature, and legacy bridge visibility |
| `generate_phase5_frame_hist_path_stp.py` | generates the frame-deassembly/MTS/histogram SignalTap profile; current `phase5_frame_hist_path.stp` validates 1180/1180 nodes against the pipe revision and includes MTS debug stream plus hit-stack-0 debug/fill-level probes |
| `prepare_phase5_frame_hist_path_stp.sh` | required pre-compile SignalTap preparation step: regenerate, Node-Finder-check, and import the frame/hist STP into `top_stp_pipe_phase5_frame_hist` so Quartus emits the stripped `SLD_FILE` and CRC post-fit assignments |
| `run_signaltap_capture.py` | invoke segmented `.stp` capture from a pre-authored Phase-5 image |
| `run_phase5_injector_signaltap_capture.py` | concurrent injector + SignalTap wrapper retained as a debug tool; default runner mode now uses normal SC synchronization, with `--runner-no-sc-reset` opt-in only for known-safe sessions because no-reset can stale the secondary ring after FPGA reprogramming |
| `check_ip_metadata.py` / `check_sc_bridges.py` | pre-flight gate after the FEB SOF is reflashed for Phase 5 |

The cfg bitstream upload helper used by MIDAS production is `/home/yifeng/packages/online_dpv2/online/switching_pc/slowcontrol/mutrig/Mutrig_FEB.cpp`. For Phase 5 bring-up under board_test, `configure_mutrig_from_xml.py` mirrors the FE SciFi toolkit parameter ordering, stages the 84-word packed bitstream via `sc_tool` writes into `scratch_pad_ram`, and commits it via `mutrig_cfg_ctrl_0.OPCODE_STATUS`. The production C++/toolkit flow remains the packing reference if the helper and hardware evidence disagree.

For rate checkpoints, keep the source boundary explicit: the active Phase-5 image exports `mutrig_injector_0.inject` through `emulator_inject_fanout` out8 to the physical `feb_inject_pulse` net, which then drives `scifi_inject`, `scifi_inject2`, and `scifi_ainj`. Real-MuTRiG 100 kHz stimulus uses the `mutrig_injector_0` CSR window at SC word base `0x0AC80`, periodic mode `2`, and pulse interval `1250` cycles. Deprecated legacy pulse-control names such as `MUTRIG_CNT_CTRL_REGISTER_W`, `pll_test_mode(0)`, and `o_pll_test` are not valid Phase-5 injector controls unless a future Qsys image explicitly remaps and proves them.

### 1.5 Document conventions reused from Phase 4

This plan adopts the BASIC catalog conventions from [`phase4/TEST_PLAN_BASIC.md`](phase4/TEST_PLAN_BASIC.md):

- **method** — `D` = directed, `R` = random multi-seed
- **implementation** — `live BOARD` = on-board run via `../systems/system_20260427_testplanphase5/script/`; `live STP` = SignalTap segmented capture; `live CMP` = DISLIN cross-layer / cross-source compare; `planned` = stimulus exists, runner not yet wired
- **stage** — `B` = on-board, `S` = SignalTap segmented capture, `C` = cross-source DISLIN compare against the Phase 4 emulator reference

Phase 5 is on-board-first by construction; the TLM/RTL-SIM rows of Phase 4 are the **reference** that real-MuTRiG cases compare against.

### 1.6 Functional coverage accounting and bucket files

Phase 5 directed verification (§3) is split into four functional-coverage buckets, each with its own catalog Markdown:

| Coverage bucket | Catalog file | Minimum cases | Scope |
|---|---|---:|---|
| INJECTOR-PATH gate | [`TEST_INJECTOR_PATH.md`](TEST_INJECTOR_PATH.md) | gate only | Live `mutrig_injector_0` to fanout to source path boundary debug. This must pass or be explicitly bypassed before any real/injector-dependent BASIC/PROF cases are claimed. |
| BASIC | [`TEST_BASIC.md`](TEST_BASIC.md) | ≥ 144 | Nominal end-to-end hit propagation across the full IP chain (`emulator_mutrig` / real MuTRiG → `mutrig_frame_deassembly` → `backpressure_fifo` → `mux_mutrig2processor` → `mts_processor` → `histogram_ingress_bridge` → `ring_buffer_cam` → `feb_frame_assembly` → SWB ingress) at low rate, with hits restricted to selected (ASIC, channel) combinations and counted at every IP boundary. |
| PROF | [`TEST_PROF.md`](TEST_PROF.md) | ≥ 144 | Performance / rate-pressure cases — emulator and real-MuTRiG hit-rate sweeps, per-lane skew, ring-CAM and backpressure-FIFO fill-level pressure, sustained-run soak. Uses GTS-armed segmented acquisition to capture multi-frame propagation under load. |
| EDGE | [`TEST_EDGE.md`](TEST_EDGE.md) | ≥ 144 | Run-state transition corner cases — first hit after `RUNNING`, terminating last hit before `TERMINATING`-idle-guard close, frame-counter rollover, GTS rollover, MTS subheader-timestamp wrap, abort during run, in-flight hits at SYNC and TERMINATING. |
| ERROR | [`TEST_ERROR.md`](TEST_ERROR.md) | ≥ 144 | Negative-path / error-injection cases — bit-flip code/disp errors, torn frames, bad CRC, MTS `tsglitcherr`, FIFO overflow, ring-CAM saturation, terminating-idle-guard violation. Each case must be observable on a per-IP `*_error` AVST flag, a CSR overflow counter, or a SignalTap-tappable internal status. |

**Minimum cases is a floor, not a target.** Each bucket is expected to grow into the 500–3000-case range as Mu3e-side experience and additional formal-cover-driven cases are added. The current revision provides ≥ 144 well-motivated cases per bucket as the directed-verification entry catalog.

The §3 bucket files own the case enumeration. The TEST_PLAN_PHASE5 §3 sections only list the IP-boundary tap stations, the multi-instance SignalTap arming model, and the bucket cross-references — the case rows themselves live in the four bucket files.

The four bucket files are the **plaintext SignalTap sub-test plans**. They are not optional appendices and must not be dropped from Phase-5 closure. Each row is an executable capture contract: stimulus, trigger mode, armed tap stations, expected evidence, and eventual `tb_int/` match. Generated `.stp` files under `../systems/system_20260427_testplanphase5/signaltap/` are derived implementation artifacts; if an `.stp` and a bucket row disagree, patch the generator or the `.stp` to match the plaintext bucket row before running hardware.

Cross-source closure: every Phase-5 §3 BASIC/PROF/EDGE/ERROR case must have a matching `tb_int/` integration-sim case in the long term (closure requirement). The required match is *event-equivalence*: the same hit propagation pattern observed in SignalTap must be reproducible in `tb_int/` with the same per-IP boundary checkers. This plan does not enforce 1:1 today; the bucket files mark each case with `MATCH:` placeholder rows that will be backfilled as `tb_int/` covers grow.

Current bucket catalog size in this revision:

| Bucket | Cataloged cases (this revision) | Floor | Long-term target |
|---|---:|---:|---:|
| BASIC | 144 | 144 | 500–3000 |
| PROF | 144 | 144 | 500–3000 |
| EDGE | 144 | 144 | 500–3000 |
| ERROR | 144 | 144 | 500–3000 |

### 1.7 Scoreboard use

This plan is also the live Phase-5 scoreboard. The four bucket files are updated after every board run, SignalTap capture, or matching `tb_int/` run. Use the following status vocabulary:

| Status | Meaning |
|---|---|
| `not-run` | case or group is specified but has no accepted evidence yet |
| `ready` | stimulus, `.stp`, trigger, and counters are prepared, but the case has not run |
| `running` | capture/run is in progress or evidence is being reduced |
| `PASS` | all listed evidence is present, counters match, and artifact links are recorded |
| `PASS_SCOPED` | the listed sub-scope passes and is useful closure evidence, but the wider matrix named by the row remains open |
| `FAIL` | case ran and violated the listed evidence |
| `BLOCKED` | case cannot run because prerequisite hardware, `.stp`, source mux, or injector control is missing |
| `WAIVED` | deliberately removed from closure, with a reason and reviewer/date recorded |

Ranged case rows are not marked `PASS` unless every case in the range passed. If only part of a range runs, split the row or add an explicit subrange note in that bucket's scoreboard with the evidence artifact path. The group scoreboard in each bucket file is the first-level record; detailed evidence belongs under `../systems/system_20260427_testplanphase5/reports/phase5_<bucket>_<date>.md` and capture snapshots under `../systems/system_20260427_testplanphase5/signaltap/`.

Current top-level scoreboard:

| Bucket | Cases | not-run | ready | running | PASS | FAIL | BLOCKED | Last evidence |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| BASIC | 144 | 104 | 0 | 0 | 0 | 0 | 40 | [`../systems/system_20260427_testplanphase5/reports/phase5_nostp_pipe_rebuild_datapath_followup_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_nostp_pipe_rebuild_datapath_followup_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_repeat100_250ms_nostp_pipe_rebuild_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_repeat100_250ms_nostp_pipe_rebuild_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_runctl_mts_stage_hiterr_followup_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_runctl_mts_stage_hiterr_followup_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_frame_hist_mts_histstats_stp_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_frame_hist_mts_histstats_stp_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_real03_mts_input_hiterr_debug_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_real03_mts_input_hiterr_debug_20260429.md) |
| PROF | 144 | 112 | 0 | 0 | 0 | 0 | 32 | [`../systems/system_20260427_testplanphase5/reports/phase5_nostp_pipe_rebuild_datapath_followup_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_nostp_pipe_rebuild_datapath_followup_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_repeat100_250ms_nostp_pipe_rebuild_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_repeat100_250ms_nostp_pipe_rebuild_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_runctl_mts_stage_hiterr_followup_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_runctl_mts_stage_hiterr_followup_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_injector_emulator_l0_histstats_valid_stp_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_emulator_l0_histstats_valid_stp_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_injector_emulator_l0_broadcast_sweep_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_emulator_l0_broadcast_sweep_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_real03_mts_input_hiterr_debug_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_real03_mts_input_hiterr_debug_20260429.md) |
| EDGE | 144 | 144 | 0 | 0 | 0 | 0 | 0 | none |
| ERROR | 144 | 144 | 0 | 0 | 0 | 0 | 0 | none |

Current pre-case injector gate:

| Gate | Status | Evidence | Interpretation |
|---|---|---|---|
| Integration sim, injector mode 2 -> emulator path | `PASS` | [`../systems/system_20260427_testplanphase5/reports/phase5_injector_datapath_sim_20260428.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_datapath_sim_20260428.md), [`../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_injector_authentic.sh`](../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_injector_authentic.sh), [`../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/REPORT/dp_injector_authentic/run_dp_injector_authentic_dualmts_20260429.console.log`](../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/REPORT/dp_injector_authentic/run_dp_injector_authentic_dualmts_20260429.console.log), [`../systems/system_20260427_testplanphase5/syn/logs/qsys_generate_scifi_datapath_system_v3_pipe_dualmts_debug_active_20260429.log`](../systems/system_20260427_testplanphase5/syn/logs/qsys_generate_scifi_datapath_system_v3_pipe_dualmts_debug_active_20260429.log), [`../systems/system_20260427_testplanphase5/syn/logs/qsys_generate_feb_system_v3_pipe_dualmts_debug_active_20260429.log`](../systems/system_20260427_testplanphase5/syn/logs/qsys_generate_feb_system_v3_pipe_dualmts_debug_active_20260429.log) | Authentic generated-system rerun disables the decoded-din force path and uses generated run-control fanout. It passes with source muxes programmed to emulator, 160 accepted type0 transfers, 160 MTS type1 outputs, 160 rate-hist hits, 160 latency-hist hits, and zero histogram drops/underflows/overflows. Rechecked after regenerating the active dual-MTS histogram image (`histogram_statistics_v2` 26.1.4, `debug_1=upper MTS ts_delta`, `debug_2=lower MTS ts_delta`, `debug_3..6=upper ring-CAM fill levels`) with the same 4/4 PASS result. The next generated image is required to carry `histogram_statistics_v2` 26.1.5, which adds debug-mode CSR filtering on synthetic debug source bits. |
| Integration sim, histogram v26.1.6 last-interval image | `PASS` | [`../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/REPORT/dp_injector_authentic/run_dp_injector_authentic_histv6_20260429_204902.console.log`](../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/REPORT/dp_injector_authentic/run_dp_injector_authentic_histv6_20260429_204902.console.log), [`../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/REPORT/dp_injector_authentic/pre_rbcam_rate_hist.csv`](../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/REPORT/dp_injector_authentic/pre_rbcam_rate_hist.csv), [`../systems/system_20260427_testplanphase5/reports/phase5_histv6_real_rate_closure_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_histv6_real_rate_closure_20260429.md) | Authentic generated-system simulation of the current regenerated Qsys image passes 4/4. Pre-RBCAM measurement reports 160 accepted type1 words, eight active lanes, 20 samples per lane at channel 16, latency total 160, and no latency underflow. |
| Live board, emulator source, injector mode 2 | `PASS` | [`../systems/system_20260427_testplanphase5/reports/phase5_dualmts_quick_csr_closure_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_dualmts_quick_csr_closure_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_dualmts_quick_csr_closure_20260429.html`](../systems/system_20260427_testplanphase5/reports/phase5_dualmts_quick_csr_closure_20260429.html), [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_rate100k_10k_quick_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_rate100k_10k_quick_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_delay100k_quick_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_delay100k_quick_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_header1_2_4_quick_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_header1_2_4_quick_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_nostp_pipe_rebuild_datapath_followup_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_nostp_pipe_rebuild_datapath_followup_20260429.md) | After SWB reload, PCIe recovery, and broadcast `rc_tool stop-reset --feb 7`, emulator lane 0 produces MTS/histogram hits with zero drops, zero MTS discards, zero ring input errors, and monotonic interval response. The rebuilt timing-clean no-STP image checksum `0x13C7FEDB` passed the initial emulator smoke; the newer dual-MTS no-STP image checksum `0x13DB4566` passes the quick-CSR emulator collective matrix: 18/18 rate rows, 9/9 delay rows, and 27/27 header-mode rows, all with zero histogram drops. |
| Live board, histogram v26.1.6 emulator source, rate mode | `PASS` | [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_emulator_lane0_rate100k_histv6_20260429_214318.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_emulator_lane0_rate100k_histv6_20260429_214318.md), [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_emulator_lane0_rate100k_histv6_20260429_214318.json`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_emulator_lane0_rate100k_histv6_20260429_214318.json) | The current image proves the `LAST_INTERVAL_TOTAL_HITS` CSR path on board: emulator lane0 100 kHz reports 99,842 / 100,000 hits (`-0.158%`), zero drops, zero MTS discards, and zero ring input errors. |
| Live board, real source, rate mode scoped lanes 0 and 3 | `PASS_SCOPED` | [`../systems/system_20260427_testplanphase5/reports/phase5_histv6_real_rate_closure_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_histv6_real_rate_closure_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_real_lane0_rate100k_histv6_real_scopefix_20260429_214703.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_real_lane0_rate100k_histv6_real_scopefix_20260429_214703.md), [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_real_lane0_rate10k_histv6_real_scopefix_20260429_214739.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_real_lane0_rate10k_histv6_real_scopefix_20260429_214739.md), [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_real_lane3_rate100k_histv6_real_scopefix_20260429_214807.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_real_lane3_rate100k_histv6_real_scopefix_20260429_214807.md), [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_real_lane3_rate10k_histv6_real_scopefix_20260429_214838.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_real_lane3_rate10k_histv6_real_scopefix_20260429_214838.md) | Real lane0 and lane3 pass 100 kHz and 10 kHz periodic rate checks within the 1% criterion using the v26.1.6 last-interval CSR. Lane0: 99,839 / 100,000 (`-0.161%`) and 9,998 / 10,000 (`-0.020%`). Lane3: 99,841 / 100,000 (`-0.159%`) and 9,999 / 10,000 (`-0.010%`). All four scoped rows have zero histogram drops, zero MTS discards, and zero ring input errors. The failed pre-fix row [`phase5_hist_matrix_real_lane0_rate100k_histv6_20260429_214226.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_real_lane0_rate100k_histv6_20260429_214226.md) is retained as a source-mux contamination diagnostic: `selected_source_mask=0x00` selected all real lanes, producing 629,938 / 100,000 hits and 928,293 ring input errors. |
| Live board, real source, injector mode 2 | `BLOCKED` | [`../systems/system_20260427_testplanphase5/reports/phase5_nostp_pipe_rebuild_datapath_followup_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_nostp_pipe_rebuild_datapath_followup_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_repeat100_250ms_nostp_pipe_rebuild_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_repeat100_250ms_nostp_pipe_rebuild_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_repeat20_250ms_nostp_pipe_rebuild_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_repeat20_250ms_nostp_pipe_rebuild_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_runctl_mts_stage_hiterr_followup_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_runctl_mts_stage_hiterr_followup_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_repeat40_250ms_post_hiterr_timeout_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_repeat40_250ms_post_hiterr_timeout_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_frame_hist_mts_histstats_stp_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_frame_hist_mts_histstats_stp_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_real03_mts_input_hiterr_debug_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_real03_mts_input_hiterr_debug_20260429.md) | Real lanes 0/3 are injector-correlated after ASIC0/ASIC3 XML configuration and channel-16-only overrides, and the recompiled frame/MTS/histogram STP proves the path can reach `histogram_statistics_0.asi_hist_fill_in_valid`. Earlier repeated 250 ms windows reproduced one MTS discard in 5 windows and one in 8 windows while keeping histogram drops, ring input errors, and frame CRC errors at zero; the successful input-hiterr trigger showed the discarded beat was already flagged as `mutrig_frame_deassembly_0.aso_hit_type0_error[0]` before MTS. After the fresh runctl/MTS-stage rebuild/program (`0x145AA92C`), the same hiterr trigger timed out, 52 debug-image follow-up windows passed, and the rebuilt timing-clean no-STP image checksum `0x13C7FEDB` passed a 100/100 accepted soak: histogram `3,185,632`, MTS `2,485,619`, frame actual/declared `3,103,835`, zero MTS discards, zero ring input errors, zero histogram drops, zero frame CRC errors, and zero missing hits. Keep the gate blocked only for full-lane closure until lanes 1/2/4/5/6/7 are recovered or explicitly waived. |
| No-STP firmware timing after dual-MTS histogram fix | `PASS` | [`../systems/system_20260427_testplanphase5/reports/phase5_dualmts_quick_csr_closure_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_dualmts_quick_csr_closure_20260429.md), [`../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_nostp_pipe_dualmts_debug_20260429.console.log`](../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_nostp_pipe_dualmts_debug_20260429.console.log), [`../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/program_top_nostp_pipe_dualmts_debug_20260429.log`](../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/program_top_nostp_pipe_dualmts_debug_20260429.log), [`../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.fit.summary`](../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.fit.summary), [`../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.sta.summary`](../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.sta.summary), [`../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.sof`](../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.sof) | The 2026-04-29 dual-MTS rebuild includes the histogram timing fixes plus `histogram_statistics_v2` mode `-7` for upper/lower MTS delay capture. Map/Fit/ASM/STA complete with 0 errors / 1731 warnings; elapsed `00:38:47`. STA is timing-clean: slow 85 C setup WNS `+0.318 ns` on LVDS `pll_sclk`, all listed TNS `0.000`. The programmed SOF checksum is `0x13DB4566` (`cksum` CRC `0xB4F49A95`); the prior checksum `0x13C7FEDB` is retained only as the pre-dual-MTS histogram timing-fix baseline. |
| No-STP firmware timing after histogram v26.1.6 last-interval fix | `PASS` | [`../systems/system_20260427_testplanphase5/reports/phase5_histv6_real_rate_closure_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_histv6_real_rate_closure_20260429.md), [`../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_nostp_pipe_histv6_20260429_205028.console.log`](../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_nostp_pipe_histv6_20260429_205028.console.log), [`../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/program_top_nostp_pipe_histv6_20260429.log`](../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/program_top_nostp_pipe_histv6_20260429.log), [`../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.fit.summary`](../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.fit.summary), [`../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.sta.summary`](../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.sta.summary), [`../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.sof`](../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.sof) | Map/Fit/ASM/STA complete with `0 errors / 1734 warnings`; elapsed `00:48:53`. STA is timing-clean: slow 85 C setup WNS `+0.454 ns`, hold WNS `+0.241 ns`, recovery `+1.156 ns`, removal `+0.464 ns`, min-pulse `+0.160 ns`, and all listed TNS `0.000`. The programmed SOF checksum is `0x13A9CC2D`; SOF `cksum` is `3252249893 12694619`, SHA-256 `6dcf331d6fd8cc541dbd91b5d8ddedaee95d4a15baaeb41e4fd69e5e031832be`. |
| Directed SignalTap probe list | `PASS` | [`../systems/system_20260427_testplanphase5/signaltap/phase5_injector_path_lvds.nodes.md`](../systems/system_20260427_testplanphase5/signaltap/phase5_injector_path_lvds.nodes.md), [`../systems/system_20260427_testplanphase5/reports/phase5_injector_signaltap_compile_20260428.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_signaltap_compile_20260428.md), [`../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe_phase5_injector_stp/top_stp_pipe_phase5_injector.sof`](../systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe_phase5_injector_stp/top_stp_pipe_phase5_injector.sof) | Injector-path micro STP generation/import/compile is clean: 31/31 pre-synthesis probes, 95/95 post-map SignalTap pins, map/fit/ASM/STA with 0 errors. STA is timing-clean: slow 85 C setup WNS `+0.337 ns` overall and `+0.447 ns` on LVDS `pll_sclk`; slow 0 C setup WNS `+0.521 ns` on LVDS `pll_sclk`; all TNS `0.000`. The rebuilt 2026-04-29 micro SOF was programmed and used for the pre-armed capture. |
| Injector micro STP runtime | `PASS_WITH_METHOD_NOTE` | [`../systems/system_20260427_testplanphase5/reports/phase5_injector_prearmed_stp_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_prearmed_stp_20260429.md), [`../systems/system_20260427_testplanphase5/captures/phase5_injector_path_prearmed_periodic_20260429.vcd`](../systems/system_20260427_testplanphase5/captures/phase5_injector_path_prearmed_periodic_20260429.vcd), [`../systems/system_20260427_testplanphase5/reports/phase5_injector_signaltap_capture_20260429_063441.log`](../systems/system_20260427_testplanphase5/reports/phase5_injector_signaltap_capture_20260429_063441.log) | SC pre-arm method passes: program injector over SC first, capture in SignalTap while periodic pulses are already running, then stop injector over SC. VCD shows the pulse chain through `periodic_injector_pulse`, injector conduit, fanout lane 0, emulator input synchronizer, and `inject_pulse_clk`; `avs_csr_waitrequest` stays 0. The old concurrent wrapper remains a known-bad method because SC timed out while SignalTap was armed. |

---

## 2. Real-MuTRiG bring-up via `mutrig_cfg_ctrl_0`

### 2.1 What this stage proves

After SOF reflash and Phases 1..4 PASS, the FEB SciFi v3 contains both the eight `emulator_mutrig` cores and the live LVDS/MuTRiG decode path. `mutrig_lane_source_mux_[0..7].csr` selects the source at run time; reset default is real MuTRiG for Phase 5, while `script/set_mutrig_lane_sources.py` can switch all lanes to emulator or any mixed 8-bit mask. Phase 5.A is the act of proving the integration build can run **real-MuTRiG-fed** by ensuring:

1. The `mutrig_cfg_ctrl_0` IP can stage a 2662-bit cfg bitstream into the IP's internal CFG-mem RAM via DMA from `scratch_pad_ram`, then SPI-write that bitstream into each MuTRiG3.
2. Every MuTRiG returns a frame_header + payload + trailer at the FEB-side `mutrig_frame_deassembly_N.csr` decoder for at least one full integration interval.
3. The TSA (TTH Scan Automation) co-routine sweeps the per-channel threshold and reports a sane, monotonic dark-rate vs threshold curve — which then anchors a known-good operating threshold per ASIC for §3 and the future §4 collective-PDF stage.

### 2.2 mutrig_cfg_ctrl_0 CSR contract

Per [`../../mutrig_controller/mutrig_ctrl.vhd`](../../mutrig_controller/mutrig_ctrl.vhd) and [`../../mutrig_controller/mutrig_cfg_ctrl.svd`](../../mutrig_controller/mutrig_cfg_ctrl.svd), the controller exposes a 4-word CSR aperture:

| Word | Name | Direction | Field layout |
|---|---|---|---|
| `0x00` | `OPCODE_STATUS` | RW | write: `[31:20]=command`, `[19:16]=asic_id`, `[15:0]=cfglen_words`. Read while busy: `[31:16]=opcode_echo`, `[15:0]=status_word`; read while idle: `0x00000000` |
| `0x01` | `OFFSET` | RW | scratchpad byte offset where the cfg bitstream begins, matching `mutrig_ctrl.vhd` `avm_schpad_address` |
| `0x02` | `MONITOR_SECONDS` | RW | counter integration interval in seconds |
| `0x03` | reserved | — | reads zero |

Opcodes (per `mutrig_ctrl.vhd:202..204`):

| Constant | Hex | Meaning |
|---|---|---|
| `CMD_MUTRIG_ASIC_CFG` | `0x011` | DMA `cfglen_words` 32-bit words from `scratch_pad_ram[OFFSET..]` into the IP's CFG-mem partition for `asic_id`, then SPI-write `MUTRIG_CFG_LENGTH_BIT` bits to the MuTRiG. |
| `CMD_MUTRIG_ASIC_TTH_SCAN` | `0x012` | sweep per-channel TTH for `asic_id` over 64 steps; record per-(channel, TTH) hit-rate into the Result RAM exposed at `avs_scanresult_*`. Requires that the MuTRiG was already configured at least once via `CMD_MUTRIG_ASIC_CFG` (per the controller's note). |
| `CMD_MUTRIG_ASIC_TTH_SCAN_ALL` | `0x014` | Intended all-ASIC TSA helper used by the FE SciFi toolkit. For Phase-5 board signoff, prefer the per-ASIC `0x012` loop unless `0x014` is first proven live on the flashed RTL; see §8. |

**Important constants** (from `mutrig_ctrl.vhd:201, 210..213`):

- `CFG_MEM_PARTITION_SIZE_WORD = 128` — each ASIC has a 128-word internal cfg-mem partition.
- `MUTRIG_CFG_WORDS = ceil(2662/32) = 84 = 0x0054` — this is the value written to `cfglen_words` and matches `toolkits/fe_scifi/system_console/lib/mutrig_controller_toolkit_gui.tcl`.
- `CFG_HEADER_LENGTH = 34` bits, `CFG_SINGLE_CH_LENGTH = 71` bits, `CFG_SINGLE_CH_TTH_OFFSET = 24` bits, `CFG_TTH_SETTING_LENGTH = 6` bits, `CFG_N_CH = 32`.
- `MUTRIG_CFG_LENGTH_BIT = 2662` for MuTRiG3; the controller rounds this internally to 2688 bits for SPI shifting. This is **not** the `cfglen_words` field.

### 2.3 Bring-up procedure

This is a procedure description; the actual execution wraps `sc_tool`, `configure_mutrig_from_xml.py`, and reuses `run_phase4_emulator.py`'s run-control sequence where a timed run window is needed. The production MuTRiG packing remains the reference; helper scripts are allowed only to stage, issue, poll, and report that flow.

1. **Pre-flight**:
    - `script/check_ip_metadata.py` and `script/check_sc_bridges.py` clean.
    - `script/set_mutrig_lane_sources.py --mode real --clear-counters` succeeds; use `--mode emulator` for Phase-4 reference reruns and `--mode mixed --mask 0xNN` for lane-by-lane A/B tests.
    - `rc_tool status` reports IDLE (no run armed).
    - Read `mutrig_cfg_ctrl_0.OPCODE_STATUS` (`0x0FC04`) and confirm the full word is `0x00000000` (idle).

2. **Stage cfg bitstream** for ASIC `k ∈ {0..7}`:
    - Compute the cfg-bitstream **word stream** from the production packing used by `/home/yifeng/packages/online_dpv2/online/switching_pc/slowcontrol/mutrig/Mutrig_FEB.cpp` and the FE SciFi toolkit (a sequence of 84 32-bit words holding the 2662-bit packed bitstream, padded to a word boundary). The board-test helper for this is `script/configure_mutrig_from_xml.py`; if its word order is questioned, compare it bit-for-bit against the production C++/Tcl path before changing hardware expectations.
    - Block-write that single ASIC's 84-word stream into `scratch_pad_ram` at `OFFSET_BYTE = 0x000` (`sc_tool` word address `0x00000`). Reuse the same scratchpad window for each ASIC; do **not** stage all eight ASIC streams back-to-back.
    - The next opcode's `cfglen_words` field is `0x0054` (84 words). The 2662-bit SPI length comes from the IP generic, not from the opcode.

3. **Issue `CMD_MUTRIG_ASIC_CFG`** for ASIC `k`:
    - `sc_tool write 0x0FC05 0x00000000` (`OFFSET` is a scratchpad byte offset as seen by the controller).
    - `sc_tool write 0x0FC04 [(0x011 << 20) | (k << 16) | 0x0054]`.
    - Poll `OPCODE_STATUS` until the full word returns `0x00000000`. While busy, record `[31:16]` for the opcode echo and `[15:0]` for progress/status.

4. **Verify decoded frames** at `mutrig_frame_deassembly_k.csr`:
    - Read the per-IP UID/VERSION/STATUS aperture.
    - Confirm the per-IP frame-counter advances over a 100 ms interval (i.e. the deassembler is locked on the live K28.5 idle stream and decoding K28.0 SOPs).
    - If any deassembler does not advance, halt — that ASIC was not configured (most likely scratchpad word stream was wrong), and `/home/yifeng/packages/online_dpv2/online/switching_pc/slowcontrol/mutrig/Mutrig_FEB.cpp` is the reference for the bit packing.

5. **Run TSA before real-MuTRiG §3 cases**:
    - Preferred signoff sequence: for each ASIC `k`, `sc_tool write 0x0FC04 [(0x012 << 20) | (k << 16) | 0x0054]`.
    - `CMD_MUTRIG_ASIC_TTH_SCAN_ALL` (`0x01400054`) may be used only after it is proven on the flashed RTL. The current source tree contains both the toolkit all-scan command and a controller command-legalization path that should be checked if all-scan hangs.
    - The TSA increments TTH 0..63 and writes `(per-channel, per-TTH)` rate into the Result RAM exposed via `avs_scanresult_*` (14-bit address aperture).
    - Read out the full 8 × 32 × 64 result block; for each ASIC and each channel, record the TTH knee position. The knee per channel is the candidate operating threshold for that channel.
    - Bind the per-channel threshold into a *known-good* set in the cfg bitstream by re-running step 3 with the updated cfg word stream. Record this stream as the Phase-5 baseline.

6. **Save the baseline**: write the resulting per-ASIC, per-channel TTH table to `../systems/system_20260427_testplanphase5/reports/phase5_mutrig_baseline_<date>.md`. This file is the *only* implementation-bearing artifact this plan calls for, and it is data, not code.

### 2.4 Pass / fail

Phase 5 §2 PASSES when:

- All eight `mutrig_frame_deassembly_k` blocks report incrementing frame counters for at least 100 ms with no reported decoder errors.
- The `histogram_statistics_0` `TOTAL_HITS` advances over a 1 s window with the live MuTRiG-fed datapath.
- The TSA result RAM contains a sane, per-channel monotonic rate-vs-TTH curve for every (ASIC, channel) pair (no zero columns; no flatline rows).
- The baseline cfg word stream is recorded.

Phase 5 §2 FAILS hard if any of the eight ASICs cannot lock its decoded frame within the integration interval — that is the prerequisite gate for §3 and any future §4 collective-PDF work. A common symptom and its first-pass debug entry point are listed in §6.

Current §2 scoreboard:

| Check | Status | Evidence | Notes |
|---|---|---|---|
| XML pack dry-run, ASIC 0 | `PASS` | [`../systems/system_20260427_testplanphase5/reports/phase5_mutrig_config_dryrun_asic0_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_mutrig_config_dryrun_asic0_20260429.md) | Packed 84 words from the FE SciFi XML/Tcl parameter order without hardware writes. |
| XML cfg command, ASIC 0 | `FAIL_LOCK` | [`../systems/system_20260427_testplanphase5/reports/phase5_mutrig_config_asic0_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_mutrig_config_asic0_20260429.md) | `mutrig_cfg_ctrl_0` returned idle, but `mutrig_frame_deassembly_0` did not advance over the post-config window. LVDS status/error counters point to a lane training/config/physical-link issue that must be debugged before §3 real-source rows can move out of `BLOCKED`. |

---

## 3. Directed verification — IP-by-IP cascade SignalTap signoff

§3 is the **directed** Phase-5 closure: every nominal hit produced at the source must be observed at every IP boundary on the way to the SWB ingress. Each case in the four bucket files ([`TEST_BASIC.md`](TEST_BASIC.md), [`TEST_PROF.md`](TEST_PROF.md), [`TEST_EDGE.md`](TEST_EDGE.md), [`TEST_ERROR.md`](TEST_ERROR.md)) defines one stimulus configuration plus the SignalTap evidence required to attest the case.

### 3.1 SignalTap segmented-acquisition contract used in §3

Verified against the Intel Quartus Prime documentation and an example `.stp` in this repo:

- The default Basic / Advanced trigger flow has **one trigger condition per analyzer instance**. In segmented acquisition the analyzer fills the next segment on each trigger occurrence — the trigger expression is global, only the trigger position is per-acquisition.
- Different per-segment trigger conditions exist only via **state-based trigger flow** (`<segment_trigger>` actions inside `<flow>/<state>` blocks). State-based flow is not used in this plan: each `.stp` instance below carries one trigger condition. When several trigger conditions are required, several `.stp` instances are armed in parallel, or the same `.stp` is re-armed with a different trigger between runs.

Sources: Intel "Segmented Buffer" page in the Quartus Prime Pro 22.1 Debugging User Guide; KDB rd12022004_7762 (custom trigger position in segmented buffers); the example `firmware_builds/systems/system_20260427_testplanphase5/signaltap/phase4c_runctl_ready_fanout_high.stp` lines 239..242 (`segment_size="1"`, single `<level name="condition1" type="basic">`). The codex skill `signaltap-creation-co-debug` does not document segmented acquisition, so the verdict is based on Intel's docs.

**Segment depth is sized per IP, not globally.** A short MuTRiG frame is 910 cycles; capturing a SOP-anchored window with at least one full payload + one trailer comfortably fits in **1024 samples × 4 segments**, which is the default for IPs in the per-MuTRiG / per-deassembler / per-FIFO chain. The `feb_frame_assembly` outbound packet is longer at high rate — that instance uses **4096 × 4 segments**. Default depths per tap station are listed in §3.4.

**Capture position is 50% pre / 50% post-trigger** for SOP/EOP triggers so the segment retains both the inter-frame K28.5 idle preceding the SOP and the payload that follows. This is the position used unless a case explicitly overrides it.

### 3.2 The chain under test (canonical IP boundaries)

```text
  emulator_mutrig_N (or real MuTRiG via mutrig_cfg_ctrl_0)
     │  aso_tx8b1k[8:0] (lvds_rx_28nm_0.outclock @ 156.25 MHz)
     ▼
  mutrig_frame_deassembly_N  (frame_rcv_ip.vhd)
     │  aso_hit_type0 — channel[5:0], data[44:0], sop, eop, endofrun, error[2:0], valid, ready
     │  csr.frame_counter / frame_counter_head / frame_counter_tail
     ▼
  backpressure_fifo_N        (alt_dcfifo wrapper, depth=128, USE_FILL_LEVEL=1)
     │  aso (out) hit_type0 + filllevel[6:0]
     ▼
  mux_mutrig2processor_{0,1} (lane mux, 8 lanes → 1 processor each)
     │  aso hit_type0 muxed
     ▼
  mts_processor_{0,1}        (mts_processor.vhd; gts_8n counter, mts→gts mapping)
     │  aso_hit_type1 — channel[3:0], data[38:0], sop, eop, empty, error, valid, ready
     │  d_gts_counter[47:0] (48-bit global timestamp at 8 ns step)
     ▼
  histogram_ingress_bridge_0 (pre/post tap selector)
     │  pre_in / pre_out / post_out for hit_stack_subsystem_0; subsystem_1 bypasses this bridge
     ▼
  hit_stack_subsystem_M.ring_buffer_cam_K (M=0..1, K=0..3; depth=512, key=8 bits, side=31 bits)
     │  asi_hit_type1 → aso_hit_type2 — channel[3:0], data[35:0], sop, eop, valid, ready, error
     │  aso_filllevel[15:0]
     ▼
  feb_frame_assembly_{0,1}   (feb_frame_assembly.vhd; INTERLEAVING_FACTOR=4, N_SHD=128)
     │  aso_hit_type3 — data[35:0], sop, eop, valid, ready
     │  counter_gts_8n[47:0], frame_cnt[35:0], terminating_marker_*
     ▼
  upload_subsystem.upload_data → LVDS TX (xcvr_clock 156.25 MHz)
     ▼  (link 2, 8b/10b)
  SWB ingress 8b/10b decoder (online_sc) → SWB per-link hit counter
```

Sources for the boundary signal lists and counter widths:
- `mutrig_frame_deassembly/rtl/frame_rcv_ip.vhd:85..98, 119..121, 240, 260` (run_state, hit_type0 ports, frame_counter shadow).
- `mutrig_timestamp_processor/mts_processor.vhd:158..182, 345, 411, 515..516, 547..549` (hit_type0 in, hit_type1 out, run_state_t, gts counter, delta_timestamp).
- `ring-buffer_cam/rtl/ring_buffer_cam.vhd:37..58` (hit_type1 in, hit_type2 out, filllevel).
- `feb_frame_assembly/feb_frame_assembly.vhd:51..96, 290..303, 485..487, 551, 585..610` (hit_type2 in, hit_type3 out, gts counter, frame_cnt, run_state_t).
- `firmware_builds/systems/system_20260427_testplanphase5/syn/feb_system_v3_pipe.qsys` AVMM map (CSR address bases).
- `firmware_builds/systems/system_20260427_testplanphase5/syn/scifi_datapath_system_v3_pipe.qsys:1238..1266, 2308..2378, 2870..3029` (two hit-stack subsystems, four ring-CAM partitions each, and stream wiring).

### 3.3 Multi-instance SignalTap arming model

Phase-5 §3 arms **one SignalTap instance per IP boundary** in the same Quartus build. The analyzer instances run on their respective IP clocks (`lvds_rx_28nm_0.outclock @ 156.25 MHz` for the byte-stream end-points; `data_path_clock @ 125 MHz` for the AVST hit_type stages). Each instance taps the same `gts_8n_counter` (a low-bit slice mirrored into its own clock domain — `counter_gts_8n` in `feb_frame_assembly` and `d_gts_counter` in `mts_processor`; for upstream IPs a small free-running counter on the IP's own clock is used as the SignalTap-only timing anchor and the GTS-equivalent slice is correlated post-capture via a single common-clock cycle alignment).

Each case in the four bucket files specifies:

1. The stimulus configuration (emulator CSR / real-MuTRiG cfg / injector mode + parameters / run-control sequence).
2. The set of SignalTap instances that must be armed for the case.
3. The trigger condition for each instance — typically equality on `gts_8n_counter[N:0] == TARGET_GTS` so all instances trigger on the same frame, or a packet-boundary K-symbol (K28.0/K28.4/sub-header) for byte-stream taps.
4. The expected per-instance evidence: which channel-ID/lane appears in the captured AVST stream, which counter increments are expected at the IP's CSR shadow, and the per-IP `*_error` flag must stay deasserted (or assert if the case is in ERROR).

### 3.4 Per-IP tap station defaults

| ID | Tap station | `.stp` instance name | Clock | Default depth × segments | Probed signals (minimum) |
|---|---|---|---|---|---|
| T0 | `emulator_mutrig_N.aso_tx8b1k` (or real-MuTRiG byte-stream into LVDS-RX deassembler) | `phase5_t0_emulator_egress` | `lvds_rx_28nm_0.outclock` (156.25 MHz) | 1024 × 4 | `aso_tx8b1k_valid`, `aso_tx8b1k_data[8:0]`, `gts_8n_lo[15:0]`, `run_state[8:0]` |
| T1 | `mutrig_frame_deassembly_N.aso_hit_type0` | `phase5_t1_frame_deassembly` | `data_path_clock` (125 MHz) | 1024 × 4 | `aso_hit_type0_{valid, ready, sop, eop, endofrun}`, `aso_hit_type0_data[44:0]`, `aso_hit_type0_channel[5:0]`, `aso_hit_type0_error[2:0]`, `csr.frame_counter[15:0]`, `gts_8n_lo[15:0]` |
| T2 | `backpressure_fifo_N.out` + `filllevel` | `phase5_t2_backpressure_fifo` | `data_path_clock` | 1024 × 4 | hit_type0 AVST out, `filllevel[6:0]`, drop indicator (if exposed), `gts_8n_lo[15:0]` |
| T3 | `mux_mutrig2processor_M.out` | `phase5_t3_lane_mux` | `data_path_clock` | 1024 × 4 | hit_type0 muxed AVST, `select[2:0]` if exposed, `gts_8n_lo[15:0]` |
| T4 | `mts_processor_M.aso_hit_type1` | `phase5_t4_mts_processor` | `data_path_clock` | 1024 × 4 | `aso_hit_type1_{valid, ready, sop, eop, empty, error}`, `aso_hit_type1_data[38:0]`, `aso_hit_type1_channel[3:0]`, `d_gts_counter[15:0]`, `delta_timestamp[11:0]`, `run_state_cmd[3:0]` |
| T5 | `histogram_ingress_bridge_0.{pre_in, pre_out}` (and optionally `post_in/post_out`) | `phase5_t5_hist_ingress_bridge` | `data_path_clock` | 1024 × 4 | both AVST sides of the bridge, `live_select_post`, `pre_packet_active`, `post_packet_active`, `gts_8n_lo[15:0]` |
| T6 | `hit_stack_subsystem_M.ring_buffer_cam_K.aso_hit_type2` + `aso_filllevel` | `phase5_t6_ring_buffer_cam_M_K` (one per M=0..1, K=0..3; eight total) | `data_path_clock` | 1024 × 4 | `aso_hit_type2_*`, `aso_filllevel_data[15:0]`, `gts_8n_lo[15:0]` |
| T7 | `hit_stack_subsystem_M.feb_frame_assembly.aso_hit_type3` | `phase5_t7_feb_frame_assembly_M` (one per M=0..1) | `xcvr_clock` (156.25 MHz) | **4096 × 4** | `aso_hit_type3_*`, `frame_cnt[35:0]`, `counter_gts_8n[15:0]`, `terminating_marker_*`, `run_state_cmd[3:0]` |
| T8 | LVDS TX byte stream (final aso_tx8b1k into the lane mux) | `phase5_t8_lvds_tx` | `xcvr_clock` | 1024 × 4 | byte stream + K-flag, link-2 disparity, `gts_8n_lo[15:0]` |
| TS | SWB ingress (in `online_sc`, not this repo) | `phase5_ts_swb_ingress` | SWB link-2 RX clock | 1024 × 4 | post-decoder `data[7:0]`, `is_k`, `disp_err`, `code_err`, RX FIFO state, SWB per-link hit counter shadow |

The depths above are **defaults**; bucket cases may override per case (e.g. a sustained-rate PROF case may bump T2 to 2048×4 to capture FIFO fill ramps).
When a bucket row names only T6 partition `K`, the hit-stack subsystem `M` is selected by the active source lane unless the row says otherwise: lanes 0..3 feed `M=0`, and lanes 4..7 feed `M=1`.

### 3.5 GTS-armed alignment

Multiple SignalTap instances cannot share a literal trigger wire across clock domains, but they can be armed before the run and triggered by the same event in their respective domains. Phase-5 §3 standardizes one of three triggering modes per instance per case:

- **GTS-arm** — the instance triggers on `gts_8n_lo == TARGET` at its IP boundary. Because `gts_8n` is the global timestamp counter mirrored onto every IP's own clock domain, each instance triggers on the corresponding GTS bucket; the post-capture cross-IP alignment uses the captured GTS samples to pin events to the same simulated 8 ns step.
- **K-symbol arm** — the instance triggers on a K-symbol pattern at its byte-stream boundary (T0, T7, T8, TS). Cross-IP alignment uses the captured GTS slice in the same window.
- **State-arm** — the instance triggers on a run-state transition (e.g. `run_state_cmd → TERMINATING`) for EDGE cases that exercise the run sequence.

Every bucket-file case lists the trigger mode used per tap station.

### 3.6 Plaintext SignalTap implementation format

The bucket tables are intentionally kept as plain Markdown instead of generated XML. For each case row, the SignalTap implementation expands the row into the following run manifest:

```text
CASE <case_id>
STIMULUS <bucket-row stimulus field>
SOURCE <EMU | REAL | MIXED>, lanes=<mask>, channels=<mask-or-list>
RUN_CONTROL <IDLE->RUN_PREPARE->SYNC->RUNNING->TERMINATING->IDLE or bucket override>
TAPS <T0..T8, TS from the bucket-row taps field>
TRIGGER <GTS-arm | K-symbol arm | State-arm | error-trigger>, target=<case-specific value>
DEPTH <tap-station default unless the bucket row overrides it>
EXPECTED <bucket-row evidence field>
COUNTERS <stage counters plus SWB per-link counter delta>
MATCH <tb_int case path or pending>
```

The manifest is the handoff format for the `.stp` author or generator. Runtime trigger edits are allowed only when they preserve the tap list, storage order, and depth recorded here. Any new probe, changed clock domain, changed storage width, or changed instance split requires a regenerated `.stp` and a fresh Node Finder validation report.

### 3.7 Pass / fail per case

Each case in a bucket file passes when **every required tap station** captures the expected evidence under the case's stimulus, AND no case's ERROR-bucket negative trigger fires during the case's observation window. Per-case detail (which tap stations, which GTS targets, which counter deltas, which `*_error` flags must stay zero) lives inside the bucket-file row.

Each case fails if:
- a required tap station does not see the expected hit envelope at the predicted GTS bucket;
- an upstream tap shows a hit and the next downstream tap does not (lost hit);
- a counter delta at the IP boundary is wrong (e.g. `frame_counter_head` advanced but `aso_hit_type1_valid` did not assert);
- a per-IP `*_error` flag asserts when it should not.

For ERROR cases the inverse applies: the negative trigger **must** fire and the listed downstream IPs **must** record the propagation of the error (or the absence of cross-talk to other lanes).

### 3.8 Closure cross-check vs `tb_int/`

Long-term Phase-5 §3 closure requires every BASIC/PROF/EDGE/ERROR case to have a matching `tb_int/` integration-sim case that produces the same per-IP boundary evidence. The current `tb_int/` harness simulates an authentic regenerated `feb_system_v3_pipe` image and attaches custom checks at the SC/Qsys boundary; helper edits are allowed only to keep those boundary agents aligned with regenerated hierarchy, reset, and bus-width facts. Bucket-file rows have a `MATCH:` placeholder (e.g. `MATCH: tb_int/INT_fe_scifi_v3-2026-04-17/<case>`) reserved for case-level backfill. A bucket case can pass on board with `MATCH: pending` today; at final closure each row's `MATCH:` must point to a passing `tb_int/` run.

### 3.9 SWB ingress arrival check (FEB→SWB end-to-end packet receipt)

Even before the SWB-side `.stp` (`phase5_ts_swb_ingress`) is authored in `online_sc`, the SWB-side `LINK_LOCKED_*_REGISTER_R` and the SWB **per-link hit counter** are reachable via `sc_tool` against the SWB SC hub. Every Phase-5 §3 case must, at minimum, snapshot the SWB per-link hit counter before and after the run and confirm:

- the counter delta is non-zero whenever any FEB-egress tap (T7/T8) saw outgoing hits,
- the counter delta is zero in cases where no FEB egress traffic is expected (e.g. ERROR cases that terminate before any hit reaches `feb_frame_assembly`).

This is the pre-`.stp` proxy for "SWB received any packet at all" and is the SWB-side gate the bucket files reference per case (alongside the eventual `phase5_ts_swb_ingress` capture).

---

## 4. Collective verification — histogram-statistics rate / delay PDFs

§4 is the *collective* verification surface, complementary to §3's directed per-IP cascade. It uses `histogram_statistics_0` to measure rate distributions and delay PDFs for the full hit stream under injector modes and source selections, then compares each measurement against an authentic generated-system `tb_int/` run of the same Qsys image and the Phase 4 TLM/SIM/BOARD reference shapes (slides 23 / 24 / 25 / 38 of `doc/Archive/ethhw_reordering.pdf`).

Two evidence levels are allowed:

| Evidence level | Accepted use | Required artifact |
|---|---|---|
| `quick CSR` | iterative hardware debug and scoreboard triage | `run_phase5_histogram_matrix.py` Markdown/JSON using `sc_tool` reads through the SC hub; no screenshot required. Optional HTML table packages may summarize the same JSON but do not replace raw histogram-bin closure evidence. |
| `closure` | final Phase-5 signoff | Raw CSR/bin dump, DISLIN histogram plot generated from those bins (or the live System Console Histogram Statistics plot screenshot as additional GUI evidence), matching `tb_int/` result from the same generated firmware image, and reviewer notes explaining why source/lane masks match the expected rate or delay scaling |

Final closure is not a loose trend match. The DISLIN plot or live screenshot, raw CSR/bin dump, and `tb_int/` run must use the same scenario tuple: source selection, lane mask, injector mode, pulse interval, header multiplicity, histogram profile, bin bounds, and firmware checksum. If hardware and simulation disagree, debug order is Qsys wiring first, then RTL, then board state.

Required sanity figures for the closure report:

1. `phase5_rate_10k_100k_256ch.png`: one DISLIN figure with all 256 global channels on the x-axis (`ASIC * 32 + channel`) and two legends, 10 kHz and 100 kHz periodic injection. The histogram-statistics rate preset must use `INTERVAL_CFG = 125000000` clocks (1 s at 125 MHz) and update key `data[38:30]`.
2. `phase5_header_1_2_5.png`: one DISLIN figure with header mode 1, 2, and 5 injections per observed header as three legends.
3. `phase5_delay_lanes.png`: one DISLIN figure with eight lane traces. Each trace is measured in its own isolated/filtered one-second run. `histogram_statistics_v2` 26.1.5 applies the CSR filter in negative debug modes against a synthetic word: bits `[15:0]` are the debug sample, bits `[23:16]` are the zero-based debug source, and bits `[31:24]` are the absolute debug mode. With the present Qsys wiring this separates upper/lower MTS delay streams (`debug_1`/`debug_2`); true per-lane delay isolation still requires the source/lane mask unless a future lane-tagged debug stream is wired.

Required collective matrix:

| ID | Scenario | Sources | Scopes | Closure criterion | Status | Evidence |
|---|---|---|---|---|---|---|
| H001 | 100 kHz periodic rate | emulator, real, mixed | all lanes and each individual lane | one-second rate-preset histogram, zero histogram drops, zero MTS discards, every selected global-channel bin within 1% of 100,000 counts/s; plotted in `phase5_rate_10k_100k_256ch.png` | `quick CSR PASS_SCOPED; needs raw-bin closure` | v26.1.6 quick-CSR evidence: emulator lane0 `99,842 / 100,000` (`-0.158%`), real lane0 `99,839 / 100,000` (`-0.161%`), real lane3 `99,841 / 100,000` (`-0.159%`), all with zero drops/discards/ring input errors: [`../systems/system_20260427_testplanphase5/reports/phase5_histv6_real_rate_closure_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_histv6_real_rate_closure_20260429.md). Historical all-emulator quick matrix remains debug evidence: [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_rate100k_10k_quick_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_rate100k_10k_quick_20260429.md). Full 256-bin DISLIN/System Console plot is still required. |
| H002 | 10 kHz periodic rate | emulator, real, mixed | all lanes and each individual lane | one-second rate-preset histogram, zero histogram drops, zero MTS discards, every selected global-channel bin within 1% of 10,000 counts/s; plotted with H001 in `phase5_rate_10k_100k_256ch.png` | `quick CSR PASS_SCOPED; needs raw-bin closure` | v26.1.6 quick-CSR evidence: real lane0 `9,998 / 10,000` (`-0.020%`) and real lane3 `9,999 / 10,000` (`-0.010%`), both with zero drops/discards/ring input errors: [`../systems/system_20260427_testplanphase5/reports/phase5_histv6_real_rate_closure_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_histv6_real_rate_closure_20260429.md). Historical all-emulator quick matrix reports all-scope 100k/10k hist ratio `10.22x` and MTS ratio `10.21x`: [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_rate100k_10k_quick_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_rate100k_10k_quick_20260429.md). Full 256-bin DISLIN/System Console plot is still required. |
| H003 | 100 kHz periodic delay, all channels | emulator, real, mixed | all lanes and each individual lane | negative debug delay mode, non-wrapping, zero drops/errors, one narrow delta function per isolated lane; expected occupied width is <=200 cycles and injector-delay sweep moves the peak from 0 to about 1000 cycles; plotted in `phase5_delay_lanes.png` with eight legends | `needs raw-bin closure` | Historical quick-CSR dual-MTS emulator all+lane0..7 PASS, plus targeted lane0/lane4 reruns close the prior lower-half failure: [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_delay100k_quick_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_delay100k_quick_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_lane0_delay100k_quick_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_lane0_delay100k_quick_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_lane4_delay100k_quick_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_lane4_delay100k_quick_20260429.md) |
| H004 | header mode, 1 injection per header | emulator, real, mixed | all lanes and each individual lane | one delay population per selected header with expected count scaling; plotted in `phase5_header_1_2_5.png` | `needs raw-bin closure` | Historical quick-CSR emulator matrix used 1/2/4 and is retained only as debug: [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_header1_2_4_quick_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_header1_2_4_quick_20260429.md) |
| H005 | header mode, 2 injections per header | emulator, real, mixed | all lanes and each individual lane | approximately 2x H004 accepted delay samples with the same selected lanes and no new drops; plotted in `phase5_header_1_2_5.png` | `needs raw-bin closure` | Historical quick-CSR emulator matrix used 1/2/4 and is retained only as debug: [`../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_header1_2_4_quick_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_hist_matrix_dualmts_emulator_all_header1_2_4_quick_20260429.md) |
| H006 | header mode, 5 injections per header | emulator, real, mixed | all lanes and each individual lane | approximately 5x H004 accepted delay samples with the same selected lanes and no new drops; plotted in `phase5_header_1_2_5.png` | `needs raw-bin closure` | New required multiplicity. The old 4/header quick matrix is not a substitute for this closure row. |

Current debug finding: the post-hit-stack rate path is collectively merged, so lower-side lane4 rate tests pass. The earlier delay path was upper-only because `mts_preprocessor_0.ts_delta` was wired to `histogram_statistics_0.debug_1` while `mts_preprocessor_1.ts_delta` was not connected. Source RTL, active datapath Qsys, active parent FEB Qsys, and the authentic `tb_int` harness now use `histogram_statistics_v2` mode `-7` with `debug_1=upper MTS ts_delta`, `debug_2=lower MTS ts_delta`, and `debug_3..6=upper ring-CAM fill levels`. The 26.1.5 RTL extends the debug path so CSR filtering can select debug source 0/1 inside mode `-7`; it does not by itself make a single MTS stream carry individual lane identity. The v26.1.6 no-STP image checksum `0x13A9CC2D` adds the last-interval rate counter and closes quick-CSR scoped real-rate evidence on lanes 0 and 3. Full all-lane real/mixed source evidence and final raw-bin DISLIN/System-Console histogram plot plus matching-`tb_int` closure are still open.

---

## 5. Legacy stimulus mapping

The earlier 5 x 64 stimulus catalog (TPB5A..TPB5E) is superseded by the four directed §3 bucket files. Keep any future stimulus expansion in [`TEST_BASIC.md`](TEST_BASIC.md), [`TEST_PROF.md`](TEST_PROF.md), [`TEST_EDGE.md`](TEST_EDGE.md), or [`TEST_ERROR.md`](TEST_ERROR.md), where each row is tied to the tap stations in §3.4 and the SWB counter check in §3.9.

No Phase-5 closure credit is assigned to the legacy TPB5A..TPB5E IDs. They remain historical planning notes only; the active coverage denominator is the BASIC/PROF/EDGE/ERROR catalog floor in §1.6.

---

## 6. Failure debug ladder

Phase 5 reuses the disagreement protocol from `phase4/TEST_PLAN_BASIC.md` §"Disagreement protocol" with one substitution: the **TLM is no longer the apex** for §3. The Phase-4-passed **emulator path** is the fixed reference; the per-bucket cross-source check is real-MuTRiG vs Phase-4-emulator at the same per-IP cascade tap stations.

| Symptom | First-pass debug entry point |
|---|---|
| Datapath CSR access works through `sc_tool` but times out through headless JTAG | current `debug_sc_system_v3.qsys` does not connect `jtag_master.master` to `mm_bridge.s0`; use SC word addresses for datapath CSRs and do not credit any JTAG datapath preset evidence |
| §2 some ASICs do not lock decoded frames | `mutrig_cfg_ctrl_0` cfglen / scratchpad word stream — confirm the 84-word block is bit-for-bit the production bitstream from `/home/yifeng/packages/online_dpv2/online/switching_pc/slowcontrol/mutrig/Mutrig_FEB.cpp`, then check the SPI clock domain (`i_clk_spi`) reset and the SS-N fan-out |
| §2 TSA all-scan (`0x01400054`) returns immediately or hangs | fall back to the per-ASIC `CMD_MUTRIG_ASIC_TTH_SCAN` loop (`0x012k0054`) and inspect `mutrig_ctrl.vhd` command legalization before trusting all-scan evidence |
| Injector emulator path produces histogram/MTS hits but real-source path stays zero | injector/SC/fanout is no longer the first suspect; debug MuTRiG XML packing, SPI config completion, LVDS RX lane training, physical ribbon/lane mapping, and `mutrig_frame_deassembly_N` lock/error counters |
| Real-source path produces frame/MTS/histogram hits but MTS discard or `ring_buffer_cam.INERR_COUNT` increments | first check `mutrig_frame_deassembly_N.aso_hit_type0_error[*]` and the raw frame parser reason before changing MTS or ring filters. Current 2026-04-29 evidence shows a lane-0 `aso_hit_type0_error[0]` beat on ASIC0/channel16 before MTS; treat MTS as correctly filtering until a capture proves an output timestamp-error. |
| SignalTap capture arms but a simultaneous SC stimulus command times out | first check whether the wrapper forced `BOARD_TEST_SC_NO_RESET=1`; after FPGA reprogramming that can stale the SC secondary ring. Use the default synchronized `sc_tool` mode, then rerun the exact CSR write before blaming the tapped datapath. |
| §3 BASIC tap T0 sees hits but T1 does not | `mutrig_frame_deassembly_N` decoder error / link-lock, then the LVDS RX outclock and 8b/10b alignment |
| §3 BASIC tap T1 sees hits but T2 does not | `backpressure_fifo_N` write-side enable / fill_level rising / FIFO read-side ready stuck — usually upstream `mts_processor` not consuming |
| §3 BASIC tap T4 sees hits but T6 (ring_buffer_cam) does not | for `M=0`, check `histogram_ingress_bridge_0` selector first; for either hit-stack, check partition decode, then ring_buffer_cam tag-search miss |
| §3 BASIC tap T6 sees hits but T7 does not | `feb_frame_assembly` interleaving FIFO read-side, `terminating_marker_*` lane stuck, or run_state TERMINATING entered prematurely |
| §3 BASIC tap T7 sees hits but SWB per-link counter (§3.9) shows zero delta | LVDS TX clock-domain crossing, SWB link-2 lock, link mux at the FEB egress |
| §3 EDGE TERMINATING idle-guard violation | `feb_frame_assembly.TERMINATING_IDLE_GUARD_CONST = 2048` is documented; check `terminating_idle_guard_cnt` in capture, then `terminating_marker_valid` per lane |
| §3 EDGE GTS rollover misalignment | `counter_gts_8n` 48-bit width on `feb_frame_assembly`, `d_gts_counter` width on `mts_processor`; verify both increment monotonically across the captured window |
| §3 ERROR `disp_err` / `code_err` at SWB ingress | SWB-side 8b/10b decoder, link-2 RX equalization, then the FEB LVDS TX driver disparity |
| §3 ERROR `tsglitcherr` on `aso_hit_type1_error` | `mts_processor` mts→gts mapping, `delta_timestamp` (12-bit) vs the captured GTS slice |
| §3 PROF rate clipping below 200 Mhit/s | check whether the historical 135 Mhit/s knee from Phase 4 `inputs/board/phase4_emulator_20260425_*` has reappeared — if so, route to Phase 4's open item (board rate-signoff at 200 Mhit/s) |
| Any §3 `OVERFLOW_COUNT` advance on `histogram_statistics_0` | route to Phase 4 TPBH series — Phase 5 closure is gated on TPBH001..TPBH030 PASS, so any new overflow is a regression and Phase 4 evidence is invalidated until the regression is debugged |
| §4 (when written) collective PDF disagreement | revisit §3 directed evidence first; collective PDFs are the union of directed cases and cannot pass before the directed chain is closed |

---

## 7. Reports and closure attestation

Each Phase-5 stage produces a structured Markdown report under `../reports/`:

| Report | Contents |
|---|---|
| `phase5_mutrig_baseline_<date>.md` | per-(ASIC, channel) known-good TTH from §2.5; the cfg-bitstream baseline word stream pointer; the `mutrig_frame_deassembly_*` lock evidence |
| `phase5_basic_<date>.md` | TEST_BASIC.md per-case results: per-IP cascade tap evidence (T0..T8 + TS), GTS arming targets, per-IP counter deltas |
| `phase5_prof_<date>.md` | TEST_PROF.md per-case results: rate-pressure tap evidence, ring-CAM and backpressure-FIFO fill-level traces, sustained-run soak windows |
| `phase5_edge_<date>.md` | TEST_EDGE.md per-case results: run-state-transition captures, GTS rollover, frame-counter rollover, terminating-idle-guard evidence |
| `phase5_error_<date>.md` | TEST_ERROR.md per-case results: per-case negative-trigger fire, error-flag propagation through the cascade, recovery evidence |
| `phase5_closure_<date>.md` | aggregated PASS/FAIL across §2..§3, per-bucket coverage as `implemented_pass / cases_in_bucket`, MATCH-with-tb_int rollup, and cross-source discrepancies with their numeric ratios |

The reports are the sign-off artifact; Phase 5 is closed when:

- §2..§3 all PASS per their stage aggregator (§4 is RESERVED in this revision),
- the closure report is checked into `../reports/`,
- BASIC/PROF/EDGE/ERROR per-bucket coverage is at least the documented per-case-floor (≥ 144) for each bucket,
- every Phase-5 cross-source overlay is within the tolerance documented in the bucket's pass aggregator,
- no Phase-4 closure invariant (`OVERFLOW_COUNT`, `DROPPED_HITS`, `UNDERFLOW_COUNT` deltas all zero) is violated.

---

## 8. Open items / known caveats

- **One injector instance**: the integration build instantiates a single `mutrig_injector_0`. Its conduit output feeds `emulator_inject_fanout`; the fanout's out8 export drives the physical FEB injection net in the active Phase-5 image. Real-MuTRiG rate checks must therefore use the `mutrig_injector_0` CSR path, not deprecated `pll_test_mode(0)` / `o_pll_test` constants. Two-source mode-1 + mode-2 superposition is no longer a Phase-5 catalog blocker; if dual-path analog routing is later proven, add the extension cases to the active BASIC/PROF/EDGE/ERROR bucket files instead of reviving the legacy TPB5E range.
- **SWB-side `.stp` image** lives in the SWB Quartus project (`online_sc/online/switching_pc/a10_board/`), not in this repo. Authoring and check-in of `phase5_swb_ingress.stp` is a follow-up task in `online_sc`. This plan calls out the trigger conditions and the depth/segment configuration; the actual `.stp` author and check-in is expected to land in the SWB tree before §3.2 captures are run.
- **Histogram delay key extraction**: `histogram_statistics_0.CONTROL.mode` selects which slice of the snooped data word is used as the update key. The exact bit slice for the delay key on the post-hit-stack tap is set by `histogram_statistics_0.KEY_LOC` and depends on the `feb_frame_assembly` / hit-stack output layout. The plan above assumes the slice was already pinned during Phase 4 §4.5; if Phase 5 needs a different slice (e.g. delay rather than channel), the slice is pinned per case via the `KEY_LOC` field. The `KEY_LOC` setting per case is part of the per-case configuration; this plan does not enumerate the bit positions because they are stable across Phase 4 → Phase 5.
- **Cfg bitstream packing**: the production cfg-bitstream packing (LSB-first vs MSB-first per word, padding policy at the 2662-bit boundary) is defined in `/home/yifeng/packages/online_dpv2/online/switching_pc/slowcontrol/mutrig/Mutrig_FEB.cpp` and mirrored by `toolkits/fe_scifi/`. Phase-5 §2 reuses that packing exactly; this plan does not redefine it.
- **TSA range and stride**: the controller's TSA increments TTH 0..63 (6-bit field). The full 64-step per-channel TSA result-RAM dump is §2 baseline evidence; any reduced representative threshold grid belongs in the active bucket files as explicit cases.
- **Datapath JTAG aperture**: the current generated debug system exposes the datapath CSRs through the SC hub, not through the headless JTAG master. Any future JTAG datapath helper must first add and regenerate an explicit JTAG-to-`mm_bridge.s0` connection; until then, `sc_tool` is the authoritative board CSR path for Phase 5.
- **Real MuTRiG lock**: ASIC0/ASIC3 XML cfg now produces pulse-correlated hits on lanes 0/3 after channel-16-only overrides, and the recompiled frame/MTS/histogram SignalTap image proves accepted real hits can reach `histogram_statistics_0`. Earlier repeated 250 ms windows reproduced an intermittent one-discard event; the input-hiterr SignalTap capture localized it to `mutrig_frame_deassembly_0.aso_hit_type0_error[0]` on ASIC0/channel16 before MTS. A fresh runctl/MTS-stage image did not reproduce the hiterr trigger, 52 debug-image follow-up windows passed, and the rebuilt timing-clean no-STP image passed a 100-window accepted soak with zero MTS discards, zero ring input errors, zero histogram drops, zero frame CRC errors, and zero missing hits. The newer v26.1.6 timing-clean image passes scoped real-rate checks on lanes 0/3 at 100 kHz and 10 kHz using `LAST_INTERVAL_TOTAL_HITS`; it still needs all-lane recovery or explicit waiver of lanes 1/2/4/5/6/7 before BASIC/PROF rows get full closure credit.

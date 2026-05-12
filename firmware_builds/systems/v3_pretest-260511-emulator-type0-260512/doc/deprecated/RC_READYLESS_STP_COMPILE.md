# RC-Readyless SignalTap Compile Report

Build: `v3_pretest-260511-rc-readyless-260511`
Date: 2026-05-12
Revision: `top_stp_phase4_rc_readyless_gap`

## Status

The focused Phase 4 SignalTap gap image now imports, maps, fits, assembles,
and runs STA through the full Quartus flow.

This is a hardware debug-load candidate only. It is not production/signoff
closure: the slow timing corners still fail and TimeQuest reports unconstrained
setup/hold requirements.

The on-board capture is now complete and documented in
`doc/RC_READYLESS_STP_CAPTURE.md`. The STP image was good enough for the
debug loop: start-run reached the emulator control leaf and `run_generating`
asserted, but `aso_tx8b1k_valid` never asserted.

## Debug Boundary

The 2026-05-12 hardware retest proves that run-control reaches the FEB CSR
plane and that direct `dbg_mm2runctrl` injection increments its send counter,
while `TOTAL_HITS`, `LAST_INT_HITS`, and the frame-assembly actual-hit counters
stay at zero.

Known-good side:

- `runctl_mgmt_host_0.LOCAL_CMD`
- `dbg_mm2runctrl_0.HOST_CMD`
- `dbg_mm2runctrl_0.SENT_COUNT`
- `run_control_splitter.out15_valid/out15_data`
- `emulator_ctrl_splitter.out0_valid/out0_data`
- `emulator_mutrig_0.asi_ctrl_valid/asi_ctrl_data`
- `emulator_mutrig_0.u_frontend_run_ctl.run_generating`

Unknown side:

- downstream consumption of the first lane-0 byte-stream source
- whether the fix should enable `BYTE_STREAM_ENABLE` for the current `tx8b1k`
  wiring or rewire the integration to consume direct `hit_type0`

This matches the hardware-first iterative-debug rule: use the board symptom to
choose the first boundary, use simulation only as support, and keep narrowing
with SignalTap until a defensible RTL fix point exists.

## STP Source

- Generator:
  `script/generate_phase4_rc_readyless_gap_stp.py`
- STP file:
  `signaltap/phase4_rc_readyless_gap.stp`
- Node report:
  `signaltap/phase4_rc_readyless_gap_nodes.md`
- Probe result: `99` probes, `99` found, `0` missing
- Instance: `phase4_rc_readyless_gap_lvds`
- Trigger: rising edge of `run_control_splitter|out15_valid`
- Sample depth: `1024`

The acquisition clock is the exported Qsys port:

```text
feb_system:u_feb_system|feb_system_v3:u_qsys|feb_system_v3_data_path_subsystem:data_path_subsystem|lvds_outclock_clk
```

The earlier reimport attempt with internal clock name
`lvds_rx_28nm_0_outclock_clk` produced `Critical Warning (35025)` with one
missing connection. The fixed generator uses `lvds_outclock_clk`; the fixed
map reports `Info (35024)` and no remaining `35025` in the successful compile
log.

## Reproduction Commands

Generate the STP:

```bash
cd firmware_builds/systems/v3_pretest-260511-rc-readyless-260511
python3 script/generate_phase4_rc_readyless_gap_stp.py \
  --output signaltap/phase4_rc_readyless_gap.stp
```

Validate probe names after map/synthesis DB refresh:

```bash
python3 ~/.codex/skills/signaltap-creation-co-debug/scripts/check_stp_nodes.py \
  --project-dir syn/board_projects/fe_scifi_feb_v3 \
  --project top \
  --revision top_stp_phase4_rc_readyless_gap \
  --stp-file signaltap/phase4_rc_readyless_gap.stp \
  --observable-type stp_pre_synthesis \
  --report-out signaltap/phase4_rc_readyless_gap_nodes.md
```

Import the STP into the dedicated Quartus revision:

```bash
cd syn/board_projects/fe_scifi_feb_v3
quartus_stp top -c top_stp_phase4_rc_readyless_gap \
  --enable --signaltap \
  --stp_file=/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/signaltap/phase4_rc_readyless_gap.stp
```

Run the full compile watcher:

```bash
cd /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores
firmware_builds/systems/system_20260427_testplanphase5/script/watch_feb_quartus_compile.sh \
  --dir firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/syn/board_projects/fe_scifi_feb_v3 \
  --project top \
  --rev top_stp_phase4_rc_readyless_gap \
  --interval-sec 300 \
  --log quartus_compile_top_stp_phase4_rc_readyless_gap_clkfix_20260512_0328.console.log
```

## Compile Evidence

- Console log:
  `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_stp_phase4_rc_readyless_gap_clkfix_20260512_0328.console.log`
- Output directory:
  `syn/board_projects/fe_scifi_feb_v3/output_files_stp_phase4_rc_readyless_gap_clkfix`
- Full compile result: `Quartus Prime Full Compilation was successful. 0
  errors, 1580 warnings`
- Watcher result: `rc=0`
- Runtime: `00:39:29`
- SignalTap connection:
  `Info (35024): Successfully connected in-system debug instance
  "phase4_rc_readyless_gap_lvds" to all 231 required data inputs, trigger
  inputs, acquisition clocks, and dynamic pins`
- QSF output directory assignment:
  `PROJECT_OUTPUT_DIRECTORY output_files_stp_phase4_rc_readyless_gap_clkfix`
- QSF SignalTap assignments:
  `USE_SIGNALTAP_FILE`, `SIGNALTAP_FILE`, and `ENABLE_SIGNALTAP ON`
- QSF acquisition clock assignment:
  `CONNECT_TO_SLD_NODE_ENTITY_PORT acq_clk` to `lvds_outclock_clk`
- QSF CRC assignments are mixed `gnd`/`vcc`, not all-zero trigger metadata.

## Programming Files

| Artifact | Size | SHA-256 |
|---|---:|---|
| `top_stp_phase4_rc_readyless_gap.sof` | `12686909` bytes | `7dd7f9303a7551d4b0074136a38f2b818ad37e1d20ec4a9decfd6dd21e7f03ad` |
| `top_stp_phase4_rc_readyless_gap.rbf` | `7013448` bytes | `70bd0ec7f67d48e500f14dc6232a616f90645eb278606ac25922760bd38e9a6c` |
| `top_stp_phase4_rc_readyless_gap.jdi` | `92916` bytes | `362404a223d94d36e24fa0d5c3f4b4c3b061947ab7a68fc9029fc5a49bfa26d9` |

## Resource Summary

- Device: `5AGXBA7D4F31C5`
- Logic utilization: `61,643 / 91,680 ALMs (67%)`
- Total registers: `93325`
- Pins: `218 / 426 (51%)`
- Block memory bits: `4,133,578 / 13,987,840 (30%)`
- RAM blocks: `550 / 1,366 (40%)`
- DSP blocks: `0 / 800 (0%)`
- HSSI RX PCSs / PMA deserializers: `4 / 9 (44%)`
- HSSI TX PCSs / PMA serializers: `8 / 9 (89%)`
- PLLs: `7 / 21 (33%)`

## Timing Status

| Corner | Setup | Hold | Recovery | Removal | Debug result |
|---|---:|---:|---:|---:|---|
| Slow 1100 mV 85 C | `-1.345` | `0.188` | `-1.335` | `0.457` | fail |
| Slow 1100 mV 0 C | `-1.177` | `0.175` | `-1.242` | `0.352` | fail |
| Fast 1100 mV 85 C | `0.625` | `0.080` | `1.187` | `0.268` | pass |
| Fast 1100 mV 0 C | `0.789` | `0.063` | `1.290` | `0.205` | pass |

Debug acceptance: **pass for FEB iterative debug** because 2 of 4 corners pass.
Production signoff: **fail** because all corners are not clean and
`top_stp_phase4_rc_readyless_gap.sta.rpt` reports unconstrained setup/hold.

## Capture Evidence

Capture report:
`doc/RC_READYLESS_STP_CAPTURE.md`

Capture directory:
`signaltap/captures/phase4_rc_readyless_gap_20260512_042348`

Decisive capture facts:

- Trigger: rising `run_control_splitter.out15_valid` after `LOCAL_CMD=0x12`.
- Run-control payload: `run_control_mux.out_data=0x008` and
  `run_control_splitter.out15_data=0x008`.
- Emulator control payload:
  `emulator_ctrl_splitter.out0_data=0x008` and
  `emulator_mutrig_0.asi_ctrl_data=0x008`.
- Emulator state: `run_generating` first high at `129500 ps`, final
  `frame_rst=0`.
- Byte-stream output: `aso_tx8b1k_valid` never high, final
  `aso_tx8b1k_data=0x1bc`.
- Post-capture counters: histogram `TOTAL_HITS=0`; HSS0/HSS1 actual-hit
  counters remain zero.

Preliminary source/sim confirmation:

- Generated `syn/feb_system_v3.sopcinfo` wires all eight
  `data_path_subsystem_emulator_mutrig_N.tx8b1k` outputs to decoded-lane mux
  inputs while the emulator instances keep `BYTE_STREAM_ENABLE=false`.
- `emulator_mutrig.sv` intentionally ties `aso_tx8b1k_valid` low and drives
  K28.5 idle in the `no_byte_stream_gen` branch.
- `sim_byte_stream_disable.log` reports `tx_valid=0`, `tx_data=1bc` for
  `BYTE_STREAM_ENABLE=0`.

## Next Integration Step

Use the shared bench queue before touching JTAG:

```bash
BENCH_QUEUE_DIR=/home/yifeng/packages/mu3e_ip_dev/.bench_queue \
python3 firmware_builds/systems/system_20260427_testplanphase5/tools/bench_queue/bench_ticket.py claim <agent-name>
BENCH_QUEUE_DIR=/home/yifeng/packages/mu3e_ip_dev/.bench_queue \
python3 firmware_builds/systems/system_20260427_testplanphase5/tools/bench_queue/bench_ticket.py acquire <agent-name>
```

The next image should implement one coherent output contract:

1. Keep the current decoded-lane mux wiring and set `BYTE_STREAM_ENABLE=true`
   on all eight `emulator_mutrig_N` Qsys instances, then regenerate/compile and
   rerun the same STP/counter gate.
2. Or rewire the system to consume the emulator's direct `hit_type0` outputs,
   then regenerate/compile and rerun the same gate.

Do not treat the rc-readyless splitter fix as Phase 4 closure until the next
hardware run shows `TOTAL_HITS > 0`, HSS actual-hit counters advance, and the
downstream conservation ledger can be populated.

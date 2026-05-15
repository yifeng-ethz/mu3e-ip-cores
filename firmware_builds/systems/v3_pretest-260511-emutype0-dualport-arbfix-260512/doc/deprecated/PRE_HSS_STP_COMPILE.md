# Pre-HSS SignalTap Compile Report

Build: `v3_pretest-260511-rc-readyless-260511`
Date: 2026-05-12
Revision: `top_stp_phase4_pre_hss_gap`

## Status

The focused Phase 4 pre-HSS SignalTap image now imports, maps, fits,
assembles, and runs STA through the full Quartus flow.

This is a hardware debug-load candidate only. It is not production/signoff
closure: the slow timing corners still fail and TimeQuest reports
unconstrained setup/hold requirements.

The image is also **not payload-complete**. Quartus Node Finder resolves all
pre-synthesis probe names, but map connects the SignalTap instance only
partially because several payload/channel/error aliases are optimized or not
preserved. Use this image first for handshake/stage localization; regenerate or
retarget payload taps only if the next capture proves payload words are needed.

## Hardware Boundary

Known-good side from the 2026-05-12 hardware smoke:

- `BYTE_STREAM_ENABLE=true` retires the disabled byte-stream source blocker.
- Post-selected histogram word counters advance with zero
  dropped/underflow/overflow counts in that profile.

Unknown side:

- `histogram_ingress_bridge_0.pre_in/pre_out` remain dark.
- `mts_preprocessor_0.hit_type1_out`, visible MTS totals, rbCAM payload
  counters, and HSS frame-assembly counters remain zero.

This follows the hardware-first debug rule for the FEB/SWB blocker hunt: use
the board symptom to pick the boundary, use sim as supporting evidence, then
move to SignalTap when sim does not narrow the failing hardware stage enough
for a defensible RTL fix.

## Preliminary Simulation

Tiny mixed-language smoke test:
`tb_int/tb_pre_hss_axis.sv`

Run directory:
`tb_int/sim_pre_hss_axis_20260512/`

Transcript:

- `PRE_HSS_AXIS_COUNTS tx_valid=11659 emu_type0=1919 parser_headers=19 parser_hits=1918`
- `*** PRE_HSS_AXIS PASSED ***`
- `Errors: 0, Warnings: 11`

Interpretation: the current emulator byte stream is decodable by the direct
parser path in this reduced harness. This does **not** explain the on-board
dark pre-HSS path and is not sufficient for an RTL fix claim.

## STP Source

- Generator:
  `script/generate_phase4_pre_hss_gap_stp.py`
- STP file:
  `signaltap/phase4_pre_hss_gap.stp`
- Dedicated Node Finder report:
  `signaltap/phase4_pre_hss_gap_nodes_top_stp_phase4_pre_hss_gap.md`
- Probe result: `76` probes, `76` found, `0` missing
- Instance: `phase4_pre_hss_gap_lvds`
- Sample depth: `1024`

The acquisition clock is the exported Qsys port:

```text
feb_system:u_feb_system|feb_system_v3:u_qsys|feb_system_v3_data_path_subsystem:data_path_subsystem|lvds_outclock_clk
```

## Reproduction Commands

Import the STP into the dedicated Quartus revision:

```bash
cd firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/syn/board_projects/fe_scifi_feb_v3
quartus_stp top -c top_stp_phase4_pre_hss_gap --enable --signaltap \
  --stp_file=/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/signaltap/phase4_pre_hss_gap.stp
```

Validate probe names after map/synthesis DB refresh:

```bash
python3 ~/.codex/skills/signaltap-creation-co-debug/scripts/check_stp_nodes.py \
  --project-dir syn/board_projects/fe_scifi_feb_v3 \
  --project top \
  --revision top_stp_phase4_pre_hss_gap \
  --stp-file signaltap/phase4_pre_hss_gap.stp \
  --observable-type stp_pre_synthesis \
  --report-out signaltap/phase4_pre_hss_gap_nodes_top_stp_phase4_pre_hss_gap.md
```

Run the full compile watcher:

```bash
cd /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores
firmware_builds/systems/system_20260427_testplanphase5/script/watch_feb_quartus_compile.sh \
  --dir firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/syn/board_projects/fe_scifi_feb_v3 \
  --project top \
  --rev top_stp_phase4_pre_hss_gap \
  --interval-sec 300 \
  --log quartus_compile_top_stp_phase4_pre_hss_gap_20260512_0619.console.log
```

## Compile Evidence

- Console log:
  `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_stp_phase4_pre_hss_gap_20260512_0619.console.log`
- Output directory:
  `syn/board_projects/fe_scifi_feb_v3/output_files_stp_phase4_pre_hss_gap`
- Full compile result: Quartus Prime Full Compilation was successful; `0`
  errors, `1580` warnings
- Watcher result: `rc=0`
- Runtime: `00:38:35`; CPU: `02:06:57`
- Fitter result: `0 errors, 30 warnings`
- Assembler result: `0 errors, 1 warning`
- Timing analyzer result: `0 errors, 24 warnings`
- QSF SignalTap assignments:
  `USE_SIGNALTAP_FILE`, `ENABLE_SIGNALTAP ON`, `SLD_DATA_BITS=76`,
  `SLD_TRIGGER_BITS=76`, and `SLD_STORAGE_QUALIFIER_BITS=76`
- QSF CRC assignments are mixed `gnd`/`vcc`, not all-zero trigger metadata.

## SignalTap Connection Caveat

Analysis & Synthesis reports:

```text
Critical Warning (35025): Partially connected in-system debug instance
"phase4_pre_hss_gap_lvds" to 129 of its 185 required data inputs, trigger
inputs, acquisition clocks, and dynamic pins. There were 0 illegal,
0 inaccessible, and 56 missing sources or connections.
```

The missing sources are duplicated across trigger/data connection rows. The
unique missing aliases are payload/channel/error style taps:

```text
asi_ctrl_data
avalon_st_adapter_032_out_0_{channel,data,error}
decoded_lane_fifo_0_out_{channel,data,error}
decoded_lane_mux_0_out_{channel,data,error}
emulator_mutrig_0_tx8b1k_{channel,data,error}
hist_post_cdc_0_out_data
histogram_ingress_bridge_0_{hist_out_channel,hist_out_data,pre_out_channel,pre_out_data}
mts_preprocessor_0_hit_type1_out_{channel,data}
mutrig_datapath_subsystem_0_headerinfo_{channel,data}
mutrig_datapath_subsystem_0_hit_type0_out_{channel,data,error}
mux_mutrig2processor_out_{channel,data,error}
```

Quartus suggests preserving the pre-synthesis taps by setting the partition
netlist type to `Source` and recompiling. For the next bench pass, treat the
current image as loadable for stage/handshake localization only.

## Programming Files

| Artifact | Size | SHA-256 |
|---|---:|---|
| `top_stp_phase4_pre_hss_gap.sof` | `12684913` bytes | `bbb2b17af1a65c63394acfae40606968565dd562f54d5606ca6ce2aa77dd939c` |
| `top_stp_phase4_pre_hss_gap.rbf` | `7117568` bytes | `f472dbbae6a1b64ef57aaa0d150c0f57e1aefd8393f791a302da58c60cdd7d46` |
| `top_stp_phase4_pre_hss_gap.jdi` | `92837` bytes | `cc35b09817ae87dc25b3f0b703d7e43f7f2199d7782f1fc0fd11bc53618e5b66` |

## Resource Summary

- Device: `5AGXBA7D4F31C5`
- Logic utilization: `65,557 / 91,680 ALMs (72%)`
- Total registers: `102648`
- Block memory bits: `4,209,354 / 13,987,840 (30%)`
- RAM blocks: `564 / 1,366 (41%)`
- DSP blocks: `0 / 800 (0%)`
- HSSI RX PCSs: `4 / 9 (44%)`
- HSSI TX PCSs: `8 / 9 (89%)`
- PLLs: `7 / 21 (33%)`

## Timing Status

| Corner | Setup | Hold | Recovery | Removal | Min pulse | Debug result |
|---|---:|---:|---:|---:|---:|---|
| Slow 1100 mV 85 C | `-1.097` | `0.247` | `-1.330` | `0.480` | `0.160` | fail |
| Slow 1100 mV 0 C | `-0.728` | `0.217` | `-1.236` | `0.372` | `0.160` | fail |
| Fast 1100 mV 85 C | `0.784` | `0.154` | `1.192` | `0.273` | `0.160` | pass |
| Fast 1100 mV 0 C | `0.917` | `0.126` | `1.292` | `0.215` | `0.160` | pass |

Debug acceptance: **pass for FEB iterative debug** because 2 of 4 corners pass.
Production signoff: **fail** because all corners are not clean and the design
is not fully constrained for setup/hold.

## Next Hardware Step

Use the shared bench queue before touching JTAG, then program:

```text
syn/board_projects/fe_scifi_feb_v3/output_files_stp_phase4_pre_hss_gap/top_stp_phase4_pre_hss_gap.sof
```

Arm:

```text
signaltap/phase4_pre_hss_gap.stp
```

Capture the first dark boundary between the decoded-lane mux/FIFO,
mutrig-datapath type0 stream, MTS ingress/egress, and histogram pre tap. If
the handshake boundary localizes the failure but payload values are required,
regenerate with preserved/source pre-synthesis payload taps or retarget to
post-synthesis payload nets before the next compile.

# MuTRiG Frame-Deassembly CSR Probe - 2026-05-22

## Context

The FEB/SWB run-control state was already RUNNING/start-run before the CSR probe:

| Word | Source | Name | Value | Description |
|---:|---|---|---|---|
| 0 | run-control | RESET_LINK_STATUS_REGISTER_R | **0x12000004** | Last state byte is `0x12`, decoded by `rc_tool` as `start-run`. |
| 1 | run-control | RESET_LINK_RUN_NUMBER_REGISTER_W | **0x0003F9AA** | Current run number image. |

## Expected Frame-Deassembly CSR

This is what the `mutrig_frame_deassembly` CSR should show if it were exposed by the current system map.

| Word | JTAG byte addr | Name | Value | Description |
|---:|---:|---|---|---|
| 0 | N/A | CONTROL_STATUS | **BAD: not mapped in current FEB v4 data-path master** | `[7:0]` is the control write image; bit 0 should normally be `1` to allow header pickup in RUNNING. `[29:24]` mirrors the latest decoded `frame_flags` when `headerinfo` updates. |
| 1 | N/A | CRC_ERR_COUNT | **BAD: not mapped in current FEB v4 data-path master** | CRC error counter. A good link should keep this at `0`; nonzero would prove corrupted frames reached the parser. |
| 2 | N/A | FRAME_COUNT_DELTA | **BAD: not mapped in current FEB v4 data-path master** | Snapshot of `frame_counter_head - frame_counter_tail`, updated on hit_type0 EOP. Empty frames can leave this at `0`; it is not a pure header counter. |
| 3 | N/A | RESERVED / undefined | **BAD: not mapped in current FEB v4 data-path master** | No field-accurate semantics published for word 3. |

Evidence: `quartus_systems/scifi_datapath_system_v4.qsys` exposes `mutrig_datapath_subsystem_N.backpressure_fifo_csr` to `master_datapath.master`, plus `mutrig_injector_0.csr` and `histogram_statistics_0.csr`. Searches for `mutrig_frame_deassembly_0.csr`, `frame_deassembly_0.csr`, and a frame-deassembly master connection in both the Qsys file and generated `feb_system_v4.sopcinfo` returned no matches.

## Live Proxy Dump

Command output is archived in `proxy_dump.log`; the Tcl probe is `read_mutrig_frame_proxies.tcl`.

### LVDS Global CSR

| Word | JTAG byte addr | Name | Value | Description |
|---:|---:|---|---|---|
| 0 | 0x00000000 | UID | **0x4C564453** | Normal: LVDS UID, ASCII `LVDS`. |
| 3 | 0x0000000C | SYNC_PATTERN | **0x000000FA** | Non-default/running value: current sync pattern. |
| 4 | 0x00000010 | LANE_GO | **0x000001FF** | Normal: lanes 0-8 enabled. |
| 7 | 0x0000001C | MODE_MASK | 0x00000000 | Mode 0, current RTL consumes bits `[1:0]`. |
| 11 | 0x0000002C | PHY_STATUS | **0x00000001** | Normal: PLL lock set; aggregate LOS/DPA-unlock/FIFO-reset/DPA-reset bits clear. |
| 12 | 0x00000030 | PHY_LOSN_STATUS | **0x000001FF** | Normal: redriver LOS_N is high on lanes 0-8, signal present. |
| 13 | 0x00000034 | PHY_LOS_ALERT | 0x00000000 | Normal: no sticky LOS alert after prior clear. |
| 14 | 0x00000038 | PHY_DPALOCK_STATUS | **0x000001FF** | Normal: lanes 0-8 report DPA lock. |
| 15 | 0x0000003C | PHY_FIFORST_STATUS | 0x00000000 | Normal: controller is not holding PHY FIFO reset. |
| 16 | 0x00000040 | LANE_SELECT | **0x00000008** | Selected-lane snapshot window is on lane 8, the RC reference lane. |
| 27 | 0x0000006C | LANE_TRAIN_STATUS | **BAD: 0x00000000** | Suspicious because aggregate lane 8 lock is good; this selected-lane snapshot path still looks stale/idle. |

### Backpressure FIFO CSR

| Word | JTAG byte addr | Name | Value | Description |
|---:|---:|---|---|---|
| 0 | 0x00008860 | BP_LANE0 WORD000..003 | 0x00000000, 0x00000000, 0x00000000, 0x00000000 | No downstream per-lane FIFO activity visible. |
| 1 | 0x00001860 | BP_LANE1 WORD000..003 | 0x00000000, 0x00000000, 0x00000000, 0x00000000 | No downstream per-lane FIFO activity visible. |
| 2 | 0x00002860 | BP_LANE2 WORD000..003 | 0x00000000, 0x00000000, 0x00000000, 0x00000000 | No downstream per-lane FIFO activity visible. |
| 3 | 0x00003860 | BP_LANE3 WORD000..003 | 0x00000000, 0x00000000, 0x00000000, 0x00000000 | No downstream per-lane FIFO activity visible. |
| 4 | 0x00004860 | BP_LANE4 WORD000..003 | 0x00000000, 0x00000000, 0x00000000, 0x00000000 | No downstream per-lane FIFO activity visible. |
| 5 | 0x00005860 | BP_LANE5 WORD000..003 | 0x00000000, 0x00000000, 0x00000000, 0x00000000 | No downstream per-lane FIFO activity visible. |
| 6 | 0x00006860 | BP_LANE6 WORD000..003 | 0x00000000, 0x00000000, 0x00000000, 0x00000000 | No downstream per-lane FIFO activity visible. |
| 7 | 0x00007860 | BP_LANE7 WORD000..003 | 0x00000000, 0x00000000, 0x00000000, 0x00000000 | No downstream per-lane FIFO activity visible. |

### Histogram CSR

| Word | JTAG byte addr | Name | Value | Description |
|---:|---:|---|---|---|
| 0 | 0x00007000 | UID | **0x48495354** | Normal: histogram UID, ASCII `HIST`. |
| 2 | 0x00007008 | CONTROL | 0x00000000 | Current histogram source/mode/filter control is default. |
| 12 | 0x00007030 | PORT_STATUS | **0x000000FF** | All eight ingress FIFOs empty. |
| 13 | 0x00007034 | TOTAL_HITS | **BAD: 0x00000000** | Confirms no accepted Type0 hits in the current interval. |
| 14 | 0x00007038 | DROPPED_HITS | 0x00000000 | No evidence of drops; this is empty rather than overflowed. |
| 15 | 0x0000703C | COAL_STATUS | 0x00000000 | Coalescing queue empty, no overflow count. |
| 17 | 0x00007044 | LAST_INTERVAL_TOTAL_HITS | **BAD: 0x00000000** | Last completed interval also had no accepted hits. |
| 18 | 0x00007048 | LAST_INTERVAL_DROPPED_HITS | 0x00000000 | Last completed interval had no dropped hits. |

### Mutrig Injector CSR

| Word | JTAG byte addr | Name | Value | Description |
|---:|---:|---|---|---|
| 0 | 0x0000A000 | UID | **0x4D494E4A** | Normal: injector UID, ASCII `MINJ`. |
| 2 | 0x0000A008 | MODE | 0x00000000 | Injector is off; this CSR is not a headerinfo counter. |
| 3 | 0x0000A00C | HEADER_DELAY | **0x00000064** | Non-default configured header delay. |
| 4 | 0x0000A010 | HEADER_INTERVAL | **0x00000001** | Header-synchronous interval setting. |
| 5 | 0x0000A014 | INJECTION_MULTIPLICITY | **0x00000001** | One pulse per selected trigger setting. |
| 6 | 0x0000A018 | HEADER_CH | 0x00000000 | Headerinfo channel selector is lane/channel 0. |
| 7 | 0x0000A01C | PULSE_INTERVAL | **0x000003E8** | Non-default periodic interval setting. |
| 8 | 0x0000A020 | PULSE_HIGH_CYCLES | **0x00000005** | Non-default pulse width setting. |
| 9 | 0x0000A024 | PRBS_RATE | **0x000003E7** | Non-default PRBS rate setting. |
| 10 | 0x0000A028 | PRBS_PATTERN | **0x00000001** | Non-default PRBS pattern. |
| 11 | 0x0000A02C | PRBS_SEED | **0x0000ACE1** | Non-default PRBS seed. |
| 12 | 0x0000A030 | PRBS_CTRL | **0x00000004** | Non-default PRBS control. |

## Conclusion

The frame-deassembly CSR should show useful header-derived state, especially word 0 `[29:24]` after any decoded header. In the currently loaded FEB v4 image I cannot read that CSR because it is not wired into the data-path master map.

The live proxies show a healthy LVDS aggregate lock and no PHY FIFO reset, but no downstream Type0 activity: all backpressure FIFO windows are zero and histogram `TOTAL_HITS`, `LAST_INTERVAL_TOTAL_HITS`, and `DROPPED_HITS` are all zero. This confirms "no hits", but it does not distinguish "no MuTRiG header reaches frame_deassembly" from "headers/empty frames decode but no hit payload" because the needed header-facing CSR/debug surface is missing.

Recommended closure change: expose `mutrig_datapath_subsystem_N.mutrig_frame_deassembly_0.csr` for all lanes on the data-path JTAG/SC map, and add at least `header_seen_count`, `last_frame_number`, `last_frame_len`, `last_frame_flags`, `crc_err_count`, and parser FSM state to the CSR or STP tap.

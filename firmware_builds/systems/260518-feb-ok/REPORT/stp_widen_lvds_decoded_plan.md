# lvds_decoded SignalTap Widening Plan

Date: 2026-05-25

## Current Inventory

File:
`firmware_builds/systems/260518-feb-ok/syn/board_projects/fe_scifi_feb_v3/mutrig_cfg_lvds.stp`

Existing instance:

| Item | Current value |
| --- | --- |
| SignalTap instance | `lvds_decoded` |
| Sample clock | `feb_system:u_feb_system|feb_system_v4:u_qsys|feb_system_v4_data_path_subsystem:data_path_subsystem|lvds_outclock_clk` |
| Sample depth | 4096 |
| Unique stored data indices | 121 (`data_index=0..120`) |
| Current lane-specific decoded byte probe | `stp_decoded_data_q[8][8:0]` only |
| Current lane-specific decoded error probe | `stp_decoded_error_q[8][2:0]` only |
| Current lane control probe | `stp_lane8_ctrl_q[8:0]` only |
| Current raw lane-8 PHY probe | `coe_parallel_data[89:80]` |
| Current trigger | lane-8 K flag falling on `stp_decoded_data_q[8][8]` |

Inventory grep used:

```sh
rg -o 'data_index="[0-9]+"' mutrig_cfg_lvds.stp | sed 's/[^0-9]//g' | sort -n -u | wc -l
rg -o 'stp_decoded_data_q\[[0-9]+\]' mutrig_cfg_lvds.stp | sort -u
rg -o 'stp_decoded_error_q\[[0-9]+\]' mutrig_cfg_lvds.stp | sort -u
rg -o 'stp_lane[0-9]+_ctrl_q' mutrig_cfg_lvds.stp | sort -u
```

Result: only lane 8 has explicit decoded byte/error/control probes today.

## Proposed Additions

Add the missing lane 0-7 decoded probes to the existing `lvds_decoded`
instance. Do not add another SignalTap instance.

| Probe group | Bits |
| --- | ---: |
| `stp_decoded_data_q[0..7][8:0]` | 72 |
| `stp_decoded_error_q[0..7][2:0]` | 24 |
| `stp_laneN_ctrl_q` dpalock bit for lanes 0..7 | 8 |
| Total minimal addition | 104 |

If the full `stp_laneN_ctrl_q[8:0]` bus is needed for lanes 0..7, the control
addition becomes 72 bits and the total addition becomes 168 bits. The minimal
104-bit plan is preferred for the next compile because it captures the specific
lock/decoded/error question with lower routing pressure.

## Routing Impact Estimate

Last successful FEB fit:

| Metric | Value |
| --- | --- |
| ALMs | 55,597 / 91,680 (61%) |
| Registers | 92,651 |
| Block memory bits | 6,651,276 / 13,987,840 (48%) |
| DSP | 0 / 800 |
| Slow 1100 mV 85 C setup WNS | +0.344 ns |
| Slow 1100 mV 85 C hold WNS | +0.200 ns |

The 104-bit minimal addition raises the stored probe count from 121 to about
225. At depth 4096, the raw storage increase is about 104 * 4096 = 425,984
bits, or roughly 3.0% of the A5 block-memory budget. Timing margin is positive
but not large; the risk is mostly SignalTap routing congestion, not logic
utilization. Keeping only dpalock from the lane control bus is the safest first
step.

## Minimal STP Edit

Add only `<wire>` entries in the existing `lvds_decoded` `trigger_input_vec`,
`data_input_vec`, and related node/net sections using the same fully-qualified
hierarchy as the existing lane-8 probes:

```xml
<wire name="feb_system:u_feb_system|feb_system_v4:u_qsys|feb_system_v4_data_path_subsystem:data_path_subsystem|feb_system_v4_data_path_subsystem_mu3e_lvds_controller_0:mu3e_lvds_controller_0|mu3e_lvds_controller_phy_adapter:core|mu3e_lvds_controller:u_core|stp_decoded_data_q[L][B]" tap_mode="classic"/>
<wire name="feb_system:u_feb_system|feb_system_v4:u_qsys|feb_system_v4_data_path_subsystem:data_path_subsystem|feb_system_v4_data_path_subsystem_mu3e_lvds_controller_0:mu3e_lvds_controller_0|mu3e_lvds_controller_phy_adapter:core|mu3e_lvds_controller:u_core|stp_decoded_error_q[L][B]" tap_mode="classic"/>
<wire name="feb_system:u_feb_system|feb_system_v4:u_qsys|feb_system_v4_data_path_subsystem:data_path_subsystem|feb_system_v4_data_path_subsystem_mu3e_lvds_controller_0:mu3e_lvds_controller_0|mu3e_lvds_controller_phy_adapter:core|mu3e_lvds_controller:u_core|stp_laneL_ctrl_q[3]" tap_mode="classic"/>
```

Use `L=0..7`, `B=8..0` for decoded data, and `B=2..0` for decoded error.
`stp_laneL_ctrl_q[3]` is the lane-lock bit used in the lane-8 capture flow.
Keep sample depth at 4096 and keep the existing `lvds_decoded` instance name.

The safer implementation path is to update
`firmware_builds/systems/260518-feb-ok/script/signaltap/generate_mutrig_cfg_lvds_stp.py`
and regenerate this STP instead of hand-editing all repeated XML sections.
After regeneration, verify that the SLD trigger CRC is not `00000000`.

## Recompile Cost

Expected cost: one FEB compile from
`firmware_builds/systems/260518-feb-ok/syn/board_projects/fe_scifi_feb_v3/`,
then reprogram the FEB. The last comparable FEB compile was about 50 minutes.

No `qsys-from-tcl` regeneration is needed for this STP-only change.

## Recommended Trigger

For all-lane health:

```text
(stp_decoded_error_q[0] != 3'h0) ||
(stp_decoded_error_q[1] != 3'h0) ||
(stp_decoded_error_q[2] != 3'h0) ||
(stp_decoded_error_q[3] != 3'h0) ||
(stp_decoded_error_q[4] != 3'h0) ||
(stp_decoded_error_q[5] != 3'h0) ||
(stp_decoded_error_q[6] != 3'h0) ||
(stp_decoded_error_q[7] != 3'h0) ||
(stp_decoded_data_q[8][8:0] != 9'h1BC && stp_lane8_ctrl_q[3] == 1'b1)
```

For ASIC7-focused follow-up, use lane 7:

```text
stp_decoded_data_q[7][8:0] != 9'h1BC || stp_decoded_error_q[7][2:0] != 3'h0
```

Use pre-trigger capture, depth 4096, and the existing `lvds_outclock_clk`
sample clock.

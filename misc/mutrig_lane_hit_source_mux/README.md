# mutrig_lane_hit_source_mux

Runtime-selectable lane source mux on the **post-deassembly hit_type0**
boundary. Select between the real MuTRiG path
(`mutrig_frame_deassembly.aso_hit_type0`) and the emulator path
(`emulator_mutrig.aso_hit_type0`, available when the IP is built with
`BYTE_STREAM_ENABLE = 0` per `emulator_mutrig/doc/RTL_PLAN_central_trigger.md`).

Switching is deferred until the active source is between packets so
SOP/EOP/EOR atomicity is preserved end-to-end. A pending CSR write to
`CONTROL.select_emulator` is held in `select_emulator_pending` and only
takes effect when `in_packet_active = 0`.

CSR map, word addressed (kept identical in shape to
`misc/mutrig_lane_source_mux` for software reuse):

| Word | Name | Meaning |
|---:|---|---|
| `0x0` | `UID` | `0x484C534D` (`HLSM`) |
| `0x1` | `META` | selector-controlled version/date/git/instance |
| `0x2` | `CONTROL` | bit 0 select_emulator; bit 1 W1P clear counters |
| `0x3` | `STATUS` | live select, valid/sop/eop/eor/in_packet, pending |
| `0x4` | `REAL_BEATS` | saturating real input valid-beat counter |
| `0x5` | `EMU_BEATS` | saturating emulator input valid-beat counter |
| `0x6` | `SELECTED_BEATS` | saturating selected output valid-beat counter |
| `0x7` | `SWITCH_COUNT` | saturating count of effective source switches |
| `0x8` | `LAST_SELECTED` | last selected source/error/channel/data[8:0] |

# mutrig_lane_source_mux

Runtime lane source selector for FEB SciFi bring-up. Each instance forwards
either the decoded real MuTRiG LVDS stream or the local `emulator_mutrig`
stream into one MuTRiG datapath lane.

CSR summary, word addressed:

| Word | Name | Meaning |
|---:|---|---|
| `0x0` | `UID` | `0x4D4C534D` (`MLSM`) |
| `0x1` | `META` | selector-controlled version/date/git/instance word |
| `0x2` | `CONTROL` | bit 0 selects emulator, bit 1 clears counters |
| `0x3` | `STATUS` | live source plus current valid/error/channel sidebands |
| `0x4` | `REAL_BEATS` | real input valid-beat counter |
| `0x5` | `EMU_BEATS` | emulator input valid-beat counter |
| `0x6` | `SELECTED_BEATS` | selected output valid-beat counter |
| `0x7` | `SWITCH_COUNT` | source-change counter |
| `0x8` | `LAST_SELECTED` | last selected source/error/channel/data |

In `system_20260427_testplanphase5`, host control is through
`firmware_builds/systems/system_20260427_testplanphase5/script/set_mutrig_lane_sources.py`.

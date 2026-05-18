# data_path_subsystem_lvds_rx_controller_pro_0.csr CSR readback

- **Timestamp**: 2026-05-18T20:38:10
- **Kind**: `lvds_rx_controller_pro`
- **sc-byte base**: `0x020000`
- **addressSpan**: `0x0100` bytes
- **probe mode**: report (burst 256)
- **SVD**: `lvds_rx_controller_pro.svd` v26.2.1.0506

### `data_path_subsystem_lvds_rx_controller_pro_0.csr`  (kind=`lvds_rx_controller_pro`)

- **sc-byte base**: `0x020000`  (sc-word `0x08000`)
- **addressSpan**: `0x0100` bytes (`64` words)
- **probed**: first `64` words (min(span_words, 256))
- **SVD**: `lvds_rx_controller_pro.svd` v26.2.1.0506  (22 registers declared)

| offset | register | SVD (reset + description) | UVM (expected) | board (single / burst) | diff |
|---|---|---|---|---|---|
| `+0x000` | `UID` | `0x4C564453` — Software-visible LVDS controller UID. Default ASCII "LVDS" (0x4C564453). | — | `0x00FA0009` / `0x00FA0009` | drift |
| `+0x004` | `META` | _(no reset declared)_ — Read-multiplexed metadata word. Write page[1:0] before reading back: 0=VERSION, 1=VERSION_DATE, 2=VERSION_GIT, 3=INSTANCE_ID. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x008` | `CAPABILITY` | `0x1A01090A` — Packed capability word for the compiled lane/engine/routing profile. | — | `0x00000000` / `0x00000000` | drift |
| `+0x00C` | `SYNC_PATTERN` | `0x000000FA` — Training/control symbol accepted as the lane synchronization pattern. Writes are accepted only for RTL-recognized K28.5/K28.0/K23.7 encodings. | — | `0x00000000` / `0x00000000` | drift |
| `+0x010` | `LANE_GO` | `0x000001FF` — Per-lane enable mask, clipped by the compiled active-lane mask. | — | `0x000001FF` / `0x000001FF` | match |
| `+0x014` | `DPA_HOLD` | `0x00000000` — Per-lane DPA hold request mask, clipped by the compiled active-lane mask. | — | `0x0000C630` / `0x0000C630` | drift |
| `+0x018` | `SOFT_RESET` | `0x00000000` — Per-lane soft-reset request latch. Writing 1 requests a lane soft reset; RTL clears the bit after the hold interval completes. | — | `0xFFFFFFFF` / `0xFFFFFFFF` | drift |
| `+0x01C` | `MODE_MASK` | `0x00000000` — Global two-bit lane mode in the current RTL. The full word is stored, but lane_mode() currently consumes bits [1:0]. | — | `0x0000C5BB` / `0x0000C5BB` | drift |
| `+0x020` | `SCORE_ACCEPT` | `0x00000008` — Engine steering accept threshold, clamped by the RTL score window. | — | `0xFFFFFFFF` / `0xFFFFFFFF` | drift |
| `+0x024` | `SCORE_REJECT` | `0x00000002` — Engine steering reject threshold, clamped not to exceed SCORE_ACCEPT. | — | `0x0000AB05` / `0x0000AB05` | drift |
| `+0x028` | `STEER_STATUS` | _(no reset declared)_ — Snapshot status from the data-clock steering queue. This read may wait while the control clock requests the data-clock snapshot. | — | `0x00009F70` / `0x00009F70` | no-svd-reset |
| `+0x02C` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x030` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x034` | `—` | — | — | `0x0002F435` / `0x0002F435` | no-svd-reset |
| `+0x038` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x03C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x040` | `LANE_SELECT` | `0x00000000` — Selected lane for the counter snapshot window. Writes above the last active lane clamp to the last active lane. | — | `0x00000000` / `0x00000000` | match |
| `+0x044` | `CODE_VIOLATIONS` | `0x00000000` — Illegal or unexpected 8b/10b symbol events observed on the selected lane. The lane is selected by LANE_SELECT and the value is returned through the RTL snapshot | — | `0x00000000` / `0x00000000` | match |
| `+0x048` | `DISP_VIOLATIONS` | `0x00000000` — Disparity violation events observed on the selected lane. The lane is selected by LANE_SELECT and the value is returned through the RTL snapshot path. | — | `0x00000000` / `0x00000000` | match |
| `+0x04C` | `COMMA_LOSSES` | `0x00000000` — Selected-lane comma/sync-pattern loss events. The lane is selected by LANE_SELECT and the value is returned through the RTL snapshot path. | — | `0x00000000` / `0x00000000` | match |
| `+0x050` | `BITSLIP_EVENTS` | `0x00000000` — Selected-lane bitslip control events. The lane is selected by LANE_SELECT and the value is returned through the RTL snapshot path. | — | `0x00000000` / `0x00000000` | match |
| `+0x054` | `DPA_UNLOCKS` | `0x00000000` — Selected-lane DPA unlock events. The lane is selected by LANE_SELECT and the value is returned through the RTL snapshot path. | — | `0x00000000` / `0x00000000` | match |
| `+0x058` | `REALIGNS` | `0x00000000` — Selected-lane realignment events. The lane is selected by LANE_SELECT and the value is returned through the RTL snapshot path. | — | `0x00000000` / `0x00000000` | match |
| `+0x05C` | `SCORE_CHANGES` | `0x00000000` — Selected-lane engine-score change events. The lane is selected by LANE_SELECT and the value is returned through the RTL snapshot path. | — | `0x00000000` / `0x00000000` | match |
| `+0x060` | `ENGINE_STEER` | `0x00000000` — Selected-lane engine steering decisions. The lane is selected by LANE_SELECT and the value is returned through the RTL snapshot path. | — | `0x00000000` / `0x00000000` | match |
| `+0x064` | `SOFT_RESETS` | `0x00000000` — Selected-lane soft-reset completions. The lane is selected by LANE_SELECT and the value is returned through the RTL snapshot path. | — | `0x00000000` / `0x00000000` | match |
| `+0x068` | `UPTIME` | `0x00000000` — Selected-lane uptime counter in data-clock cycles. The lane is selected by LANE_SELECT and the value is returned through the RTL snapshot path. | — | `0x00000000` / `0x00000000` | match |
| `+0x06C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x070` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x074` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x078` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x07C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x080` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x084` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x088` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x08C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x090` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x094` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x098` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x09C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0A0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0A4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0A8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0AC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0B0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0B4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0B8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0BC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0C0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0C4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0C8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0CC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0D0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0D4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0D8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0DC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0E0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0E4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0E8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0EC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0F0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0F4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0F8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0FC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |

**Per-IP summary**: 12 match / 8 drift / 44 no-svd-reset (of 64 words)


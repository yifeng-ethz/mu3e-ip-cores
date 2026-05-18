# control_path_subsystem_firefly_xcvr_ctrl_0.firefly CSR readback

- **Timestamp**: 2026-05-18T20:38:10
- **Kind**: `firefly_xcvr_ctrl`
- **sc-byte base**: `0x004000`
- **addressSpan**: `0x0200` bytes
- **probe mode**: report (burst 256)
- **SVD**: `firefly_xcvr_ctrl.svd` v26.0.330

### `control_path_subsystem_firefly_xcvr_ctrl_0.firefly`  (kind=`firefly_xcvr_ctrl`)

- **sc-byte base**: `0x004000`  (sc-word `0x01000`)
- **addressSpan**: `0x0200` bytes (`128` words)
- **probed**: first `128` words (min(span_words, 256))
- **SVD**: `firefly_xcvr_ctrl.svd` v26.0.330  (14 registers declared)

| offset | register | SVD (reset + description) | UVM (expected) | board (single / burst) | diff |
|---|---|---|---|---|---|
| `+0x000` | `FF1_TEMP_STATUS` | _(no reset declared)_ — Firefly 1 status/control word. Reads return temperature in bits [7:0]. When hidden CSR mode is enabled, bits [27:24] expose present_n and int_n pins. Writing bi | — | `0x00000039` / `0x00000039` | no-svd-reset |
| `+0x004` | `FF1_VCC_RESET` | _(no reset declared)_ — Firefly 1 VCC/control word. Reads return the low 16 bits of the VCC measurement. Writing bit 0 requests a Firefly reset pulse. | — | `0x0000754E` / `0x00000039` | BURST≠SINGLE |
| `+0x008` | `FF1_RXPWR1_HIDDEN` | _(no reset declared)_ — Firefly 1 RX power channel 1 on read. Writing bit 0 enables or disables the hidden CSR page that augments FF1_TEMP_STATUS. | — | `0x00000F46` / `0x00000F46` | no-svd-reset |
| `+0x00C` | `FF1_RXPWR2` | _(no reset declared)_ — Firefly 1 received optical power for channel 2 in the low 16 bits. | — | `0x00000CB2` / `0x00000F46` | BURST≠SINGLE |
| `+0x010` | `FF1_RXPWR3` | _(no reset declared)_ — Firefly 1 received optical power for channel 3 in the low 16 bits. | — | `0x00000BE0` / `0x00000BF4` | BURST≠SINGLE |
| `+0x014` | `FF1_RXPWR4` | _(no reset declared)_ — Firefly 1 received optical power for channel 4 in the low 16 bits. | — | `0x000018A6` / `0x00000BF4` | BURST≠SINGLE |
| `+0x018` | `FF1_ALARM` | _(no reset declared)_ — Firefly 1 latched alarm/status flags. Bits clear on read inside the module according to the Firefly alarm semantics. | — | `0x50000000` / `0x50000000` | no-svd-reset |
| `+0x01C` | `FF2_TEMP_STATUS` | _(no reset declared)_ — Firefly 2 status word. Reads return temperature in bits [7:0]. | — | `0x000000FF` / `0x50000000` | BURST≠SINGLE |
| `+0x020` | `FF2_VCC` | _(no reset declared)_ — Firefly 2 VCC measurement in the low 16 bits. | — | `0x0000FFFF` / `0x0000FFFF` | no-svd-reset |
| `+0x024` | `FF2_RXPWR1` | _(no reset declared)_ — Firefly 2 received optical power for channel 1 in the low 16 bits. | — | `0x0000FFFF` / `0x0000FFFF` | no-svd-reset |
| `+0x028` | `FF2_RXPWR2` | _(no reset declared)_ — Firefly 2 received optical power for channel 2 in the low 16 bits. | — | `0x0000FFFF` / `0x0000FFFF` | no-svd-reset |
| `+0x02C` | `FF2_RXPWR3` | _(no reset declared)_ — Firefly 2 received optical power for channel 3 in the low 16 bits. | — | `0x0000FFFF` / `0x0000FFFF` | no-svd-reset |
| `+0x030` | `FF2_RXPWR4` | _(no reset declared)_ — Firefly 2 received optical power for channel 4 in the low 16 bits. | — | `0x0000FFFF` / `0x0000FFFF` | no-svd-reset |
| `+0x034` | `FF2_ALARM` | _(no reset declared)_ — Firefly 2 latched alarm/status flags. Bits clear on read inside the module according to the Firefly alarm semantics. | — | `0xFFFFFFFF` / `0x0000FFFF` | BURST≠SINGLE |
| `+0x038` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x03C` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x040` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x044` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x048` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x04C` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x050` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x054` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x058` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x05C` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x060` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x064` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x068` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x06C` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x070` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x074` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x078` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x07C` | `—` | — | — | `0xFFFFFFFF` / `0xFFFFFFFF` | no-svd-reset |
| `+0x080` | `—` | — | — | `0x20000010` / `0x20000010` | no-svd-reset |
| `+0x084` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x088` | `—` | — | — | `0x000007D0` / `0x000007D0` | no-svd-reset |
| `+0x08C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x090` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x094` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x098` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x09C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0A0` | `—` | — | — | `0x20000010` / `0x20000010` | no-svd-reset |
| `+0x0A4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0A8` | `—` | — | — | `0x000007D0` / `0x000007D0` | no-svd-reset |
| `+0x0AC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0B0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0B4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0B8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0BC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0C0` | `—` | — | — | `0x20000010` / `0x20000010` | no-svd-reset |
| `+0x0C4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0C8` | `—` | — | — | `0x000007D0` / `0x000007D0` | no-svd-reset |
| `+0x0CC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0D0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0D4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0D8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0DC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0E0` | `—` | — | — | `0x20000010` / `0x20000010` | no-svd-reset |
| `+0x0E4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0E8` | `—` | — | — | `0x000007D0` / `0x000007D0` | no-svd-reset |
| `+0x0EC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0F0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0F4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0F8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0FC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x100` | `—` | — | — | `0x20000010` / `0x20000010` | no-svd-reset |
| `+0x104` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x108` | `—` | — | — | `0x000007D0` / `0x000007D0` | no-svd-reset |
| `+0x10C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x110` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x114` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x118` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x11C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x120` | `—` | — | — | `0x20000010` / `0x20000010` | no-svd-reset |
| `+0x124` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x128` | `—` | — | — | `0x000007D0` / `0x000007D0` | no-svd-reset |
| `+0x12C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x130` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x134` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x138` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x13C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x140` | `—` | — | — | `0x20000010` / `0x20000010` | no-svd-reset |
| `+0x144` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x148` | `—` | — | — | `0x000007D0` / `0x000007D0` | no-svd-reset |
| `+0x14C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x150` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x154` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x158` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x15C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x160` | `—` | — | — | `0x20000010` / `0x20000010` | no-svd-reset |
| `+0x164` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x168` | `—` | — | — | `0x000007D0` / `0x000007D0` | no-svd-reset |
| `+0x16C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x170` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x174` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x178` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x17C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x180` | `—` | — | — | `0x20000010` / `0x20000010` | no-svd-reset |
| `+0x184` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x188` | `—` | — | — | `0x000007D0` / `0x000007D0` | no-svd-reset |
| `+0x18C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x190` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x194` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x198` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x19C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1A0` | `—` | — | — | `0x20000010` / `0x20000010` | no-svd-reset |
| `+0x1A4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1A8` | `—` | — | — | `0x000007D0` / `0x000007D0` | no-svd-reset |
| `+0x1AC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1B0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1B4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1B8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1BC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1C0` | `—` | — | — | `0x20000010` / `0x20000010` | no-svd-reset |
| `+0x1C4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1C8` | `—` | — | — | `0x000007D0` / `0x000007D0` | no-svd-reset |
| `+0x1CC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1D0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1D4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1D8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1DC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1E0` | `—` | — | — | `0x20000010` / `0x20000010` | no-svd-reset |
| `+0x1E4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1E8` | `—` | — | — | `0x000007D0` / `0x000007D0` | no-svd-reset |
| `+0x1EC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1F0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1F4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1F8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1FC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |

**Per-IP summary**: 0 match / 0 drift / 122 no-svd-reset (of 128 words)


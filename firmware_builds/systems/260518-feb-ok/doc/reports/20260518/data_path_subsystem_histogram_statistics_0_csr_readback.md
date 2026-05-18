# data_path_subsystem_histogram_statistics_0.csr CSR readback

- **Timestamp**: 2026-05-18T20:38:10
- **Kind**: `histogram_statistics_v2`
- **sc-byte base**: `0x027000`
- **addressSpan**: `0x0200` bytes
- **probe mode**: report (burst 256)
- **SVD**: `histogram_statistics.svd` v26.3.0.0515

### `data_path_subsystem_histogram_statistics_0.csr`  (kind=`histogram_statistics_v2`)

- **sc-byte base**: `0x027000`  (sc-word `0x09C00`)
- **addressSpan**: `0x0200` bytes (`128` words)
- **probed**: first `128` words (min(span_words, 256))
- **SVD**: `histogram_statistics.svd` v26.3.0.0515  (19 registers declared)

| offset | register | SVD (reset + description) | UVM (expected) | board (single / burst) | diff |
|---|---|---|---|---|---|
| `+0x000` | `UID` | `0x48495354` — Software-visible IP identifier. Default ASCII "HIST" (0x48495354). | — | `0x00000000` / `0x00000000` | drift |
| `+0x004` | `META` | _(no reset declared)_ — Read-multiplexed metadata word. Write meta_sel[1:0] before reading back: 0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x008` | `CONTROL` | `0x00000100` — Configuration apply, mode, key interpretation, filter control, and validation status. | — | `0x00000000` / `0x00000000` | drift |
| `+0x00C` | `LEFT_BOUND` | _(no reset declared)_ — Signed left boundary of the histogram range. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x010` | `RIGHT_BOUND` | _(no reset declared)_ — Signed right boundary of the histogram range. Recomputed at apply time when BIN_WIDTH != 0. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x014` | `BIN_WIDTH` | _(no reset declared)_ — Bin width in key-space units. Set to 0 to keep explicit left and right bounds. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x018` | `KEY_LOC` | `0x26231D11` — Packed bit-slice locations for update-key and filter-key extraction. | — | `0x00000000` / `0x00000000` | drift |
| `+0x01C` | `KEY_VALUE` | _(no reset declared)_ — Packed runtime key overrides used by mode-dependent histogram logic. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x020` | `UNDERFLOW_COUNT` | _(no reset declared)_ — Count of keys mapped below the configured range. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x024` | `OVERFLOW_COUNT` | _(no reset declared)_ — Count of keys mapped above the configured range. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x028` | `INTERVAL_CFG` | _(no reset declared)_ — Ping-pong interval timer configuration in clock cycles. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x02C` | `BANK_STATUS` | _(no reset declared)_ — Ping-pong bank-selection and flush-progress status. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x030` | `PORT_STATUS` | _(no reset declared)_ — Ingress FIFO empty-mask and maximum observed fill level. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x034` | `TOTAL_HITS` | _(no reset declared)_ — Live accepted-hit count in the current interval. Resets at manual clear and at every interval pulse. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x038` | `DROPPED_HITS` | _(no reset declared)_ — Live dropped-hit count caused by FIFO or queue overflow in the current interval. Resets at manual clear and at every interval pulse. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x03C` | `COAL_STATUS` | _(no reset declared)_ — Coalescing-queue occupancy, occupancy maximum, and overflow count. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x040` | `SCRATCH` | _(no reset declared)_ — General-purpose scratch register for integration testing. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x044` | `LAST_INTERVAL_TOTAL_HITS` | _(no reset declared)_ — Accepted-hit count latched at the most recent interval pulse before the live counter reset. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x048` | `LAST_INTERVAL_DROPPED_HITS` | _(no reset declared)_ — Dropped-hit count latched at the most recent interval pulse before the live counter reset. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x04C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x050` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x054` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x058` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x05C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x060` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x064` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x068` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
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
| `+0x100` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x104` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x108` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x10C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x110` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x114` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x118` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x11C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x120` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x124` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x128` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x12C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x130` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x134` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x138` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x13C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x140` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x144` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x148` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x14C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x150` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x154` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x158` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x15C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x160` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x164` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x168` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x16C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x170` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x174` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x178` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x17C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x180` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x184` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x188` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x18C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x190` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x194` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x198` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x19C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1A0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1A4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1A8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1AC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1B0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1B4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1B8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1BC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1C0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1C4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1C8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1CC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1D0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1D4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1D8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1DC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1E0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1E4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1E8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1EC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1F0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1F4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1F8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x1FC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |

**Per-IP summary**: 0 match / 3 drift / 125 no-svd-reset (of 128 words)


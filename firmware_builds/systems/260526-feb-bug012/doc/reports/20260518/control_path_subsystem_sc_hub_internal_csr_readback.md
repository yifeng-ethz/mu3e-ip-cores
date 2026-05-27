# control_path_subsystem_sc_hub.internal_csr CSR readback

- **Timestamp**: 2026-05-18T23:52:32
- **Kind**: `sc_hub_v2`
- **sc-byte base**: `0x03FA00`
- **addressSpan**: `0x0040` bytes
- **probe mode**: report (burst 256)
- **SVD**: `sc_hub.svd` v26.6.9.0414

### `control_path_subsystem_sc_hub.internal_csr`  (kind=`sc_hub_v2`)

- **sc-byte base**: `0x03FA00`  (sc-word `0x0FE80`)
- **addressSpan**: `0x0040` bytes (`16` words)
- **probed**: first `16` words (min(span_words, 256))
- **SVD**: `sc_hub.svd` v26.6.9.0414  (30 registers declared)

| offset | register | SVD (reset + description) | UVM (expected) | board (single / burst) | diff |
|---|---|---|---|---|---|
| `+0x000` | `UID` | `0x53434842` — Immutable Mu3e IP identifier. Default ASCII "SCHB". | — | `0x53434842` / `0x53434842` | match |
| `+0x004` | `META` | _(no reset declared)_ — Read-multiplexed metadata word. Write page_sel[1:0] before reading back: 0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID. | — | `0x1A06919E` / `0x1A06919E` | no-svd-reset |
| `+0x008` | `CTRL` | _(no reset declared)_ — Enable, diagnostic clear, and software-reset control word. | — | `0x00000001` / `0x00000001` | no-svd-reset |
| `+0x00C` | `STATUS` | _(no reset declared)_ — Busy/error summary and FIFO/bus state. | — | `0x00000010` / `0x00000010` | no-svd-reset |
| `+0x010` | `ERR_FLAGS` | _(no reset declared)_ — Sticky overflow, timeout, packet-drop, and bus error flags. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x014` | `ERR_COUNT` | _(no reset declared)_ — Saturating 32-bit error counter. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x018` | `SCRATCH` | _(no reset declared)_ — General-purpose software scratch register. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x01C` | `GTS_SNAP_LO` | _(no reset declared)_ — Global-timestamp snapshot low word. | — | `0x00000000` / `0x1F93FEDF` | BURST≠SINGLE |
| `+0x020` | `GTS_SNAP_HI` | _(no reset declared)_ — Global-timestamp snapshot high word. Reading this register captures a fresh snapshot. | — | `0x00000000` / `0x00000009` | BURST≠SINGLE |
| `+0x024` | `FIFO_CFG` | _(no reset declared)_ — Backpressure and store-and-forward configuration summary. | — | `0x00000003` / `0x00000003` | no-svd-reset |
| `+0x028` | `FIFO_STATUS` | _(no reset declared)_ — Download, reply, and read-data FIFO state summary. | — | `0x00000020` / `0x00000000` | BURST≠SINGLE |
| `+0x02C` | `DOWN_PKT_CNT` | _(no reset declared)_ — Download packet occupancy summary bit. | — | `0x00000001` / `0x00000001` | no-svd-reset |
| `+0x030` | `UP_PKT_CNT` | _(no reset declared)_ — Reply FIFO packet count. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x034` | `DOWN_USEDW` | _(no reset declared)_ — Download FIFO used words. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x038` | `UP_USEDW` | _(no reset declared)_ — Reply FIFO used words. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x03C` | `EXT_PKT_RD` | _(no reset declared)_ — External read packet counter. | — | `0x000009E9` / `0x000009E9` | no-svd-reset |

**Per-IP summary**: 1 match / 0 drift / 12 no-svd-reset (of 16 words)


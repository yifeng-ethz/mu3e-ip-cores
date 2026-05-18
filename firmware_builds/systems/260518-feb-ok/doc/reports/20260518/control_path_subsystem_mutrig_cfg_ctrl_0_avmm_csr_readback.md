# control_path_subsystem_mutrig_cfg_ctrl_0.avmm_csr CSR readback

- **Timestamp**: 2026-05-18T20:38:10
- **Kind**: `mutrig_cfg_ctrl`
- **sc-byte base**: `0x005000`
- **addressSpan**: `0x0040` bytes
- **probe mode**: report (burst 256)
- **SVD**: `mutrig_cfg_ctrl.svd` v24.0.817

### `control_path_subsystem_mutrig_cfg_ctrl_0.avmm_csr`  (kind=`mutrig_cfg_ctrl`)

- **sc-byte base**: `0x005000`  (sc-word `0x01400`)
- **addressSpan**: `0x0040` bytes (`16` words)
- **probed**: first `16` words (min(span_words, 256))
- **SVD**: `mutrig_cfg_ctrl.svd` v24.0.817  (4 registers declared)
- **probe error**: `single@+0x038: rc=2: err: SC secondary did not report ready after reset`

| offset | register | SVD (reset + description) | UVM (expected) | board (single / burst) | diff |
|---|---|---|---|---|---|
| `+0x000` | `OPCODE_STATUS` | _(no reset declared)_ — MuTRiG command/status word. Writes latch a 32-bit opcode. Reads return zero while idle; while busy, bits [31:16] echo opcode[31:16] and bits [15:0] return the c | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x004` | `OFFSET` | _(no reset declared)_ — Scratchpad/configuration memory offset word used by the MuTRiG controller RPC engine. | — | `0x0000BEEF` / `0x0000BEEF` | no-svd-reset |
| `+0x008` | `MONITOR_SECONDS` | _(no reset declared)_ — Monitor integration interval in seconds for the MuTRiG controller counter logic. | — | `0x00000001` / `0x00000001` | no-svd-reset |
| `+0x00C` | `RESERVED3` | _(no reset declared)_ — Reserved fourth CSR word. Reads return zero. Writes are ignored. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x010` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x014` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x018` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x01C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x020` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x024` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x028` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x02C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x030` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x034` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |

**Per-IP summary**: 0 match / 0 drift / 14 no-svd-reset (of 14 words)


# control_path_subsystem_on_die_temp_sense_ctrl.csr CSR readback

- **Timestamp**: 2026-05-18T23:52:32
- **Kind**: `altera_temp_sense_ctrl`
- **sc-byte base**: `0x002000`
- **addressSpan**: `0x0010` bytes
- **probe mode**: report (burst 256)
- **SVD**: `altera_temp_sense_ctrl.svd` v1.1

### `control_path_subsystem_on_die_temp_sense_ctrl.csr`  (kind=`altera_temp_sense_ctrl`)

- **sc-byte base**: `0x002000`  (sc-word `0x00800`)
- **addressSpan**: `0x0010` bytes (`4` words)
- **probed**: first `4` words (min(span_words, 256))
- **SVD**: `altera_temp_sense_ctrl.svd` v1.1  (1 registers declared)

| offset | register | SVD (reset + description) | UVM (expected) | board (single / burst) | diff |
|---|---|---|---|---|---|
| `+0x000` | `CSR` | _(no reset declared)_ — Shared control/status word for the Arria-V on-die temperature sensor wrapper. Reads return the signed 8-bit temperature sample in bits [7:0]. Writes use bit 0 t | — | `0x00000030` / `0x00000030` | no-svd-reset |
| `+0x004` | `—` | — | — | `0x1A0301FA` / `0x1A0301FA` | no-svd-reset |
| `+0x008` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x00C` | `—` | — | — | `0x00000002` / `0x00000002` | no-svd-reset |

**Per-IP summary**: 0 match / 0 drift / 4 no-svd-reset (of 4 words)


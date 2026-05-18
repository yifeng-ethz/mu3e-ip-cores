# control_path_subsystem_onewire_master_controller_0.csr CSR readback

- **Timestamp**: 2026-05-18T20:38:10
- **Kind**: `onewire_master_controller`
- **sc-byte base**: `0x003000`
- **addressSpan**: `0x0100` bytes
- **probe mode**: report (burst 256)
- **SVD**: `onewire_master_controller.svd` v26.2.1

### `control_path_subsystem_onewire_master_controller_0.csr`  (kind=`onewire_master_controller`)

- **sc-byte base**: `0x003000`  (sc-word `0x00C00`)
- **addressSpan**: `0x0100` bytes (`64` words)
- **probed**: first `64` words (min(span_words, 256))
- **SVD**: `onewire_master_controller.svd` v26.2.1  (11 registers declared)

| offset | register | SVD (reset + description) | UVM (expected) | board (single / burst) | diff |
|---|---|---|---|---|---|
| `+0x000` | `UID` | `0x4F574D43` — Common Mu3e software-visible IP identifier. Default is ASCII OWMC. | — | `0x4F574D43` / `0x4F574D43` | match |
| `+0x004` | `META` | _(no reset declared)_ — Common read-multiplexed metadata word. Writes select the readback page: 0 VERSION, 1 VERSION_DATE, 2 VERSION_GIT, 3 INSTANCE_ID. | — | `0x1A0211AC` / `0x1A0211AC` | no-svd-reset |
| `+0x008` | `SCRATCH` | _(no reset declared)_ — Software scratch/readback word for CSR liveness tests. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x00C` | `CAPABILITY` | _(no reset declared)_ — 1-Wire controller capability register. | — | `0x00000006` / `0x00000006` | no-svd-reset |
| `+0x010` | `STATUS` | _(no reset declared)_ — Line select and per-line control/status register. Reads return the selected line and its sticky error summary. Writes update sel_line and processor_go for the a | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x014` | `SENSOR0_TEMP_F32` | _(no reset declared)_ — IEEE-754 float32 temperature reading for sensor 0. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x018` | `SENSOR1_TEMP_F32` | _(no reset declared)_ — IEEE-754 float32 temperature reading for sensor 1. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x01C` | `SENSOR2_TEMP_F32` | _(no reset declared)_ — IEEE-754 float32 temperature reading for sensor 2. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x020` | `SENSOR3_TEMP_F32` | _(no reset declared)_ — IEEE-754 float32 temperature reading for sensor 3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x024` | `SENSOR4_TEMP_F32` | _(no reset declared)_ — IEEE-754 float32 temperature reading for sensor 4. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x028` | `SENSOR5_TEMP_F32` | _(no reset declared)_ — IEEE-754 float32 temperature reading for sensor 5. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x02C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x030` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x034` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x038` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x03C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x040` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x044` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x048` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
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

**Per-IP summary**: 1 match / 0 drift / 63 no-svd-reset (of 64 words)


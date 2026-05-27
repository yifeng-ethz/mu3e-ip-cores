# data_path_subsystem_mutrig_injector_0.csr CSR readback

- **Timestamp**: 2026-05-18T23:52:32
- **Kind**: `mutrig_injector_multiheader`
- **sc-byte base**: `0x02A000`
- **addressSpan**: `0x0100` bytes
- **probe mode**: report (burst 256)
- **SVD**: `mutrig_injector.svd` v26.0.3.0429

### `data_path_subsystem_mutrig_injector_0.csr`  (kind=`mutrig_injector_multiheader`)

- **sc-byte base**: `0x02A000`  (sc-word `0x0A800`)
- **addressSpan**: `0x0100` bytes (`64` words)
- **probed**: first `64` words (min(span_words, 256))
- **SVD**: `mutrig_injector.svd` v26.0.3.0429  (16 registers declared)

| offset | register | SVD (reset + description) | UVM (expected) | board (single / burst) | diff |
|---|---|---|---|---|---|
| `+0x000` | `UID` | `0x4D494E4A` — Software-visible IP identifier. Default payload is ASCII MINJ. | — | `0x00000000` / `0x00000000` | drift |
| `+0x004` | `META` | `0x1A0031AD` — Read-multiplexed metadata word. Write 0=VERSION, 1=VERSION_DATE, 2=VERSION_GIT, 3=INSTANCE_ID before reading back. | — | `0x00000000` / `0x00000000` | drift |
| `+0x008` | `MODE` | `0x00000000` — Injection mode selector. Writing value 4 emits a one-click pulse and stores mode 0. Writing value 5 also reseeds PRBS state. | — | `0x00000000` / `0x00000000` | match |
| `+0x00C` | `HEADER_DELAY` | `0x00000064` — Main-clock delay from selected header match to first header-synchronous pulse. | — | `0x00000000` / `0x00000000` | drift |
| `+0x010` | `HEADER_INTERVAL` | `0x00000001` — Number of selected header matches between mode-1 bursts. | — | `0x00000000` / `0x00000000` | drift |
| `+0x014` | `INJECTION_MULTIPLICITY` | `0x00000001` — Number of pulses in each header-triggered or PRBS-triggered burst. | — | `0x00000000` / `0x00000000` | drift |
| `+0x018` | `HEADER_CH` | `0x00000000` — Selected header channel. The RTL compares this value against all eight headerinfo channel sidebands. | — | `0x00000000` / `0x00000000` | match |
| `+0x01C` | `PULSE_INTERVAL` | `0x000003E8` — Mode-2 interval in main-clock cycles. Mode 3 derives the oscillator-domain interval from this value. | — | `0x00000000` / `0x00000000` | drift |
| `+0x020` | `PULSE_HIGH_CYCLES` | `0x00000005` — Pulse high duration. RTL uses bits [7:0] and enforces a minimum low gap between burst pulses. | — | `0x00000000` / `0x00000000` | drift |
| `+0x024` | `PRBS_RATE` | `0x000003E7` — Number of main-clock cycles between PRBS state advances in mode 5. | — | `0x00000000` / `0x00000000` | drift |
| `+0x028` | `PRBS_PATTERN` | `0x00000001` — Pattern compared against the low PRBS bits selected by PRBS_CTRL. | — | `0x00000000` / `0x00000000` | drift |
| `+0x02C` | `PRBS_SEED` | `0x0000ACE1` — Seed used when entering or reseeding mode 5. All-zero selected bits are sanitized to bit 0 set. | — | `0x00000000` / `0x00000000` | drift |
| `+0x030` | `PRBS_CTRL` | `0x00000004` — PRBS polynomial and match-width selector. | — | `0x00000000` / `0x00000000` | drift |
| `+0x034` | `RESERVED13` | `0x00000000` — Reserved decoded word. Current RTL returns zero and ignores writes. | — | `0x00000000` / `0x00000000` | match |
| `+0x038` | `RESERVED14` | `0x00000000` — Reserved decoded word. Current RTL returns zero and ignores writes. | — | `0x00000000` / `0x00000000` | match |
| `+0x03C` | `RESERVED15` | `0x00000000` — Reserved decoded word. Current RTL returns zero and ignores writes. | — | `0x00000000` / `0x00000000` | match |
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

**Per-IP summary**: 5 match / 11 drift / 48 no-svd-reset (of 64 words)


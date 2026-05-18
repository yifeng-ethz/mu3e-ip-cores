# control_path_subsystem_scratch_pad_ram.s1 CSR readback

- **Timestamp**: 2026-05-18T23:52:32
- **Kind**: `altera_avalon_onchip_memory2`
- **sc-byte base**: `0x000000`
- **addressSpan**: `0x1000` bytes
- **probe mode**: report (burst 256)

### `control_path_subsystem_scratch_pad_ram.s1`  (kind=`altera_avalon_onchip_memory2`)

- **sc-byte base**: `0x000000`  (sc-word `0x00000`)
- **addressSpan**: `0x1000` bytes (`1024` words)
- **probed**: first `256` words (min(span_words, 256))
- **SVD**: (not mapped for this kind)
- **probe error**: `single@+0x000: rc=4: 311
  [17] invalid RD_NI link=23 addr=0x0C0FF rsp=OK ack=0 declared=57575 actual=0 start=0x2319
warn: scan ended with an incomplete candidate packet
err: timed out waiting for matching secondary reply`

> No readback data — probe failed before any word was read.


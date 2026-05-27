# control_path_subsystem_max10_prog_avmm_0.csr_avmm CSR readback

- **Timestamp**: 2026-05-18T23:52:32
- **Kind**: `max10_prog_avmm`
- **sc-byte base**: `0x001000`
- **addressSpan**: `0x4000` bytes
- **probe mode**: report (burst 256)
- **SVD**: `max10_prog_avmm.svd` v0.2.0

### `control_path_subsystem_max10_prog_avmm_0.csr_avmm`  (kind=`max10_prog_avmm`)

- **sc-byte base**: `0x001000`  (sc-word `0x00400`)
- **addressSpan**: `0x4000` bytes (`4096` words)
- **probed**: first `256` words (min(span_words, 256))
- **SVD**: `max10_prog_avmm.svd` v0.2.0  (79 registers declared)

| offset | register | SVD (reset + description) | UVM (expected) | board (single / burst) | diff |
|---|---|---|---|---|---|
| `+0x000` | `ID` | `0x4D313050` — IP identifier magic. Default Rev-A value is ASCII "M10P". | — | `0x4D312850` / `0x4D312850` | drift |
| `+0x004` | `VERSION` | _(no reset declared)_ — Packed interface version: [31:24]=major, [23:16]=minor, [15:12]=patch, [11:0]=build. | — | `0x00020000` / `0x00020000` | no-svd-reset |
| `+0x008` | `CTRL` | _(no reset declared)_ — Common management control. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x00C` | `STATUS` | _(no reset declared)_ — Common ready/busy/fault/resetting summary. | — | `0x00000001` / `0x00000001` | no-svd-reset |
| `+0x010` | `ERR_FLAGS` | _(no reset declared)_ — Sticky local error flags. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x014` | `ERR_COUNT` | _(no reset declared)_ — Saturating count of newly-detected error events. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x018` | `SCRATCH` | _(no reset declared)_ — Diagnostic scratch register with no side effects. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x01C` | `FLASH_ADDR` | _(no reset declared)_ — Absolute SPI flash byte address for the next page launch. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x020` | `XFER_BYTES` | `0x00000100` — Number of valid payload bytes for the next START request. Reset default is 256. | — | `0x00000100` / `0x00000100` | match |
| `+0x024` | `PROG_CTRL` | _(no reset declared)_ — Write-one pulse programming commands. Reads are not meaningful and should be avoided. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x028` | `PROG_STATUS` | _(no reset declared)_ — Programming engine status and mirrored MAX10 status summary. | — | `0x00000011` / `0x00000011` | no-svd-reset |
| `+0x02C` | `STAGED_WORDS` | _(no reset declared)_ — Number of contiguous valid words staged from PAGE_DATA[0]. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x030` | `MAX10_STAT` | _(no reset declared)_ — Raw mirror of MAX10 PROGRAMMING_STATUS. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x034` | `MAX10_COUNT` | _(no reset declared)_ — Raw mirror of MAX10 PROGRAMMING_COUNT. Debug only. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x038` | `LAST_ERROR` | _(no reset declared)_ — Last error code and debug snapshot. | — | `0x00000000` / `0x00000000` | no-svd-reset |
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
| `+0x080` | `PAGE_DATA_00` | _(no reset declared)_ — Page staging word 0. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x084` | `PAGE_DATA_01` | _(no reset declared)_ — Page staging word 1. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x088` | `PAGE_DATA_02` | _(no reset declared)_ — Page staging word 2. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x08C` | `PAGE_DATA_03` | _(no reset declared)_ — Page staging word 3. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x090` | `PAGE_DATA_04` | _(no reset declared)_ — Page staging word 4. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x094` | `PAGE_DATA_05` | _(no reset declared)_ — Page staging word 5. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x098` | `PAGE_DATA_06` | _(no reset declared)_ — Page staging word 6. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x09C` | `PAGE_DATA_07` | _(no reset declared)_ — Page staging word 7. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0A0` | `PAGE_DATA_08` | _(no reset declared)_ — Page staging word 8. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0A4` | `PAGE_DATA_09` | _(no reset declared)_ — Page staging word 9. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0A8` | `PAGE_DATA_10` | _(no reset declared)_ — Page staging word 10. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0AC` | `PAGE_DATA_11` | _(no reset declared)_ — Page staging word 11. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0B0` | `PAGE_DATA_12` | _(no reset declared)_ — Page staging word 12. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0B4` | `PAGE_DATA_13` | _(no reset declared)_ — Page staging word 13. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0B8` | `PAGE_DATA_14` | _(no reset declared)_ — Page staging word 14. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0BC` | `PAGE_DATA_15` | _(no reset declared)_ — Page staging word 15. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0C0` | `PAGE_DATA_16` | _(no reset declared)_ — Page staging word 16. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0C4` | `PAGE_DATA_17` | _(no reset declared)_ — Page staging word 17. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0C8` | `PAGE_DATA_18` | _(no reset declared)_ — Page staging word 18. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0CC` | `PAGE_DATA_19` | _(no reset declared)_ — Page staging word 19. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0D0` | `PAGE_DATA_20` | _(no reset declared)_ — Page staging word 20. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0D4` | `PAGE_DATA_21` | _(no reset declared)_ — Page staging word 21. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0D8` | `PAGE_DATA_22` | _(no reset declared)_ — Page staging word 22. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0DC` | `PAGE_DATA_23` | _(no reset declared)_ — Page staging word 23. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0E0` | `PAGE_DATA_24` | _(no reset declared)_ — Page staging word 24. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0E4` | `PAGE_DATA_25` | _(no reset declared)_ — Page staging word 25. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0E8` | `PAGE_DATA_26` | _(no reset declared)_ — Page staging word 26. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0EC` | `PAGE_DATA_27` | _(no reset declared)_ — Page staging word 27. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0F0` | `PAGE_DATA_28` | _(no reset declared)_ — Page staging word 28. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0F4` | `PAGE_DATA_29` | _(no reset declared)_ — Page staging word 29. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0F8` | `PAGE_DATA_30` | _(no reset declared)_ — Page staging word 30. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x0FC` | `PAGE_DATA_31` | _(no reset declared)_ — Page staging word 31. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x100` | `PAGE_DATA_32` | _(no reset declared)_ — Page staging word 32. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x104` | `PAGE_DATA_33` | _(no reset declared)_ — Page staging word 33. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x108` | `PAGE_DATA_34` | _(no reset declared)_ — Page staging word 34. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x10C` | `PAGE_DATA_35` | _(no reset declared)_ — Page staging word 35. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x110` | `PAGE_DATA_36` | _(no reset declared)_ — Page staging word 36. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x114` | `PAGE_DATA_37` | _(no reset declared)_ — Page staging word 37. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x118` | `PAGE_DATA_38` | _(no reset declared)_ — Page staging word 38. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x11C` | `PAGE_DATA_39` | _(no reset declared)_ — Page staging word 39. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x120` | `PAGE_DATA_40` | _(no reset declared)_ — Page staging word 40. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x124` | `PAGE_DATA_41` | _(no reset declared)_ — Page staging word 41. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x128` | `PAGE_DATA_42` | _(no reset declared)_ — Page staging word 42. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x12C` | `PAGE_DATA_43` | _(no reset declared)_ — Page staging word 43. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x130` | `PAGE_DATA_44` | _(no reset declared)_ — Page staging word 44. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x134` | `PAGE_DATA_45` | _(no reset declared)_ — Page staging word 45. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x138` | `PAGE_DATA_46` | _(no reset declared)_ — Page staging word 46. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x13C` | `PAGE_DATA_47` | _(no reset declared)_ — Page staging word 47. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x140` | `PAGE_DATA_48` | _(no reset declared)_ — Page staging word 48. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x144` | `PAGE_DATA_49` | _(no reset declared)_ — Page staging word 49. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x148` | `PAGE_DATA_50` | _(no reset declared)_ — Page staging word 50. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x14C` | `PAGE_DATA_51` | _(no reset declared)_ — Page staging word 51. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x150` | `PAGE_DATA_52` | _(no reset declared)_ — Page staging word 52. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x154` | `PAGE_DATA_53` | _(no reset declared)_ — Page staging word 53. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x158` | `PAGE_DATA_54` | _(no reset declared)_ — Page staging word 54. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x15C` | `PAGE_DATA_55` | _(no reset declared)_ — Page staging word 55. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x160` | `PAGE_DATA_56` | _(no reset declared)_ — Page staging word 56. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x164` | `PAGE_DATA_57` | _(no reset declared)_ — Page staging word 57. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x168` | `PAGE_DATA_58` | _(no reset declared)_ — Page staging word 58. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x16C` | `PAGE_DATA_59` | _(no reset declared)_ — Page staging word 59. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x170` | `PAGE_DATA_60` | _(no reset declared)_ — Page staging word 60. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x174` | `PAGE_DATA_61` | _(no reset declared)_ — Page staging word 61. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x178` | `PAGE_DATA_62` | _(no reset declared)_ — Page staging word 62. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x17C` | `PAGE_DATA_63` | _(no reset declared)_ — Page staging word 63. Byte lane mapping is little-endian: [7:0]=byte 4n+0 through [31:24]=byte 4n+3. | — | `0x00000000` / `0x00000000` | no-svd-reset |
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
| `+0x200` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x204` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x208` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x20C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x210` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x214` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x218` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x21C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x220` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x224` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x228` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x22C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x230` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x234` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x238` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x23C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x240` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x244` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x248` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x24C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x250` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x254` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x258` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x25C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x260` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x264` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x268` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x26C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x270` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x274` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x278` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x27C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x280` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x284` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x288` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x28C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x290` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x294` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x298` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x29C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2A0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2A4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2A8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2AC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2B0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2B4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2B8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2BC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2C0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2C4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2C8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2CC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2D0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2D4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2D8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2DC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2E0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2E4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2E8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2EC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2F0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2F4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2F8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x2FC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x300` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x304` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x308` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x30C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x310` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x314` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x318` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x31C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x320` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x324` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x328` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x32C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x330` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x334` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x338` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x33C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x340` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x344` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x348` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x34C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x350` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x354` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x358` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x35C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x360` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x364` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x368` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x36C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x370` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x374` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x378` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x37C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x380` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x384` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x388` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x38C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x390` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x394` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x398` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x39C` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3A0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3A4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3A8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3AC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3B0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3B4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3B8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3BC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3C0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3C4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3C8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3CC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3D0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3D4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3D8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3DC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3E0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3E4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3E8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3EC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3F0` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3F4` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3F8` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |
| `+0x3FC` | `—` | — | — | `0x00000000` / `0x00000000` | no-svd-reset |

**Per-IP summary**: 1 match / 1 drift / 254 no-svd-reset (of 256 words)


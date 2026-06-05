# Phase 5 MuTRiG XML Configuration Report

- Timestamp: `2026-06-05T17:02:35`
- SC link: `2`
- SMB3 XML: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/board_test_system/trash_bin/good_ribbon_0/config_smb3_tdc.txt`
- SMB5 XML: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/board_test_system/trash_bin/good_ribbon_0/config_smb5_tdc.txt`
- Dry run: `no`
- Channel enable override: `0xFFFFFFFF`
- TDC-test channel override: `0x00000000`
- Channel field overrides: `[('recv_all', 1), ('cml_sc', 0)]`
- Header field overrides: `none`
- TDC field overrides: `none`
- CML flush after config: `no`
- CML start/flush/final values: `0` / `8` / `0`
- Force `cml_sc=0` during CML flush/final: `yes`
- Require frame delta after config: `no`
- Result: `PASS`

| Phase | ASIC | XML Local | Opcode | Words | Final Status | Frame Delta | CRC Delta | Result |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `main` | 0 | 0 | `0x01100054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `main` | 1 | 1 | `0x01110054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `main` | 2 | 2 | `0x01120054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `main` | 3 | 3 | `0x01130054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `main` | 4 | 0 | `0x01140054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `main` | 5 | 1 | `0x01150054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `main` | 6 | 2 | `0x01160054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `main` | 7 | 3 | `0x01170054` | 84 | `0x00000000` | 0 | 0 | `PASS` |

## Packed Word Preview

- main ASIC 0: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F01`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- main ASIC 1: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F01`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- main ASIC 2: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F01`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- main ASIC 3: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F01`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- main ASIC 4: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F01`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- main ASIC 5: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F01`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- main ASIC 6: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F01`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- main ASIC 7: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F01`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`

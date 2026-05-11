# Phase 5 MuTRiG XML Configuration Report

- Timestamp: `2026-04-30T10:29:22`
- SC link: `2`
- SMB3 XML: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/board_test_system/trash_bin/good_ribbon_0/config_smb3_tdc.txt`
- SMB5 XML: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/board_test_system/trash_bin/good_ribbon_0/config_smb5_tdc.txt`
- Dry run: `no`
- Channel enable override: `0xFFFFFFFF`
- TDC-test channel override: `0xFFFFFFFF`
- Channel field overrides: `[('cml_sc', 0), ('recv_all', 1)]`
- Header field overrides: `none`
- TDC field overrides: `[(0, 'vnhitlogic', 40), (2, 'vncnt', 40), (2, 'vnvcodelay', 30), (2, 'vnhitlogic', 30), (3, 'vncnt', 35), (3, 'vnvcodelay', 12), (3, 'vnhitlogic', 25), (7, 'vncnt', 30), (7, 'vnvcodelay', 14), (7, 'vnhitlogic', 40)]`
- Require frame delta after config: `no`
- Result: `PASS`

| ASIC | XML Local | Opcode | Words | Final Status | Frame Delta | CRC Delta | Result |
|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 0 | `0x01100054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| 1 | 1 | `0x01110054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| 2 | 2 | `0x01120054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| 3 | 3 | `0x01130054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| 4 | 0 | `0x01140054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| 5 | 1 | `0x01150054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| 6 | 2 | `0x01160054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| 7 | 3 | `0x01170054` | 84 | `0x00000000` | 0 | 0 | `PASS` |

## Packed Word Preview

- ASIC 0: first `0xF8200003, 0x7C7800DC, 0xF8001020, 0x3C006F01`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- ASIC 1: first `0xF8200003, 0x7C7800DC, 0xF8001020, 0x3C006F01`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- ASIC 2: first `0xF8200003, 0x7C7800DC, 0xF8001020, 0x3C006F01`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- ASIC 3: first `0xF8200003, 0x7C7800DC, 0xF8001020, 0x3C006F01`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- ASIC 4: first `0xF8200003, 0x7C7800DC, 0xF8001020, 0x3C006F01`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- ASIC 5: first `0xF8200003, 0x7C7800DC, 0xF8001020, 0x3C006F01`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- ASIC 6: first `0xF8200003, 0x7C7800DC, 0xF8001020, 0x3C006F01`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- ASIC 7: first `0xF8200003, 0x7C7800DC, 0xF8001020, 0x3C006F01`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`

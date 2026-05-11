# Phase 5 MuTRiG XML Configuration Report

- Timestamp: `2026-04-30T01:24:53`
- SC link: `2`
- SMB3 XML: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/board_test_system/trash_bin/good_ribbon_0/config_smb3_tdc.txt`
- SMB5 XML: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/board_test_system/trash_bin/good_ribbon_0/config_smb5_tdc.txt`
- Dry run: `no`
- Channel enable override: `0xFFF0FF0F`
- TDC-test channel override: `0xFFF0FF0F`
- Channel field overrides: `[('cml_sc', 0), ('recv_all', 1)]`
- Header field overrides: `none`
- TDC field overrides: `none`
- Require frame delta after config: `no`
- Result: `PASS`

| ASIC | XML Local | Opcode | Words | Final Status | Frame Delta | CRC Delta | Result |
|---:|---:|---:|---:|---:|---:|---:|---|
| 5 | 1 | `0x01150054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| 6 | 2 | `0x01160054` | 84 | `0x00000000` | 0 | 0 | `PASS` |

## Packed Word Preview

- ASIC 5: first `0xF8200003, 0x7C7800DC, 0xF8001020, 0x3C006F01`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- ASIC 6: first `0xF8200003, 0x7C7800DC, 0xF8001020, 0x3C006F01`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`

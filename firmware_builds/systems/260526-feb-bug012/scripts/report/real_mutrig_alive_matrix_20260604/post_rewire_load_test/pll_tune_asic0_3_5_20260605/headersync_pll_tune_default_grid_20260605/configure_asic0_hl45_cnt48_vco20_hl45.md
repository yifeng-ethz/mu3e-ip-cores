# Phase 5 MuTRiG XML Configuration Report

- Timestamp: `2026-06-05T15:47:56`
- SC link: `2`
- SMB3 XML: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/board_test_system/trash_bin/good_ribbon_0/config_smb3_tdc.txt`
- SMB5 XML: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/board_test_system/trash_bin/good_ribbon_0/config_smb5_tdc.txt`
- Dry run: `no`
- Channel enable override: `0xFFFFFFFF`
- TDC-test channel override: `0xFFFFFFFF`
- Channel field overrides: `[('recv_all', 1), ('cml_sc', 0)]`
- Header field overrides: `none`
- TDC field overrides: `[(0, 'vncnt', 48), (0, 'vnhitlogic', 45), (0, 'vnvcodelay', 20)]`
- CML flush after config: `yes`
- CML start/flush/final values: `0` / `8` / `0`
- Force `cml_sc=0` during CML flush/final: `yes`
- Require frame delta after config: `no`
- Result: `PASS`

| Phase | ASIC | XML Local | Opcode | Words | Final Status | Frame Delta | CRC Delta | Result |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `cml_start_0` | 0 | 0 | `0x01100054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_flush_8` | 0 | 0 | `0x01100054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_final_0` | 0 | 0 | `0x01100054` | 84 | `0x00000000` | 0 | 0 | `PASS` |

## Packed Word Preview

- cml_start_0 ASIC 0: first `0xF8200003, 0x7C7800DC, 0xF8001020, 0x3C006F01`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- cml_flush_8 ASIC 0: first `0xF8200003, 0x7C7800DC, 0xF8001020, 0x3C006F03`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- cml_final_0 ASIC 0: first `0xF8200003, 0x7C7800DC, 0xF8001020, 0x3C006F01`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`

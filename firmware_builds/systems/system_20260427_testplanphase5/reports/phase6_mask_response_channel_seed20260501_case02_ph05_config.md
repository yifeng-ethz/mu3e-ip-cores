# Phase 5 MuTRiG XML Configuration Report

- Timestamp: `2026-05-01T11:04:09`
- SC link: `2`
- SMB3 XML: `/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_phase6_closure_20260430/board_test_system/trash_bin/good_ribbon_0/config_smb3_tdc.txt`
- SMB5 XML: `/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_phase6_closure_20260430/board_test_system/trash_bin/good_ribbon_0/config_smb5_tdc.txt`
- Dry run: `no`
- Channel enable override: `0x36CA3E18`
- TDC-test channel override: `0x36CA3E18`
- Channel field overrides: `[('recv_all', 1)]`
- Header field overrides: `none`
- TDC field overrides: `[(0, 'vnhitlogic', 40), (2, 'vncnt', 40), (2, 'vnvcodelay', 30), (2, 'vnhitlogic', 30), (3, 'vncnt', 35), (3, 'vnvcodelay', 12), (3, 'vnhitlogic', 25), (7, 'vncnt', 30), (7, 'vnvcodelay', 14), (7, 'vnhitlogic', 40)]`
- CML flush after config: `yes`
- CML start/flush/final values: `0` / `8` / `0`
- Force `cml_sc=0` during CML flush/final: `yes`
- Require frame delta after config: `no`
- Result: `PASS`

| Phase | ASIC | XML Local | Opcode | Words | Final Status | Frame Delta | CRC Delta | Result |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `cml_start_0` | 0 | 0 | `0x01100054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_start_0` | 1 | 1 | `0x01110054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_start_0` | 2 | 2 | `0x01120054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_start_0` | 3 | 3 | `0x01130054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_start_0` | 4 | 0 | `0x01140054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_start_0` | 5 | 1 | `0x01150054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_start_0` | 6 | 2 | `0x01160054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_start_0` | 7 | 3 | `0x01170054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_flush_8` | 0 | 0 | `0x01100054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_flush_8` | 1 | 1 | `0x01110054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_flush_8` | 2 | 2 | `0x01120054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_flush_8` | 3 | 3 | `0x01130054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_flush_8` | 4 | 0 | `0x01140054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_flush_8` | 5 | 1 | `0x01150054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_flush_8` | 6 | 2 | `0x01160054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_flush_8` | 7 | 3 | `0x01170054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_final_0` | 0 | 0 | `0x01100054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_final_0` | 1 | 1 | `0x01110054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_final_0` | 2 | 2 | `0x01120054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_final_0` | 3 | 3 | `0x01130054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_final_0` | 4 | 0 | `0x01140054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_final_0` | 5 | 1 | `0x01150054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_final_0` | 6 | 2 | `0x01160054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| `cml_final_0` | 7 | 3 | `0x01170054` | 84 | `0x00000000` | 0 | 0 | `PASS` |

## Packed Word Preview

- cml_start_0 ASIC 0: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- cml_start_0 ASIC 1: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- cml_start_0 ASIC 2: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- cml_start_0 ASIC 3: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- cml_start_0 ASIC 4: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- cml_start_0 ASIC 5: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- cml_start_0 ASIC 6: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- cml_start_0 ASIC 7: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- cml_flush_8 ASIC 0: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F83`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- cml_flush_8 ASIC 1: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F83`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- cml_flush_8 ASIC 2: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F83`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- cml_flush_8 ASIC 3: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F83`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- cml_flush_8 ASIC 4: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F83`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- cml_flush_8 ASIC 5: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F83`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- cml_flush_8 ASIC 6: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F83`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- cml_flush_8 ASIC 7: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F83`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- cml_final_0 ASIC 0: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- cml_final_0 ASIC 1: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- cml_final_0 ASIC 2: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- cml_final_0 ASIC 3: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0x14000000, 0x00000000`
- cml_final_0 ASIC 4: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- cml_final_0 ASIC 5: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- cml_final_0 ASIC 6: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`
- cml_final_0 ASIC 7: first `0xF8200003, 0x7C7804DC, 0xF8001020, 0x3C026F81`, last `0x00000000, 0x00366000, 0xD9000000, 0x00000000`

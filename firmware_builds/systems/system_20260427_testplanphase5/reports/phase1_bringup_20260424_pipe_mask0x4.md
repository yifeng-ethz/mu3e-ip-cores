# Phase 1 Bring-Up Report

- Timestamp: `2026-04-24T09:12:32`
- SC link: `2`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool`
- System Console: `/data1/intelFPGA/18.1/quartus/sopc_builder/bin/system-console`
- JDI: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.jdi`
- Project dir: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3`
- Debug Qsys: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/debug_sc_system_v3.qsys`
- FEB Qsys/SOPC: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/feb_system_v3_pipe.qsys`, `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/feb_system_v3_pipe.sopcinfo`
- JTAG cable: `USB-BlasterII [7-2]`
- SC enable mask: `0x00000004`
- Expected JDI hash: `768B16B404A0AA5F62D5`
- Live design hash: `768B16B404A0AA5F62D5`
- Result: `FAIL`

## Pre-Flight

### `jtagconfig -n`

- Return code: `0`
```
1) DE5 [3-6.2]
  02E660DD   10AX115H1(.|E2|ES)/10AX115H2/..
    Node 19104600  Nios II #0
    Node 0C206E00  JTAG PHY #0
    Node 0C006E00  JTAG UART #0
    Node 30006E00  Signal Tap #0
    Design hash    3B5F2C87A2CED31867F6

2) USB-BlasterII [7-2]
  02A020DD   5AGT(FC7H3|MC7G3)/5AGXBA7D4/..
    Node 0C206E00  JTAG PHY #0
    Node 10186E00  ROM/RAM/Constant #0
    Node 19104600  Nios II #0
    Node 0C006E00  JTAG UART #0
    Node 0C206E01  JTAG PHY #1
    Node 0C206E02  JTAG PHY #2
    Design hash    768B16B404A0AA5F62D5
```

### `ls -l /dev/mudaq0`

- Return code: `0`
```
crw-rw-rw- 1 root users 10, 124 Apr 22 16:37 /dev/mudaq0
```

## Image Check

- Status: `PASS`
- Detail: live 768B16B404A0AA5F62D5 matches JDI 768B16B404A0AA5F62D5

## Metadata Gate

- Command: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/script/check_ip_metadata.py --link 2 --sc-tool /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool --system-console /data1/intelFPGA/18.1/quartus/sopc_builder/bin/system-console --jdi /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.jdi --project-dir /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3 --inventory-out /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/generated/debug_sc_system_v3_inventory_pipe_live.json`
- Return code: `1`
```
FAIL max10_prog_avmm_0 svd=feb_max10_comm/legacy/max10_prog_avmm/max10_prog_avmm.svd exp_ver=0x00020000 qsys_ver=0x00020000 sc_ver=n/a jtag_ver=0x00020000 exp_git=n/a sc_git=n/a jtag_git=n/a
  error: SC=Command '['/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool', '2', 'read', '0x04801', '1', '--quiet', '--enable-mask', '0x00000004']' returned non-zero exit status 4.
FAIL sc_hub svd=slow-control_hub/sc_hub.svd exp_ver=0x1A06919E qsys_ver=0x1A06919E sc_ver=n/a jtag_ver=0x1A06919E exp_git=0x05E3EABD sc_git=n/a jtag_git=0x05E3EABD
  error: SC=Command '['/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool', '2', 'write', '0x0FE81', '0x00000000', '--quiet', '--enable-mask', '0x00000004']' returned non-zero exit status 4.
```

## Bridge Gate

- Command: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/script/check_sc_bridges.py --link 2 --sc-tool /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool --system-console /data1/intelFPGA/18.1/quartus/sopc_builder/bin/system-console --jdi /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.jdi --project-dir /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3 --debug-qsys /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/debug_sc_system_v3.qsys --feb-qsys /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/feb_system_v3_pipe.qsys --sopcinfo /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/feb_system_v3_pipe.sopcinfo`
- Return code: `1`
```
FAIL mm_bridge.histogram_statistics_0.uid
  Command '['/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool', '2', 'read', '0x0A900', '1', '--quiet', '--enable-mask', '0x00000004']' returned non-zero exit status 4.
PASS mm_bridge.histogram_statistics_1.uid
  note: not present in current downstream map
  topology: single histogram_statistics_0 instance fed by histogram_ingress_bridge_0
PASS mm_bridge.emulator_mutrig_0.reachability
  sc_addr: 0x08800
  uid_raw: 0x00000001
  version_raw: 0x01000800
FAIL mm_bridge.dbg_mm2runctrl_0.reachability
  Command '['/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool', '2', 'read', '0x08880', '1', '--quiet', '--enable-mask', '0x00000004']' returned non-zero exit status 4.
FAIL upload_mm_bridge.runctl.sc
  Command '['/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool', '2', 'read', '0x0C001', '1', '--quiet', '--enable-mask', '0x00000004']' returned non-zero exit status 4.
FAIL upload_mm_bridge.runctl.jtag
  JTAG runctl META/version mismatch: got 0x1A0221A7, expected 0x1A0201A0
SUMMARY pass=2 fail=4
```

## Read-Only Slave Audit

| Status | Probe | Word addr | Count | RSP | First payload | Detail |
|---|---:|---:|---:|---:|---:|---|
| PASS | `scratch_pad_ram[0..15]` | `0x00000` | 16 | `OK` | `0x00000000` | read-only baseline |
| PASS | `onewire_master_controller_0.CAPABILITY` | `0x04400` | 1 | `OK` | `0x00000006` | SVD has CAPABILITY at offset 0, no UID register |
| PASS | `onewire_master_controller_0.out_of_range` | `0x04408` | 1 | `OK` | `0x00000000` | one word past 0x20-byte SVD aperture |
| PASS | `max10_prog_avmm_0.ID` | `0x04800` | 1 | `OK` | `0x4D312850` | expected match; expected from Qsys IP_ID parameter |
| PASS | `max10_prog_avmm_0.VERSION` | `0x04801` | 1 | `OK` | `0x00020000` | expected match |
| PASS | `max10_prog_avmm_0.STATUS` | `0x04803` | 1 | `OK` | `0x00000001` | ready/busy/fault status |
| PASS | `charge_injection_pulser_0.read_probe` | `0x04C00` | 1 | `OK` | `0x00000000` | write-only SVD; OK/SLVERR/DECERR acceptable |
| FAIL | `firefly_xcvr_ctrl_0[0..13]` | `0x05000` | 14 | `NO_RSP` | `n/a` | read-only audit; no I2C start write issued; sc_tool rc=4 |
| FAIL | `on_die_temp_sense_ctrl.CSR` | `0x05400` | 1 | `NO_RSP` | `n/a` | temperature status; sc_tool rc=4 |
| PASS | `legacy_firefly_bridge.word0` | `0x05800` | 1 | `OK` | `0xCCCCCCCC` | bridge reachability |
| FAIL | `mutrig_cfg_ctrl_0.OPCODE_STATUS` | `0x0FC04` | 1 | `NO_RSP` | `n/a` | cfg CSR reachability; sc_tool rc=4 |

## Scratchpad Baseline

- `0x00000` = `0x00000000`
- `0x00001` = `0x00000000`
- `0x00002` = `0x00000000`
- `0x00003` = `0x00000000`
- `0x00004` = `0x00000000`
- `0x00005` = `0x00000000`
- `0x00006` = `0x00000000`
- `0x00007` = `0x00000000`
- `0x00008` = `0x00000000`
- `0x00009` = `0x00000000`
- `0x0000A` = `0x00000000`
- `0x0000B` = `0x00000000`
- `0x0000C` = `0x00000000`
- `0x0000D` = `0x00000000`
- `0x0000E` = `0x00000000`
- `0x0000F` = `0x00000000`

## Notes

- This phase is read-only except for metadata page-select writes performed by the existing metadata/bridge gate scripts.
- The bridge gate uses `debug_sc_system_v3.qsys` for the SC primary map and the pipe Qsys/SOPC pair for downstream datapath addresses.
- Phase 2 remains destructive and was not run by this script.

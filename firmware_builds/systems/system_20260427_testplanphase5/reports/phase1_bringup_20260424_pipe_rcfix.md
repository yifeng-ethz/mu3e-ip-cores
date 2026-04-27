# Phase 1 Bring-Up Report

- Timestamp: `2026-04-24T15:23:28`
- SC link: `2`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool`
- System Console: `/data1/intelFPGA/18.1/quartus/sopc_builder/bin/system-console`
- JDI: `board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.jdi`
- Project dir: `board_projects/fe_scifi_feb_v3`
- Debug Qsys: `firmware_builds/debug_sc_system_v3.qsys`
- FEB Qsys/SOPC: `firmware_builds/feb_system_v3_pipe.qsys`, `firmware_builds/feb_system_v3_pipe.sopcinfo`
- JTAG cable: `USB-BlasterII [7-2]`
- SC enable mask: `0x00000004`
- Expected JDI hash: `4D764698C3DC3069C118`
- Live design hash: `4D764698C3DC3069C118`
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
    Design hash    4D764698C3DC3069C118
```

### `ls -l /dev/mudaq0`

- Return code: `0`
```
crw-rw-rw- 1 root users 10, 124 Apr 24 14:08 /dev/mudaq0
```

## Image Check

- Status: `PASS`
- Detail: live 4D764698C3DC3069C118 matches JDI 4D764698C3DC3069C118

## Metadata Gate

- Command: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/script/check_ip_metadata.py --link 2 --sc-tool /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool --system-console /data1/intelFPGA/18.1/quartus/sopc_builder/bin/system-console --jdi board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.jdi --project-dir board_projects/fe_scifi_feb_v3 --inventory-out /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/generated/debug_sc_system_v3_inventory_pipe_live.json`
- Return code: `1`
```
FAIL max10_prog_avmm_0 svd=feb_max10_comm/legacy/max10_prog_avmm/max10_prog_avmm.svd exp_ver=0x00020000 qsys_ver=0x00020000 sc_ver=0x00020000 jtag_ver=n/a exp_git=n/a sc_git=n/a jtag_git=n/a
  error: JTAG=Command '['/data1/intelFPGA/18.1/quartus/sopc_builder/bin/system-console', '-cli', '-disable_readline', '-disable_timeout', '--project_dir=board_projects/fe_scifi_feb_v3', '--jdi=board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.jdi', '--script=/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/script/jtag_rw.tcl', '--op', 'read', '--addr', '0x00012004', '--count', '1', '--master-pattern', '*#7-2*/control_path_subsystem_jtag_master.master', '--fallback-pattern', '*control_path_subsystem_jtag_master.master', '--uid-addr', '0x00000400', '--uid-expected', '0x53434842', '--service-tag', 'board_test_meta']' returned non-zero exit status 127.
FAIL sc_hub svd=slow-control_hub/sc_hub.svd exp_ver=0x1A06919E qsys_ver=0x1A06919E sc_ver=0x1A06919E jtag_ver=n/a exp_git=0x05E3EABD sc_git=0x05E3EABD jtag_git=n/a
  error: JTAG=Command '['/data1/intelFPGA/18.1/quartus/sopc_builder/bin/system-console', '-cli', '-disable_readline', '-disable_timeout', '--project_dir=board_projects/fe_scifi_feb_v3', '--jdi=board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.jdi', '--script=/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/script/jtag_rw.tcl', '--op', 'write', '--addr', '0x00000404', '--count', '1', '--master-pattern', '*#7-2*/control_path_subsystem_jtag_master.master', '--fallback-pattern', '*control_path_subsystem_jtag_master.master', '--uid-addr', '0x00000400', '--uid-expected', '0x53434842', '--service-tag', 'board_test_meta', '--data', '0x00000000']' returned non-zero exit status 127.
```

## Bridge Gate

- Command: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/script/check_sc_bridges.py --link 2 --sc-tool /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool --system-console /data1/intelFPGA/18.1/quartus/sopc_builder/bin/system-console --jdi board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.jdi --project-dir board_projects/fe_scifi_feb_v3 --debug-qsys firmware_builds/debug_sc_system_v3.qsys --feb-qsys firmware_builds/feb_system_v3_pipe.qsys --sopcinfo firmware_builds/feb_system_v3_pipe.sopcinfo`
- Return code: `1`
```
Traceback (most recent call last):
  File "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/script/check_sc_bridges.py", line 360, in <module>
    raise SystemExit(main())
  File "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/script/check_sc_bridges.py", line 134, in main
    manifest = collect_manifest(args.debug_qsys.resolve())
  File "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/script/svd_inventory_lib.py", line 267, in collect_manifest
    modules, connections = parse_qsys(qsys_path)
  File "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/script/svd_inventory_lib.py", line 204, in parse_qsys
    root = ET.parse(qsys_path).getroot()
  File "/opt/anaconda3/lib/python3.10/xml/etree/ElementTree.py", line 1222, in parse
    tree.parse(source, parser)
  File "/opt/anaconda3/lib/python3.10/xml/etree/ElementTree.py", line 569, in parse
    source = open(source, "rb")
FileNotFoundError: [Errno 2] No such file or directory: '/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/firmware_builds/debug_sc_system_v3.qsys'
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
| PASS | `firefly_xcvr_ctrl_0[0..13]` | `0x05000` | 14 | `OK` | `0x0000003A` | read-only audit; no I2C start write issued |
| PASS | `on_die_temp_sense_ctrl.CSR` | `0x05400` | 1 | `OK` | `0x00000031` | temperature status |
| PASS | `legacy_firefly_bridge.word0` | `0x05800` | 1 | `OK` | `0xCCCCCCCC` | bridge reachability |
| PASS | `mutrig_cfg_ctrl_0.OPCODE_STATUS` | `0x0FC04` | 1 | `OK` | `0x00000000` | cfg CSR reachability |

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

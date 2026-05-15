# Phase 4 Emulator Type0 Round 3 Board Probe

Date: 2026-05-12
SOF: `firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`
SOF SHA256: `55d1f09361c75e7fdcf5a404e056e5b8cf458a6d38fb024c3d94ebe9590d7b46`
Bench ticket: `codex_phase4_emulator_type0`

## Purpose

Round 3 flashes the Round 2 emulator-type0 FEB image and proves the Phase 4 LOCAL_CMD emulator path on board.

## Key Commands

- Bench claim:
  `python3 /home/yifeng/packages/mu3e_ip_dev/.bench_queue/bench_ticket.py claim --agent codex_phase4_emulator_type0 --minutes 60 --reason "Phase 4 emulator type0 Round 3 FEB flash and CSR histogram board probe"`
- Bench acquire:
  `python3 /home/yifeng/packages/mu3e_ip_dev/.bench_queue/bench_ticket.py acquire --agent codex_phase4_emulator_type0`
- FEB flash:
  `tools/run_script/program_feb.sh firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`
- PCIe recovery:
  `sudo -n /usr/local/sbin/mudaq_recover_pcie`
- SC sanity and board probe:
  `~/.local/bin/swb_ring_lock -- tools/run_script/build/sc_tool ...`
  `~/.local/bin/swb_ring_lock -- python3 firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/script/run_phase4_emutype0_board_probe.py --sc-tool tools/run_script/build/sc_tool --link 2 --output-dir firmware_builds/systems/v3_pretest-260511/reports/phase4_emulator_type0_20260512_130108 --run-seconds 4`
- Bench release:
  `python3 /home/yifeng/packages/mu3e_ip_dev/.bench_queue/bench_ticket.py release --agent codex_phase4_emulator_type0`

## SC Sanity

All three Phase 1 mini-sanity reads responded through `sc_tool` link 2 without `0xEEEEEEEE`.

| Probe | Address | Payload |
|---|---:|---:|
| SC hub UID | `0x0FE80` | `0x53434842` |
| Histogram UID | `0x0A900` | `0x48495354` |
| Run-control UID | `0x0C000` | `0x52434D48` |

## LOCAL_CMD Trace

Opcodes `0x30` and `0x31` were not issued.

| Step | LOCAL_CMD word | LAST_CMD |
|---|---:|---:|
| run-prepare | `0x03088510` | `0x00000010` |
| sync | `0x00000011` | `0x00000011` |
| start-run | `0x00000012` | `0x00000012` |
| end-run | `0x00000013` | `0x00000013` |

## Four-Second Snapshot

| Counter | Before | During/after 4 s | After end-run |
|---|---:|---:|---:|
| `TOTAL_HITS` | 0 | 3,567,472 | 861,772 |
| `BANK_STATUS` | `0x00000000` | `0x00000000` | `0x00000001` |
| `PORT_STATUS` | `0x000000FF` | `0x000200FE` | `0x000200FF` |
| `DROPPED_HITS` | 0 | 0 | 0 |
| `hist_bin[0..63]` sum | 0 | 7,537,459 | 7,535,689 |
| Arb ingress EMU hits | 0 | 261,472,521 | 303,428,928 |
| Arb egress EMU hits | 0 | 261,472,589 | 303,428,928 |
| Arb EMU drops | 0 | 0 | 0 |
| HSS0 frame actual hits | 0 | 35,792,465 | 36,029,984 |
| HSS1 frame actual hits | 0 | 35,814,350 | 36,029,984 |

Histogram `BANK_STATUS` samples during RUNNING were `[0, 0, 1, 1, 0, 0, 1, 1]`.

## Evidence Files

- Log: `firmware_builds/systems/v3_pretest-260511/reports/phase4_emulator_type0_20260512_130108.log`
- Summary: `firmware_builds/systems/v3_pretest-260511/reports/phase4_emulator_type0_20260512_130108/PHASE4_EMUTYPE0_BOARD_PROBE.md`
- Raw JSON: `firmware_builds/systems/v3_pretest-260511/reports/phase4_emulator_type0_20260512_130108/phase4_emutype0_board_probe.json`

## Verdict

PASS for the Phase 4 emulator LOCAL_CMD path: `TOTAL_HITS > 0`, `BANK_STATUS` toggled during RUNNING, and `PORT_STATUS != 0xFF` while hits flowed. The Round 2 timing-risk note still applies to this SOF.

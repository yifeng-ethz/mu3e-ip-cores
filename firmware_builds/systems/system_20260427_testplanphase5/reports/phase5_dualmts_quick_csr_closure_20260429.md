# Phase 5 dual-MTS quick CSR closure

- Date: `2026-04-29`
- Evidence level: `quick CSR`
- Firmware vehicle: `top_nostp_pipe`
- Quartus programming checksum: `0x13DB4566`
- POSIX `cksum`: `0xB4F49A95`
- SOF SHA-256: `136c2d5df538a12713b7138cf775128d633993c3411f9040f4f300d9aae0c8cc`
- Compile log: [`../syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_nostp_pipe_dualmts_debug_20260429.console.log`](../syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_nostp_pipe_dualmts_debug_20260429.console.log)
- Program log: [`../syn/board_projects/fe_scifi_feb_v3/program_top_nostp_pipe_dualmts_debug_20260429.log`](../syn/board_projects/fe_scifi_feb_v3/program_top_nostp_pipe_dualmts_debug_20260429.log)
- HTML report: [`phase5_dualmts_quick_csr_closure_20260429.html`](phase5_dualmts_quick_csr_closure_20260429.html)
- Screenshot assets: [`screenshots/dualmts_20260429/`](screenshots/dualmts_20260429/)
- Plot assets: [`assets/phase5_dualmts_20260429/`](assets/phase5_dualmts_20260429/)

## Firmware gate

The active no-STP FEB build contains `histogram_statistics_v2` `26.1.4.0429` with dual-MTS debug mode `-7`: `debug_1` samples the upper MTS `ts_delta`, `debug_2` samples the lower MTS `ts_delta`, and `debug_3..6` keep upper ring-CAM fill-level debug.

| Step | Result |
|---|---|
| Full Quartus compile | `PASS`: 0 errors / 1731 warnings; elapsed `00:38:47` |
| Fitter | `PASS`: 63,280 / 91,680 ALMs (69%), 83,241 registers, 546 / 1,366 RAM blocks |
| STA | `PASS`: slow 85 C setup WNS `+0.318 ns`, all listed TNS `0.000` |
| FPGA programming | `PASS`: `quartus_pgm` programmed checksum `0x13DB4566` on Arria V JTAG ID `0x02A020DD` |
| PCIe/UIO recovery | `PASS`: `/usr/local/sbin/mudaq_recover_pcie` unloaded/reloaded `mudaq` |

## Quick CSR matrix

These runs are SC-hub CSR/counter evidence only. The HTML report embeds System-Console-style screenshots generated from the captured CSR JSON plus quantitative plots for quick review. They intentionally do not replace final closure evidence, which still requires a live System Console screenshot, raw CSR/bin dump, and a matching authentic generated-system `tb_int` run for the same scenario tuple and firmware checksum.

| Matrix | Result | Notes |
|---|---|---|
| [`phase5_hist_matrix_dualmts_lane4_delay100k_quick_20260429.md`](phase5_hist_matrix_dualmts_lane4_delay100k_quick_20260429.md) | `PASS` | Previously failing lower-half lane4 delay now has histogram `261,966`, MTS `223,972`, zero drops. |
| [`phase5_hist_matrix_dualmts_lane0_delay100k_quick_20260429.md`](phase5_hist_matrix_dualmts_lane0_delay100k_quick_20260429.md) | `PASS` | Upper-half lane0 regression has histogram `252,234`, MTS `218,877`, zero drops. |
| [`phase5_hist_matrix_dualmts_lane4_rate100k_10k_quick_20260429.md`](phase5_hist_matrix_dualmts_lane4_rate100k_10k_quick_20260429.md) | `PASS` | Lane4 100k/10k hist counts `260,420` / `25,393`, ratio `10.26x`, zero drops. |
| [`phase5_hist_matrix_dualmts_emulator_all_delay100k_quick_20260429.md`](phase5_hist_matrix_dualmts_emulator_all_delay100k_quick_20260429.md) | `PASS` | Emulator all-lanes plus lane0..lane7 delay all pass, zero drops. |
| [`phase5_hist_matrix_dualmts_emulator_all_rate100k_10k_quick_20260429.md`](phase5_hist_matrix_dualmts_emulator_all_rate100k_10k_quick_20260429.md) | `PASS` | 18/18 pass; all-scope 100k/10k hist ratio `10.22x`, MTS ratio `10.21x`, zero drops. |
| [`phase5_hist_matrix_dualmts_emulator_all_header1_2_4_quick_20260429.md`](phase5_hist_matrix_dualmts_emulator_all_header1_2_4_quick_20260429.md) | `PASS` | 27/27 pass; all-scope header hit scaling is `2.06x` for 2/header and `4.12x` for 4/header, zero drops. |

## Reviewer notes

Subagent review found no quick-CSR PASS blocker. The reviewer specifically noted that `all` and `lane*` rows are separate 100 ms scope runs and should not be treated as additive, and that the header-mode lane-level ratios are broader than ideal but still compatible with independent quick windows. This evidence is emulator-source only; real and mixed source closure remains pending.

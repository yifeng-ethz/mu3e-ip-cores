# Post-Rewire FEB/SWB Load And Real MuTRiG Scan - 2026-06-04

## Firmware

- FEB build: full `make flow` completed with 0 errors.
- FEB SOF: `firmware_builds/systems/260526-feb-bug012/syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`
- FEB SOF SHA256: `a491653684f7f6eb66071be1e39a65690229ebaa9f3cf183896bc52bc3c1e0b6`
- FEB Quartus programmer checksum: `0x1E378A3B`
- SWB SOF: `firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10/output_files/top.sof`
- SWB SOF SHA256: `9ea0d11e3230831c25121bb26d16774635179afed950abea5997cb807aa90fb7`
- SWB Quartus programmer checksum: `0x31C1C61F`

Programming logs:

- `quartus_pgm_swb.log`
- `quartus_pgm_feb.log`

## Inject Route Evidence

The regenerated FEB system routes the physical FEB inject export directly from
`mutrig_injector_0.inject`. The emulator MuTRiG inject input is tied to a
constant-low `inactive_pulse_source`.

Relevant generated signals:

- `feb_system_v4_data_path_subsystem.vhd`: `mutrig_injector_0 ... coe_inject_pulse => inject_pulse`
- `feb_system_v4_data_path_subsystem.vhd`: `emulator_inject_zero:cso_pulse -> emulator_mutrig_qsys_inst:coe_inject_pulse`
- No generated top-level `inject_aux` export remains.

## Post-Program Recovery

After programming SWB, initial slow-control reads returned `0xffffffff` status and timed out. Recovery was:

1. `pcie_uio_rescan 1172:0004`
2. `sudo -n /usr/local/sbin/mudaq_recover_pcie`

Post-check: `/dev/mudaq0` and `/dev/mudaq0_dmabuf` were present, and a one-word SC read on link 2 returned a matching secondary packet.

Logs:

- `pcie_uio_rescan.log`
- `mudaq_recover_pcie.log`

## MuTRiG Configure

Re-applied the known TDC-test XML configuration:

- SMB3 XML: `board_test_system/trash_bin/good_ribbon_0/config_smb3_tdc.txt`
- SMB5 XML: `board_test_system/trash_bin/good_ribbon_0/config_smb5_tdc.txt`
- ASICs: `0-7`
- Channel enable mask: `0xffffffff`
- TDC-test channel mask: `0xffffffff`
- Channel overrides: `recv_all=1`, `cml_sc=0`
- CML sequence: `0 -> 8 -> 0`
- Result: `SUMMARY pass=24 fail=0`

Artifacts:

- `configure_mutrig_post_rewire_allow_idle.md`
- `configure_mutrig_post_rewire_allow_idle.json`
- `configure_mutrig_post_rewire_allow_idle.log`

## Directed Real MuTRiG Probe

Command used short TDC mode with periodic physical injector:

- interval: `12500`
- pulse high: `5`
- multiplicity: `1`
- dwell: `2 s`
- LVDS soft reset: yes

Result:

| Path | Occupancy | Sum | Frame Status | CRC Delta |
|---|---:|---:|---|---|
| Type0 | `254/256` | `1367157` | all `0x31` | all `0` |
| Type1 up | `128/256` | `1279990` | all `0x31` | all `0` |
| Type1 down | `126/256` | `1259255` | all `0x31` | all `0` |
| Type1 combined | `254/256` | `2539245` | all `0x31` | all `0` |

Artifact:

- `probe_periodic_20260604_151409/post_rewire_periodic_12500_high5.json`

## Rate Scan

Artifact directory:

- `type0_type1_scan_20260604_151520/`

Summary:

| Interval | Requested Hz | Type0 Occupancy | Type0 Sum | Type1 Occupancy | Type1 Sum | Type1 Up | Type1 Down |
|---:|---:|---:|---:|---:|---:|---:|---:|
| `50000` | `2500.0` | `254/256` | `341738` | `254/256` | `633364` | `128` | `126` |
| `12500` | `10000.0` | `254/256` | `1367914` | `254/256` | `2539244` | `128` | `126` |
| `5000` | `25000.0` | `254/256` | `3416768` | `254/256` | `6344799` | `128` | `126` |

Data outputs:

- `real_mutrig_type0_type1_scan.json`
- `real_mutrig_type0_type1_scan_summary.csv`
- `real_mutrig_type0_type1_scan_channels.csv`

## Requested Style Plots

Only the two main requested PNG outputs are linked here:

- Type1 delay, Image #1 style:
  [real_mutrig_type1_delay_asic0_up_4panel_dislin.png](style_plots_20260604/real_mutrig_type1_delay_asic0_up_4panel_dislin.png)
- Type0/Type1 rate histograms, Image #2 style:
  [real_mutrig_type0_type1_rate_histograms_dislin.png](style_plots_20260604/real_mutrig_type0_type1_rate_histograms_dislin.png)

## Type0 Drop Debug

The Type0 left-column undercounts are not caused by the ping-pong readout
interval being too short. A counter-only repeat of the three rate points shows
the same fixed per-channel ratio buckets while the histogram drop counter is
active and `OVERFLOW_COUNT` remains zero.

| Interval | Requested Hz | Type0 Sum | Ratio Buckets | DROPPED_HITS | LAST_INTERVAL_DROPPED_HITS | OVERFLOW |
|---:|---:|---:|---|---:|---:|---:|
| `50000` | `2500.0` | `341827` | `0:2, 0.25:54, 0.5:152, 0.75:6, 1.0:42` | `276974` | `293173` | `0` |
| `12500` | `10000.0` | `1368139` | `0:2, 0.25:54, 0.5:152, 0.75:6, 1.0:42` | `1041115` | `1048575` | `0` |
| `5000` | `25000.0` | `3418976` | `0:2, 0.25:54, 0.5:152, 0.75:6, 1.0:42` | `1048575` | `1048575` | `0` |

Low-level artifacts:

- [type0_counter_sweep_2500_10000_25000hz.json](stp_type0_debug_20260604/type0_counter_sweep_2500_10000_25000hz.json)
- [type0_stp_directed_interval12500_summary.json](stp_type0_debug_20260604/type0_stp_directed_interval12500_summary.json)
- [quartus_stp_mts_debug_type0_interval12500.log](stp_type0_debug_20260604/quartus_stp_mts_debug_type0_interval12500.log)
- [quartus_stp_lvds_decoded_type0_interval12500.log](stp_type0_debug_20260604/quartus_stp_lvds_decoded_type0_interval12500.log)

SignalTap runtime trigger attempts did not capture a valid Type0 trigger in the
existing STP. The useful evidence from the same directed windows is the CSR
drop snapshot: drops scale with the missing Type0 population, while frame CRCs
stay clean and Type1 is flat. I did not flush CML after this result; the
signature is in the histogram ingress/coalescer path, not the physical MuTRiG
link.

## Histogram Direct Sim And 32-Bit Rebuild

The directed histogram IP simulation reproduces the Type0 drop with the old
small ingress sizing and removes it with the 32-bit/default rebuild sizing:

| Configuration | Type0 accepts | Type0 drops | Coalescer status | Result |
|---|---:|---:|---|---|
| old `MAX_COUNT_BITS=20`, `FIFO_ADDR_WIDTH=2`, `COAL_QUEUE_DEPTH=4` | `1536` | `978` | `0x00000100` | reproduced ingress FIFO loss |
| fixed `MAX_COUNT_BITS=32`, `FIFO_ADDR_WIDTH=5`, `COAL_QUEUE_DEPTH=160` | `1536` | `0` | `0x00000100` | no drops |

The existing direct Type0/Type1 regression also passes with the fixed defaults:
Type0 reports `dropped=0`, Type1 up/down rate and delay each report
`delta_total=256`, and UVM reports `0` errors and `0` fatals.

Main outputs:

- [old 20-bit/fifo4/q4 Type0 stress log](hist_direct_sim_20260604/hist_type0_interval_stress_old_20b_fifo4_q4_expect_drop_seed11.log)
- [fixed 32-bit/fifo32/q160 Type0 stress log](hist_direct_sim_20260604/hist_type0_interval_stress_fixed_32b_fifo32_q160_seed11.log)
- [fixed-default direct Type0/Type1 regression log](hist_direct_sim_20260604/hist_v3_direct_input_fixed_defaults_seed7.log)
- [FEB 32-bit histogram rebuild transcript](hist_direct_sim_20260604/feb_make_flow_hist_32b_20260604.log)

The regenerated FEB subsystem maps `histogram_statistics_0` with
`MAX_COUNT_BITS=32`, `FIFO_ADDR_WIDTH=5`, and `COAL_QUEUE_DEPTH=160`.
The compile produced `top.sof` with SHA256
`af19af76ef175ca2aa4711fa0e6ceff9d6139d7e55b9adb57904cce6fdbfbe07`.
I did not load this new image because STA still reports setup timing not met in
the LVDS `pll_sclk` domain: worst setup slack is `-6.063 ns` at the worst slow
corner and `-0.473 ns` at the other failing slow corner.

Timing follow-up on 2026-06-05 kept the 32-bit counters and FIFO depth 32, but
returned `COAL_QUEUE_DEPTH` to `4`. The directed stress still passes with zero
drops and `coal_status=0x00000100`, matching the evidence that the coalescer
queue was not the bottleneck.

Main outputs:

- [default q4 Type0 stress log](hist_direct_sim_20260605/hist_type0_interval_stress_default_q4_seed11.log)
- [default q4 direct Type0/Type1 regression log](hist_direct_sim_20260605/hist_v3_direct_input_default_q4_seed7.log)
- [FEB q4 timing-fix rebuild transcript](hist_direct_sim_20260605/feb_make_flow_hist_q4_timingfix_20260605.log)

The q4 rebuild completed full `make flow` successfully with 0 errors. Fitter
completed on Arria V `5AGXBA7D4F31C5` at 77% ALM and 77% RAM utilization.
TimeQuest closed timing with worst setup slack `+0.102 ns`, worst hold slack
`+0.245 ns`, minimum pulse width slack `+0.160 ns`, and TNS `0.000`. The new
FEB SOF SHA256 is
`6ec67bec276c42a2f852821c71c057e718b4cd62efbeca92d659e994abdfa938`.

## 2026-06-05 Timing-Fix Load And JTAG Smoke

The timing-fix FEB SOF and the SWB SOF were loaded after the successful q4
compile:

- [SWB programmer log](quartus_pgm_swb_20260605.log)
- [FEB programmer log](quartus_pgm_feb_20260605.log)

Normal SWB slow-control scan could not be rerun after the load because the PCIe
endpoint was left bound to `uio_pci_generic`, `/dev/mudaq0` and
`/dev/mudaq0_dmabuf` were absent, and `sc_tool --device /dev/uio0` failed to
map the needed BAR region. The non-privileged recovery path could rescan to
UIO, but could not complete the `mudaq` device recovery in this shell.

Recovery artifacts:

- [pcie_uio_rescan_20260605.log](pcie_uio_rescan_20260605.log)
- [mudaq_recover_pcie_20260605.log](mudaq_recover_pcie_20260605.log)
- [sc_read_uio0_hist_uid_20260605.log](sc_read_uio0_hist_uid_20260605.log)

The FEB-side JTAG masters were usable, so the post-load smoke was run through
System Console instead. The datapath master read `HIST=0x48495354`,
`MINJ=0x4D494E4A`, and `LVDS=0x4C564453`; the run-control master read
`RCMH=0x52434D48`.

JTAG artifacts:

- [jtag_hist_probe_20260605.log](jtag_hist_probe_20260605.log)
- [jtag_runctl_probe_20260605.log](jtag_runctl_probe_20260605.log)
- [jtag_real_mutrig_smoke_20260605.log](jtag_real_mutrig_smoke_20260605.log)
- [jtag_real_mutrig_smoke_20260605_counts.csv](jtag_real_mutrig_smoke_20260605_counts.csv)
- [jtag_real_mutrig_smoke_lvdsreset_20260605.log](jtag_real_mutrig_smoke_lvdsreset_20260605.log)
- [jtag_real_mutrig_smoke_lvdsreset_20260605_counts.csv](jtag_real_mutrig_smoke_lvdsreset_20260605_counts.csv)

One 10 kHz requested-rate JTAG smoke was run for Type0, Type1-up, and
Type1-down. Histogram drops stayed at zero in all nonzero windows, and
`COAL_STATUS` stayed `0x00000100`, matching the q4 direct-sim result that the
histogram ingress no longer drops the real-MuTRiG burst.

| Window | LVDS reset | Occupied bins | Bin sum | DROPPED_HITS | LAST_INTERVAL_DROPPED_HITS | COAL_STATUS |
|---|---|---:|---:|---:|---:|---|
| Type0 | no | `96/256` | `960000` | `0` | `0` | `0x00000100` |
| Type1 up | no | `32/256` | `320000` | `0` | `0` | `0x00000100` |
| Type1 down | no | `64/256` | `640000` | `0` | `0` | `0x00000100` |
| Type0 | yes | `64/256` | `640000` | `0` | `0` | `0x00000100` |
| Type1 up | yes | `0/256` | `0` | `0` | `0` | `0x00000000` |
| Type1 down | yes | `64/256` | `640000` | `0` | `0` | `0x00000100` |

The reduced occupancy after today’s reload is a link/physical-state symptom,
not a histogram ingress symptom. Before and after LVDS soft reset, both
`PHY_LOSN_STATUS` and `PHY_DPALOCK_STATUS` were `0x00000135`, so only the
locked subset of lanes could contribute. The old Type0 undercount signature
was drops in the histogram ingress with clean link CRCs; the timing-fix image
now reports zero histogram drops on the lanes that are actually locked.

## 2026-06-05 Passwordless SWB Reload Rate Redo

After passwordless SWB reload and `mudaq` recovery, the Type0/Type1 rate plot
was rerun through the normal `/dev/mudaq0` slow-control path. The first retry
exposed a software sequencing issue: `runctl_mgmt_host.STATUS` is a host-FSM
diagnostic word, so valid accepted START commands can read back as
`0x00000302` rather than low-nibble `0x3`. The scan helper now accepts START
when `LAST_CMD[7:0] == 0x12` and the host command path is idle.

Main outputs:

- [Type0/Type1 rate contact sheet](type0_type1_scan_20260605_passwordless_retry/real_mutrig_type0_type1_rate_histograms_dislin.png)
- [Type0/Type1 rate contact sheet PDF](type0_type1_scan_20260605_passwordless_retry/real_mutrig_type0_type1_rate_histograms_dislin.pdf)
- [rate summary CSV](type0_type1_scan_20260605_passwordless_retry/real_mutrig_type0_type1_scan_summary.csv)
- [raw scan JSON](type0_type1_scan_20260605_passwordless_retry/real_mutrig_type0_type1_scan.json)
- [scan log](type0_type1_scan_20260605_passwordless_retry/feb_real_mutrig_type0_type1_scan.log)

All populated bins match the red requested-rate reference exactly:

| Requested rate | Type0 populated bins | Type0 bin count | Type1 populated bins | Type1 bin count |
|---:|---:|---:|---:|---:|
| `2500 Hz` | `64` | `2500` | `64` | `2500` |
| `10000 Hz` | `64` | `10000` | `64` | `10000` |
| `25000 Hz` | `64` | `25000` | `64` | `25000` |

The populated range is bins `128..191` for both Type0 and Type1. Final
readback still shows `PHY_LOSN_STATUS=0x00000135` and
`PHY_DPALOCK_STATUS=0x00000135`, so the reduced 64-bin occupancy is the current
LVDS physical-lock subset, not a histogram-rate loss. The board was left quiet
with `inj_mode=0x00000000` and `runctl_last_cmd=0x00000013`.

## 2026-06-05 All-MuTRiG Rate, Periodic Plateau, And Header-Sync Lock

The known-good SMB3/SMB5 TDC-test XML was reloaded for ASICs `0..7` with
`recv_all=1`, `cml_sc=0`, `channel_enable_mask=0xffffffff`,
`tdctest_channel_mask=0xffffffff`, and CML flush `0 -> 8 -> 0`. The all-ASIC
configuration passed `24/24` operations. After an SC burst-read retry with PCIe
recovery, the all-MuTRiG periodic rate scan was clean.

Main outputs:

- [all-MuTRiG Type0/Type1 rate contact sheet](all_mutrig_header_sync_lock_20260605/main_dislin_outputs_20260605/real_mutrig_type0_type1_rate_histograms_dislin.png)
- [all-MuTRiG Type1 periodic delay plateau](all_mutrig_header_sync_lock_20260605/main_dislin_outputs_20260605/real_mutrig_type1_periodic_delay_plateau_dislin.png)
- [ASIC1 header-sync Type1 delay lock plot](all_mutrig_header_sync_lock_20260605/main_dislin_outputs_20260605/real_mutrig_header_sync_delay_asic1_hch1_dislin.png)
- [all-MuTRiG rate summary CSV](all_mutrig_header_sync_lock_20260605/type0_type1_scan_all_mutrig_periodic_20260605_clean_retry/real_mutrig_type0_type1_scan_summary.csv)
- [periodic plateau summary CSV](all_mutrig_header_sync_lock_20260605/type1_periodic_delay_plateau_all_mutrig_20260605/real_mutrig_type1_periodic_delay_plateau_summary.csv)
- [ASIC1 header-sync summary CSV](all_mutrig_header_sync_lock_20260605/header_sync_delay_hch1_asic1_only_20260605/real_mutrig_type1_header_sync_delay_hch1_asic1_only_summary.csv)

The all-MuTRiG rate scan populated `191/256` bins at each requested rate.
The reproducible missing bins are `0..31`, `64..95`, and `230`; populated bins
sit on the red requested-rate line for both Type0 and Type1. This is now a
physical/channel availability pattern, not a histogram drop or ping-pong
interval artifact.

Periodic Type1 delay used `LEFT=0`, `RIGHT=1024`, and `BIN_WIDTH=4`. All three
periodic points occupied all `256/256` delay bins, spanning `2..1022` cycles.
The strict `[0,1000]` fraction is `97.75%..97.79%`; the remainder is the six
4-cycle bin centers at `1002..1022`, so the observed shape is the expected
periodic plateau over the frame interval.

For header-sync, `HEADER_CH=0` produced no traffic. A directed header-channel
sweep showed live mode-1 traffic for `HEADER_CH=1,3,4,5,6,7`, while values like
`32/64/96/...` read back as zero. The PLL-lock delay plot therefore isolates
ASIC1 by disabling TDC-test on all ASICs, enabling only ASIC1, and using
`HEADER_CH=1`. The four header-delay points (`100,300,500,700`) have p05-p95
width `100` cycles and `99.988%..99.999%` of counts inside `[0,1000]`. The
peak moves with header delay (`922,722,438,238` cycles), giving the expected
header-sync narrow cluster rather than the periodic plateau.

After the isolated ASIC1 check, the all-ASIC TDC-test XML/mask was restored and
the restore passed `24/24` CML start/flush/final operations.

## 2026-06-05 ASIC0/ASIC2 Directed Liveness And Recovery

ASIC0 and ASIC2 were rechecked because the all-MuTRiG rate scan missed bins
`0..31` and `64..95`. The baseline frame-receiver read showed a split symptom:
ASIC0 was at `word0=0x00000001` / status `0`, while ASIC2 was already at
`word0=0x31000001` / status `49`. After reloading the known-good SMB3/SMB5 TDC
XMLs, using CML flush `0 -> 8 -> 0`, and issuing an LVDS soft reset, both ASICs
produce real Type0 and Type1 histogram hits.

Evidence:

- [baseline CSR/frame read log](asic0_asic2_alive_debug_20260605/baseline_csr_20260605_143242.log)
- [ASIC1 isolated control JSON](asic0_asic2_alive_debug_20260605/asic1_only_periodic_control.json)
- [ASIC0 isolated recovery JSON](asic0_asic2_alive_debug_20260605/asic0_only_periodic_default_cmlflush_lvdsreset.json)
- [ASIC2 isolated recovery JSON](asic0_asic2_alive_debug_20260605/asic2_only_periodic_default_cmlflush_lvdsreset.json)
- [all-ASIC low-rate Type0 JSON](asic0_asic2_alive_debug_20260605/all_mutrig_type0_lowrate_after_asic0_refresh_default_lvdsreset.json)
- [all-ASIC low-rate Type1 JSON](asic0_asic2_alive_debug_20260605/all_mutrig_type1_lowrate_after_asic0_refresh_default_lvdsreset.json)

| Test point | Path | ASIC0 occupied | ASIC2 occupied | Global occupancy | Note |
|---|---|---:|---:|---:|---|
| ASIC0 isolated, 10 kHz | Type0 | `32/32` | `0/32` | `33/256` | bins `0..31` full, small residual at bin `118` |
| ASIC0 isolated, 10 kHz | Type1 combined | `32/32` | `0/32` | `33/256` | bins `0..31` full, small residual at bin `118` |
| ASIC2 isolated, 10 kHz | Type0 | `0/32` | `32/32` | `33/256` | bins `64..95` full, small residual at bin `118` |
| ASIC2 isolated, 10 kHz | Type1 combined | `0/32` | `32/32` | `33/256` | bins `64..95` full, small residual at bin `118` |
| All ASICs, 2.5 kHz | Type0 | `32/32` | `32/32` | `255/256` | only ASIC7 channel 6 missing |
| All ASICs, 2.5 kHz | Type1 combined | `32/32` | `32/32` | `256/256` | full Type1 liveness |

At the all-ASIC 10 kHz point, one 32-channel ASIC window can still disappear
depending on the latest per-ASIC refresh order; after refreshing ASIC0, ASIC0
was present but ASIC2 dropped. Since both ASICs are alive in isolated mode and
both are present together at 2.5 kHz, the 10 kHz all-source missing-window
signature is a shared-rate/path symptom, not dead ASIC0 or ASIC2 silicon.

## 2026-06-05 Filled-Bin Rate And Per-ASIC Delay Plots

The refreshed plots below use filled step/shaded histograms instead of separate
thin bars, so adjacent occupied bins are rendered as one continuous piece and
only real holes remain visible.

Main outputs only:

- [Type0/Type1 rate scan, filled bins](all_mutrig_per_asic_delay_rate_20260605/main_dislin_outputs_20260605/real_mutrig_type0_type1_rate_histograms_filled_dislin.png)
- [per-ASIC periodic Type1 delay, 100 kHz per channel](all_mutrig_per_asic_delay_rate_20260605/main_dislin_outputs_20260605/real_mutrig_per_asic_periodic_delay_filled_dislin.png)
- [per-ASIC header-sync Type1 delay, 1 pulse per frame](all_mutrig_per_asic_delay_rate_20260605/main_dislin_outputs_20260605/real_mutrig_per_asic_headersync_delay_filled_dislin.png)

The all-ASIC rate scan now has Type0 and Type1 `255/256` nonzero bins at
requested rates `2.5 kHz`, `10 kHz`, and `25 kHz`. The remaining zero bin is
`230` in both paths at all three rates. Type1 bin `245` is below `90%` of the
requested count at `2.5 kHz` and `10 kHz`, then recovers at `25 kHz`.

The per-ASIC periodic delay scan used isolated ASIC TDC-test injection at
`100 kHz` per channel. ASIC1/2/4/6/7 show the expected broad periodic plateau
mostly inside `[0,1000]`, with strict in-window fractions from `97.70%` to
`97.87%`. ASIC0 is alive but sparse in this dwell (`64` total hits), and ASIC3
and ASIC5 have lower totals than the stronger ASICs.

The per-ASIC header-sync scan used one pulse per frame. ASIC1/2/4/6/7 produce
compact locked peaks inside `[0,1000]` with p05-p95 widths near `96..104`
cycles for ASIC1/2/4/6/7, while ASIC0 remains sparse and ASIC3/5 remain broad.

## Final Quiet State

Final readback after the filled-bin per-ASIC delay and Type0/Type1 rate scans:

- `inj_mode=0x00000000`
- `inj_header_delay=0x0000012c`
- `inj_header_interval=0x00000001`
- `inj_multiplicity=0x00000001`
- `inj_header_ch=0x00000001`
- `inj_pulse_interval=0x00001388`
- `inj_pulse_high=0x00000005`
- `runctl_status=0x00000003`
- `runctl_last_cmd=0x00000013`
- `hist_uid=0x48495354`
- `lvds_phy_losn=0x000001ff`
- `lvds_phy_dpa_locked=0x000000ca`
- `lvds_lane_go=0x000001ff`
- `frame_receiver[0..7].word0=0x31000001`
- [final CSR readback log](all_mutrig_per_asic_delay_rate_20260605/final_csr_after_filled_plot_scans_20260605.log)

The board was left with the injector disabled, run-control terminated, all
frame receivers in short-hit mode, and the all-ASIC TDC-test mask restored.

## Conclusion

The previous real-MuTRiG no-hit condition is fixed by preserving the physical
inject pulse timing/level and routing the FEB inject pins 1:1 from
`mutrig_injector_0`. Short TDC mode now produces Type0 and Type1 histogram hits
on the real MuTRiG path with clean frame CRC deltas.

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

## Final Quiet State

Final readback after the scan:

- `inj_mode=0x00000000`
- `inj_pulse_interval=0x00001388`
- `inj_pulse_high=0x00000005`
- `runctl_status=0x00000003`
- `runctl_last_cmd=0x00000013`

The board was left with the injector disabled and run-control terminated.

## Conclusion

The previous real-MuTRiG no-hit condition is fixed by preserving the physical
inject pulse timing/level and routing the FEB inject pins 1:1 from
`mutrig_injector_0`. Short TDC mode now produces Type0 and Type1 histogram hits
on the real MuTRiG path with clean frame CRC deltas.

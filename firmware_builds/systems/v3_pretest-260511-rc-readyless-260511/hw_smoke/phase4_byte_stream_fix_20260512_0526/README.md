# Phase 4 Byte-Stream Fix Hardware Smoke 2026-05-12

## Image

- SOF:
  `syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`
- SOF SHA-256:
  `c8239ef1ab2f0bc21da91e0de41ca4c452531cb363677c43c9fb3f7930712dcd`
- RBF SHA-256:
  `5dc37ae000a5e37a677f8dcae0a62e769416675342a8409a88f86807e4951bd1`
- Compile log:
  `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_20260512_0445_byte_stream_fix.console.log`

## Hardware Sequence

1. Programmed the FEB with `tools/run_script/program_feb.sh`; `program_feb.log`
   shows `quartus_pgm` success and the mandatory 20 s settle.
2. Recovered PCIe with `sudo -n /usr/local/sbin/mudaq_recover_pcie`;
   `mudaq_recover_pcie.log` unloads and reloads `mudaq`.
3. Took a pre-run JTAG snapshot in `snapshot_pre.log/json`.
4. Configured emulator lane 0, histogram post selector, injector, and local
   run-control by JTAG in `jtag_setup_start.log`.
5. Sampled JTAG and SC-visible counters while running.
6. Ended the run by JTAG in `jtag_teardown_end.log` and released the bench
   ticket.

## Positive Evidence

- `jtag_setup_start.log`: run-control writes
  `{0x00FFFF30, 0x00000240, 0x00FFFF31, 0x01023510, 0x00000011, 0x00000012}`;
  `runctl_last_cmd=0x00020012`.
- `sc_runctl_last_cmd.log`: `0x00020012`.
- `sc_runctl_rx_cmd_count.log`: `0x00000006`.
- `hist_rate_dump.log`: after the 1.1 s rate-profile wait,
  `underflow_count 0`, `overflow_count 0`, `total_hits 836042`,
  `dropped_hits 0`, and `last_interval_total_hits 7995716`.
- `hist_rate_bins.csv`: sum `7995716`, active bins `1`, bin `0` count
  `7995716`.
- `sc_hist_after_rate_0x0A908_len11.log`: `TOTAL_HITS=0x001C9282`,
  `DROPPED_HITS=0`, `LAST_INT_HITS=0x007A0144`, `UNDERFLOW=0`,
  `OVERFLOW=0`.

## Remaining Blocker

- This run selected `hist_snoop_source=post`; `hist_rate_dump.log` reports
  `live_select_post 1` and `post_hit_filter_enabled 0`. Treat the positive
  histogram result as post-selected word-counter activity, not legal-hit
  conservation proof.
- `sc_hss0_after_hist_rate.log`: frame assembly declared/actual/missing
  counters are all zero.
- `sc_hss1_after_hist_rate.log`: frame assembly declared/actual/missing
  counters are all zero.
- Follow-up evidence in
  `../phase4_pre_hss_probe_20260512_0541/` selected `hist_snoop_source=pre`;
  `hist_pre_rate_dump.log` and `hist_pre_rate_bins.csv` both stayed at zero.

## Verdict

`BYTE_STREAM_ENABLE=true` fixes the captured byte-stream boundary:
post-selected histogram word-counter activity is present on hardware with zero
drops, underflow, and overflow in the rate profile. Phase 4 is not closed. The
next known-good/unknown gap is upstream of
`histogram_ingress_bridge_0.pre_in` / `mts_preprocessor_0.hit_type1_out`;
continue with decoded-lane, mutrig-datapath, MTS, and histogram-pre SignalTap
or synchronized CSR snapshots. The prepared
`../../signaltap/phase4_pre_hss_gap.stp` source is Node-Finder clean
(`76/76` probes found) but not yet compiled into a loadable image.

# Phase 4 Pre-HSS Boundary Probe 2026-05-12

Purpose: test whether the byte-stream-fix image's post-selected histogram
activity is legal pre-HSS hit traffic.

## Image and Setup

- SOF:
  `syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`
- SOF SHA-256:
  `c8239ef1ab2f0bc21da91e0de41ca4c452531cb363677c43c9fb3f7930712dcd`
- Bench ticket: `codex_v3_pre_hss_probe`, released after teardown.
- Programming: `program_feb.log` shows Quartus programmer success and the
  mandatory 20 s FEB settle.
- PCIe recovery: `mudaq_recover_pcie.log` unloads and reloads `mudaq`.
- JTAG setup: `jtag_setup_pre_start.log` uses `hist_snoop_source=pre`,
  one active emulator lane, and reaches `runctl_last_cmd=0x00020012`.

## Result

- `hist_pre_rate_dump.log`: `live_select_post 0`; all histogram stats remain
  zero after the 1.1 s wait.
- `hist_pre_rate_bins.csv`: `sum(count)=0`.
- `sc_hist_pre_after_rate_0x0A908_len11.log`: `TOTAL_HITS=0`,
  `DROPPED_HITS=0`, `LAST_INT_HITS=0`, `UNDERFLOW=0`, `OVERFLOW=0`,
  `PORT_STATUS=0x000000FF`.
- `sc_hss0_after_pre_rate_0x0B400_len8.log` and
  `sc_hss1_after_pre_rate_0x0B410_len8.log`: HSS declared/actual/missing
  counters remain zero.
- `sc_rbcam_*_after_pre_rate_*.log`: rbCAM CSRs respond with UID `0x5242434D`,
  but the visible push/pop/error-style payload words remain zero.
- `jtag_teardown_pre_stop.log`: clean end-run, `runctl_last_cmd=0x00020013`.

## Interpretation

The earlier post-selected histogram count is word-counter evidence, not a
hit-conservation proof. With the histogram bridge selected to the pre-HSS tap,
the histogram, MTS-visible totals, rbCAM payload counters, and HSS counters all
stay at zero. The next hardware-first gap is upstream of
`histogram_ingress_bridge_0.pre_in` / `mts_preprocessor_0.hit_type1_out`.

The focused SignalTap source for that gap is
`../../signaltap/phase4_pre_hss_gap.stp`. Node Finder report
`../../signaltap/phase4_pre_hss_gap_nodes.md` shows `76/76` probes found and
`0` missing; the STP still needs Quartus import/compile before hardware use.

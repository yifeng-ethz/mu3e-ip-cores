# FEB to SWB Cosim Usage

Run the sanity test from this directory:

```sh
make run_COSIM_SANITY
```

The target performs three steps:

1. Syntax-checks the cosim SV/UVM packages.
2. Runs the dualport FEB/SWB corun with periodic all-channel emulation.
3. Builds `REPORT/sanity_1ms/sanity_1ms_summary.md`.

The sanity configuration is:

- `SOURCE_MODE=periodic`
- `ASIC_COUNT=8`
- `HIT_PERIOD_8NS=5000`
- `RUN_WINDOW_8NS=125000`
- Expected hits: 6400

That window creates 25 periodic samples per channel across the 8 virtual
MuTRiG ASICs, with 32 channels per ASIC, for exactly 6400 generated hits. The
current dualport corun wrapper maps the 8 ASIC sources onto the two active SWB
data lanes used by the reference SWB UVM wrapper.

Primary outputs:

- `REPORT/sanity_1ms/run_swb_corun.log`
- `REPORT/sanity_1ms/feb_swb_trace_debug_summary.txt`
- `REPORT/sanity_1ms/feb_swb_lifetime_hist_stats.csv`
- `REPORT/sanity_1ms/sanity_1ms_summary.md`
- `REPORT/sanity_1ms/feb_swb_feb_egress_waveform.csv`
- `REPORT/sanity_1ms/feb_swb_swb_ingress_waveform.csv`

The waveform CSVs are raw cycle captures. The parsed trace CSVs remain valid
beat-only so the existing lineage analyzer can decode frames and hit words.

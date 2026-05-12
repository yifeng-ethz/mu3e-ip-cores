# FEB to SWB Cosim Usage

## RN.BASIC 208-row sweep

Run the complete RN.BASIC sim sweep from this directory:

```sh
make run_BASIC PARALLEL=30
```

Useful scoped runs:

```sh
make run_BASIC ROW=RN.BASIC.001
make run_BASIC ROW=1
make run_BASIC SLICE=1 PARALLEL=30
make run_BASIC COLLECT_ONLY=1
make run_BASIC DRY_RUN=1
```

`scripts/rn_basic_cosim.py` parses
`../v3_pretest-260511/doc/TEST_BASIC.md`, stamps each row into
`REPORT/RN.BASIC.NNN/row_config.json`, precompiles the shared Questa corun
once, and dispatches up to 30 row runs per batch.  Use `WORK_ROOT=<scratch>`
when the raw Questa CSVs will not fit under `cosim/REPORT`; the runner still
writes the requested checkpoint evidence back to `REPORT/RN.BASIC.NNN/`.
Intermediate raw files are truncated after collection by default.  Set
`KEEP_RAW_TRACES=1` only when there is enough scratch space to retain them.
Each row receives row-specific `+RN_BASIC_*` plusargs plus the source-mode
controls available in the FEB/SWB corun wrapper.  The summary is written to:

```text
REPORT/RN.BASIC.208_summary.json
```

Each row evidence directory contains the three condition checkpoints:

- `rate_csr_dump.json`: TERM counter dump keyed by
  `arb_hit_type0_supercore`, `histogram_statistics_v2`, `ring_buffer_cam`,
  `mutrig_frame_deassembly`, `feb_frame_assembly`, `mutrig_cfg_ctrl`, and
  `mts_preprocessor`; includes `theoretical_hits`
- `delay_hist_bin_a.json` and `delay_hist_bin_b.json`: dual-bank histogram
  bin readings derived from the row-filtered hit trace
- `delay_scoreboard.json`: `true_ts[]`, `measured_ts[]`, `delay_ns[]`, and
  delay statistics from emulator truth to post-rbCAM observation
- `delay_plot.svg`: measured delay versus emulator true timestamp
- `rdma_rxbuffer.bin`: row-filtered 64-bit DMA hit records as raw bytes
- `rdma_rxbuffer_summary.json`: byte count, record count, first/last records,
  and average record size

PASS rules follow `TEST_BASIC.md`: rate must be within 5 percent of the row
math model with zero reported error counters, the two hist banks must sum to
the rate CSR count within +/-8 hits and have `delay_stddev_ns < 100`, and the
RDMA record count must match the rate CSR count within +/-8 hits.

The current corun publishes full source traces and the RN.BASIC collector
filters by `lane_mask` and `channel_mask` when stamping per-row evidence.  The
row config records both the TEST_BASIC mode and the effective corun source
mode so follow-up can distinguish planner coverage from unsupported source
knobs in the underlying sim wrapper.

## Sanity run

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

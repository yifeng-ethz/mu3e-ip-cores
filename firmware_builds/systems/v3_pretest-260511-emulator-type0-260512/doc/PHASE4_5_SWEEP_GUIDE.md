# Phase 4.5 Sweep Operator Guide

Date: 2026-05-12

## Purpose

One-page operator guide for `scripts/cotest/phase4_5_sweep.py` (relative to
mu3e-ip-cores repo root), the single
integrated TEST_PLAN section 4.5 sweep runner for the FEB v3
emulator-type0 build (commit a710b11a working baseline).

Everything the downstream test agent needs is in one script. No external
plan JSON, no separate plotter, no separate table regenerator. The agent
flashes the SOF and runs one command.

## What it does

For every row in the 32-row sweep matrix, the script

1. Programs `arb_hit_type0_supercore` admit `lane_mask`.
2. Programs `emulator_mutrig` `channel_mask`, `rate_88fp`, `hit_mode`.
3. Programs `histogram_statistics_v2` `LEFT=0 RIGHT=255 BIN_WIDTH=1
   KEY_LOC=channel_post`, and `INTERVAL_CFG = INTERVAL_CFG_NEVER_FIRE`
   so the LIVE current-interval counter accumulates the full run
   (see Live-vs-Stable Counter Contract below).
4. Drains the `runctl_mgmt_host_0` LOG FIFO.
5. Writes a self-defined run_number `0xAA0000 | row_idx` to
   `CSR_RUN_NUMBER`.
6. Drives the LOCAL_CMD opcode sequence `0x10 -> 0x11 -> 0x12 ->
   (wait interval_seconds) -> 0x13`.
7. Polls `CSR_STATUS` until `host_state==IDLE` (timeout 2 s, falls back
   to wall-clock).
8. Drains the LOG FIFO and decodes the 128-bit entries.
9. Reads all 256 histogram bins ONE WORD AT A TIME.
10. Snapshots every counter (arb, hist, ring, mts, frame, runctl) and
    captures `csr13 TOTAL_HITS` (LIVE), `csr17 LAST_INTERVAL_TOTAL_HITS`
    (STABLE), and `hist_bin_sum` for cross-validation.
11. Computes a structured verdict per row (`total_hits_csr13` is the
    authoritative full-run total; `hist_bin_sum_matches_csr13` is a
    warning-only cross-check with an 8-hit pipeline tolerance).
12. Renders a 2-panel matplotlib plot.
13. Regenerates `doc/PHASE4_5_SWEEP_TABLE.md`.

## Live-vs-Stable Counter Contract

`histogram_statistics_v2_hw.tcl` documents this contract verbatim:

> *"TOTAL_HITS and DROPPED_HITS are LIVE CURRENT-INTERVAL counters.
> LAST_INTERVAL_TOTAL_HITS and LAST_INTERVAL_DROPPED_HITS latch the
> completed interval just before the live counters reset, allowing
> stable one-second rate polling."*

CSR offset 13 (`TOTAL_HITS`) maps to `csr_total_hits`, a live accumulator
cleared at every `interval_pulse`. The pulse period equals `INTERVAL_CFG`
clock cycles at `lvdspll_clk = 125 MHz` (8 ns / tick).

On the FEB v3 emulator-type0 build, `histogram_statistics_0.interval_reset`
is wired only to the generic POR reset bridge, so the periodic timer is
the sole source of `interval_pulse`. If `INTERVAL_CFG <= run window`,
multiple pulses fire during the run; the post-end-run `TOTAL_HITS` read
returns at most the `t=last_pulse..end_run` partial (often zero), and the
ping-pong `hist_bin` bank reflects only one interval's worth of data.

To get the full-run total in `TOTAL_HITS`, the script programs
`INTERVAL_CFG = INTERVAL_CFG_NEVER_FIRE = 0xFFFFFFFF` (~34.36 s @
125 MHz). No interval pulse fires during any reasonable run window; the
live counter accumulates every hit, and the dual-bank SRAM never swaps,
so `hist_bin[0..255]` reads the same accumulator.

A hard safety check refuses to start a row whose `interval_seconds`
exceeds `INTERVAL_CFG_NEVER_FIRE_S = 34.36 s` (the entire matrix's max
is 4 s today). If a future row needs a longer window, switch to manual
`interval_reset` between runs.

Three counters are captured every row for cross-validation:

| Field in `verdict.json` | CSR | Reflects |
|---|---|---|
| `total_hits_csr13` | 13 | LIVE current-interval accumulator (authoritative full-run total under INTERVAL_CFG_NEVER_FIRE) |
| `last_interval_total_hits_csr17` | 17 | STABLE last-completed-interval latch (should be 0 or stale; no interval pulse fired) |
| `hist_bin_sum` | hist_bin[0..255] | per-channel SRAM sum (must equal `total_hits_csr13` &plusmn;8) |

`hist_bin_sum_matches_csr13` is a warning-only flag (not a verdict fail),
because end-of-run pipeline drain can leave a small residual between the
CSR sample and the bin-RAM reads.

## Pre-flight

| Step | Command | Why |
|------|---------|-----|
| 1 | `tools/run_script/program_feb.sh <FEB SOF>` | flash FEB SciFi |
| 2 | `sleep 20` | per `feedback_feb_post_program_settle` |
| 3 | `sudo -n /usr/local/sbin/mudaq_recover_pcie` | recover `/dev/mudaq0` |
| 4 | confirm FEB link 2 reachable via `sc_tool 2 read 0x0FE80 1` | sc_hub UID check |

## Run commands

### Full sweep (~32 rows, ~6-7 min on board)

```bash
/home/yifeng/.local/bin/swb_ring_lock \
    python3 scripts/cotest/phase4_5_sweep.py --all
```

### Single row

```bash
/home/yifeng/.local/bin/swb_ring_lock \
    python3 scripts/cotest/phase4_5_sweep.py \
        --row p45_000_all_lanes_0xFFFFFFFF_default_dir
```

### Smoke / preview (no SWB required)

```bash
# print every command without executing
python3 scripts/cotest/phase4_5_sweep.py --dry-run --all

# list 32 row_ids
python3 scripts/cotest/phase4_5_sweep.py --list

# synthetic-data plot + LOG_POP decoder self-test
python3 scripts/cotest/phase4_5_sweep.py --plot-smoke

# rebuild master table from existing sweep_evidence/
python3 scripts/cotest/phase4_5_sweep.py --regen-table

# dump the inline plan to a json file
python3 scripts/cotest/phase4_5_sweep.py --export-plan /tmp/plan.json
```

## Flag reference

| Flag | Purpose |
|------|---------|
| `--all` | Run every row in the inline plan, in order. |
| `--row ROW_ID` | Run a single row. List with `--list`. |
| `--dry-run` | Print sc_tool command list per row; render smoke plot; run LOG_POP self-test. No SC transactions. |
| `--list` | List the 32 row_ids and exit. |
| `--plot-smoke` | Render synthetic-data plot to `sweep_evidence/_smoke/plot.png`. |
| `--regen-table` | Rebuild `doc/PHASE4_5_SWEEP_TABLE.md` from existing `sweep_evidence/`. |
| `--export-plan FILE` | Write the inline plan to a JSON file. |
| `--sc-tool PATH` | Override `sc_tool` binary (default: repo `tools/run_script/build/sc_tool`). |
| `--link N` | Override FEB SC link (default: 2). |
| `--verbose` | Verbose logging. |

## Per-row evidence layout

```
sweep_evidence/<row_id>/
  counters.json     -- pre/post CSR snapshots + stage timing
                       + run_number_writeback_ok flag
  hist_bin.csv      -- 256 channels x count
  tool_calls.log    -- every sc_tool call + return + retry attempts
  plot.png          -- 2-panel pre/post-rbCAM histogram, x-range [-1000, 3096]
  verdict.json      -- standalone verdict block (pass/total_hits/
                       stage_durations/failure_mode/...)
```

If a directory already exists, the script renames it to
`<row_id>.bak.<ISO8601>` before writing fresh artifacts. The script
NEVER deletes files.

## Grace periods (top-of-file constants in phase4_5_sweep.py)

| Constant | Value | When applied |
|----------|-------|--------------|
| `GRACE_1_POST_SC_WRITE_S` | 0.200 s | after CSR config writes settle |
| `GRACE_2_AFTER_FIFO_DRAIN_S` | 0.100 s | after FIFO drain, before run_number write |
| `GRACE_3_AFTER_RUN_NUMBER_S` | 0.050 s | after run_number write, before LOCAL_CMD |
| `GRACE_STAGE_PREPARE_S` | 0.200 s | after `0x10` RUN_PREPARE |
| `GRACE_STAGE_SYNC_S` | 0.200 s | after `0x11` RUN_SYNC |
| `GRACE_STAGE_TERMINATE_S` | 0.500 s | after `0x13` END_RUN (FIFO drain) |
| `GRACE_IDLE_POLL_TIMEOUT_S` | 2.000 s | max wait for STATUS to return to IDLE |
| `SC_RETRY_COUNT` | 3 | retries before declaring fail |
| `SC_RETRY_BACKOFF_S` | 0.100 s | linear backoff (100, 200, 300 ms) |
| `LOG_FIFO_DRAIN_MAX_ITER` | 100 | hard cap to prevent infinite loops |

## Pass/fail criteria (per row)

A row PASSes when all of the following hold:

- `total_hits_csr13 > 0` (or `== 0` for `sanity_negative` rows)
- `UNDERFLOW == 0`
- `OVERFLOW == 0`
- histogram `DROPPED_HITS == 0`
- arb `drops_emu == 0` summed across lanes
- `RX_CMD_COUNT` delta `== 4` (one for each of 0x10/0x11/0x12/0x13)
- `RX_ERR_COUNT` delta `== 0`

`total_hits_csr13` is the LIVE CSR 13 accumulator captured post-end-run.
With `INTERVAL_CFG_NEVER_FIRE` it equals the full-run total.

`run_number_writeback_ok` is captured as a non-fatal sanity flag in
`verdict.json`. If `CSR_RUN_NUMBER` only latches from the LVDS
RUN_PREPARE payload (not the side-load), the flag is `false` but the
verdict does not depend on it.

`hist_bin_sum_matches_csr13` is a WARNING-only flag (not a fail). It
fires when `abs(hist_bin_sum - total_hits_csr13) > 8` (8-hit pipeline
drain tolerance). A mismatch reported here is logged in
`verdict.warnings` but the row's PASS predicate still uses CSR 13
alone.

`failure_mode` in `verdict.json` lists every predicate that failed.

## Stage timing recipe summary

| Stage | Trigger | Window | Unit |
|-------|---------|--------|------|
| GRACE_1 | post-SC-write settle | 200 ms | ms |
| GRACE_2 | after FIFO drain | 100 ms | ms |
| GRACE_3 | after run_number write | 50 ms | ms |
| PREPARE | `0x10` accepted | grace 200 ms | ms |
| SYNC | `0x11` accepted | grace 200 ms | ms |
| RUNNING | `0x12` accepted -> `0x13` issued | row.interval_seconds | s |
| TERMINATE | `0x13` accepted -> STATUS==IDLE | grace 500 ms + idle poll (timeout 2 s) | ms |

The `stage_durations` block in `verdict.json` records every value
computed from FIFO timestamps. Terminating duration falls back to
wall-clock when STATUS never reaches IDLE; the `idle_completion` field
records which path was used.

## Sweep matrix (32 rows)

| Axis section | rows | description |
|---|---|---|
| section 4.5.1 channel-mask | 6 | all-lanes x 6 channel_masks x default rate x direct |
| lane isolation | 8 | single-lane admit x all-channels x default rate x direct |
| section 4.5.2 rate-doubling | 7 | all-lanes x all-channels x 7 rates x direct |
| section 4.5.3 hit-mode | 2 | burst + periodic at default rate |
| cross-product | 7 | lane x channel cross-products + high-rate |
| sanity-negative | 2 | `lane_mask=0x00` predicts `TOTAL_HITS==0` |

Each row is listed by `--list`.

## Counter inventory (per snapshot, pre + post)

| IP block | counters captured |
|---|---|
| arb_hit_type0_supercore | 8 lanes x {MODE, FIFO_LEVEL_MAX, ingress_emu_hits, drops_emu, egress_emu_hits, ingress_real_hits, drops_real, egress_real_hits} |
| histogram_statistics_v2 | UNDERFLOW, OVERFLOW, INTERVAL_CFG, BANK_STATUS, PORT_STATUS, TOTAL_HITS (CSR 13, LIVE), DROPPED_HITS (CSR 14, LIVE), COAL_STATUS, LAST_INTERVAL_TOTAL_HITS (CSR 17, STABLE), LAST_INTERVAL_DROPPED_HITS (CSR 18, STABLE), hist_bin[0..255] |
| ring_buffer_cam_0..7 | uid, ctrl, fill_level, inerr_count, push_count, pop_count, overwrite_count, cache_miss_count |
| mts_preprocessor_0/1 | status_control, discard_hits, expected_latency, total_hits |
| feb_frame_assembly_HSS0/1 | declared_hits, actual_hits, missing_hits |
| runctl_mgmt_host | UID, STATUS, LAST_CMD, RUN_NUMBER, RECV_TS, EXEC_TS, RX_CMD_COUNT, RX_ERR_COUNT, LOG_STATUS, 4-entry LOG_POP decode |

Counters that are not exposed are recorded as `NOT_AVAILABLE` rather
than raising an exception.

## Failure-mode coverage

The script handles all of the following without raising an uncaught
Python exception:

1. sc_tool transient error (rc != 0, `SLVERR`, `DECERR`, timeout) -> 3
   retries with 100/200/300 ms backoff before declaring sc_read /
   sc_write fail.
2. LOG FIFO has fewer than 4 entries -> records what is there,
   `log_entries_count` reflects the actual count, never crashes.
3. `CSR_STATUS` never reaches IDLE -> idle poll times out at 2 s,
   terminating duration falls back to wall-clock, `idle_completion`
   field set to `WALL_CLOCK_FALLBACK`.
4. `hist_bin` readout returns all zeros -> plot renders an annotated
   empty panel ("no hits captured"); does not crash.
5. CSR address not defined -> field recorded as `NOT_AVAILABLE` in
   `counters.json`, snapshot continues.
6. Output directory already exists -> renamed to `<dir>.bak.<ISO8601>`,
   never overwritten or deleted.
7. Fatal SC hub unreachable -> structured `verdict.json` with
   `failure_mode="FATAL: ..."` and full traceback in `counters.json`.

## Hard rules baked into the script

- All sc_tool / rc_tool calls run under `/home/yifeng/.local/bin/swb_ring_lock`.
  The script enforces `have_swb_ring_lock()` for live mode.
- `hist_bin` reads are SINGLE-WORD only (Round 3 a710b11a finding:
  burst reads corrupt the SC bridge).
- Opcodes `0x30` / `0x31` are blocked by `FORBIDDEN_OPCODES` and refused
  by `drive_local_cmd()`.
- Plots use matplotlib only.
- All paths are absolute or computed from `__file__`; the script runs
  from any cwd.
- ASCII only.
- Move-aside (never delete) for existing output directories.

## Where things live

| Path | Owner |
|------|-------|
| `<REPO_ROOT>/scripts/cotest/phase4_5_sweep.py` | THE script (all integrated, repo-level) |
| `doc/PHASE4_5_SWEEP_GUIDE.md` | this guide |
| `doc/PHASE4_5_SWEEP_TABLE.md` | auto-regenerated master table |
| `sweep_evidence/<row_id>/` | per-row artifacts |
| `sweep_evidence/_smoke/` | smoke-test artifacts (synthetic) |
| `script/phase4_5_*.deprecated.*` | move-aside copies of the legacy 4-file split (kept for audit) |

To target a different build (evidence/doc output dir), override the build dir
via env var:
```
PHASE4_5_BUILD_DIR=/abs/path/to/build python3 scripts/cotest/phase4_5_sweep.py --all
```

## Reading the master table

`doc/PHASE4_5_SWEEP_TABLE.md` is an HTML table inside Markdown with a
double-column header. Each row links to its evidence directory and the
2-panel plot. `Verdict` column shows `PASS`, `FAIL`, or `PENDING`.

## Recovery

If the script aborts mid-sweep, just rerun. Each row's evidence dir is
move-aside before being rewritten, so prior partial artifacts are
preserved as `<row_id>.bak.<ISO8601>`.

## Provenance

- script: `script/phase4_5_sweep.py` (single file)
- TEST_PLAN: `firmware_builds/systems/v3_pretest-260511/doc/TEST_PLAN.md` section 4.5
- working baseline: commit `a710b11a` (FEB v3 emulator-type0 round 3 board)
- CSR map source: `run-control_mgmt/rtl/runctl_mgmt_host.sv`

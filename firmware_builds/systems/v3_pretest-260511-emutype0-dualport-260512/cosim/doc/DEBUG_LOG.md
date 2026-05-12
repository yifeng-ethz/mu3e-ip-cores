# DEBUG_LOG.md - RN.BASIC cosim iterative debug

## 2026-05-12 - Iter 1

- Cluster being closed: BUG-002-T stale 208-row row_config / RN.BASIC.194
  parser mismatch.
- Root-cause hypothesis: the runner still expected the old 208-row layout and
  could reuse saved row configs, so rows 161 onward did not reliably represent
  the trimmed 194-row TEST_BASIC plan.
- Patch summary:
  - `cosim/scripts/rn_basic_cosim.py`: parse RN.BASIC.001-194, map slice 3 to
    rows 161-162, map slice 4 to rows 163-194, and export delay cycle
    percentiles.
  - `cosim/scripts/analyze_rn_basic_fail_modes.py`: prefer
    `RN.BASIC.194_summary.json`.
  - `cosim/doc/COSIM_USAGE.md`: document the 194-row runner output.
  - `scripts/cotest/cosim_auto_report.py`: surface delay range bound evidence
    in generated reports.
- Re-run PASS count delta: parser dry-run moved the plan endpoint from
  RN.BASIC.208 to RN.BASIC.194. The first affected slice 3 rerun still went
  0/2 because BUG-003-H was exposed; BUG-002-T row remapping is closed.

## 2026-05-12 - Iter 2

- Cluster being closed: BUG-003-H onclick expected_pulses under-generation.
- Root-cause hypothesis: slice 3 used one source pulse per 1 ms window even
  though the two onclick sanity rows require `expected_pulses=10`.
- Patch summary:
  - `cosim/scripts/rn_basic_cosim.py`: scale slice 3 source period as
    `RUN_WINDOW_8NS // expected_pulses`.
- Re-run PASS count delta: slice 3 went 0/2 to 2/2; RN.BASIC.161 reports
  2,560/2,560 hits and RN.BASIC.162 reports 80/80 hits, with rate, delay, and
  RDMA all PASS. BUG-003-H is closed.

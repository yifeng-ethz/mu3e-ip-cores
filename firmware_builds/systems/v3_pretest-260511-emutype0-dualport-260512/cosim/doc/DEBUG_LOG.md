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

## 2026-05-12 - Iter 3

- Cluster being closed: BUG-004-H four-ASIC lane-mask compaction in the
  FEB/SWB corun harness.
- Root-cause hypothesis: the cosim source and trace checker still used the old
  two-lane virtual mapping, so 0x55/0xAA rows overloaded two SWB physical lanes
  instead of exercising the four-lane OPQ wrapper.
- Patch summary:
  - `tb_int/feb_swb_corun/sv/feb_swb_corun_plain_tb.sv`: drive four lanes and
    map adjacent ASIC pairs onto SWB lanes 0..3.
  - `tb_int/feb_swb_corun/sv/feb_swb_parallel_cdc_adapter.sv`: derive
    `swb_enable_mask` from `ACTIVE_LANES`.
  - `tb_int/feb_swb_corun/scripts/analyze_feb_swb_trace.py`: use the same
    adjacent-pair lane oracle as the harness.
- Re-run PASS count delta: directed RN.BASIC.167 went FAIL to PASS; slice 4
  went 20/32 to 28/32. BUG-004-H is closed for RN.BASIC.167-194 except the
  separate full-mask rows RN.BASIC.163-166, which still fail at
  OPQ/RDMA egress with 75,217/125,000 hits and move to the next cluster.

## 2026-05-12 - Iter 4

- Cluster being closed: BUG-005-R full-mask OPQ handle-credit corruption in
  RN.BASIC.163-166, plus BUG-006-H native-signoff analyzer/defaults fallout.
- Root-cause hypothesis: the OPQ source-compat wrapper used by the cosim
  native-signoff compile had drifted from maintained RTL and left
  `page_allocator.handle_credit_update_valid_i` unconnected, so full-mask
  backlog recycled handle slots and emitted zero-payload ghosts after counts
  were otherwise conserved. Once that was fixed, the harness still failed
  because it required generated-OPQ text summaries that native-signoff traces
  do not emit.
- Patch summary:
  - `packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic.sv`:
    wire `block_path_lane_credit_update_valid` into the page allocator and
    hook the adjacent debug-only ports.
  - `tb_int/feb_swb_corun/scripts/analyze_feb_swb_trace.py`: allow missing
    native OPQ text summaries only when the per-hit trace proves exact
    OPQ-ingress / OPQ-egress / DMA bijection with no ghosts.
  - `cosim/Makefile`: default `PARALLEL=16` and export the native-signoff OPQ
    profile rooted at this repo.
  - `cosim/doc/COSIM_USAGE.md`: document the closure command, `/data2` scratch
    workflow, and native-signoff OPQ profile.
- Re-run PASS count delta: RN.BASIC.163 moved from 116,716/125,138 matched
  hits with 8,422 ghosts to 125,138/125,138 matched hits with zero ghosts.
  RN.BASIC.163-166 went 0/4 to 4/4 PASS under the corrected native-signoff
  profile; slice 4 is therefore closed by composition from 28/32 to 32/32.

## 2026-05-12 - Iter 5

- Cluster being closed: BUG-007-H header-sync source cadence under-generation
  in slice 2.
- Root-cause hypothesis: the header-sync cosim source emitted one burst per
  virtual short-frame interval instead of using the RN.BASIC `0x0100` pulse
  interval, so source_generation, rbCAM, RDMA, and histogram counters all
  conserved a smaller stream.
- Patch summary:
  - `tb_int/feb_swb_corun/sv/feb_swb_corun_plain_tb.sv`: advance header-sync
    bursts by `HIT_PERIOD_8NS` while preserving per-ASIC header phase and burst
    spacing.
  - `tb_int/feb_swb_corun/scripts/analyze_feb_swb_trace.py`: validate the
    same header-phase plus period schedule in the trace oracle.
- Re-run PASS count delta: slice 2 went 0/32 to 32/32; RN.BASIC.129 reports
  124,928/125,000 hits with zero trace/corun errors, and RN.BASIC.160 reports
  488/488 hits. BUG-007-H is closed.

## 2026-05-12 - Iter 6

- Cluster being closed: BUG-008-H single-lane native OPQ SciFi header alias and
  stale all-lane SWB mask in RN.BASIC.082.
- Root-cause hypothesis: the row selected ASIC 2 only, but the corun SWB
  register shim still enabled all four physical OPQ lanes. That exposed an
  empty-lane native OPQ merge boundary and, after masking the inactive lanes,
  the native adapter still decoded the OPQ SciFi header alias as MuPix.
- Patch summary:
  - `cosim/scripts/rn_basic_cosim.py`: pass a local RN.BASIC native OPQ adapter
    into both precompile and row runs.
  - `tb_int/feb_swb_corun/sv/feb_swb_corun_plain_tb.sv`: derive the SWB
    enable mask from the selected RN.BASIC physical lanes.
  - `tb_int/feb_swb_corun/vhd/ingress_egress_adaptor_native_sv_scifi.vhd`:
    map unknown native K28.5 header aliases to `SCIFI_HEADER_ID` in this
    SciFi-only cosim.
- Re-run PASS count delta: RN.BASIC.082 directed rerun went 0/1 to 1/1; the
  row reports 7,808/7,808 pass hits, zero ghosts, `issue_count=0`, and delay
  min/p05/p50/p95/max all 0 cycles. BUG-008-H is closed; by composition from
  the iter4 full sweep plus iter5 slice-2 closure, the next full sweep should
  move 193/194 to 194/194.

## 2026-05-12 - Closure

- Iter count: 6 debug iterations.
- Clusters closed: BUG-002-T, BUG-003-H, BUG-004-H, BUG-005-R, BUG-006-H,
  BUG-007-H, BUG-008-H.
- Final full sweep: `make run_BASIC PARALLEL=16
  WORK_ROOT=/data2/cosim_work_full_20260512_final` completed with
  RN.BASIC.001-194 all PASS. Slice rollup: slice 1 128/128, slice 2 32/32,
  slice 3 2/2, slice 4 32/32; total 194/194.
- Delay hard evidence: all 194 `delay_scoreboard.json` files contain
  `delay_min_cycles`, `delay_p05_cycles`, `delay_p50_cycles`,
  `delay_p95_cycles`, and `delay_max_cycles`; maximum observed
  `abs(max - min)` across the sweep is 0 cycles, within every scaled
  math-reviewer bound.
- Final auto-report:
  `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/reports/rn_basic_194_final_20260512_iter6_h5a6a44f7_report43f79e6b/`.
  Its top-level `index.md` has 194 rows with green rate, delay, bound, and
  RDMA columns.
- Deferred item: BUG-001-H remains the board-evidence compatibility item.
  The final auto-report records `BOARD_MAPPED=0` and `BOARD_UNRESOLVED=32`;
  no p45 PERF/4 s board bytes were normalized into the BASIC/1 ms cosim
  closure.

## 2026-05-13 - Per-Checkpoint Refresh

- Cluster being closed: BUG-009-T per-checkpoint delay-bound model and
  BUG-010-H lifetime analyzer join bug, before the refreshed RN.BASIC sweep.
- Qsys refresh action:
  - `script/apply_reset_sync_v3.sh`: applied the local
    `add_mclk125_reset_bridge_v3.tcl` qsys-script recipe to both SciFi
    datapath Qsys variants and the local `syn/feb_system_v3.qsys`.
  - `script/regenerate_local_qsys_clean.sh`: regenerated all four local Qsys
    files with `qsys-generate --clear-output-directory`.
- Qsys refresh evidence: all four clean status files from stamp
  `20260513_003225` report `exit_code=0` and `error_count=0`; regenerated
  `syn/feb_system_v3/synthesis/feb_system_v3.vhd` mtime is
  `2026-05-13 00:34:26 +0200`.
  `pulse_fanout8.sv` contains the three-stage `async_reg` synchronizers from
  `bff7ea43`, `mclk125_reset_sync` is present in the parent generated VHDL,
  and `monitor_reset_sync` is present in the data-path generated VHDL.

## 2026-05-13 - Per-Checkpoint Delay Evidence Review

- Cluster being closed: BUG-009-T per-checkpoint bound model and BUG-010-H
  lifetime percentile analyzer.
- Patch summary:
  - `scripts/cotest/cosim_lifetime_analyzer.py`: materializes checkpoint CSVs,
    joins by `hit_id`, computes non-flat min/p05/p50/p95/max, validates
    per-checkpoint bounds, and fails rows on flat, out-of-range, or skipped
    bound evidence.
  - `scripts/cotest/cosim_delay_bounds.py`: defines the four RN.BASIC
    injector-mode bound tables.
  - `scripts/cotest/feb_swb_lifetime_dislin.c`: renders the five stacked
    lifetime panels with bound and percentile markers.
  - `cosim/scripts/rn_basic_cosim.py` and `scripts/cotest/cosim_auto_report.py`:
    export the per-checkpoint CSVs and replace the single delay-bound summary
    with `delay_pre`, `delay_post`, `delay_feb`, `delay_ing`, and `delay_opq`.
- Validation completed before DUT refresh: Python compile passed; the available
  sanity trace produced nonzero five-checkpoint stats and the DISLIN lifetime
  PDF rendered with `Warnings: 0`.
- Phase-D DUT refresh completed against the local Qsys files present in the
  cosim build: `quartus_systems/arb_hit_type0_supercore.qsys`,
  `quartus_systems/scifi_datapath_system_v3.qsys`,
  `quartus_systems/scifi_datapath_system_v3_pipe.qsys`, and
  `syn/feb_system_v3.qsys`. The parent `feb_system_v3.qsys` is local to
  `syn/`, not `quartus_systems/`; it was regenerated together with the three
  local subsystem Qsys files.

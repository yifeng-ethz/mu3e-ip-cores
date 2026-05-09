# FEB to SWB Corun Adapter

This directory is a focused integration scaffold for co-running the
`system_20260504_emulator_type0` FEB path with the MuSiP/SWB OPQ datapath.

The preferred hardware-faithful path is:

1. FEB Firefly serial lane at line rate.
2. SWB XCVR receive PHY.
3. SWB OPQ four-lane native input.

That path is not enabled here because the Arria transceiver/CDR/8b10b
simulation model is not present in this worktree. The implemented path starts
one boundary later, at the FEB parallel hit_type3 egress. For this corun the
FEB side is the 125 MHz stream clock and the SWB side is the synchronous
250 MHz datapath clock, so the adapter keeps an explicit two-clock FIFO at the
boundary and drives SWB lanes 0 and 1. SWB lanes 2 and 3 must be disabled with
`feb_enable_mask = 4'h3` or `+SWB_FEB_ENABLE_MASK=3`.

## FEB Hook Points

Use `prof_int_002_full_pipeline_top.sv` as the FEB baseline, but bind the
corun adapter to the actual FEB parallel stream clock used by this setup
(125 MHz). The two existing FEB egress streams to adapt are:

- lane 0:
  - `u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_valid`
  - `u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_ready`
  - `u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_data`
  - `u_dut.data_path_subsystem.hit_stack_subsystem_0.frame_debug_hit_sidecar_valid`
  - `u_dut.data_path_subsystem.hit_stack_subsystem_0.frame_debug_hit_sidecar_data`
- lane 1:
  - `u_dut.data_path_subsystem.hit_type3_lower_valid`
  - `u_dut.data_path_subsystem.hit_type3_lower_ready`
  - `u_dut.data_path_subsystem.hit_type3_lower_data`
  - `u_dut.data_path_subsystem.hit_stack_subsystem_1.frame_debug_hit_sidecar_valid`
  - `u_dut.data_path_subsystem.hit_stack_subsystem_1.frame_debug_hit_sidecar_data`

Connect those streams to `feb_swb_parallel_cdc_adapter` as `feb_data[0]` and
`feb_data[1]`. The adapter preserves the existing hit_type3 word mapping:

- `data[35:32]` becomes SWB `datak[3:0]`
- `data[31:0]` becomes SWB `data[31:0]`

## SWB Hook Points

The MuSiP UVM SWB wrapper already models the post-XCVR receive boundary:

- repo: `/home/yifeng/packages/musip_2604`
- test: `tb_int/cases/basic/uvm`
- interface: `sv/interfaces.sv`, `feb_ingress_if`
- wrapper: `dut/swb_block_uvm_wrapper.vhd`

Drive MuSiP `feb_if0` and `feb_if1` from the adapter outputs and keep
`feb_if2`/`feb_if3` idle. The control sequence must set:

- `ctrl_if.feb_enable_mask = 4'h3`
- `ctrl_if.enable_dma = 1'b1`
- `ctrl_if.use_merge` according to the OPQ/DMA coverage point under test
- `+SWB_PASSIVE_INGRESS=1` so the MuSiP UVM agents monitor the lanes without
  also driving generated frames

## Run Control and CSR Configuration

The corun needs one owning sequence for both systems:

1. Hold FEB and SWB reset/run disabled.
2. Configure FEB/emulator CSRs and DEBUG_LEVEL-related enables.
3. Configure SWB CSRs, including FEB enable mask, generic mask, DMA enable,
   merge/generic mode, and event/readout limits.
4. Release both run controls from the same simulation epoch.
5. Start scoreboard capture after both sides have accepted configuration.

Do not let the FEB source begin streaming before the SWB wrapper has accepted
the lane mask and DMA/readout configuration, otherwise the no-loss check has an
unobservable prefix.

## Debug Metadata Contract

The UVM corun carries a 64-bit sideband alongside each transferred FEB word.
The current contract is defined in `sv/feb_swb_corun_pkg.sv`:

- `debug_level[1:0]`
- `swb_lane[1:0]`
- `source_id[3:0]`
- `ps_tag[7:0]`
- `ts_tag[15:0]`
- `hit_id[31:0]`

This is a UVM correlation contract; it does not change the FEB RTL payload.
The existing RTL already exposes DEBUG_LEVEL 2 sidecars near the emulator,
arbiter, and FEB frame assembly, but the canonical mapping for `ps`, `ts`, and
`hit_id` must be locked before changing the production RTL metadata encoding.

## Files

- `sv/feb_swb_parallel_cdc_adapter.sv` is the active parallel fallback.
- `sv/feb_swb_corun_plain_tb.sv` is the direct mixed FEB/MuSiP RTL
  continuation bench. It instantiates the parallel adapter and the MuSiP
  `swb_block_uvm_wrapper`, drives lanes 0 and 1 with FEB-style hit_type3
  frames, masks lanes 2 and 3, and checks OPQ/DMA hit identity.
- `sv/feb_swb_musip_uvm_driver.sv` drives MuSiP `feb_ingress_if`
  instances from the packed adapter outputs.
- `sv/feb_swb_async_fifo.sv` is a simulation FIFO for the 125 MHz FEB to
  250 MHz SWB clock crossing.
- `sv/feb_swb_serial_line_adapter_stub.sv` documents and guards the future
  pin-level Firefly/XCVR path.
- `sv/feb_swb_parallel_cdc_adapter_smoke_tb.sv` is a small non-UVM smoke test.

## Local Check

From this directory:

```sh
make compile
make compile_musip_driver
make smoke
```

For the direct SWB RTL continuation corun:

```sh
make compile_swb_corun QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim
make run_swb_corun QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim
```

The maintained directed contract run uses virtual MuTRiG ASIC0..7 channels
0..31 at 100 kHz/channel for 1 ms on lane 0, an empty legal FEB frame on lane 1,
and `feb_enable_mask = 4'h3`. Lanes 2 and 3 are masked. The default make
variables are `RUN_WINDOW_8NS=125000`, `HIT_PERIOD_8NS=1250`,
`ASIC_COUNT=8`, and `SOURCE_MODE=periodic`; this gives 100 time samples per
ASIC/channel and 25600 expected DMA hits. The scoped no-bottleneck run should
use:

```sh
make run_swb_corun \
  QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim \
  OPQ_SOURCE_MODE=native_sv_signoff \
  OPQ_LANE_FIFO_DEPTH=65536 \
  OPQ_TICKET_FIFO_DEPTH=65536 \
  ASIC_COUNT=8 \
  RUN_WINDOW_8NS=125000 \
  HIT_PERIOD_8NS=1250 \
  SOURCE_MODE=periodic
```

The stochastic comparison uses independent Poisson streams per ASIC/channel:

```sh
make run_swb_corun_poisson \
  QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim \
  OPQ_SOURCE_MODE=native_sv_signoff \
  OPQ_LANE_FIFO_DEPTH=65536 \
  OPQ_TICKET_FIFO_DEPTH=65536 \
  ASIC_COUNT=8 \
  RUN_WINDOW_8NS=125000 \
  HIT_PERIOD_8NS=1250 \
  POISSON_SEED=20260508
```

The deterministic header-sync comparison uses a virtual MuTRiG short-frame
period of 910 cycles, phase 100, one pulse per short frame, and a 16-cycle
per-ASIC phase stagger so the one-lane FEB subheader count never overflows:

```sh
make run_swb_corun_header_sync \
  QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim \
  OPQ_SOURCE_MODE=native_sv_signoff \
  OPQ_LANE_FIFO_DEPTH=65536 \
  OPQ_TICKET_FIFO_DEPTH=65536 \
  ASIC_COUNT=8 \
  RUN_WINDOW_8NS=125000 \
  HEADER_SYNC_PHASE_8NS=100 \
  HEADER_SYNC_BURST_COUNT=1 \
  HEADER_SYNC_ASIC_STAGGER_8NS=16
```

The MuSiP OPQ source defaults used by this corun provision
`OPQ_DEBUG_LEVEL=2`; under the scoped no-bottleneck assumption every native OPQ
drop counter must remain zero. The test expects the final log to contain
`FEB_SWB_CORUN_PLAIN_PASS` and writes ingress, OPQ, DMA, and summary traces
under `report/` for periodic mode, `report_poisson/` for Poisson mode, and
`report_header_sync/` for header-sync mode. `run_swb_corun`,
`run_swb_corun_poisson`, and `run_swb_corun_header_sync` also run
`scripts/analyze_feb_swb_trace.py`, which emits
`feb_swb_hit_trace_debug.csv` plus `feb_swb_lifetime_trace.csv` and proves each
hit reaches OPQ and DMA with the expected ASIC, channel, hit id, and
frame/subheader timestamp bucket. The direct-continuation harness also emits
virtual MuTRiG generation, pre-rbCAM, and post-rbCAM checkpoint traces. In this
special FEB-to-SWB corun those pre/post-rbCAM checkpoints are pass-through
lineage markers, not a real rbCAM instance. The DISLIN pre-rbCAM top panel uses
the virtual MuTRiG short-frame source model as the golden source-to-pre-rbCAM
profile; the post-rbCAM top panel imports the clean full-FEB rbCAM DEBUG-age
reference from the `prof_int_002` tb_int flow.

The lifetime trace uses the carried hit global timestamp/debug contract as the
origin, so the histogram axis is in 8 ns cycles and measures each hit's
lifetime from its actual virtual MuTRiG generation event, not from
inter-checkpoint deltas. `scripts/render_feb_swb_lifetime_dislin.sh` writes
`feb_swb_lifetime_hist.png`, `feb_swb_lifetime_hist.pdf`,
`feb_swb_lifetime_hist_stats.csv`, and `feb_swb_lifetime_dislin.log` for the
rbCAM reference, FEB egress, OPQ ingress, and OPQ egress hit lifetimes. The
plot uses one shared x-axis across all checkpoint panels and annotates p05,
p50, and p95 directly; p05 is orange dashed, p50 is black, and p95 is black
dashed. The pre-rbCAM panel also labels the virtual-MuTRiG expected envelope as
PASS when the observed source-model lifetime stays below 1100 cycles. The
analyzer also writes `feb_swb_range_validation.csv`, which validates the direct
corun ranges: synthetic pre/post-rbCAM `0` cycles in the trace,
virtual-MuTRiG pre-rbCAM source model under the `[0,2000]` aperture, post-rbCAM
DEBUG-age reference `[2000,2200)`, two-frame store-forward FEB egress
`[2049,6143]` cycles, OPQ ingress `[2049,6159]` cycles, and OPQ/DMA against the
measured finite-burst OPQ queue envelope. It also emits `feb_swb_tunnel_scoreboard.csv`,
`feb_swb_factual_scoreboard.csv`, and `feb_swb_opq_native_summary.csv`.

Current accepted all-ASIC 1 ms summaries:

```text
periodic:
  expected_hits=25600, expected_dma_words=6400
  feb_hit_count=25600, actual_hits=25600
  missing_hits=0, ghost_hits=0, opq_drop_counter_total=0
  pre_rbcam_virtual_model min/p05/p50/p95/max=27/125/536/946/1044 cycles
  plot=report/feb_swb_lifetime_hist.png

poisson_iid seed 20260508:
  expected_hits=25629, expected_dma_words=6431
  feb_hit_count=25629, actual_hits=25629
  missing_hits=0, ghost_hits=0, opq_drop_counter_total=0
  pre_rbcam_virtual_model min/p05/p50/p95/max=67/148/524/892/938 cycles
  plot=report_poisson/feb_swb_lifetime_hist.png

header_sync phase100 burst1 stagger16:
  expected_hits=35328, expected_dma_words=8832
  feb_hit_count=35328, actual_hits=35328
  missing_hits=0, ghost_hits=0, opq_drop_counter_total=0
  pre_rbcam_virtual_model min/p05/p50/p95/max=725/753/835/917/945 cycles
  plot=report_header_sync/feb_swb_lifetime_hist.png
```

The OPQ queue report is `feb_swb_opq_queue_model.csv` plus the DISLIN plots
`feb_swb_opq_queue_model.png` and `.pdf`. It aligns each lane-0 FEB frame SOP
with the OPQ output frame SOP and applies the deterministic recurrence
`wait[n] = wait[n-1] + service_iat[n] - ingress_iat[n]`. In the accepted
periodic run this model has zero residual and reports
`rho = mean(service_iat) / mean(ingress_iat) = 1.729`, `wait_min=2733.5`, and
`wait_max=92256.5` cycles. In the accepted Poisson run the zero-residual queue
model reports `mean(service_iat)=3607.639`, `rho=1.762`, `wait_min=2789.5`,
and `wait_max=97927.5` cycles. In the accepted header-sync run it reports
`mean(service_iat)=3542.058`, `rho=1.730`, `wait_min=2819.0`, and
`wait_max=92462.5` cycles. Because these are finite bursts with provisioned
buffering and post-run drain,
`rho>1` is reported as queue residency, not as an allowed loss condition.

The excluded 1024-entry lane-FIFO diagnostic profile is recorded in
`../doc/BUG_HISTORY.md` as BUG-022-R. It remains useful as an overload
calibration run, but it is not the maintained no-bottleneck contract for this
corun.

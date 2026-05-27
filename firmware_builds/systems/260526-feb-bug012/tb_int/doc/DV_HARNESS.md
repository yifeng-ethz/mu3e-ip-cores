# DV_HARNESS.md - 260518-feb-ok tb_int UVM harness

## DUT

Authentic generated firmware tree (dv-workflow rule 19):

```
firmware_builds/systems/260518-feb-ok/generated/simulation/feb_system_v3/
```

produced by `make qsys-gen` (DEBUG_LEVEL=2). The harness binds at the
Qsys system boundary - it never substitutes a behavioral model for the
generated wrapper or its internal fabric.

## tb_top + interfaces

- `uvm/harness/tb_top.sv`: instantiates `feb_system_v3` from the
  generated simulation tree and binds the boundary interfaces below.
- `uvm/harness/feb_swb_corun_if.sv`: SystemVerilog interface(s) for the
  exposed Avalon-MM / Avalon-ST / conduit / run-control ports.
- `uvm/harness/feb_swb_corun_uvm_pkg.sv`: package declaring the env, the
  scoreboards, the sequence base, and bucket sequence libraries.

(These three files were lifted from
`trash_bin/legacy_scenarios/feb_swb_corun/uvm/` during the 2026-05-18
restructure and are kept as the starting reference. They need to be
re-pointed at `<system>/generated/simulation/feb_system_v3/` once
`make qsys-gen` lands the simulation tree; today's `make qsys`
sequence has the simulation phase blocked on Arria V family bring-up,
tracked in [BUG_HISTORY.md](BUG_HISTORY.md).)

## Boundary agents

Per dv-workflow rule 19, agents attach at exposed Qsys boundaries only:

- `data_path_subsystem.hit_type{0,3}_*` upload egress streams
- `upload_subsystem.upload_{data,sc,idle}` mux ingress
- `debug_sc_subsystem` SC packet round-trip
- `histogram_statistics_0.{csr, hist_bin, type1_up_ts, type1_down_ts}`
- `mts_preprocessor_{0,1}.hit_type1_ts` conduit (the eb67302-merged
  interface)
- Run-control + reset broadcast splitter
- The exported feb_bringup CSR

## Scoreboard

One scenario-oriented scoreboard, reusable across BASIC / EDGE /
PROF / ERROR / CROSS buckets. Per dv-workflow rule 19 it adapts to
each bucket via configuration, never via per-case DUT variants.

Pending hook-up:
- `upload_pkt_mux` arbitration scoreboard (in0 vs in1 vs in2 fairness
  + EOP accounting), originally in
  `trash_bin/legacy_scenarios/upload_backpressure/tb_feb_upload_backpressure.sv`.
- Histogram bank ping-pong scoreboard, originally in
  `trash_bin/legacy_scenarios/hist_dualport/*`.

## Sequences

- `uvm/sequence/basic/` - B0xx directed cases
- `uvm/sequence/edge/`  - E0xx corner cases
- `uvm/sequence/prof/`  - P0xx soak / throughput
- `uvm/sequence/error/` - X0xx reset / fault / recovery
- `uvm/sequence/cross/` - C0xx bucket_frame / all_buckets_frame
  composers (per dv-workflow rule 9)

## Coverage hook-up

- Each isolated case emits its own UCDB under `uvm/builds/<case>/cov.ucdb`.
- Merged isolated UCDB at `uvm/builds/merged_isolated.ucdb`, recomputed
  by `make merge_cov` after each new case run.
- `bucket_frame` and `all_buckets_frame` produce separate UCDBs at
  `uvm/builds/bucket_frame_<bucket>.ucdb` and
  `uvm/builds/all_buckets_frame.ucdb`, never merged into the isolated
  total (dv-workflow rule 9).

## Build flow

1. From the system root, run `make qsys` to produce
   `generated/{qsys,synthesis,simulation}/`.
2. `make -C tb_int/uvm compile` reads the simulation tree's
   `submodules/` source list and compiles into `uvm/builds/work_<case>/`.
3. `make -C tb_int/uvm run TEST=<id>` runs an isolated case.
4. Evidence is dropped under `REPORT/<id>/summary.md` + per-case CSV.

# Streaming Debug Plane - Datapath Re-architecture Plan

Status: Phase A implemented in the 2026-05-15 snapshot worktree; Phase B deferred
Owner: yifeng wang
Target repo: `mu3e-ip-cores`
Scope: `feb_system_v3`, `mutrig_timestamp_processor`, `histogram_statistics_v2`

---

## 1. Motivation

The pre-change FEB v3 image carried the 48-bit true-hit timestamp inside the
main Type-1 stream and also routed timestamp observability through the
`histogram_ingress_bridge`. That made the main MTS to splitter to rbCAM path
87 bits wide even though the functional Type-1 contract is 39 bits, and it
made histogram delay-mode source selection depend on a separate bridge IP.

The new contract moves observability to a readyless streaming-debug plane:

- the main MTS Type-1 output is restored to the original 39-bit payload;
- `mts_processor` exposes two readyless 87-bit debug sources,
  `hit_type1_extended_0` and `hit_type1_extended_1`;
- `histogram_statistics_v2` owns source selection internally through
  `CONTROL.in_port[3:2]`;
- `histogram_ingress_bridge` is removed from the FEB v3 topology and from the
  `histogram_statistics` IP repository.

The normal histogram fill inputs remain available on `histogram_statistics_v2`.
For FEB v3 streaming-debug capture, the selected source is now the histogram
IP itself, not an external bridge.

---

## 2. Implemented Topology

### 2.1 Main Datapath

```text
mts_processor
  |-- aso_hit_type1            : type1[38:0]
  |-- aso_hit_type1_extended_0 : { true_ts[47:0], type1[38:0] }
  `-- aso_hit_type1_extended_1 : { true_ts[47:0], type1[38:0] }

aso_hit_type1
  -> splitter / hit_stack upper and lower banks
  -> rbCAM
  -> feb_frame_assembly

aso_hit_type1_extended_0
  -> histogram_statistics_v2.asi_hit_type1_extended_0

aso_hit_type1_extended_1
  -> histogram_statistics_v2.asi_hit_type1_extended_1
```

The generated `feb_system_v3` synthesis tree confirms the production main
datapath uses 39-bit Type-1 payloads and that the two 87-bit extended streams
connect directly from the two MTS instances into `histogram_statistics_v2`.

### 2.2 Retired Bridge

`histogram_ingress_bridge` is no longer part of the active contract:

- no bridge RTL, `_hw.tcl`, SVD, CMSIS generator, or standalone bridge TB
  remains in `histogram_statistics`;
- the FEB v3 Qsys updater removes stale bridge, post-sideband, and pre-trim
  instances if they exist in older `.qsys` files;
- no bridge CSR aperture is published in the regenerated parent map.

This intentionally discards the old bridge source-switch path. Source
selection is absorbed into `histogram_statistics_v2`.

---

## 3. Interface Contracts

### 3.1 `mts_processor.hit_type1`

| signal | width | notes |
|---|---:|---|
| `aso_hit_type1_data` | 39 | functional Type-1 payload only |
| `aso_hit_type1_valid` | 1 | unchanged real-hit payload gate |
| `aso_hit_type1_sop/eop/channel/empty/error` | unchanged | normal packet sidebands |

The internal non-wrapping timestamp reconstruction remains in the MTS
processor and is reused only for the debug-plane payload.

### 3.2 `mts_processor.hit_type1_extended_<bank>`

| signal | width | notes |
|---|---:|---|
| `aso_hit_type1_extended_<bank>_data` | 87 | `{true_ts[47:0], type1[38:0]}` |
| `aso_hit_type1_extended_<bank>_valid` | 1 | asserted only for real Type-1 hit beats |

Rules:

- no ready, no packets, no channel, no empty, no error;
- `_0` is the upper-bank source and `_1` is the lower-bank source in FEB v3;
- DEBUG_LEVEL=2 UVM observes per-hit lineage, but production Qsys keeps the
  generated MTS `DEBUG` generic at the synthesizable default.

### 3.3 `histogram_statistics_v2`

New readyless sinks:

| interface | payload |
|---|---|
| `asi_hit_type1_extended_0` | 87-bit upper-bank `{true_ts, type1}` stream |
| `asi_hit_type1_extended_1` | 87-bit lower-bank `{true_ts, type1}` stream |

`CONTROL.in_port[3:2]` selects the source when an apply strobe is written:

| value | source |
|---:|---|
| `0` | normal `hist_fill_in` / `fill_in_1..7` path |
| `1` | `asi_hit_type1_extended_0` |
| `2` | `asi_hit_type1_extended_1` |
| `3` | rejected; `csr_error_info = 0x2` |

For extended ports, the lower 39 bits feed the normal payload extraction path.
In delay mode, `data[86:39]` supplies the 48-bit true timestamp used by the
existing GTS subtraction/binning logic.

---

## 4. Phase A Work Completed

### `mutrig_timestamp_processor`

- restored `aso_hit_type1_data` to 39 bits;
- added readyless `hit_type1_extended_0/1` 87-bit sources;
- routed `_0` for the upper bank and `_1` for the lower bank;
- updated wrapper/testbench files and package metadata to version
  `26.3.4.0515`.

### `histogram_statistics`

- deleted `histogram_ingress_bridge` RTL, package metadata, SVD, CMSIS
  generator, and standalone bridge testbench;
- added `asi_hit_type1_extended_0/1` sinks to `histogram_statistics_v2`;
- added `CONTROL.in_port[3:2]` source selection to the histogram IP;
- updated SVD/CMSIS metadata and package version to `26.3.0.0515`;
- updated the standalone board wrapper so the direct pre path drives the
  histogram extended sink without the bridge.

### `feb_system_v3`

- updated `update_scifi_datapath_v3_histogram_stats.tcl` to remove stale
  bridge/sideband/pre-trim instances and connections;
- wired MTS extended streams directly into `histogram_statistics_0`;
- regenerated `quartus_systems/feb_system_v3.qsys` and the v3 datapath Qsys
  variants;
- updated the live capture script so `upper`/`lower` map to histogram
  `in_port = 1/2` without bridge CSR access.

---

## 5. Verification Evidence

All evidence below is from the 2026-05-15 bridge-free Phase A worktree.

| area | command / artifact | result |
|---|---|---|
| MTS standalone TB | `make -C mutrig_timestamp_processor/tb run_all` | PASS, `mts_processor_tb PASSED`, `mts_processor_terminating_tb PASSED`, 0 errors |
| histogram standalone TB | `make -C histogram_statistics/tb run_all` | PASS, `47 PASS, 0 FAIL` |
| FEB v3 Qsys generation | `generate_feb_system_v3.sh` with stamp `20260515_stream_debug_bridgefree_retry1` | PASS, status `exit_code=0`, `error_count=0` |
| tb_int BASIC + RC + cosim | `make regress_basic run_RC_EMUL run_source_mux_frame_parser_cosim SIM_ROOT=sim_stream_debug_20260515_rerun SEED=1` | PASS |
| generated DUT bind smoke | `make run_B067 BIND_REAL_DUT=1 SIM_ROOT=sim_stream_debug_bind SEED=1` | PASS, generated `synthesis/` tree compiled and instantiated as `u_dut` |

Per-hit DEBUG_LEVEL=2 scoreboard evidence from the old dual UVM environment:

| sequence | closed hits | evidence |
|---|---:|---|
| `B065` | 16 | `debug_obs SRC/PRE/POST/FEB=16/16/16/16`, duplicate IDs 0 |
| `B066` | 16 | `debug_obs SRC/PRE/POST/FEB=16/16/16/16`, duplicate IDs 0 |
| `B067` | 100 | `debug_obs SRC/PRE/POST/FEB=100/100/100/100`, duplicate IDs 0 |
| `B068` | 1024 | `debug_obs SRC/PRE/POST/FEB=1024/1024/1024/1024`, duplicate IDs 0 |
| `B069` | 1 | `debug_obs SRC/PRE/POST/FEB=1/1/1/1`, duplicate IDs 0 |
| `RC_EMUL` | 16 | `debug_obs SRC/PRE/POST/FEB=16/16/16/16`, duplicate IDs 0 |
| `SOURCE_MUX_FRAME` | 5056 parser hits | source-mux/frame-parser cosim PASS, CRC errors 0 |

The `BIND_REAL_DUT=1` mode instantiates the generated `feb_system_v3`
synthesis tree in the old dual UVM harness. The generated system is held in a
benign dormant configuration while the existing per-hit scoreboard continues
to validate the behavioral shell taps. Vendor/generated assertions under
`u_dut` are disabled in this bind mode so dormant unconnected fabric does not
pollute the UVM scoreboard result.

---

## 6. Non-Claims And Remaining Work

- Full standalone Quartus timing signoff for the new bridge-free
  `histogram_statistics_v2` standalone harness was not rerun in this turn.
  The old bridge-plus-hist timing result is archived only and is not current
  26.3.0 signoff evidence.
- Full FEB board Quartus compile and on-board SC/histogram capture are not
  claimed here.
- UCDB/code coverage closure is not claimed by the tb_int run; the evidence
  is functional DEBUG_LEVEL=2 per-hit scoreboard closure.
- Phase B, which would source the same histogram extended sinks from
  `feb_frame_assembly` Type-2 boundaries, remains deferred.

---

## 7. What This Plan Does Not Change

- rbCAM and `feb_frame_assembly` main hit widths remain at their original
  Type-1/Type-2 contracts.
- The MTS internal timestamp reconstruction remains available for debug-plane
  payload construction.
- The existing simulation-only per-hit sidecar monitors remain the
  DEBUG_LEVEL=2 UVM evidence path.
- The normal histogram fill inputs remain part of `histogram_statistics_v2`,
  but FEB v3 no longer feeds or selects them through `histogram_ingress_bridge`.

---

## 8. Migration Risks

| risk | mitigation |
|---|---|
| Qsys inserts an adapter on the readyless extended streams | both MTS sources and histogram sinks declare no ready; regenerated VHDL shows direct 87-bit connections |
| stale bridge instances remain in older `.qsys` files | the v3 updater removes retired bridge, post-sideband, and pre-trim instances before rewiring |
| host scripts still read bridge CSR words | `live_hist_sideband_capture.py` now programs `histogram_statistics_0.csr` `CONTROL.in_port` directly |
| users confuse old bridge timing evidence with current signoff | `histogram_statistics/syn/SYN_REPORT.md` marks the bridge-plus-hist result as archived and not current |

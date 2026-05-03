# DV Plan - mutrig_lane_source_mux

**DUT:** `misc/mutrig_lane_source_mux/rtl/mutrig_lane_source_mux.sv`
**Harness:** [`uvm/`](uvm/)
**Buckets:** [`DV_BASIC.md`](DV_BASIC.md), [`DV_PROF.md`](DV_PROF.md),
[`DV_CROSS.md`](DV_CROSS.md), [`DV_COV.md`](DV_COV.md)
**Bug ledger:** [`BUG_HISTORY.md`](BUG_HISTORY.md)

## 1. Scope

The mux is a per-lane byte-source selector between real MuTRiG decoded traffic
and the emulator stream. It supports runtime CSR selection of real-only,
emulator-only, and mixed round-robin mode. The verification target is the
functional contract needed by the current timing-fix integration:

- real valid may be either explicit (`REAL_ALWAYS_VALID=0`) or validless
  (`REAL_ALWAYS_VALID=1`)
- direct modes must forward byte, channel, error, and selected-valid without
  blocking
- mixed mode must admit both input streams through shallow per-source FIFOs,
  arbitrate in round-robin order, and account accepted, selected, switched, and
  dropped beats
- CSR control, clear, metadata, and live status must stay responsive while the
  datapath is active

## 2. Non-Scope

This bench does not decode full MuTRiG frames. The downstream monitor is the
input-side contract of the following byte consumer: it captures the selected
byte stream and sidebands exactly as a frame-input stage would see them. Full
frame semantic checking remains owned by `mutrig_frame_deassembly`.

## 3. Harness Summary

The UVM top instantiates one DUT per run. Build parameter
`REAL_ALWAYS_VALID` is selected through the Makefile. `mlsm_directed_test` runs
one documented case per fresh reset; `mlsm_bucket_frame_test` executes a
continuous ordered frame; `mlsm_soak_test` randomly picks from the directed
case bodies for long pressure runs.

The scoreboard is contract-derived. It models direct-source forwarding, mixed
FIFO occupancy, round-robin source choice, expected drops, and selected-output
sideband visibility. CSR checks use coherent snapshots; in validless mode the
raw real-input beat counter is monotonic by definition and is not treated as a
static multi-word snapshot unless the selected side has first been moved idle.

## 4. Closure Gates

1. `make -C misc/mutrig_lane_source_mux/tb/uvm directed64` passes.
2. `make -C misc/mutrig_lane_source_mux/tb/uvm bucket_frame` passes for both
   real-valid builds.
3. Three profiled soak runs execute from random directed-case picks and run for
   at least 30 seconds each on the target simulator host.
4. `rtl_style_check.py` is clean on the DUT and UVM-added synthesizable probe
   code.
5. Any RTL or harness bug found during these runs is recorded in
   [`BUG_HISTORY.md`](BUG_HISTORY.md).

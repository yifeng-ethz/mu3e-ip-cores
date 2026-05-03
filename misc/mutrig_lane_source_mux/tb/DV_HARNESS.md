# DV Harness: mutrig_lane_source_mux

**Harness root:** `misc/mutrig_lane_source_mux/tb/uvm`  
**Author:** Codex  
**Date:** 2026-05-04  
**Status:** Active UVM harness for standalone mux functional regression.

## 1. Topology

`uvm/tb_top.sv` instantiates:

- `mutrig_lane_source_mux`
- `mlsm_if`, the combined CSR and byte-stream test interface
- `mlsm_downstream_input_probe`, which records selected valid beats and last
  sidebands while also instantiating the real `frame_rcv_ip` downstream
  byte-input stage as a non-scoring contract sink

The UVM package is intentionally compact:

- `mlsm_directed_test`: isolated B001-B064 cases
- `mlsm_bucket_frame_test`: ordered continuous frame for carry-over behavior
- `mlsm_soak_test`: random directed-case pressure loop
- `mlsm_coverage`: case, mode, real-valid mode, input-valid, and drop coverage

## 2. Drivers

The upstream driver uses the mux contract directly:

- real source: 9-bit decoded byte plus valid, error, and channel sidebands
- emulator source: same byte contract, independently valid-qualified
- CSR source: Avalon-MM word writes and combinational reads to the mux CSR map

For `REAL_ALWAYS_VALID=1`, the driver may hold `asi_real_valid=0`; the DUT must
still treat the real byte and sidebands as live.

## 3. Monitor And Scoreboard

The downstream probe observes exactly what the frame receiver byte-input stage
would consume: `aso_valid`, `aso_data`, `aso_error`, and `aso_channel`. The
scoreboard checks the same output cycle-by-cycle, asserts the probe
count/last-sideband snapshot, and separately checks CSR accounting. A live
`frame_rcv_ip` instance is connected behind the probe so the selected stream is
compiled and elaborated against the real downstream input boundary, while full
frame semantic scoring remains in the `mutrig_frame_deassembly` bench.

Mixed-mode reference modeling uses two FIFO queues and the documented
round-robin rule:

- both FIFOs non-empty: select the `rr_next_emulator` source
- one FIFO non-empty: select that source
- after selecting real, next paired grant prefers emulator
- after selecting emulator, next paired grant prefers real

## 4. Snapshot Rule

In validless mode, the real input count is an always-running clock-qualified
counter. The harness therefore avoids false multi-word readback failures by
checking coherent selected-output counters only after moving the selected side
idle. Raw real input count is checked as nonzero/monotonic in validless cases.

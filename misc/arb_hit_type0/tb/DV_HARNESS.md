# DV Harness: `arb_hit_type0`

**Parent:** [DV_PLAN.md](DV_PLAN.md)

## 1. Topology

```
+----------------+       +----------------+
| real_st_agent  |---+   | csr_agent      |
+----------------+   |   +----------------+
                     |          |
                     v          v
                 +-------------------+         +-----------------+
                 |   arb_hit_type0   |-------> | egress_st_agent |
                 +-------------------+         +-----------------+
                     ^          ^
                     |          |
+----------------+   |          |       +----------------+
| emu_st_agent   |---+          +-----> | scoreboard     |
+----------------+                       +----------------+
```

UVM components:

| Component | Role |
|---|---|
| `real_st_agent` | Active Avalon-ST source on `real_in`. Drives 45-bit data, error, channel ∈ [0..7], sop/eop/eor. |
| `emu_st_agent` | Active Avalon-ST source on `emu_in`. Drives 45-bit data, error, channel ∈ [8..15], sop/eop/eor. |
| `csr_agent` | Active AVMM master on `csr` (5-bit word, 32-bit data, read latency 1, no waitrequest). |
| `run_ctrl_agent` | Active Avalon-ST source on `run_ctrl`. Issues 9-bit run-state commands (RUN_PREP, SYNC, RUNNING, TERMINATING, RESET) per the runctl_mgmt_host shared encoding. |
| `egress_st_agent` | Passive monitor on `selected_out`. Records beats and packet boundaries. |
| `scoreboard` | Reference model: per-source FIFO + arbiter + merge-packet FSM + watchdog + counter model. Compares against egress-side observed beats and CSR readback. |
| `assertion_pkg` | SVA module bound into the DUT for SOP/EOP balance, no-tear-on-mode-switch, drop-on-full, counter-clear correctness, watchdog synthesis correctness, run-control reset behaviour. |

The harness must support both reset-per-test execution and continuous no-restart execution (for `bucket_frame` and `all_buckets_frame`).

## 2. Reference Model

The scoreboard runs a deterministic Python-friendly transaction-level model that ingests every accepted beat per source and emits the expected egress beats. The model owns:

- 16-deep ingress FIFO model per source, with full/empty status and a wrap pointer.
- Mode register with `mode_pending` and the egress-side `merged_open` flag; mode commit is observed when `merged_open == 0`.
- Round-robin arbiter state (`last_grant` and pending switch).
- Six 64-bit counters, identical saturating semantics to the DUT.
- Sticky flags `partial_packet_drop_sticky` and `mode_reserved_seen`.

A predicted-vs-observed mismatch on any of these surfaces is a hard test fail.

## 3. Stimulus Knobs

Per-source sequences:

- `bytestream_idle_long_short` — emulator-style packet shapes (12 / 8 / 4 / 1-beat hits in various proportions).
- `lvds_decoded_after_deassembly` — real-MuTRiG style packet shapes (frame-correlated bursts, then idle gaps).
- `single_beat_repeated` — every accepted beat is `sop && eop && valid`.
- `back_to_back_no_idle` — `valid` held high for sustained sequences (worst-case for FIFO occupancy).
- `eor_then_idle` — final packet ends with `endofrun=1`.

CSR sequences:

- `mode_set` (write `CONTROL.mode`)
- `mode_set_W1P_clear` (mode write with bit 2 set)
- `mode_set_with_pending_switch` (write while egress mid-packet, expect deferred commit)
- `counter_full_pair_read` (low then high read pair for atomicity)
- `clear_sticky` (W1P bit 3)

## 4. Assertions (SVA)

`bind`-attached to the DUT. SOP/EOP balance is checked on the **merged egress packet** (single-bit `merged_open`), not per-channel — the merge-packet FSM in §1 of `doc/RTL_PLAN.md` collapses two source frames into one merged Avalon-ST packet:

1. **Egress SOP/EOP balance.** Over any reset-bounded interval, the count of egress beats with `valid && startofpacket` equals the count of beats with `valid && endofpacket`, modulo a single open packet at the end of run (which closes only after row 10 fires).
2. **No nested merged packets.** Two consecutive `valid && startofpacket` beats without an intervening `valid && endofpacket` is forbidden.
3. **Merged_open consistency.** `STATUS.merged_open == (real_open | emu_open)` at every observable read.
4. **Mode-switch defer.** `mode_pending != mode` and `merged_open == 1` → `mode` does not change in the next clock; `mode == mode_pending` may only happen on a clock where `merged_open == 0`.
5. **Drop accounting.** FIFO full + ingress beat with `valid` → drop counter for that source increments by exactly 1 on the next cycle.
6. **Egress hit counter coherence.** `selected_out.valid && last_grant_real` → `EGRESS_REAL_HITS` increments by 1 on the next cycle; symmetric for emu.
7. **EOR final-grant lock.** Egress beat with `egress_eop && egress_eor` → no further egress beats until reset (`merged_locked` sticky-set).
8. **Per-source FIFO order preserved.** For each source, the sequence of egress beats sourced from that source matches the sequence of beats accepted into its FIFO modulo drops.
9. **EOR sticky.** `eor_seen_<source>` is set on the first egress beat from that source carrying `eor=1` and stays set until reset.

## 5. Coverage

Per `DV_COV.md`:

- Functional bins: every `(mode, real_fifo_state, emu_fifo_state)` cell, every mode-transition pair (3 × 3 = 9), every CSR address read and write, every counter saturation event observed at least once, every sticky flag set/clear pair.
- Code coverage: line ≥ 95%, branch ≥ 90%, toggle ≥ 90%.

## 6. Debug Hooks

- `+UVM_VERBOSITY=UVM_HIGH` enables per-beat trace lines.
- `+ARB_DUMP_FIFO=1` plusarg prints FIFO occupancy every clock during regression failures.
- Optional `.gtkw` post-pass via the `gtkwave-reporting` skill for any failing case.

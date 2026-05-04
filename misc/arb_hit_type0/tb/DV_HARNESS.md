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
| `real_st_agent` | Active Avalon-ST source on `real_in`. Drives 45-bit data, error, channel, sop/eop/eor. `valid` controlled per sequence; no `ready` line on the IP side, so the agent is purely supply-side. |
| `emu_st_agent` | Same shape on `emu_in`. |
| `csr_agent` | Active AVMM master on `csr` (4-bit word, 32-bit data, read latency 1, no waitrequest). |
| `egress_st_agent` | Passive monitor on `selected_out`. Records beats and packet boundaries. |
| `scoreboard` | Reference model: per-source FIFO model + arbiter model + counter model. Compares against egress-side observed beats and CSR readback. |
| `assertion_pkg` | SVA module bound into the DUT for SOP/EOP balance, no-tear-on-mode-switch, drop-on-full, counter-clear correctness. |

The harness must support both reset-per-test execution and continuous no-restart execution (for `bucket_frame` and `all_buckets_frame`).

## 2. Reference Model

The scoreboard runs a deterministic Python-friendly transaction-level model that ingests every accepted beat per source and emits the expected egress beats. The model owns:

- 16-deep ingress FIFO model per source, with full/empty status and a wrap pointer.
- Mode register with `mode_pending` and the egress-side `in_packet_active` flag; mode commit is observed at `endofpacket && valid` on egress.
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

`bind`-attached to the DUT:

1. `selected_out.endofpacket -> $past(selected_out.startofpacket, *)` — every EOP has a matching prior SOP on the same source ownership stretch.
2. `mode_change @(posedge clk) |-> ##[0:$] (selected_out.endofpacket && selected_out.valid)` ahead of effective `mode == mode_pending`. (Encoded as a property-level checker.)
3. FIFO full + ingress beat → drop counter for that source increments by exactly 1 in the next cycle.
4. `selected_out.valid && selected_out.endofpacket` → exactly one of `egress_real_hits` or `egress_emu_hits` increments by 1.
5. EOR propagated to egress → no further grants until reset.

## 5. Coverage

Per `DV_COV.md`:

- Functional bins: every `(mode, real_fifo_state, emu_fifo_state)` cell, every mode-transition pair (3 × 3 = 9), every CSR address read and write, every counter saturation event observed at least once, every sticky flag set/clear pair.
- Code coverage: line ≥ 95%, branch ≥ 90%, toggle ≥ 90%.

## 6. Debug Hooks

- `+UVM_VERBOSITY=UVM_HIGH` enables per-beat trace lines.
- `+ARB_DUMP_FIFO=1` plusarg prints FIFO occupancy every clock during regression failures.
- Optional `.gtkw` post-pass via the `gtkwave-reporting` skill for any failing case.

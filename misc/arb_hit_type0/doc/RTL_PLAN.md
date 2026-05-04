# `arb_hit_type0` — RTL Plan

**IP family:** `arb_hit_type0`
**Active release (planned):** `26.2.0.0504`
**Top:** `rtl/arb_hit_type0.sv`
**Companion docs:** [`README.md`](../README.md), [`tb/DV_PLAN.md`](../tb/DV_PLAN.md), [`tb/DV_HARNESS.md`](../tb/DV_HARNESS.md), [`syn/SYN_REPORT.md`](../syn/SYN_REPORT.md)

## 1. Scope

Per-lane arbiter on the **post-deassembly hit_type0** boundary. One instance
per MuTRiG lane. Selects between the real MuTRiG hit_type0 stream
(`mutrig_frame_deassembly.aso_hit_type0`) and the emulator hit_type0 stream
(`emulator_mutrig.aso_hit_type0`, available with `BYTE_STREAM_ENABLE = 0` per
`emulator_mutrig/doc/RTL_PLAN_central_trigger.md`). Output drives the existing
downstream `backpressure_fifo.in` inside `mutrig_datapath_system_v3`, with no
shape change for the consumer.

Three modes:

| Mode | `CONTROL.mode[1:0]` | Behaviour |
|---:|---:|---|
| `REAL` | `2'b00` | Drains the real-input FIFO only; emulator-input FIFO accumulates and drops on overflow. |
| `EMU` | `2'b01` | Drains the emulator-input FIFO only; real-input FIFO accumulates and drops on overflow. |
| `MIX_RR` | `2'b10` | Round-robin between the two FIFOs at packet boundary; both inputs sink concurrently. |
| reserved | `2'b11` | Treated as `REAL` and `STATUS.mode_reserved_seen` is sticky-set. |

Mode change is deferred until the active source is between packets (no
in-flight SOP-without-EOP). A pending request is held in `mode_pending` and
committed when the egress is at packet boundary, so SOP/EOP/EOR atomicity is
preserved end-to-end on every switch.

## 2. Delivered Architecture

```
              +---------------------+
 real_in --->| HIT FIFO (16 deep)  |---+
              +---------------------+    \
                                          \    +-------+   +----------+
                                           +-->|  RR   |-->| egress   |--> selected_out
                                          /    | arb   |   | counters |
              +---------------------+    /     +-------+   +----------+
 emu_in  --->| HIT FIFO (16 deep)  |---+
              +---------------------+
                    |          |
                    v          v
              +-----------------------+
              | ingress + drop counters (64-bit, per lane, per source)  |
              +---------------------------------------------------------+
                                |
                                v
                       AVMM CSR slave (4-bit word, 32-bit data)
```

### 2.1 Per-source ingress FIFO

- 16-deep, 1-cycle latency, store-and-forward at hit granularity.
- Element width = 45 (`data`) + 3 (`error`) + 4 (`channel`) + 3 (sop/eop/eor)
  = **55 bits**. Implemented in distributed RAM (M9K not justified at
  16 entries × 8 lanes × 2 sources = 256 entries total per system).
- Write-side accepts every input beat with `valid = 1`. If the FIFO is full
  and a beat arrives, the beat is dropped and the per-source `drops` counter
  increments. The dropped beat does **not** corrupt an in-flight packet on
  the consumer because the FIFO accepts whole beats only and partial-packet
  drops are not modelled (an SOP without its matching EOP is logged as
  `status.partial_packet_drop_sticky` for diagnostic visibility).
- Read-side draining strategy is per-mode (see RR arbiter below).

### 2.2 Round-robin arbiter

- Operates at packet boundary. A "packet" is the SOP-to-EOP run on a single
  source.
- In `MIX_RR` mode, the arbiter alternates source ownership per packet. After
  a winning source completes its packet (SOP, ..., EOP), ownership flips and
  the other source is granted the next packet **iff** its FIFO is non-empty.
  If only one FIFO has data, it keeps draining without waiting for the empty
  side.
- In `REAL` / `EMU` mode the arbiter is hard-locked to the named source; the
  other FIFO accumulates and overflows but never wins.
- The arbiter never tears a packet across sources. Any source switch always
  occurs on the boundary `egress.endofpacket = 1, egress.valid = 1`.

### 2.3 Counters

Per-lane, per-source 64-bit saturating counters, latched on read for 64-bit
pair atomicity (low word read latches the high word; reading high without
first reading low returns the previously latched high):

- `INGRESS_REAL_HITS` — count of real-input hits (`asi_real_endofpacket && asi_real_valid`)
- `INGRESS_EMU_HITS` — count of emulator-input hits (`asi_emu_endofpacket && asi_emu_valid`)
- `DROPS_REAL` — count of real-input beats dropped because real FIFO was full
- `DROPS_EMU` — count of emulator-input beats dropped because emulator FIFO was full
- `EGRESS_REAL_HITS` — egress hits whose source was real
- `EGRESS_EMU_HITS` — egress hits whose source was emulator

Counters increment on **hit completion** (`endofpacket && valid`) for ingress
and egress. Drops are byte-level and increment **on the dropped beat**, not on
hit completion, because a dropped SOP loses the rest of the hit.

A single-bit `STATUS.partial_packet_drop_sticky` flag is set if a SOP is
accepted into the FIFO but the matching EOP is not (e.g. the FIFO fills
mid-packet). This is a diagnostic flag; the corresponding hit does not count
toward `INGRESS_*_HITS` because the hit was never complete on the source side.

### 2.4 CSR map (4-bit word address, 32-bit data)

| Word | Name | Access | Notes |
|---:|---|---|---|
| `0x0` | `UID` | RO | `0x41485430` (ASCII `AHT0`) |
| `0x1` | `META` | RW/RO | mux 0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID |
| `0x2` | `CONTROL` | RW | bits[1:0]=mode (00=REAL,01=EMU,10=MIX_RR,11=resv); bit[2]=W1P clear counters; bit[3]=W1P clear sticky |
| `0x3` | `STATUS` | RO | live mode, mode_pending, in_packet_active, real_full, real_empty, emu_full, emu_empty, last_grant, partial_packet_drop_sticky, mode_reserved_seen |
| `0x4` | `INGRESS_REAL_HITS_L` | RO | low 32 bits; latches high on read |
| `0x5` | `INGRESS_REAL_HITS_H` | RO | high 32 bits; reads previously latched value |
| `0x6` | `INGRESS_EMU_HITS_L` | RO | |
| `0x7` | `INGRESS_EMU_HITS_H` | RO | |
| `0x8` | `DROPS_REAL_L` | RO | |
| `0x9` | `DROPS_REAL_H` | RO | |
| `0xa` | `DROPS_EMU_L` | RO | |
| `0xb` | `DROPS_EMU_H` | RO | |
| `0xc` | `EGRESS_REAL_HITS_L` | RO | |
| `0xd` | `EGRESS_REAL_HITS_H` | RO | |
| `0xe` | `EGRESS_EMU_HITS_L` | RO | |
| `0xf` | `EGRESS_EMU_HITS_H` | RO | |

`STATUS.last_grant` is 1-bit (0=real, 1=emulator). `STATUS.in_packet_active`
denotes the egress-side in-flight packet flag (used for mode-switch defer).

## 3. Resource Model (target)

| Item | Target |
|---|---|
| ALMs (single instance) | `< 200` |
| Registers (single instance) | `~ 600` (mostly the 64-bit counters: 6 × 64 = 384 bits) |
| RAM blocks | `0` (FIFOs in distributed RAM) |
| DSP blocks | `0` |

Standalone signoff at `137.5 MHz` (`1.1 × 125 MHz`) per the
`timing-performance-resources-sign-off` skill.

## 4. Functional Notes

1. The arbiter is purely combinational up to the `selected_out` register
   stage; the egress beat is registered to keep the `backpressure_fifo`
   side-band timing budget healthy.
2. `endofrun` propagates from whichever source is currently granted. In
   `MIX_RR` mode an EOR on either source is granted at the next packet
   boundary and locks out further grants until reset (matching the
   `mutrig_frame_deassembly` end-of-run semantics).
3. The CSR clock is the same as the data clock (single clock domain). No
   CDC inside the IP.
4. Reset behaviour: on async reset assert, all FIFOs and counters clear,
   `mode <= CONTROL.mode_default` (defaults to `REAL`), `mode_pending` matches
   `mode`, sticky flags clear.

## 5. Open Items

- Whether a third "mix-priority" mode (real always wins on tie) is needed.
  Out of scope for 26.2.0; can be added on a `bit[3]` future encoding.
- Whether per-lane `endofrun` arrival ordering needs an explicit assertion
  contract or if upstream guarantees ordered EORs already.

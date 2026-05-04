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
| `MIX_RR` | `2'b10` | **Beat-level round-robin** between the two FIFOs combined with a **merge-packet FSM** that rewrites egress `sop`/`eop`/`eor` so the consumer sees one merged Avalon-ST packet per `merged_open` window. Each granted beat carries its source's `channel` and `error` sidebands unchanged so the consumer can still demux beats by source. The merged packet boundary is the union of in-flight source-packet windows. See §2.2 for the FSM and the corner-case coverage analysis. |
| reserved | `2'b11` | Treated as `REAL` and `STATUS.mode_reserved_seen` is sticky-set. |

Mode change between `REAL`/`EMU` and `MIX_RR` is deferred until **all
outstanding packets** on the active mode are closed (i.e. neither
`asi_real` nor `asi_emu` packet that has emitted its SOP is still missing
its EOP on the egress side). A pending request is held in `mode_pending`
and committed when both sources are at packet boundary, so SOP/EOP/EOR
atomicity per channel is preserved end-to-end on every switch.

### Why beat-level interleave is safe at this stage

- Each source caps at `1 hit / 3.5 cycles` raw saturation
  (`emulator_mutrig/README.md:89` and the matching real-MuTRiG decoded
  rate). Two sources combine to ≤ `1 hit / 1.75 cycles`, well below the
  `1 beat / cycle` egress capacity — there is no throughput bottleneck,
  so both FIFOs drain without backpressure-induced packet loss.
- The Avalon-ST `channel` sideband disambiguates which source a beat
  belongs to. For one focus-build instance with one real ASIC and one
  emulator lane, set the emulator's `asic_id` to a value distinct from
  the real ASIC's so `channel` uniquely identifies the source on every
  beat. (The `arb_hit_type0` IP itself does **not** rewrite `channel`;
  the downstream contract relies on the upstream having set distinct
  IDs already.)
- A sustained-stress regression in `tb/DV_PROF.md` (P003 `mix_rr_peak`
  and P004 `emulator_raw_3p5_cycles_per_hit`) confirms the FIFO never
  saturates under nominal traffic; counter zero-drop is the gate.

### Downstream-compatibility warning (MIX_RR mode)

The merge-packet FSM (§2.2) collapses two source packets into one
merged Avalon-ST packet, but **`channel` still varies per beat inside
the merged packet** because each beat keeps its source's native
channel. Two consumer-side properties are therefore required:

1. **Single-packet boundary tracking is sufficient.** Downstream needs
   only one outstanding-packet flag, not a per-channel one — the FSM
   guarantees `merged_open` is the union of source `_open` flags and
   never opens nested or overlapping merged packets. This is a
   strict relaxation versus the original "interleaved per-channel
   packets" contract, so any consumer that previously handled the
   single-packet case still works.
2. **Per-beat channel demultiplexing.** If the consumer wants to
   separate the two sources' contributions inside the merged packet
   (e.g. for golden-reference plotting per source), it must read
   `channel` per beat. The Avalon-ST `channel` sideband and
   `maxChannel > 0` declared at `mts_processor.hit_type0_in`
   (`maxChannel = 63`) and `ring_buffer_cam.hit_type1` (`maxChannel = 15`)
   is the **declared contract**; the **implementation** of per-beat
   `channel` use inside those IPs is an audit item before MIX_RR is
   promoted to a production datapath.

The hw.tcl Identity tab and Platform Designer validation callback
carry the verbatim warning and emit a Platform Designer message when
`MODE_DEFAULT = MIX_RR`. Treat MIX_RR as a debug / test-only mode
until the downstream chain is independently verified.

For the focus build, MIX_RR is used only in scoped DV cases and
single-IP standalone tests. The integration into a 4-lane RR follow-on
stage is out of scope for `arb_hit_type0` and is captured as an open
item below.

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

### 2.2 Round-robin arbiter and merge-packet FSM

In `MIX_RR` mode the arbiter is **beat-level**: every cycle each FIFO
with a head-of-queue beat is a candidate, and ownership alternates per
accepted egress beat (`last_grant` toggle). On top of the beat-level
RR, a **merge-packet FSM** rewrites the egress `sop` / `eop` / `eor`
sidebands so the consumer sees **one merged Avalon-ST packet per merged
window**, even when source packets overlap on egress.

In `REAL` / `EMU` mode the arbiter is hard-locked to the named source.
The merge-packet FSM still runs; with only one source contributing
beats it reduces to passthrough (the other source's `_open` flag is
always 0, so the FSM emits the source's native SOP/EOP unchanged).

#### State

| Var | Width | Update | Purpose |
|---|---|---|---|
| `real_open` | 1 | flips on real-sourced egress beats with sop or eop | real-source packet currently in flight on egress |
| `emu_open` | 1 | flips on emu-sourced egress beats with sop or eop | same for emulator |
| `eor_seen_real` | 1, sticky | set on real beat with eor=1, cleared on reset | real has signalled run-end |
| `eor_seen_emu` | 1, sticky | as above for emulator | same |
| `merged_locked` | 1, sticky | set when both `eor_seen_*` are set | locks further grants until reset |
| `last_grant` | 1 | toggles every accepted egress beat | RR pointer, 0=real, 1=emu |

`merged_open = real_open | emu_open` is combinational.

#### Per-egress-beat rewrite

Let the granted source `S ∈ {real, emu}`, and let `was_open_self`,
`was_open_other` be the corresponding `_open` flags before the beat:

| beat.sop | beat.eop | egress.sop | egress.eop | self_open transition |
|---:|---:|---|---|---|
| 1 | 0 | `~was_open_self & ~was_open_other` | 0 | 0 → 1 |
| 0 | 0 | 0 | 0 | unchanged |
| 0 | 1 | 0 | `~was_open_other` | 1 → 0 |
| 1 | 1 | `~was_open_other` | `~was_open_other` | 0 → 0 (net) |

EOR is sticky per source. Egress EOR fires exactly once on the
run-ending merged eop:

```
egress.eor = egress.eop & eor_seen_real_post_update & eor_seen_emu_post_update
```

After that beat, `merged_locked = 1` and the arbiter denies all
further grants until reset.

#### Mode-switch commit

A pending mode commits exactly when `merged_open == 0` (both source
`_open` flags are 0). This is the natural "between merged packets"
boundary and is preserved across all three transitions
`{REAL, EMU, MIX_RR} ↔ {REAL, EMU, MIX_RR}`.

#### Counter semantics

Hit_type0 packs one hit per beat (45-bit hit word) and uses SOP/EOP
to mark the **frame** boundary, not the hit boundary. So:

- `INGRESS_REAL_HITS` += 1 every cycle a real beat is accepted into the real FIFO (`asi_real_valid` true and FIFO not full)
- `DROPS_REAL` += 1 every cycle a real beat is offered but the real FIFO is full (`asi_real_valid` true and FIFO full)
- `EGRESS_REAL_HITS` += 1 every cycle an egress beat is granted from the real source (`aso_valid` true and `last_grant=0`)

Symmetric counters for emu. Frame counting is intentionally not a
counter in this IP; the merge changes frame semantics anyway and any
frame-correlation logic belongs downstream.

#### Invariants enforced by construction

1. `#egress_sop = #egress_eop` over any reset-bounded interval (modulo a final pending packet at run-end), because each is the count of a `merged_open` 0↔1 transition.
2. Per-source FIFO order is preserved end-to-end, so each source's beat sequence on egress matches its ingress sequence modulo drops at full.
3. Merged packets never overlap and never nest (`merged_open` is single-bit).
4. In REAL or EMU mode the egress SOP/EOP/EOR pattern equals the granted source's native pattern beat-for-beat (the FSM degenerates to passthrough when only one `_open` is ever asserted).
5. On reset assert, all FSM state clears and `aso_valid` drops; the downstream sees a clean restart.

#### Coverage of corner cases

The FSM handles:

- Single source active, no overlap (REAL/EMU degenerate path).
- Two sources fully sequential (two independent merged packets).
- Two sources fully overlapping (one merged packet wraps both).
- Single-beat packet from one source while the other is mid-packet (absorbed as middle beat).
- Single-beat packet, both sources idle (merged opens and closes in one egress beat).
- EOR on either source mid-flight (sticky-captured, suppressed eop until both EORs seen).
- EOR from one source while the other's traffic continues (egress EOR holds until both EORs seen — see open-item (a) below).
- Both EORs in adjacent egress cycles (row 9 then row 10, single egress EOR fires).
- CSR mode change anywhere in time (deferred to next `merged_open == 0` boundary).

It does **not** by itself handle:

- (a) Graceful run-end when only one source ever emits EOR. A CSR `force_close_run` W1P bit is the proposed mitigation; tracked as an open item below, not in 26.2.0.
- (b) Upstream protocol violation (two SOPs without an intervening EOP from the same source). The FSM detects this as `was_open_self == 1 && beat.sop == 1` and sets `STATUS.upstream_protocol_violation_sticky`; the offending SOP is forced to 0 on egress so merged state stays consistent. Captured in `tb/DV_ERROR.md`.
- (c) Drop mid-packet (FIFO fills after SOP is admitted but before EOP). `_open` stays 1 forever from the egress side. `STATUS.partial_packet_drop_sticky` flags it on the dropped beat. Mitigation is a CSR `force_close_<source>` W1P pulse that synthesizes the missing EOP. Tracked as an open item, not in 26.2.0.
- (d) Channel collision (real and emu carry the same `channel` value). The FSM does not rewrite channel; upstream must configure distinct `asic_id`s. The `enforce_distinct_channel` parameter is an open item, not in 26.2.0.

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

- A "mix-priority" mode (real always wins on tie) is out of scope for
  26.2.0; can be added on a `bit[3]` future encoding if the RR-fairness
  matrix is found insufficient during integration.
- A 4-lane RR follow-on stage (4 instances of `arb_hit_type0` to one
  multi-channel egress) is the natural next IP. That IP must support
  per-lane `channel` tagging plus SOP/EOP and the same multi-channel
  packetized contract on its egress. It is captured in a separate
  `RTL_PLAN_arb_hit_type0_4to1.md` once `arb_hit_type0` is signed off.
- Per-lane `endofrun` arrival ordering: in `MIX_RR` two sources can both
  emit EOR. The current contract is "the first-granted EOR locks egress;
  the second-granted EOR is also propagated and after that further grants
  are blocked until reset." Verify against the upstream contract during
  DV (case `R010_two_simultaneous_eors`).
- **Hit-processor compatibility audit.** Before `arb_hit_type0` MIX_RR is
  promoted from debug-only into a production datapath, the
  `mutrig_timestamp_processor` and `ring_buffer_cam` implementations
  must be independently verified to track outstanding packets per
  `channel`, not globally. The Avalon-ST channel sideband is declared at
  both interfaces (`mts_processor.hit_type0_in` `maxChannel = 63`,
  `ring_buffer_cam.hit_type1` `maxChannel = 15`) — that is the contract,
  not a pass.

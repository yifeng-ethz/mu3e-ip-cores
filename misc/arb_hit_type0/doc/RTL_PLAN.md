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

### 1.5 Channel mapping convention

Real-MuTRiG hit_type0 beats and emulator hit_type0 beats both carry a
4-bit `channel` field. By **upstream convention**, the two sources use
disjoint channel ranges so per-beat source identification is a free
SignalTap-friendly debug feature inside the merged Avalon-ST packet:

| Source | `channel` range | Meaning |
|---|---|---|
| Real MuTRiG | `4'h0..4'h7` | ASIC ID 0..7 (mapped from `mutrig_frame_deassembly` channel field) |
| Emulator MuTRiG | `4'h8..4'hF` | emulator lane index 0..7 mapped to `0x8 + lane` via the emulator's `asic_id_base` parameter |

The arbiter does not enforce this convention — it passes `channel`
through. Enforcement is at the integration step: the upstream
`emulator_mutrig_qsys_lane.frontend_csr.asic_id_base` must be set so
emu beats land in `[0x8..0xF]`. This is verified at standalone DV
(case `B025_channel_convention`) by checking the egress beat sequence
keeps real beats inside `[0..7]` and emu beats inside `[8..F]` for
the duration of any test that spans both sources.

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
to mark the **frame** boundary, not the hit boundary. So **hits**
(per-beat) and **frames** (per-EOP) are separately observable, and the
IP keeps both:

Per-source **hit** counters (one beat = one hit):

- `INGRESS_REAL_HITS` += 1 every cycle a real beat is accepted into the real FIFO (`asi_real_valid` true and FIFO not full)
- `DROPS_REAL` += 1 every cycle a real beat is offered but the real FIFO is full (`asi_real_valid` true and FIFO full)
- `EGRESS_REAL_HITS` += 1 every cycle an egress beat is granted from the real source (`aso_valid` true and `last_grant=0`)

Per-source **frame** counters (one frame = one source EOP):

- `INGRESS_REAL_FRAMES` += 1 every cycle the real input port presents `asi_real_valid && asi_real_endofpacket`, **regardless of FIFO accept**. Counts upstream-offered frames. The diff `INGRESS_REAL_FRAMES − EGRESS_REAL_FRAMES` is the count of frames lost in this IP (FIFO-full drops on EOP-bearing beats, watchdog-synthesized closes, or upstream-protocol-violation events).
- `EGRESS_REAL_FRAMES` += 1 every cycle a granted egress beat carries source-side eop=1 from the real FIFO (`aso_valid` true, `last_grant=0`, the FIFO entry's `eop` bit set). This is **not** keyed off the merge-FSM-rewritten `aso_endofpacket` — the merge FSM may suppress a source-EOP when the other source is still mid-packet. The frame is counted as soon as that source's frame has fully traversed the egress, even if the merged egress packet stays open.

Symmetric counters for emu (`INGRESS_EMU_HITS`, `DROPS_EMU`, `EGRESS_EMU_HITS`, `INGRESS_EMU_FRAMES`, `EGRESS_EMU_FRAMES`).

In `REAL` and `EMU` mode, `INGRESS_*_FRAMES = EGRESS_*_FRAMES` for the active source under upstream-protocol compliance; in `MIX_RR` mode the equality holds **per source** (the merge FSM doesn't drop frames; it only collapses the merged egress packet boundary). A non-equality is the immediate signal of a fault and the syndrome registers should be inspected.

Watchdog-synthesized egress beats do **not** increment any counter — they are control beats, not hits or frames. The synthesis event itself sets `STATUS.watchdog_synthesized_*` sticky.

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

Out-of-protocol scenarios fall into two classes — recoverable (handled by the frame-alignment watchdog) and non-recoverable (recorded as upstream bugs in error counters and syndrome registers):

- (a) Graceful run-end when only one source ever emits EOR — **recoverable**. After `WATCHDOG_CYCLES` of inactivity from a stranded source while the peer has either EORed or has also been silent, the FAW synthesizes the missing EOP (and EOR if applicable). See §2.3.
- (b) Upstream protocol violation (two SOPs without intervening EOP from the same source) — **intentional upstream bug, not recovered**. The arbiter does not attempt to repair the merged packet because the input stream itself violated the contract; doing so would mask a real hardware fault. Detection sets `STATUS.protocol_violation_sticky`, increments `ERROR_COUNT_PROTOCOL` (saturating 32-bit), and snapshots `SYNDROME_PROTOCOL` (source, prior `_open` state, beat fields, run-state) on the **first** event after reset. The merged packet is left in whatever state the violation produced; downstream is expected to recover at the next reset. See §2.5.
- (c) Drop mid-packet (FIFO fills after SOP is admitted but before EOP) — **intentional upstream bug, not recovered**. Same recording surface: `STATUS.drop_mid_packet_sticky`, `ERROR_COUNT_DROP_MID_PACKET`, `SYNDROME_DROP_MID_PACKET` snapshot on first event. The arbiter relies on the upstream contract that hit_type0 packets either fully fit in a 16-deep ingress FIFO or are emitted slower than the egress can drain — both true for `1 hit / 3.5 cycles` MuTRiG sources. A drop mid-packet means upstream is misbehaving (over-rate or longer-than-FIFO frame); fix upstream rather than mask here.
- (d) Channel collision is **not a fault — it's the convention**. See §1.5.

### 2.3 Frame-alignment watchdog (FAW)

Real and emulator hit_type0 streams are designed to emit frames at the
same MuTRiG frame interval. After both sources have started a run, a
prolonged silence on one source while the peer has either ended its run
or also gone silent is interpreted as "the missing source's last frame
has implicitly ended". The FAW synthesizes the missing EOP (and EOR if
the peer has EORed) so the merged packet closes deterministically.

**State:**

| Var | Width | Update |
|---|---:|---|
| `idle_cycles_real` | 16 | reset on `asi_real_valid`; +1 every cycle otherwise; saturate at `0xFFFF` |
| `idle_cycles_emu` | 16 | symmetric |
| `last_channel_real` | 4 | latched on every real beat with `valid=1` |
| `last_channel_emu` | 4 | symmetric |
| `WATCHDOG_CYCLES` | 16, RW CSR | configurable (default 500); `0` disables the watchdog |
| `STATUS.watchdog_synthesized_real` | 1, sticky | set on real-source synthesis event |
| `STATUS.watchdog_synthesized_emu` | 1, sticky | symmetric |

**Trigger.** FAW fires for source `S` when **all** of:

1. `WATCHDOG_CYCLES != 0`
2. `_open_S == 1` (S is mid-packet on egress)
3. `idle_cycles_S > WATCHDOG_CYCLES`
4. `eor_seen_other == 1` **or** (`_open_other == 0` and `idle_cycles_other > WATCHDOG_CYCLES`)

Condition (4) means the peer is verifiably done (EORed) or also
silent for a comparable interval, so it is safe to declare S also
ended. Without (4), a brief gap on a normally-firing source must
not synthesize an EOP.

**Action.** On the cycle FAW fires for source `S`:

- The arbiter inserts a one-cycle synthesized egress beat that bypasses the FIFO:
  - `aso_valid = 1`
  - `aso_data = 45'h0`
  - `aso_error = 3'b100` (`overflow` bit set; identifies a watchdog-synthesized beat)
  - `aso_channel = last_channel_S`
  - `aso_startofpacket = 0`
  - `aso_endofpacket = 1` (closes merged packet because `_open_other = 0` is implied by the trigger when paired with FSM state at synthesis time)
  - `aso_endofrun = eor_seen_other` (fires merged EOR if the peer had EORed; otherwise the merged packet just closes and a new one can open)
- `_open_S → 0`
- `eor_seen_S → eor_seen_S | eor_seen_other` (mirror peer's EOR if peer was the run-ender)
- `STATUS.watchdog_synthesized_S → 1` sticky
- `EGRESS_<S>_HITS` does **not** increment (the synthesized beat is a control beat, not a real hit)

If both sources are eligible to fire in the same cycle (rare:
both stranded with peer EOR), FAW fires the source whose
`idle_cycles_S` is larger; the other fires next cycle. After the
second fire, both `_open` are 0, both `eor_seen` are 1, and
`merged_locked = 1`.

**Disabling.** `WATCHDOG_CYCLES = 0` disables FAW completely. The
DV negative case (`tb/DV_ERROR.md` `R015`) verifies that a
disabled watchdog leaves the merged packet stuck on a one-sided
EOR run, matching the documented behaviour without watchdog.

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

### 2.4 CSR map (5-bit word address, 32-bit data)

| Word | Name | Access | Notes |
|---:|---|---|---|
| `0x00` | `UID` | RO | `0x41485430` (ASCII `AHT0`) |
| `0x01` | `META` | RW/RO | mux 0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID |
| `0x02` | `CONTROL` | RW | bits[1:0]=mode (00=REAL, 01=EMU, 10=MIX_RR, 11=resv); bit[2]=W1P clear counters; bit[3]=W1P clear sticky; bit[4]=W1P clear error counters; bit[5]=W1P clear syndromes |
| `0x03` | `STATUS` | RO | live mode, mode_pending, merged_open, real_open, emu_open, real_full, real_empty, emu_full, emu_empty, last_grant, partial_packet_drop_sticky, mode_reserved_seen, protocol_violation_sticky, drop_mid_packet_sticky, watchdog_synthesized_real, watchdog_synthesized_emu, run_state[2:0] |
| `0x04` | `WATCHDOG_CYCLES` | RW | `[15:0]` watchdog threshold (default `500`; `0` disables FAW) |
| `0x05` | `WATCHDOG_STATUS` | RO | `[15:0]` `idle_cycles_real`, `[31:16]` `idle_cycles_emu` (live values, saturating at `0xFFFF`) |
| `0x06` | `ERROR_COUNT_PROTOCOL` | RO | 32-bit saturating count of upstream-protocol-violation events |
| `0x07` | `ERROR_COUNT_DROP_MID_PACKET` | RO | 32-bit saturating count of mid-packet drops |
| `0x08` | `SYNDROME_PROTOCOL` | RO | snapshot of first protocol-violation event: `[3:0]` source channel, `[4]` source (0=real, 1=emu), `[5]` `prior_real_open`, `[6]` `prior_emu_open`, `[7]` beat.sop, `[8]` beat.eop, `[11:9]` beat.error, `[14:12]` run_state, `[31:15]` reserved |
| `0x09` | `SYNDROME_DROP_MID_PACKET` | RO | snapshot of first drop-mid-packet event: `[3:0]` source channel, `[4]` source, `[8:5]` FIFO depth at drop, `[9]` source's `_open` at drop, `[12:10]` beat.error, `[15:13]` run_state, `[31:16]` reserved |
| `0x0A` | `INGRESS_REAL_HITS_L` | RO | low 32 bits; latches high on read |
| `0x0B` | `INGRESS_REAL_HITS_H` | RO | high 32 bits; reads previously latched value |
| `0x0C` | `INGRESS_EMU_HITS_L` | RO | |
| `0x0D` | `INGRESS_EMU_HITS_H` | RO | |
| `0x0E` | `DROPS_REAL_L` | RO | |
| `0x0F` | `DROPS_REAL_H` | RO | |
| `0x10` | `DROPS_EMU_L` | RO | |
| `0x11` | `DROPS_EMU_H` | RO | |
| `0x12` | `EGRESS_REAL_HITS_L` | RO | |
| `0x13` | `EGRESS_REAL_HITS_H` | RO | |
| `0x14` | `EGRESS_EMU_HITS_L` | RO | |
| `0x15` | `EGRESS_EMU_HITS_H` | RO | |
| `0x16` | `INGRESS_REAL_FRAMES_L` | RO | per-source upstream-offered frames; low 32 bits; latches high on read |
| `0x17` | `INGRESS_REAL_FRAMES_H` | RO | high 32 bits; reads previously latched value |
| `0x18` | `INGRESS_EMU_FRAMES_L` | RO | |
| `0x19` | `INGRESS_EMU_FRAMES_H` | RO | |
| `0x1A` | `EGRESS_REAL_FRAMES_L` | RO | per-source frames whose source-EOP traversed egress; low 32 bits; latches high on read |
| `0x1B` | `EGRESS_REAL_FRAMES_H` | RO | high 32 bits; reads previously latched value |
| `0x1C` | `EGRESS_EMU_FRAMES_L` | RO | |
| `0x1D` | `EGRESS_EMU_FRAMES_H` | RO | |
| `0x1E..0x1F` | reserved | RO | reads as zero |

`STATUS.last_grant` is 1-bit (0=real, 1=emulator). `STATUS.merged_open`
is the union flag used for mode-switch defer. `STATUS.run_state[2:0]`
is the decoded run-control state observed on the `run_ctrl` AVST sink.

## 3. Resource Model (target)

| Item | Target |
|---|---|
| ALMs (single instance) | `< 250` |
| Registers (single instance) | `~ 850` (mostly the ten 64-bit counters: 10 × 64 = 640 bits) |
| RAM blocks | `0` (FIFOs in distributed RAM) |
| DSP blocks | `0` |

Standalone signoff at `137.5 MHz` (`1.1 × 125 MHz`) per the
`timing-performance-resources-sign-off` skill.

### 2.5 Error counters and syndromes (upstream-bug recording)

Two saturating 32-bit counters and two latch-once syndrome words
record upstream-bug events without attempting recovery. These are the
**only** error-recording surface in the IP; sticky bits live in
`STATUS` (§2.4 word `0x03`), counters in `0x06`/`0x07`, syndromes in
`0x08`/`0x09`. The arbiter keeps operating after these events but the
merged packet semantics are no longer trustworthy — the only
guaranteed recovery is a clean reset (which the run-control sink in
§2.6 will apply on the next `RUN_PREP` or `RESET` state).

| Field | Trigger | Recorded |
|---|---|---|
| `ERROR_COUNT_PROTOCOL` | egress beat with `was_open_self == 1 && beat.sop == 1` from one source | +1 saturating |
| `SYNDROME_PROTOCOL` | first such event after sticky clear | source, prior `_open` flags, beat fields, run_state |
| `STATUS.protocol_violation_sticky` | as above | sticky-set; W1P clear via `CONTROL.bit[5]` |
| `ERROR_COUNT_DROP_MID_PACKET` | beat with `valid && fifo_full` from one source while that source's `_open == 1` | +1 saturating |
| `SYNDROME_DROP_MID_PACKET` | first such event after sticky clear | source, FIFO depth at drop (`[5:0]` to encode `0..16`), beat fields, run_state |
| `STATUS.drop_mid_packet_sticky` | as above | sticky-set; W1P clear via `CONTROL.bit[5]` |

The syndrome words record only the **first** event per sticky-cleared
window so the original cause stays visible for SignalTap/SC tool
inspection while subsequent events still bump the counters.

Diagnostic check (host-side software): for each source, audit
`INGRESS_*_FRAMES`, `EGRESS_*_FRAMES`, `DROPS_*`,
`ERROR_COUNT_DROP_MID_PACKET`, `ERROR_COUNT_PROTOCOL`,
`STATUS.partial_packet_drop_sticky`, `STATUS.drop_mid_packet_sticky`,
and `STATUS.protocol_violation_sticky`. A clean run satisfies
`INGRESS_<S>_FRAMES == EGRESS_<S>_FRAMES` and all sticky / error
counters at zero.

### 2.6 Run-control sink

A standard 9-bit `asi_ctrl_*` Avalon-ST sink mirrors the contract
documented at `mutrig_timestamp_processor/mts_processor_hw.tcl:484` and
`emulator_mutrig/emulator_mutrig_hw.tcl` (interface `ctrl`). The IP
decodes the run-state per the shared run-control encoding owned by
`runctl_mgmt_host` and exposes the decoded state at
`STATUS.run_state[2:0]`.

| State observed | Internal effect |
|---|---|
| `IDLE` | normal operation; counters and FIFOs hold |
| `RUN_PREP` | **synchronous internal reset** — flush both ingress FIFOs, clear `_open`, `eor_seen`, `merged_locked`, `mode_pending → CONTROL.mode_default`, `STATUS.*_sticky` clear, `STATUS.watchdog_synthesized_*` clear, idle counters cleared. Counter pairs **not cleared** (so software can audit pre-prep counters during prep); explicit `CONTROL.bit[2]` clear remains the way to zero counters. |
| `SYNC` | normal operation |
| `RUNNING` | normal operation |
| `TERMINATING` | normal operation; FAW continues to run |
| `RESET` | **synchronous internal reset** — same as `RUN_PREP`, plus counters cleared and `ERROR_COUNT_*` cleared, syndromes cleared. Equivalent to a soft reset. |

The internal reset is single-cycle and synchronous — no asynchronous
reset path beyond the global `rst` input. This keeps STA simple and
matches the staged-reset pattern documented in
`/home/yifeng/CLAUDE.md` "Staged Reset Trick" rule.

The IP does **not** ack run-control commands on a separate path; it
only observes the broadcast state.

## 4. Functional Notes

1. The arbiter is purely combinational up to the `selected_out` register
   stage; the egress beat is registered to keep the `backpressure_fifo`
   side-band timing budget healthy.
2. `endofrun` propagates only on the merged-packet-closing beat once
   both `eor_seen` flags are set (or synthesized by FAW). After that the
   `merged_locked` sticky bit blocks further grants until reset or until
   run-control transitions to `RUN_PREP`/`RESET`.
3. The CSR clock is the same as the data clock (single clock domain). No
   CDC inside the IP.
4. Reset behaviour:
   - **Hard reset (`rst` asserted):** all FIFOs and counters clear, mode
     reverts to `CONTROL.mode_default`, every sticky and counter clears.
   - **Run-control `RUN_PREP` or `RESET`:** synchronous internal flush per
     §2.6; selected counters preserved as documented in that section.

## 5. Open Items

- A "mix-priority" mode (real always wins on tie) is out of scope for 26.2.0; can be added on a future `CONTROL.mode[2]` encoding if the RR-fairness matrix is found insufficient during integration.
- A 4-lane RR follow-on stage (4 instances of `arb_hit_type0` to one multi-channel egress) is the natural next IP. That IP must support per-lane `channel` tagging plus SOP/EOP and the same multi-channel packetized contract on its egress. Captured in a separate `RTL_PLAN_arb_hit_type0_4to1.md` once `arb_hit_type0` is signed off.
- **Per-beat channel demux audit at downstream consumers.** Before `arb_hit_type0` MIX_RR is promoted from debug-only into a production datapath, `mutrig_timestamp_processor` and `ring_buffer_cam` must be independently verified to use per-beat `channel` for source attribution inside a single Avalon-ST packet. `maxChannel = 63` at `mts_processor.hit_type0_in` and `maxChannel = 15` at `ring_buffer_cam.hit_type1` declare the contract; the implementation audit is the gate.

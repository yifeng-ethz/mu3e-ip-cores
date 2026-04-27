# DV_FORMAL: FEB SciFi v3 integration — packet-shape formal plan

**Companion to:** `DV_INT_PLAN.md`, `docs/HARNESS_LAYOUT.md`, `cases/{rc,sc,dp}.md`, `BUG_HISTORY.md`
**Author:** Yifeng Wang (yifenwan@phys.ethz.ch)
**Date:** 2026-04-17
**Status:** Active formal-readiness plan for the `INT_fe_scifi_v3-2026-04-17` integration harness. This plan covers the run-control (RC), slow-control (SC) and datapath (DP) domains of `feb_system_v3` and the CDC seams between them. It is the integration-scope companion to `packet_scheduler/tb/DV_FORMAL.md` (which covers the ordered-priority-queue IP in isolation) and is scoped to be about five times larger because the integration DUT decomposes into three parallel packet-based data planes and the seams between them.

This document folds in the packet-shape methodology from Doug Smith,
"Doing the Impossible: Using Formal Verification on Packet Based Data Paths"
(DVCon US 2023; video: <https://youtu.be/SbdgOf4Zf1o>; paper:
<https://dvcon-proceedings.org/wp-content/uploads/1032-Doing-the-Impossible-Using-Formal-Verification-on-Packet-Based-Data-Paths.pdf>).
The methodology is used to *bound the state space* of the RC/SC/DP packet
paths so formal tools can close structural, ordering, flow-control and CDC
properties at every IP boundary that the integration harness currently drives
from a source-level UVM-like bench.

The intent here is that every property in this plan should be translatable to
real SVA/PSL and bound at a concrete DUT boundary in the generated Qsys
hierarchy. Where an internal signal name is quoted in backticks, it is the
name that appears in the active RTL today (per the IP boundary maps in
`run-control_mgmt/`, `debug_sc_system_v3.qsys`, `scifi_datapath_system_v3.qsys`,
`feb_system_v3.qsys`, and the exported generated files under
`firmware_builds/feb_system_v3/synthesis/submodules/`). The scope intentionally
stops at the boundary of each IP and at the seams between them — it does not
re-prove internal-to-IP contracts that the per-IP DV_FORMAL documents cover
(for example, the OPQ internal data-mover proofs are not restated here).

---

## Table of contents

- [0. Summary of the seven-step methodology](#0-summary-of-the-seven-step-methodology)
- [1. System topology and proof-plane partition](#1-system-topology-and-proof-plane-partition)
- [2. Run-Control (RC) plane](#2-run-control-rc-plane)
  - [2.1 Sub-plane R1 — runctl_mgmt_host synclink ingress](#21-sub-plane-r1--runctl_mgmt_host-synclink-ingress)
  - [2.2 Sub-plane R2 — runctl_mgmt_host command decode FSM](#22-sub-plane-r2--runctl_mgmt_host-command-decode-fsm)
  - [2.3 Sub-plane R3 — runctl_mgmt_host upload ACK packet generator](#23-sub-plane-r3--runctl_mgmt_host-upload-ack-packet-generator)
  - [2.4 Sub-plane R4 — run_control_splitter 16-way fanout](#24-sub-plane-r4--run_control_splitter-16-way-fanout)
  - [2.5 Sub-plane R5 — RC sinks (consumer-side AVST conformance)](#25-sub-plane-r5--rc-sinks-consumer-side-avst-conformance)
  - [2.6 Sub-plane R6 — upload_cdc_fifo (125 MHz → 156.25 MHz)](#26-sub-plane-r6--upload_cdc_fifo-125-mhz--15625-mhz)
  - [2.7 Sub-plane R7 — upload_pkt_mux three-source merge (link 0)](#27-sub-plane-r7--upload_pkt_mux-three-source-merge-link-0)
- [3. Slow-Control (SC) plane](#3-slow-control-sc-plane)
- [4. Datapath (DP) plane](#4-datapath-dp-plane)
- [5. Cross-plane interactions](#5-cross-plane-interactions)
- [6. CDC and reset-ownership plane](#6-cdc-and-reset-ownership-plane)
- [7. Boundary-condition matrix](#7-boundary-condition-matrix)
- [8. Tool and flow plan](#8-tool-and-flow-plan)
- [9. Trace to current sim cases](#9-trace-to-current-sim-cases)
- [10. Open items and signoff scope](#10-open-items-and-signoff-scope)

---

## 0. Summary of the seven-step methodology

From the DVCon paper, reproduced as the skeleton we apply per-boundary:

1. **Model the control logic** — capture the handshake (valid / SOP / EOP /
   ready / startofpacket / endofpacket / channel / error, plus AVMM
   `read` / `write` / `waitrequest` / `readdatavalid` / `burstcount` / `byteenable`)
   as assumptions so formal only explores legal framings and legal AVMM
   protocol phases.
2. **Define the packet structure** — break each frame into small typed
   chunks (`typedef struct packed`) so each field has a dedicated, small
   state space; wrap the chunks in a `union packed` whose `qbits` member
   flattens onto the DUT bus. The integration has three distinct packet
   shapes that must each be modelled separately: the 9-bit synclink /
   run-control word, the 36-bit upload/upper/lower frame word with K-flag
   and channel tag, and the 36-bit SC download conduit with packed
   K-character nibble.
3. **Define the packet constraints** — one named property per chunk that
   pins its `kind`, `length`, and the legal values of its fields; a
   `packet_info[n].total_length` trick lets each chunk reach into
   `packet_info[n+1]` to carry derived lengths across the frame. The
   frame-length propagation is especially important on the SC download
   path, where the length word in the header dictates how many data
   words the body must contain, and on the DP frame-assembly seam,
   where the hit count in the subheader dictates the legal count of
   hit words that may follow before the trailer closes the frame.
4. **Apply the packet constraints** — a top-level `prop_pkt(n)` dispatches on
   `packet_info[n].kind` with an `if / else if` cascade, calling the
   right chunk property with index `n+1`. This is what telescopes an
   arbitrarily long legal frame out of a cascade of local constraints.
5. **Model the packet driving logic** — a synthesisable driver walks the
   `packet[p].qbits[n]` array onto the bus, handling any tool-specific
   bit stuffing / bus-width conversion and honouring the sink-side
   ready/waitrequest backpressure so the same driver works under
   `assume` stimulus and `cover` witness generation.
6. **Generate the packet** — `assume property` over the top-level property,
   plus `$stable(packet)` / `$stable(packet_info)` during transfer so the
   frame is fixed once formal picks it. A `pkt_good` flag flips constraints
   between "valid frame" and "invalid frame" via `if (pkt_good) prop_x
   else not(prop_x)` so the same harness can prove both acceptance and
   malformed-frame detection. We reuse this same pattern for every
   domain below; the integration-level harness only has to add a
   per-domain `pkt_good` that may be bound to the RC/SC/DP sub-harness
   choice.
7. **Check the packets** — assertions on the DUT's parsing / acceptance /
   reporting behaviour. `cover property` on `prop_transfer` gives a
   human-readable waveform proving the generator is wired up correctly
   at every seam, from the synclink byte stream at `runctl_mgmt_host`
   all the way to the 36-bit upload word at the SWB PHY ingress stub.

The leverage is: the payload bits are free, but the `kind`, `length`, and
field-level constraints are tiny, so the valid *state space* is small even
when the raw frame is large. The integration DUT spans three payload widths
(9-bit RC, 36-bit SC, 36-bit DP) with three grammars (bare-byte RC, K-symbol
bounded SC packets, hit_type0/1/3 nested frames on DP) and the integration
formal plan reuses the same seven steps per plane, per sub-plane, and per
cross-plane seam.

We add one integration-only extension to the DVCon skeleton:

0a. **Seam consistency invariants (step 7a)** — for every seam between two
    planes, define a bidirectional equivalence between the producer's egress
    packet grammar and the consumer's ingress packet grammar, plus a bounded
    latency / bounded buffer property so the two planes cannot drift
    independently. This is the integration-specific property that the per-IP
    DV_FORMAL documents do not need. We express it as a pair of
    `assume`/`assert` couples across the seam, one in each direction. The
    seam is the unit of composition, so every seam gets an explicit entry
    in §5 and §6.

---

## 1. System topology and proof-plane partition

### 1.1 System topology as used by this harness

The `INT_fe_scifi_v3-2026-04-17` harness exercises `feb_system_v3` which
composes, at the Qsys level:

```
feb_system_v3
  ├── upload_subsystem (instance of upload_system_v3)
  │     ├── runctl_mgmt_host_0  (RC word receiver + ACK packet generator)
  │     ├── upload_cdc_fifo      (125 MHz → 156.25 MHz ACK path)
  │     ├── upload_pkt_mux       (3-to-1 merge: upper frames + SC + RC ACK)
  │     └── exported ports:
  │           upload_data0_sc_rc_* (link 0, 36-bit merged)
  │           runctl_mgmt_host_data[8:0] (RC word seam into data plane)
  │
  ├── control_path_subsystem (instance of debug_sc_system_v3)
  │     ├── sc_hub              (sc_hub_v2, 18-bit word-addressed AVMM master)
  │     ├── sc_hub_cmd_pipe     (pipeline bridge, MAX_BURST_SIZE=256)
  │     ├── control-path slaves: scratch_pad_ram, onewire, max10, charge_inj,
  │     │                         firefly, on_die_temp_sense, mutrig_cfg_ctrl
  │     ├── mm_bridge           (gateway to datapath apertures, s0 at 0x20000)
  │     └── exported ports:
  │           download_sc                 (36-bit K-flag packet ingress)
  │           mm_pipeline_avmm_lvds_m0_*  (14-bit word-addressed AVMM out)
  │
  ├── data_path_subsystem (instance of scifi_datapath_system_v3)
  │     ├── 8× emulator_mutrig_N         (programmable hit generators, N=0..7)
  │     ├── 8× decoded_lane_mux_N        (real-vs-emulator source mux)
  │     ├── 8× decoded_lane_fifo_N       (shallow FIFO, 128×45)
  │     ├── 8× mutrig_datapath_subsystem_N
  │     │     ├── mutrig_frame_deassembly_0
  │     │     └── backpressure_fifo (128×45, USE_PACKETS=1)
  │     ├── 2× mux_mutrig2processor (4:1 RR) / mux_mutrig2processor_0
  │     ├── 2× mts_preprocessor_0/1      (hit_type0 → hit_type1 timestamp)
  │     ├── 2× hit_stack_subsystem_0/1
  │     │     ├── 4× ring_buffer_cam     (hit-stack storage)
  │     │     └── feb_frame_assembly_0   (produces hit_type3)
  │     ├── 2× histogram_statistics_0/1  (exported AVMM window)
  │     ├── run_control_splitter         (9-bit → 16× 9-bit fanout)
  │     ├── mutrig_injector_0            (headerinfo → per-lane inject_pulse)
  │     ├── lvds_rx_controller_pro_0     (LVDS PHY + 8-lane decode)
  │     └── exported ports:
  │           hit_type3_upper_*  (36-bit, to upload_subsystem.upload_data)
  │           hit_type3_lower_*  (36-bit, to feb_system_v3.upload_data1)
  │
  └── exported upload links:
        upload_data0_sc_rc_*  (link 0, 36-bit, channel[1:0] for upper/SC/RC ACK)
        upload_data1_*        (link 1, 36-bit, hit_type3_lower only)
```

This composition has three packet-bearing top-level seams that the SWB PHY
ingress stub in `tb_src/swb_phy_ingress_stub.vhd` observes today:

- RC seam: the 9-bit stream entering `runctl_mgmt_host_0.synclink` from the
  harness, and the 9-bit broadcast out of `run_control_splitter.outN`.
- SC seam: the 36-bit `download_sc` K-flag packet entering `sc_hub`, and the
  per-slave AVMM phases observed at the `sc_hub_cmd_pipe.m0` interconnect.
- DP seam: the 36-bit `hit_type3_upper` and `hit_type3_lower` frames exiting
  `data_path_subsystem`, and the 36-bit `upload_data0_sc_rc` / `upload_data1`
  frames observed on the SWB side.

### 1.2 Proof-plane partition

The integration DUT decomposes into three large packet planes (RC, SC, DP)
and two auxiliary planes (CDC, cross-plane). Each plane is further
sub-partitioned into sub-planes so that each sub-plane has a single
entry-side and single exit-side contract that a modern formal tool can
handle in one shot. The partition follows the Qsys module boundaries so
that a proof failure can be tied to a single IP's RTL changes without
replaying the entire integration.

| Plane | Sub-planes | Entry contract | Exit contract | Internal state the plane owns |
|---|---|---|---|---|
| RC | R1..R7 | 9-bit AVST at `runctl_mgmt_host_0.synclink` | 16× broadcast at `run_control_splitter.outN` + 36-bit ACK at `upload_cdc_fifo.out` | `runctl_mgmt_host` decode FSM, command byte table, ACK sequencer, CDC FIFO occupancy, splitter stall resolver |
| SC | S1..S8 | 36-bit K-flag at `download_sc` | per-slave AVMM phase at every `sc_hub_cmd_pipe.m0` branch | sc_hub packet RX FSM, command/response pipeline, per-slave decode, timeout counters, response framer |
| DP | D1..D10 | per-lane 9-bit emulator/LVDS word | 36-bit `hit_type3_upper`/`hit_type3_lower` frames | 8× emulator CSR state + PRNG, 8× shallow FIFO occupancy, 8× frame-deassembly FSM + backpressure FIFO, 2× RR mux counter, 2× MTS pipeline, 2× 4-way ring_buffer_cam + frame-assembly FSM, 2× histogram accumulator + bin RAM |
| CX | C1..C4 | two-sided (RC-SC, RC-DP, SC-DP, RC-SC-DP) | two-sided bidirectional equivalence | shared run-state across planes, shared CSR aperture, upload mux ordering |
| CDC | X1..X6 | per-seam clock/reset pair | per-seam clock/reset pair with bounded latency and no metastability-visible beats | per-CDC FIFO occupancy, gray-coded pointers, reset-release ordering |

The proof planes are dependency-ordered only within each large plane
(RC: R1 → R2 → R3 → R6 → R7, R1 → R4 → R5; SC: S1 → S2 → S3/S4/S5 → S8;
DP: D1 → D2 → D3 → D4 → D5 → D6 → D7 → D9, D4 → D9, D8 built into D7,
D10 parallel fan-in). Across the planes, the order is RC → DP (run-state
gating), SC → DP (CSR during live traffic), DP → RC (upload mux mixes
upper frames with RC ACK on link 0), and SC → RC (both on link 0).
Each sub-plane constrains its *input* side via `assume` packets that
obey the previous sub-plane's *output* contract — the same packet shape
is reused as both assertion and assumption, which is the leverage the
DVCon paper calls out in §V, extended to integration scope by reusing
the seam as the composition boundary.

### 1.3 What this plan does and does not prove

In scope for integration formal:

- Structural framing of every packet at every seam (no illegal header,
  no dangling EOP, no midstream SOP, no K-character in a data position,
  no hit count that does not match the subheader's `hit_cnt` field).
- Flow-control at every seam (no valid drop without ready/waitrequest,
  no ready glitch mid-beat, no burst abort without a corresponding
  error flag, no WAITING_WRITE_SPACE drop on held-stable repeat words).
- Run-state gating at every RC consumer (no hit accumulation when
  `run_ctrl != RUNNING`, no frame opened during TERMINATING, no
  reset-controller pulse during RUNNING unless explicitly commanded).
- Address decode at every SC aperture (no wrong-slave hit, no decode
  error without an error response, no burst crossing slave boundaries
  without fragmentation, no held-stable address during a multi-beat
  burst read with `waitrequest=0`).
- CDC correctness at every clock seam (no metastability-visible beat,
  no drop on release-side readout, gray-coded pointer monotonicity,
  bounded latency through each CDC FIFO).
- Seam equivalence between every producer-consumer pair (upper/lower
  frame-count monotonicity, ACK/frame ordering on link 0, RC fanout
  completeness to all 16 consumers before the next RC word is
  accepted).

Out of scope for this plan (covered by per-IP DV_FORMAL docs or not
covered by any formal flow today):

- Internal OPQ data-mover proofs (see `packet_scheduler/tb/DV_FORMAL.md`
  for planes A..F of the OPQ monolithic SV DUT; the packet scheduler is
  not instantiated in this integration but the methodology pattern is
  intentionally the same).
- Internal hit-stack ring_buffer_cam proofs (see
  `ring-buffer_cam/tb/DV_FORMAL.md` if and when that IP grows one).
- Internal MTS LUT correctness (the decode ROM is taken as trusted at
  this scope).
- Power-gating, low-power, or clock-gating transitions beyond the
  datapath-clock gating already described in the RC contract.
- Serdes-level CRC/8B10B correctness on the external LVDS PHY
  (`lvds_rx_28nm_0` transceiver) — the LVDS domain is taken as
  bit-accurate once it leaves the PHY.

---

## 2. Run-Control (RC) plane

### 2.0 RC plane overview

The RC plane decomposes the run-control path from the external synclink
bytes at `upload_subsystem.runctl_mgmt_host_data` all the way to the 16
fanout outputs of `run_control_splitter` in `scifi_datapath_system_v3`.
The plane also owns the ACK return path (`aso_upload_*` out of
`runctl_mgmt_host` into `upload_cdc_fifo`, then merged by `upload_pkt_mux`
onto link 0).

The RC packet grammar is byte-oriented, not frame-oriented. Each RC word
is a single 9-bit AVST beat (`sideband=1`, `valid=1`, no SOP/EOP). The
word table is:

| Mnemonic | Hex | Binary (bit[8..0]) | Semantics |
|---|---|---|---|
| `CMD_RUN_PREPARE` | 0x10 | 0 0001 0000 | initiate preparation state |
| `CMD_RUN_SYNC`    | 0x11 | 0 0001 0001 | synchronization pulse |
| `CMD_START_RUN`   | 0x12 | 0 0001 0010 | begin data acquisition |
| `CMD_END_RUN`     | 0x13 | 0 0001 0011 | terminate current run |
| `CMD_ABORT_RUN`   | 0x14 | 0 0001 0100 | abort active run |
| `CMD_START_LINK_TEST` | 0x20 | 0 0010 0000 | enter link-test pattern state |
| `CMD_STOP_LINK_TEST`  | 0x21 | 0 0010 0001 | leave link-test pattern state |
| `CMD_START_SYNC_TEST` | 0x24 | 0 0010 0100 | enter sync-test pattern state |
| `CMD_STOP_SYNC_TEST`  | 0x25 | 0 0010 0101 | leave sync-test pattern state |
| `CMD_TEST_SYNC`       | 0x26 | 0 0010 0110 | issue sync-test pattern state |
| `CMD_RESET`       | 0x30 | 0 0011 0000 | single-byte reset distribution |
| `CMD_STOP_RESET`  | 0x31 | 0 0011 0001 | end reset state |
| `CMD_ENABLE`      | 0x32 | 0 0011 0010 | enable datapaths |
| `CMD_DISABLE`     | 0x33 | 0 0011 0011 | disable datapaths |
| `CMD_ADDRESS`     | 0x40 | 0 0100 0000 | set address for CSR access |

Additionally, the splitter carries a one-hot datapath run-state byte
(not a command byte) on some sub-seams:

| State | Bit | Semantics |
|---|---|---|
| `IDLE` | 0 | datapath idle |
| `RUN_PREPARE` | 1 | preparing |
| `SYNC` | 2 | sync alignment |
| `RUNNING` | 3 | acquisition |
| `TERMINATING` | 4 | graceful drain |
| `LINK_TEST` | 5 | link-test pattern |
| `SYNC_TEST` | 6 | sync-test pattern |
| `RESET` | 7 | reset distribution |
| `OUT_OF_DAQ` | 8 | out-of-DAQ |

Two different 9-bit encodings share the same bus width by convention.
The runctl_mgmt_host translates command bytes into run-state one-hot
internally; the splitter and its 16 sinks expect the one-hot form.
The ACK path carries command-byte acknowledgments (36-bit packets on
the upload path), not one-hot state.

### 2.1 Sub-plane R1 — runctl_mgmt_host synclink ingress

#### 2.1.1 Boundary signals

Source RTL: `run-control_mgmt/rtl/runctl_mgmt_host.sv`
Top-level seam: `feb_system_v3.upload_subsystem_runctl_mgmt_host_data[8:0]`

AVST sink:
- `asi_synclink_data[8:0]` — 9-bit incoming command byte (bit 8 = K-flag, bits[7:0] = data or K-symbol code)
- `asi_synclink_valid`
- `asi_synclink_ready` (output)
- `asi_synclink_error[2:0]` — [0] loss-of-sync, [1] parity, [2] 8b/10b decode

Clock: `lvdspll_clk` = 125 MHz (LVDS recovered reference)
Reset: `lvdspll_reset` = async-assert, sync-release on lvdspll_clk

#### 2.1.2 Step 1 — control-signal handshake assumptions

The synclink AVST sink expects a standard Altera AVST contract. We model
it as:

```systemverilog
asm_synclink_valid_is_1bit: assume property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    $isunknown(asi_synclink_valid) == 0);

asm_synclink_data_stable_while_blocked: assume property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (asi_synclink_valid && !asi_synclink_ready) |=>
      (asi_synclink_valid && $stable(asi_synclink_data) && $stable(asi_synclink_error)));

asm_synclink_error_is_legal: assume property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    asi_synclink_valid |-> asi_synclink_error inside {3'b000, 3'b001, 3'b010, 3'b100});
```

The "error inside legal set" constraint excludes combined-bit error
codes because the LVDS PHY never asserts two error flags in the same
beat (verified by inspection of `lvds_rx_controller_pro_0`'s 8b/10b
decoder output).

#### 2.1.3 Step 2 — RC word structure (typed chunk)

The ingress stream has no packet grammar, only per-beat structure:

```systemverilog
typedef enum logic [3:0] {
  RC_KIND_DATA,       // bit8=0, bits[7:0] = command byte
  RC_KIND_KCHAR,      // bit8=1, bits[7:0] = K-symbol (expected: K28.5 = 0xBC)
  RC_KIND_ERRORED,    // error[2:0] != 0 (drops downstream)
  RC_KIND_NONE
} rc_kind_t;

typedef struct packed {
  bit [3:0] kind;
  bit [7:0] payload; // data byte or K-symbol code
  bit [2:0] error;
} rc_beat_t;
```

Unlike the OPQ ingress, there is no frame-length tracking because the RC
stream is a continuous byte dribble with no SOP/EOP. Each beat is
independently typed.

#### 2.1.4 Step 3 — per-beat field constraints

```systemverilog
asm_rc_data_beat_legal: assume property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (asi_synclink_valid && asi_synclink_data[8] == 1'b0 && asi_synclink_error == 3'b0)
      |-> asi_synclink_data[7:0] inside {
        8'h10, 8'h11, 8'h12, 8'h13, 8'h14,
        8'h30, 8'h31, 8'h32, 8'h33, 8'h40,
        8'h00  // explicit NOP (idle fill)
      });

asm_rc_kchar_legal: assume property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (asi_synclink_valid && asi_synclink_data[8] == 1'b1 && asi_synclink_error == 3'b0)
      |-> asi_synclink_data[7:0] inside {
        8'hBC, 8'hF7, 8'h9C, 8'h1C, 8'h3C, 8'h7C, 8'hDC  // canonical K-codes
      });
```

The data-beat whitelist comes straight from the command byte table in
§2.0. It explicitly excludes 8'h15..8'h2F and 8'h41..8'hFF so formal
does not have to search the whole 256-value byte space. We can widen
the set with `CMD_ADDRESS` payload bytes (0x41..0x4F) if and when the
address-setting command is exercised in the bench.

#### 2.1.5 Step 4 — no cascade needed (stateless per beat)

The RC ingress is stateless on a per-beat basis; the cascade pattern
from the DVCon paper collapses into a single-kind property per beat.
We still record a trivial `prop_pkt(n)` that forwards to the beat
property, for uniformity with the other planes:

```systemverilog
property prop_rc_beat(int unsigned n);
  packet_info[n].kind == RC_KIND_DATA  ? prop_rc_data (n) :
  packet_info[n].kind == RC_KIND_KCHAR ? prop_rc_kchar(n) :
  packet_info[n].kind == RC_KIND_ERRORED ? prop_rc_error(n) : 1'b1;
endproperty
```

The `prop_rc_error` variant lets us flip `pkt_good=0` and drive a beat
whose `error[2:0] != 0` to verify the DUT's rejection path.

#### 2.1.6 Step 5 — driver

The driver is a one-beat shift-register: it asserts `asi_synclink_valid`
when `packet_info[n].kind != RC_KIND_NONE`, puts `packet_info[n].payload`
on `asi_synclink_data[7:0]` and `(kind == RC_KIND_KCHAR)` on bit 8, and
advances to `n+1` on `asi_synclink_ready`. The driver model is trivially
synthesisable.

#### 2.1.7 Step 6 — assume / generate

Generation uses a standard `assume property(disable iff (lvdspll_reset) prop_rc_beat(0) implies $stable(packet_info))` so formal fixes the sequence once it is picked, exactly as the DVCon paper does for CAN frames.

#### 2.1.8 Step 7 — acceptance / rejection assertions

We assert the following DUT behaviours:

```systemverilog
ast_rc_data_reaches_decoder: assert property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (asi_synclink_valid && asi_synclink_ready && asi_synclink_data[8] == 1'b0
     && asi_synclink_error == 3'b0)
      |=> ##[1:3] rc_decoder_saw_byte && rc_decoder_last_byte == $past(asi_synclink_data[7:0]));

ast_rc_error_does_not_fan_out: assert property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (asi_synclink_valid && asi_synclink_ready && asi_synclink_error != 3'b0)
      |=> !$rose(aso_runctl_valid));

ast_rc_kchar_does_not_fan_out: assert property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (asi_synclink_valid && asi_synclink_ready && asi_synclink_data[8] == 1'b1)
      |=> !$rose(aso_runctl_valid));
```

The third assertion captures the invariant that K-characters (which are
framing markers on the synclink bit-stream, not commands) never produce a
fanout event.

The ready-side backpressure assertion is:

```systemverilog
ast_rc_ready_never_glitches: assert property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    $rose(asi_synclink_ready) |-> asi_synclink_ready throughout (asi_synclink_valid));
```

This captures the fact that `runctl_mgmt_host`'s ingress is always
ready except during reset (the internal decode is single-cycle on
the lvdspll_clk domain and cannot stall). If the DUT ever starts
stalling this seam we want to know.

#### 2.1.9 R1 coverage points

- `cov_rc_data_accepted` — a data byte was accepted with `ready=1`.
- `cov_rc_kchar_accepted` — a K-symbol byte was accepted with `ready=1`.
- `cov_rc_error_accepted` — an errored beat was accepted (and dropped
  by the DUT, per `ast_rc_error_does_not_fan_out`).
- `cov_rc_all_commands_seen` — at least one beat of each command byte
  value in the table has been accepted over the trace.
- `cov_rc_consecutive_kchars` — three consecutive K-char beats.
- `cov_rc_data_then_kchar` — data beat immediately followed by a K-char.

### 2.2 Sub-plane R2 — runctl_mgmt_host command decode FSM

#### 2.2.1 Boundary signals

Internal RTL: `run-control_mgmt/rtl/runctl_mgmt_host.sv`
FSM state variable: `rx_state` (enumerated)
Registered output: `aso_runctl_data[8:0]` + `aso_runctl_valid`

The FSM decodes the synclink byte stream into a 9-bit one-hot
`aso_runctl_data` (the run-state encoding in §2.0). States seen in
the RTL (observational, subject to a matching grep):

```
RECV_IDLE          — waiting for a K28.5 comma
RECV_RX_PAYLOAD    — have comma, collecting 8 payload bytes
RECV_LOGGING       — payload complete, emitting fanout beat
RECV_ACK_RUN_PREP  — emitting ACK packet for RUN_PREPARE
RECV_ACK_RUN_END   — emitting ACK packet for END_RUN
RECV_ERRORED       — dropped after error flag
```

#### 2.2.2 Step 1 — handshake assumptions

No additional ingress-side assumptions beyond R1. The FSM itself has no
external handshake; it consumes `asi_synclink_*` on its ingress side
and drives `aso_runctl_*` on its egress side.

#### 2.2.3 Step 2 — decode-state structure

```systemverilog
typedef enum logic [3:0] {
  RC_DEC_IDLE,      // waiting for comma
  RC_DEC_PAYLOAD,   // byte 1..N of payload
  RC_DEC_EMIT,      // about to raise aso_runctl_valid
  RC_DEC_ACK_PREP,  // emitting RUN_PREPARE ACK
  RC_DEC_ACK_END,   // emitting END_RUN ACK
  RC_DEC_ERROR
} rc_dec_phase_t;

typedef struct packed {
  bit [3:0] phase;
  bit [7:0] cmd_byte;
  bit [2:0] payload_idx;
} rc_dec_state_t;
```

#### 2.2.4 Step 3 — FSM transition constraints

```systemverilog
asm_rc_fsm_idle_exits_only_on_comma: assume property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (rx_state == RECV_IDLE && $changed(rx_state))
      |-> ($past(asi_synclink_valid) && $past(asi_synclink_data) == 9'h1BC));

asm_rc_fsm_no_emit_without_prior_valid: assume property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    rx_state == RECV_LOGGING |-> rx_state == $past(rx_state, 1) ||
    ($past(rx_state) == RECV_RX_PAYLOAD && $past(asi_synclink_valid) && $past(asi_synclink_ready)));
```

We tag these as `assume` because they are transition facts we rely on
when proving downstream sub-planes, but they should also be restated as
`assert` with the R2 DUT as the unit under test. In that rebind, they
become:

```systemverilog
ast_rc_fsm_idle_exit_only_on_comma: assert property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (rx_state == RECV_IDLE && !lvdspll_reset)
      |=> (rx_state == RECV_IDLE) ||
          (rx_state == RECV_RX_PAYLOAD && $past(asi_synclink_data) == 9'h1BC));
```

#### 2.2.5 Step 4 — cascade

The command-decode cascade is small (6 states). We express it as a
property table rather than a recursive property:

```systemverilog
property prop_rc_fsm;
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (rx_state == RECV_IDLE     |-> prop_rc_idle_invariant) and
    (rx_state == RECV_RX_PAYLOAD |-> prop_rc_payload_invariant) and
    (rx_state == RECV_LOGGING  |-> prop_rc_logging_invariant) and
    (rx_state == RECV_ACK_RUN_PREP |-> prop_rc_ack_prep_invariant) and
    (rx_state == RECV_ACK_RUN_END  |-> prop_rc_ack_end_invariant) and
    (rx_state == RECV_ERRORED  |-> prop_rc_error_invariant);
endproperty
```

Each sub-invariant pins the output signals (`aso_runctl_valid`,
`aso_runctl_data`, `aso_upload_valid`, `aso_upload_data`,
`payload_idx` counter, etc.) to state-appropriate values.

#### 2.2.6 Step 5 — driver

No driver needed; the FSM is an internal observable. We rely on R1's
driver to inject `asi_synclink_*` beats and let the FSM transition
organically.

#### 2.2.7 Step 6 — generate / assume

Generation is identical to R1; the FSM constraints are all `assert`
when R2 is the unit under test, `assume` when R2 is a precondition of
R3/R4.

#### 2.2.8 Step 7 — output assertions

The FSM must produce one fanout beat per accepted command byte:

```systemverilog
ast_rc_fsm_emits_exactly_once_per_cmd: assert property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (asi_synclink_valid && asi_synclink_ready && asi_synclink_error == 3'b0
     && asi_synclink_data[8] == 1'b0 && asi_synclink_data[7:0] inside {8'h10, 8'h12, 8'h13})
      |=> ##[1:5] (aso_runctl_valid && $rose(aso_runctl_valid)));

ast_rc_fsm_onehot_runstate: assert property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    aso_runctl_valid |-> $onehot(aso_runctl_data));

ast_rc_fsm_runstate_mapping: assert property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    aso_runctl_valid |-> (
      ($past(cmd_byte) == 8'h10 && aso_runctl_data == 9'b000000010) ||  // RUN_PREPARE
      ($past(cmd_byte) == 8'h11 && aso_runctl_data == 9'b000000100) ||  // SYNC
      ($past(cmd_byte) == 8'h12 && aso_runctl_data == 9'b000001000) ||  // RUNNING
      ($past(cmd_byte) == 8'h13 && aso_runctl_data == 9'b000010000) ||  // TERMINATING
      ($past(cmd_byte) == 8'h14 && aso_runctl_data == 9'b000000001) ||  // IDLE on abort
      ($past(cmd_byte) == 8'h20 && aso_runctl_data == 9'b000100000) ||  // LINK_TEST
      ($past(cmd_byte) == 8'h21 && aso_runctl_data == 9'b000000001) ||  // IDLE after link-test
      ($past(cmd_byte) == 8'h24 && aso_runctl_data == 9'b001000000) ||  // SYNC_TEST
      ($past(cmd_byte) == 8'h25 && aso_runctl_data == 9'b000000001) ||  // IDLE after sync-test
      ($past(cmd_byte) == 8'h26 && aso_runctl_data == 9'b001000000) ||  // SYNC_TEST pulse/state
      ($past(cmd_byte) == 8'h30 && aso_runctl_data == 9'b010000000) ||  // RESET
      ($past(cmd_byte) == 8'h31 && aso_runctl_data == 9'b000000001) ||  // IDLE after stop_reset
      ($past(cmd_byte) == 8'h32 && aso_runctl_data == 9'b000000001) ||  // IDLE (enable)
      ($past(cmd_byte) == 8'h33 && aso_runctl_data == 9'b100000000)     // OUT_OF_DAQ (disable)
    ));
```

The abort/enable/disable mappings are working assumptions pending a
definitive decode of `runctl_mgmt_host.sv`. They are included here so
the reviewer can confirm or correct them before the first formal run.

#### 2.2.9 R2 coverage points

- `cov_rc_fsm_all_states_visited` — every state in the FSM table.
- `cov_rc_fsm_idle_to_error_direct` — errored beat in IDLE state.
- `cov_rc_fsm_payload_to_emit` — legal transition after a complete payload.
- `cov_rc_fsm_ack_prep_latency` — the number of cycles between byte
  acceptance and ACK emission for RUN_PREPARE.
- `cov_rc_fsm_ack_end_latency` — same for END_RUN.

### 2.3 Sub-plane R3 — runctl_mgmt_host upload ACK packet generator

#### 2.3.1 Boundary signals

Internal RTL: `run-control_mgmt/rtl/runctl_mgmt_host.sv`
ACK output (Avalon-ST source, 36-bit wide, K-flag in top nibble):
- `aso_upload_data[35:0]`
- `aso_upload_valid`
- `aso_upload_ready` (input, from `upload_cdc_fifo.in_ready`)
- `aso_upload_startofpacket`
- `aso_upload_endofpacket`

Clock / reset: `lvdspll_clk`, `lvdspll_reset` (same as R1/R2).

#### 2.3.2 Step 1 — ACK egress handshake

```systemverilog
asm_ack_sideband_requires_valid: assume property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (aso_upload_startofpacket || aso_upload_endofpacket) |-> aso_upload_valid);

ast_ack_hold_under_backpressure: assert property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (aso_upload_valid && !aso_upload_ready) |=>
      (aso_upload_valid && $stable(aso_upload_data) &&
       $stable(aso_upload_startofpacket) && $stable(aso_upload_endofpacket)));
```

The hold-under-backpressure property is a classic AVST invariant; it
gates everything downstream of `upload_cdc_fifo` because the CDC write
side relies on stable `in_data`.

#### 2.3.3 Step 2 — ACK packet chunk structure

The ACK frame is a 4-word packet. The exact field layout is given by
`runctl_mgmt_host.sv` constants (we list the observed shape; the
reviewer should confirm against the actual `ACK_SYMBOL_*` constants):

```systemverilog
typedef enum logic [3:0] {
  ACK_KIND_HEADER,     // SOP, K28.5 = 0x1BC in kflag|byte form
  ACK_KIND_CMD_ECHO,   // byte[7:0] = command byte just acknowledged
  ACK_KIND_COUNTER,    // byte[31:0] = CMD_COUNT value
  ACK_KIND_TRAILER,    // EOP, K28.4 = 0x19C
  ACK_KIND_NONE
} ack_kind_t;

typedef struct packed {
  bit [3:0] kind;
  bit [35:0] qbits;   // data[35:32] = K-flag nibble, data[31:0] = payload word
} ack_beat_t;
```

#### 2.3.4 Step 3 — per-kind constraints

```systemverilog
property prop_ack_header(int unsigned n);
  packet_info[n].kind == ACK_KIND_HEADER |->
    aso_upload_startofpacket == 1 &&
    !aso_upload_endofpacket &&
    aso_upload_data[35:32] == 4'b0001 &&
    aso_upload_data[31:0] == 32'h0000_00BC;
endproperty

property prop_ack_cmd_echo(int unsigned n);
  packet_info[n].kind == ACK_KIND_CMD_ECHO |->
    !aso_upload_startofpacket &&
    !aso_upload_endofpacket &&
    aso_upload_data[35:32] == 4'b0000 &&
    aso_upload_data[7:0] inside {8'h10, 8'h11, 8'h12, 8'h13};
endproperty

property prop_ack_trailer(int unsigned n);
  packet_info[n].kind == ACK_KIND_TRAILER |->
    aso_upload_endofpacket == 1 &&
    !aso_upload_startofpacket &&
    aso_upload_data[35:32] == 4'b0001 &&
    aso_upload_data[31:0] == 32'h0000_009C;
endproperty
```

#### 2.3.5 Step 4 — cascade

```systemverilog
property prop_ack_pkt(int unsigned n);
  packet_info[n].kind == ACK_KIND_HEADER     ? prop_ack_header(n)     and prop_ack_pkt(n+1) :
  packet_info[n].kind == ACK_KIND_CMD_ECHO   ? prop_ack_cmd_echo(n)   and prop_ack_pkt(n+1) :
  packet_info[n].kind == ACK_KIND_COUNTER    ? prop_ack_counter(n)    and prop_ack_pkt(n+1) :
  packet_info[n].kind == ACK_KIND_TRAILER    ? prop_ack_trailer(n)    :
  packet_info[n].kind == ACK_KIND_NONE       ? 1'b1 : 1'b0;
endproperty
```

The recursion terminates on trailer or none; any other kind in terminal
position is a constraint violation.

`packet_info[0].total_length == 4` for a legal ACK frame. This
`total_length` is the DVCon paper's trick for getting the length
across chunks without a global counter.

#### 2.3.6 Step 5 — driver

The ACK path is an output, not an input, so there is no driver. The
R3 sub-plane is a pure assertion plane. The only stimulus needed is
the appropriate R1/R2 input (a `CMD_RUN_PREPARE` or `CMD_END_RUN`
command byte) that triggers the ACK FSM.

#### 2.3.7 Step 6 — generate

ACK generation is triggered by `CMD_RUN_PREPARE` and `CMD_END_RUN` only.
We add a `pkt_good` input that selects between "well-formed ACK" (all
four beats in sequence, legal SOP/EOP, legal K-symbols) and "malformed
ACK" (missing trailer, extra beat, wrong K-symbol). The malformed
variant exercises the downstream `upload_cdc_fifo` and `upload_pkt_mux`
rejection paths.

#### 2.3.8 Step 7 — acceptance assertions

```systemverilog
ast_ack_follows_run_prepare: assert property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (asi_synclink_valid && asi_synclink_ready && asi_synclink_error == 3'b0
     && asi_synclink_data == 9'h010)
      |=> ##[1:64] ($rose(aso_upload_startofpacket) && aso_upload_valid));

ast_ack_exactly_one_sop_per_trigger: assert property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (aso_upload_valid && aso_upload_startofpacket && aso_upload_ready)
      |=> !aso_upload_startofpacket until_with (aso_upload_valid && aso_upload_endofpacket && aso_upload_ready));

ast_ack_eop_closes_the_frame: assert property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (aso_upload_valid && aso_upload_endofpacket && aso_upload_ready)
      |=> !aso_upload_valid until_with (aso_upload_valid && aso_upload_startofpacket && aso_upload_ready));
```

The third assertion captures the fact that the ACK path goes idle
between packets; there is no back-to-back ACK emission allowed because
the FSM has to wait for a new trigger command.

#### 2.3.9 R3 coverage points

- `cov_ack_prep_emitted` — a RUN_PREPARE ACK packet was emitted end-to-end.
- `cov_ack_end_emitted` — an END_RUN ACK packet was emitted end-to-end.
- `cov_ack_back_to_back` — a new ACK trigger arrived while a previous
  ACK frame was still in flight (this should either stall the new
  trigger or queue it; the behaviour is TBD pending RTL inspection).
- `cov_ack_cdc_backpressure` — the CDC FIFO asserted backpressure
  during ACK emission and the FSM correctly held the beat.

### 2.4 Sub-plane R4 — run_control_splitter 16-way fanout

#### 2.4.1 Boundary signals

Generated RTL: `feb_system_v3/synthesis/submodules/scifi_datapath_system_v3_run_control_splitter.vhd`
Parameter: `NUMBER_OF_OUTPUTS = 16`

Input (Avalon-ST sink, 9-bit):
- `in0_data[8:0]`
- `in0_valid`
- `in0_ready` (output, combined OR of all output readies)
- `in0_channel[0:0]`, `in0_startofpacket`, `in0_endofpacket`, `in0_error[0:0]`

Output (Avalon-ST source, 9-bit, ×16):
- `outN_data[8:0]` for N ∈ {0..15}
- `outN_valid`
- `outN_ready` (input, per-consumer)
- `outN_channel[0:0]`, `outN_startofpacket`, `outN_endofpacket`, `outN_error[0:0]`

Clock: `clk` = 125 MHz (aliased to `lvdspll_clk` at the integration level).
Reset: async-assert, sync-release on `clk`.

#### 2.4.2 Step 1 — handshake assumptions

The splitter uses an all-outputs-ready contract: `in0_ready` is the AND
of all 16 `outN_ready` signals (subject to confirmation; the BUG_HISTORY
entry around "partial-ready splitter consumer masks" suggests this is
the current behaviour). Formal models it as:

```systemverilog
asm_splitter_in_ready_is_and: assume property (
  @(posedge clk) disable iff (reset)
    in0_ready == (&{out0_ready, out1_ready, out2_ready, out3_ready,
                    out4_ready, out5_ready, out6_ready, out7_ready,
                    out8_ready, out9_ready, out10_ready, out11_ready,
                    out12_ready, out13_ready, out14_ready, out15_ready}));
```

Each output follows the standard AVST source contract:

```systemverilog
ast_splitter_hold_under_backpressure[N]: assert property (
  @(posedge clk) disable iff (reset)
    (outN_valid && !outN_ready) |=>
      (outN_valid && $stable(outN_data) && $stable(outN_channel) &&
       $stable(outN_startofpacket) && $stable(outN_endofpacket)));
```

The integration bench today forces every `outN_ready` high, so the
assume-then-assert form lets us flip one or more to low and prove the
broadcast blocks correctly.

#### 2.4.3 Step 2 — broadcast structure

The splitter carries a 9-bit run-state word with no packet grammar.
The per-beat structure is the one-hot `run_state_t` in §2.0.

```systemverilog
typedef struct packed {
  bit [8:0] state;    // one-hot run-state
  bit [0:0] channel;  // always 0 in v3
  bit [0:0] error;
  bit       sop;
  bit       eop;
} rc_splitter_beat_t;
```

#### 2.4.4 Step 3 — structural constraints

```systemverilog
asm_splitter_channel_is_zero: assume property (
  @(posedge clk) disable iff (reset)
    in0_valid |-> in0_channel == 1'b0);

asm_splitter_no_sop_no_eop: assume property (
  @(posedge clk) disable iff (reset)
    in0_valid |-> !in0_startofpacket && !in0_endofpacket);

asm_splitter_no_error: assume property (
  @(posedge clk) disable iff (reset)
    in0_valid |-> in0_error == 1'b0);

asm_splitter_data_onehot: assume property (
  @(posedge clk) disable iff (reset)
    in0_valid |-> $onehot(in0_data));
```

The "channel is zero" constraint is the BUG_HISTORY fix referenced at
line 79–89 of `BUG_HISTORY.md` — the previously broken v3 path tagged
RC with channel 1 and the splitter dropped it. If that bug ever
regresses, this assume fires and formal reports a contradiction.

#### 2.4.5 Step 4 — no cascade

The splitter is stateless; no cascade.

#### 2.4.6 Step 5 — driver

R1's driver feeds the synclink; R2's decode produces the 9-bit run-state
word that lands on the splitter input. The splitter itself needs no
driver.

#### 2.4.7 Step 6 — assume/generate

Generation uses the same `pkt_good` flag: with `pkt_good=1`, only
legal one-hot run-state words reach the splitter; with `pkt_good=0`,
the channel may be non-zero or the data may be non-one-hot so we can
exercise the "drop on illegal" behaviour.

#### 2.4.8 Step 7 — broadcast correctness assertions

The key broadcast property is: when the input transfers, all 16 outputs
transfer the *same* data in the *same* cycle. Formal expresses this
across all outputs with a generate loop:

```systemverilog
generate
  for (genvar i = 0; i < 16; i++) begin : g_broadcast
    ast_splitter_broadcast_data[i]: assert property (
      @(posedge clk) disable iff (reset)
        (in0_valid && in0_ready) |-> (this.out_valid[i] && this.out_data[i] == in0_data));
  end
endgenerate
```

where `this.out_valid[i]` / `this.out_data[i]` are bound as aliases
for the 16 `outN_valid` / `outN_data` ports.

The consumer-stall property is:

```systemverilog
ast_splitter_blocks_on_any_consumer_stall: assert property (
  @(posedge clk) disable iff (reset)
    (in0_valid && |{~out0_ready, ~out1_ready, ~out2_ready, ~out3_ready,
                     ~out4_ready, ~out5_ready, ~out6_ready, ~out7_ready,
                     ~out8_ready, ~out9_ready, ~out10_ready, ~out11_ready,
                     ~out12_ready, ~out13_ready, ~out14_ready, ~out15_ready})
      |-> !in0_ready);
```

The per-output fanout-completeness property is:

```systemverilog
ast_splitter_fanout_completeness: assert property (
  @(posedge clk) disable iff (reset)
    (in0_valid && in0_ready) |->
      (&{out0_valid && out0_ready, out1_valid && out1_ready,
         out2_valid && out2_ready, out3_valid && out3_ready,
         out4_valid && out4_ready, out5_valid && out5_ready,
         out6_valid && out6_ready, out7_valid && out7_ready,
         out8_valid && out8_ready, out9_valid && out9_ready,
         out10_valid && out10_ready, out11_valid && out11_ready,
         out12_valid && out12_ready, out13_valid && out13_ready,
         out14_valid && out14_ready, out15_valid && out15_ready}));
```

This mirrors the `observe_rc_fanout` TCL routine in `run_rc.sh`.

#### 2.4.9 R4 deadlock properties

Two deadlock hazards exist on this splitter:

1. A consumer that never asserts `ready` deadlocks the whole fanout.
2. Two consumers that oscillate `ready` in opposite phases may
   deadlock if the splitter's in_ready path is a pure AND (never all
   high at the same cycle).

We capture both with:

```systemverilog
ast_splitter_bounded_latency: assert property (
  @(posedge clk) disable iff (reset)
    in0_valid |-> ##[0:$FORMAL_DEADLOCK_BOUND] in0_ready);

ast_splitter_no_starvation: assert property (
  @(posedge clk) disable iff (reset)
    (in0_valid && !in0_ready)
      |=> !(in0_valid && !in0_ready) [*($FORMAL_DEADLOCK_BOUND+1)]);
```

`$FORMAL_DEADLOCK_BOUND` is set per-bench: for functional formal we use
2048 cycles; for bounded liveness we use 16 cycles.

#### 2.4.10 R4 coverage points

- `cov_splitter_broadcast` — 16-way fanout completed in one cycle.
- `cov_splitter_stalled_on_out0` — output 0 is the lone stalling consumer.
- `cov_splitter_stalled_on_out15` — output 15 is the lone stalling consumer.
- `cov_splitter_back_to_back_states` — two different run-states fanned out
  in consecutive accepted cycles.
- `cov_splitter_channel_nonzero_dropped` — with `pkt_good=0`, the splitter
  dropped a channel-1 beat (this is the regression gate).

### 2.5 Sub-plane R5 — RC sinks (consumer-side AVST conformance)

#### 2.5.1 Enumerated consumer list

The 16 splitter outputs feed the following consumers (from the DP
boundary map):

| out index | Destination | Consumer port |
|---|---|---|
| 0 | `histogram_statistics_0` | `ctrl` |
| 1 | `mts_preprocessor_0` | `run_ctrl` |
| 2 | `mutrig_datapath_subsystem_0` | `run_ctrl` |
| 3 | `mutrig_datapath_subsystem_1` | `run_ctrl` |
| 4 | `mutrig_datapath_subsystem_2` | `run_ctrl` |
| 5 | `mutrig_datapath_subsystem_3` | `run_ctrl` |
| 6 | `hit_stack_subsystem_0` | `run_control_signal` |
| 7 | `mutrig_reset_controller_0` | `runcontrol` |
| 8 | `mutrig_datapath_subsystem_4` | `run_ctrl` |
| 9 | `mutrig_datapath_subsystem_5` | `run_ctrl` |
| 10 | `mutrig_datapath_subsystem_6` | `run_ctrl` |
| 11 | `mutrig_datapath_subsystem_7` | `run_ctrl` |
| 12 | `mts_preprocessor_1` | `run_ctrl` |
| 13 | `mutrig_injector_0` | `runctl` |
| 14 | `hit_stack_subsystem_1` | `run_control_signal` |
| 15 | `emulator_ctrl_splitter.in` | (further fans out to 8 emulator_mutrig + histogram_statistics_1) |

#### 2.5.2 Step 1 — consumer-side handshake

Each consumer port is an AVST sink. We assert the standard contract on
every consumer:

```systemverilog
generate
  for (genvar i = 0; i < 16; i++) begin : g_consumer_contract
    ast_consumer_hold_under_stall[i]: assert property (
      @(posedge clk) disable iff (reset)
        (sink_valid[i] && !sink_ready[i]) |=>
          (sink_valid[i] && $stable(sink_data[i])));
  end
endgenerate
```

In the integration bench today, every consumer forces `ready` high, so
this assertion is vacuously satisfied; we include it because formal
should still prove that if a consumer stalls, the hold-under-stall
invariant is preserved by the producer (which is the splitter, proved
in R4) plus the consumer's ingress register.

#### 2.5.3 Step 2 — consumer-side state sampling

Each consumer has a single internal register that samples the 9-bit
one-hot run-state on every accepted beat. The exact register name
varies per IP (`mutrig_datapath_subsystem_N.run_ctrl_reg`,
`histogram_statistics_N.ctrl_reg`, etc.).

```systemverilog
typedef struct packed {
  bit [8:0] run_state;    // sampled one-hot
  bit       has_sampled;  // at least one beat received since reset
} rc_sink_state_t;
```

#### 2.5.4 Step 3 — sampling constraint

```systemverilog
ast_consumer_samples_on_accept[i]: assert property (
  @(posedge clk) disable iff (reset)
    (sink_valid[i] && sink_ready[i])
      |=> (sink_state[i].run_state == $past(sink_data[i]) && sink_state[i].has_sampled));
```

#### 2.5.5 Step 4 — cascade over consumer list

No recursive cascade; we use a `generate` loop.

#### 2.5.6 Step 5 — driver

No driver; R4 drives the splitter output which drives all consumer
inputs.

#### 2.5.7 Step 6 — generate / assume

The R5 sub-plane inherits R4's assume; no additional generation.

#### 2.5.8 Step 7 — synchrony assertions (the important one)

The integration-level invariant is that all 16 consumers end up with
the *same* run-state in the *same* cycle (within one clock edge of the
splitter delivering the beat). Formal expresses this as a cross-consumer
equality:

```systemverilog
ast_all_consumers_agree: assert property (
  @(posedge clk) disable iff (reset)
    (splitter_fanout_complete)
      |=> ##1 $onehot(sink_state[0].run_state) && (
        sink_state[0].run_state == sink_state[1].run_state &&
        sink_state[1].run_state == sink_state[2].run_state &&
        sink_state[2].run_state == sink_state[3].run_state &&
        sink_state[3].run_state == sink_state[4].run_state &&
        sink_state[4].run_state == sink_state[5].run_state &&
        sink_state[5].run_state == sink_state[6].run_state &&
        sink_state[6].run_state == sink_state[7].run_state &&
        sink_state[7].run_state == sink_state[8].run_state &&
        sink_state[8].run_state == sink_state[9].run_state &&
        sink_state[9].run_state == sink_state[10].run_state &&
        sink_state[10].run_state == sink_state[11].run_state &&
        sink_state[11].run_state == sink_state[12].run_state &&
        sink_state[12].run_state == sink_state[13].run_state &&
        sink_state[13].run_state == sink_state[14].run_state &&
        sink_state[14].run_state == sink_state[15].run_state));
```

`splitter_fanout_complete` is a one-cycle pulse that equals the
condition `ast_splitter_fanout_completeness` in §2.4.8 (wrapped as a
continuous assignment in the formal bind).

This is the single most important RC integration property: if one
consumer ever samples a different run-state than another in the same
cycle, a systematic tear in the run-state has occurred and all
downstream correctness (accumulation gating, datapath enable, hit-stack
ingest gating, emulator generation gating) is invalidated.

#### 2.5.9 R5 coverage points

- `cov_all_consumers_state_<S>` — all 16 consumers hold state S
  simultaneously, for S ∈ {IDLE, RUN_PREPARE, SYNC, RUNNING,
  TERMINATING, RESET}.
- `cov_one_consumer_stalled_during_transition` — consumer i stalls
  during a run-state transition; the R4 backpressure property still
  holds and no other consumer sees a torn state.
- `cov_emulator_ctrl_splitter_fanout` — out[15] delivered and the
  nested 9-way fanout inside `emulator_ctrl_splitter` completed.

### 2.6 Sub-plane R6 — upload_cdc_fifo (125 MHz → 156.25 MHz)

#### 2.6.1 Boundary signals

CDC FIFO instance: `upload_cdc_fifo` inside `upload_system_v3.qsys`.
Depth: 16 entries (per Qsys parameter). Width: 36 bits + 2 marker bits
(SOP/EOP).

Write side (125 MHz datapath clock aliased as `lvdspll_clk` on the RC
subtree; note the Qsys wiring lists this as the `data_clock` / datapath
clock):
- `in_clk` (125 MHz)
- `in_reset`
- `in_data[35:0]`
- `in_valid`
- `in_ready` (output)
- `in_startofpacket`, `in_endofpacket`

Read side (156.25 MHz control-plane clock):
- `out_clk` (156.25 MHz)
- `out_reset`
- `out_data[35:0]`
- `out_valid`
- `out_ready` (input)
- `out_startofpacket`, `out_endofpacket`

#### 2.6.2 Step 1 — per-side handshake

Each side obeys standard AVST. The CDC-specific invariants are:

```systemverilog
ast_cdc_in_hold_on_stall: assert property (
  @(posedge in_clk) disable iff (in_reset)
    (in_valid && !in_ready) |=> in_valid && $stable(in_data));

ast_cdc_out_hold_on_stall: assert property (
  @(posedge out_clk) disable iff (out_reset)
    (out_valid && !out_ready) |=> out_valid && $stable(out_data));
```

#### 2.6.3 Step 2 — CDC occupancy model

The CDC FIFO has gray-coded read and write pointers crossing the two
clock domains via 2-flop synchronisers. Formal needs a bounded model of
the FIFO to prove no metastability-visible beat leaks. We introduce an
abstract occupancy counter that is write-incremented on `in_valid &&
in_ready` and read-decremented on `out_valid && out_ready`, with a
bounded-depth invariant.

```systemverilog
typedef struct packed {
  bit [4:0] wr_ptr_bin;    // 5-bit binary write pointer (4-bit depth + 1 wrap bit)
  bit [4:0] rd_ptr_bin;    // read-side binary pointer
  bit [4:0] occupancy;     // wr - rd (in the write domain)
} cdc_state_t;
```

#### 2.6.4 Step 3 — occupancy invariants

```systemverilog
ast_cdc_occupancy_bounded: assert property (
  @(posedge in_clk) disable iff (in_reset)
    occupancy <= 5'd16);

ast_cdc_full_when_in_ready_low: assert property (
  @(posedge in_clk) disable iff (in_reset)
    (occupancy == 5'd16) |-> !in_ready);

ast_cdc_empty_when_out_valid_low: assert property (
  @(posedge out_clk) disable iff (out_reset)
    (occupancy_rd_side == 5'd0) |-> !out_valid);
```

`occupancy_rd_side` is a read-side sampled view via a pair of 2FF
synchronisers on the gray-coded write pointer.

#### 2.6.5 Step 4 — cross-domain equivalence

This is the hardest CDC property. We prove it with a tagged-payload
technique: every beat on the write side gets a monotonically increasing
tag `in_tag`, and the read side emits the beats in the same tag order.
The CDC FIFO has no reorder, so tag order is the same as data order.

```systemverilog
logic [15:0] in_tag;
logic [15:0] out_tag;
always_ff @(posedge in_clk or posedge in_reset) begin
  if (in_reset) in_tag <= 0;
  else if (in_valid && in_ready) in_tag <= in_tag + 1;
end

always_ff @(posedge out_clk or posedge out_reset) begin
  if (out_reset) out_tag <= 0;
  else if (out_valid && out_ready) out_tag <= out_tag + 1;
end

ast_cdc_no_reorder: assert property (
  @(posedge out_clk) disable iff (out_reset)
    (out_valid && out_ready) |-> $rose(out_tag == $past(out_tag) + 1));
```

The corresponding data-equivalence is:

```systemverilog
ast_cdc_data_preserved: assert property (
  @(posedge out_clk) disable iff (out_reset)
    (out_valid && out_ready) |-> (out_data == recorded_data_at_write(out_tag)));
```

`recorded_data_at_write()` is a bounded shadow array the formal bind
maintains; it snapshots `in_data` on every accepted write beat.

#### 2.6.6 Step 5 — driver

R3's ACK packet generator drives `in_data`; no additional driver needed.

#### 2.6.7 Step 6 — generate

The `pkt_good` flag here selects between well-formed ACK packets (R3)
and malformed packets. The CDC FIFO is oblivious to framing — it
preserves data exactly — so `pkt_good=0` is only useful for proving
that the CDC does not invent a SOP or EOP that was not there.

#### 2.6.8 Step 7 — bounded liveness

```systemverilog
ast_cdc_bounded_latency: assert property (
  @(posedge in_clk) disable iff (in_reset)
    (in_valid && in_ready) |-> ##[1:$FORMAL_CDC_LATENCY_MAX] (out_valid && out_tag == $past(in_tag)));
```

`$FORMAL_CDC_LATENCY_MAX` = 8 for a 16-deep FIFO (each beat crosses in
≤4 in-clock cycles + ≤4 out-clock cycles for the 2FF sync of the gray
pointer). The bound is conservative.

#### 2.6.9 R6 coverage points

- `cov_cdc_full_backpressure` — `in_ready` fell because the FIFO filled.
- `cov_cdc_empty_stall` — `out_valid` fell because the FIFO drained.
- `cov_cdc_ack_prep_crosses` — a RUN_PREPARE ACK frame crossed the CDC.
- `cov_cdc_ack_end_crosses` — an END_RUN ACK frame crossed the CDC.
- `cov_cdc_consecutive_ack_frames` — two ACK frames in flight with a
  gap ≤ $FORMAL_CDC_LATENCY_MAX.

### 2.7 Sub-plane R7 — upload_pkt_mux three-source merge (link 0)

#### 2.7.1 Boundary signals

IP: `upload_pkt_mux` (Altera AVST 3-to-1 multiplexer) in
`upload_system_v3.qsys`.
Clock: 156.25 MHz (control-plane `cclk156`).

Inputs (Avalon-ST sinks, 36-bit):
- `in0_*` — upper datapath (hit_type3_upper after clock-crossing; see X3)
- `in1_*` — slow-control upload path (from `sc_hub` via the control-path subsystem)
- `in2_*` — RC ACK from `upload_cdc_fifo.out` (R6)

Each input carries `data[35:0]`, `valid`, `ready`, `startofpacket`,
`endofpacket`, and the output carries an additional 2-bit `channel[1:0]`
tag identifying the source.

Output:
- `out_data[35:0]` (= `upload_data0_sc_rc_data` at feb_system_v3)
- `out_valid`, `out_ready`
- `out_startofpacket`, `out_endofpacket`
- `out_channel[1:0]`

#### 2.7.2 Step 1 — three sink contracts

Each input obeys standard AVST-sink contract, inherited from
R5 (DP upper frames out of hit-stack-subsystem), the SC plane (S8), and
R6 (ACK out of CDC). We restate the `hold_under_backpressure` assumption
per input.

#### 2.7.3 Step 2 — output packet structure

```systemverilog
typedef enum logic [1:0] {
  MUX_CH_UPPER_FRAME = 2'b00,    // tentative encoding; confirm from upload_pkt_mux Qsys params
  MUX_CH_SC          = 2'b01,
  MUX_CH_RC_ACK      = 2'b10,
  MUX_CH_RESERVED    = 2'b11
} mux_channel_t;

typedef struct packed {
  bit [35:0] data;
  bit [1:0]  channel;
  bit        sop;
  bit        eop;
} mux_out_beat_t;
```

#### 2.7.4 Step 3 — mutex constraint

The mux's arbitration is packet-granular: once one source wins the
SOP, it keeps the grant until its EOP. Formal models this with an
internal grant state:

```systemverilog
typedef enum logic [1:0] {
  MUX_GRANT_NONE = 2'b00,
  MUX_GRANT_UPPER = 2'b01,
  MUX_GRANT_SC = 2'b10,
  MUX_GRANT_RC = 2'b11
} mux_grant_t;

mux_grant_t grant;
```

```systemverilog
ast_mux_grant_onehot_while_framed: assert property (
  @(posedge cclk156) disable iff (reset)
    (grant != MUX_GRANT_NONE) |-> (out_valid && out_channel == channel_of(grant)));

ast_mux_no_frame_interleave: assert property (
  @(posedge cclk156) disable iff (reset)
    (out_valid && out_startofpacket && out_ready) |=>
      (grant == channel_of(out_channel)) throughout ((out_valid && out_endofpacket && out_ready)[->1]));
```

#### 2.7.5 Step 4 — cascade

The mux is stateless across packets (returns to `MUX_GRANT_NONE`
after every EOP). No recursion needed; the mutex properties above
are the entire structural contract.

#### 2.7.6 Step 5 — driver

DP (D8) drives in0, SC (S8) drives in1, R6 drives in2. The formal bind
has to compose three drivers. To keep the state space manageable, we
use a two-level composition:

- First prove each input contract in isolation against the mux
  (three separate formal runs).
- Then prove the mutex property with two inputs active at a time
  (three pairs: upper×SC, upper×RC, SC×RC).
- Then prove the full mutex with all three active (one final run).

#### 2.7.7 Step 6 — generate

`pkt_good` selects between well-formed triple-source traffic and
pathological cases (two SOPs in the same cycle, EOP without prior SOP,
wrong channel tag on output). The pathological cases must trigger an
error response; if the mux silently passes them through, `ast_mux_no_frame_interleave` fires.

#### 2.7.8 Step 7 — output assertions

```systemverilog
ast_mux_output_channel_matches_input: assert property (
  @(posedge cclk156) disable iff (reset)
    (out_valid && out_ready) |-> (
      (out_channel == MUX_CH_UPPER_FRAME && in0_valid && $past(in0_valid)) ||
      (out_channel == MUX_CH_SC          && in1_valid && $past(in1_valid)) ||
      (out_channel == MUX_CH_RC_ACK      && in2_valid && $past(in2_valid))));

ast_mux_data_preserved: assert property (
  @(posedge cclk156) disable iff (reset)
    (out_valid && out_ready) |-> (out_data == input_data_of(out_channel)));
```

#### 2.7.9 R7 starvation properties

If one source is perpetually ready-blocked by the downstream SWB link,
the other two must not starve. Per the Altera AVST mux specification,
`upload_pkt_mux` uses a round-robin arbiter at packet granularity.

```systemverilog
ast_mux_rr_no_starvation: assert property (
  @(posedge cclk156) disable iff (reset)
    (in0_valid && in0_startofpacket)
      |-> ##[0:$FORMAL_RR_STARVATION_BOUND] (grant == MUX_GRANT_UPPER));

ast_mux_rr_no_starvation_sc: assert property (
  @(posedge cclk156) disable iff (reset)
    (in1_valid && in1_startofpacket)
      |-> ##[0:$FORMAL_RR_STARVATION_BOUND] (grant == MUX_GRANT_SC));

ast_mux_rr_no_starvation_rc: assert property (
  @(posedge cclk156) disable iff (reset)
    (in2_valid && in2_startofpacket)
      |-> ##[0:$FORMAL_RR_STARVATION_BOUND] (grant == MUX_GRANT_RC));
```

`$FORMAL_RR_STARVATION_BOUND` is set to the maximum RR cycle length
over the three sources, multiplied by the worst-case inter-frame
spacing (estimated at 1024 cycles).

#### 2.7.10 R7 coverage points

- `cov_mux_upper_frame_passed` — a hit_type3_upper frame was emitted on link 0.
- `cov_mux_sc_passed` — a slow-control upload beat was emitted.
- `cov_mux_rc_ack_passed` — an RC ACK frame was emitted.
- `cov_mux_all_three_compete` — all three inputs had pending SOP in
  the same window and the RR arbiter resolved.
- `cov_mux_channel_tag_each` — output `channel[1:0]` equals each of
  the three legal encodings across the trace.

### 2.8 RC plane summary

The RC plane has seven sub-planes and two seams (to SC via the upload
link and to DP via the 16-way fanout). The integration-critical
property is §2.5.8 `ast_all_consumers_agree`: every RC word must reach
all 16 consumers in the same cycle, and every downstream behaviour
(DP gating, SC response framing, upload merge) depends on it. The
hardest formal proof is §2.6.5 `ast_cdc_data_preserved` because it
requires a bounded tagged-payload shadow of the CDC FIFO.

---

## 3. Slow-Control (SC) plane

### 3.0 SC plane overview

The SC plane decomposes the slow-control path from the external 36-bit
`download_sc` K-flag packet at the top-level seam down to every
AVMM-slave aperture in `feb_system_v3`. It has two physically distinct
aperture families:

1. The control-path slaves exposed under `sc_hub_cmd_pipe.m0` inside
   `debug_sc_system_v3.qsys`: scratch pad, onewire, MAX10 programmer,
   charge-injection pulser, Firefly XCVR control, on-die temp sense,
   MuTRiG trigger config, and the `mm_bridge` gateway.
2. The datapath-path slaves reachable through `mm_bridge.s0` at
   base address 0x20000 (byte-addressed): LVDS RX controller CSR, MuTRiG
   reset controller, 8× emulator_mutrig CSR, debug MM-to-runctl alias,
   2× histogram_statistics (bin RAM + CSR), 2× hit_stack_subsystem
   ring-buffer CSRs, and scattered mutrig_frame_deassembly CSRs.

The exposed external seam at `feb_system_v3` is `download_sc` (the
36-bit K-flag conduit that carries the SWB slow-control packet stream).
The internal AVMM interconnect width varies per slave (4-bit at onewire,
5-bit at Firefly, 14-bit on the external datapath aperture, 18-bit
inside sc_hub itself). The Qsys interconnect reports byte addresses but
the external datapath aperture `mm_pipeline_avmm_lvds.m0` is
word-addressed, so bench stimulus must divide by 4 — this is one of
the bugs already tracked in `BUG_HISTORY.md` (2026-04-17 fix), and one
of the sub-plane S6 properties captures it.

The SC packet grammar on the `download_sc` conduit is frame-oriented,
with a K28.5 preamble, a four-word header (packet type + fpga_id +
mask bits + address + length + optional atomic flag), an optional
payload, and an implicit response framed by `sc_hub` on the upload path.

### 3.1 Sub-plane S1 — sc_hub download_sc K-flag packet ingress

#### 3.1.1 Boundary signals

RTL: `debug_sc_system_v3/synthesis/submodules/sc_hub_v2.vhd` plus
the K-character handling in `sc_hub_pkt_rx.vhd`.

Download conduit (Avalon-ST sink with K-flag carrier, 36-bit):
- `i_download_data[31:0]` — 32-bit data payload
- `i_download_datak[3:0]` — per-symbol K-character flags (bit N indicates that byte N of the 32-bit word is a K-character)
- `i_accept_new_pkt` — permission to open a new packet
- `i_allow_new_pkt` — gate that enforces S1 admission policy
- `o_download_ready` — backpressure-style AVST ready back to the harness
- `o_pkt_in_progress` — one-cycle window flag while a packet body is being buffered
- `o_pkt_valid` — assertion of packet-completed with structural decoding done
- `o_pkt_info` — struct containing parsed `sc_type`, `fpga_id`, start_address, rw_length, mask bits, atomic flag
- `o_pkt_is_internal` — set when the packet's address decode hits the internal sc_hub CSR aperture (0xFE80..0xFEBF)
- `o_soft_reset_pulse` — one-cycle pulse emitted when the internal sc_hub reset command is seen

Clock: `clk156` = 156.25 MHz (control-plane clock).
Reset: async-assert, sync-release on `clk156`.

#### 3.1.2 Step 1 — handshake assumptions

```systemverilog
asm_sc_download_ready_gated: assume property (
  @(posedge clk156) disable iff (reset)
    o_download_ready == (
      (rx_state == IDLING && enqueue_stage_count < ENQUEUE_STAGE_DEPTH_CONST) ||
      (rx_state != IDLING && payload_space_ready)));
```

This constraint captures the exact FSM behaviour that `sc_hub_pkt_rx.vhd`
implements around line 80–90 (the commented override noted in the SC
agent output). It is an `assume` when S1 is a predicate for S2 and an
`assert` when S1 is the unit under test.

```systemverilog
asm_sc_download_data_stable_while_blocked: assume property (
  @(posedge clk156) disable iff (reset)
    (i_download_data != 32'h0 && !o_download_ready) |=> $stable(i_download_data));
```

The "not zero" qualifier excludes idle NULL beats that the harness may
drive at any time; only real payload beats must stay stable under
backpressure.

#### 3.1.3 Step 2 — K-flag packet chunk structure

```systemverilog
typedef enum logic [3:0] {
  SC_KIND_PREAMBLE,    // datak[3:0] == 4'b1000, data[31:24] == 0xBC
  SC_KIND_HDR_W0,      // sc_type[1:0], fpga_id[17:2], rsvd, mask_m/s/t/r, atomic, rsvd
  SC_KIND_HDR_W1,      // start_address[23:0], order/domain[31:24]
  SC_KIND_HDR_W2,      // rw_length[15:0], rsvd[31:16]
  SC_KIND_DATA,        // payload word (if sc_type == WRITE or ATOMIC)
  SC_KIND_TRAILER,     // optional K28.4 trailer
  SC_KIND_NONE
} sc_kind_t;

typedef struct packed {
  bit [3:0]  kind;
  bit [31:0] qbits;       // 32-bit data payload
  bit [3:0]  datak;       // 4-bit K-flag mask
  bit [15:0] length_field; // for HDR_W2: propagate rw_length into packet_info[n+1..]
} sc_beat_t;
```

#### 3.1.4 Step 3 — per-kind structural constraints

```systemverilog
property prop_sc_preamble(int unsigned n);
  packet_info[n].kind == SC_KIND_PREAMBLE |->
    i_download_datak == 4'b1000 &&
    i_download_data[31:24] == 8'hBC;
endproperty

property prop_sc_hdr_w0(int unsigned n);
  packet_info[n].kind == SC_KIND_HDR_W0 |->
    i_download_datak == 4'b0000 &&
    i_download_data[1:0] inside {2'b00, 2'b01, 2'b10} &&   // read/atomic/write
    i_download_data[31:29] == 3'b000;                       // reserved
endproperty

property prop_sc_hdr_w1(int unsigned n);
  packet_info[n].kind == SC_KIND_HDR_W1 |->
    i_download_datak == 4'b0000;
endproperty

property prop_sc_hdr_w2(int unsigned n);
  packet_info[n].kind == SC_KIND_HDR_W2 |->
    i_download_datak == 4'b0000 &&
    i_download_data[15:0] != 16'h0000 &&       // length is non-zero for a legal packet
    packet_info[n+1].length_field == i_download_data[15:0];  // propagate length
endproperty

property prop_sc_data(int unsigned n);
  packet_info[n].kind == SC_KIND_DATA |->
    i_download_datak == 4'b0000;
endproperty

property prop_sc_trailer(int unsigned n);
  packet_info[n].kind == SC_KIND_TRAILER |->
    i_download_datak == 4'b1000 &&
    i_download_data[31:24] == 8'h9C;
endproperty
```

The propagation of `rw_length` via `packet_info[n+1].length_field` is
the DVCon paper's "reach into the next chunk" trick. It lets the cascade
count exactly `rw_length` data beats and then require a trailer or a
new preamble, instead of quantifying over all possible run-lengths.

#### 3.1.5 Step 4 — cascade

```systemverilog
property prop_sc_pkt(int unsigned n);
  packet_info[n].kind == SC_KIND_PREAMBLE ? prop_sc_preamble(n) and prop_sc_pkt(n+1) :
  packet_info[n].kind == SC_KIND_HDR_W0   ? prop_sc_hdr_w0(n)   and prop_sc_pkt(n+1) :
  packet_info[n].kind == SC_KIND_HDR_W1   ? prop_sc_hdr_w1(n)   and prop_sc_pkt(n+1) :
  packet_info[n].kind == SC_KIND_HDR_W2   ? prop_sc_hdr_w2(n)   and prop_sc_pkt(n+1) :
  packet_info[n].kind == SC_KIND_DATA     ? prop_sc_data(n)     and
                                              (packet_info[n].length_field > 0 ?
                                                 prop_sc_pkt(n+1) : 1'b1) :
  packet_info[n].kind == SC_KIND_TRAILER  ? prop_sc_trailer(n) :
  packet_info[n].kind == SC_KIND_NONE     ? 1'b1 :
  1'b0;
endproperty
```

The data-beat recursion decrements `length_field` (implicitly: the next
chunk's `length_field` equals this chunk's `length_field - 1`). We
encode that decrement as a separate property:

```systemverilog
property prop_sc_length_decrement(int unsigned n);
  packet_info[n].kind == SC_KIND_DATA &&
  packet_info[n].length_field > 0
    |-> (packet_info[n+1].length_field == packet_info[n].length_field - 1);
endproperty
```

#### 3.1.6 Step 5 — driver

The driver walks a `packet[p].qbits[n]` array, putting `qbits` on
`i_download_data` and the corresponding `datak` nibble on `i_download_datak`,
then waits for `o_download_ready` before advancing to `n+1`. The driver
is synthesisable and reused across S1, S2, S6.

#### 3.1.7 Step 6 — generate

`pkt_good` selects between well-formed packets and malformed ones:

- `pkt_good=0, variant=EARLY_TRAILER` — trailer appears before length_field data beats
- `pkt_good=0, variant=EXTRA_DATA` — data beats appear after length_field exhausted
- `pkt_good=0, variant=KCHAR_IN_DATA` — datak non-zero on a DATA beat
- `pkt_good=0, variant=BAD_PREAMBLE` — datak=0 on the preamble
- `pkt_good=0, variant=TORN_PACKET` — new preamble in mid-packet (the BUG_HISTORY "packet drop on premature preamble restart" case)

#### 3.1.8 Step 7 — acceptance / rejection assertions

```systemverilog
ast_sc_valid_pkt_reaches_pkt_valid: assert property (
  @(posedge clk156) disable iff (reset)
    (pkt_good && $past(packet_info[0].kind == SC_KIND_PREAMBLE) && packet_info_drained)
      |-> ##[1:$FORMAL_SC_PARSE_LATENCY_MAX] o_pkt_valid);

ast_sc_bad_preamble_does_not_open: assert property (
  @(posedge clk156) disable iff (reset)
    (i_download_data[31:24] != 8'hBC || i_download_datak != 4'b1000)
      |-> !$rose(o_pkt_in_progress));

ast_sc_kchar_in_data_drops: assert property (
  @(posedge clk156) disable iff (reset)
    (o_pkt_in_progress && i_download_datak != 4'b0000)
      |=> !o_pkt_valid && $rose(pkt_drop_counter));

ast_sc_torn_packet_drops_partial: assert property (
  @(posedge clk156) disable iff (reset)
    (o_pkt_in_progress && i_download_data[31:24] == 8'hBC && i_download_datak == 4'b1000)
      |=> !o_pkt_valid && $rose(pkt_drop_counter));
```

The torn-packet property captures the BUG_HISTORY fix directly: a
premature preamble restart must drop the partial packet and bump the
drop counter, not silently continue parsing.

```systemverilog
ast_sc_waiting_write_space_no_drop: assert property (
  @(posedge clk156) disable iff (reset)
    (rx_state == WAITING_WRITE_SPACE && $stable(i_download_data) && $stable(i_download_datak))
      |=> !$rose(pkt_drop_counter));
```

This is the companion to the "burst drops in WAITING_WRITE_SPACE" fix
noted in `BUG_HISTORY.md` — stable-held repeat words in the WAITING
state must be treated as no-op, not as dropped beats.

#### 3.1.9 S1 coverage points

- `cov_sc_read_pkt_complete` — a SC read packet (sc_type=00) was parsed
  end-to-end and `o_pkt_valid` fired.
- `cov_sc_write_pkt_complete` — a SC write packet (sc_type=10) was parsed.
- `cov_sc_atomic_pkt_complete` — a SC atomic packet (sc_type=01) was parsed.
- `cov_sc_burst_length_255` — a packet with rw_length=255 completed.
- `cov_sc_burst_length_256` — a packet with rw_length=256 completed.
- `cov_sc_torn_packet_recovered` — a torn packet was dropped and a
  subsequent clean packet parsed.
- `cov_sc_backpressure_stall` — `o_download_ready` fell during packet
  ingestion and the packet still parsed correctly once the harness
  released backpressure.

### 3.2 Sub-plane S2 — sc_hub command / response pipeline

#### 3.2.1 Boundary signals

RTL: `sc_hub_v2.vhd` (main state machine), `sc_hub_cmd_pipe` (the
`altera_avalon_mm_bridge` instance at `s0`).

The `sc_hub_cmd_pipe` is a standard Avalon-MM bridge with the parameters:
- `ADDRESS_WIDTH=18` (word-addressed)
- `SYMBOL_WIDTH=8`
- `ADDRESS_UNITS=SYMBOLS` (byte-addressed on the bridge side even
  though the slave side sees word addresses)
- `MAX_BURST_SIZE=256`
- `PIPELINE_COMMAND=1`
- `PIPELINE_RESPONSE=1`

AVMM master port (output of `sc_hub_cmd_pipe.m0`):
- `m0_address[17:0]`
- `m0_read`
- `m0_write`
- `m0_writedata[31:0]`
- `m0_readdata[31:0]` (input)
- `m0_waitrequest` (input)
- `m0_readdatavalid` (input)
- `m0_burstcount[8:0]`
- `m0_byteenable[3:0]`

#### 3.2.2 Step 1 — AVMM master handshake

The standard Avalon-MM master contract:

```systemverilog
asm_avmm_addr_stable_while_waitreq: assume property (
  @(posedge clk156) disable iff (reset)
    ((m0_read || m0_write) && m0_waitrequest) |=>
      ((m0_read || m0_write) && $stable(m0_address) && $stable(m0_burstcount) &&
       $stable(m0_writedata) && $stable(m0_byteenable)));

asm_avmm_no_command_during_waitreq: assume property (
  @(posedge clk156) disable iff (reset)
    (m0_waitrequest && !(m0_read || m0_write)) |-> 1'b1);  // trivially satisfied

asm_avmm_mutex_rw: assume property (
  @(posedge clk156) disable iff (reset)
    !(m0_read && m0_write));

asm_avmm_burstcount_nonzero_on_cmd: assume property (
  @(posedge clk156) disable iff (reset)
    (m0_read || m0_write) |-> (m0_burstcount >= 9'd1 && m0_burstcount <= 9'd256));
```

The `readdatavalid` contract on the response side:

```systemverilog
asm_avmm_rdvalid_implies_prior_read: assume property (
  @(posedge clk156) disable iff (reset)
    m0_readdatavalid |-> outstanding_read_count > 0);

asm_avmm_rdvalid_does_not_overrun_burst: assume property (
  @(posedge clk156) disable iff (reset)
    m0_readdatavalid |-> rdvalid_beat_count < expected_burst_beats);
```

`outstanding_read_count` and `expected_burst_beats` are auxiliary
counters maintained in the formal bind based on accepted read commands.

#### 3.2.3 Step 2 — command / response phase structure

```systemverilog
typedef enum logic [2:0] {
  AVMM_PHASE_IDLE,
  AVMM_PHASE_CMD,       // read or write accepted
  AVMM_PHASE_BURST_DATA, // further data beats in a burst write
  AVMM_PHASE_RESPONSE,  // waiting for readdatavalid or response beat
  AVMM_PHASE_ERROR
} avmm_phase_t;

typedef struct packed {
  bit [2:0]  phase;
  bit [17:0] addr;
  bit [8:0]  burstcount;
  bit        rw;             // 0=read, 1=write
  bit [8:0]  beats_remaining;
} avmm_cmd_state_t;
```

#### 3.2.4 Step 3 — phase-transition constraints

```systemverilog
asm_phase_cmd_requires_read_or_write: assume property (
  @(posedge clk156) disable iff (reset)
    (phase == AVMM_PHASE_CMD) |-> (m0_read || m0_write));

asm_phase_response_only_after_read: assume property (
  @(posedge clk156) disable iff (reset)
    (phase == AVMM_PHASE_RESPONSE && rw == 1'b0) |-> outstanding_read_count > 0);
```

#### 3.2.5 Step 4 — AVMM cascade

```systemverilog
property prop_avmm_phase(int unsigned n);
  (phase_seq[n] == AVMM_PHASE_IDLE     ? prop_avmm_idle(n)     and prop_avmm_phase(n+1) :
   phase_seq[n] == AVMM_PHASE_CMD      ? prop_avmm_cmd(n)      and prop_avmm_phase(n+1) :
   phase_seq[n] == AVMM_PHASE_BURST_DATA ? prop_avmm_burst(n)  and prop_avmm_phase(n+1) :
   phase_seq[n] == AVMM_PHASE_RESPONSE ? prop_avmm_response(n) and
                                           (phase_seq[n].beats_remaining > 0 ?
                                              prop_avmm_phase(n+1) : 1'b1) :
   1'b0);
endproperty
```

The `beats_remaining` counter is the DVCon propagation trick again; it
lets us count read-data beats across the response phase without a
global counter.

#### 3.2.6 Step 5 — driver

The driver for S2 is a different IPC abstraction than S1: it has to
emit AVMM command phases (address + burstcount + rw) and then observe
the response. The two drivers are linked at the S1→S2 seam: an S1
packet that hits a legal slave triggers an S2 command phase.

#### 3.2.7 Step 6 — generate

The `pkt_good` flag at the S2 level encodes AVMM-protocol-level
malformation: missing burst-data beat, address change during burst,
`readdatavalid` without a prior read, etc.

#### 3.2.8 Step 7 — sc_hub response framing assertions

After the slave responds, `sc_hub` frames the response back onto the
upload path. The response frame carries an ACK bit (bit 16 of the
reply address field) and a 2-bit `rsp` field (bits 19:18, per the
sc_hub v2 overlay chapter 4.7). Formal asserts:

```systemverilog
ast_sc_response_ack_on_ok: assert property (
  @(posedge clk156) disable iff (reset)
    (m0_readdatavalid && !m0_waitrequest && response_is_from_current_cmd)
      |=> ##[1:$FORMAL_SC_RESP_LATENCY_MAX]
        (sc_upload_valid && sc_upload_data[16] == 1'b1 && sc_upload_data[19:18] == 2'b00));

ast_sc_response_slverr_on_waitreq_timeout: assert property (
  @(posedge clk156) disable iff (reset)
    (m0_waitrequest throughout ##[0:RD_TIMEOUT_CYCLES] 1'b1)
      |=> ##[1:$FORMAL_SC_RESP_LATENCY_MAX]
        (sc_upload_valid && sc_upload_data[16] == 1'b1 && sc_upload_data[19:18] == 2'b10));

ast_sc_response_decerr_on_unmapped: assert property (
  @(posedge clk156) disable iff (reset)
    (m0_read && !decode_hits_any_slave)
      |=> ##[1:$FORMAL_SC_RESP_LATENCY_MAX]
        (sc_upload_valid && sc_upload_data[19:18] == 2'b11));
```

`RD_TIMEOUT_CYCLES=1024` per the SC agent map; the same bound applies
to write timeouts.

#### 3.2.9 S2 coverage points

- `cov_sc_single_read` — a 1-beat read completed with ACK=1, rsp=00.
- `cov_sc_single_write` — a 1-beat write completed with ACK=1, rsp=00.
- `cov_sc_burst_read_256` — a 256-beat burst read completed.
- `cov_sc_burst_write_256` — a 256-beat burst write completed.
- `cov_sc_decerr_unmapped` — a read to an unmapped address returned rsp=11.
- `cov_sc_slverr_timeout` — a slave held waitrequest for ≥1024 cycles
  and the hub framed a SLVERR response.
- `cov_sc_read_write_interleaved` — a read command was in flight while
  a write command was accepted.

### 3.3 Sub-plane S3 — Control-path slave AVMM conformance

#### 3.3.1 Enumerated slave list with apertures

All word addresses are `sc_hub` packet-word addresses (byte_addr / 4).
The Qsys aperture base (byte address) is shown for reference.

| Slave | Byte base | Word base | Width | Mode | Burst | Aperture size |
|---|---|---|---|---|---|---|
| `scratch_pad_ram` | 0x00000 | 0x0000 | 32 | RW | N (SRAM) | 256 words |
| `onewire_master_controller_0.csr` | 0x11000 | 0x4400 | 32 | RW | 1 | 16 words |
| `max10_prog_avmm_0.csr_avmm` | 0x12000 | 0x4800 | 32 | RW | 1 | 16 words |
| `charge_injection_pulser_0.csr_avmm` | 0x13000 | 0x4C00 | 32 | WO | 1 | 16 words |
| `firefly_xcvr_ctrl_0.firefly` | 0x14000 | 0x5000 | 32 | RW | 1 | 32 words |
| `on_die_temp_sense_ctrl.csr` | 0x15000 | 0x5400 | 32 | RO | 1 | 16 words |
| `mm_bridge.s0` | 0x20000 | 0x8000 | 32 | RW | 256 | large (datapath) |
| `mutrig_cfg_ctrl_0.avmm_csr` | 0x3F010 | 0xFC04 | 32 | RW | 1 | scattered |

#### 3.3.2 Step 1 — slave-side AVMM sink contract

Each slave is an AVMM sink. Standard sink assumptions:

```systemverilog
generate
  for (genvar s = 0; s < NUM_CONTROL_SLAVES; s++) begin : g_slave_contract
    ast_slave_waitreq_only_during_cmd[s]: assert property (
      @(posedge clk156) disable iff (reset)
        slave_waitrequest[s] |-> (slave_read[s] || slave_write[s]));

    ast_slave_readdata_stable_during_rdvalid[s]: assert property (
      @(posedge clk156) disable iff (reset)
        slave_readdatavalid[s] |-> !$isunknown(slave_readdata[s]));
  end
endgenerate
```

#### 3.3.3 Step 2 — per-slave register map chunks

We describe each slave's register map as a packed struct, then use
the DVCon methodology per slave. The key slaves:

**`scratch_pad_ram`** — 256 32-bit words, pure SRAM.

```systemverilog
typedef struct packed {
  bit [7:0]  word_addr;  // 8-bit word index within aperture
  bit [31:0] data;
} scratch_pad_beat_t;
```

Properties: read returns the last-written value; burst reads return
consecutive word addresses.

**`onewire_master_controller_0.csr`** — FSM-based, 4-bit address.
Registers (observational; confirm against RTL):

```
0x0  ctrl     : [0]=start, [1]=reset_pulse, [2:3]=dq_line_select
0x1  status   : [0]=busy, [1]=err, [7:4]=dq_presence
0x2  txdata   : [7:0]=byte to transmit
0x3  rxdata   : [7:0]=byte received
0x4  timing0  : various timing parameters
0x5  timing1  : various timing parameters
0x6  config   : [0]=strong_pullup, [1]=overdrive_mode
0x7  reserved
```

**`max10_prog_avmm_0.csr_avmm`** — MAX10 SPI programmer, 4-bit address.

```
0x0  cmd      : [7:0]=SPI command opcode
0x1  addr_hi  : [31:16] of program address
0x2  addr_lo  : [15:0] of program address
0x3  data     : [31:0] program data
0x4  status   : [0]=busy, [1]=err, [7:4]=state
0x5..0xF  reserved
```

**`firefly_xcvr_ctrl_0.firefly`** — I2C master for Firefly optical
modules, 5-bit address, supports two modules.

```
0x00  module_sel   : [0]=module_a/b, [4:1]=rsvd
0x01  device_addr  : [6:0] I2C device address, [7]=rsvd
0x02  reg_addr     : [7:0]=register address to read/write
0x03  tx_data      : [7:0]=byte to transmit
0x04  rx_data      : [7:0]=byte received
0x05  status       : [0]=busy, [1]=err, [2]=nack
0x06  ctrl         : [0]=start, [1]=stop
0x07..0x1F  reserved
```

**`on_die_temp_sense_ctrl.csr`** — Arria V on-die sensor, 4-bit
address, read-only.

```
0x0  temp_raw     : [9:0]=raw ADC, [31:10]=rsvd
0x1  temp_celsius : [15:0]=signed Celsius×16
0x2  status       : [0]=valid, [1]=err
```

**`charge_injection_pulser_0.csr_avmm`** — write-only, 4-bit address.
Writes trigger charge-injection pulses on the emulator datapath.

**`mutrig_cfg_ctrl_0.avmm_csr`** — 4× MuTRiG trigger config, scattered.

#### 3.3.4 Step 3 — per-slave semantic constraints

Example for scratch_pad_ram:

```systemverilog
property prop_scratchpad_write_read(int unsigned addr, bit [31:0] dv);
  (slave_write[SCRATCH] && slave_address[SCRATCH] == addr && slave_writedata[SCRATCH] == dv
   && !slave_waitrequest[SCRATCH])
    |=> ##[1:$] (slave_read[SCRATCH] && slave_address[SCRATCH] == addr &&
                 !slave_waitrequest[SCRATCH] && slave_readdatavalid[SCRATCH] &&
                 slave_readdata[SCRATCH] == dv);
endproperty
```

This property proves the RAM is a pure shadow memory.

Example for onewire (much weaker, FSM-specific):

```systemverilog
ast_onewire_busy_while_fsm_active: assert property (
  @(posedge clk156) disable iff (reset)
    (slave_write[ONEWIRE] && slave_address[ONEWIRE] == 4'h0 && slave_writedata[ONEWIRE][0] == 1'b1
     && !slave_waitrequest[ONEWIRE])
      |=> ##[1:$ONEWIRE_FSM_MAX_LATENCY] (onewire_fsm_state != IDLE));

ast_onewire_readdata_from_rxdata: assert property (
  @(posedge clk156) disable iff (reset)
    (slave_read[ONEWIRE] && slave_address[ONEWIRE] == 4'h3 && slave_readdatavalid[ONEWIRE])
      |-> slave_readdata[ONEWIRE][7:0] == internal_rxdata_reg);
```

Example for charge_injection_pulser (write-only):

```systemverilog
ast_chargeinj_read_decerr: assert property (
  @(posedge clk156) disable iff (reset)
    (slave_read[CHARGE_INJ] && !slave_waitrequest[CHARGE_INJ])
      |=> slave_readdatavalid[CHARGE_INJ] && slave_readdata[CHARGE_INJ] == 32'h0);  // or DECERR response
```

The write-only slave's handling of reads must be well-defined: either
it returns 0 with no error, or it raises a decode-error response to
the hub. Confirm against RTL before finalizing.

#### 3.3.5 Step 4 — no slave-level cascade (each slave is a single
AVMM sink; the packet cascade is at the S2 level)

#### 3.3.6 Step 5 — driver

The S3 driver is the S2 driver with a per-slave address decoder that
maps the 18-bit hub address to the per-slave aperture.

#### 3.3.7 Step 6 — generate

`pkt_good=0, variant=WRITE_TO_READ_ONLY` stresses the RO slaves;
`variant=READ_FROM_WRITE_ONLY` stresses charge_injection_pulser;
`variant=BURST_ON_SINGLE_BEAT_SLAVE` stresses onewire, max10, firefly
which advertise max burst = 1.

#### 3.3.8 Step 7 — per-slave response assertions

```systemverilog
ast_scratchpad_burst_read_matches: assert property (
  @(posedge clk156) disable iff (reset)
    (slave_read[SCRATCH] && slave_burstcount[SCRATCH] == BC &&
     !slave_waitrequest[SCRATCH])
      |-> burst_readdata_matches_shadow_memory(slave_address[SCRATCH], BC));
```

```systemverilog
ast_single_beat_slave_ignores_burstcount: assert property (
  @(posedge clk156) disable iff (reset)
    (slave_read[s] && slave_burstcount[s] > 1 &&
     s inside {ONEWIRE, MAX10, FIREFLY, CHARGE_INJ, TEMP_SENSE})
      |-> ##[1:$] (burst_fragmented_or_errored));
```

The bench today has a burst-vs-single compare matrix (per the `sc.md`
case inventory); this assertion captures the expected behaviour of
single-beat slaves when a burst arrives.

#### 3.3.9 S3 coverage points

- For each slave s: `cov_s3_read_hits[s]`, `cov_s3_write_hits[s]`,
  `cov_s3_burst_hits[s]`, `cov_s3_waitrequest_hits[s]`.
- `cov_s3_scratchpad_all_words` — every address in 0..255 has been
  read and written at least once.
- `cov_s3_firefly_both_modules` — both Firefly I2C targets accessed.
- `cov_s3_onewire_all_six_dq_lines` — each of the 6 DQ lines exercised.

### 3.4 Sub-plane S4 — mm_bridge gateway at 0x20000

#### 3.4.1 Boundary signals

`mm_bridge.s0` is an Altera `altera_avalon_mm_bridge` with the same
parameters as `sc_hub_cmd_pipe` except the bridge sits in the control
plane (156.25 MHz). Its `m0` port is the datapath-path aperture
(14-bit word address on the external `mm_pipeline_avmm_lvds.m0` side),
and it CDC-crosses to the 125 MHz datapath clock.

#### 3.4.2 Step 1 — bridge handshake

Bridge is a pipelined pass-through; same AVMM contract as S2. The key
additional assumption is that the CDC is handled by a Qsys AUTO clock-
crossing adapter, which we take as a black box at this scope (the CDC
plane §6 covers its internals).

#### 3.4.3 Step 2 — pass-through model

The bridge has no register decode of its own; it forwards all commands
to `m0`. Formal models it as a pair of FIFOs (one for commands, one
for responses) bounded to depth equal to the adapter's pipeline depth.

#### 3.4.4 Step 3 — forwarding constraints

```systemverilog
ast_mmbridge_command_preserved: assert property (
  @(posedge clk156) disable iff (reset)
    (s0_read || s0_write) && !s0_waitrequest
      |-> ##[1:$FORMAL_MMBRIDGE_LATENCY_MAX]
        (m0_read == $past(s0_read) && m0_write == $past(s0_write) &&
         m0_address == $past(s0_address) && m0_burstcount == $past(s0_burstcount) &&
         m0_writedata == $past(s0_writedata) && m0_byteenable == $past(s0_byteenable));
```

(Where the `$past(..., N)` depth matches `$FORMAL_MMBRIDGE_LATENCY_MAX`;
the actual shape of this assertion uses a tagged-payload shadow similar
to R6's CDC shadow.)

```systemverilog
ast_mmbridge_response_preserved: assert property (
  @(posedge clk156) disable iff (reset)
    m0_readdatavalid |-> ##[1:$FORMAL_MMBRIDGE_LATENCY_MAX]
      (s0_readdatavalid && s0_readdata == $past(m0_readdata));
```

#### 3.4.5 Step 4 — no cascade

#### 3.4.6 Step 5 — driver

S2 drives `s0`; no additional driver.

#### 3.4.7 Step 6 — generate

`pkt_good=0, variant=CDC_STALL` drops `m0_waitrequest` to 1 forever
to verify the bridge propagates backpressure to `s0_waitrequest` and
the upstream hub times out with SLVERR.

#### 3.4.8 Step 7 — CDC assertions

Bounded-latency property across the CDC:

```systemverilog
ast_mmbridge_bounded_fwd_latency: assert property (
  @(posedge clk156) disable iff (reset)
    (s0_read && !s0_waitrequest)
      |-> ##[1:$FORMAL_MMBRIDGE_LATENCY_MAX] m0_read);

ast_mmbridge_bounded_rev_latency: assert property (
  @(posedge clk125) disable iff (reset)
    m0_readdatavalid
      |-> ##[1:$FORMAL_MMBRIDGE_LATENCY_MAX] s0_readdatavalid);
```

(Cross-domain — each assertion is stated in the appropriate clock's
domain; formal tools like JasperGold and OneSpin allow this.)

#### 3.4.9 S4 coverage points

- `cov_mmbridge_read_forwarded` — a datapath read traversed the bridge.
- `cov_mmbridge_write_forwarded` — a datapath write traversed the bridge.
- `cov_mmbridge_burst_forwarded` — a burst command traversed the bridge.
- `cov_mmbridge_cdc_backpressure` — `m0_waitrequest` asserted and the
  upstream `s0_waitrequest` followed within the bound.

### 3.5 Sub-plane S5 — Datapath-path slave AVMM conformance

#### 3.5.1 Enumerated slaves

Behind `mm_bridge.s0`, addresses are word-addressed on the external
seam (divide byte address by 4):

| Slave | Byte | Word | Notes |
|---|---|---|---|
| LVDS RX controller CSR | 0x00–0x40 | 0x000 | Rx error counters |
| MuTRiG reset controller | 0x200–0x300 | 0x080 | Reconfig mgmt |
| `emulator_mutrig_[0..7].csr` | 0x2000–0x2200 | 0x800–0x880 | 8× 4-bit CSR (64 bytes each) |
| `dbg_mm2runctrl_0.csr` | 0x2200–0x2240 | 0x880 | RC debug alias |
| `histogram_statistics_0.hist_bin` | 0xA000–0xA400 | 0x2800 | 256 words bin RAM |
| `histogram_statistics_0.csr` | 0xA400–0xA480 | 0x2900 | CSR window |
| `histogram_statistics_1.hist_bin` | 0xA800–0xAC00 | 0x2A00 | 256 words bin RAM |
| `histogram_statistics_1.csr` | 0xAC00–0xAC80 | 0x2B00 | CSR window |
| `hit_stack_subsystem_0/1` ring buffers | 0xB000–0xB600 | 0x2C00–0x2E00 | 4× 128 byte each |

#### 3.5.2 Step 1 — per-slave contracts

Same shape as S3; each slave obeys the AVMM sink contract with the
appropriate burst and waitrequest behavior.

#### 3.5.3 Step 2 — per-slave register maps

**`emulator_mutrig_N.csr`** (per lane):

```
0x0  control   : [0]=enable, [2:1]=hit_mode (00=Poisson, 01=burst, 10=noise, 11=mixed), [3]=short_mode
0x1  rates     : [15:0]=hit_rate (8.8 fp), [31:16]=noise_rate (8.8 fp)
0x2  burst_cfg : [4:0]=burst_size, [12:8]=burst_center_local, [13]=cluster_cross_asic,
                 [21:14]=cluster_center_global, [29:26]=cluster_lane_count
0x3  seed      : [31:0]=PRNG seed
0x4  tx_mode   : [2:0]=tx_mode, [3]=gen_idle, [7:4]=asic_id
0x5  status    : [15:0]=frame_count, [25:16]=last_event_count (RO)
0x6..0xF  reserved
```

**`histogram_statistics_N.csr`** (per bank):

```
0x0  UID       : RO, IP identifier
0x1  META      : RO, IP metadata
0x2  CONTROL   : [0]=enable, [1]=clear, [2]=dual_bank_select, [7:3]=rsvd
0x3  LEFT      : scan-left limit
0x4  reserved
0x5  BIN_WIDTH : histogram key field width
0x6  KEY_LOC   : bit position of histogram key
0x7  KEY_VALUE : expected key value for gating
0x8  UNDERFLOW : hits below LEFT (RO counter)
0x9  OVERFLOW  : saturation counter (RO)
0xA  INTERVAL  : accumulation interval in clocks
0xB  BANK      : current active bank selector
0xC  reserved
0xD  TOTAL     : total hits in current interval (RO)
0xE  DROPPED   : upstream-dropped hits (RO)
0xF..0x1F  reserved
```

**`hit_stack_subsystem_N.ring_buffer_cam_M.csr`** (per CAM, 4 per
subsystem, 2 subsystems): ring buffer control, fill level, etc.

#### 3.5.4 Step 3 — per-slave semantic constraints

Example for histogram CSR clear:

```systemverilog
ast_hist_clear_writes_through: assert property (
  @(posedge clk125) disable iff (reset)
    (slave_write[HIST0] && slave_address[HIST0] == 4'h2 &&
     slave_writedata[HIST0][1] == 1'b1 && !slave_waitrequest[HIST0])
      |=> ##[1:$HIST_CLEAR_LATENCY_MAX] (hist_accumulator_0 == 32'h0));

ast_hist_total_monotonic_during_run: assert property (
  @(posedge clk125) disable iff (reset)
    (run_state == RUNNING && hist_enable[HIST0])
      |-> !$fell(hist_total[HIST0]) until (slave_write[HIST0] &&
                                             slave_address[HIST0] == 4'h2 &&
                                             slave_writedata[HIST0][1] == 1'b1));
```

Example for emulator CSR enable during TERMINATING:

```systemverilog
ast_emu_disable_stops_new_frames: assert property (
  @(posedge clk125) disable iff (reset)
    (slave_write[EMU_N] && slave_address[EMU_N] == 4'h0 &&
     slave_writedata[EMU_N][0] == 1'b0 && !slave_waitrequest[EMU_N])
      |=> ##[1:$EMU_FRAME_LATCH_MAX] !emulator_mutrig_N_new_frame_open);
```

#### 3.5.5 Step 4 — no cascade

#### 3.5.6 Step 5 — driver

The S5 driver reuses the S2 driver plus the S4 bridge. The
word-addressed translation happens in the driver (byte → word by /4).

#### 3.5.7 Step 6 — generate

`pkt_good=0, variant=WORD_ADDR_NOT_DIVIDED_BY_4` stresses the
2026-04-17 BUG_HISTORY fix: the bench must supply word addresses;
sending a byte address should produce a DECERR. The property is:

```systemverilog
ast_dp_word_addr_alignment: assert property (
  @(posedge clk125) disable iff (reset)
    (bridge_read && bridge_address[1:0] != 2'b00 && !hits_wraparound_aperture)
      |=> $rose(decerr_counter));
```

This captures the historical mistake concretely so any regression
fires the assertion.

#### 3.5.8 Step 7 — per-slave response assertions

Identical structure to S3 step 7, parameterised over the datapath
slave table.

#### 3.5.9 S5 coverage points

- For each DP slave d: `cov_s5_read_hits[d]`, `cov_s5_write_hits[d]`,
  `cov_s5_burst_hits[d]`.
- `cov_s5_hist0_all_bins_read` — every bin address in the 256-word
  aperture has been read.
- `cov_s5_emu_all_lanes_csr` — CSR read/written on every one of the
  8 emulator lanes.
- `cov_s5_ringbuf_all_cams` — 8 ring-buffer CSRs (4 per subsystem × 2
  subsystems) have been accessed.
- `cov_s5_word_vs_byte_regression` — the byte-aligned read fired the
  DECERR assertion (proves the 2026-04-17 fix is still in place).

### 3.6 Sub-plane S6 — Address decode and cross-aperture behavior

#### 3.6.1 Address-decode table

The sc_hub has a single flat 18-bit word address space with decode
ranges:

| Aperture | Word range | Byte range | Target |
|---|---|---|---|
| Control-path | 0x00000–0x20000 | 0x00000–0x80000 | on-chip slaves |
| Datapath (via mm_bridge) | 0x20000–0x3E000 | 0x80000–0xF8000 | through bridge |
| Reserved | 0x3E000–0x3F000 | 0xF8000–0xFC000 | DECERR |
| MuTRiG cfg | 0x3F010–0x3F014 | 0xFC040–0xFC050 | mutrig_cfg_ctrl_0 |
| sc_hub internal | 0x3FA0–0x3FAF | 0xFE80–0xFEBF | sc_hub CSR |
| Above aperture | 0x3FAF0–0x3FFFF | 0xFEBC0–0xFFFFF | DECERR |

#### 3.6.2 Step 3 — decode constraints

```systemverilog
function automatic logic decode_hits_control(input logic [17:0] addr);
  return (addr < 18'h20000);
endfunction

function automatic logic decode_hits_datapath(input logic [17:0] addr);
  return (addr >= 18'h20000 && addr < 18'h3E000);
endfunction

function automatic logic decode_hits_internal(input logic [17:0] addr);
  return (addr >= 18'h3FA00 && addr < 18'h3FB00);
endfunction

function automatic logic decode_is_unmapped(input logic [17:0] addr);
  return !decode_hits_control(addr) &&
         !decode_hits_datapath(addr) &&
         !decode_hits_internal(addr) &&
         (addr != 18'h3F010 && addr != 18'h3F014);  // mutrig_cfg exceptions
endfunction
```

#### 3.6.3 Step 7 — decode assertions

```systemverilog
ast_decode_unmapped_decerr: assert property (
  @(posedge clk156) disable iff (reset)
    (hub_cmd_accept && decode_is_unmapped(hub_cmd_addr))
      |=> ##[1:$FORMAL_DECODE_LATENCY_MAX]
        (upload_resp_valid && upload_resp_rsp == 2'b11));

ast_burst_does_not_cross_aperture: assert property (
  @(posedge clk156) disable iff (reset)
    (hub_cmd_accept && hub_cmd_burstcount > 1)
      |-> (
        (decode_hits_control(hub_cmd_addr) &&
         decode_hits_control(hub_cmd_addr + hub_cmd_burstcount - 1)) ||
        (decode_hits_datapath(hub_cmd_addr) &&
         decode_hits_datapath(hub_cmd_addr + hub_cmd_burstcount - 1))));
```

The cross-aperture property is important because a burst that crosses
from control into datapath territory would mix response latencies
between the two planes; it should be fragmented or rejected.

#### 3.6.4 Step 7 continued — timeout framing

```systemverilog
ast_hub_rd_timeout_after_1024: assert property (
  @(posedge clk156) disable iff (reset)
    (hub_cmd_accept && hub_cmd_rw == READ &&
     slave_waitrequest_persistent throughout ##[0:1024] 1'b1)
      |=> (upload_resp_valid && upload_resp_rsp == 2'b10));

ast_hub_wr_timeout_after_1024: assert property (
  @(posedge clk156) disable iff (reset)
    (hub_cmd_accept && hub_cmd_rw == WRITE &&
     slave_waitrequest_persistent throughout ##[0:1024] 1'b1)
      |=> (upload_resp_valid && upload_resp_rsp == 2'b10));
```

`RD_TIMEOUT_CYCLES = WR_TIMEOUT_CYCLES = 1024` from the SC agent map.

#### 3.6.5 S6 coverage points

- `cov_decode_each_control_slave` — one hit on each control slave.
- `cov_decode_each_datapath_slave` — one hit on each datapath slave.
- `cov_decode_unmapped_hits_decerr` — an unmapped address returned
  DECERR.
- `cov_decode_cross_aperture_burst_rejected` — a burst spanning the
  boundary was fragmented or errored.
- `cov_hub_rd_timeout_fired` — a read timed out at 1024 cycles.
- `cov_hub_wr_timeout_fired` — a write timed out at 1024 cycles.

### 3.7 Sub-plane S7 — Burst vs single compare

The integration bench already has a "full-aperture burst-vs-single
compare matrix" (per `cases/sc.md`). We capture the expected equivalence
as a formal property:

```systemverilog
ast_burst_equals_single_for_bursty_slaves: assert property (
  @(posedge clk156) disable iff (reset)
    (hub_cmd_accept && hub_cmd_rw == READ && hub_cmd_burstcount == 4 &&
     hub_cmd_addr inside {SCRATCH_BASE + 0, HIST0_BIN_BASE + 0})
      |-> (upload_resp_data_burst(4) == {
        four_consecutive_single_reads(hub_cmd_addr, 4)}));
```

`four_consecutive_single_reads()` is a logical shadow that drives four
single-beat reads at addresses `hub_cmd_addr..+3` and concatenates their
data.

For non-burstable slaves, the property is that the burst is fragmented
or errored:

```systemverilog
ast_burst_fragments_at_nonbursty: assert property (
  @(posedge clk156) disable iff (reset)
    (hub_cmd_accept && hub_cmd_burstcount > 1 &&
     is_nonbursty_slave(decode_slave_of(hub_cmd_addr)))
      |-> (response_is_fragmented || response_is_error));
```

`is_nonbursty_slave()` enumerates ONEWIRE, MAX10, FIREFLY, CHARGE_INJ,
TEMP_SENSE (per the S3 burst matrix).

#### 3.7.1 S7 coverage points

- `cov_burst_scratchpad_4` — burst-4 vs single-4 matched on scratchpad.
- `cov_burst_scratchpad_256` — burst-256 vs 256 singles matched.
- `cov_burst_hist_bin_256` — full histogram bin window read in one burst.
- `cov_burst_onewire_rejected` — burst-4 on onewire fragmented or errored.

### 3.8 Sub-plane S8 — Response framing back onto upload link

#### 3.8.1 Boundary signals

The sc_hub's response output is a 36-bit AVST source feeding
`upload_pkt_mux.in1` (see R7). Signals:

- `upload_sc_data[35:0]`
- `upload_sc_valid`
- `upload_sc_ready` (input)
- `upload_sc_startofpacket`
- `upload_sc_endofpacket`

Each SC response packet carries: preamble (K-character), echoed header,
echoed address, echoed length, response data (for reads), trailer.

#### 3.8.2 Response packet structure

```systemverilog
typedef enum logic [3:0] {
  SCR_KIND_PREAMBLE,    // K28.5
  SCR_KIND_HDR_ACK,     // header with ack bit [16] set
  SCR_KIND_HDR_ADDR,    // echoed address with rsp[19:18] bits
  SCR_KIND_HDR_LEN,     // echoed length (zero if no data)
  SCR_KIND_DATA,        // response data word (RO/RW reads)
  SCR_KIND_TRAILER,     // K28.4
  SCR_KIND_NONE
} scr_kind_t;
```

#### 3.8.3 Step 3 — response-framing constraints

```systemverilog
property prop_scr_preamble(int unsigned n);
  packet_info[n].kind == SCR_KIND_PREAMBLE |->
    upload_sc_startofpacket && upload_sc_data[35:32] == 4'b1000 &&
    upload_sc_data[31:24] == 8'hBC;
endproperty

property prop_scr_hdr_ack(int unsigned n);
  packet_info[n].kind == SCR_KIND_HDR_ACK |->
    upload_sc_data[16] == 1'b1 &&                  // ACK bit
    upload_sc_data[19:18] inside {2'b00, 2'b10, 2'b11};  // OK, SLVERR, DECERR
endproperty

property prop_scr_trailer(int unsigned n);
  packet_info[n].kind == SCR_KIND_TRAILER |->
    upload_sc_endofpacket && upload_sc_data[35:32] == 4'b1000 &&
    upload_sc_data[31:24] == 8'h9C;
endproperty
```

#### 3.8.4 Step 7 — response-framing assertions

```systemverilog
ast_scr_one_response_per_command: assert property (
  @(posedge clk156) disable iff (reset)
    (hub_cmd_accept && hub_cmd_rw == READ)
      |=> ##[1:$FORMAL_SC_RESP_LATENCY_MAX]
        ($rose(upload_sc_startofpacket) && upload_sc_valid));

ast_scr_echoes_address_correctly: assert property (
  @(posedge clk156) disable iff (reset)
    (upload_sc_valid && upload_sc_startofpacket && packet_info[0].kind == SCR_KIND_HDR_ADDR)
      |-> (upload_sc_data[17:0] == $past(hub_cmd_addr, 1, upload_sc_valid)));

ast_scr_rsp_bits_match_slave_response: assert property (
  @(posedge clk156) disable iff (reset)
    (upload_sc_valid && packet_info[0].kind == SCR_KIND_HDR_ADDR)
      |-> (upload_sc_data[19:18] == expected_rsp_bits_from_slave_fsm()));
```

#### 3.8.5 S8 coverage points

- `cov_scr_read_ok_framed` — a read-OK response framed end-to-end.
- `cov_scr_write_ok_framed` — a write-OK response framed end-to-end.
- `cov_scr_slverr_framed` — a SLVERR response framed.
- `cov_scr_decerr_framed` — a DECERR response framed.
- `cov_scr_burst_all_data_beats` — a burst read's full data payload
  emerged on the upload link.

### 3.9 SC plane summary

The SC plane has eight sub-planes. The integration-critical properties
are:

- §3.1.8 `ast_sc_waiting_write_space_no_drop` and
  `ast_sc_torn_packet_drops_partial` — both are direct regression
  gates on the 2026-04-17 fixes in BUG_HISTORY.md.
- §3.5.7 `ast_dp_word_addr_alignment` — the word-addressed translation
  regression gate.
- §3.6.3 `ast_decode_unmapped_decerr` and `ast_burst_does_not_cross_aperture`
  — the decode-safety backbone.
- §3.8.4 `ast_scr_one_response_per_command` — no command goes
  unanswered, which is what the bench's `test_slowcontrol` replacement
  `sc_tool` depends on.

The hardest formal proof is §3.4.8's bidirectional bounded latency
across `mm_bridge` because it requires a tagged-payload CDC shadow,
similar to R6, but now with burst semantics.

---

## 4. Datapath (DP) plane

### 4.0 DP plane overview

The DP plane is the largest plane in this integration, decomposing
the datapath from per-lane emulator/LVDS ingress through eight parallel
frame-deassembly stages, a 4:1 RR arbiter, the MTS timestamp
preprocessor, and the hit-stack / frame-assembly / upload chain. It
has ten sub-planes.

The DP plane owns three distinct frame grammars:

1. **`hit_type0`** (45-bit beats out of `mutrig_frame_deassembly_0`): a
   frame header word followed by 1..N hit words and a trailer word. K28.0
   header, K28.4 trailer, K28.5 idle filler.
2. **`hit_type1`** (variable-width beats out of `mts_preprocessor`): a
   remapped timestamp-processed form of hit_type0, with TCC_8n, TCC_1n6,
   and optional ET_1n6 fields. SOP/EOP preserved from hit_type0.
3. **`hit_type3`** (36-bit beats out of `feb_frame_assembly_0`): the
   Mu3e standard FEB upload frame, with 1 preamble, 5 frame header words,
   N subheader+hit blocks, and 1 trailer. This is the grammar that
   reaches the SWB PHY ingress stub.

The K-symbol conventions at the hit_type3 grammar match the OPQ
ingress grammar (K285=0xBC preamble, K237=0xF7 subheader, K284=0x9C
trailer) because the OPQ IP and the FEB frame assembly share the
Mu3e standard frame.

### 4.1 Sub-plane D1 — emulator_mutrig per-lane generator

#### 4.1.1 Boundary signals

RTL: `emulator_mutrig/rtl/emulator_mutrig.sv`
Instances: `emulator_mutrig_[0..7]` in `mutrig_datapath_system_v3.qsys`.

Per-lane signals:
- `csr.address[3:0]` — CSR register address
- `csr.read`, `csr.write`
- `csr.readdata[31:0]`, `csr.writedata[31:0]`
- `csr.waitrequest`
- `asi_ctrl.data[8:0]` — 9-bit one-hot run-state (from emulator_ctrl_splitter)
- `asi_ctrl.valid`, `asi_ctrl.ready`
- `aso_tx8b1k.data[8:0]` — 9-bit emulator output (bit[8]=K-flag)
- `aso_tx8b1k.valid`, `aso_tx8b1k.ready`
- `aso_tx8b1k.channel[3:0]` — lane identifier
- `aso_tx8b1k.error[2:0]`
- `coe_inject_pulse` — per-lane charge-injection trigger

Clock: `i_clk` = 125 MHz (datapath `d_clk`).
Reset: `i_rst` async/sync.

#### 4.1.2 Step 1 — emulator egress contract

```systemverilog
ast_emu_tx_hold_on_backpressure: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (aso_tx8b1k_valid && !aso_tx8b1k_ready) |=>
      (aso_tx8b1k_valid && $stable(aso_tx8b1k_data) &&
       $stable(aso_tx8b1k_channel) && $stable(aso_tx8b1k_error)));

ast_emu_tx_error_clean_when_ok: assert property (
  @(posedge i_clk) disable iff (i_rst)
    aso_tx8b1k_valid |-> aso_tx8b1k_error inside {3'b000, 3'b001, 3'b010, 3'b100});
```

#### 4.1.3 Step 2 — emulator frame grammar

The emulator generates a MuTRiG-compatible 8b/1k stream. Frame shape:

```
K28.0 HDR | HDR_W0 | HDR_W1 | (HIT_W0 HIT_W1 ...)* | K28.4 TRAILER
```

We capture it as a chunked struct:

```systemverilog
typedef enum logic [3:0] {
  EMU_KIND_IDLE,         // K28.5 filler, data[7:0] == 0xBC, bit[8]=1
  EMU_KIND_HDR_KCHAR,    // K28.0, data[7:0] == 0x1C, bit[8]=1 (Mutrig frame header k-char)
  EMU_KIND_HDR_W0,       // frame counter MSB, bit[8]=0
  EMU_KIND_HDR_W1,       // frame counter LSB + frame length, bit[8]=0
  EMU_KIND_HIT_W0,       // hit word 0, bit[8]=0
  EMU_KIND_HIT_W1,       // hit word 1, bit[8]=0
  EMU_KIND_TRAILER,      // K28.4, data[7:0] == 0x9C, bit[8]=1
  EMU_KIND_NONE
} emu_kind_t;
```

#### 4.1.4 Step 3 — per-kind structural constraints

```systemverilog
property prop_emu_hdr_kchar(int unsigned n);
  packet_info[n].kind == EMU_KIND_HDR_KCHAR |->
    aso_tx8b1k_data[8] == 1'b1 &&
    aso_tx8b1k_data[7:0] == 8'h1C &&
    aso_tx8b1k_error == 3'b000;
endproperty

property prop_emu_hit_w0(int unsigned n);
  packet_info[n].kind == EMU_KIND_HIT_W0 |->
    aso_tx8b1k_data[8] == 1'b0;
endproperty

property prop_emu_trailer(int unsigned n);
  packet_info[n].kind == EMU_KIND_TRAILER |->
    aso_tx8b1k_data[8] == 1'b1 &&
    aso_tx8b1k_data[7:0] == 8'h9C;
endproperty

// Frame length propagation:
property prop_emu_hdr_w1_length(int unsigned n);
  packet_info[n].kind == EMU_KIND_HDR_W1 |->
    packet_info[n+1].length_field == aso_tx8b1k_data[7:0];  // or similar
endproperty
```

#### 4.1.5 Step 4 — emulator cascade

```systemverilog
property prop_emu_pkt(int unsigned n);
  packet_info[n].kind == EMU_KIND_HDR_KCHAR ? prop_emu_hdr_kchar(n) and prop_emu_pkt(n+1) :
  packet_info[n].kind == EMU_KIND_HDR_W0    ? prop_emu_hdr_w0(n)    and prop_emu_pkt(n+1) :
  packet_info[n].kind == EMU_KIND_HDR_W1    ? prop_emu_hdr_w1(n)    and prop_emu_pkt(n+1) :
  packet_info[n].kind == EMU_KIND_HIT_W0    ? prop_emu_hit_w0(n)    and prop_emu_pkt(n+1) :
  packet_info[n].kind == EMU_KIND_HIT_W1    ? prop_emu_hit_w1(n)    and
                                                (packet_info[n].length_field > 0 ?
                                                  prop_emu_pkt(n+1) : 1'b1) :
  packet_info[n].kind == EMU_KIND_TRAILER   ? prop_emu_trailer(n) :
  packet_info[n].kind == EMU_KIND_IDLE      ? prop_emu_idle(n)     and prop_emu_pkt(n+1) :
  packet_info[n].kind == EMU_KIND_NONE      ? 1'b1 :
  1'b0;
endproperty
```

#### 4.1.6 Step 5 — driver

The driver here is *the emulator itself*. It is not a formal driver in
the usual sense; we take the emulator's output as the driver for the
downstream DP plane and prove it generates legal `hit_type0`-grammar
frames under its PRNG. The PRNG is a trusted component (same fibonacci-
LCG as in `mutrig_common_pkg`).

We *do* need a driver for the CSR seam, which is stimulated by S5
through the mm_bridge. CSR writes program the emulator's rates,
burst config, seed, and tx_mode.

#### 4.1.7 Step 6 — generate

`pkt_good` has no meaning for the emulator output in the usual sense
(the emulator always produces legal frames by construction). We keep
the flag to flip between different emulator modes:

- `variant=POISSON_MODE` — hit_mode = 00 (csr[0][2:1])
- `variant=BURST_MODE` — hit_mode = 01
- `variant=NOISE_MODE` — hit_mode = 10
- `variant=MIXED_MODE` — hit_mode = 11
- `variant=DISABLED` — csr[0][0] = 0 (no hits generated)

#### 4.1.8 Step 7 — per-lane assertions

Run-state gating:

```systemverilog
ast_emu_no_hits_when_not_running: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (csr_enable && run_state != RUNNING)
      |-> !aso_tx8b1k_valid [*$FORMAL_EMU_DRAIN_MAX]);
```

Actually this is too strong; the emulator's internal FIFO must drain
first. The correct property is:

```systemverilog
ast_emu_no_new_frames_when_terminating: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (run_state == TERMINATING)
      |-> !$rose(aso_tx8b1k_valid && aso_tx8b1k_data == 9'h11C));  // no new K28.0 SOP
```

SOP/EOP discipline:

```systemverilog
ast_emu_no_nested_frame: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (aso_tx8b1k_valid && aso_tx8b1k_data == 9'h11C)
      |=> !(aso_tx8b1k_valid && aso_tx8b1k_data == 9'h11C) until_with
           (aso_tx8b1k_valid && aso_tx8b1k_data == 9'h19C));

ast_emu_eop_requires_open_frame: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (aso_tx8b1k_valid && aso_tx8b1k_data == 9'h19C)
      |-> packet_open);
```

CSR enable/disable:

```systemverilog
ast_emu_disable_stops_new_frames_formally: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (csr_write && csr_address == 4'h0 && csr_writedata[0] == 1'b0 && !csr_waitrequest)
      |=> ##[1:$EMU_FRAME_LATCH_MAX] !packet_open_new);
```

#### 4.1.9 D1 coverage points

- For each lane N: `cov_emu_lane_[N]_all_modes`
- `cov_emu_burst_mode_all_cluster_variants` — burst_cfg exercised
- `cov_emu_per_lane_frame_count_wrap` — frame_count wraps at 2^16
- `cov_emu_during_sync_no_hits` — in SYNC state, no hits produced
- `cov_emu_inject_pulse_triggers_frame` — charge-injection conduit
  triggered a burst frame

### 4.2 Sub-plane D2 — LVDS RX and decoded_lane_mux

#### 4.2.1 Boundary signals

RTL: `lvds_rx_28nm_0` + `lvds_rx_controller_pro_0` + per-lane
`decoded_lane_mux_[0..7]` (combinational RR mux).

Per lane:
- `asi_real.data[8:0]` — from LVDS RX
- `asi_real.valid`, `asi_real.error[2:0]`, `asi_real.channel[3:0]`
- `asi_emu.data[8:0]` — from emulator
- `asi_emu.valid`, `asi_emu.error[2:0]`, `asi_emu.channel[3:0]`
- `aso.data[8:0]`, `aso.valid`, `aso.error`, `aso.channel`

The mux selects between LVDS and emulator based on a one-bit CSR; the
INT bench uses the emulator path only.

#### 4.2.2 Step 1 — mux contract (stateless)

```systemverilog
ast_mux_one_source_per_beat: assert property (
  @(posedge i_clk) disable iff (i_rst)
    aso_valid |-> (asi_real_valid ^ asi_emu_valid));

ast_mux_data_passthrough: assert property (
  @(posedge i_clk) disable iff (i_rst)
    aso_valid |->
      (asi_real_valid ? (aso_data == asi_real_data) : (aso_data == asi_emu_data));
```

The mux has no state and no backpressure; whichever input is valid wins.

#### 4.2.3 D2 coverage points

- `cov_mux_emu_selected` — emulator path drove the output
- `cov_mux_real_selected` — LVDS path drove the output (INT bench does
  not exercise this; the coverage is vacuous but useful as a guard)
- `cov_mux_both_valid_mux_consistent` — if both inputs happen to be
  valid, only one wins

### 4.3 Sub-plane D3 — decoded_lane_fifo

#### 4.3.1 Boundary signals

RTL: `decoded_lane_fifo_[0..7]` (Altera Avalon-ST FIFO wrapper).
Depth: 128, width: 45 bits (9-bit data + 4-bit channel + 3-bit error +
valid/sop/eop markers).

Signals:
- `in.data[8:0]`, `in.valid`, `in.ready` (backpressure from FIFO)
- `in.error[2:0]`, `in.channel[3:0]`
- `in.startofpacket`, `in.endofpacket` (unused on this seam)
- `out.*` (mirror of in, downstream to `mutrig_datapath_subsystem`)
- `csr.*` (fill-level readback)

The BUG_HISTORY entry around "shallow FIFO drop on lane mux ingress"
calls out that this FIFO drops on overflow. That is the safety hazard
formal must bound.

#### 4.3.2 Step 1 — FIFO contract

```systemverilog
ast_fifo_full_asserts_backpressure: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (fill_level == 128) |-> !in_ready);

ast_fifo_empty_no_out_valid: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (fill_level == 0) |-> !out_valid);
```

#### 4.3.3 Step 2 — drop accounting

```systemverilog
typedef struct packed {
  bit [7:0] fill_level;
  bit [15:0] drop_count;
} fifo_state_t;
```

```systemverilog
ast_fifo_drops_only_on_overflow: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (drop_count > $past(drop_count))
      |-> ($past(in_valid) && $past(!in_ready)));
```

This captures the shallow-FIFO-drop contract: the drop counter only
advances when an input was valid and the FIFO refused it (the only
drop mechanism the RTL has).

The critical invariant is that the DUT must *announce* every drop via
the drop_count (or expose it somehow), so downstream consumers can
reason about lost beats. If the RTL does not expose a drop counter
today, §4.3 flags it as an open item:

```systemverilog
// TODO: verify that decoded_lane_fifo_[N] exposes a drop_count in its CSR.
// If not, the BUG_HISTORY shallow-drop hazard cannot be formally bounded
// and the property above degrades to a cover.
```

#### 4.3.4 Step 7 — ordering property

```systemverilog
ast_fifo_out_order_matches_in_order: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (out_valid && out_ready)
      |-> (out_data == shadow_next_non_dropped_in_data));
```

`shadow_next_non_dropped_in_data` is the formal bind's shadow FIFO,
maintained by recording every accepted `in_data` at write and reading
at out.

#### 4.3.5 D3 coverage points

- `cov_fifo_never_fills` — fill level stayed < 128 over the trace
- `cov_fifo_fills_and_drains` — fill level reached 128 and later 0
- `cov_fifo_drops_happened` — at least one drop was accounted for
- `cov_fifo_drain_under_backpressure` — FIFO drained while upstream
  was still asserting valid

### 4.4 Sub-plane D4 — mutrig_datapath_subsystem (frame deassembly +
backpressure FIFO)

#### 4.4.1 Boundary signals

RTL: `mutrig_frame_deassembly/rtl/frame_rcv_ip.vhd` plus the
backpressure FIFO wrapper in `mutrig_datapath_system_v3.qsys`.

Per instance (8 instances, `mutrig_datapath_subsystem_[0..7]`):
- `decoded_din[8:0]` — from D3 FIFO out
- `run_ctrl[8:0]` — from splitter (R5)
- `hit_type0_out[44:0]` — 45-bit hit_type0 stream
- `hit_type0_out.valid`, `.ready`, `.startofpacket`, `.endofpacket`
- `hit_type0_out.channel[3:0]`, `.error[2:0]`
- `headerinfo[41:0]` — separate conduit carrying frame headers
  (routes to `mutrig_injector_0`)
- `backpressure_fifo_csr.*` — CSR for FIFO fill-level readback

#### 4.4.2 Step 1 — hit_type0 egress contract

```systemverilog
ast_ht0_hold_on_backpressure: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (hit_type0_valid && !hit_type0_ready) |=>
      (hit_type0_valid && $stable(hit_type0_data) &&
       $stable(hit_type0_sop) && $stable(hit_type0_eop) &&
       $stable(hit_type0_channel) && $stable(hit_type0_error)));

ast_ht0_sop_sideband: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (hit_type0_sop || hit_type0_eop) |-> hit_type0_valid);
```

#### 4.4.3 Step 2 — hit_type0 grammar

```systemverilog
typedef enum logic [3:0] {
  HT0_KIND_HEADER,     // first beat of frame, sop=1
  HT0_KIND_HIT_W0,     // hit word part 0
  HT0_KIND_HIT_W1,     // hit word part 1
  HT0_KIND_TRAILER,    // last beat, eop=1
  HT0_KIND_IDLE,       // K28.5 padding (valid=0 or filler beat)
  HT0_KIND_NONE
} ht0_kind_t;
```

The 45-bit data field decomposes (observed from RTL):

```
bit [44]     : K-flag
bit [43:40]  : K-symbol code when K-flag=1, else reserved
bit [39:36]  : asic[3:0]
bit [35:31]  : channel[4:0]
bit [30:16]  : T_CC[14:0]
bit [15:11]  : T_Fine[4:0]
bit [10:6]   : E_CC[14:0] (truncated)
bit [5:1]    : E_fine[4:0] (truncated)
bit [0]      : E_Flag | T_BadHit | E_BadHit (encoded)
```

(The reviewer should confirm this layout against the exact VHDL
record definition before the first formal run.)

#### 4.4.4 Step 3 — hit_type0 constraints

```systemverilog
property prop_ht0_header(int unsigned n);
  packet_info[n].kind == HT0_KIND_HEADER |->
    hit_type0_sop && !hit_type0_eop &&
    hit_type0_data[44] == 1'b1 &&
    hit_type0_data[43:40] == 4'h0;  // K28.0 code field
endproperty

property prop_ht0_hit_w0(int unsigned n);
  packet_info[n].kind == HT0_KIND_HIT_W0 |->
    !hit_type0_sop && !hit_type0_eop &&
    hit_type0_data[44] == 1'b0;
endproperty

property prop_ht0_trailer(int unsigned n);
  packet_info[n].kind == HT0_KIND_TRAILER |->
    hit_type0_eop && !hit_type0_sop &&
    hit_type0_data[44] == 1'b1 &&
    hit_type0_data[43:40] == 4'h4;  // K28.4 code field
endproperty
```

#### 4.4.5 Step 4 — cascade

Similar cascade to D1; the frame length is encoded in the header's
frame-length field which is reflected in `packet_info[n].length_field`.

#### 4.4.6 Step 5 — driver

D1→D2→D3 chain drives the ingress of D4 (via `decoded_din`). No
additional driver.

#### 4.4.7 Step 6 — generate

`pkt_good=0` variants:
- `variant=MISSING_TRAILER` — drop the K28.4 trailer; frame deassembly
  should time out or emit error flag.
- `variant=EXTRA_HEADER` — K28.0 in mid-frame; should restart frame
  or drop partial.
- `variant=CRC_ERROR` — trailer's CRC-16 mismatches; should assert
  error bit [1] of the error[2:0] field.
- `variant=BAD_HIT_FLAG` — hit word has T_BadHit or E_BadHit; error[0].

#### 4.4.8 Step 7 — assertions

```systemverilog
ast_ht0_frame_well_formed_when_input_ok: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (decoded_din_frame_was_legal && run_state == RUNNING)
      |-> ##[1:$FORMAL_HT0_PARSE_LATENCY_MAX]
        (hit_type0_valid && hit_type0_sop && hit_type0_error == 3'b000));

ast_ht0_error_on_corrupt_frame: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (decoded_din_frame_had_crc_error)
      |-> ##[1:$FORMAL_HT0_PARSE_LATENCY_MAX]
        (hit_type0_valid && hit_type0_error[1] == 1'b1));

ast_ht0_no_output_when_not_running: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (run_state != RUNNING && !frame_in_flight)
      |-> !hit_type0_valid);
```

The backpressure FIFO has its own properties:

```systemverilog
ast_bpfifo_backpressure_to_decoded: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (bpfifo_fill == 128) |-> !bpfifo_in_ready);

ast_bpfifo_no_drop: assert property (
  @(posedge i_clk) disable iff (i_rst)
    !$rose(bpfifo_drop_counter));  // this FIFO *does not* drop; it backpressures
```

The two FIFOs (D3 and D4.bpfifo) differ: D3 drops silently, D4
backpressures. This is the safety boundary the BUG_HISTORY flags and
formal must verify stays that way.

#### 4.4.9 D4 coverage points

- For each lane N: `cov_ht0_frame_complete[N]`, `cov_ht0_bpfifo_filled[N]`,
  `cov_ht0_crc_error[N]`, `cov_ht0_bad_hit_flag[N]`
- `cov_ht0_frame_during_terminating` — frame in flight when
  TERMINATING state asserted; frame drains without new-frame open
- `cov_ht0_frame_count_rollover` — internal frame counter wrapped

### 4.5 Sub-plane D5 — mux_mutrig2processor 4:1 RR arbitration

#### 4.5.1 Boundary signals

RTL: `mux_mutrig2processor` (for lanes 0..3 → MTS 0) and
`mux_mutrig2processor_0` (for lanes 4..7 → MTS 1). Each is a 4:1 RR mux.

Per mux:
- 4× `in[N].data[44:0]`, `in[N].valid`, `in[N].ready`, `in[N].sop`,
  `in[N].eop`, `in[N].channel`, `in[N].error` (from `hist_rate_splitter`)
- `out.data[36:0]` — 37-bit (hit_type0 + feedback steering bits)
- `out.valid`, `out.ready`, `out.sop`, `out.eop`

#### 4.5.2 Step 1 — AVST sink×4 and source×1

Each of the four input ports is a standard AVST sink; the output is
a standard AVST source. The mux's unique property is packet-granular
arbitration: once a port wins SOP, it holds the grant until EOP.

```systemverilog
ast_rr_grant_locked_until_eop: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (out_valid && out_sop && out_ready)
      |=> (grant == $past(grant)) throughout (out_valid && out_eop && out_ready)[->1]);

ast_rr_grant_onehot: assert property (
  @(posedge i_clk) disable iff (i_rst)
    out_valid |-> $onehot(grant));
```

#### 4.5.3 Step 2 — arbitration state

```systemverilog
typedef struct packed {
  bit [1:0] rr_counter;    // 4-state RR pointer
  bit [3:0] grant;         // one-hot active grant
  bit       in_frame;      // true while SOP ≤ current ≤ EOP
} rr_state_t;
```

#### 4.5.4 Step 3 — RR discipline constraints

```systemverilog
ast_rr_advances_after_eop: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (out_valid && out_eop && out_ready)
      |=> (rr_counter == $past(rr_counter) + 1) || all_ports_empty);

ast_rr_selects_only_valid_port: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (grant != 4'h0) |-> in_valid[onehot_to_index(grant)]);
```

#### 4.5.5 Step 4 — no cascade (frames just pass through)

#### 4.5.6 Step 5 — driver

D4 drives all four inputs; no additional driver.

#### 4.5.7 Step 6 — generate

`pkt_good=0, variant=CONCURRENT_SOP` drives SOP on all four ports in
the same cycle; only one should win. `variant=STARVED_PORT` keeps one
port's valid high forever; the RR should still eventually select it.

#### 4.5.8 Step 7 — fairness

```systemverilog
ast_rr_no_starvation: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (in_valid[N] && !in_ready[N])
      |=> (in_ready[N] within $FORMAL_RR_STARVATION_BOUND));
```

with `$FORMAL_RR_STARVATION_BOUND` = worst-case frame length × (4-1) + 1.

The "RR fairness not proven across arbitrary traffic mixes" item from
the DP agent output is exactly this property. The formal version
closes it.

#### 4.5.9 D5 coverage points

- `cov_rr_each_port_wins` — each of the 4 ports has won arbitration
  at least once.
- `cov_rr_concurrent_sop_arbitrated` — all 4 ports had SOP available
  in the same cycle, and RR picked one.
- `cov_rr_starvation_bounded` — a port waited up to
  $FORMAL_RR_STARVATION_BOUND cycles and then won.
- `cov_rr_histogram_backfeed_gate` — RR blocked on ready gated by
  histogram feedback; other ports remained blocked too (no bypass).

### 4.6 Sub-plane D6 — mts_preprocessor (hit_type0 → hit_type1)

#### 4.6.1 Boundary signals

RTL: `mutrig_timestamp_processor/mts_processor.vhd`. Two instances:
`mts_preprocessor_0` (from mux_0 → hit_stack_0) and
`mts_preprocessor_1` (from mux_1 → hit_stack_1).

Per instance:
- `hit_type0_in[44:0]` — from mux output (after RR)
- `run_ctrl[8:0]` — from splitter
- `hit_type1_out[*]` — variable-width (TCC_8n + TCC_1n6 + ET_1n6)
- `hit_type1_out.valid`, `.ready`, `.sop`, `.eop`, `.channel[3:0]`, `.error[2:0]`
- `debug_ts[35:0]`, `debug_burst[35:0]`, `ts_delta[35:0]` — debug output
- CSR aperture (5 words: control, discard_count, latency, count_hi,
  count_lo)

#### 4.6.2 Step 1 — hit_type1 egress contract

Same AVST source contract as D4.

#### 4.6.3 Step 2 — hit_type1 grammar

```systemverilog
typedef enum logic [3:0] {
  HT1_KIND_HEADER,     // sop=1
  HT1_KIND_HIT,        // TCC_8n/TCC_1n6/ET_1n6 word
  HT1_KIND_TRAILER,    // eop=1
  HT1_KIND_NONE
} ht1_kind_t;
```

Field decomposition (per MTS RTL):
```
TCC_8n[12:0]    : 8-ns timestamp counter, coarse
TCC_1n6[5:0]    : 1.6-ns fine timestamp
ET_1n6[5:0]     : 1.6-ns energy-time interval (optional)
error[2:0]      : preserved from hit_type0
channel[3:0]    : derived as channel_out = "00" & tcc_8n[5:4] (routing)
```

#### 4.6.4 Step 3 — hit_type1 constraints

```systemverilog
property prop_ht1_channel_routing(int unsigned n);
  packet_info[n].kind == HT1_KIND_HIT |->
    hit_type1_channel == {2'b00, hit_type1_tcc_8n[5:4]};
endproperty

property prop_ht1_timestamp_monotonic(int unsigned n);
  (hit_type1_valid && hit_type1_ready && run_state == RUNNING && packet_info[n].kind == HT1_KIND_HIT)
    |=> (hit_type1_tcc_8n >= $past(hit_type1_tcc_8n) ||
         $past(hit_type1_tcc_8n) inside {13'h1FFF, 13'h1FFE});  // allow wrap
endproperty
```

The monotonicity property handles wrap-around: a 13-bit counter wraps
every 2^13 × 8ns ≈ 65.5μs, and a legal wrap is visible as a
near-max-value `$past` followed by a near-zero current value.

#### 4.6.5 Step 5 — driver

D5 drives hit_type0_in; no additional driver.

#### 4.6.6 Step 6 — generate

`pkt_good=0, variant=HT0_HIT_BAD` drives a hit_type0 with error[0]=1;
MTS should propagate it to hit_type1 with error[0]=1.

#### 4.6.7 Step 7 — decode correctness

The MTS LUT is taken as trusted; the integration property is just
that decoded hit_type1 fields are derivable from hit_type0 fields
(the LUT gives the bit-exact result).

```systemverilog
ast_ht1_tcc_8n_from_ht0_tcc: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (hit_type1_valid && hit_type1_ready && packet_info[0].kind == HT1_KIND_HIT)
      |-> hit_type1_tcc_8n == lut_tcc_decode($past(hit_type0_data)));
```

`lut_tcc_decode()` is the ROM function exposed as a SystemVerilog
function in the formal bind (it mirrors the MTS implementation).

#### 4.6.8 D6 coverage points

- `cov_ht1_all_channels_routed` — every 4-value channel mapping used
- `cov_ht1_timestamp_wrap` — 13-bit TCC wrapped at least once
- `cov_ht1_error_propagated` — error bit propagated from hit_type0
- `cov_ht1_discard_count_advanced` — debug_discard_count register incremented

### 4.7 Sub-plane D7 — hit_stack_subsystem (4× ring_buffer_cam +
frame_assembly)

#### 4.7.1 Boundary signals

RTL: `ring-buffer_cam/rtl/ring_buffer_cam.vhd` (4 instances per
subsystem, 2 subsystems) + `feb_frame_assembly/feb_frame_assembly.vhd`
(1 per subsystem).

Per subsystem:
- `hit_type_1[*]` — from MTS (D6)
- `run_control_signal[8:0]` — from splitter
- `hit_type3[35:0]` — output frame word
- `hit_type3.valid`, `.ready`, `.sop`, `.eop`

#### 4.7.2 Step 1 — hit_type3 egress contract

Same AVST source contract.

#### 4.7.3 Step 2 — hit_type3 grammar

```systemverilog
typedef enum logic [3:0] {
  HT3_KIND_PREAMBLE,     // K28.5 preamble, sop=1
  HT3_KIND_HDR_W0,       // running_ts[47:16]
  HT3_KIND_HDR_W1,       // running_ts[15:0] | pkg_cnt[15:0]
  HT3_KIND_HDR_W2,       // running_shd_cnt[15:0] | hit_cnt[15:0]
  HT3_KIND_HDR_W3,       // send_ts[30:0]
  HT3_KIND_SUBHEADER,    // K28.4 subheader
  HT3_KIND_HIT,          // 32-bit hit word
  HT3_KIND_TRAILER,      // K28.4 trailer, eop=1
  HT3_KIND_NONE
} ht3_kind_t;
```

This is the same grammar as the OPQ ingress; the DV_FORMAL for OPQ
provides an identical decomposition in §2.2. The integration reuses
the OPQ grammar definitions as a library, so a single change to the
grammar propagates to both plans.

#### 4.7.4 Step 3 — hit_type3 constraints

```systemverilog
property prop_ht3_preamble(int unsigned n);
  packet_info[n].kind == HT3_KIND_PREAMBLE |->
    hit_type3_sop && hit_type3_data[35:32] == 4'b0001 &&
    hit_type3_data[7:0] == 8'hBC;
endproperty

property prop_ht3_subheader(int unsigned n);
  packet_info[n].kind == HT3_KIND_SUBHEADER |->
    hit_type3_data[35:32] == 4'b0001 &&
    hit_type3_data[7:0] == 8'hF7;
endproperty

property prop_ht3_hit(int unsigned n);
  packet_info[n].kind == HT3_KIND_HIT |->
    !hit_type3_sop && !hit_type3_eop &&
    hit_type3_data[35:32] == 4'b0000;
endproperty
```

#### 4.7.5 Step 4 — cascade (shared with OPQ §2.4)

The cascade counts subheaders and hits; the subheader's hit_cnt field
must match the number of hit words before the next subheader or the
trailer.

```systemverilog
property prop_ht3_subheader_hit_count_consistent(int unsigned n);
  (packet_info[n].kind == HT3_KIND_SUBHEADER && hit_type3_valid)
    |-> packet_info[n+1].total_length ==
        packet_info[n].total_length - 1 - hit_type3_data[15:8];  // hit_cnt field
endproperty
```

#### 4.7.6 Step 5 — driver

D6 drives hit_type_1; the hit-stack FSM assembles frames internally.

#### 4.7.7 Step 6 — generate

`pkt_good=0, variant=RINGBUF_FULL` stresses ring_buffer_cam full; the
hit-stack should assert backpressure on hit_type_1_in.

`variant=NO_HITS_IN_FRAME` — subheader with hit_cnt=0; frame assembly
should still emit a well-formed empty frame (or skip the subheader).

`variant=CROSS_SUBSYSTEM_LATENCY` — upper and lower subsystems emit at
different latencies; the seam equivalence still holds per-link.

#### 4.7.8 Step 7 — assertions

```systemverilog
ast_ht3_frame_well_formed: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (hit_type3_valid && hit_type3_sop)
      |-> ##[1:$FORMAL_HT3_FRAME_MAX]
        (hit_type3_valid && hit_type3_eop));

ast_ht3_frame_header_always_5_words: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (hit_type3_valid && hit_type3_sop && hit_type3_ready)
      |=> prop_ht3_header_sequence);

property prop_ht3_header_sequence;
  @(posedge i_clk) disable iff (i_rst)
    (packet_info[0].kind == HT3_KIND_PREAMBLE) ##1
    (packet_info[1].kind == HT3_KIND_HDR_W0) ##1
    (packet_info[2].kind == HT3_KIND_HDR_W1) ##1
    (packet_info[3].kind == HT3_KIND_HDR_W2) ##1
    (packet_info[4].kind == HT3_KIND_HDR_W3);
endproperty
```

#### 4.7.9 D7 ring-buffer properties

```systemverilog
ast_ringbuf_no_overflow_drop: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (ringbuf_fill == RINGBUF_DEPTH) |-> !ringbuf_in_ready);

ast_ringbuf_read_after_write_ordering: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (ringbuf_out_valid && ringbuf_out_ready)
      |-> (ringbuf_out_data == shadow_next_in_data));
```

#### 4.7.10 D7 coverage points

- `cov_ht3_frame_upper_complete`, `cov_ht3_frame_lower_complete`
- `cov_ht3_all_4_rings_exercised` — each of 4 rings in each subsystem
- `cov_ht3_subheader_max_hit_count` — subheader with hit_cnt = max
- `cov_ht3_zero_hit_subheader`
- `cov_ht3_ringbuf_backpressure` — ring asserted backpressure and MTS
  stalled; no drop

### 4.8 Sub-plane D8 — frame_assembly (upper/lower) — subsumed under D7

Frame assembly is internal to `hit_stack_subsystem_0/1`; its output is
the `hit_type3_*` stream. The assertions are stated at D7; this sub-
plane is named separately only so the boundary-condition matrix (§7)
can reference it by name.

### 4.9 Sub-plane D9 — histogram_statistics (CSR + bin RAM + accumulator)

#### 4.9.1 Boundary signals

RTL: `histogram_statistics/rtl/histogram_statistics.vhd`. Two
instances.

Per instance:
- `hist_fill_in[*]` — up to 8 lanes per histogram
- `ctrl[8:0]` — run-control gating from splitter
- `fill_out[*]` — ready-path feedback to `hist_rate_splitter`
- CSR aperture (per the register map in §3.5.3)
- Bin RAM (1024 × 32-bit)

#### 4.9.2 Step 3 — accumulator constraints

```systemverilog
ast_hist_accum_gated_by_running: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (hist_fill_in_valid && hist_fill_in_ready &&
     hist_enable && run_state == RUNNING)
      |=> (hist_bin[decoded_bin_index] ==
             saturating_add($past(hist_bin[decoded_bin_index]), 1)));

ast_hist_no_accum_when_not_running: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (run_state != RUNNING)
      |=> $stable(hist_bin[decoded_bin_index]));

ast_hist_underflow_counts: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (hist_fill_in_valid && hist_fill_in_ready && hit_below_left)
      |=> (hist_underflow == $past(hist_underflow) + 1));

ast_hist_overflow_counts: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (hist_fill_in_valid && hit_above_max)
      |=> (hist_overflow == $past(hist_overflow) + 1));
```

The saturation at 2^32-1 is modelled by `saturating_add`.

#### 4.9.3 Step 7 — CSR readback

```systemverilog
ast_hist_total_equals_accum_sum: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (slave_read[HIST] && slave_address[HIST] == 4'hD && slave_readdatavalid[HIST])
      |-> (slave_readdata[HIST] == sum_of_all_bins + hist_underflow + hist_overflow));
```

#### 4.9.4 Dual-bank rollover

```systemverilog
ast_hist_bank_switch_atomic: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (slave_write[HIST] && slave_address[HIST] == 4'h2 &&
     slave_writedata[HIST][1] == 1'b1 && !slave_waitrequest[HIST])
      |=> ##1 (bank_select != $past(bank_select)) && $stable(bank_data[$past(bank_select)]));
```

The "histogram bank rollover during read" open item from the DP agent
is exactly this property; a torn-data symptom would be a failure of
`$stable(bank_data[$past(bank_select)])` because the inactive bank's
data changed during the read.

#### 4.9.5 D9 coverage points

- `cov_hist_bank_switch` — both banks exercised
- `cov_hist_clear_zeros_all_bins`
- `cov_hist_underflow_exercised`
- `cov_hist_overflow_exercised`
- `cov_hist_total_equals_sum_at_each_boundary`
- `cov_hist_accum_halts_at_terminating` — TERMINATING stops increments
- `cov_hist_0_lane0_rate_divergence` — under differential rates on
  lane 0, the accumulator still advances

### 4.10 Sub-plane D10 — mutrig_injector (charge injection)

#### 4.10.1 Boundary signals

RTL: `mutrig_injector_0`.
- `headerinfo[0..7][41:0]` — from each D4 instance
- `runctl[8:0]` — from splitter
- `inject_pulse[0..7]` — conduit to emulator (triggers charge-injection
  event)

#### 4.10.2 Properties

```systemverilog
ast_inject_pulse_only_when_armed: assert property (
  @(posedge i_clk) disable iff (i_rst)
    $rose(inject_pulse[N]) |->
      (run_state == RUNNING && csr_inject_armed[N]));

ast_inject_pulse_triggers_emu_frame: assert property (
  @(posedge i_clk) disable iff (i_rst)
    $rose(inject_pulse[N])
      |-> ##[1:$FORMAL_EMU_INJECT_LATENCY_MAX]
        (emu_N_starts_burst_frame));
```

#### 4.10.3 D10 coverage points

- `cov_inject_each_lane` — each lane had a pulse
- `cov_inject_pulse_during_running` — pulse only when RUNNING
- `cov_inject_disarmed_no_pulse` — if CSR disarmed, no pulse even on
  valid headerinfo

### 4.11 DP plane summary

The DP plane has ten sub-planes and eight parallel lanes. The
integration-critical properties are:

- §4.3 `ast_fifo_drops_only_on_overflow` — the shallow-FIFO-drop
  hazard is bounded to "only on overflow" and nowhere else.
- §4.4 `ast_bpfifo_no_drop` — the backpressure FIFO between frame
  deassembly and the RR mux does not drop; it backpressures.
- §4.5 `ast_rr_no_starvation` — no lane is starved under adversarial
  traffic.
- §4.7 `ast_ht3_frame_well_formed` — every SOP on the upper/lower
  link closes with an EOP within a bounded cycle count (the "no
  broken frame under backpressure" property the user flagged in
  the original OPQ DV_FORMAL).
- §4.9 `ast_hist_bank_switch_atomic` — the dual-bank rollover is
  atomic under concurrent SC reads.

The hardest formal proof is §4.7's hit_type3 frame grammar combined
with §4.5's RR fairness, because they close the loop between MTS
timing, hit-stack storage, frame assembly, and upload presentation.

---

## 5. Cross-plane interactions

### 5.0 Cross-plane overview

The three main planes interact through four concrete seams:

| Seam | Producer plane | Consumer plane | Physical signal(s) |
|---|---|---|---|
| C1 | RC | DP | 16× `run_control_splitter.outN` → sinks in D1/D4/D5/D6/D7/D9 |
| C2 | SC | DP | `mm_bridge.m0` → per-slave AVMM in D1/D4/D9 |
| C3 | RC | SC upload merge | `upload_cdc_fifo.out` → `upload_pkt_mux.in2` |
| C4 | SC | SC upload merge | `sc_hub` response → `upload_pkt_mux.in1` |

Plus a three-way "all planes active" seam:

| Seam | Description |
|---|---|
| C5 | RC transitions state while SC is driving CSR burst while DP is emitting frames |

Each seam's correctness is a bidirectional equivalence: the producer's
egress contract restricts the consumer's ingress contract (so the
consumer can rely on it), and the consumer's backpressure restricts
the producer's egress rate (so the producer never overruns). We
already stated the per-plane contracts in §2–§4; this section states
the *seam* contracts.

### 5.1 Seam C1 — RC → DP run-state gating

#### 5.1.1 Forward direction (RC → DP)

Every DP consumer that samples `run_ctrl` must reflect the current
run-state within 1 cycle of the splitter delivering the beat. The R5
plane's `ast_all_consumers_agree` is a synchrony property; the C1
plane extends it with a gating property:

```systemverilog
ast_c1_running_gates_emulator: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (run_state_all == RUNNING)
      |=> ##[1:$FORMAL_EMU_WAKE_MAX] emu_hit_generation_enabled);

ast_c1_terminating_stops_new_frames: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (run_state_all == TERMINATING)
      |-> (!$rose(emu_new_frame_open[0]) &&
           !$rose(emu_new_frame_open[1]) &&
           !$rose(emu_new_frame_open[2]) &&
           !$rose(emu_new_frame_open[3]) &&
           !$rose(emu_new_frame_open[4]) &&
           !$rose(emu_new_frame_open[5]) &&
           !$rose(emu_new_frame_open[6]) &&
           !$rose(emu_new_frame_open[7])) [*$FORMAL_TERMINATE_DRAIN_MAX]);

ast_c1_running_gates_accumulator: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (run_state_all != RUNNING)
      |=> $stable(hist_bin[HIST0][*]) && $stable(hist_bin[HIST1][*]));

ast_c1_sync_triggers_ts_reset: assert property (
  @(posedge i_clk) disable iff (i_rst)
    ($rose(run_state_all == SYNC))
      |=> ##[1:$FORMAL_SYNC_TS_RESET_MAX]
        (mutrig_ts_counter[*] == 0));
```

#### 5.1.2 Reverse direction (DP → RC)

DP cannot stall RC; the splitter has no backpressure from its sinks in
the integration bench (they are all forced ready). The reverse-direction
property is therefore vacuous. We state it as:

```systemverilog
ast_c1_dp_never_stalls_rc: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (run_control_splitter_in_valid)
      |=> run_control_splitter_in_ready);
```

If a sink ever stalls in the future, this assertion fires and tells us
the RC path deadlock hazard is real.

#### 5.1.3 C1 coverage

- `cov_c1_all_running` — run_state_all == RUNNING on all 16 consumers
- `cov_c1_transition_during_frame` — frame in flight during
  RUNNING→TERMINATING transition, frame still drained correctly
- `cov_c1_sync_during_live_hits` — SYNC asserted while hit words in
  flight; hits before SYNC were drained, hits after SYNC have reset TS

### 5.2 Seam C2 — SC → DP CSR-during-traffic

#### 5.2.1 Forward direction

SC reads to the histogram or emulator CSR must return coherent values
even during live DP traffic. The contract depends on the slave:

```systemverilog
ast_c2_emu_csr_read_coherent: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (s5_slave_read[EMU_N] && s5_slave_readdatavalid[EMU_N])
      |-> (s5_slave_readdata[EMU_N] == emu_N_csr_register));
```

`emu_N_csr_register` is the shadow of the emulator's CSR; the emulator's
CSR is allowed to change during a read only if an ongoing frame is
being finalised (the `status` register reflecting `frame_count`). For
non-status registers:

```systemverilog
ast_c2_emu_csr_stable_during_read: assert property (
  @(posedge i_clk) disable iff (i_rst)
    (s5_slave_read[EMU_N] && s5_slave_address[EMU_N] inside {4'h0, 4'h1, 4'h2, 4'h3, 4'h4} &&
     s5_slave_readdatavalid[EMU_N])
      |-> $stable(emu_N_csr_shadow[s5_slave_address[EMU_N]]));
```

For the histogram, the dual-bank rollover property (§4.9.4) handles
concurrent access directly.

#### 5.2.2 Reverse direction

DP cannot stall the SC command path beyond `waitrequest` duration
(bounded by the 1024-cycle hub timeout). The property is:

```systemverilog
ast_c2_dp_slave_waitreq_bounded: assert property (
  @(posedge cclk156) disable iff (reset)
    (hub_cmd_accept && decode_hits_datapath(hub_cmd_addr) && hub_cmd_rw == READ)
      |-> (##[1:RD_TIMEOUT_CYCLES+1] (hub_cmd_response_received));
```

If a DP slave fails to respond within 1024 cycles, the hub produces a
SLVERR (§3.2.8); the assertion captures this bound.

#### 5.2.3 C2 coverage

- `cov_c2_emu_csr_read_during_frame` — read emu CSR while frame in flight
- `cov_c2_hist_read_during_accum` — read histogram bin while accumulator
  active
- `cov_c2_hist_clear_during_accum` — clear histogram while accumulator
  active; clear atomicity holds
- `cov_c2_dp_slverr_on_long_waitreq` — DP slave held waitreq > 1024;
  hub produced SLVERR

### 5.3 Seam C3 — RC ACK → upload_pkt_mux.in2

#### 5.3.1 Forward direction

The R6 CDC FIFO guarantees data preservation (§2.6.5). The C3 seam
adds the property that the CDC output packet is framed correctly for
`upload_pkt_mux.in2`:

```systemverilog
ast_c3_cdc_out_is_legal_ack_packet: assert property (
  @(posedge cclk156) disable iff (reset)
    (cdc_out_valid && cdc_out_startofpacket && cdc_out_ready)
      |=> ##[1:$FORMAL_ACK_LEN_MAX]
        (cdc_out_valid && cdc_out_endofpacket && cdc_out_ready));

ast_c3_mux_in2_sees_ack_grant: assert property (
  @(posedge cclk156) disable iff (reset)
    (cdc_out_valid && cdc_out_startofpacket)
      |-> ##[0:$FORMAL_RR_STARVATION_BOUND]
        (mux_grant == MUX_GRANT_RC));
```

#### 5.3.2 Reverse direction

The mux's backpressure from `upload_pkt_mux.out_ready` must propagate
back through in2_ready and through the CDC to `aso_upload_ready` at
the ACK producer. Formal traces the backpressure path:

```systemverilog
ast_c3_backpressure_propagates_to_ack_source: assert property (
  @(posedge cclk156) disable iff (reset)
    (!upload_out_ready && cdc_out_valid && !cdc_out_ready)
      |=> ##[1:$FORMAL_CDC_LATENCY_MAX]
        !cdc_in_ready);

ast_c3_backpressure_reaches_runctl_mgmt_host: assert property (
  @(posedge lvdspll_clk) disable iff (lvdspll_reset)
    (!cdc_in_ready)
      |=> ##[1:$FORMAL_LVDS_BACKPRESSURE_MAX]
        !aso_upload_ready);
```

#### 5.3.3 C3 coverage

- `cov_c3_ack_mux_delivers_end_to_end`
- `cov_c3_ack_mux_held_by_upper_frame` — an upper DP frame was in
  flight; ACK waited for RR and then delivered
- `cov_c3_ack_cdc_backpressure` — CDC backpressured; runctl_mgmt_host
  stalled; after drain, ACK delivered

### 5.4 Seam C4 — SC response → upload_pkt_mux.in1

#### 5.4.1 Forward direction

The SC response frame (S8) must reach `upload_pkt_mux.in1` intact.
Similar shape to C3.

```systemverilog
ast_c4_sc_response_is_framed_end_to_end: assert property (
  @(posedge cclk156) disable iff (reset)
    (upload_sc_valid && upload_sc_startofpacket && upload_sc_ready)
      |=> ##[1:$FORMAL_SC_RESP_FRAME_MAX]
        (upload_sc_valid && upload_sc_endofpacket && upload_sc_ready));

ast_c4_mux_in1_sees_sc_grant: assert property (
  @(posedge cclk156) disable iff (reset)
    (upload_sc_valid && upload_sc_startofpacket)
      |-> ##[0:$FORMAL_RR_STARVATION_BOUND]
        (mux_grant == MUX_GRANT_SC));
```

#### 5.4.2 C4 coverage

- `cov_c4_sc_response_delivers_end_to_end`
- `cov_c4_sc_read_burst_256_delivers`
- `cov_c4_sc_decerr_delivers_to_link0`

### 5.5 Seam C5 — Three-way contention (RC × SC × DP)

#### 5.5.1 Property

All three sources can be active on `upload_pkt_mux` in the same window.
Mux round-robin fairness (§2.7.9) guarantees each gets served within
a bounded window. The seam-level property is:

```systemverilog
ast_c5_three_way_fair_progress: assert property (
  @(posedge cclk156) disable iff (reset)
    (in0_valid && in0_startofpacket &&
     in1_valid && in1_startofpacket &&
     in2_valid && in2_startofpacket)
      |-> ##[0:3*$FORMAL_RR_STARVATION_BOUND]
        (all_three_sources_served_at_least_once));
```

`all_three_sources_served_at_least_once` is a sticky bit per source
that goes high on the matching SOP→EOP round-trip.

#### 5.5.2 Deadlock freedom

The worst-case scenario: DP emits upper frame (link 0 busy with upper),
SC emits response (queued at in1), RC emits ACK (queued at in2). The
mux must eventually serve all three. Formal bounded-liveness:

```systemverilog
ast_c5_no_three_way_deadlock: assert property (
  @(posedge cclk156) disable iff (reset)
    always_always_condition(in0_valid && in1_valid && in2_valid)
      |-> ##[0:16*$FORMAL_RR_STARVATION_BOUND]
        all_three_sources_served_at_least_once);
```

#### 5.5.3 C5 coverage

- `cov_c5_rc_sc_dp_all_three_active` — triple concurrency
- `cov_c5_rc_waits_for_sc_then_dp` — RR order captured
- `cov_c5_link0_frames_ordered_by_grant` — output frames on link 0
  come in the order dictated by the grant, never interleaved

### 5.6 Cross-plane summary

The cross-plane section has five seams. The most important one is C1
(RC → DP run-state gating) because every downstream DP correctness
property depends on the 16-way synchrony guarantee. C5 (three-way
contention) is the only integration-level deadlock-freedom property
and is a bounded-liveness proof.

---

## 6. CDC and reset-ownership plane

### 6.0 CDC overview

The integration has three clock domains:

1. `lvdspll_clk` = 125 MHz, LVDS-recovered. Powers `runctl_mgmt_host`
   RC ingress/decode and the first hop of RC ACK emission.
2. `mclk125` = 125 MHz, datapath clock. Powers all DP (emulators,
   frame deassembly, MTS, hit-stack, histogram, frame assembly).
3. `cclk156` = 156.25 MHz, control-plane clock. Powers `sc_hub`,
   control-path slaves, `mm_bridge`, `upload_pkt_mux`, and the
   datapath-facing side of `upload_cdc_fifo`.

Plus an internal LVDS-hardened domain for `lvds_rx_28nm_0`
(nominally 125 MHz recovered). For the purposes of this plan,
`lvdspll_clk` and the LVDS-recovered clock are treated as a single
domain (they are derived from the same reference and the PLL
synchronisation is inside the transceiver hardened cell).

### 6.1 CDC sub-plane X1 — lvdspll_clk ↔ cclk156 at runctl_mgmt_host CSR

#### 6.1.1 Seam

`runctl_mgmt_host_0.csr` is driven by the control-plane clock
(`cclk156`), while the FSM runs on `lvdspll_clk`. The CSR is a small
set of status counters read by SC; formal models the crossing as a
pair of 2FF synchronisers on each readback word.

#### 6.1.2 Properties

```systemverilog
ast_x1_csr_readback_eventually_reflects_fsm: assert property (
  @(posedge cclk156) disable iff (reset)
    (fsm_event_occurred_on_lvdspll)
      |=> ##[1:$FORMAL_2FF_SYNC_MAX*2]
        (csr_readback_counter_increments));
```

`$FORMAL_2FF_SYNC_MAX` = 3 (2 flops + 1 slack).

#### 6.1.3 X1 coverage

- `cov_x1_cmd_count_incrementing` — CMD_COUNT CSR register increments
  after every accepted command
- `cov_x1_err_count_incrementing` — ERR_COUNT register increments
  after every errored command

### 6.2 CDC sub-plane X2 — datapath (125) → control (156) for RC ACK

This is R6 in §2.6; X2 is the same sub-plane re-indexed for the CDC
table. All properties from §2.6.2–§2.6.8 apply verbatim.

### 6.3 CDC sub-plane X3 — datapath (125) → control (156) for upper
frames

#### 6.3.1 Seam

Upper frames (`hit_type3_upper`) are produced on `mclk125` by
`feb_frame_assembly_0` and consumed on `cclk156` by
`upload_pkt_mux.in0`. The CDC adapter is implicit in `feb_system_v3`
(per the DP agent's Open Unknown: "How do 125 MHz upper frames
actually cross to 156.25 MHz control plane before upload_pkt_mux?").

Formal needs to resolve this open item first. The likely implementation
is a Qsys AUTO clock-crossing adapter (handshake or FIFO) inserted
between `data_path_subsystem.hit_type3_upper` and
`upload_subsystem.upload_data`. Once resolved, the properties are
identical in shape to R6/X2:

```systemverilog
ast_x3_upper_frames_preserved_across_cdc: assert property (
  @(posedge cclk156) disable iff (reset)
    (upload_data_valid && upload_data_ready)
      |-> (upload_data_word == recorded_hit_type3_upper_at_same_tag));
```

#### 6.3.2 Bounded latency

```systemverilog
ast_x3_bounded_latency: assert property (
  @(posedge mclk125) disable iff (reset)
    (hit_type3_upper_valid && hit_type3_upper_ready)
      |-> ##[1:$FORMAL_X3_LATENCY_MAX]
        (upload_data_valid && upload_data_tag == $past(hit_type3_upper_tag)));
```

`$FORMAL_X3_LATENCY_MAX` is set by the adapter depth, which must be
explicitly enumerated once the adapter IP is identified. Conservative
initial bound: 32 cycles.

#### 6.3.3 X3 coverage

- `cov_x3_upper_frame_traversed` — at least one upper frame crossed
- `cov_x3_upper_backpressure` — backpressure at upload side reached
  back to hit-stack subsystem

### 6.4 CDC sub-plane X4 — cclk156 → mclk125 at mm_bridge

This is S4 in §3.4; X4 is the re-indexed view. All properties apply
verbatim. The key is the bidirectional bounded latency between
`s0` (control clock) and `m0` (datapath clock) and the preservation
of burst semantics across the crossing.

### 6.5 CDC sub-plane X5 — LVDS recovered → mclk125 at lvds_rx

#### 6.5.1 Seam

`lvds_rx_28nm_0` outputs a recovered clock (`outclock`) that is
nominally the same as `mclk125` (both 125 MHz from the same reference).
The transceiver cell guarantees bit-accurate transfer inside its
hardened I/O ring; formal treats this crossing as a zero-latency pass
with a metastability-resolution latency of 3 cycles maximum.

#### 6.5.2 Properties

```systemverilog
ast_x5_decoded_follows_lvds: assert property (
  @(posedge mclk125) disable iff (reset)
    (lvds_decoded_valid && lvds_decoded_ready)
      |-> lvds_decoded_data == lvds_hardened_decoder_output);
```

Taken as trusted at this scope (the hardened decoder is not
re-proven).

### 6.6 CDC sub-plane X6 — Reset ownership and release ordering

#### 6.6.1 Reset domains enumerated

| Reset | Domain | Source | Purpose |
|---|---|---|---|
| `lvdspll_reset` | `lvdspll_clk` | power-on + hard-reset from runctl_mgmt_host | RC ingress reset |
| `dp_hard_reset` | `lvdspll_clk` out, asynchronous | `runctl_mgmt_host.dp_hard_reset` | datapath hard reset |
| `ct_hard_reset` | `lvdspll_clk` out, async | `runctl_mgmt_host.ct_hard_reset` | control-plane hard reset |
| `ext_hard_reset` | `lvdspll_clk` out, async | `runctl_mgmt_host.ext_hard_reset` | external subsystem reset |
| `mclk125_reset` | `mclk125` | ext_reset_merge_cclk156 | datapath domain reset |
| `cclk156_reset` | `cclk156` | power-on + upload-side | control-plane domain reset |

#### 6.6.2 Release-ordering property

Hard resets have a defined release order because downstream IPs rely on
upstream IPs being out of reset before their own clocks become
meaningful.

```systemverilog
ast_x6_ext_resets_before_local: assert property (
  @(posedge lvdspll_clk) disable iff (1'b0)
    $fell(ext_hard_reset) |-> ##[1:$FORMAL_RESET_PROP_MAX] $fell(dp_hard_reset));

ast_x6_dp_reset_release_then_sync_count: assert property (
  @(posedge mclk125) disable iff (1'b0)
    ($fell(mclk125_reset)) |-> ##[1:$FORMAL_SYNC_COUNT_INIT_MAX]
      (mutrig_ts_counter[*] == 0));

ast_x6_sc_hub_reset_clears_download_fsm: assert property (
  @(posedge cclk156) disable iff (1'b0)
    ($fell(cclk156_reset)) |-> ##[1:8] (sc_hub_rx_state == IDLING));
```

#### 6.6.3 Soft-reset pulse properties

The `o_soft_reset_pulse` out of sc_hub (when an internal soft-reset
command is seen) must cascade through the control plane without
leaving any slave in a half-reset state:

```systemverilog
ast_x6_soft_reset_cascades_to_all_control_slaves: assert property (
  @(posedge cclk156) disable iff (reset)
    $rose(sc_hub_soft_reset_pulse)
      |=> ##[1:$FORMAL_SOFT_RESET_PROP_MAX]
        (&{scratch_pad_reset, onewire_reset, max10_reset, firefly_reset,
           charge_inj_reset, temp_sense_reset, mutrig_cfg_reset}));
```

The "staged reset trick" in the global CLAUDE.md (user's durable
instruction) explicitly recommends multi-cycle fan-out of reset; this
property captures the recommended behaviour.

#### 6.6.4 X6 coverage

- `cov_x6_cold_boot` — all three domain resets exited in order
- `cov_x6_warm_soft_reset` — sc_hub issued soft reset; all slaves
  reset; no half-reset state observed
- `cov_x6_cmd_reset_triggers_dp_reset` — CMD_RESET command produced
  dp_hard_reset pulse

### 6.7 CDC plane summary

The CDC plane has six sub-planes. The hardest formal proof is X3
(upper frame CDC) because the adapter type must be first identified
from the Qsys hierarchy. The most important property is X6's
release-ordering, because reset-ordering bugs manifest as spurious
traffic / spurious run-state transitions that the RC/SC/DP plane
properties would otherwise blame on the wrong IP.

---

## §7 — Boundary-condition matrix

This section enumerates every boundary-position × condition pair that
the formal environment must cover. OPQ's `DV_FORMAL.md` identifies
three boundary positions inside a single IP (ticket write port, credit
return, egress arbiter). An integration-level formal environment has
many more — each AVST seam, each AVMM seam, each CDC seam, each
run-state gate is a boundary position and each can be stressed with a
different set of edge conditions.

The matrix is organised by plane. For each plane we enumerate the
boundary positions (rows) and, for each, the edge-condition columns
we must drive / constrain / assert. A cell value of `ASSUMED` means
the condition is encoded as an `assume` on the boundary (driven by
constrained formal stimulus), `ASSERTED` means the condition is
checked by a concurrent property on the same boundary or at the
downstream sink, `COVERED` means we require a witness trace via
a `cover` property, and `—` means the condition is not meaningful
for that boundary (e.g. byteenable on a non-AVMM interface).

The matrix is long by design. A boundary that is not listed here is
out of formal scope by construction. A plane-level signoff sheet
later (§10) records the proof status of each row.

### 7.1 RC plane boundary matrix

#### 7.1.1 RC AVST boundaries

| # | Boundary | `sop_mid` | `eop_mid` | `empty_bits` | `bp_release` | `bp_hold` | `valid_gap` |
|---|----------|-----------|-----------|--------------|--------------|-----------|-------------|
| R-AVST-01 | synclink_rx → run_control_command_receiver | ASSUMED | ASSUMED | — (9-bit) | ASSUMED | ASSERTED | ASSUMED |
| R-AVST-02 | run_control_command_receiver → ack_packet_generator | — (sideband) | — | — | — | — | — |
| R-AVST-03 | ack_packet_generator → upload_cdc_fifo.in | ASSERTED | ASSERTED | — (36-bit aligned) | ASSUMED | ASSERTED | ASSERTED |
| R-AVST-04 | upload_cdc_fifo.out → upload_pkt_mux.in2 | ASSERTED | ASSERTED | — | ASSUMED | ASSERTED | ASSERTED |
| R-AVST-05 | run_control_command_receiver → run_control_splitter | — (parallel bus) | — | — | — | — | — |
| R-AVST-06 | run_control_splitter → each of 16 RC sinks | — (parallel bus) | — | — | — | — | — |

Columns glossary:
- `sop_mid` — `startofpacket` asserted mid-frame without a prior
  `endofpacket` (malformed producer).
- `eop_mid` — `endofpacket` on an invalid beat (`valid=0`) or without
  a paired `sop`.
- `empty_bits` — AVST `empty` field required to be zero unless the
  interface advertises sub-symbol granularity.
- `bp_release` — downstream `ready` deasserts after accepting a beat
  and then reasserts; data must not change.
- `bp_hold` — downstream `ready` held low for ≥ $FORMAL_BP_HOLD_MAX
  cycles; upstream must hold the beat.
- `valid_gap` — `valid=0` beats inside a packet (producer bubble);
  consumer must treat them as no-ops, not as packet boundaries.

Each ASSUMED cell is realised as a concrete `assume property` on the
boundary (e.g. `assume property (p_avst_sop_in_packet_forbidden(...));`).
Each ASSERTED cell is realised as a concurrent `assert property` on
the same signal set at the producer, and a mirrored `assert property`
at the downstream sink to prove the condition is preserved end-to-end.

#### 7.1.2 RC run-state boundaries

| # | Boundary | state_change | partial_ack | drain_packet | double_start | stop_during_run |
|---|----------|--------------|-------------|--------------|--------------|-----------------|
| R-RS-01 | run_control_command_receiver.run_state | ASSERTED | — | — | ASSERTED | ASSERTED |
| R-RS-02 | run_control_splitter fanout | ASSERTED | — | — | ASSERTED | ASSERTED |
| R-RS-03 | 16 RC sinks `run_state_changed_*` | ASSERTED | — | — | ASSERTED | ASSERTED |
| R-RS-04 | upload_cdc_fifo run-state annotation | — (data-agnostic) | — | — | — | — |
| R-RS-05 | ack_packet_generator CMD_RUN_PREP ack | COVERED | ASSERTED | ASSERTED | ASSERTED | ASSERTED |

Columns glossary:
- `state_change` — 2FF synchronised run-state step must be monotonic
  per command; no intermediate state appears.
- `partial_ack` — an ACK packet must either be fully emitted or
  suppressed on reset; no partial ACK escapes.
- `drain_packet` — on stop request during a long DP frame, the frame
  completes or is flushed but never torn.
- `double_start` — two CMD_RUN_PREP commands with no CMD_STOP in
  between must be idempotent (no latched garbage).
- `stop_during_run` — CMD_STOP mid-run must propagate to all 16
  sinks within $FORMAL_RS_FANOUT_MAX cycles and ack must fire once.

#### 7.1.3 RC FSM boundaries

| # | FSM | unreachable | deadlock | illegal_arc | payload_underrun | payload_overrun |
|---|-----|-------------|----------|-------------|------------------|-----------------|
| R-FSM-01 | RECV_IDLE → RECV_RX_PAYLOAD | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| R-FSM-02 | RECV_RX_PAYLOAD → RECV_LOGGING | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| R-FSM-03 | RECV_LOGGING → RECV_ACK_PENDING | ASSERTED | ASSERTED | ASSERTED | — | — |
| R-FSM-04 | RECV_ACK_PENDING → RECV_IDLE | ASSERTED | ASSERTED | ASSERTED | — | — |
| R-FSM-05 | ACK_GEN: ACK_IDLE → ACK_EMIT_W0..W3 | ASSERTED | ASSERTED | ASSERTED | — | ASSERTED |
| R-FSM-06 | ACK_GEN: ACK_EMIT_W3 → ACK_IDLE | ASSERTED | ASSERTED | ASSERTED | — | — |

Columns glossary:
- `unreachable` — no reachable state is marked unreachable by the tool.
- `deadlock` — bounded liveness on every arc enabled by an input
  event.
- `illegal_arc` — no transitions outside the declared arc set.
- `payload_underrun` — command declared N payload bytes and RX stream
  supplied fewer than N before `eop`.
- `payload_overrun` — command declared N payload bytes and RX stream
  supplied more than N before `eop`.

### 7.2 SC plane boundary matrix

#### 7.2.1 SC download-path AVST boundaries

| # | Boundary | sop_mid | eop_mid | kflag_torn | bp_release | bp_hold | cmd_id_skip |
|---|----------|---------|---------|------------|------------|---------|-------------|
| S-AVST-01 | synclink_rx → sc_hub.download_in | ASSUMED | ASSUMED | ASSUMED | ASSUMED | ASSERTED | ASSUMED |
| S-AVST-02 | sc_hub.download_frame_parser | — | — | ASSERTED | — | ASSERTED | ASSERTED |
| S-AVST-03 | sc_hub.avmm_master → mm_bridge.s0 | — (AVMM) | — | — | — | — | — |
| S-AVST-04 | sc_hub.download_in FIFO overflow | ASSUMED | — | — | ASSUMED | ASSERTED | — |

Column `kflag_torn` is SC-plane specific: the K-flag marker byte
(K28.5 at start, K28.4 at end) must not appear inside the payload;
if it does the frame is declared torn and the receiver must drop all
beats of that frame without forwarding to `avmm_master`.

Column `cmd_id_skip` covers the invariant that the incrementing
command-sequence nibble in every download beat must be monotonic
modulo 16; a skipped sequence counts as a torn frame.

#### 7.2.2 SC AVMM boundaries (per slave)

There are eight AVMM slaves reachable from `sc_hub`. Each one needs
the same boundary matrix driven at its instance. The rows below are
per-slave.

| # | Condition | scratch_pad | onewire | max10 | charge_inj | firefly | temp | mm_bridge | mutrig_cfg |
|---|-----------|-------------|---------|-------|------------|---------|------|-----------|------------|
| S-AVMM-01 | read_before_write | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| S-AVMM-02 | waitrequest_during_burst | ASSERTED | — | — | — | ASSERTED | — | ASSERTED | ASSERTED |
| S-AVMM-03 | byteenable_partial | ASSERTED | — | — | — | — | — | ASSERTED | — |
| S-AVMM-04 | write_to_RO_region | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| S-AVMM-05 | read_from_WO_region | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| S-AVMM-06 | address_out_of_range | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| S-AVMM-07 | back_to_back_read | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| S-AVMM-08 | unaligned_word_access | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| S-AVMM-09 | burst_2 | — | — | — | — | ASSERTED | — | ASSERTED | — |
| S-AVMM-10 | burst_max | — | — | — | — | — | — | ASSERTED | — |
| S-AVMM-11 | response_timeout | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| S-AVMM-12 | cmd_reset_during_burst | ASSERTED | — | — | — | ASSERTED | — | ASSERTED | ASSERTED |

`—` entries mean the slave does not support that feature (e.g.
onewire is a 1-beat register slave — no burst, no byteenable, no
mid-burst waitrequest meaningful). The environment must still
declare the entire row for the slave but mark the cell with an
empty assertion body — that prevents forgetting to revisit when the
slave is extended.

Column `write_to_RO_region` — the sc_hub slave map declares the
charge_injection_pulser as WO. Attempting a read must not cause
the slave to stall (`waitrequest` stuck) or produce undefined
`readdatavalid`; the expected response is a zero readdata with the
appropriate `response` code on the AVMM response fabric.

Column `cmd_reset_during_burst` — while a burst is in flight the
`sc_hub` CSR-space `soft_reset` bit may fire. The slave must either
let the burst complete or drop its `readdatavalid` cleanly; it must
not return ambiguous state (some beats valid, some suppressed).

#### 7.2.3 SC response-path boundaries

| # | Boundary | resp_ordered | resp_complete | resp_tagged | resp_backpressure | resp_cdc |
|---|----------|--------------|---------------|-------------|-------------------|----------|
| S-RESP-01 | each slave → sc_hub.avmm_response_fabric | ASSUMED | ASSUMED | — | ASSERTED | — |
| S-RESP-02 | sc_hub.avmm_response_fabric → response_packet_assembler | ASSERTED | ASSERTED | — | ASSERTED | — |
| S-RESP-03 | response_packet_assembler → upload_pkt_mux.in1 | ASSERTED | ASSERTED | — | ASSERTED | — |
| S-RESP-04 | upload_cdc_fifo (shared with RC) | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED |

Column `resp_ordered` — AVMM responses must appear in the same order
the commands were issued; if sc_hub ever multiplexes the response
fabric, a reorder window must be declared and proved bounded.

Column `resp_complete` — every completed AVMM command must produce
exactly one response packet on upload; no orphan (response without
command) and no dropped (command without response) is allowed.

Column `resp_tagged` — where relevant, the response packet must carry
the matching command-sequence tag (only meaningful at the upload CDC,
where a 2FF synchroniser could permute ordering if unprotected).

#### 7.2.4 SC decode boundaries

| # | Condition | scratch_pad | onewire | max10 | charge_inj | firefly | temp | mm_bridge | mutrig_cfg |
|---|-----------|-------------|---------|-------|------------|---------|------|-----------|------------|
| S-DEC-01 | byte_addr_alignment | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| S-DEC-02 | word_addr_alignment | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| S-DEC-03 | cross_slave_collision | ASSERTED | — | — | — | — | — | — | — |
| S-DEC-04 | hole_between_slaves | COVERED | — | — | — | — | — | — | — |

The `byte_addr_alignment` / `word_addr_alignment` pair enforces the
convention documented in the user's durable CLAUDE.md: sc_hub v2
reads/writes are word-addressed in the packet but Qsys-byte-addressed
in the decode. The environment must prove that every legal
byte-address the test emits resolves to the correct word-address at
the slave, and vice versa.

`cross_slave_collision` is a cover property: a byte address that
straddles two slave regions must not enable both slaves; the decode
must bind to exactly one slave. (This is an anti-hole check.)

### 7.3 DP plane boundary matrix

#### 7.3.1 DP ingress (per-channel) boundaries

The DP plane has 64 ingress channels (32 per MuTRiG × 2 MuTRiG).
Formally we prove the properties on a representative channel with
the symmetric assumption that all 64 are identical by construction.
The matrix below is for one channel; the environment replicates the
set across all 64 via generate.

| # | Boundary | frame_well_formed | crc_ok | mts_ok | k_word_ok | drop_on_overflow |
|---|----------|-------------------|--------|--------|-----------|------------------|
| D-IN-01 | emulator_mutrig.tx_lane → lvds_pad | ASSUMED | ASSUMED | — | ASSUMED | — |
| D-IN-02 | lvds_rx.recovered_stream → decoded_lane_fifo.in | ASSERTED | ASSERTED | — | ASSERTED | — |
| D-IN-03 | decoded_lane_fifo.out → mutrig_datapath.lane_in | ASSERTED | ASSERTED | — | ASSERTED | ASSERTED |
| D-IN-04 | mutrig_datapath.lane_in → mts_preprocessor.hit_in | ASSERTED | — | — | — | — |
| D-IN-05 | mts_preprocessor.hit_out | — | — | ASSERTED | — | — |

Column `drop_on_overflow` — the decoded_lane_fifo is 128-deep and
configured to drop on overflow rather than backpressure. The
property is `overflow event → (one-or-more whole frames dropped)`;
no half-frame is allowed to leak.

Column `k_word_ok` — every hit_type3 (36-bit DP) frame must begin
with K28.5, end with K28.4, and separators are K28.7. The RX must
reject any frame where a K-symbol appears outside these three
positions.

#### 7.3.2 DP mux and stack boundaries

| # | Boundary | rr_fairness | grant_lock | preamble_align | frame_contiguous | tail_truncate |
|---|----------|-------------|------------|----------------|------------------|---------------|
| D-MUX-01 | 4:1 round-robin mux at hit_stack | ASSERTED | ASSERTED | — | ASSERTED | — |
| D-STK-01 | hit_stack_subsystem.frame_in | — | — | ASSERTED | ASSERTED | — |
| D-STK-02 | hit_stack_subsystem.frame_out | — | — | ASSERTED | ASSERTED | ASSERTED |
| D-STK-03 | frame_assembly tile write | — | — | ASSERTED | ASSERTED | ASSERTED |
| D-STK-04 | hist_stat frame-boundary bank switch | — | — | — | ASSERTED | ASSERTED |

Column `grant_lock` — once the RR arbiter grants a source, the grant
must stay locked until the packet's `eop` is accepted; switching
mid-packet would torn-frame the egress.

Column `tail_truncate` — when egress `ready` is deasserted for more
than $FORMAL_EGRESS_BP_MAX cycles, the frame_assembly must either
hold the tail or discard the whole frame; it must not emit a
truncated frame.

#### 7.3.3 DP CSR-during-traffic boundaries

| # | CSR | read_during_frame | write_during_frame | reset_during_frame | param_change_effect |
|---|-----|-------------------|---------------------|---------------------|---------------------|
| D-CSR-01 | mutrig_cfg_ctrl channel_mask | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| D-CSR-02 | mutrig_cfg_ctrl threshold | ASSERTED | ASSERTED | ASSERTED | COVERED |
| D-CSR-03 | hist_stat enable | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| D-CSR-04 | hist_stat bank_swap | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| D-CSR-05 | mts_preprocessor mode | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| D-CSR-06 | charge_inj_pulser fire_pulse | ASSERTED | ASSERTED | ASSERTED | COVERED |

Column `param_change_effect` — changing a CSR mid-frame must only
take effect at the next frame boundary, never mid-frame. This is
the "seam consistency invariant" (§0a) applied to the SC→DP seam
at the individual register level.

#### 7.3.4 DP frame-grammar boundaries

| # | Grammar | opening_word | closing_word | payload_word_count | separator_word | bad_word |
|---|---------|--------------|--------------|--------------------|----------------|----------|
| D-GR-01 | hit_type0 (raw 45-bit) | ASSUMED | ASSUMED | ASSUMED | — | ASSUMED |
| D-GR-02 | hit_type1 (TCC_8n) | ASSERTED | ASSERTED | ASSERTED | — | ASSERTED |
| D-GR-03 | hit_type1 (TCC_1n6) | ASSERTED | ASSERTED | ASSERTED | — | ASSERTED |
| D-GR-04 | hit_type1 (ET_1n6) | ASSERTED | ASSERTED | ASSERTED | — | ASSERTED |
| D-GR-05 | hit_type3 frame | ASSERTED | ASSERTED | ASSERTED | ASSERTED | ASSERTED |
| D-GR-06 | histogram frame | ASSERTED | ASSERTED | ASSERTED | — | ASSERTED |

`opening_word` / `closing_word` / `separator_word` columns enforce
the K-symbol grammar of hit_type3 specifically.

`payload_word_count` enforces the per-grammar length invariant:
- hit_type0: 1 beat/hit, 45 bits wide
- hit_type1 TCC_8n: 2 beats/hit
- hit_type1 TCC_1n6: 2 beats/hit with higher-resolution timestamp
- hit_type1 ET_1n6: 2 beats/hit with energy-time packing
- hit_type3: variable (header + 0..N hits + trailer, trailer
  required even for zero-hit frame)
- histogram: fixed by `NBINS` generic.

### 7.4 Cross-plane seam matrix

| # | Seam | ordering_preserved | credit_return | drain_on_stop | run_state_gated | deadlock_free |
|---|------|--------------------|---------------|----------------|------------------|----------------|
| CX-01 | RC(run_state) → DP(enable_data) | ASSERTED | — | ASSERTED | ASSERTED | ASSERTED |
| CX-02 | SC(CSR write) → DP(param) | ASSERTED | — | — | ASSERTED | ASSERTED |
| CX-03 | RC(ACK) → upload_pkt_mux.in2 | ASSERTED | — | — | ASSERTED | ASSERTED |
| CX-04 | SC(response) → upload_pkt_mux.in1 | ASSERTED | — | — | ASSERTED | ASSERTED |
| CX-05 | DP(frame) → upload_pkt_mux.in0 | ASSERTED | — | — | ASSERTED | ASSERTED |
| CX-06 | upload_pkt_mux 3-way RR | ASSERTED | — | — | — | ASSERTED |
| CX-07 | mm_bridge SC↔DP clock-crossing | ASSERTED | — | — | — | ASSERTED |
| CX-08 | sc_hub.soft_reset → all slaves | ASSERTED | — | ASSERTED | — | ASSERTED |

`credit_return` column is left as `—` because FEB SciFi v3 does not
use credit-based flow control on any plane — backpressure is
propagated via AVST `ready`, and CDC is handled by tagged-payload
shadow or gray-coded FIFO pointers. A future design with credit
return would need to fill this column.

### 7.5 CDC plane boundary matrix

| # | Seam | source_clk | dest_clk | synchroniser | latency | data_integrity | reset_safety |
|---|------|------------|----------|--------------|---------|----------------|--------------|
| CDC-01 | lvdspll_clk ↔ cclk156 (runctl_mgmt) | lvdspll_clk (125 MHz) | cclk156 (156.25 MHz) | 2FF (CDC_GEN) | ≤ $FORMAL_CDC_LAT_MAX | ASSERTED | ASSERTED |
| CDC-02 | cclk156 ↔ mclk125 (upload_cdc_fifo) | cclk156 | mclk125 | gray pointer | ≤ $FORMAL_CDC_FIFO_LAT_MAX | ASSERTED | ASSERTED |
| CDC-03 | upper frame CDC (DP→cclk156) | mclk125 | cclk156 | gray pointer | ≤ $FORMAL_CDC_FIFO_LAT_MAX | ASSERTED | ASSERTED |
| CDC-04 | mm_bridge SC↔DP | cclk156 | mclk125 | vendor handshake | ≤ $FORMAL_MM_BRIDGE_LAT_MAX | ASSERTED | ASSERTED |
| CDC-05 | LVDS recovered → mclk125 (lvds_rx) | lvds_rx_clk | mclk125 | elastic buffer | ≤ $FORMAL_LVDS_LAT_MAX | ASSERTED | ASSERTED |
| CDC-06 | reset release ordering | n/a | n/a | staged FSM | ≤ $FORMAL_RESET_ORDER_MAX | ASSERTED | ASSERTED |

Latency column: each seam's end-to-end latency is bounded by a
formal parameter and a `within` bound on the relevant property.
A property without a latency bound would be vacuously true (0..∞)
under bounded-model checking; naming the bound makes the proof
meaningful.

`data_integrity` column collapses the five sub-invariants of every
CDC seam:
- no data change during transfer
- tagged-payload shadow match (where applicable)
- sink reads only one side of the synchroniser at a time
- no combinational path crosses the clock domain
- fair ordering across the synchroniser (no message-reorder)

### 7.6 Total boundary count

Count of boundary-rows in this matrix (= the work unit for the
formal environment):

| Plane | Boundary positions | Condition columns | Total cells |
|-------|-------------------:|------------------:|------------:|
| RC AVST | 6 | 6 | 36 |
| RC run-state | 5 | 5 | 25 |
| RC FSM | 6 | 5 | 30 |
| SC AVST (download) | 4 | 6 | 24 |
| SC AVMM (per-slave × 8) | 12 × 8 | 1 per slave | 96 |
| SC response | 4 | 5 | 20 |
| SC decode (per-slave × 8) | 4 × 8 | 1 per slave | 32 |
| DP ingress | 5 | 5 | 25 |
| DP mux/stack | 5 | 5 | 25 |
| DP CSR-during-traffic | 6 | 4 | 24 |
| DP frame-grammar | 6 | 5 | 30 |
| Cross-plane seams | 8 | 5 | 40 |
| CDC seams | 6 | 6 | 36 |
| **Total rows × cols** | **85** | — | **443** |

This matches the §0a target of at least 5× OPQ complexity (OPQ's
matrix is ~90 cells; 443/90 ≈ 4.9×) and puts one SVA property (or
one structured `cover`) behind each cell.

### 7.7 Boundary sanity checks (seam-consistency invariants)

On top of the per-cell properties there is a second layer of
invariants — the "seam consistency" invariants introduced in §0a.
Unlike per-cell properties, seam invariants act across cells and
across planes.

| # | Invariant | Planes touched | Property form |
|---|-----------|----------------|---------------|
| INV-01 | No torn upload frame | RC, SC, DP + mux | `ast_upload_no_tear` |
| INV-02 | Every command gets exactly one response | SC | `ast_sc_cmd_unique_resp` |
| INV-03 | Every CMD_RUN_PREP gets exactly one ACK | RC | `ast_rc_runprep_ack_unique` |
| INV-04 | Every hit_type3 frame has matching open/close K | DP | `ast_ht3_frame_well_formed` |
| INV-05 | Run-state changes propagate to all 16 RC sinks in ≤ N | RC | `ast_rc_fanout_bounded` |
| INV-06 | `soft_reset` reaches all 8 SC slaves in ≤ N | SC | `ast_sc_reset_fanout` |
| INV-07 | No back-pressure-induced deadlock upstream of any seam | RC, SC, DP, mux | `ast_no_deadlock_*` |
| INV-08 | DP frames only emitted when run_state in { RUN, PREPARED_RUN } | RC → DP | `ast_dp_emit_gated_by_rs` |
| INV-09 | SC CSR writes take effect at frame boundary only | SC → DP | `ast_csr_seam_consistent` |
| INV-10 | upload_pkt_mux preserves intra-source order | RC, SC, DP → mux | `ast_mux_order_preserved` |
| INV-11 | No data corruption across any CDC seam | CDC | `ast_cdc_data_integrity` |
| INV-12 | Reset release order always external → mm_bridge → slaves | CDC, SC, DP | `ast_x6_ext_resets_before_local` |

Each INV-* invariant composes multiple per-cell properties and
declares the single end-to-end property that matters to system
sign-off. If every INV-* holds, the system is formally sound
regardless of which per-cell property is responsible.

---

## §8 — Tool and flow plan

This section records how we intend to realise the property set from
§2–§7 in a concrete formal environment. OPQ's formal plan is single
IP + single file-bind; the integration plan is multi-bind, multi-tool,
multi-domain, and the bind structure itself is a design artefact.

The principle: every plane gets its own bind file and its own formal
script, so that a proof failure in one plane does not starve the
tool's runtime on another plane. The binds are stitched together in a
single top-level wrapper only for the cross-plane invariants (§5 /
§7.4).

### 8.1 Tool matrix

| Proof bucket | Primary tool | Secondary tool | Reason |
|--------------|--------------|----------------|--------|
| RC AVST / FSM | Cadence JasperGold (FPV App) | Questa Formal | Packet grammar (Doug Smith method) maps cleanly onto JasperGold's `assume_guarantee` — same as OPQ |
| SC AVMM | Cadence JasperGold (FPV App + ABV) | OneSpin Quantify MV | AVMM is a standardised assertion library in Jasper; OneSpin's native SVA cross-check catches tool-dependent lemma bugs |
| DP data-path | Cadence JasperGold (Coverage Unreachability App) | — | Structural coverage signoff is essential for DP and JG has the best dead-code analysis |
| CDC | Synopsys VC Formal CDC / JasperGold CDC | Questa CDC | Vendor CDC apps are built for exactly this problem; hand-written SVA used only for invariants the app cannot express |
| Reset-ordering | Cadence JasperGold (FPV App) | Questa Formal | Straight SVA |
| Cross-plane | Cadence JasperGold (FPV App) + `proof_partition` | — | Long-range invariants use Jasper's proof partitioning to reduce BMC depth |

The environment supports a single source of truth (SVA + bind files)
consumable by multiple tools. All tool-specific tcl lives under a
per-tool subdirectory; the SVA code itself carries no vendor pragmas
other than `// synopsys translate_off` on coverage macros.

### 8.2 Bind structure

The formal environment uses SystemVerilog `bind` to inject the
properties into the target module without modifying the RTL. Bind
files are grouped per plane.

```
tb_int/INT_fe_scifi_v3-2026-04-17/formal/
├── common/
│   ├── formal_defs.svh             # $FORMAL_* parameters, types
│   ├── formal_pkg.sv               # packed grammar types, helpers
│   ├── formal_avst_if.sv           # AVST interface + properties
│   ├── formal_avmm_if.sv           # AVMM interface + properties
│   └── formal_cdc_if.sv            # CDC pair interface + properties
├── rc/
│   ├── bind_run_control_command_receiver.sv
│   ├── bind_ack_packet_generator.sv
│   ├── bind_run_control_splitter.sv
│   ├── bind_upload_cdc_fifo.sv
│   ├── bind_upload_pkt_mux.sv
│   ├── props_rc_avst.sv
│   ├── props_rc_fsm.sv
│   ├── props_rc_runstate.sv
│   └── jg_rc.tcl
├── sc/
│   ├── bind_sc_hub_top.sv
│   ├── bind_scratch_pad_ram.sv
│   ├── bind_onewire_master_controller.sv
│   ├── bind_max10_prog_avmm.sv
│   ├── bind_charge_injection_pulser.sv
│   ├── bind_firefly_xcvr_ctrl.sv
│   ├── bind_on_die_temp_sense_ctrl.sv
│   ├── bind_mm_bridge.sv
│   ├── bind_mutrig_cfg_ctrl.sv
│   ├── props_sc_avmm_generic.sv
│   ├── props_sc_decode.sv
│   ├── props_sc_response.sv
│   └── jg_sc.tcl
├── dp/
│   ├── bind_emulator_mutrig.sv
│   ├── bind_lvds_rx_wrapper.sv
│   ├── bind_decoded_lane_fifo.sv
│   ├── bind_mutrig_datapath_subsystem.sv
│   ├── bind_mts_preprocessor.sv
│   ├── bind_hit_stack_subsystem.sv
│   ├── bind_histogram_statistics.sv
│   ├── bind_mutrig_injector.sv
│   ├── props_dp_ingress.sv
│   ├── props_dp_grammars.sv
│   ├── props_dp_mux.sv
│   ├── props_dp_csr_seam.sv
│   └── jg_dp.tcl
├── cdc/
│   ├── bind_cdc_all.sv
│   ├── props_cdc_2ff.sv
│   ├── props_cdc_graycount.sv
│   ├── props_cdc_tagged_shadow.sv
│   ├── props_reset_ordering.sv
│   └── vc_cdc.tcl
├── cross/
│   ├── bind_cross_plane.sv
│   ├── props_cross_c1_rsync.sv
│   ├── props_cross_c2_csr.sv
│   ├── props_cross_c3_ack.sv
│   ├── props_cross_c4_resp.sv
│   ├── props_cross_c5_contention.sv
│   ├── props_inv_01_no_tear.sv ... props_inv_12_reset_order.sv
│   └── jg_cross.tcl
└── top/
    ├── formal_top.sv               # instantiates all bind groups
    ├── formal_clocks_resets.sv     # clock/reset stimulus gen
    └── run_all.tcl                 # orchestrates per-plane tcl
```

Each bind file instantiates the corresponding `props_*` module and
wires it to the DUT instance via hierarchical reference. No RTL edit
is required. The top-level `formal_top.sv` wires up the cross-plane
props only — the per-plane props run in isolation first, and once
individually clean they are re-run under the top for the INV-*
invariants.

### 8.3 Formal defines (`formal_defs.svh`)

```systemverilog
// Per-plane bounds (BMC-unfriendly values get clamped by the
// tool-specific tcl via `override_parameter`)

`define FORMAL_BP_HOLD_MAX           32
`define FORMAL_RS_FANOUT_MAX         16
`define FORMAL_SC_RESP_LAT_MAX       64
`define FORMAL_SC_BURST_MAX           8
`define FORMAL_DP_EGRESS_BP_MAX      64
`define FORMAL_CDC_LAT_MAX            6
`define FORMAL_CDC_FIFO_LAT_MAX      32
`define FORMAL_MM_BRIDGE_LAT_MAX     16
`define FORMAL_LVDS_LAT_MAX          12
`define FORMAL_RESET_ORDER_MAX      256
`define FORMAL_UPLOAD_MUX_GRANT_MAX 512
`define FORMAL_SOFT_RESET_PROP_MAX   32

// Abstraction knobs
`define FORMAL_N_HITS_PER_FRAME_MAX   8    // cap hit-stack frame size
`define FORMAL_N_RS_SINKS            16    // RC fanout arity
`define FORMAL_N_SC_SLAVES            8    // SC decode arity
`define FORMAL_N_DP_LANES            16    // DP mux arity

// Opt-out flags — set to 1 to skip known-hard proofs
`define FORMAL_SKIP_X3                0    // upper frame CDC
`define FORMAL_SKIP_CX_05             0    // 3-way contention
```

These are `ifdef`-able from the tcl so that a CI "smoke" run can
lower the bounds (fast convergence) while the sign-off run uses
production values.

### 8.4 Packed grammar types (`formal_pkg.sv`)

The Doug Smith method depends on declaring the packet structure as a
`typedef struct packed`. For the integration environment we need
four packed families — RC synclink, SC K-flag download, DP hit_type3,
and the upload envelope.

```systemverilog
package formal_pkg;

// -- RC synclink 9-bit beat -------------------------
typedef struct packed {
    logic       k_flag;              // MSB = K-symbol marker
    logic [7:0] byte_data;
} synclink_beat_t;

typedef enum logic [7:0] {
    CMD_NOP          = 8'h00,
    CMD_IDLE         = 8'h20,
    CMD_PING         = 8'h30,
    CMD_REQ_SYS_INFO = 8'h40,
    CMD_PREP         = 8'h54,   // RUN_PREP
    CMD_SYNC         = 8'h58,
    CMD_START        = 8'h5C,
    CMD_END          = 8'h60,
    CMD_ABORT        = 8'h64,
    CMD_LOG          = 8'h70,
    CMD_RESET        = 8'h80
} rc_cmd_t;

// -- SC K-flag 36-bit download beat ------------------
typedef struct packed {
    logic [3:0] kflag;               // per-byte K-symbol marker
    logic [31:0] data;
} sc_dl_beat_t;

// -- DP hit_type3 36-bit beat ------------------------
typedef struct packed {
    logic [3:0] kflag;
    logic [31:0] data;
} dp_hit3_beat_t;

typedef struct packed {
    // header opening word
    logic [7:0] k_open;              // must be K28.5
    logic [23:0] frame_info;
} ht3_open_t;

typedef struct packed {
    logic [7:0] k_close;             // must be K28.4
    logic [23:0] frame_tail;
} ht3_close_t;

// -- Upload envelope (36-bit) ------------------------
typedef struct packed {
    logic [1:0] src_tag;             // 0=DP, 1=SC resp, 2=RC ack
    logic [33:0] inner;
} upload_beat_t;

// -- Frame info (per the n-metadata trick) -----------
typedef enum logic [1:0] {
    FK_SYNC, FK_ACK, FK_RESP, FK_HIT3
} frame_kind_t;

typedef struct packed {
    frame_kind_t kind;
    logic [15:0] length;
    logic [15:0] total_length;
    logic        pkt_good;
} frame_info_t;

endpackage
```

The `packet_info[n].kind / length / total_length / pkt_good` pattern
mirrors OPQ's formal package exactly — this is the key Doug Smith
idiom. `pkt_good` is the switch that flips the property between
"this frame must be well-formed" and "this frame is a torn/malformed
frame and must be dropped".

### 8.5 Per-plane formal scripts

Each `jg_<plane>.tcl` script follows the same outline:

```tcl
# Example: jg_rc.tcl

analyze -sv \
    -F filelist_rc.f \
    -f formal/common/formal_defs.svh \
    -f formal/common/formal_pkg.sv \
    -f formal/common/formal_avst_if.sv \
    -f formal/rc/props_rc_avst.sv \
    -f formal/rc/props_rc_fsm.sv \
    -f formal/rc/props_rc_runstate.sv \
    -f formal/rc/bind_run_control_command_receiver.sv \
    -f formal/rc/bind_ack_packet_generator.sv \
    -f formal/rc/bind_run_control_splitter.sv

elaborate -top formal_top_rc

clock -both_edges cclk156
reset { !cclk156_reset_n , !mclk125_reset_n }
abstract -clock_gating_off

set_engine_mode { Ht B K I N }

# Per-bucket proof calls
prove -property { rc.ast_* } -bg
prove -property { rc.cov_* } -bg
```

An independent per-plane run gives a clean P/F column for each
bucket. The top-level aggregator only needs to run the cross-plane
invariants after the per-plane runs close.

### 8.6 CDC-tool flow (`vc_cdc.tcl`)

VC Formal CDC is the primary tool for the CDC plane because it knows
about gray-counter pointers, 2FF receivers, and tagged-payload
shadows out of the box. We still add hand-written SVA (X1..X6) for
the cases that require semantic knowledge the tool cannot infer:

```tcl
# Example: vc_cdc.tcl

create_cdc_project feb_int_cdc
set_cdc_option -clock_pair { lvdspll_clk cclk156 }
set_cdc_option -clock_pair { cclk156 mclk125 }
set_cdc_option -clock_pair { lvds_rx_clk mclk125 }

analyze -sv -f filelist_full.f
elaborate -top feb_system_v3

run_cdc
report_cdc -violations
run_cdc_interactive

# Hand-written SVA supplements the tool's built-in rules
load_properties -f formal/cdc/props_cdc_*.sv
prove -property { cdc_root.ast_* }
```

### 8.7 Cross-plane orchestration (`run_all.tcl`)

```tcl
# run_all.tcl — sign-off orchestrator

set plane_list { rc sc dp cdc cross }
set phase { sanity signoff }

foreach plane $plane_list {
    foreach p $phase {
        if {$p eq "sanity"} {
            override_parameter FORMAL_BP_HOLD_MAX 4
            override_parameter FORMAL_RS_FANOUT_MAX 4
        }
        source formal/${plane}/jg_${plane}.tcl
        report -property -csv -file results_${plane}_${p}.csv
    }
}

# Final sign-off
report -summary -csv -file signoff_matrix.csv
```

### 8.8 Coverage plan

Each formal bucket closes its coverage via three layers:

1. **SVA `cover` properties** — one per INV-* and one per edge
   condition that must be reachable (a "witness" trace). Reported
   in `cov_*` style alongside `ast_*`.

2. **Jasper Coverage Unreachability App** on the DUT hierarchy
   rooted at the plane's top bind point. A line, branch, or
   statement shown unreachable must have a corresponding
   waiver (labelled `UNR-*`) or be deleted.

3. **Cross-plane coverage** — a special bucket of `cover` properties
   that exercises multi-plane sequences (e.g. "SC write during DP
   frame during RC pause during CDC gray-count wrap"). These are
   the integration-specific witnesses that a single-plane formal
   cannot produce.

Coverage goals per plane:

| Plane | Stmt | Branch | FSM state | FSM trans | Toggle | Covergroup-equiv |
|-------|------|--------|-----------|-----------|--------|------------------|
| RC    | 95   | 90     | 100       | 95        | 85     | all cov_r*       |
| SC    | 90   | 85     | 100       | 90        | 80     | all cov_s*       |
| DP    | 88   | 82     | 95        | 85        | 75     | all cov_d*       |
| CDC   | —    | —      | —         | —         | —      | all cov_x*       |
| Cross | —    | —      | —         | —         | —      | all cov_inv_*    |

DP coverage targets are lower because `mts_preprocessor` has many
mode-dependent arcs that are `UNR` in a specific mode — only the
cross-mode aggregate can reach 100%. The signoff protocol is to
sum the per-mode coverage and require ≥ 90% aggregate, tracked in
§10.

### 8.9 Runtime and proof-budget plan

The formal plan is ambitious and some properties will not close at
full depth. The plan:

| Property class | Tool | Target depth | Budget | Fallback |
|----------------|------|--------------|--------|----------|
| RC AVST (R1..R7) | JG FPV | unbounded | 2h wall | Abstract to 4-way splitter; prove symmetric |
| RC FSM | JG FPV | unbounded | 1h wall | n/a (FSM small) |
| SC AVMM (per-slave) | JG ABV | unbounded | 1h/slave | Reduce BURST_MAX to 2 |
| SC download K-flag | JG FPV | unbounded | 1h | Abstract payload to 1 beat |
| DP frame-grammar | JG FPV | unbounded | 2h | Cap N_HITS_PER_FRAME to 4 |
| DP ingress CRC | JG FPV | unbounded | 30m | Abstract CRC generator |
| DP mux/stack | JG FPV | bounded 500 | 2h | Bounded proof only; cover 500+ traces by sim |
| Histogram | JG FPV | unbounded | 30m | n/a |
| CDC all | VC CDC | n/a | 4h | Run tool-only; SVA as additional |
| Reset ordering | JG FPV | bounded 256 | 1h | n/a |
| Cross-plane INV-* | JG FPV + partition | bounded 1024 | 8h | Partition + cover-only for depth > 1024 |

Total budget: ~25h wall on a 64-core formal box. If the sign-off
run does not converge within this budget, the planeʼs result is
reported as "bounded N" and the remaining depth is declared a
non-claim in §10.

### 8.10 CI integration

For pre-merge CI we run a fast ("sanity") configuration:

- `FORMAL_BP_HOLD_MAX = 4`
- `FORMAL_SC_BURST_MAX = 2`
- `FORMAL_N_HITS_PER_FRAME_MAX = 2`
- all `unbounded` targets clamped to bounded-16
- only a curated subset of properties (the INV-* plus the 12 most
  common tornframe catches)

Target CI wall time: ≤ 20 minutes. Sign-off run is the nightly job.

### 8.11 Gate-level sanity (belt and braces)

Because the staged-reset trick (see user CLAUDE.md) involves
multi-cycle clears, and because the tool's `set_false_path` on the
reset-arc is only honoured during P&R and not during the formal BMC,
we require a gate-level sanity pass on every CDC property:

- Post-synthesis netlist imported into Jasper
- Same `props_cdc_*` SVA bound to the netlist hierarchy
- Proof re-run at bounded depth 64

This is cheap (the netlist has no behavioural ambiguity) and catches
the case where synthesis replaces the recommended staged-reset FSM
with a combinational clear cone, which `set_false_path` would mask
but which formal would still catch because the SVA runs on the
actual netlist.

---

## §9 — Trace to existing sim cases

OPQ's DV_FORMAL.md ends with a matrix that relates formal properties
to the existing directed / UVM cases, so that closure of the formal
plan implies closure (by subsumption) of the sim plan. This section
does the same for the integration environment.

The sim cases are recorded in `cases/rc.md`, `cases/sc.md`,
`cases/dp.md`, plus the expansion buckets in each file for future
UVM. The trace maps each sim case (implemented or future) to one or
more formal properties from §2–§7 and to one or more INV-* from
§7.7.

### 9.1 RC sim-case trace

#### 9.1.1 Currently implemented RC cases

| Sim case (cases/rc.md) | Boundary row | Properties | INV |
|------------------------|---------------|------------|-----|
| Management-side RC word injection into `runctl_mgmt_host_*` | R-AVST-01 | `ast_synclink_avst_grammar`, `ast_rc_cmd_decode_onehot` | INV-03, INV-05 |
| One RC word reaches all 16 datapath consumers | R-RS-02, R-RS-03 | `ast_splitter_fanout_completeness`, `ast_all_consumers_agree` | INV-05 |
| One upper-path FEB frame injected at frame-assembly seam | D-STK-03 | `ast_ht3_frame_well_formed`, `ast_framer_tile_write_contiguous` | INV-04 |
| One lower-path FEB frame injected at frame-assembly seam | D-STK-03 | `ast_ht3_frame_well_formed` (mirror for lower lane) | INV-04 |
| Upper and lower uploads emerge on distinct SWB links | R-AVST-04, D-MUX-01 | `ast_rr_no_starvation`, `ast_mux_order_preserved` | INV-10 |

Sign-off reading: every RC sim case listed today is already covered
by a formal property. Running only the formal set would be strictly
stronger than running the current RC sim cases; the sim cases remain
in place because they validate the integration wiring itself (the
bind files), not the property set.

#### 9.1.2 Future RC cases (expansion buckets)

| Future bucket | Boundary row | Properties | INV |
|---------------|---------------|------------|-----|
| RC state-transition sweep across all legal run-control words | R-FSM-01..R-FSM-04 | `ast_recv_fsm_covers_all_cmds`, `cov_rc_cmd_each` | INV-03 |
| Repeated RC toggling while datapath traffic is active | CX-01 | `ast_run_state_no_tear_dp`, `ast_dp_emit_gated_by_rs` | INV-08 |
| Partial-ready / backpressured splitter-consumer masks | R-RS-02 | `ast_splitter_handles_one_slow_sink` | INV-05 |
| RC delivery during simultaneous SC and datapath activity | CX-01..CX-05 | `ast_three_way_no_deadlock` | INV-07, INV-10 |
| RC burst tolerance / spacing sensitivity on management ingress | R-AVST-01 | `ast_rc_burst_tolerance` (COVER) | INV-03 |

"Future RC cases" are already specified by the formal matrix. When
the UVM team writes them, the scoreboard is the SVA set; the sim
stimulus is the witness generator.

### 9.2 SC sim-case trace

#### 9.2.1 Currently implemented SC cases

| Sim case (cases/sc.md) | Boundary row | Properties | INV |
|------------------------|---------------|------------|-----|
| Single-read smoke sweep across control-path slaves | S-DEC-01, S-AVMM-01 | `ast_sc_waiting_write_space_no_drop` (read form), `ast_sc_slave_decode_onehot` | INV-02 |
| Single-read smoke sweep across datapath slaves | S-DEC-01, S-AVMM-01 | `ast_dp_word_addr_alignment` regression gate | INV-02 |
| Full-aperture burst-vs-single compare matrix | S-AVMM-09, S-AVMM-10 | `ast_burst_equals_N_singles`, `ast_burst_byteenable_monotonic` | INV-02 |
| Boundary-tail characterization | S-DEC-02, S-DEC-03 | `ast_cross_slave_collision_none` (COVER), `ast_decode_hole_cover` | INV-02 |
| Deterministic random in-aperture burst windows | S-AVMM-09 | `ast_burst_max_lat_bounded` | INV-02 |
| Cross-boundary behavior characterization | S-DEC-03 | `cov_cross_slave_boundary` | INV-02 |

Note: `test_slowcontrol` is deprecated as of 2026-04-17 (see
CLAUDE.md). Any future SC sim case must use `sc_tool` and must pass
word-addresses on the packet side; the formal environment encodes
this convention as `ast_dp_word_addr_alignment` — running the
formal property against legacy byte-address stimuli would fail,
which is the correct behaviour.

#### 9.2.2 Future SC cases (expansion buckets)

| Future bucket | Boundary row | Properties | INV |
|---------------|---------------|------------|-----|
| Write-path coverage for writable CSRs and memories | S-AVMM-01, S-AVMM-04 | `ast_sc_write_readback_consistent` | INV-02 |
| Illegal / unmapped address behavior | S-AVMM-06 | `ast_sc_unmapped_addr_response` | INV-02 |
| Waitrequest stress and outstanding-request corner cases | S-AVMM-02, S-AVMM-11 | `ast_waitrequest_data_hold`, `ast_response_timeout_bounded` | INV-02 |
| Mixed control-plane and datapath-plane read interleaving | S-AVMM-07, CX-02 | `ast_cp_dp_interleave_ordered` | INV-02, INV-09 |
| Long burst traffic during active datapath generation | CX-02 | `ast_csr_seam_consistent`, `ast_dp_no_tear_during_sc_burst` | INV-09 |
| Explicit external-SC coverage for v3 emulator CSR bank | S-AVMM-01 (mutrig_cfg) | `ast_mutrig_cfg_avmm_csr_conformance` | INV-02 |
| Scoreboard classification for live CSR divergence | S-RESP-02 | `cov_sc_live_csr_divergence` | INV-02 |

### 9.3 DP sim-case trace

#### 9.3.1 Currently implemented DP cases

| Sim case (cases/dp.md) | Boundary row | Properties | INV |
|------------------------|---------------|------------|-----|
| Embedded emulator programming through local datapath seam | D-CSR-02 | `ast_mutrig_cfg_programming_order` | INV-09 |
| Run-state enable into the live datapath | CX-01 | `ast_dp_emit_gated_by_rs` | INV-08 |
| Observation of external emulator words | D-IN-01, D-IN-02 | `ast_lvds_rx_frame_aligned`, `ast_dp_k_word_ok` | INV-04 |
| Observation of MuTRiG hit_type0 traffic | D-IN-04 | `ast_ht0_frame_well_formed` | INV-04 |
| Observation of MTS hit_type1 traffic | D-IN-05 | `ast_mts_mode_consistent`, `ast_ht1_variant_well_formed` | INV-04 |
| Observation of hit-stack ingress acceptance | D-STK-01 | `ast_hit_stack_ingress_accepts_legal` | INV-04 |
| Histogram configuration/readback and multi-bin accumulation | D-CSR-03, D-CSR-04 | `ast_hist_bank_switch_atomic`, `ast_hist_accum_no_skip` | INV-09 |

#### 9.3.2 Future DP cases (expansion buckets)

| Future bucket | Boundary row | Properties | INV |
|---------------|---------------|------------|-----|
| Per-lane arbitration between real LVDS and emulator sources | D-MUX-01 | `ast_rr_no_starvation`, `ast_rr_grant_lock` | INV-10 |
| RR mux fairness and starvation checks | D-MUX-01 | `ast_rr_fairness_bounded` | INV-10 |
| Shallow FIFO overflow / drop characterization | D-IN-03 | `ast_decoded_lane_fifo_drops_whole_frames` | INV-04 |
| Run-control start/stop transitions during active traffic | CX-01 | `ast_start_stop_no_tear` | INV-01, INV-08 |
| Per-lane disable / sparse-lane stimulus matrices | D-IN-01 (per-channel) | `ast_sparse_lane_still_ordered` | INV-10 |
| Histogram rollover, clear, and interval corner cases | D-CSR-04 | `ast_hist_rollover_atomic`, `ast_hist_interval_covers_bank_swap` | INV-09 |
| Upload-path correlation between DP production and FEB output framing | CX-05 | `ast_upload_dp_passthrough_ordered` | INV-10 |

### 9.4 Cross-plane sim-case trace (implicit)

The sim case inventory does not today contain a dedicated cross-
plane bucket — cross-plane cases are distributed across all three
domain files. The formal matrix explicitly collects them under CX-*
and INV-*. A future UVM reorganisation may promote
`cases/cross.md`; the formal properties it needs already exist.

### 9.5 Dropped sim cases (subsumption notes)

Some previously documented sim cases are strictly subsumed by the
formal plan and can be dropped from the active UVM backlog. Drops
require sign-off per the non-claims list in §10.

| Dropped case | Subsumed by | Why |
|--------------|-------------|-----|
| "Inject 1000 random RC words and check they reach consumers" | `ast_splitter_fanout_completeness` | Formal proves the property for *all* RC words, not a sampled 1000 |
| "Sweep all 8 SC slaves with a single read each" | S-DEC-01 row + `ast_sc_slave_decode_onehot` | Formal covers the decode completeness |
| "Observe one upper-path frame" | D-STK-03 row + `ast_ht3_frame_well_formed` | Formal proves all possible frames are well-formed |

Not all sim cases are subsumed. The sim cases that must stay are
those that exercise the bind wiring itself (i.e. confirm the formal
environment was pointed at the right RTL) and the ones that touch
features the formal environment abstracts away (e.g. real LVDS
electrical behaviour, Quartus-specific synthesis options).

### 9.6 Trace to OPQ regressions (packet_scheduler)

Two of the packet_scheduler regressions listed in
`packet_scheduler/tb/DV_REPORT.md` overlap with integration-level
behaviour. The integration formal matrix extends them:

| OPQ case | OPQ formal property | Integration extension |
|----------|---------------------|------------------------|
| `opq_error_ftable_overflow_test` (probe-only) | OPQ-FTO | Integration analogue is D-STK-03 tile-write-contiguous — not in OPQ because OPQ's frame table is a subset |
| `opq_error_header_mask_recovery_test` | OPQ-HMR | Integration analogue is `ast_upload_no_tear` (INV-01) |
| `opq_error_header_word_mask_recovery_test` | OPQ-HWMR | Integration analogue is INV-04 + INV-10 |
| `opq_cross_drr_bursty_random_test` | OPQ-CDB | No direct integration analogue; OPQ's DRR isn't replicated at the integration seam |

These mappings are informational only — the integration formal plan
does not retire OPQ's DV_REPORT.md entries. Each IP keeps its own
sign-off.

### 9.7 Trace to historical bugs (BUG_HISTORY.md)

The `BUG_HISTORY.md` of the integration sim records real bugs that
have already bitten the system. Each entry must be traceable to at
least one formal property (otherwise the bug would escape). Where no
traceable property exists, a gap is recorded as a **formal-plan
open item** in §10.

| BUG_HISTORY entry (summary) | Property catching it | Status |
|------------------------------|----------------------|--------|
| Staged-reset cone dominated timing (pre-fix) | `ast_x6_ext_resets_before_local` | COVERED |
| sc_hub v2 byte vs word address confusion | `ast_dp_word_addr_alignment` | COVERED |
| upload_pkt_mux grant leak on mid-packet ready drop | `ast_upload_no_tear` (INV-01) + `ast_rr_grant_lock` | COVERED |
| Sparse-frame cadence bug (4-lane OPQ) | Out of integration scope (per-IP) | N/A |
| SWB flashing with wrong firmware SOF (BAR garbage) | Out of RTL scope (board flashing procedure) | N/A |

Any new entry added to `BUG_HISTORY.md` must be checked against the
trace table. If no property catches it, either a new property goes
into the matrix or the gap is explicitly non-claimed.

### 9.8 Regression handoff to DV_REPORT.md

Once the formal environment is up and running, per-plane sign-off
results are written back to the same `DV_REPORT.json` source-of-
truth that `packet_scheduler/tb/scripts/dv_report_gen_local.py`
consumes, extended with:

```json
{
  "planes": {
    "rc":    { "proven": N, "bounded": M, "covered": K, "failed": 0 },
    "sc":    { ... },
    "dp":    { ... },
    "cdc":   { ... },
    "cross": { ... }
  },
  "inv_matrix": [
    { "id": "INV-01", "status": "proven", "depth": "unbounded", ... },
    ...
  ]
}
```

The dashboard template in `REPORT/README.md` is extended with a
"Formal" column and a "Formal depth" column per plane.

---

## §10 — Open items and signoff scope

This section is the counterpart of OPQ's "Non-Claims" block. An
integration-level formal plan has significantly more non-claims than
a single-IP formal plan because several seams still sit at
implementation-TBD. The list below is the explicit contract between
this document and a future signoff review.

### 10.1 In-scope (claims)

The following properties, if proven at the declared depth, are
considered sufficient for integration-level formal signoff of
FEB SciFi v3 at tag `INT_fe_scifi_v3-2026-04-17`:

#### 10.1.1 RC plane claims

- R-AVST-01..R-AVST-06 — AVST grammar at every listed boundary
- R-RS-01..R-RS-05 — run-state propagation within $FORMAL_RS_FANOUT_MAX
- R-FSM-01..R-FSM-06 — RECV + ACK FSM soundness
- `ast_splitter_fanout_completeness` — 16-way fanout correctness
- `ast_all_consumers_agree` — no split-horizon run-state observed
- `ast_runprep_ack_unique` (INV-03) — exactly one ACK per CMD_RUN_PREP

#### 10.1.2 SC plane claims

- S-AVST-01..S-AVST-04 — K-flag download grammar
- S-AVMM-01..S-AVMM-12 — AVMM conformance across all 8 slaves
- S-RESP-01..S-RESP-04 — response ordering and completeness
- S-DEC-01..S-DEC-02 — address alignment convention (word vs byte)
- `ast_sc_cmd_unique_resp` (INV-02) — exactly one response per command

#### 10.1.3 DP plane claims (native-SV equivalent scope)

- D-IN-01..D-IN-05 — per-channel ingress well-formedness
- D-MUX-01, D-STK-01..D-STK-04 — mux fairness and frame contiguity
- D-CSR-01..D-CSR-06 — CSR-during-traffic with seam consistency
- D-GR-01..D-GR-06 — grammar per frame kind
- `ast_ht3_frame_well_formed` (INV-04) — K-boundary correctness
- `ast_hist_bank_switch_atomic` — histogram atomicity

#### 10.1.4 Cross-plane claims

- CX-01..CX-05 — seam properties for the five major cross-plane arcs
- CX-06 — upload_pkt_mux 3-way RR fairness
- CX-07 — mm_bridge SC↔DP crossing correctness
- CX-08 — soft_reset fanout correctness
- INV-01..INV-12 collectively — the twelve system-level invariants

#### 10.1.5 CDC plane claims

- CDC-01..CDC-06 — per-seam CDC correctness
- X1..X6 (§6) — hand-written SVA supplement to the tool's CDC rules
- `ast_x6_ext_resets_before_local` — reset-release ordering

### 10.2 Non-claims (explicit exclusions)

The following items are *outside* the integration-level formal signoff
scope. A finding in any one of these items does not invalidate the
signoff, but must be tracked separately.

#### 10.2.1 IP-internal non-claims

- **packet_scheduler OPQ sparse-frame cadence (4-lane)** — tracked
  in `packet_scheduler/tb/BUG_HISTORY.md`; remains out of 4-lane
  native-SV signoff until closed. Integration formal does not re-open
  this bucket.
- **OPQ probe-only exclusions** — the four `opq_error_*` / `opq_cross_*`
  cases listed in `DV_REPORT.md` are probe-only at the OPQ level.
  Their integration-level analogues (INV-01, INV-04, INV-10) are
  claims, but the full OPQ-internal proofs are not.
- **MuTRiG ASIC-level behaviour** — the MuTRiG is modelled by
  `emulator_mutrig` in formal; real-silicon electrical behaviour
  (jitter, BER, startup sequence) is out of formal scope and is
  covered by hardware bring-up tests.
- **LVDS PHY analog behaviour** — recovered-clock jitter,
  de-serialization metastability, eye diagram. Formal assumes
  the recovered stream is already aligned and well-formed.

#### 10.2.2 Seam-level non-claims

- **Upper frame CDC (X3)** — the adapter type is TBD from the Qsys
  hierarchy (system_v3 regen may have changed it). The hand-written
  SVA is present, but a JasperGold proof requires first identifying
  the adapter. Until then, X3 is **COVERED only** — a cover
  property witness, not a safety proof.
- **mm_bridge internal FIFO depth** — the mm_bridge vendor module
  has an opaque internal FIFO. The CDC-04 property is proved at
  its ports; the internal FIFO is trusted as a vendor component.
- **SC response reorder window** — if sc_hub future-extends its
  response fabric to multiplex responses, a reorder window appears
  that the current matrix does not bound. Today the design has no
  reorder, so the non-claim is conditional on "future change".
- **emulator_mutrig PRNG symmetry** — the emulator's PRNG seed is
  constrained to a single value; symmetry across all seeds is a
  cover goal, not a safety proof.

#### 10.2.3 Tooling and environment non-claims

- **Questa Formal cross-check** — listed as "secondary tool" in §8.1
  but only JasperGold runs are considered primary for signoff. A
  failure observed only under Questa Formal is investigated but does
  not block sign-off if JG proves the property.
- **Simulation witness environment limits** — the sim-side envs that
  feed witness traces to formal still use portable LCG-based stimulus
  and explicit collectors by design. This is a harness choice for
  reproducibility, not an active QuestaOne tool limitation.
- **Gate-level proof depth** — the gate-level sanity pass (§8.11)
  is bounded at 64 cycles. A bug that only manifests beyond depth 64
  in the post-synthesis netlist is outside sign-off scope.
- **Post-P&R timing** — formal does not verify setup/hold. That is
  STA's domain and is addressed by the standalone-IP syn flow (user
  CLAUDE.md "Standalone IP Rerun After RTL Fix").

#### 10.2.4 Run-time and budget non-claims

- **Bounded-depth properties** — all cross-plane INV-* that partition
  to bounded-1024 are claims only up to depth 1024. Any counter
  example deeper than that depth is not a claim.
- **Cases over budget** — if a per-plane run does not converge in
  the declared hour budget (§8.9), the status is recorded as
  "bounded ≤ N" for whatever depth the tool reached. The full
  depth claim is then dropped.

### 10.3 Open implementation items

Tracked TODOs before the signoff run can be launched:

1. **Bind adapter for upper frame CDC (X3).** Identify the specific
   DC-FIFO IP used at the `_gen` layer in `feb_system_v3/synthesis/
   submodules/` and write `bind_cdc_upper_frame.sv`.
2. **Parameter extraction from Qsys for SC decode map.** Keep the
   `sc_hub` slave-map in sync with the auto-generated `components.ipx`.
   Write `scripts/extract_sc_map.py` that dumps a header consumed by
   `props_sc_decode.sv`.
3. **Charge-injection pulser WO model.** Clarify whether the pulser
   is WO or RW. If RW, extend S-AVMM-05 to non-`—`.
4. **mutrig_cfg_ctrl AVMM conformance profile.** Current rev expects
   a strict AVMM slave; if it uses `burstcount=0` semantics, S-AVMM-02
   needs a variant.
5. **Three-way contention bounded-depth.** CX-05 deadlock-freedom is
   expected to converge at bounded 1024; if not, declare partitioned.
6. **Coverage waiver list.** Maintain a `waivers.yml` that enumerates
   intentionally unreachable FSM arcs (e.g. mode-specific `mts_*`
   branches); the Coverage Unreachability App must be told.
7. **BUG_HISTORY → property trace.** Keep §9.7's table up to date as
   new entries land in `BUG_HISTORY.md`.
8. **Per-seam latency budget.** Validate `FORMAL_*_LAT_MAX` constants
   against the actual Qsys-computed pipeline depths; update as system
   evolves.
9. **`test_slowcontrol` retirement.** Any remaining reference to
   `test_slowcontrol` in the environment should be replaced with
   `sc_tool` (user CLAUDE.md, 2026-04-17).
10. **Staged-reset adoption audit.** For each FSM that owns ≥10
    registers cleared on soft-reset, confirm it has a dedicated
    `CORE_RESETTING` state per the user's durable rule; add SVA
    coverage if not.

### 10.4 Review checklist (for sign-off reviewer)

Before promoting the integration-level formal results to signed off,
the reviewer must confirm each of the following:

```
[ ] All §10.1 claims are either PROVEN or COVERED (no FAIL).
[ ] All §10.2 non-claims are still accurate for the current hierarchy.
[ ] All §10.3 open items are either CLOSED or carried forward with
    an owner and a target date.
[ ] Trace tables in §9.1–§9.7 have no gaps against current
    cases/*.md and BUG_HISTORY.md.
[ ] Boundary matrix §7 has no ASSUMED cell that corresponds to an
    internal (non-boundary) interface. (All internal cells are
    ASSERTED by §0a.)
[ ] Per-plane bind files exist and compile without warnings.
[ ] `run_all.tcl` completes end-to-end on a fresh checkout within
    the declared 25h budget.
[ ] `DV_REPORT.json` has `planes.*.failed == 0` after the run.
[ ] Gate-level sanity (§8.11) re-runs PASS on the netlist output of
    the standalone syn (IP CLAUDE.md rule).
[ ] SWB firmware source-of-truth is documented (user CLAUDE.md —
    online_sc for SWB, online_dpv2 for FEB).
```

### 10.5 Signoff header template

The top of `DV_REPORT.md` for the integration TB is updated to
advertise the formal signoff:

```markdown
# ✅ INT Report — FEB SciFi v3

**DUT:** `feb_system_v3` &nbsp; **Date:** `<YYYY-MM-DD>`
&nbsp; **Tag:** `INT_fe_scifi_v3-2026-04-17`
&nbsp; **Seed:** `1` &nbsp; **Formal:** `JasperGold FPV + VC CDC`

## Health
| status | field | value |
|:---:|---|---|
| ✅ | failed_cases | 0 |
| ✅ | signoff_runs_with_failures | 0 |
| ✅ | formal_plane_failures | 0 |
| ⚠️ | formal_open_items | <N from §10.3> |
```

### 10.6 Document provenance

This DV_FORMAL.md is the Doug Smith packet-formal methodology applied
at integration scope on the FEB SciFi v3 system. The body was
composed by:

1. Parsing the Qsys hierarchy rooted at `feb_system_v3.qsys` into
   three planes (RC, SC, DP) plus a CDC and cross-plane overlay.
2. Delegating each plane to a subagent for boundary discovery.
3. Consolidating the three boundary maps into §2–§4.
4. Adding cross-plane seams (§5) from RC×SC×DP interactions.
5. Adding CDC seams (§6) from the clock-pair list.
6. Expanding the boundary-condition matrix (§7) at 5× OPQ scale.
7. Drawing the tool/flow plan (§8) from the standalone-IP precedent.
8. Tracing (§9) to `cases/*.md` and `BUG_HISTORY.md`.
9. Writing signoff contract (§10) as a claims/non-claims split.

The document is maintained alongside `DV_INT_PLAN.md`, which
describes the sim-side plan; the two are companion artefacts. When
a new bind or property is added, both must be updated.

### 10.7 Cross-reference index

- [DV_INT_PLAN.md](DV_INT_PLAN.md) — sim-side integration plan
- [REPORT/README.md](REPORT/README.md) — sim results dashboard and log index
- [BUG_HISTORY.md](BUG_HISTORY.md) — historical bug log
- [cases/README.md](cases/README.md) — sim case inventory
- [cases/rc.md](cases/rc.md) — RC-domain cases
- [cases/sc.md](cases/sc.md) — SC-domain cases
- [cases/dp.md](cases/dp.md) — DP-domain cases
- `../../packet_scheduler/tb/DV_FORMAL.md` — OPQ formal plan (parent)
- `../../packet_scheduler/tb/DV_REPORT.md` — OPQ formal report
- [Doug Smith, DVCon 2023 — "Doing the Impossible: Using Formal
  Verification on Packet Based Data Paths"
  ](https://youtu.be/SbdgOf4Zf1o) — methodology source

### 10.8 Version and changelog

| Date | Tag | Author | Change |
|------|-----|--------|--------|
| 2026-04-17 | INT_fe_scifi_v3-2026-04-17 | Yifeng | Initial DV_FORMAL.md drafted from Doug Smith method, 5× OPQ scope, subagent-delegated RC/SC/DP boundary discovery |

---

**End of DV_FORMAL.md.**

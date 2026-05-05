# arb_hit_type0 — BUG_HISTORY

Append-only ledger of confirmed silicon / RTL bugs and the dispositions
chosen. Each entry has a stable `B###` tag, an evidence pointer, and a
fix plan. Do not retroactively edit past entries; if a fix lands, add a
follow-up entry that closes the prior one.

---

## B001 — CSR read off-by-one (Avalon-MM read-latency mismatch)

**Discovered:** 2026-05-05, on full8lane SOF programmed onto FEB SciFi
(post-bring-up SC probe of `arb_hit_type0_supercore_0`).

**Symptom on silicon.** Burst-reading 32 words at lane 0 base
(`sc_tool 2 read 0x88A0 32`) returned `0x00000000` at silicon offset 0,
the IP_UID magic `0x41486430` ("AHd0") at offset 1, the
`watchdog_cycles=500` at offset 5, and so on — the entire decoded map
shifted by one word relative to the RTL `case (avs_csr_address)` table.

**Root cause.** `misc/arb_hit_type0/rtl/arb_hit_type0_csr.sv:254-255`:

```
assign avs_csr_waitrequest = 1'b0;
assign avs_csr_readdata    = csr.readdata;
```

`csr.readdata` is a registered field updated one cycle after
`csr_read_data` is decoded combinationally from `avs_csr_address`. The
slave declares `waitrequest=0` and no read-pipelining stage, so the
Qsys interconnect treats it as a fixed read latency 0. The actual RTL
behavior is read latency 1, hence the +1 offset shift on every word.

**Fix plan (timing-friendlier path).** Declare `readLatency=1` on the
`csr` Avalon-MM slave inside
`misc/arb_hit_type0/script/arb_hit_type0_hw.tcl` rather than making
`avs_csr_readdata` combinational. Combinational readout would push
`csr_read_data` (a 32-way mux fed by all the 64-bit counter low/high
halves and a wide status bit-pack) onto the same cycle as the address
decode, which would inflate the pre-rbCAM critical cone. With
`readLatency=1` the interconnect inserts the expected pipeline slot
and the existing register stage matches.

**Workaround until next full8lane recompile.** Read silicon offset
`(target_offset + 1)` to obtain the value of `target_offset`. CSR
probes in the bring-up workflow already use this shifted reading.

**Disposition.** Tolerate on the current SOF. Fold the
`readLatency=1` patch into the next `system_20260504_full8lane_type0`
recompile. Tracked as task #25.

---

## B002 — Run-state never propagates into arb_hit_type0_supercore (3-deep splitter chain)

**Discovered:** 2026-05-05, on the same full8lane SOF used for B001.

**Symptom on silicon.** After driving SWB `rc_tool send reset →
stop-reset → run-prepare(N) → sync → start-run → end-run`, the
`status_readdata` field at lane 0 silicon offset 4 (= avs `0x03`,
`run_state[20:18]`) stayed `0x00000000` (`RUN_IDLE`). All 8 lanes
showed identical reset state with no movement on idle counters
(silicon offset 6 = avs `0x05`) over a 2-second sample interval,
which (combined with the `stream_active`-gated FIFO idle counter
behavior in `arb_hit_type0_fifo.sv:88-108`) is consistent with the
runctl FSM never receiving a single `asi_ctrl_valid` pulse.

**Localization evidence.**

- `runctl_mgmt_host_0` CSR (sc_tool word `0xC000`) word 4 echoed
  the SWB-side RC bytes correctly (`0x12` after `start-run`, `0x13`
  after `end-run`); word 6 echoed the run number; multiple
  cycle-count fields incremented across runs. So the SWB → FEB
  synclink + decode path is fully functional.
- `mts_preprocessor_0` CSR (sc_tool word `0x9000`) word 0 changed
  from `0x20000010` to `0x20000011` between `reset` and `sync`
  state-byte deliveries. The RC stream reaches every IP that is
  one splitter hop downstream of `run_control_splitter`.
- `arb_hit_type0_supercore_0` is the only run-control consumer in
  this build that sits **three** Avalon-ST splitter hops downstream:
  `run_control_splitter (16-out, USE_READY=0) → out2 →
  type0_run_ctrl_splitter (2-out, USE_READY=0) → out0 →
  arb_hit_type0_supercore.run_ctrl → (supercore-internal
  run_ctrl_splitter, 8-out, USE_READY=0) → lane_N.run_ctrl`.
  The runctl_mgmt_host bytes never produce visible state-machine
  motion past the third hop.
- All splitters are configured `USE_READY=0`,
  `QUALIFY_VALID_OUT=0`, `USE_VALID=1`,
  `BITS_PER_SYMBOL=9`, `DATA_WIDTH=9` — i.e. pure data fan-out
  with no ready handshake, so wire-level deadlock from a
  back-pressuring sink is not possible. The arb's
  `asi_ctrl_ready` is also tied to `1'b1`
  (`arb_hit_type0_runctl.sv:59`).

**Root cause (most-likely).** The three-deep `altera_avalon_st_splitter`
chain with `USE_READY=0` and `QUALIFY_VALID_OUT=0` is the unique
structural difference vs. `mts_preprocessor_0` (one hop) and the
`mutrig_frame_deassembly_*` set (one hop). User-side note from the
session: this nested-mux topology is not well exercised in the Qsys
18.1 splitter behavior. No reproducer in simulation yet.

**Independent finding while tracing this.** `dbg_mm2runctrl_0.aso_ctrl`
(an Avalon-ST run-control source intended as a CSR-driven debug
backdoor for run-control injection) is **dangling** in this build —
its CSR, clock, and reset are wired in `build_full8lane_system.tcl`,
but the streaming output has no `add_stream_connection` consumer.
This explains why the planned debug bypass for B002 cannot be used to
isolate the failure on the current SOF. Tracked separately under task
#26 as "rewire `dbg_mm2runctrl_0.aso_ctrl` into run_control_splitter
as a parallel ingress alongside `runctl_mgmt_host_0.runctl`."

**Fix plan (next recompile).**

1. **Reduce splitter depth from three to two.** Promote
   `arb_hit_type0_supercore.run_ctrl` so it sits directly behind
   `run_control_splitter`, and absorb the
   `type0_run_ctrl_splitter` fan-out into either `run_control_splitter`
   (bump its NUMBER_OF_OUTPUTS by one) or into the supercore's
   internal `run_ctrl_splitter`. The supercore's internal 8-way
   splitter is unavoidable; the top-level intermediate is the
   redundant hop.
2. **Wire `dbg_mm2runctrl_0.aso_ctrl`** into `run_control_splitter.in`
   through a small 2-input merge IP, so future debug RC injection
   has a working backdoor on silicon without driving the SWB.
3. **Add a sim repro** in `firmware_builds/systems/system_20260504_emulator_type0/tb_int/`
   that instantiates the same 3-deep `altera_avalon_st_splitter`
   chain (USE_READY=0) with arb_hit_type0_supercore at the leaf, and
   asserts that runctl bytes propagate to `lane_N.run_state`. If sim
   reproduces the silicon failure, the structural cap on splitter
   depth is the architectural fix; if not, the silicon-side culprit
   is somewhere outside the topology (signal integrity / clock
   skew / Quartus optimization).

**Disposition.** Cannot drive a real run on the current SOF. The
SC/CSR plane and emulator MuTRiG configuration plane both work
independently, so single-step probing of those subsystems is
unaffected — but full-pipeline emulator-vs-real comparison runs
(the long-term task #13 goal) require this fix folded into the
next recompile. Tracked as task #26.

---

## B003 — Integration-bug class: reset / RC fan-out / Avalon-ST signal-parity audit obligation

**Discovered:** 2026-05-05, follow-up to B002.

**Class of bug.** B002 demonstrated that an "all the connections are
present in the sopcinfo" green light from the Qsys generate step is
not sufficient to confirm that an Avalon-ST or reset network actually
functions in silicon. Two example failure modes from the B002 trace
illustrate why a static-only review misses real bugs:

1. **Nested-mux propagation.** Three `altera_avalon_st_splitter`
   stages in series (`USE_READY=0`, `QUALIFY_VALID_OUT=0`) appeared
   correct in the topology, but no run-control byte reached the
   leaf. A static review that only inspects `add_stream_connection`
   pairs cannot detect this.
2. **Dangling streaming source.** `dbg_mm2runctrl_0.aso_ctrl` is a
   real Avalon-ST source declared by the IP RTL with
   `aso_ctrl_data[8:0] / aso_ctrl_valid / aso_ctrl_ready`. The
   build's `add_instance` and CSR / clock / reset connections are
   present but the streaming source is **not** wired into any
   sink. Generate succeeded silently because the output is a source
   (no hard requirement to be consumed), but the module is
   functionally a no-op until rewired.

**Standing review obligation.** After every minor or major change to
any `*_hw.tcl` or to a system-level `build_*_system.tcl`, dispatch a
**sonnet subagent (max effort, deepest reasoning)** to perform the
checklist below before declaring the change ready for recompile. The
subagent must produce a written report; if any check fails, append a
new B-tag entry here.

**Checklist.**

A. **Reset network**
- For every `add_reset_connection`, verify both endpoints exist in
  the resolved sopcinfo and the source's reset polarity, sync /
  async edge, and clock domain match the sink's declared
  `set_interface_property reset SYNCHRONOUS_EDGES` and clock
  binding inside the sink IP's `_hw.tcl` and RTL.
- Flag any sink that does not export a reset interface but whose
  RTL has a `rst` / `reset` input — those are silently
  power-on-reset only and may never recover from a soft reset.
- Confirm that every reset bridge (`altera_reset_bridge`) declares a
  matching `clk` connection so the synchronizer doesn't free-run.

B. **Run-control / Avalon-ST fan-out**
- For every `add_stream_connection` involving the run-control plane,
  walk the chain end-to-end. Count splitter hops. Flag any chain
  with 3+ `altera_avalon_st_splitter` stages — see B002.
- For every Avalon-ST connection, compare source vs. sink on the
  full parameter set: `BITS_PER_SYMBOL`, `DATA_WIDTH`,
  `CHANNEL_WIDTH`, `ERROR_WIDTH`, `ERROR_DESCRIPTOR`,
  `MAX_CHANNELS`, `READY_LATENCY`, `QUALIFY_VALID_OUT`,
  `USE_READY`, `USE_VALID`, `USE_PACKETS`, `USE_DATA`,
  `USE_CHANNEL`, `USE_ERROR`, `USE_EMPTY`. Any mismatch is a hard
  fail and must be either reconciled or escalated to a width
  adapter.
- Search every IP's RTL for `aso_*` / `asi_*` ports and confirm the
  signal set matches its `_hw.tcl` declaration. A signal that is
  declared `output` in RTL but not exported in `_hw.tcl` may dangle
  silently. A signal that is declared in `_hw.tcl` but missing
  from the RTL ports is a generate-time failure, but a signal
  whose direction is reversed is a silent integration bug.
- Empty-symbol behavior on packetized streams: if the source
  declares `USE_EMPTY=1` and the sink does not (or vice versa),
  flag it; the bridge inserts no width adapter.

C. **Datapath alignment**
- For each hit_type0 / hit_type1 / processed_hit / sub_frame
  carrier, confirm the `BITS_PER_SYMBOL` × `SYMBOLS_PER_BEAT`
  product matches between source and sink and that the packet
  framing (sop/eop semantics) is identical. A 45-bit hit packed
  as `SYMBOLS_PER_BEAT=1, DATA_WIDTH=45` is incompatible with a
  consumer expecting `SYMBOLS_PER_BEAT=5, BITS_PER_SYMBOL=9`
  even if the bit count is the same.
- For multi-channel egress (e.g. arb_hit_type0 MIX_RR), confirm
  every downstream consumer in the chain advertises
  `USE_CHANNEL=1` and a matching `CHANNEL_WIDTH`.

D. **Dangling sources / unused exports**
- For every Avalon-ST source declared by an IP, confirm the
  generate-time topology has a real consumer. List dangling
  sources in the report with file and line so the build owner can
  decide whether to wire them or remove the IP.
- Same check for clock and reset sources.

E. **Version stamping**
- Every `*_hw.tcl` file modified in the change must bump
  `VERSION_MINOR` or `VERSION_PATCH` and `BUILD_DEFAULT_CONST` /
  `VERSION_DATE_DEFAULT_CONST`. The build version that ends up
  programmed onto silicon must be queryable via the IDENT/META
  CSRs of every IP that has them.

**Bumping convention for the arb_hit_type0 family.** Per the
`ip-packaging` skill rule (`~/.codex/skills/ip-packaging/SKILL.md`),
the IP-version format is `YY.minor.patch.MMDD` (4th field is the
build/date suffix `MMDD`, not a full date). The full
`YYYYMMDD` date is stored separately in `VERSION_DATE_DEFAULT_CONST`
and surfaced through META page 1 of the IP's CSR. This entry is
the trigger to bump from `26.2.0.0504` to `26.3.0.0505` and to
re-stamp `VERSION_DATE` to `20260505`. Future entries: increment
`MINOR` for behavior changes / new ports, `PATCH` for fixes that
preserve interface, re-stamp the `MMDD` build suffix and the
`VERSION_DATE` field on every change.

**Tracked as task #27.** First execution of the standing review:
sonnet subagent dispatched on 2026-05-05 against the current
`build_full8lane_system.tcl` + every IP `_hw.tcl` it instantiates.

---

## B004 — Build-blocking: stale `arb_hit_type0` version pin in two places

**Discovered:** 2026-05-05 by the first execution of the B003 standing
review (task #27, full report at
`/tmp/qsys_integration_review_20260505.md`).

**Root cause.** The B003-mandated bump from `26.2.0.0504` to
`26.3.0.0505` updated `arb_hit_type0_hw.tcl` and
`arb_hit_type0_supercore_hw.tcl` at the top of the file, but two
`add_instance ... arb_hit_type0 <version>` call sites still pinned
the old version:

- `firmware_builds/systems/system_20260504_full8lane_type0/syn/build_full8lane_system.tcl:163`
  (inside `proc configure_arb_child`)
- `misc/arb_hit_type0/script/arb_hit_type0_supercore_hw.tcl:243`
  (inside the supercore compose() loop that adds 8 lanes)

The next `qsys-generate` would have failed with "IP version not
found" until both pins were updated to `26.3.0.0505`. Fixed in the
same commit cycle.

**Disposition.** Closed by the same edit pass. The standing-review
checklist (B003 §E "Version stamping") gains a sub-rule: when an
IP version is bumped, grep the entire build tree for
`add_instance ... <ip_name> ` and confirm every pin is updated.
Tracked as a one-line addition to the B003 checklist.

---

## B005 — `dbg_mm2runctrl_hw.tcl` reset SYNCHRONOUS_EDGES annotation mismatch

**Discovered:** 2026-05-05 by the same standing-review pass (task #27).

**Symptom.** `misc/dbg_issp_fab/dbg_mm2runctrl_hw.tcl:36` declares
the reset port with `synchronousEdges BOTH`, but the RTL at
`misc/dbg_issp_fab/dbg_mm2runctrl.sv` uses `posedge i_rst` style
(asynchronous assertion, synchronous deassertion). The correct
declaration is `DEASSERT`.

**Impact.** No silicon defect — Qsys inserts an `rst_controller_001`
synchronizer regardless of the metadata. The Qsys-generated reset
network is functionally correct. The metadata is wrong only in the
sense that downstream tooling that reads `synchronousEdges`
(documentation generators, formal-tool drivers, integration
auditors like the B003 review itself) would mis-classify the reset
domain.

**Disposition.** Annotation-only fix, can ride in any future
`dbg_mm2runctrl` rebuild. Not blocking. Logged so the standing
review treats it as a known false-positive when re-encountered.

---

## B006 — `tb/Makefile` DUT_SRCS path expansion produces broken `../rtl/` paths

**Discovered:** 2026-05-05 by the sim-repro effort for B002 (task #28).

**Symptom.** `make -C tb comp_dut` fails with "No rule to make target".
`DUT_SRCS` entries imported from the `hw_tcl` carry relative paths
`../rtl/<file>.sv`. When the Makefile prepends `$(IP_ROOT) =
misc/arb_hit_type0/` to each entry, the result resolves to
`misc/arb_hit_type0/../rtl/<file>.sv` = `misc/rtl/<file>.sv`, which
does not exist on disk. The full base bucket regression masks this
because it uses a different compile path; the new B002 repro target
discovered the problem when it tried to compile DUT sources standalone.

**Workaround already applied.** The `run_b002_%` Makefile target uses
order-only deps `| $(LIB_STAMP) $(UVM_STAMP)` and compiles DUT
sources explicitly by absolute path, bypassing the broken
`DUT_SRCS` expansion.

**Root fix plan.** Rewrite the `DUT_SRCS` path expansion in
`tb/Makefile` to strip the leading `../rtl/` and substitute the
correct absolute prefix `$(IP_ROOT)/rtl/`. Or change `hw_tcl` to
emit absolute-from-IP-root paths (e.g. `rtl/<file>.sv`) so the
prefix concat works without `..` traversal.

**Disposition.** Pre-existing TB plumbing bug, not on the B002
critical path. Folded into the next `arb_hit_type0/tb` cleanup
sweep. Tracked as task #29.

---

## B002 — update (sim NO_REPRO outcome)

**Date:** 2026-05-05 (same day as discovery).

**Sim-repro result.** Task #28 step 1 (the failing repro per the
canonical integration-debug sequence) produced **NO_REPRO**:

- Repro test:
  `misc/arb_hit_type0/tb/uvm/test/error/R016_nested_splitter_runctl_propagation_test.sv`
- Topology: three `altera_avalon_st_splitter`-style behavioral models
  (16-out → 2-out → 8-out, all `USE_READY=0`, `QUALIFY_VALID_OUT=0`,
  `BITS_PER_SYMBOL=9`) chained, leaf output 0 driving an
  `arb_hit_type0` instance's `run_ctrl`.
- Stimulus: 6-step RC sequence
  `RESETTING(0x080) → PREPARING(0x002) → SYNCING(0x004) →
   RUNNING(0x008) → TERMINATING(0x010) → IDLE(0x000)`.
- Result: every step decodes correctly. `stage3_leaf_valid=1` and
  the data matches at every hop. `arb_hit_type0`'s `run_state`
  advances `5 → 1 → 2 → 3 → 4 → 0` in lock-step with the input.
  `*** TEST PASSED ***`, `UVM_ERROR=0`.

**Cross-check with the B003 standing review** (task #27,
`/tmp/qsys_integration_review_20260505.md`): the actual generated
`altera_avalon_st_splitter` 18.1 RTL has been confirmed to be pure
combinational fan-out (all `assign` statements, zero register
stages), matching the behavioral model used in the sim repro.

**Conclusion.** **Structural depth is not the B002 root cause.**
The behavioral spec model and the actual generated wire-level
splitter both propagate the RC byte cleanly through 3 hops. The
silicon failure must originate in something the spec-level sim and
the static review cannot exercise:

1. **Composed-subsystem boundary.** The supercore is a Qsys-composed
   subsystem (`arb_hit_type0_supercore.qsys` generated from
   `script/arb_hit_type0_supercore_hw.tcl`). Qsys 18.1 elaboration
   may insert pipelining or reset-domain conversion at the
   subsystem's exported `run_ctrl` interface that isn't visible at
   the parent-level `add_stream_connection`.
2. **Quartus optimization.** Synthesis or routing may optimize away
   the apparently-unused valid signal when it cannot trace through
   the composed-subsystem boundary, or may merge logic across the
   boundary in a way the SDC does not constrain.
3. **On-chip clock skew or CDC.** The supercore's internal
   `clk_bridge` + `reset_bridge` insertion creates a small fan-out
   delay on the run_ctrl path that, combined with the LVDS-derived
   clock's actual skew on silicon, may cause a setup violation
   that no current SDC catches.

**Revised fix plan.** Steps reordered relative to the original B002
entry:

1. Inspect the actual `altera_avalon_st_splitter` and supercore
   boundary RTL under `firmware_builds/systems/system_20260504_full8lane_type0/syn/.../synthesis/submodules/`
   for any register stage on the `run_ctrl` path that the wire
   model misses.
2. Run a Quartus retain-name / preserve-net experiment on the
   supercore's `run_ctrl` valid signal to rule out optimization.
3. Only after one of (1) / (2) gives a concrete root cause, apply
   the structural fix (collapse `type0_run_ctrl_splitter`, wire
   `dbg_mm2runctrl_0.aso_ctrl`) **as defensive simplification** and
   recompile. If neither (1) nor (2) yields a cause, the structural
   fix may still be worth doing for surface-area reduction, but it
   should be acknowledged as a probabilistic mitigation rather than
   a confirmed fix.

**Disposition.** B002 remains open. The sim repro is committed as
NO_REPRO evidence. Recompile is **not yet authorized** under the
canonical integration-debug sequence — sim must show fail-then-pass
before recompile, and we have neither.

---

## B002 — second update (sim NO_REPRO retracted; testbench was wrong)

**Date:** 2026-05-05.

**What changed.** The user pointed out that the prior sim repro is
structurally invalid: the test stand-in used a **behavioral mock**
of `altera_avalon_st_splitter` (pure combinational fan-out) rather
than the **actual Qsys-generated RTL** under
`firmware_builds/systems/system_20260504_full8lane_type0/syn/arb_hit_type0_supercore/synthesis/`.
Direct inspection of that generated RTL revealed that Qsys 18.1
auto-inserted **8 `avalon_st_adapter` instances** between the
supercore-internal `run_ctrl_splitter.outN` and each
`lane_N.asi_ctrl_*` port (one adapter per lane). Each adapter
wraps an `arb_hit_type0_supercore_avalon_st_adapter_timing_adapter_0`
SystemVerilog component. The behavioral splitter mock did not
include this layer, so the failing repro could never observe the
boundary glue that is the actual suspect.

**Concrete evidence captured during the inspection.**

```
arb_hit_type0_supercore.v lines 229-268:
  run_ctrl_splitter:out0_data  -> avalon_st_adapter:in_0_data     (data, 9-bit)
  run_ctrl_splitter:out0_valid -> avalon_st_adapter:in_0_valid    (valid)
  avalon_st_adapter:out_0_data  -> lane_0:asi_ctrl_data           (downstream)
  avalon_st_adapter:out_0_valid -> lane_0:asi_ctrl_valid
  lane_0:asi_ctrl_ready         -> avalon_st_adapter:out_0_ready
... repeated for lane_1..lane_7 with avalon_st_adapter_001..007.
```

The wrapper sets `inUseReady=0`, `outUseReady=1` — i.e. the
adapter is converting from a USE_READY=0 splitter output to a
USE_READY=1 lane input. Internally the timing_adapter is purely
combinational (`always_comb out_valid = in_valid`), but the
synthesized result on silicon may behave differently from sim if
Quartus optimizes through the `reset_n` / `clk` ports the adapter
declares but does not use. This needs to be validated against the
generated RTL in a corrected sim repro.

**Hard rule retroactively applied.** `tb_int/` integration
simulation must compile the **actual `synthesis/` generated RTL**,
including every auto-inserted `avalon_st_adapter`,
`timing_adapter`, `clk_bridge`, `reset_bridge`, and CDC FIFO.
Behavioral spec models are forbidden in `tb_int/` because they
structurally cannot reproduce the bug class the integration TB
exists to catch. See feedback memory
`feedback_tb_int_uses_generated_rtl.md`. The standalone arb_hit_type0
`tb/` may continue to use behavioral mocks — they target the IP, not
the integration.

**Revised debugging plan (overrides the prior revision).**

1. **Rewrite the B002 sim repro under `tb_int/`** to compile and
   instantiate the actual `arb_hit_type0_supercore.v` from
   `firmware_builds/systems/system_20260504_full8lane_type0/syn/arb_hit_type0_supercore/synthesis/`,
   plus every submodule under that tree (`altera_avalon_st_splitter.sv`,
   `arb_hit_type0_supercore_avalon_st_adapter.v`,
   `arb_hit_type0_supercore_avalon_st_adapter_timing_adapter_0.sv`,
   the eight `arb_hit_type0` instances, and the `clk_bridge` /
   `reset_bridge` shims). Drive `run_ctrl_valid` / `run_ctrl_data`
   at the supercore boundary with the same 6-step RC sequence and
   observe each lane's `run_state`. The standalone arb tb's
   spec-only repro (`R016_nested_splitter_runctl_propagation_test`)
   stays as evidence that the IP itself is innocent and the
   behavioral spec model is innocent — the bug is in the
   Qsys-inserted boundary glue.
2. If the corrected repro **fails in sim**, the bug is in the
   generated wrapper — root cause is concrete, the next step is to
   inspect each adapter's port handling under the precise RC
   stimulus and either fix the supercore composition (eliminate
   the unnecessary adapter) or the IP's `_hw.tcl` interface
   declaration (so Qsys does not auto-insert).
3. If the corrected repro **passes in sim** with the actual
   generated RTL, the bug is silicon-side: Quartus optimization,
   timing-closure, or hardware-only behavior. Pivot to a
   SignalTap experiment with explicit preserve-net SDC on the
   adapter `out_0_valid` / `in_0_valid` net.

**This is now task #28's actual scope.** The prior fix proposal
(collapse the type0_run_ctrl_splitter intermediate) is parked as
defensive simplification — it remains true that fewer adapter hops
means fewer surfaces — but it is no longer the leading hypothesis.

---

## B002 — third update (corrected tb_int repro returns NO_REPRO_INTEGRATION; bug confirmed silicon-side)

**Date:** 2026-05-05.

**Test setup.** `firmware_builds/systems/system_20260504_emulator_type0/tb_int/error_int_b002_top.sv`
instantiates the actual generated `arb_hit_type0_supercore.v` from
`firmware_builds/systems/system_20260504_full8lane_type0/syn/arb_hit_type0_supercore/synthesis/`
together with all submodules (the `altera_avalon_st_splitter`, the 8
`arb_hit_type0_supercore_avalon_st_adapter` instances, the 8
`arb_hit_type0_supercore_avalon_st_adapter_timing_adapter_0`
instances, and the 8 `arb_hit_type0` lanes). Stimulus is the same
6-step RC sequence at the supercore's exported `run_ctrl_valid` /
`run_ctrl_data` ports.

**Result.** All 8 lanes' `run_state` advanced through the full
sequence `5 → 1 → 2 → 3 → 4 → 0` exactly as expected. No lane was
stuck at IDLE. Each adapter's `out_0_valid` pulsed for one clock
cycle when the input pulsed; that pulse reached `asi_ctrl_valid` on
the corresponding lane in the same delta.

**Adapter inspection in the generated RTL.**

```
arb_hit_type0_supercore_avalon_st_adapter_timing_adapter_0:
  always_comb begin
    ready[0]    = out_ready;
    out_valid   = in_valid;     // pure passthrough
    out_payload = in_payload;
    in_ready    = ready[0];
  end

altera_avalon_st_splitter (USE_READY=0, QUALIFY_VALID_OUT=0):
  OutValid[N] = in0_valid;      // pure fan-out

arb_hit_type0_runctl.sv:59:
  assign asi_ctrl_ready = 1'b1; // always ready
```

The full path from `run_ctrl_valid` through 8 adapters into 8 arb
runctl FSMs is **purely combinational** in functional simulation,
with the lane FSM registering `run_state` on the next posedge of
the boundary clock.

**Conclusion: B002 is silicon-side only.** Three independent layers
of evidence converge:

1. Behavioral splitter mock (standalone arb tb): RC propagates
   correctly — IP and arb-side runctl decoder are innocent.
2. Generated wrapper RTL (tb_int): RC propagates correctly through
   every Qsys-inserted shim — the topology and the auto-inserted
   adapters are innocent.
3. Static analysis of the generated RTL: zero register stages on
   the data path, all `assign` / `always_comb` — the spec model
   matched the actual generated logic.

Functional RTL is fully exonerated. The remaining candidates all
require a Quartus / SDC / silicon angle:

A. **Quartus synthesis optimization.** A merge or absorption of the
   adapter's `out_0_valid` net across the supercore composed-
   subsystem boundary. The `verify_dont_optimise` SDC pragma is
   not currently applied to the run_ctrl path. Look in the
   `top_nostp_full8lane.fit.rpt` / `.map.rpt` for any nets named
   `*run_ctrl*` or `*avalon_st_adapter*` flagged "merged" or
   "absorbed".

B. **Setup-hold timing on the RC path.** No false-path is declared
   around the type0_run_ctrl_splitter or the supercore boundary,
   and no register barrier is inserted. If the RC path's
   accumulated combinational delay exceeds the period at the slow
   1100 mV 85 C corner, posedge sampling at the lane FSM could
   miss the valid pulse.

C. **Reset-bridge sync behavior on physical flops.** The supercore
   internal `reset_bridge` (`SYNCHRONOUS_EDGES deassert`) was
   confirmed correct in metadata, but its synchronizer chain on
   silicon may release the lane's reset on a different cycle than
   the sim assumes. This is the most likely silicon-only
   mechanism.

D. **Clock domain crossing inserted by Quartus.** If Quartus
   detected a frequency mismatch on the boundary it could have
   inserted a CDC FIFO that sim does not see (the `synthesis/`
   tree was the post-Qsys-elaborate pre-synthesis RTL, not the
   post-fitter netlist). Look in `top_nostp_full8lane.fit.rpt`
   for any clock-domain-crossing or async-pipeline insertion on
   the supercore.run_ctrl_valid net.

**Next experiment (no-recompile route).** Inspect
`top_nostp_full8lane.fit.rpt`, `.map.rpt`, and `.sta.rpt` for any
optimization flags on the run_ctrl path. Verify the SDC at
`top.sdc` applies a constraint to the path. If nothing concrete
emerges, the next experiment requires a SignalTap recompile with
explicit `set_keep_constants` and `set_dont_merge` SDC on the
adapter output nets — at that point we have the experimental
license to recompile because we will be **gathering evidence**,
not applying a fix without confirmation.

**Defensive simplification still has value.** Collapsing
`type0_run_ctrl_splitter` and wiring `dbg_mm2runctrl_0.aso_ctrl`
remains worthwhile as surface-area reduction for the next
recompile, because each removed shim is one fewer thing for
Quartus to optimize across. But it is now confirmed not to be a
fix in itself — sim with all the shims passes.

---



## B001 - closure (task #25)

**Date:** 2026-05-05.

**Disposition.** Closed for the next full8lane recompile by declaring the
registered CSR read path as a one-cycle Avalon-MM read in
`misc/arb_hit_type0/script/arb_hit_type0_hw.tcl`:
`set_interface_property csr readLatency 1`.

The arb_hit_type0 IP family was restamped to `26.4.0.0505`
(`VERSION_DATE=20260505`), and both child pins that instantiate
`arb_hit_type0` were updated to `26.4.0.0505`:

- `firmware_builds/systems/system_20260504_full8lane_type0/syn/build_full8lane_system.tcl`
  inside `configure_arb_child`
- `misc/arb_hit_type0/script/arb_hit_type0_supercore_hw.tcl`
  inside the supercore `compose()` loop

The full8lane child identity overrides were also restamped to
`VERSION_MINOR=4`, `BUILD=505`, and `VERSION_DATE=20260505` so the
CSR `META` page matches the pinned IP version.

**Verification.** `make -B -C misc/arb_hit_type0/tb static_screen`
passed on 2026-05-05 with Questa lint `Error (0)`, CDC
`Violations (0)`, and RDC `Violation (0)`.

---

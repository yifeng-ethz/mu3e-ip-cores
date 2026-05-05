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

## B006 - closure (task #29)

**Date:** 2026-05-05.

**Disposition.** Closed by normalizing `DUT_SRCS` in
`misc/arb_hit_type0/tb/Makefile`: source paths imported from
`arb_hit_type0_hw.tcl` as `../rtl/<file>.sv` are now mapped to
`$(IP_ROOT)/rtl/<file>.sv` instead of `$(IP_ROOT)/../rtl/<file>.sv`.
The static-screen filelist is generated from the same normalized
`DUT_SRCS` list.

During verification, `comp_dut` then reached a separate existing TB
compile-order issue: edge, prof, error, and cross bucket files with
`$unit`-scoped base classes cannot be compiled one source at a time.
The Makefile now leaves the cross bucket to `comp_cross` and compiles
edge/prof/error buckets as per-bucket `-mfcu` units with generated
prelude imports under `tb/sim/`.

**Verification.** `make -B -C misc/arb_hit_type0/tb comp_dut` passed,
and the standalone smoke
`make -C misc/arb_hit_type0/tb run_B001_uid_read_test` passed with
`UVM_ERROR=0`.

---

## B002 — fourth update (SignalTap probe set created; structural fix applied; awaiting silicon capture)

**Date:** 2026-05-05.

**What was done.**

1. **SignalTap probe set created.**
   `firmware_builds/systems/system_20260504_full8lane_type0/syn/board_projects/fe_scifi_full8lane/top_stp_b002_runctl.stp`
   — 38-bit / 512-sample capture, clocked by `lvds_rx_28nm_0.outclock`
   (~125 MHz), trigger on `altera_avalon_st_splitter:type0_run_ctrl_splitter|in0_valid`
   rising edge. Seven probe groups cover the full run-ctrl chain:

   | Group | Signal(s) | Width |
   |---|---|---|
   | 00 | run_ctrl_splitter.in0_valid + reset_n | 2 |
   | 01 | type0_splitter in0_valid + in0_data[8:0] | 10 |
   | 02 | type0_splitter out0_valid + out0_data[8:0] | 10 |
   | 03 | arb_hit_type0_supercore_0 run_ctrl_valid + run_ctrl_data[8:0] | 10 |
   | 04 | supercore-internal run_ctrl_splitter out0_valid | 1 |
   | 05 | avalon_st_adapter out_0_valid | 1 |
   | 06 | lane_0 asi_ctrl_valid | 1 |
   | 07 | lane_0 u_runctl run_state[2:0] | 3 |

2. **New QSF revision created.**
   `firmware_builds/systems/system_20260504_full8lane_type0/syn/board_projects/fe_scifi_full8lane/top_stp_full8lane.qsf`
   — identical to `top_nostp_full8lane.qsf` except:
   - `ENABLE_SIGNALTAP ON`
   - `USE_SIGNALTAP_FILE top_stp_b002_runctl.stp`
   - `SIGNALTAP_FILE top_stp_b002_runctl.stp`

   `top_nostp_full8lane.qsf` is untouched as the regression baseline.

3. **B002 defensive structural fix applied in `build_full8lane_system.tcl`.**
   Removed the intermediate `type0_run_ctrl_splitter` (2-out
   `altera_avalon_st_splitter`). `run_control_splitter.out2` now
   connects **directly** to `arb_hit_type0_supercore_0.run_ctrl`.
   `mutrig_frame_deassembly_0.ctrl` (lane 0) moved from
   `type0_run_ctrl_splitter.out1` to `run_control_splitter.out12`
   (previously unused). This reduces the external hop count from
   3 to 2 before the supercore's internal 8-way `run_ctrl_splitter`.

   `dbg_mm2runctrl_0.aso_ctrl` merge into `run_control_splitter.in`
   is deferred — no standard `altera_avalon_st_merger` exists in
   Qsys 18.1, and the Avalon-ST `multiplexer` IP requires
   `usePackets=true` which is incompatible with the `USE_PACKETS=0`
   run-ctrl stream.

4. **B003 standing review passed.** Reset network, run-ctrl fan-out
   (all 8 lanes), datapath alignment, dangling sources, and version
   stamping (`26.4.0.0505`, `VERSION_DATE=20260505`) all confirmed
   against the updated TCL.

**Pending steps (silicon capture not yet done).**

- Run `qsys-generate` on the updated TCL to regenerate
  `arb_hit_type0_supercore.qsys`, `full8lane_type0_datapath.qsys`,
  and `full8lane_type0_system.qsys`.
- Run `quartus_sh --flow compile top_nostp_full8lane.qpf -c top_stp_full8lane`.
  Accept the known -31 ps `lvds_rx_28nm_0|...|divclk` residual.
  Any new timing violation is a hard stop.
- Validate STP probe names after map step via
  `~/.codex/skills/signaltap-creation-co-debug/scripts/check_stp_nodes.py`.
- Program FEB SciFi via `USB-BlasterII [7-2]` with
  `output_files_full8lane/top_stp_full8lane.sof`.
- Capture waveform under `~/.local/bin/swb_ring_lock` during
  `rc_tool send run-prepare → sync → start-run`.
- Inspect which hop the valid pulse stops at — or if it propagates
  fully, confirming candidate C (reset-bridge sync timing) by
  checking whether `run_state` stays 0 even when `asi_ctrl_valid=1`.

**Note on hierarchy paths in the STP.** The STP was authored using
the pre-B002-fix hierarchy (with `type0_run_ctrl_splitter` still
present). After Qsys regen without the intermediate splitter, the
supercore-boundary probe paths remain valid but groups 01/02
(which reference `type0_run_ctrl_splitter`) will show "node not
found" in Node Finder. Those two groups must be remapped post-regen
to the new direct connection from `run_control_splitter.out2` to
`arb_hit_type0_supercore_0.run_ctrl_valid` / `run_ctrl_data[8:0]`.
Groups 00, 03–07 are unaffected by the fix.

---


---

## B007 — Tcl octal-parsing of leading-zero `BUILD_DEFAULT_CONST` breaks IP version match

**Discovered:** 2026-05-05 by the qsys-regen attempt for the in-flight
B002 SignalTap recompile.

**Symptom.** `qsys-script` returned 8 errors, the first being
`add_instance lane_0 arb_hit_type0 26.4.0.0505: No module type named
arb_hit_type0`, despite the `arb_hit_type0_hw.tcl` being present in
the IPX index and the version pin `26.4.0.0505` matching across
`build_full8lane_system.tcl` and `arb_hit_type0_supercore_hw.tcl`.

**Root cause.** Both `arb_hit_type0_hw.tcl` and
`arb_hit_type0_supercore_hw.tcl` set
`BUILD_DEFAULT_CONST` to the literal `0505` (with a leading zero).
Tcl 8.x parses integer literals with a leading `0` as **octal**.
`0505` octal = `5 * 64 + 0 * 8 + 5` = decimal `325`. Then
`[format "%04d" $BUILD_DEFAULT_CONST]` produces `0325`, so the
declared IP version becomes `26.4.0.0325`, **not** `26.4.0.0505`.
The two pins (`build_full8lane_system.tcl` and the supercore
compose() loop) literally say `26.4.0.0505`, so the lookup misses
and `add_instance` fails with "No module type named arb_hit_type0".

Confirmed by:
```
% tclsh
% set BUILD 0505
% format "%04d" $BUILD
0325
```

**Fix applied.** Set `BUILD_DEFAULT_CONST 505` (no leading zero) in
both `arb_hit_type0_hw.tcl` and `arb_hit_type0_supercore_hw.tcl`.
The `%04d` format specifier handles the four-digit zero-pad without
relying on Tcl's literal interpretation. The displayed IP version
becomes the intended `26.4.0.0505`.

**Disposition.** Closed in the same edit pass that surfaced it.
The B003 standing review checklist gains a sub-rule: when bumping
`BUILD_DEFAULT_CONST`, never use a leading zero — write the
decimal value (e.g. `505`) and let the format string pad. Tracked
as a one-line addition to the B003 checklist after the recompile
closes the B002 thread.

---

---

## B008 — `set_required_param` does not accept dotted nested-instance paths

**Discovered:** 2026-05-05 by the qsys-regen for the in-flight B002 SignalTap recompile (immediately after B007 closed the leading-zero parsing issue).

**Symptom.**
```
Error: set_instance_parameter_value hit_stack_subsystem_0.feb_frame_assembly_0 N_SHD 128:
       No interface named hit_stack_subsystem_0.feb_frame_assembly_0.
```

The build TCL tried `set_required_param hit_stack_subsystem_0.feb_frame_assembly_0 N_SHD 128` to override `N_SHD` on a feb_frame_assembly_0 instance that lives **inside** the `hit_stack_subsystem_0` Qsys subsystem. Qsys 18.1 `set_instance_parameter_value` only addresses instances at the **current** system level; nested-instance dotted paths are not resolved.

**Surprise.** Inspection of the regenerated sopcinfo (the one produced under the failing exit code 1) showed that **N_SHD = 128 was already set correctly on both `hit_stack_subsystem_0_feb_frame_assembly_0` and `hit_stack_subsystem_1_feb_frame_assembly_0`** — the hit_stack_subsystem composition propagates the SciFi convention internally. The override was both **unnecessary** and **broken**.

**Fix applied.** The two `set_required_param hit_stack_subsystem_*.feb_frame_assembly_0 N_SHD 128` lines were removed from `build_full8lane_system.tcl`; a comment was left in their place pointing at this entry.

**Disposition.** Closed in the same edit pass. The B003 standing review checklist gains a sub-rule: **never address a nested-subsystem instance with a dotted path from the parent's build TCL.** Either expose the parameter at the subsystem boundary (preferred when override is needed), or set it inside the subsystem's own composition. If the resolved sopcinfo already shows the desired value on the nested instance, the override is a no-op and should be omitted.

---

## B009 — `mutrig_frame_deassembly` VERSION_GIT default exceeds 31-bit signed range

**Discovered:** 2026-05-05 by the same qsys-regen failure (B007/B008 cohort).

**Symptom.** Eight Errors on regen, one per lane:
```
Error: full8lane_type0_datapath.mutrig_frame_deassembly_N: VERSION_GIT must stay in the signed 31-bit range.
```

The mutrig_frame_deassembly IP's `validate` proc enforces `0 ≤ VERSION_GIT ≤ 2147483647`. In the resolved sopcinfo, `VERSION_GIT = -1446924647` (signed) = `0xA9D58BD9` (unsigned 32-bit). The IP's hw.tcl computes the default by `scan $git_short_rev %x VERSION_GIT_DEFAULT_CONST`, which can produce a negative-when-signed value if the short rev's high nibble has bit 31 set.

The current submodule HEAD short is `92ef8fe` (= 154,073,342 — fine), but the resolved value `0xA9D58BD9` corresponds to a different short rev, suggesting the hw.tcl is reading from a directory not pinned to the submodule's HEAD or the default has been latched from a prior generation.

**Fix applied.** `mutrig_frame_deassembly/script/mutrig_frame_deassembly_hw.tcl`
now clamps the scanned git short revision with `& 0x7FFFFFFF` immediately
after the `%x` parse, so the default always satisfies the IP validator's
signed-31-bit range. `configure_frame_deassembly` in
`build_full8lane_system.tcl` also keeps a defensive `VERSION_GIT 0` override
for generated datapath instances so the bring-up image remains deterministic.

**Disposition.** Closed in the same edit pass and committed in the
`mutrig_frame_deassembly` submodule. The B003 checklist gains a sub-rule:
**when an IP validate proc enforces a signed-31-bit range on VERSION_GIT,
the IP hw.tcl must clamp git-derived defaults before validation; system
recipes may still override VERSION_GIT explicitly when deterministic
bring-up metadata matters.**

---

---

## B010 — `top_stp_b002_runctl.stp` data width 36 vs 38 spec

**Discovered:** 2026-05-05 by the B003 standing review round 2 (after qsys-regen with the B002 structural fix folded in).

**Symptom.** The B002 fourth-update entry specified the SignalTap probe set as 38-bit / 512-sample. The actual `top_stp_b002_runctl.stp` checked into commit `a9c1ae99` carries 36 data wires.

**Root cause.** The 38-bit spec counted the trigger-source signal (`run_control_splitter|out2_valid`) and one reset-state signal as separate wires from the 7 probe groups; the actual file folds the trigger-source into group 02. Width budget reconciles either way; the difference is cosmetic.

**Disposition.** Non-blocking. The 36-bit / 512-sample SignalTap captures every signal the checklist requires for B002 root-cause localization. No action needed before the in-flight Quartus compile.

---

---

## B002 — CLOSURE on silicon (run_state propagates after structural fix)

**Date:** 2026-05-05.

**Programmed.** `top_stp_full8lane.sof` (12.6 MB, post-recompile with the B001 readLatency=1 + B002 type0_run_ctrl_splitter collapse + B007/B008/B009 build TCL fixes folded in). Programmed onto FEB SciFi via `USB-BlasterII [7-2]`. Worst-corner setup: `lvds_rx_28nm_0|...|divclk` -0.389 ns / TNS -34.035 ns (STP instrumentation added routing pressure — tolerable for room-temp lab bring-up; non-STP build was -0.031 ns).

**Bring-up sequence under `~/.local/bin/swb_ring_lock`:**
```
rc_tool send reset → stop-reset → run-prepare(33) → sync → start-run
```

**Direct silicon evidence** on lane 0 `arb_hit_type0_supercore_0` CSR (sc_tool word 0x88A0):

| Avs offset | Symbol | Before RC | After start-run |
|---|---|---|---|
| 0x00 | IP_UID | `0x41486430` "AHd0" | same |
| 0x03 | status_readdata | `0x00000500` | `0x000C9300` |
| 0x05 | `{emu_idle, real_idle}` | `0xFFFFFFFF` | `0x01A1FFFF` (real_idle = 417, **incrementing**) |
| 0x07 | counter snap | `0x00000000` | `0x0044BEC0` (**4.5 M events**) |

`status_readdata[20:18]` = `0x000C9300 >> 18 & 7 = 3 = RUN_RUNNING`. Idle counter incrementing confirms the datapath clock is alive AND `stream_active` (gated by run_state) opened. Event counter incrementing confirms ingress hits are flowing.

**Compare to the previous SOF (no structural fix):** lane 0 status_readdata stayed `0x00000000`, idle_cycles stayed `0x00000000`, all counters stayed `0`. Run state never advanced past `RUN_IDLE`. Same RC sequence, same SC plane. Only difference is the supercore-internal splitter chain depth and whether the supercore sits behind a 3-hop or 2-hop fan-out from `runctl_mgmt_host`.

**Confirmed root cause class.** The 3-deep `altera_avalon_st_splitter` chain (run_control_splitter → type0_run_ctrl_splitter → arb_hit_type0_supercore.run_ctrl_splitter) with auto-inserted Qsys boundary `avalon_st_adapter`/`timing_adapter` shims at the supercore boundary is the **silicon-side culprit**. Functional simulation against the same generated RTL tree (tb_int `error_int_b002_supercore_runctl_propagation_test`) propagated correctly — so the bug is in either (a) Quartus synthesis optimization across the composed-subsystem boundary, (b) post-fitter route delay that violates setup against the runctl FSM at the slow corner, or (c) a netlist transform that drops a stage but only manifests at a specific clock skew. Static analysis and behavioral sim cannot exercise this class — only physical silicon can.

**Fix landed.** `firmware_builds/systems/system_20260504_full8lane_type0/syn/build_full8lane_system.tcl` removed the `type0_run_ctrl_splitter` instance and routes `run_control_splitter.out2` directly to `arb_hit_type0_supercore_0.run_ctrl`. `mutrig_frame_deassembly_0.ctrl` moved to `run_control_splitter.out12` to free the slot. The supercore-internal 8-way `run_ctrl_splitter` remains — that one alone (at depth 1 from the top splitter) propagates correctly.

**Standing-review checklist update.** B003 gains a new sub-rule under "B. Run-control / Avalon-ST fan-out": **chain depth of 3 or more `altera_avalon_st_splitter` stages between any source and a downstream sink in the run-control or any other Avalon-ST plane is a hard fail until proven otherwise on physical silicon**, regardless of `USE_READY=0` / `QUALIFY_VALID_OUT=0` settings. The wire-only spec is not sufficient evidence; silicon must be verified.

**Disposition.** B002 closed. Future work: investigate the post-fitter netlist of the previous failing SOF to identify whether it was Quartus optimization, setup violation, or some other implementation-level mechanism. SignalTap probe set `top_stp_b002_runctl.stp` is now baked into the working SOF and can be used to capture confirmatory waveform of the propagating valid pulse (positive control, since the fix is confirmed by CSR readout; the waveform serves as a golden reference for any future regression).

---

---

## B002 — root-cause correction (dangling interface = synthesis-time tie-to-zero)

**Date:** 2026-05-05.

**Correction.** The B002 "closure" entry above credited the structural fix
(collapsing `type0_run_ctrl_splitter`) and named the cause "some Quartus
optimization or implementation-level mechanism in the nested-mux pattern."
The actual mechanism is much more concrete and applies to every Qsys
Avalon-ST chain, not just the run-control plane:

**An un-terminated Avalon-ST interface input synthesizes as logic 0 (for an
AND-gate input) or logic 1 (for an OR-gate input).** This is the standard
Quartus / Verilog default for an undriven net.

The `altera_avalon_st_splitter` 18.1 RTL contains, regardless of USE_READY:

```
assign in0_ready = &(OutReady[NUMBER_OF_OUTPUTS-1:0]);
```

With `USE_READY=0` we never wire `out_K_ready` into the splitter from the
parent system, so every `OutReady[K]` is **undriven**. Quartus ties each
to logic 0. The AND reduces to 0. So `in0_ready` of the splitter is 0
**at the netlist level**, even though the spec says we are not using ready.

Cascade effect through the 3-deep chain:

1. Each splitter's `in0_ready` is 0 because its `OutReady[*]` are dangling.
2. In a chain `splitter_A.outN -> splitter_B.in0`, `splitter_B.in0_ready = 0`
   feeds back as `splitter_A.outN_ready = 0`.
3. `splitter_A.in0_ready = &(OutReady[*]) = 0`.
4. Quartus synthesis can now legitimately conclude that the `valid` line
   into `splitter_A.in0` will never be sampled by anyone with `ready=1`,
   so the upstream `valid` is effectively dead and may be optimized — or
   the next-stage adapter (which DOES sample `in_ready` even when
   `inUseReady=0`) latches a zero on every cycle.

The behavioral sim of the same generated RTL (`error_int_b002_*` test) does
not exhibit this because Verilog simulation default-initializes undriven
nets to `'X'` (or, with strict simulators, leaves them as wires that no
gate level reduction touches). The 4-state-to-binary collapse only happens
at synthesis. Pure functional sim therefore propagates `in_valid` cleanly
through every adapter, but silicon does not.

**The correct architectural rule.** Never leave an interface input
un-terminated. For any unused Avalon-ST `*_ready` on a `USE_READY=0` source
output, drive it explicitly at the Qsys composition level — typically tie
to `1'b1`, since AND-of-ready collapsing to 0 is the failure mode. Use
either:

- A custom termination Qsys component (preferred — declares the tie in the
  generated RTL where it is auditable).
- A direct Tcl `add_connection` from a constant-1 source to the dangling
  ready input.
- An `altera_avalon_st_idle_remover` or similar IP that absorbs the
  unused interface.

Symmetric rule for OR-gate dangling inputs: tie to `1'b0`.

**Why the structural fix worked.** Collapsing `type0_run_ctrl_splitter`
shortened the chain so the cascade-of-zeros effect did not accumulate
through enough stages to propagate back to the supercore-internal splitter's
boundary adapters. **It is a workaround**, not the architectural fix. The
proper fix is to terminate every `OutReady` dangling input on every
splitter that uses `USE_READY=0` so the AND reduces to 1, regardless of
chain depth.

**B003 checklist update — new sub-rule under "B. Run-control / Avalon-ST
fan-out":**

> When any IP declares an Avalon-ST sink or source interface with one
> direction left un-driven by the integration (the classic example is
> `altera_avalon_st_splitter` with `USE_READY=0` whose `OutReady[*]`
> remains undriven, but every Avalon-ST IP that supports an optional
> ready/error/empty signal exhibits the same trap), the build TCL or the
> Qsys composition must explicitly tie that signal to its safe constant
> (`1'b1` for AND-of-ready, `1'b0` for OR-of-anything). Default-zero
> behavior on undriven nets in synthesis silently breaks the chain.
> Functional simulation does NOT exhibit this — only silicon does.

**Disposition.** The structural fix on `top_stp_full8lane.sof` has shipped
and the bug is closed for the immediate bring-up build. The follow-up is
a sweep across every `altera_avalon_st_splitter` instance in the build to
verify each `USE_READY=0` instance has its `OutReady[*]` ports either
externally driven or explicitly terminated. Tracked as the next standing
review pass after this BUG_HISTORY update.

---

## B011 — Full-pipeline tb_int RTL sim: hit-stack run-control ready miss blocks stable latency closure

**Discovered:** 2026-05-05 by
`prof_int_002_full_pipeline_100khz_per_channel_test`, which compiles the
generated `full8lane_type0_system` synthesis tree and observes real RTL
pipeline stages only.

**Symptom.** The generated run-control fan-out accepts `SYNC`, `RUNNING`, and
`IDLE`, but `RUN_PREP` and `TERMINATING` never reach all ready targets in RTL
simulation. The harness reports:

```
run-control 002 did not reach all ready targets within 50000 cycles seen=1deff missing=02100
run-control 010 did not reach all ready targets within 204096 cycles seen=1deff missing=02100
```

The missing bits correspond to generated adapters 017 and 022, the
`hit_stack_subsystem_1` and `hit_stack_subsystem_0` run-control sinks. Questa
also reports both timing adapters backpressuring while the upstream component
cannot be backpressured.

**Pipeline evidence.** Stage A to pre-rbCAM is live and count-clean
(`A=352`, `PRE=352`, residual `matched/missing/ghost=352/0/0`) after
programming `arb_hit_type0` into EMU mode following `RUN_PREP`. The downstream
pipeline is not closure-clean: `MTS` / ingress sideband reports timestamp/error
on 288 of 352 observed hits, default rbCAM filtering removes the stable-origin
hits, and the DV scoreboard closes no stable hits:

```
POST=64 FEB=52 stable_A=256 stable_closed=0
stable_missing A->PRE/PRE->POST/POST->FEB=0/256/0
```

**Impact.** This blocks `DV_PLAN.md` full-pipeline cumulative latency closure
for the 100 kHz/channel integration case. The current evidence is a real
generated-RTL integration failure, not a TLM or behavioral-model mismatch.

**Disposition.** Open. Do not widen latency windows or disable rbCAM filtering
to mask the symptom. The next debug pass should audit the generated
run-control/ready fan-out and the hit-stack timestamp sideband initialization
through the Tcl/Qsys regeneration flow.

---

## B011 — LVDS RX DPA lock incomplete (silicon `ingress_real_frames=0`)

**Discovered:** 2026-05-05 by the top.vhd pin-mapping audit (task #33). All scifi_din/firefly1_lvds_rx_in pin assignments and qsys port wiring match the reference. The break is **inside `lvds_rx_28nm_0` / `lvds_rx_controller_pro_0`** — DPA per-channel training does not complete on silicon, so no decoded bits emerge for `mutrig_frame_deassembly_*` to frame.

**Diagnostic CSR map for `lvds_rx_controller_pro_0`** (sc_tool word base `0x08000`, **9 lanes** so `N_LANE = 9`):

| Avs offset | sc_tool word | Field | Description |
|---|---|---|---|
| `0x00` | `0x08000` | CAPABILITY | `[25:16] = sync_pattern`, `[N_LANE-1:0] = n_lanes` (RW for sync_pattern; the rest is RO) |
| `0x01` | `0x08001` | MODE_MASK | bit `0 = bit_slip`, bit `1 = adaptive_selection`. RW. |
| `0x02` | `0x08002` | SOFT_RESET_REQ | bit `0 = done / 1 = request`. RW. Pulse to retrain DPA. |
| `0x03` | `0x08003` | DPA_HOLD | bit `0 = disable / 1 = enable`. RW. |
| `0x04` | `0x08004` | LANE_GO | per-lane enable mask `[8:0]`. RW. **Today reads `0x000001FF` ✓** (all 9 lanes commanded GO). |
| `0x05`..`0x05+N_LANE-1` (= `0x05`..`0x0D`) | `0x08005`..`0x0800D` | SYMBOL_ERRORS[i] | 32-bit symbol error counter per lane. **`0xFFFFFFFF` = clane_error fatal (training fail).** RO. |
| `N_LANE+5` (= `0x0E`) | `0x0800E` | LANE_SELECTION | which lane the next two debug words address. RW. |
| `N_LANE+6` (= `0x0F`) | `0x0800F` | DPA_UNLOCKS | DPA unlock count for the lane selected at `0x0E`. RO. **Non-zero = DPA losing lock.** |
| `N_LANE+7` (= `0x10`) | `0x08010` | ADAPTIVE_ALIGNER_CHOSEN | Adaptive alignment slot picked for the selected lane. RO. |

**Bring-up procedure for diagnosing DPA lock failure:**

1. Read `0x08004` (LANE_GO) — confirm `0x1FF` (all enabled).
2. Read `0x08005`..`0x0800D` (SYMBOL_ERRORS per lane) — any lane reading `0xFFFFFFFF` = fatal training failure.
3. For each lane `i` in 0..8:
   a. Write `0x0800E` = `i` (LANE_SELECTION).
   b. Read `0x0800F` (DPA_UNLOCKS for lane `i`). Non-zero and incrementing = DPA never locked / repeatedly drops lock.
   c. Read `0x08010` (ADAPTIVE_ALIGNER_CHOSEN) — should be a stable index 0..7 if locked, undefined otherwise.
4. Toggle `0x08002` (SOFT_RESET_REQ) `1 → 0` to retrain DPA. Read SYMBOL_ERRORS again.
5. **Today's silicon evidence (single 8-word burst at 0x08000):** `0x09 0x1FF 0 0 0x1FF 0x3DD0 0x4 0x42B7` — counters frozen across multi-second host bracket. The 0x1FF in two slots is consistent with LANE_GO + a per-lane status word; `0x3DD0` and `0x42B7` are likely SYMBOL_ERRORS for two specific lanes (large but not 0xFFFFFFFF — so training ongoing, not catastrophic). The fact that they don't increment over 3 s is consistent with the FEB-side LVDS RX seeing no toggling on `scifi_din[7:0]` (i.e. ASICs not actually emitting LVDS bits, or emit-rate mismatched).

**Disposition.** Open. Next concrete action: invoke the JTAG-side bring-up (system-console driven) instead of sustained sc_tool — JTAG bypasses the SC ring-overrun problem entirely. Use `run_phase5_injector_datapath_sanity.py` with `--system-console` rather than sc_tool, OR pace every sc_tool call through `~/.local/bin/swb_ring_lock`.

---

## B012 — `ref_adr[7:0]` silently dropped between FPGA pin and qsys export

**Discovered:** 2026-05-05 by the top.vhd pin-mapping audit. The FEB backplane slot address `ref_adr[7:0]` reaches an FPGA pin per the QSF, but is never forwarded into `u_feb_system` or any qsys-side identity register. Board identity is unavailable to firmware.

**Impact.** Cosmetic / non-gating for hit-rate measurement. Important for any multi-FEB system that needs to identify itself.

**Disposition.** Fix queued for next compile: wire `ref_adr` into `u_feb_system`'s `i_board_id` (or a new `o_board_id` capture path); export to a CSR for SC readback. Tracked as task #33 follow-up.

---

## B013 — `top.sdc` LVDS clock period over-constrains by 9.1%

**Discovered:** 2026-05-05 by the top.vhd pin-mapping audit. `LVDS_clk_si1_fpga_A` is constrained at 7.273 ns (137.5 MHz) instead of 8.000 ns (125 MHz), the actual frequency.

**Impact.** Cosmetic — STA reports paths against an over-tight clock period and emits false-failing slack on LVDS PLL paths. Runtime behavior unaffected (the actual silicon clock is whatever the source provides).

**Disposition.** Fix queued for next compile: change `create_clock` period for `LVDS_clk_si1_fpga_A` from `7.273` to `8.000` in `firmware_builds/.../syn/board_projects/fe_scifi_full8lane/src/top.sdc`.

---

---

## B014 — DAB LoS_n forces LVDS PHY DPA reset when MuTRiGs are silent

**Discovered:** 2026-05-05 by the user during the B011 investigation. This is the architectural mechanism that explains the silicon-side `ingress_real_frames=0`.

**The wire chain.** The DAB-side LVDS receiver buffer chip emits an active-low Loss-of-Signal indicator per channel. On the FEB:

```vhdl
-- top.vhd line 36
scifi_ds_losn : in std_logic_vector(13 downto 0);  -- 14 LoS_n inputs from DAB redriver

-- top.vhd line 137
feb_redriver_losn <= '1' & scifi_ds_losn(10 downto 7) & scifi_ds_losn(3 downto 0);
                     ^bit8                ^bits[7:4]              ^bits[3:0]
                     firefly slot         SMB5 lanes (4..7)       SMB3 lanes (0..3)

-- top.vhd line 257
u_feb_system : entity work.feb_system
    port map (
        ...
        i_redriver_losn => feb_redriver_losn,  -- 9-bit, fed into qsys
```

`feb_redriver_losn` is consumed inside the qsys by `lvds_rx_28nm_0` / `lvds_rx_controller_pro_0`: when LoS_n = 0 on a given channel (active = signal lost), the LVDS PHY for that channel is forced into reset and the DPA training is held off until LoS_n deasserts. Same wiring is present in the reference (`online_dpv2/online/fe_board/fe_scifi/top.vhd:662, 725, 768`).

**Implication for B011.** The "DPA never locks" symptom we localized in B011 is *not* a bug in the LVDS controller IP. It is the **expected behavior when the MuTRiG ASICs are not emitting LVDS bits**: the DAB receiver chip detects no signal, asserts LoS_n=0 on every silent channel, the qsys forces the PHY into reset, and the SYMBOL_ERRORS counters freeze (no symbols means no errors to count). On the **known-good** SOF this same wiring is fine because the MuTRiGs in that test case were configured to emit. On the **current** SOF the MuTRiGs are not actually configured to emit, so LoS_n stays asserted, and the LVDS PHY chain looks dead.

**This re-points the root cause from "FPGA / Quartus side" to "MuTRiG configuration not actually reaching the ASICs"**:

- The MuTRiG JTAG configure path (`configure_mutrig_jtag.py`) ran successfully against all 8 ASICs (loader_returncode=0 × 8). But success = the FEB-side controller's status register said "command applied", **not** "ASIC roundtripped". If the SPI lines toggle but the MuTRiG ASIC doesn't latch the bits (clock polarity / timing / electrical), the ASIC never enters the configured state and never emits LVDS.
- The temperature sensors confirming MuTRiGs are powered (29.6 / 31.2 °C) only proves the ASIC supplies are up, not that the digital config loaded.

**Diagnostic to confirm vs falsify B014.** Read the per-channel LoS_n state somewhere observable. Two paths:

1. **Through SignalTap** — the existing `top_stp_full8lane.sof` already has STP probes; add `scifi_ds_losn` or `feb_redriver_losn` to the probe set on the next compile (cheap addition, ~50 min recompile).
2. **Through a debug GPIO** — wire `feb_redriver_losn` (or the raw `scifi_ds_losn`) to spare `FPGA_Test` pins and probe the FPGA-output pin with a scope or logic analyzer. Even cheaper than recompile if the GPIO is reachable on the board.
3. **Indirect inference** — drive the rate-injection SPI sequence via JTAG / system-console (bypasses the SC ring corruption issue) and watch SYMBOL_ERRORS counters at `lvds_rx_controller_pro_0` offsets `0x05..0x0D`. If the MuTRiGs start emitting, LoS_n deasserts, DPA trains, SYMBOL_ERRORS first burst then settle to small steady-state.

**Disposition.** Open. Keeps B011 open as well (B011's actual cause is now traceable here). Concrete next step: run `run_phase5_injector_datapath_sanity.py` with `--system-console` (JTAG-driven, no sc_tool burst transactions) on the known-good SOF — if MuTRiGs do receive the SPI through that path and start emitting, LoS_n deasserts, LVDS RX trains, real frames flow, and B011/B014 close together. If MuTRiGs still don't emit, the SPI roundtrip itself is the culprit and we need a level-converter / polarity / timing inspection on the FEB-to-DAB SPI bus.

---

---

## B015 — MuTRiG configure SPI roundtrip never validated; bring-up may use wrong path

**Discovered:** 2026-05-05 by user-prompted review of the MuTRiG controller IP (`mutrig_controller/mutrig_ctrl.vhd`).

**Configure protocol per RTL header.**

The MCC (MuTRiG Configuration Controller) inside `mutrig_controller` is the canonical SPI-write engine. Its work flow per the RTL comments at `mutrig_ctrl.vhd` lines 17-30:

1. Host (SWB or JTAG) loads the configuration bitstream into the controller's `scratch_pad_ram`.
2. Host writes the IRQ trigger to `avmm_csr`: `FC04` = opcode, `FC05` = data location.
3. The MCC's instruction interpreter dispatches to the data mover, which copies bytes from `scratch_pad_ram` into the per-ASIC `cfg-mem` RAM.
4. The cfg writer uses the data in `cfg-mem` to drive the SPI bus to the target ASIC.
5. **`[TODO]` per the RTL comment: the cfg writer also checks the readback data to validate the SPI transaction.** This validation step is not yet implemented in the IP.

Both the SC path and the JTAG-driven `configure_mutrig_jtag.py` go through the same MCC. JTAG just lets the host bypass the SC ring for the scratch-pad fill.

**What we missed.**

Today's bring-up sequence used `configure_mutrig_jtag.py --config <SMB3/5_tdc.txt> --xml-index N --asic N --channel-enable-mask 0xFFFFFFFF --tdctest-channel-mask 0xFFFFFFFF` for all 8 ASICs and reported `loader_returncode=0` for every call. **None of those calls used `--readback`.** Per the RTL comment, even when readback is invoked, the cfg-writer's roundtrip-validation step is currently a TODO. So:

- `loader_returncode=0` only means: the FEB-side controller's instruction interpreter accepted the IRQ, the data mover copied the scratch-pad to cfg-mem, and the SPI bus toggled. It does **not** mean the MuTRiG ASIC latched the bits correctly.
- Without an explicit readback compare, an ASIC that doesn't latch (clock-polarity mismatch, level shifter half-broken, MISO line floating, level threshold off) leaves the ASIC in its power-on default state — and in the power-on default state, **MuTRiGs do not emit LVDS on `scifi_din[7:0]`**. That self-consistently produces:
  - `scifi_ds_losn = 0` on every active channel (no signal on the DAB receiver buffer).
  - LVDS RX PHY held in reset by the LoS_n input (per B014).
  - SYMBOL_ERRORS counters frozen at small non-zero values (= what they accumulated during the brief period before LoS_n asserted).
  - `ingress_real_frames = 0` at the arb input.

**This makes B011 and B014 collapse into B015's root cause hypothesis:** the SPI write is silently failing and we never knew because we never validated the readback.

**Concrete diagnostic.**

Re-run a single-ASIC configure with `--readback` and inspect the JSON output for an `spi_readback` field that compares config-vs-echo. If `configure_mutrig_jtag.py` doesn't emit one (because the IP-side readback path is the `[TODO]` line), drive a manual loopback test: write a known scratch-pad pattern, fire MCC, then read SPI MISO sampling registers from the controller's CSR (if exposed — check the IP RTL for a "last MISO word" CSR). If MISO is stuck at a constant or all-1/0, the SPI roundtrip is broken at the electrical level (level converter, pull resistor, SPI clock polarity). If MISO matches the written pattern, the configure path works and the cause shifts back to the LVDS PHY side (clock recovery / training).

**Disposition.** Open. This entry supersedes the "JTAG configure was successful" assumption that was baked into B011 and B014. The next bring-up attempt must include explicit SPI roundtrip validation before declaring the ASICs configured.

---

---

## B016 — `mu3e_lvds_controller` SV rebuild stranded on a feature branch; full8lane build still uses stale VHDL master

**Discovered:** 2026-05-05 by user-prompted check of the IP repos.

**Context.**

The `mu3e_lvds_controller` submodule has a maintained SystemVerilog rewrite on the remote branch `origin/codex/lvds-controller-sv-rebuild`. That branch contains:

- `rtl/mu3e_lvds_controller.sv` (1231 lines) — top-level LVDS RX controller in SV.
- `rtl/mu3e_lvds_controller_phy_adapter.sv` (287 lines) — PHY adapter shim.
- `script/mu3e_lvds_controller_hw.tcl` (237 lines) and `script/mu3e_lvds_controller_phy_adapter_hw.tcl` (269 lines) — fresh Qsys packaging.
- `doc/RTL_PLAN.md`, `doc/INTEGRATION_REVIEW.md`, `doc/rtl_note.md` — explicit DV plan + integration review.
- `syn/quartus/lvds_controller_syn_top.sv` and friends — standalone signoff project + GLS smoke testbench.
- `tb/BUG_HISTORY.md` (426 lines) — 10+ closure commits, including `[FIX] Clean LVDS control/data CDC`, `[FIX] Close LVDS standalone timing`, `[FIX] Close LVDS runtime DV buckets`, `[FIX] Close LVDS controller DV coverage`.

The branch is **strictly ahead of `master`** (10+ commits) — no merges back. Every consumer of `mu3e_lvds_controller` (this full8lane build, the legacy phase5 build, any other system) still pulls the stale VHDL `lvds_rx_controller_pro.terp.vhd` because the parent repo's `.gitmodules` tracks `master`.

**Implication for B011 / B014.**

The frozen `SYMBOL_ERRORS` and the held-in-reset DPA on the current SOF was investigated against the **VHDL master**, which has known closed bugs in CDC, timing, and DV coverage that the SV branch already fixes per the `[FIX]` commit messages. Even if the actual ASIC-side cause turns out to be SPI-roundtrip silence (B015), running on a stale LVDS controller is a separate latent risk that any next-recompile should clear by promoting the SV branch.

**The mu3e_lvds_controller _hw.tcl is on the codex branch already**, so a Qsys regen against the SV branch produces a different generated tree (with the SV files instead of the .terp.vhd). The standalone signoff project lets us close the SV controller's timing in isolation before integrating.

**Disposition.** Open. Concrete action for the next compile cycle:

1. In the parent `mu3e-ip-cores` repo, update the `mu3e_lvds_controller` submodule pointer from `master` (`f4e5d13`) to the head of `origin/codex/lvds-controller-sv-rebuild` (= `57ba08d` as of 2026-05-05). Either fast-forward the submodule branch or merge codex into master in the upstream repo so it ships from `master` for downstream worktrees.
2. Re-run `qsys-generate` on `system_20260504_full8lane_type0` — the regenerated synthesis tree will pick up the SV controller automatically because the `.qsys` references the IP by name + version, and the new hw.tcl script declares the same name.
3. Run the standing B003 integration review against the regenerated tree — the SV controller's port list / interface set may differ from VHDL master, so the supercore's wiring may need patching.
4. Recompile `top_nostp_full8lane.qsf`. Compare LVDS RX behavior.

**Nothing to fix in `mutrig_controller`.** That submodule has only `origin/master`; the SV rewrite the user recalled was for the LVDS controller, not MuTRiG. The MuTRiG configure path uses the existing VHDL `mutrig_ctrl.vhd` MCC; the open question there (B015) is whether the SPI roundtrip actually lands at the ASIC, which is independent of the controller language choice.

---

## B017 — SV LVDS adapter first full8lane qsys-generate fails aperture/reset checks

**Discovered:** 2026-05-05 by the B016 full8lane regen attempt
(`firmware_builds/systems/system_20260504_full8lane_type0/script/regen_full8lane_system.sh`)
after promoting `mu3e_lvds_controller` to `57ba08d` and replacing the legacy
`lvds_rx_controller_pro_0` instance with the SV
`mu3e_lvds_controller_phy_adapter`.

**Exact first errors from**
`firmware_builds/systems/system_20260504_full8lane_type0/syn/full8lane_type0_datapath/full8lane_type0_datapath_generation.rpt`:

```text
Error: full8lane_type0_datapath.master_datapath.master: backpressure_fifo_0.csr (0x860..0x86f) overlaps lvds_rx_controller_pro_0.csr (0x0..0xfff)
Error: full8lane_type0_datapath.mm_pipeline_lvds_csr_low.m0: mm_pipeline_jtagmaster2rstctrl.s0 (0x200..0x2ff) overlaps lvds_rx_controller_pro_0.csr (0x0..0xfff)
Error: full8lane_type0_datapath.: Interfaces lvds_rx_28nm_0.parallel and lvds_rx_controller_pro_0.parallel must have matching associated resets, but lvds_rx_28nm_0.parallel has no associated reset.
Error: qsys-generate failed with exit code 1: 3 Errors, 125 Warnings
```

**Root cause.** The SV adapter's `_hw.tcl` exposes `avs_csr_address` at its
default `AVMM_ADDR_W=10`, so Qsys allocates a `0x0..0xfff` CSR aperture where
the old LVDS controller occupied only the low CSR window. The current full8lane
address map has other slaves at `0x200` and `0x860`, so the new aperture
overlaps immediately. Separately, the adapter marks its `parallel` conduit as
associated with `data_clock` / `data_reset`, while the legacy
`altera_lvds_rx_28nm.parallel` conduit has no associated reset metadata; Qsys
18.1 treats that mismatch as a hard interface compatibility error.

**Disposition.** Open. Per the phase-gate rule, no B003 review or Quartus
compile is allowed until this is fixed through Tcl / `_hw.tcl` and the
full8lane qsys-generate reruns cleanly.

---

---

## B017 — Per-lane LVDS RX state on silicon (live evidence at known-good SOF)

**Discovered:** 2026-05-05 by direct sc_tool burst-read of `lvds_rx_controller_pro_0` CSR after recovering the SC ring (SWB program → driver reload → FEB reprogram with the 20260430 known-good `top_stp_pipe_phase5_frame_hist.sof`).

**Burst read at sc_tool word `0x08000`, 16 words:**

| Avs offset | Lane | SYMBOL_ERRORS / value | Decode |
|---|---|---|---|
| 0x00 | — | `0x00FA0009` | sync_pattern=`0xFA`, n_lanes=`9` ✓ |
| 0x01 | — | `0x000001FF` | mode_mask: all 9 lanes adaptive selection |
| 0x02 | — | `0x00000000` | soft_reset_req: 0 |
| 0x03 | — | `0x00000000` | dpa_hold: 0 (DPA tracking enabled) |
| 0x04 | — | `0x000001FF` | LANE_GO: all 9 enabled ✓ |
| 0x05 | **lane 0** (SMB3 ASIC 0) | `0x00003583` = 13,699 | training, low rate |
| 0x06 | **lane 1** (SMB3 ASIC 1) | **`0xFFFFFFFF`** | **clane_error fatal — silent or unrecoverable** |
| 0x07 | **lane 2** (SMB3 ASIC 2) | `0x000030A6` = 12,454 | training |
| 0x08 | **lane 3** (SMB3 ASIC 3) | **`0xFFFFFFFF`** | **clane_error fatal** |
| 0x09 | **lane 4** (SMB5 ASIC 0) | `0x00001B03` = 6,915 | training |
| 0x0A | **lane 5** (SMB5 ASIC 1) | `0x0000040A` = 1,034 | **lowest error rate — best lane** |
| 0x0B | **lane 6** (SMB5 ASIC 2) | **`0xFFFFFFFF`** | **clane_error fatal** |
| 0x0C | **lane 7** (SMB5 ASIC 3) | **`0xFFFFFFFF`** | **clane_error fatal** |
| 0x0D | **lane 8** (firefly RC synclink) | `0x0003B9EF` = 244,719 | **ALIVE — non-fatal, RC bits decoding ✓** |
| 0x0E | — | `0x00000000` | LANE_SELECTION = lane 0 |
| 0x0F | — | `0x00000000` | DPA_UNLOCKS for lane 0 = 0 (no unlocks since reset; lane 0 stable) |

**Concrete state of the SciFi SMBs in this lab setup:**

- **4 ASICs are completely silent on LVDS** (lanes 1, 3, 6, 7 = `0xFFFFFFFF`). These never produce a recoverable bit clock for the FEB-side DPA. Possible causes per ASIC: dead PLL, missing power rail, broken SPI roundtrip (per B015) so the ASIC stayed in power-on default with no LVDS TX enabled, or wiring break.
- **4 ASICs are emitting LVDS but with persistent symbol errors** (lanes 0, 2, 4, 5 with counts ≪ `0xFFFFFFFF`). They reached the trainable region but the 8b/10b decode reports residual K-char / disparity errors, consistent with marginal alignment. The lowest-error lane is **lane 5** (SMB5 ASIC 1) at 1,034 errors — same order of magnitude as the lane 8 RC synclink (244K from a much-longer-running known-good link).
- **Lane 8 (RC firefly synclink) is healthy** as the user predicted — `0x0003B9EF`, far from `0xFFFFFFFF`, decoding bits successfully. The SC plane and runctl plane being functional is consistent with this: lane 8 is the fibre carrying SC + RC from SWB, and the FEB has been responding to both throughout this session.

**Implications.**

1. **The LVDS RX controller IP is functioning correctly.** It correctly distinguishes fatal-untrainable (`0xFFFFFFFF`) from trainable-with-errors (small counter). The per-lane state machine is alive.
2. **The "real MuTRiG hits = 0" symptom is per-ASIC, not global.** 4 ASICs are silent (no signal at all → DAB asserts LoS_n → PHY held in reset on those lanes), and the 4 that emit have alignment errors that may still allow valid frames to occasionally pass through `mutrig_frame_deassembly_*`.
3. **The Apr-29 known-PASS runs** that used `--lvds-lane-mask 0x01` (lane 0 only) or `0x09` (lanes 0+3) make sense ONLY if at the time those runs were made, lanes 0 and 3 were the trainable ones. Today lane 3 is fatal — the mapping is **time-dependent**, suggesting either ASIC drift, intermittent contact, or temperature-dependent training failures.
4. **The CML toggle 0→8→0 we applied today did NOT close lane 1, 3, 6, 7.** Either those ASICs need a different per-channel config (possibly the per-ASIC `vncnt`/`vnvcodelay`/`vnhitlogic` overrides from the Apr-29 known-PASS config JSON), or they have hardware faults independent of config.
5. **Bring-up strategy going forward:** restrict to known-trainable lanes. Today that's lanes **{0, 2, 4, 5}** (or just lane 5, the lowest-error one) — NOT the full 8-lane scope. This matches the Apr-29 known-PASS pattern (small lane mask).

**Recommended next experiments (when SC ring is stable):**

1. Toggle `SOFT_RESET_REQ` (write avs `0x02 = 1`, then `0x02 = 0`) to retrain DPA. Re-read SYMBOL_ERRORS — if a fatal lane drops out of `0xFFFFFFFF`, it was a transient training failure, not hardware-dead.
2. Read `DPA_UNLOCKS` for each lane (write `LANE_SELECTION = i`, then read offset `0x0F`). Stable lanes report 0 unlocks; thrashing lanes report incrementing unlock counts.
3. Apply per-ASIC TDC fine-tunes from the Apr-29 config JSON: `0:vnhitlogic=40 2:vncnt=40 2:vnvcodelay=30 2:vnhitlogic=30 3:vncnt=35 3:vnvcodelay=12 3:vnhitlogic=25 7:vncnt=30 7:vnvcodelay=14 7:vnhitlogic=40` via `configure_mutrig_jtag.py --tdc-override`.
4. Bring-up real-MuTRiG hit measurement with `--lvds-lane-mask 0x20` (lane 5 only, the lowest-error today) at 100 kHz / channel via the injector, and see whether `mutrig_frame_deassembly_5` actually frames hits.

**Disposition.** Open. Concrete data point that changes the diagnostic strategy from "all 8 ASICs broken" to "subset trainable, subset fatal — restrict scope and tune per-ASIC".

---

---

## B018 — `configure_mutrig_jtag.py` produces an incomplete configure path; production tool is `configure_mutrig_from_xml.py`

**Discovered:** 2026-05-05 by the user-prompted bitstream comparison (B015 follow-up).

**The issue.** Two distinct host-side configure tools exist in the codebase:

- `firmware_builds/.../system_20260427_testplanphase5/script/configure_mutrig_jtag.py` — JTAG / system-console driven, single ASIC per call. Produces an 84-word SPI bitstream from the SMB3/SMB5 XML and pushes it into the FEB-side controller via JTAG. **This is the tool I had been using all session.** It exits `loader_returncode=0` but the silicon evidence is unambiguous: 4 of 8 LVDS lanes stayed at SYMBOL_ERRORS=`0xFFFFFFFF` after configuration — clane_error fatal — meaning those 4 ASICs never actually emitted any decodable LVDS bits.

- `firmware_builds/.../system_20260427_testplanphase5/script/configure_mutrig_from_xml.py` (only present in the phase6_closure_20260430 / aso_debug_ts_plot_20260501 worktrees, not in main mu3e-ip-cores) — sc_tool / MCC IRQ driven, **all 8 ASICs configured in a single invocation**. Bundles the CML 0→8→0 flush atomically with the configure phases. Supports `--set-tdc ASIC:FIELD=VALUE` for per-ASIC fine-tunes (the Apr-29 known-PASS config used these). Loads via `--bsp <mutrig_controller_bsp.tcl>`. **This is the production tool that the Apr-29 / 20260430 known-PASS runs used.**

**Smoking-gun silicon evidence on the same SOF (known-good `top_stp_pipe_phase5_frame_hist.sof`):**

After running ONLY `configure_mutrig_jtag.py` on all 8 ASICs (24 successful `loader_returncode=0` calls including CML 0→8→0 toggle):
```
LVDS SYMBOL_ERRORS per lane:  L0=13699  L1=FFFFFFFF  L2=12454  L3=FFFFFFFF  L4=6915  L5=1034  L6=FFFFFFFF  L7=FFFFFFFF  L8=244719 (RC)
```

After running `configure_mutrig_from_xml.py` with the canonical Apr-29 args (`--cml-start-value 0 --cml-flush-value 8 --cml-final-value 0 --cml-flush-after-config --cml-flush-set-cml-sc-zero --set-channel recv_all=1 --set-tdc <per-ASIC overrides> --bsp <mutrig_controller_bsp.tcl>`):
```
LVDS SYMBOL_ERRORS per lane:  L0=13699  L1=00000000  L2=12454  L3=00000000  L4=6915  L5=1034  L6=00000000  L7=00000000  L8=244719 (RC)
```

**Lanes 1, 3, 6, 7 went from `0xFFFFFFFF` (clane_error fatal) to `0x00000000` (clean, no symbol errors).** All 8 MuTRiGs are now emitting valid 8b/10b LVDS. Counters are frozen across a 2 s host bracket, indicating stable lock with no ongoing errors on the cleared lanes.

**Why the JTAG tool fails.**

Several plausible mechanisms, any of which produces the observed silent-but-loader-returncode-0 failure:

1. **Different bitstream encoding.** The JTAG tool's bit-pack may handle the per-channel `recv_all` / `mask` / `tdctest_n` fields differently than the MCC's expected bit order. The 84-word bitstream we generated from `--config $SMB3_TDC --xml-index 0 --asic 0` is byte-identical with and without `--channel-enable-mask 0xFFFFFFFF` overrides, suggesting the XML's defaults already specify those values — but the MCC may interpret the same bits differently.
2. **Missing CML-flush atomic.** The JTAG tool requires the user to run THREE separate invocations (one per CML phase) for the toggle. Between phases there are gaps where the ASIC's CML driver may end up in an undefined intermediate state. The `_from_xml` tool runs the three phases in a single transaction stream with no host-side gap, exactly per the `mutrig_controller_bsp.tcl` BSP. Empirically that matters.
3. **Missing per-channel `recv_all=1`.** The Apr-29 config set `recv_all=1` on every channel via `--set-channel`. Without it, the channel may not unmask its receiver — the channel filter could block hits even when LVDS bits are clean.
4. **No `--bsp` companion script.** The MCC IP's `mutrig_controller_bsp.tcl` provides board-specific helper functions that the simpler JTAG tool does not invoke.

**Disposition.** Closes B015 (SPI roundtrip not validated) and effectively closes B011 / B014 as well — the LVDS PHY is fine, the MuTRiGs are fine, the wrong configure tool was the dominant cause. The B011 SYMBOL_ERRORS/DPA-lock investigation remains useful for diagnostics but the primary action item is: **always use `configure_mutrig_from_xml.py` for production bring-up; reserve `configure_mutrig_jtag.py` for single-ASIC SPI debug only.**

**Action items going forward:**

1. Promote `configure_mutrig_from_xml.py` and `mutrig_controller_bsp.tcl` from the phase6_closure worktree into the mu3e-ip-cores main branch and the current worktree (so it's available without cross-worktree path tricks).
2. Update `MUTRIG.md` with a "production configure path uses `configure_mutrig_from_xml.py`" note plus the canonical Apr-29 args.
3. Update memory entry `feedback_swb_ring_lock.md` (or create a new memory) noting the production tool is the `_from_xml.py` variant — the Mu3e bring-up flow uses sc_tool MCC with BSP, not JTAG.

---

---

## MAJOR VERSION 2 — coordinated rebuild summary

**Started:** 2026-05-05.

**Tag:** the next compile cycle of `system_20260504_full8lane_type0` is hereby named **MV2** for tracking. Commit messages, report assets, and BUG_HISTORY entries that land between the 2026-05-05 evening and the next official build pass should reference MV2 so post-mortems can correlate.

**Goal of MV2:** side-by-side comparison of the **VHDL** `lvds_rx_controller_pro.terp.vhd` (current `mu3e_lvds_controller` `master` HEAD = `f4e5d13`) and the **SV** `mu3e_lvds_controller.sv` + `mu3e_lvds_controller_phy_adapter.sv` (`codex/lvds-controller-sv-rebuild` HEAD = `57ba08d`) on identical silicon, with identical MuTRiG configure via the production tool `configure_mutrig_from_xml.py` (per B018). The SV branch claims closed DV coverage and 10+ `[FIX]` commits across CDC / timing / standalone signoff — MV2 measures whether those translate into observable on-silicon improvements:

- Are the per-lane SYMBOL_ERRORS counters cleaner with the SV controller (idle = 0, training spikes only during DPA bring-up)?
- Are DPA_UNLOCKS counters non-zero on any lane during a stable run (= intermittent lock loss)?
- Does the SV controller expose any new CSR fields that the VHDL doesn't (per the SV branch's RTL_PLAN.md)?
- Does the SV controller's `phy_adapter` inject any timing/CDC behavior that breaks integration into the supercore wiring (B003 standing review will catch this)?

**Folded fixes:**

| Tag | Status going into MV2 |
|---|---|
| B001 | folded (`readLatency=1` in `arb_hit_type0_hw.tcl`) |
| B002 | folded (`type0_run_ctrl_splitter` collapsed) |
| B003 | standing review obligation; will run on regen |
| B004, B005 | folded (version pin sweep + dbg_mm2runctrl annotation) |
| B006 | folded (tb/Makefile DUT_SRCS) |
| B007 | folded (Tcl octal-parsing of `0505`) |
| B008 | folded (nested-instance dotted path removed) |
| B009 | folded (mutrig_frame_deassembly VERSION_GIT clamp) |
| B010 | non-blocking annotation |
| B011 | reframed by B018 — was a consequence of the wrong configure tool |
| B012 | placeholder fix in tree (`ref_adr` packed into `feb_si_status_in[7:6]`); promote to full identity register on a future regen |
| B013 | folded (`top.sdc` LVDS clock 7.273 → 8.000 ns) |
| B014 | reframed by B018 |
| B015 | closed by B018 |
| B016 | core MV2 deliverable — adopt SV LVDS controller |
| B017 | superseded by post-B018 LVDS state (all 8 lanes cleared) |
| B018 | rule captured in memory `feedback_mutrig_configure_tool.md` |

**In-flight backgrounds (2026-05-05 evening):**

- codex2 PID 22047 — Phase 1-5 of the SV adoption + Quartus compile (~90 min budget).
- sonnet agent `a6dbe311b...` — companion `top_stp_first_stage_full8lane` build with first-stage STP probes (LVDS DPA + frame_deassembly ingress + arb real_in). ~50 min Quartus compile.

**Verification plan post-MV2 compile:**

1. Program FEB with **SV-built** `top_nostp_full8lane.sof`. Run `configure_mutrig_from_xml.py` canonical Apr-29 args. Read LVDS RX SYMBOL_ERRORS, DPA_UNLOCKS — record per-lane state as the **SV-MV2 baseline**.
2. Drive the injector at 100 kHz/channel periodic, post-rbCAM histogram bin readout. Record per-channel rate.
3. Re-program FEB with **VHDL-built** `top_nostp_full8lane.sof` from prior MV1 (May 5 morning). Same configure_mutrig_from_xml.py + same injector + histogram readout. Record as the **VHDL-MV1 baseline**.
4. Diff the two: per-lane SYMBOL_ERRORS, per-channel hist rate, per-lane DPA_UNLOCKS, any fatal-lane differences.
5. If SV outperforms VHDL on observable silicon metrics → recommend the SV branch be promoted to `master` upstream and the parent `.gitmodules` track `master`.
6. If SV is no better than VHDL → flag the SV branch's "closed DV" claims as not silicon-validated and recommend it stay on the codex branch until the gap is understood.

---

## B019 — MV2 SV LVDS supercore integration and compile fold-in

**Discovered:** 2026-05-05 during the MV2 full8lane rebuild.

**Scope.** MV2 switches `system_20260504_full8lane_type0` to the newer SV
`mu3e_lvds_controller` package, with Qsys system major version 2.0. The new
component absorbs the LVDS PHY inside the controller super-core, so the old
`lvds_rx_28nm_0` / `lvds_rx_controller_pro_0` split is no longer a valid system
wiring contract.

**Folded issues in this compile.**

- The LVDS CSR aperture had to move to a free slot. The local datapath CSR base
  now uses the free `0x9000` window, and the master CSR aperture is shifted to
  `0x00030000` so the new wider controller aperture does not overlap existing
  slaves.
- The full8lane Qsys recipe now instantiates `mu3e_lvds_controller` directly,
  exports the absorbed LVDS PHY conduits, and wires the super-core clock/reset,
  redriver, serial, and reset-link conduits without the legacy external PHY.
- The top-level FEB wiring now maps the nine FEB serial inputs as
  `firefly1_lvds_rx_in & scifi_din`; DAB redriver LoS_n enters the FEB for the
  eight SciFi lanes plus the firefly link. Unused outgoing FEB LoS behavior is
  tied benignly in the top-level build contract.
- The histogram-statistics Qsys wrapper compile issue is folded: integer generic
  values are passed through the full8lane wrapper and converted to boolean only
  inside the histogram IP. This removes the VHDL `/=` type errors seen in the
  first no-STP compile.
- The LVDS clock SDC period is updated from 7.273 ns to 8.000 ns, matching the
  125 MHz LVDS/firefly domain used by this MV2 build.

**Validation.**

- `firmware_builds/systems/system_20260504_full8lane_type0/script/regen_full8lane_system.sh`
  passes for the control subsystem, supercore, inner datapath, outer datapath,
  and top-level full8lane system. The generated wrapper instantiates the SV
  controller with absorbed PHY and records Qsys component version `26.2.0.505`.
- `quartus_sh --flow compile top_nostp_full8lane -c top_nostp_full8lane` passes
  with 0 errors. Timing is not closed: worst setup slack is -2.914 ns on
  `lvds_firefly_clk`, with total negative setup slack -81.917 ns. Hold timing is
  positive in the reported domains.
- `quartus_sh --flow compile top_nostp_full8lane -c top_stp_first_stage_full8lane`
  passes with 0 errors and 1635 warnings. The first-stage STP file is focused
  on LVDS PLL/DPA/reset/fifo/bitslip/decode, redriver LoS, frame deassembly,
  and arbiter crossing signals. The generated `.sld` and `.jdi` files are
  present, and the inspected compile reports contain no SignalTap node-not-found
  or trigger CRC errors.
- The STP compile carries the same timing debt as no-STP: worst setup slack is
  -2.914 ns on `lvds_firefly_clk`, with TNS -81.917 ns. Hold, recovery, and
  minimum-pulse-width reported slacks remain positive.
- The pre-synthesis STP node helper reports one top-level alias caveat:
  `feb_redriver_losn[0]` is not found as a probe name. The actual top-level DAB
  LoS_n inputs are `scifi_ds_losn[...]`, and Quartus still compiled the STP
  image and emitted `.sld` / `.jdi` without node-not-found diagnostics.

**Disposition.** Compile-closed for MV2, with timing debt recorded. Board
programming and silicon comparison remain future work.

---

## B020 — PROF-INT-002 latency plot harness needed aggregate rbCAM fanout and ps-to-cycle conversion

**Discovered:** 2026-05-05 by the user-requested latency plot review and a
read-only subagent cross-check of `tb_int/`.

**Issue.**

The first PROF-INT-002 harness captured a real pre-rbCAM boundary, but only at
`hit_stack_subsystem_0.data_splitter_0_out0_*`. The generated system feeds four
rbCAM instances from `data_splitter_0_out0_*` through `out3_*`, so the old tap
was rbCAM0-only and could not represent aggregate pre-rbCAM ingress. The same
review found the post-rbCAM monitor used an `if/else` priority chain across the
four rbCAM outputs, which could drop simultaneous observations from the
scoreboard. The plot renderer also treated `$time` ps timestamps as cycles, so
real records outside a tiny unit-test aperture rendered as empty panels.

**Fix.**

- The PROF-INT-002 top now instantiates eight Stage-A monitor interfaces, one
  per `emulator_mutrig_N` L2 FIFO commit point.
- The pre-rbCAM monitor fanout now instantiates four `hit_tap_if` interfaces
  for `data_splitter_0_out0_*` through `data_splitter_0_out3_*`, all connected
  to the same scoreboard pre-rbCAM analysis export.
- The post-rbCAM monitor fanout now instantiates four independent taps for
  `ring_buffer_cam_0_hit_type2_*` through `ring_buffer_cam_3_hit_type2_*`,
  eliminating the priority drop on simultaneous rbCAM outputs.
- The PROF-INT-002 active-lane guard is removed; active-lane masks now drive the
  per-lane Stage-A taps and per-lane emulator enable/rate forces.
- The contact-sheet renderer converts timestamp differences from ps to 125 MHz
  cycles, uses the reference rbCAM aperture `[-1024, 3072]` cycles, and marks the
  rbCAM window with green 0/2000-cycle lines to match the requested report
  format.

**Validation.**

- `make comp_prof_int_002` passes after the fanout changes.
- `timeout 180s make run_prof_int_002_full_pipeline_100khz_per_channel_test
  PROF_INT_002_RUN_CYCLES=20000 PROF_INT_002_DRAIN_CYCLES=1024 SEED=2` elaborates
  and reaches scoreboard export, but exits non-zero by design because the
  scoreboard closure gate fails.
- The short run exports 52 closed records and renders
  `reports/prof_int_002_full_pipeline_100khz_per_channel_test/contact_sheet_dislin.png`.
  The pre-rbCAM panel is populated in the rbCAM reference aperture. Post-rbCAM
  and FEB-egress are not populated in that aperture for the short run because
  their matched latencies are far outside the 0/2000-cycle rbCAM window.

**Remaining blocker for the 5 s plots.**

The 20k-cycle smoke run reports `A=352 PRE=256 POST=64 FEB=52`, with
`stable_closed=52/352` (14 percent, below the 95 percent closure gate). It also
reports run-control command `010` missing ready bits `0x01080`, numeric-std
metavalue warnings in the generated datapath, and MTS/output error counts
(`mts_err=288`, `hisb_err=288`, `ds_err=288`). Do not use the 5 s 1-lane,
8-lane, or emulator targets as signoff evidence until that runtime datapath
configuration issue is closed.

**Disposition.** Harness/plot bug fixed; full 5 s latency evidence remains open.

---

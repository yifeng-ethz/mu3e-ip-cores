# Run Sequence Upgrade Plan

## Scope

This plan covers the run-control termination contract across:

- `mutrig_frame_deassembly/frame_rcv_ip.vhd`
- `mutrig_timestamp_processor/mts_processor.vhd`
- `ring-buffer_cam/ring_buffer_cam_v2_core.vhd`
- `feb_frame_assembly/feb_frame_assembly.vhd`
- `emulator_mutrig/rtl/emulator_mutrig.sv` as a timing-model alignment item

The intended boundary contract is now:

- `frame_rcv_ip` closes each MuTRiG packet normally and does not fabricate new hits at run end
- `mts_processor` generates one per-run SOP and one per-run EOP per interleaving lane
- `ring_buffer_cam` treats the incoming EOP as a lane-local terminal marker, masks that lane once seen, and acknowledges `TERMINATING` only after every active lane has seen EOP and the local buffers are empty
- `feb_frame_assembly` keeps draining active lanes, does not emit a fragmented end marker inside the frame body, and marks the trailer of the final frame as the frame-level EOP
- downstream OPG/OPQ does not need a separate explicit run-end sideband if it already uses frame/trailer structure plus a bounded quiescent-grace rule

The immediate failing boundary in `packet_scheduler/tb_int` is `A -> H0`:

- `A`: MuTRiG emulator hit commit into the internal FIFO
- `H0`: `frame_rcv_ip` hit_type0 output into `mts_processor`

## Status Update: 2026-04-15

The run-sequence issue described below is no longer the primary `A -> H0`
blocker in the current RTL.

After the recent upgrades:

- `emulator_mutrig` no longer starts fresh frames in `TERMINATING`
- `frame_rcv_ip` and `mts_processor` now have explicit terminating-marker logic

The remaining dominant `A -> H0` loss is inside the emulator datapath itself:

- `emulator_mutrig/rtl/frame_assembler.sv` emits the last hit of each frame but
  does not pop that last hit from the `hit_generator` FIFO
- the carried tail then becomes the first hit of the next frame
- at end-of-run, when no next frame is allowed to start, the remaining FIFO tail
  is stranded and never reaches `H0`

This is consistent with the current `tb_int` symptom:

- stage `A` sees committed hits into the emulator FIFO
- stage `H0` misses a late-run cluster of hits
- the missing window is concentrated near the last frame interval before stop

So:

- the termination-contract work below is still worth keeping as an upgrade plan
- but the first functional root cause to fix for the current `A -> H0` failure
  is the emulator frame pop contract, not the downstream run-sequence contract

## Current Root Cause

The failing root cause is a termination-contract mismatch, not just a weak scoreboard key.

This section reflects the earlier diagnosis before the emulator-side tail-pop
bug was isolated. Keep it as design background, but do not treat it as the
current primary blocker.

## Current Primary Root Cause

### 1. `frame_assembler` does not consume the last event of a frame

Current behavior in `emulator_mutrig/rtl/frame_assembler.sv`:

- At frame start, `evt_cnt_latch` is loaded from `event_count`
- The first FIFO pop is only requested when `evt_cnt_latch > 1`
- During payload emission, each subsequent FIFO pop is only requested when
  `evt_remaining > 1`
- Therefore, the final event of the frame is transmitted but never popped from
  the FIFO

Relevant code points:

- `frame_assembler.sv:226-255`
- `frame_assembler.sv:271-287`
- `frame_assembler.sv:290-317`
- `frame_assembler.sv:326-340`

Implication:

- Every frame leaves one residual hit behind in the generator FIFO
- That residual hit is carried into the next frame
- The top-level frame parser still sees a self-consistent frame, so standalone
  emulator frame-format checks do not necessarily fail
- But end-to-end hit conservation from emulator commit (`A`) to parser output
  (`H0`) is broken

### 2. End-of-run tail loss is then guaranteed once fresh frame starts stop

Current behavior:

- `emulator_mutrig` now correctly blocks fresh `frame_start` in `TERMINATING`
- Any hits committed after the final `RUNNING` frame start, plus the one
  carried residual hit, remain buffered

Implication:

- The final FIFO tail never gets a new frame boundary
- Those hits are counted at `A`
- They never appear at `H0`

This matches the observed late-run miss cluster much better than the earlier
"post-terminate fresh frame" theory.

### 3. There is still a secondary metadata hazard on `event_count`

Current behavior:

- `hit_generator.sv` updates `event_count` on the same `frame_start` edge
  that `frame_assembler.sv` consumes it
- Both are `always_ff`, so `frame_assembler` sees the previous value

Relevant code points:

- `hit_generator.sv:112-118`
- `frame_assembler.sv:175-178`

Implication:

- The count visible to the frame assembler is one-frame stale relative to the
  same-cycle FIFO snapshot
- This is a real cleanup item, and it may explain empty/underfilled start-up
  frames, but it is not required to explain the current late-run `A -> H0`
  deficit once the unpopped last-hit bug is considered

### 4. The new synthetic terminating EOP in `frame_rcv_ip` currently violates the hit contract

Current behavior:

- `frame_rcv_ip` can assert `aso_hit_type0_endofpacket` without a valid
  `hit_type0` beat during termination

Implication:

- This triggers the `tb_int_hit0_contract_sva`
- It also creates a downstream ghost boundary into `mts_processor`

This is important, but it is not the dominant `A -> H0` count-loss root cause.

### 1. `emulator_mutrig` can still start new frames in `TERMINATING`

Current behavior:

- `ctrl_state_q[3]` enables new hit commits only in `RUNNING`
- `ctrl_state_q[3] | ctrl_state_q[4]` keeps the drain path alive in `RUNNING` and `TERMINATING`
- `frame_assembler` continues to emit `frame_start` pulses while the drain path is alive

Implication:

- Hits already committed before the `TERMINATING` edge can be packed into a frame that starts after the run state has already changed to `TERMINATING`.

### 2. `frame_rcv_ip` drops the ability to start a new frame immediately in `TERMINATING`

Current behavior:

- `run_control_mgmt_agent` drives `receiver_go <= '0'` in `TERMINATING`
- `proc_enable_ctrl` therefore drives `enable <= '0'`
- `proc_frame_rcv_comb` only leaves `FS_IDLE` when:
  - `enable = '1'`
  - `i_byteisk = '1'`
  - `i_data = c_header`

Implication:

- If the first byte of a new MuTRiG frame arrives after the `TERMINATING` edge, `frame_rcv_ip` refuses to start parsing it.
- All hits inside that frame are lost before `H0`.

### 3. `mts_processor` already expects a terminating EOP-style contract

Current behavior:

- `processor_state` moves from `RUNNING` to `FLUSHING` on `run_state_cmd = TERMINATING`
- `asi_hit_type0_ready` stays high in `FLUSHING`
- `proc_terminating_eop_pipeline` explicitly watches:
  - `asi_hit_type0_valid = '1'`
  - `run_state_cmd = TERMINATING`
  - `asi_hit_type0_endofpacket = '1'`
- `proc_payload2avst` forwards that delayed marker as `aso_hit_type1_endofpacket`

Implication:

- `mts_processor` is already structured around "I will see one last `hit_type0` packet boundary during termination".
- If `frame_rcv_ip` never starts the last frame, `mts_processor` never sees the expected terminating packet/EOP contract.

## Conclusion

The current `tb_int` miss at `A -> H0` is consistent with this exact hole:

1. The emulator has buffered hits committed before the run stop.
2. Those hits are packed into a frame that starts after the `TERMINATING` edge.
3. `frame_rcv_ip` is already disabled for new header detection.
4. The frame is dropped before `H0`.
5. `mts_processor` never receives the terminal packet/EOP boundary it was designed to react to.

This also explains why the issue can appear in end-to-end simulation while old RTL verified on beam data looks correct:

- the source-of-truth MuTRiG-side timing model may never start a fresh packet after the terminate edge
- the emulator currently can

## Proposed Chain Contract (2026-04-16)

The preferred end-of-run contract for clean hit accounting is:

### 1. `frame_rcv_ip`

- Keep packet parsing tied to the real serial protocol.
- Do not create synthetic hit beats at run end.
- If a real MuTRiG frame is already in progress, finish it and emit its normal packet EOP.
- After `TERMINATING`, do not start a fresh frame unless the source-of-truth MuTRiG timing contract proves that such a frame is legal.

### 2. `mts_processor`

- Generate exactly one SOP per run per interleaving lane, on the first emitted `hit_type1` beat of that lane.
- Generate exactly one EOP per run per interleaving lane, on the final emitted `hit_type1` beat of that lane.
- Do not use a fixed-delay synthetic EOP as the architectural contract.
- In `TERMINATING`, stop admitting new run traffic, drain local work, then emit the lane EOP on the final real beat, or an empty terminal beat only if the lane carried no payload for that run.

### 3. `ring_buffer_cam`

- Treat `asi_hit_type1_endofpacket` as a lane-local end-of-run marker.
- Track EOP per accepted interleaving lane, not as one undifferentiated global sticky bit.
- Once a lane has seen EOP, mask further intake from that lane for the current run.
- Continue popping and forming subheaders for the remaining active lanes.
- Acknowledge `TERMINATING` only when every active lane has seen EOP and the local FIFO/CAM/pop-command state is drained.

### 4. `feb_frame_assembly`

- Consume the lane-local RBCAM EOP information from the subheader stream.
- Mask lanes whose final subheader/EOP has already been consumed.
- Keep generating complete frames until all active lanes have terminated and the pending subfifos are empty.
- Do not emit a fragmented end marker in the middle of a frame body.
- Instead, place the final run-level EOP on the trailer of the frame that contains the last terminating subheader(s).

### 5. Downstream OPG / OPQ

- No extra run-end sideband is required if FEB output is structurally complete.
- It is acceptable to terminate downstream collection after a bounded grace period with no FEB traffic.
- If downstream hit accounting needs exact per-run closure, explicit trailer-based end-of-run bookkeeping is still preferable to a pure timeout.

Why this contract is better:

- it preserves timing-accurate datapath behavior
- it keeps SOP/EOP attached to real protocol beats instead of scoreboard-only cuts
- it makes `TERMINATING` acknowledgement depend on actual local drain completion
- it lets the monitor/parser/SVA layer prove `100%` hit closure without imposing a hard global time cut

## TODO Checklist (2026-04-16)

- [ ] `mutrig_timestamp_processor/mts_processor.vhd`: replace the fixed delayed global terminate pulse with lane-targeted close markers on the `hit_type1` sideband channel.
- [ ] `mutrig_timestamp_processor/tb/mts_processor_terminating_tb.vhd`: add a directed case that expects one empty close marker per downstream lane after payload drain.
- [ ] `mutrig_timestamp_processor/tb/uvm/*`: add or update a terminate-contract case so the scoreboard checks lane-targeted empty close markers and late ready ack.
- [ ] `ring-buffer_cam/ring_buffer_cam_v2_core.vhd`: consume lane-targeted empty close markers without writing them into the deassembly FIFO; latch end-of-run only for the local interleaving lane.
- [ ] `ring-buffer_cam/ring_buffer_cam.vhd` and `ring_buffer_cam_hw.tcl`: expose the new `asi_hit_type1_empty` ingress sideband through the packaged IP.
- [ ] `ring-buffer_cam/tb/sim/*` and `ring-buffer_cam/tb/uvm/*`: add a lane-local terminate case that proves an empty close marker drains the instance and does not create a ghost hit.
- [ ] `packet_scheduler/tb_int/rtl/datapath_stub.sv`: wire the MTS empty-close sideband into each `ring_buffer_cam` instance.
- [ ] `packet_scheduler/tb_int/uvm/tb_int_pkg.sv`: stop counting empty close markers as H1 hits while still auditing their lane/EOP timing.
- [ ] `packet_scheduler/tb_int/uvm/*`: add an integration testcase that keeps the current FEB-output accounting intact while exercising the upgraded terminate/drain path.
- [ ] `feb_frame_assembly/*`: only touch if the post-upgrade chain still strands hits after lane-local RBCAM drain; otherwise keep it unchanged for this pass.

## Target Contract

The run-sequence contract should be made explicit and uniform:

### `RUNNING`

- New MuTRiG packets may start.
- `frame_rcv_ip` may parse new frames and emit `hit_type0`.
- `mts_processor` may emit new `hit_type1`.

### `TERMINATING`

- No new run traffic should be considered part of the next packet generation window.
- In-flight packet state must be wrapped up deterministically.
- A terminal packet boundary must be propagated downstream.
- The IP must not acknowledge the terminate transition until its local drain and terminal marker obligations are complete.

### `IDLE`

- The datapath must be quiescent.
- All termination markers must already have been emitted.

## Recommended Upgrade Direction

### 1. Make `frame_rcv_ip` termination behavior explicit

Required changes:

- Split "accepted run command" from "parser open for new header".
- On a `TERMINATING` edge, latch a `terminating_pending` state instead of immediately treating the parser as hard-disabled.
- Define one of these contracts and implement it intentionally:

Option A:

- Source-of-truth contract says no new MuTRiG frame may start after `TERMINATING`.
- `frame_rcv_ip` does not parse any fresh post-edge frame.
- It emits one explicit terminal `hit_type0_endofpacket` marker for downstream consumers.
- This matches the proposed "wrap up and signal end of packet" behavior.

Option B:

- `frame_rcv_ip` is allowed to parse exactly one final drain frame that was already physically committed upstream before the terminate edge.
- After its real EOP, it emits the downstream terminal boundary and closes.

Recommendation:

- Prefer Option A if the old beam-verified source RTL really defines "no new frame start after terminate".
- Treat any emulator behavior that violates that contract as a stimulus-model mismatch, not as golden behavior to preserve.

### 2. Make `mts_processor` termination contract first-class

Required changes:

- Keep the existing `FLUSHING` concept, but document it as part of the public run-state contract.
- Define exactly what counts as the terminal boundary:
  - real `hit_type0_endofpacket`
  - synthetic terminal EOP from `frame_rcv_ip`
  - or both
- Stop creating new `hit_type1` payload after the terminal boundary has been accepted.
- Emit one final `aso_hit_type1_endofpacket` for downstream consumers.
- Only acknowledge `TERMINATING` once the terminal boundary has been forwarded and the local FIFO/drain state is empty.

### 3. Fix the host-agent acknowledgement behavior

Current issue:

- Both IPs effectively drive `asi_ctrl_ready <= '1'` unconditionally.
- That means the run-control handshake does not reflect real completion of `RUN_PREPARE`, `SYNC`, or `TERMINATING`.

Required changes:

- `asi_ctrl_ready` must become stateful.
- `RUN_PREPARE` should acknowledge only after reset/flush work is complete.
- `SYNC` should acknowledge only after the IP is armed for the next phase.
- `TERMINATING` should acknowledge only after the terminal packet/EOP contract is complete.

### 4. Align or constrain the emulator timing model

This is not the first RTL fix to make, but it must be resolved after the receiver/processor contract is defined.

Required action:

- Compare the real MuTRiG source behavior against the emulator:
  - Can a fresh packet start after the terminate edge?
  - If not, the emulator must stop doing so.
- If the emulator is intentionally more permissive for stress purposes, tag that as non-architectural stimulus and keep dedicated assertions around it.

## Verification Plan

### A. Contract assertions

Add or refine SVA/property checks so that:

- `frame_rcv_ip` never silently drops a terminal packet boundary
- `mts_processor` always converts the accepted terminal boundary into one final downstream EOP
- `asi_ctrl_ready` is low while the IP is still draining termination work

### B. Parser-based monitors at every stage

Keep the datapath timing-accurate and do not convert the main stream back to transactions at IP boundaries.

Instead:

- parse the live RTL stream at each stage
- extract hit/header/subheader/trailer content from the real pin protocol
- run both content checking and format/SVA checking from that parser

This should be applied stage by stage, not only at OPQ.

### C. Hit-level lineage debug

The current `tb_int` debug direction remains valid:

- assign lineage IDs at `A`
- propagate candidate lineage stage by stage
- dump unmatched residuals at each boundary

This is still the right mechanism for proving exactly which hit or packet boundary is lost.

## Immediate Next Checks

Before implementing the RTL changes, confirm the source-of-truth contract:

1. Does the original MuTRiG source ever start a fresh packet after `TERMINATING`?
2. If not, use that as the architectural rule and align both `frame_rcv_ip` and the emulator to it.
3. If yes, then `frame_rcv_ip` must support one final drain frame before closing and the terminal EOP must follow that real frame boundary.

## Summary

The current failure is best explained first by the emulator tail-pop bug:

- `frame_assembler` emits the last hit of each frame but does not pop it
- the residual hit carries from frame to frame inside the emulator FIFO
- once fresh frame starts stop, the remaining FIFO tail is stranded
- stage `A` counts those hits, but `H0` never sees them

The run-sequence mismatch remains a secondary cleanup item:

- the emulator can still start a drain frame in `TERMINATING`
- `frame_rcv_ip` immediately closes new header detection in `TERMINATING`
- `mts_processor` already expects a terminal EOP contract that never arrives if the receiver drops that frame

That is no longer the first blocker to address, but it is still worth
finishing once the emulator FIFO-pop contract is corrected.

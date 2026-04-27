# DV Note

## 2026-04-18

### Formal bring-up decisions

1. `DV_FORMAL.md` stays the verification intent, but the live RTL is the source of truth for executable proofs.
   The current `runctl_mgmt_host.sv` does not expose `asi_synclink_valid` or
   `asi_synclink_ready`; the synclink side is a passive sampled byte stream
   (`asi_synclink_data`, `asi_synclink_error`).

2. The current RC ACK implementation is a single 36-bit beat with
   `startofpacket=endofpacket=1`, not the older four-beat header/body/trailer
   grammar described in `DV_FORMAL.md` section R3.

3. The intended integration formal backend is Siemens `qverify` /
   `znformal` under the QuestaOne toolchain. As of 2026-04-21 this host still
   does not expose runnable `qverify` / `znformal` executables, so active
   closure evidence in this harness remains simulation-backed and proof-ready
   rather than a live formal-pass claim.

4. Phase 1 starts with the RC plane only:
   - `runctl_mgmt_host` live ingress/decode/ack contract
   - generated `altera_avalon_st_splitter` fanout invariants
   - generated `upload_system_v3_upload_pkt_mux` packet-granular merge invariants

5. For the RC host proofs, the `mm_clk` and `lvdspll_clk` domains are collapsed
   onto one formal clock and the CSR side is held idle. This is intentional.
   The first goal is to prove the command-path safety properties; CDC-specific
   claims remain for the dedicated CDC buckets.

6. The generated RTL is not edited. Where the host depends on generated/mixed
   IP that is irrelevant to the proof target, the harness supplies a local
   formal stub instead of patching the generated source.

7. The RC host's `logging_fifo` is stubbed in the formal harness. The command,
   fanout, ACK, and hard-reset contracts do not depend on the detailed FIFO
   implementation, and stubbing keeps future `qverify` bring-up isolated from
   unnecessary mixed-language generated FIFO detail.

8. The generated `altera_avalon_st_splitter` used for `run_control_splitter`
   is a pure broadcast mirror with `QUALIFY_VALID_OUT=0`; it does not perform
   any legality filtering on channel or packet metadata. Any "drop illegal
   channel/tagged RC word" check belongs at the integration producer/consumer
   seam, not in the splitter leaf proof.

9. The generated `upload_pkt_mux` proof should start as a bounded proof bucket
   once a live `qverify` backend is available. The 1-stage pipelined Altera mux
   admits unreachable induction states unless the harness encodes a large
   amount of internal pipeline invariant state, so the first meaningful target
   remains a depth-32 bounded proof plus cover traces over concrete 3-source
   packet competition.

10. SC decode properties should consume generated metadata, not hand-copied
    addresses. A `.sopcinfo` extractor now exists to emit a SystemVerilog map
    header for `debug_sc_system_v3`, which is the planned source of truth for
    the SC formal aperture checks.

11. The SC map extractor emits scalar `FE_SC_BASE_*` / `FE_SC_END_*` constants
    instead of unpacked arrays so the generated map stays easy to consume from
    both simulation harnesses and future formal front-ends.

12. The current live `debug_sc_system_v3` export map does not match the older
    hand-written S6 table exactly. In particular, the exported `mm_bridge.s0`
    window on `sc_hub_cmd_pipe.m0` is `0x20000..0x2FFFF`, and the JTAG-only
    `mutrig_cfg_ctrl_0.avmm_scanresult` window lives at `0x40000..0x4FFFF`,
    outside the 18-bit SC command space. The executable S6 bucket therefore
    proves one-hot/non-overlap and burst-boundary behavior against the live
    generated map, while keeping the out-of-range scanresult window as a static
    map-consistency fact rather than a dynamic SC cover.

13. Until a runnable `qverify` / `znformal` backend is present on this host,
    keep any future proof and cover invocations serialized and treat the
    simulation stress buckets plus map-consistency checks as the executable
    evidence for this harness.

### Immediate follow-up

- Reconcile the RC subsection text in `DV_FORMAL.md` with the live passive
  synclink contract and single-beat ACK implementation once the first RC proofs
  are stable.
- Stage SC and DP formal buckets behind leaf-module wrappers or extracted
  generated SV views so they are ready for `qverify` / `znformal` once the
  backend becomes runnable on this host.

### Integrated soak bring-up decisions

1. The passing standalone datapath E2E bench does not hold the RC word at
   `CTRL_RUNNING` level-high. It emits short, explicit state-transition pulses:
   `RUN_PREPARE`, then `SYNC`, then `RUNNING`, with 2-cycle valid strobes and
   finite gaps between transitions.

2. The first full-FEB soak variant was incorrectly forcing `RUNNING` high for
   the full external RC window. That produced live emulator traffic and early
   datapath progress, but no visible RC fanout at the monitored consumers and
   no upper/lower frame emission. The soak now reuses the standalone bench's RC
   semantics instead of inventing a level-held approximation.

3. A later Tcl-driven pulse variant still left the integrated soak fragile.
   The `ring_buffer_cam` leaves could miss clean reset defaults or RC phase
   alignment in the mixed-language image, which showed up as `csr.go` /
   `csr.filter_inerr` staying unknown and the deassembly FIFO never accepting
   hits. The deterministic fix is split by role:
   - startup-only generated reset seams are forced from the `vsim` Tcl harness
     for one initial reset window
   - recurring RC fanout is driven from `tb_feb_system_v3_soak_sidecar.sv`
     on clock edges at the internal sink seams

4. The soak sidecar remains the source of truth for mixed-language refresh
   seams. It already republishes emulator decoded lanes every cycle; RC fanout
   now follows the same model so PREP/SYNC/RUNNING/TERMINATING pulses are
   clock-aligned and repeatable instead of depending on one-shot Tcl timing.

5. Fixed-width RC pulses are still not sufficient for the integrated full-FEB
   image. Runtime counters showed `pop_cmd_fifo_wrreq` incrementing while
   `pop_cmd_fifo_rdack`, `pop_pipeline_start`, type2, and type3 all stayed at
   zero, which points to agents still being in PREP/flush work when the test
   bench advanced to the next run-control phase. The soak sidecar therefore
   needs to behave like `runctl_mgmt_host`: hold each command level until the
   internal sink `ready` fanout has converged, then advance to the next phase.

6. The integrated soak's expensive operation is not the RC/data checks
   themselves; it is the mixed-language full-FEB simulation throughput. To
   keep long runs practical, the soak TB now separates cheap datapath/runtime
   counter status from SC heartbeat traffic. `tb_feb_system_v3_soak` exposes
   generics for active window, status interval, SC health-check interval,
   settle time, and drain time so the wallclock/runtime tradeoff can be tuned
   without recompiling the testbench source.

7. Periodic SC scratch readback during the active window is not necessary on
   every status checkpoint. The soak now performs the initial SC scratch sanity
   check at startup, allows active-window status samples to skip SC accesses
   when `G_SOAK_SC_HEALTH_INTERVAL=0 ns` (or when the coarse SC interval has
   not expired), and still performs a final SC scratch check at signoff.

8. The previous `run_soak.sh` launcher added avoidable overhead by returning to
   Tcl every `10 us` of simulated time to poll `external_rc_active`. The test
   bench already calls `stop;`, so the launcher now switches directly to
   `run -all` after the startup seam forces are installed. This materially
   improves soak throughput and makes the transcript progress observable again.

9. The top FEB run-control splitter is now a readyless broadcast in the pipe
   Qsys (`USE_READY=0`). The RC harness therefore treats missing
   `run_control_splitter_out[0:15]_ready` nodes as expected and checks the
   host-side ready plus downstream valid/data seams instead. The soak harness
   still force-drives emulator-control splitter ready leaves when those leaves
   exist, because that is a separate local fanout used only by the sidecar's
   deterministic phase machine.

10. Repeated soak iterations were previously paying the full rebuild cost every
    time. `run_soak.sh` now supports `SOAK_SKIP_BUILD=1` to reuse the existing
    compiled work library when only the soak window / status cadence changes.

11. Sparse-lane / low-hit-rate soak still did not scale because the emulator
    continuously emits idle commas with `valid=1`, and the sidecar was
    force-refreshing those bytes into the decoded seam every cycle. For the
    integrated soak only, the sidecar now supports a `+SOAK_GATE_IDLE_DECODE`
    plusarg that suppresses `{1'b1, 8'hBC}` idle bytes by forcing `valid=0`
    while preserving real payload bytes, channel, and error metadata.

12. Long-run "without drops" signoff is now explicit in the soak TB. After the
    active window closes, the bench freezes both histogram blocks through their
    local CSR seam and fails if either histogram reports non-zero dropped,
    underflow, or overflow counts. SC liveness remains checked through the
    scratch heartbeat path during the same run.

13. The local histogram CSR seam is not reliable enough for final soak signoff
    in the mixed-language full-FEB image. A reduced soak run showed
    `cfg_apply_pending` reading back as `X` during the local freeze path even
    though the datapath itself was moving hits and frames. Final histogram
    freeze/readback therefore uses the exported SC path instead of the local
    seam.

14. The original RC visibility monitor sampled datapath-side run-control pulses
    on `clk156`, which can miss the bench-driven pulses because the sidecar
    refreshes those sink seams on `clk125`. The soak RC monitor now samples on
    `clk125`, and final signoff requires full RC fanout masks for datapath,
    emulator, hit-stack ingress, frame datapath, and frame xcvr seams.

15. The VHDL-side RC alias monitor still did not observe the mixed-language
    forced seams reliably enough for signoff. RC mask accumulation now lives in
    the SystemVerilog sidecar, which both drives and samples the exact sink
    seams, then force-publishes the accumulated masks back into the VHDL test
    bench for reporting and final assertions.

16. Final no-drop signoff no longer writes `control=0` into the histogram CSRs.
    In the integrated image, the extra SC write disturbed the expected reply
    sequencing (`bad reply header, got 0x000D0001`) even though normal SC reads
    still worked. The final check now performs read-only SC status snapshots for
    dropped/underflow/overflow counters after the drain window.

17. Even read-only histogram status snapshots through the exported SC path are
    not stable enough for end-of-run signoff in the integrated image. Scratchpad
    SC accesses remain healthy, but histogram status is now sampled through the
    local datapath CSR seam in read-only mode. The local seam is sufficient for
    counter observation as long as the bench does not attempt the problematic
    control-stop write sequence.

18. The histogram status plane also proved unreliable in read-only local mode:
    the end-of-run snapshot still returned `X`. No-drop signoff therefore moves
    to stable datapath observability instead:
    - queue balance (`pop_cmd_fifo` wrreq/rdack)
    - upload frame accounting
    - frame-assembly loss indicators (`frame_debug_loss8fill_valid` and
      `frame_debug_delay8loss_valid`) on both hit-stack subsystems

19. The long-run soak reply capture was accidentally modeling the entire
    combined `datapath+SC+RC` upside link as slow-control traffic. That works
    for short runs but eventually overflows `rsp_mem` because `swb_sc_secondary`
    sees datapath and run-control frames that are not SC replies. The reply
    bridge now forwards only `upload_data0_sc_rc_channel = "01"` into the SC
    parser, which matches the generated `upload_pkt_mux` channel mapping:
    `00=data`, `01=sc`, `10=rc`.

20. In the mixed-language integrated image, the early datapath seam aliases
    (`mutrig_datapath_subsystem_*_hit_type0_out_*`, `mts_preprocessor_*_hit_type1_out_*`)
    are not reliable enough for scaled soak signoff even when later stages are
    clearly alive. A scaled run reached `7.7 s` of sim time with both hit-stack
    halves emitting type2/type3 traffic, both upload links accepting frames,
    and all frame-loss counters at zero, while the earlier seam counters stayed
    at zero. Final soak pass/fail therefore keys off the stable later-stage
    observables:
    - hit-stack type2 and type3 traffic on both halves
    - upper/lower upload frame acceptance
    - SWB frame accounting on both links
    - zero frame-assembly loss indicators
    - drained hit-stack pop-command queues

21. The soak bench had also drifted against the current `emulator_mutrig` CSR
    map. The helper was still programming a removed "timing" register at CSR
    address `2`, while the live RTL now uses that slot for burst/cluster
    control. The soak helper now only touches the still-live CSRs needed for
    traffic stimulus (`control` when lanes are disabled, `rate`, `seed`, `tx`),
    and preserves `gen_idle=1` when stamping per-lane `asic_id`.

22. For extreme time-scale soaks, the emulator bootstrap cost dominates wall
    time even though the long-run checks themselves are stable. To keep the
    stress run focused on the integrated datapath:
    - the soak launcher now supports `SOAK_EMU_CFG_FAST_FORCE=1`, which freezes
      the emulator config registers directly in `vsim` and skips the per-lane
      CSR programming loop in VHDL
    - the soak TB now supports `G_ENABLE_SC_HEALTH=false`, allowing the
      extreme-scale no-drop run to skip the initial/final scratch transport
      round-trips when SC has already been covered by the dedicated SC smoke and
      burst tests
    - this improves startup materially, but the full `120 s` simulated active
      window still did not complete within the current wall-clock budget, so
      multi-minute soak signoff remains open

23. The FE SciFi v3 histogram-rate sweep for the rebuilt `emulator_mutrig`
    (`26.1.9.0418`) is structurally wired as intended in source:
    - `scifi_datapath_system_v3` now instantiates the updated emulator version
    - the datapath already provides `mutrig_injector_0` mode `2` as the
      periodic self-clock pulse source
    - `feb_system_v3` now also connects `debug_sc_system_v3.charge_injection_pulser_0`
      into the emulator fanout through the new datapath `inject_aux` seam
    - for the rate sweep itself, the cleanest emulator configuration is
      `hit_rate=0`, `noise_rate=0`, `hit_mode=POISSON`, `burst_size=1`,
      `burst_center=16`, so only the external injection pulses generate hits
    The full mixed-language datapath bench remains very slow for rate sweeps,
    so the integration harness now includes:
    - `scripts/run_dp_hist_rate_sweep.sh` to run preserved per-rate reports
    - `scripts/check_dp_hist_rate.py` to compare the eight active histogram
      bins against the expected pulse counts
    The open issue is runtime, not setup correctness: even sub-second active
    windows on the full datapath harness remain expensive enough that second-
    scale sweeps should either use heavily calibrated shorter windows or move
    into a narrower dedicated bench for the emulator-plus-histogram path.

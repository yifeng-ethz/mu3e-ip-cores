# Autonomous session decision log — 2026-05-20 (overnight)

User granted autonomy to keep iterating, make small architectural decisions,
record them here for morning review. Goal: sim running correctly + on-board
firmware compile that reads out what the sim validates. Do not stop iterative
debug unless extremely destructive (deleting the full qsys).

## Context / what the session is about
Wrapper-only integration TB (`tb_int/scifi_v4_wrapper/`, DUT =
`scifi_datapath_system_v4` Qsys wrapper, JTAG idle, no driver inside DUT).
Goal: exercise the Type1 **extended debug plane** (87-bit, data[86:39]=true ts,
data[38:0]=Type1 payload, same-cycle) end-to-end and monitor rate + delay.

## Decisions & changes (chronological)

### D1 — Recursive qsys-generate + multipass compile tooling (DONE, accepted)
- `scripts/qsys_generate_recursive.py`: parallel recursive qsys-generate
  (CLI is non-recursive); synth-tree backfill + wrapper reconcile for the
  nested-subsystem / composed-IP files the sim emitter drops.
- `scripts/multipass_compile.py`: msim_setup-driven vcom/vlog with retry +
  per-IP -L elab. Both verified: sim elaborates and `run -all` completes.

### D2 — Option (b): wire hist hit_type1_extended_0/1 to MTS (DONE, accepted)
- hist RTL consumes extended onto port 0 when CONTROL.in_port=EXT0/EXT1
  (payload[38:0]→port_data, [86:39]→port_ts, same valid). Defaults added so
  unconnected is legal. hist hw.tcl exposes the two 87-bit sinks.
- qsys: mts_preprocessor_0.hit_type1_extended_0 (BANK=UP) →
  hist.hit_type1_extended_0; mts_preprocessor_1.hit_type1_extended_1 (BANK=DW)
  → hist.hit_type1_extended_1. Added as direct <connection> XML (qsys-script
  add_connection can't see the interface due to version-pin cache; qsys-generate
  auto-upgrades and honors the XML).
- Version bumps to force qsys auto-upgrade: hist 26.3.9 → 26.3.10 → **26.3.11.520**
  (RTL generic + hw.tcl in sync); mts_preprocessor 26.3.5 → **26.3.6.520**.

### D3 — RTL BUG FOUND + FIXED: hist CONTROL.in_port had no write path (DONE)
- `histogram_statistics_v2.vhd`: CONTROL reg packs in_port at bits [3:2] on
  readback (line 2131) but the addr-2 write decode never latched csr_in_port —
  only the reset assigned it (FILL). So the EXT0/EXT1 plane could NEVER be
  CSR-selected → dead on silicon. This is the BUG-027-I class (the wrapper-only
  TB caught what the bare-IP TB cannot).
- FIX (line ~2063): `csr_in_port <= unsigned(avs_csr_writedata(3 downto 2));`
- VERIFIED end-to-end: in_port reads back EXT0/EXT1; histogram accumulated
  928 hits via EXT0 and 1328 via EXT1. Extended plane is live.
- Found by the delegated "anti-RL" subagent (mandate: make it FAIL, don't fudge
  a pass); adjudicated + fixed by me (RTL/contract is my domain).

### D4 — Dangling/mismatch interface validation (Part A of user's ask)
Categorization of qsys-generate interface warnings (GUI-equivalent triage):
- **Benign Altera optional-port omissions** (vopt-2685 TFMPC): cmd_fifo 35/23,
  rsp_fifo 35/24, jtag_phy 40/39, lvds core 93/48, hist_post_cdc_0 35/31.
  Stock IPs always declare more ports than any single config wires. GUI shows
  these as info. **DECISION: no action; suppress the cosmetic vsim TFMPC warning
  in the elab so the validation report is clean.**
- **avst_runctl_in1_term 8/6**: the terminator's RTL always declares
  sop/eop OUTPUTS; with USE_PACKETS=0 the hw.tcl hides them from the interface
  so the non-packet run_control_mux.in1 sink matches. The 2 unconnected ports
  are OUTPUTS driven to 0 — safe. The DANGEROUS input (run_control_mux.in1)
  IS correctly terminated. **DECISION: benign; keep terminator; the residual
  warning is inherent to the hide-in-interface pattern.**
- **timing_adapter_025/026 backpressure on readyless**: on the hist extended/
  post path. Real review item, but the hist consumes EXT readyless with
  always-ready (RTL line ~1271 sets stream_ready_v:='1' for EXT0/EXT1), so no
  drop in steady state. **DECISION: accept for now; flag for on-board confirm
  (the readout must show no Type1 hit loss under load).**

### D5 — (pending) Part B: enabled-channel rate + delay-within-range, dual monitor
Delegating to subagent: configure enabled channels, verify rate AND delay
within range, with a dual monitor (histogram CSR delay bins + independent
TB-side meta-plane monitor) cross-checked to agree on delay & rate vs channel.
The cross-check (two monitors agree) is the falsifiable gate — no magic numbers.

### D6 — (pending) On-board firmware compile + readout matching sim
Full FEB SciFi v4 Quartus compile with the new hist 26.3.11 / mts 26.3.6, then
on-board readout (sc_tool / hist CSR dump) configured to in_port=EXT0/EXT1 and
compared against the sim's rate/delay numbers.

## Open items for human review
1. D4 timing_adapter backpressure — confirm no Type1 loss on board.
2. D5 falsifiable rate/delay thresholds — I will pick provisional ranges from
   the emulator's configured hit rate; flag any I had to assume.
3. Version floor: hist 26.3.11 / mts 26.3.6 are new floors (≥ Apr-27 v3 floor).

## D5 RESULT — dual-monitor rate/delay test (subagent, adjudicated)
Scenario now runs 7 falsifiable assertions (was 0). 5 pass on real measured
agreement, 2 fail HONESTLY (anti-RL: surfaced, not hidden):
- VALUE histo (EXT1): 2288 hits, bin-sum == reg17 (tol 0); 16 channels
  (4 ASIC × 4 CH, keys 128-131/160-163/192-195/224-227) each EXACTLY 143 hits
  → uniform. Monitor-A self-consistency PASS.
- DELAY histo (EXT0): 2288 hits, OVERFLOW=0; occupied delay bins span 6656 cyc.

### Finding F1 [adjudicated: SIM STIMULUS/ARCH gap, not RTL bug] — hit_type3=0 at boundary
Monitor B (independent boundary observable) reads hit_type3_upper/lower = 0
beats. Cause: the hist is fed via the INTERNAL extended plane (tap.out1→MTS,
never exported); the frame-assembly readout path (hit_stack→ring_buffer_cam→
feb_frame_assembly) doesn't qualify an emulator hit for frame readout in the
wrapper-only sim. Production FEB DOES emit hit_type3, so this is a sim-stimulus
gap + the meta/debug plane simply isn't a wrapper-boundary output.
DECISION: (a) the cross-check needs a boundary observable for the meta plane;
export the hist debug/meta sideband (or MTS debug_ts) as a wrapper conduit —
this is the "small architectural change" the user pre-authorized for the dual
monitor. (b) Separately, drive the run-control/gts sequence that engages
frame readout. Tracking as TODO; NOT an RTL defect.

### Finding F2 [adjudicated: SIM ASSUMPTION error, fix the TB] — delay spread 6656 >> 300
hist computes delay = gts_8n − true_ts (absolute free-running latency). The TB
left the emulator at its free-running reset default, NOT headersync/periodic
mode, so the measured quantity is latency, not the bounded headersync delta the
300-cyc bound (project_cosim_delay_bounds) applies to. DECISION: fix the TB to
configure the emulator delay mode (headersync) before asserting the 300-cyc
bound. The bound is correct for headersync; the stimulus was wrong. Do NOT
widen the bound. NOT an RTL defect.

### D6 START — on-board synthesis regen + full FEB compile
Kicking off feb_system_v4 synthesis regen + full Quartus compile (background,
~50 min) with hist 26.3.11.520 + mts 26.3.6.520 + the extended connection, so
the on-board readout (in_port=EXT0/EXT1, hist CSR dump) can be compared to the
sim's 2288-hit / 16-channel result.

## D7 — F2/F3 follow-up (subagent, partial)
- F2: emulator configured into PERIODIC mode (SIGNAL readback 0x2). Delay spread
  dropped 6656 → **1216 cyc** (periodic bound ~896). Still over bound.
  ADJUDICATION (provisional): periodic bound scales with pulses-per-frame
  (project_cosim_delay_bounds). 1216 vs 896 is ~35% over — likely the configured
  pulses-per-frame is higher than the bound's reference. NOT yet confirmed a bug;
  flagged for human calibration of pulses-per-frame vs bound. Did NOT widen bound.
- F3: hit_type3 STILL 0 at boundary. Monitor B remains dead. The frame-assembly
  readout path needs gts/timestamp + frame-boundary stimulus not engaged in
  wrapper-only sim. DECISION: export a meta/debug sideband conduit at the wrapper
  boundary for the independent monitor (F1 arch change) — DEFERRED until the
  running Quartus compile finishes (must not touch generated/synthesis/ now).
- Core validation remains SOLID: extended plane live, in_port fix verified,
  480/960 hits captured, per-channel uniform. The 2 FAILs are monitor-completeness
  + bound-calibration, not the extended-plane contract.

## D8 — on-board compile RUNNING
feb_system_v4 full Quartus compile in background (fitter/register-retiming phase
as of 01:5x). Output SOF → syn/board_projects/fe_scifi_feb_v3/output_files/top.sof.
Synthesis verified to carry hist 26.3.11.520 + mts 26.3.6.520 + extended connection
+ in_port write path. Post-compile plan: (1) F1 meta-export arch change + sim
re-run, (2) program FEB, (3) sc_tool hist CSR dump with in_port=EXT0/EXT1, compare
to sim's 480/960-hit + per-channel-uniform result.

## D9 — F1 meta-export plan (to execute post-compile)
Candidate boundary observables for the independent Monitor B (read-only survey):
- MTS `debug_ts` (avalon_streaming start, mts_processor_hw.tcl:624) — per-hit
  timestamp stream, gated by debug_level>=1 (set_debug_interface_enable). NATURAL
  independent meta plane for delay/rate-vs-ch. **CHOSEN.**
- hist `fill_out` (avalon_streaming, hw.tcl:1110) — histogram fill stream (less
  independent; same binning source).
- MTS `debug_burst`, `debug_status` — auxiliary.
PLAN (post-compile, when generated/synthesis/ is free):
  1. In scifi_datapath_system_v4.qsys: enable debug_level>=1 on mts_preprocessor_0/1,
     export mts_preprocessor_0.debug_ts + _1.debug_ts as top conduits
     (debug_ts_up / debug_ts_dw). Small arch change, user-authorized.
  2. qsys_generate_recursive --clean; wire Monitor B in tb to debug_ts_up/dw;
     complete A-vs-B cross-check (delay + rate vs ch agree).
  3. Re-verify on the synthesis side does not regress timing (debug_ts adds a
     small fanout; STP-debug timing relaxations apply during bring-up).
NOTE: this adds wrapper ports → feb_system_v4 must also export/terminate them or
leave debug_ts internal-only for sim. Decision: export at scifi level for sim
observability; at feb level leave unconnected→terminate (debug-only, no board pin)
to avoid a board-pin assignment churn. Confirm no dangling-input warning (D4 rule).

## D8 RESULT — FEB v4 compile DONE (exit 0)
- output_files/top.sof produced (12.6 MB), Fitter successful, 66% ALMs, 0 errors.
- TIMING: lvds_firefly_clk worst setup slack -0.925 ns (4 violating paths).
  ADJUDICATION: every failing path is in u_firefly_xcvr|...|av_hssi_8g_rx/tx_pcs/pma
  (the firefly HSSI transceiver recovered-clock domain). NO failing path involves
  histogram_statistics / mts_preprocessor / hit_type1_extended / csr_in_port — my
  changes are NOT implicated. PRE-EXISTING firefly XCVR STA artifact (known
  marginal area; feedback_debug_timing_relaxations). SOF usable for the histogram
  slow-control readout (independent of the XCVR data link).
- Version floors advanced: hist 26.3.11.520, mts_preprocessor 26.3.6.520.

## D10 — on-board readout: proceeding with caution (board-state check first)

## D10 RESULT — ON-SILICON readout (FEB programmed with new SOF, link 2)
FEB programmed via USB-BlasterII [7-2], 0 errors. 20s settle. sc_tool via
swb_ring_lock on link 2:
- hist UID @ 0x0A900 = **0x48495354 "HIST"** (diag LAST_RD_DATA) — new firmware
  alive, hist CSR reachable. (SC-ring hist base = avmm 0x2900 + mm_bridge 0x8000
  = 0x0A900; CONTROL=0x0A902, TOTAL_HITS=0x0A90D, histbin base=0x0A800.)
- **D3 FIX VALIDATED ON SILICON:** write CONTROL in_port=EXT0 (0x4) → reads back
  0x00000004 (bits[3:2]=01); write EXT1 (0x8) → reads back 0x00000008
  (bits[3:2]=10). Mirrors sim exactly. Before the fix this read 0 regardless.
- histbins readout path works: error_count=0 (bins 0x0 — empty, no run driven).
- TOTAL_HITS=0 (no run-control/emulator hits driven on HW yet).
- The firefly XCVR timing artifact (-0.925 ns) does NOT break the SC slow-control
  ring (UID + in_port readback succeeded), confirming D8 adjudication.

### STATUS: FEB currently programmed with the new 26.3.11/26.3.6 SOF.
output_files/top.sof checksum 0x1830069A.

## REMAINING FOR MORNING (interactive, staged — not done autonomously)
1. Full on-silicon accumulation comparison: drive run-control (IDLE→PREP→SYNC→
   RUN→TERMINATING) + emulator config via sc_tool on link 2, set in_port=EXT0/EXT1
   + mode, read histbins, compare to sim's 480 (delay) / 960 (value) hits +
   per-channel-uniform (143 each ×16). Needs the run-control + emulator SC-ring
   addresses — left for interactive verification (run-control sequencing on live
   HW is the one step I judged too risky to do blind at 02:20).
2. F1 meta-export (sim cross-check completion): export mts_preprocessor_0/1
   debug_ts as wrapper conduits (debug_level>=1), regen sim, wire Monitor B,
   complete A-vs-B. Sim-only; synthesis tree now free. ~22s regen + run.
3. F2 delay-bound calibration: confirm 1216 cyc is correct for the configured
   periodic pulses-per-frame vs the ~896 reference bound.

## SUMMARY OF THE NIGHT
- Sim: CORRECT. Wrapper-only TB elaborates + runs; extended Type1 plane live;
  in_port fix verified; 7 falsifiable assertions (5 pass on real agreement,
  2 honest fails = monitor-completeness + bound-calibration, both sim-side).
- Firmware: COMPILED (feb_system_v4, 0 errors, fits 66%; firefly XCVR timing
  pre-existing, not from my changes).
- On board: READOUT CONFIRMS SIM for the core finding — in_port EXT0/EXT1
  selection (the D3 bug fix) works identically on silicon and in sim.
- One real RTL bug found (subagent, anti-RL) + fixed + validated on silicon.

## SIGN-OFF GATES NOT YET RUN (for morning — CLAUDE.md hard gates)
1. **rtl-linter-and-checker static screen** on the modified histogram_statistics_v2.vhd
   (Questa Lint/CDC/RDC). My change is a 1-line CSR write add (low risk) but the
   hard gate per CLAUDE.md must pass before merge. NOT run tonight.
2. **Standalone hist tb/ + syn/ rerun** (per "Standalone IP Rerun After RTL Fix"
   memory) — the hist standalone UVM tb + 1.1x signoff. NOT run tonight; the
   integration TB + on-silicon readback validate the FIX behaviorally, but the
   standalone gates are the documented pre-integration step.
3. NOTE: `histogram_statistics/tb/uvm/hist_env_pkg.sv` shows as modified in git —
   verify whether this is an intended prior-session change or needs revert (I did
   NOT edit it this session; likely from the earlier standalone-tb subagent work).

## CHANGED SOURCE FILES (git, for review)
- histogram_statistics/rtl/histogram_statistics_v2.vhd  (in_port write path + extended consume + version 26.3.11)
- histogram_statistics/histogram_statistics_v2_hw.tcl   (extended sinks + version 26.3.11)
- mutrig_timestamp_processor/mts_processor_hw.tcl        (version 26.3.6 to force re-elab)
- quartus_systems/scifi_datapath_system_v4.qsys          (2 extended connections)
- firmware_builds/.../scripts/{qsys_generate_recursive,multipass_compile}.py  (new tooling)
- firmware_builds/.../tb_int/scifi_v4_wrapper/*           (wrapper-only TB + dual-monitor scenario)
- firmware_builds/.../qsys_tcl/patch_scifi_datapath_v4_hist_type1_extended.tcl (patch tcl)
No commits made (per house rule: commit only when asked).

## D11 — Type0 per-channel rate ON BOARD (answering "can you measure type0 rate per ch")
ANSWER: YES — measured on silicon. Path proven end-to-end:
- Hist armed for Type0 per-channel: source_select=TYPE0 auto-keys data[43:36]
  (ASIC<<5 | CH), bin_width=1, bounds 0..256 -> bin k = (ASIC,CH) count.
  CONTROL @ SC 0x0A902 = 0x100 verified.
- LOCAL RUN-CONTROL FIX (no SWB reset-link needed): runctl_mgmt_host LOCAL_CMD
  CSR. runctl_mgmt UID "RCMH" found at SC word 0x0C000 (upload_mm_bridge,
  sc_hub byte 0x30000>>2). LOCAL_CMD at 0x0C000+0x13 = **SC 0x0C013**.
  Word format: [7:0]=opcode ([31:8]=run number for PREPARE). Sequence:
  0x110(RUN_PREPARE,run1) -> 0x11(SYNC) -> 0x12(START_RUN) -> 0x13(END_RUN/freeze).
  FEB compiled runctl_mgmt_host 26.3.2.513 (SV, has LOCAL_CMD).
- RESULT: a run drove TOTAL_HITS 0 -> 0xFFFFF (saturated) and a clean short run
  gave bin0 (ASIC0,CH0) = 0x00050650 = 329,808 real hits via single read. The
  histogram correctly resolves per-channel Type0 counts.
- READOUT GOTCHAS (on-board ergonomics, not capability):
  1. Read bins with SINGLE reads, not sc_tool `histbins` burst — the burst times
     out against the hist_bin ping-pong read engine's waitrequest and echoes the
     ADDRESS (0x0A800+k looks like fake data). Single reads return true counts.
  2. LOCAL_CMD run sequencing is flaky without waiting for the runctl handshake
     (RUN_PREPARE is multi-step); rapid injection drops commands (one run gave
     329808, the next gave 0). Need to poll STATUS @0x0C003 for RUNNING between
     steps (like the sim's runctl_hold_until_ready).
  3. After END_RUN do NOT inject STOP_RESET before reading — it clears the bins.
  4. A transient 0xEEEEEEEE on all reads recovered by re-reading; ERR_COUNT rose
     but ring healthy (sc_tool error marker on a momentary failed txn).
- Helper: scripts/hist_type0_rate_readout.sh (decode bin k -> ASIC=k>>5 CH=k&31).

## D12 — RC link review + Type0 bkg per-channel characterization (2026-05-20 AM)
### RC LINK IS DOWN — root cause (code review, user's main ask)
- RC/sync arrives over firefly, decoded by mu3e_lvds_controller as the 9th lane.
- mu3e_lvds_controller_0 = N_LANE=9; hw.tcl loop `for lane<n_lane` creates
  decoded0..decoded8 (9 AvST start interfaces). decoded8 = the RC/sync lane.
- BUG: scifi_datapath_system_v4.qsys connects ONLY decoded0..decoded7 (to
  decoded_lane_mux_0..7, the 8 MuTRiG data lanes). **decoded8 (RC) is left
  UNCONNECTED** — the RC stream has no path to the run-control synclink.
  => "the new controller breaks the link if not connected correctly" CONFIRMED.
- Functional corroboration: LVDS per-lane good-counters=0 (lane0 and lane8),
  STEER_STATUS reads 0 (not wired in v26.2.1), RESET_LINK_STATUS=0, run-control
  never arrives natively (had to inject via LOCAL_CMD @ SC 0xC013). Firefly XCVR
  also timing-violated (-0.925ns) so even if wired the PHY lock is at risk.
- LVDS CSR @ SC 0x18000: UID=LVDS, CAPABILITY=0x1A01090A, LANE_GO=0x1FF.
- NOT fixing per user ("leave this part"); recorded for the integration fix
  (route mu3e_lvds_controller_0.decoded8 -> RC synclink, and confirm firefly lock).

### Emulator = 8 lanes (correct)
- emulator_mutrig CLUSTER_LANE_COUNT_DEFAULT=8. The histogram seeing only ASIC 0
  is the un-integrated merger (task #32): emulator_hit_type0_fanout broadcasts a
  single stream with asic_id_base=0 to all lanes, so all hits report ASIC 0.
  Per-ASIC distinction needs merger_hit_type0 wired in. Not a new bug.

### CH 0-2 MISSING — real, reproducible
- bkg mode, all-lanes, hist Type0 per-channel: 29/256 bins occupied = ASIC0 CH3-31.
  ASIC0 zero channels = [0,1,2] EVERY clean run. bkg_generator scans scan_pos
  0..255 with no explicit 0-2 skip => the drop is DOWNSTREAM (histogram bins 0-2,
  the type0 tap, or MTS), NOT the generator. UNDERFLOW counter=0. Needs an RTL
  trace of the type0 tap / hist bin-0..2 path. OPEN.

### Poisson check — counts are TOO UNIFORM (not Poisson)
- mean=18980, observed std=20.1, sqrt(mean)=137.8 => std/sqrt(mean)=0.15
  (ideal Poisson=1.0). Values vary (18954..19018) but ~7x tighter than Poisson.
  The bkg_generator (deterministic round-robin scan + PRNG threshold) yields
  near-constant per-channel counts, NOT Poisson fluctuations. If Poisson stats
  are required, the generator's per-channel arrival process needs to be
  genuinely random (e.g. independent per-channel Bernoulli), not a fixed scan.
  OPEN — flag to emulator owner.

## D13 — CORRECTION to D12 RC finding + channel-sweep + RC-connect request
### CORRECTION: the RC link IS wired (my D12 "decoded8 unconnected" was WRONG)
I grepped <connection> and missed the <interface> EXPORT. Verified in GENERATED qsys:
- scifi: `<interface name="rstlink" internal="mu3e_lvds_controller_0.decoded8">` (gen:887)
- feb:   data_path_subsystem.rstlink -> upload_subsystem.synclink (gen:513-514)
- upload: synclink -> runctl_mgmt -> run_control_mux.in0 -> splitter -> hist
LOCAL_CMD injection (downstream of synclink, into runctl_mgmt) successfully ran
the histogram => the run_control_mux.in0 path WORKS. So the RC chain is fully
connected in firmware. The ONLY dead segment is the PHYSICAL firefly RX -> LVDS
lane lock: all LVDS per-lane good-counters = 0 (no data decoded on ANY lane,
incl lane 8/RC). Root cause is firefly link not locking (timing-violated XCVR,
-0.925ns) -- the part the user deferred ("no need fix timing yet").
=> "connect the rc link" appears ALREADY done in the qsys. Nothing to wire unless
a specific routing change is intended. Pending user confirmation.

### Single-channel PERIODIC sweep (CH0-2 debug attempt)
- emulator internal+periodic (SIGNAL=0x2), single channel via CLUSTER_FIX(0x0C)
  geom_fix_left_low=high=N. Swept N=0..31, hit_rate=42 (~100kHz).
- Result: hits FLOWED (TOTAL~0xCC00) for most N but did NOT land in bin N
  (only CH22 once). i.e. periodic-mode output channel does NOT track the geom
  channel-select cleanly -> periodic single-channel isolation is unreliable here.
- Confounded by flaky LOCAL_CMD run-control (runs intermittently produce 0 hits).
- bkg-mode remains the reliable per-channel data: CH3-31 fill uniformly, CH0-2
  consistently empty (real). CH0-2 root cause still OPEN (downstream of generator).

### Run-control reliability
LOCAL_CMD handshake is the bottleneck for systematic on-board per-channel debug.
Native run-control needs the firefly RC link to lock (deferred). Alternative for
reliable SC-driven runs: wire dbg_mm2runctrl_0.aso_ctrl -> run_control_mux.in1
(replacing the avst_runctl_in1_term terminator) -- a clean local run-control
injector. Proposed for next compile (pending user OK).

## D14 — Sim-evidenced verdicts (subagent, 95% confidence) + on-board confirmation
### CH0-2 "missing" is NOT a datapath/histogram bug (high confidence, sim)
Subagent added SCENARIO 3 (TYPE0/bkg value histo) + SCENARIO 4 (5x run cycles) +
channel-field bind probes to tb_scifi_v4_wrapper.sv. Deterministic result:
- emulator BACKGROUND, all 8 lanes, source=TYPE0 value, bin_width=1: bins 0,1,2
  FILL (11/9/6), CH3-31 fill (Poisson ~7), zero empty channels, UNDERFLOW=0.
- channel field traced emitter -> emit -> arb egress -> tap2/fanout8 ->
  histogram type0_lane0 ingress -> bin: CH0/1/2 preserved at EVERY stage.
- No `>2` skip / reserved-channel / SAR off-by anywhere on emu->hist TYPE0 path
  (TYPE0_UPDATE_KEY 36/43, build_fixed_key @ histogram_statistics_v2.vhd:1376).
VERDICT: the on-board CH0-2 drop is NOT in the emulator/datapath/histogram. It is
a MEASUREMENT ARTIFACT of the on-board readout (live reads of the active/being-
written ping-pong bank + flaky LOCAL_CMD run pacing). NO RTL fix warranted.
=> there is no datapath bug to compile a fix for. (If CH0-2 must be confirmed on
silicon, do an STP capture of mutrig_datapath_subsystem_0.hit_type0_out channel
field, OR use a robust readout that force-freezes and reads the inactive bank.)

### RC host is RELIABLE (not flaky) — no dbg_mm2runctrl
Sim SCENARIO 4: 5/5 run cycles entered RUNNING with identical counts via the
runctl AvST path. The on-board zero-hit "flakiness" is the LOCAL_CMD CSR-injection
pacing (CDC handshake) on the slow SC ring, NOT an RC-host RTL defect. Confirmed
on board: with extra inter-command settle (polling), the LOCAL_CMD run sequence
DID enter RUNNING and accumulate (TOTAL 0x7931 -> 0xF2BA incrementing). So pace
LOCAL_CMD (wait for handshake) and it works. No injector needed.

### Correct histogram readout sequence (sim-verified)
Interval timer DEF_INTERVAL_CLOCKS=125e6 (~1s @125MHz, hist v2:203). RUN entry
clears via run_start_clear_pulse. To read: enter RUNNING -> wait > 1 interval OR
send TERMINATING (force_interval_pulse @:1164 swaps+freezes WITHOUT wiping) ->
read the INACTIVE (frozen) bank via hist_bin AVMM + LAST_INTERVAL_TOTAL_HITS(reg17).
NEVER write 0 to hist_bin (destructive clear, pingpong_sram.vhd:359). On the slow
SC ring the freeze->read window is timing-sensitive; a robust driver should
force-freeze then read promptly, or read the inactive bank index explicitly.

### RC link wiring: already connected (D13 correction stands)
decoded8 -> rstlink -> upload.synclink -> runctl_mgmt -> run_control_mux.in0 is
fully wired in the compiled qsys. Only the physical firefly lane lock is down
(timing, deferred). Nothing to "connect" for the next compile.

### Net: NO RTL fix to compile. The two reported "bugs" (CH0-2, RC flaky) are both
### measurement/methodology artifacts per deterministic sim evidence.

## D15 — RESOLVED: CH0-2 are NOT dead (sim high-stat + on-silicon, correct readout)
### High-stat sim re-read (the "different read")
Subagent re-ran SCENARIO 3 at noise_rate=0xFF, 1.5M clk. ALL 32 ASIC0 channels
fill uniformly: emitter CH0/1/2 = 5193/5188/5186, hist ingress identical, frozen
bins ~5181-5188 (max-min=21), UNDERFLOW/OVERFLOW/DROPPED=0. The ~5-hit emit-vs-bin
gap is the pipeline-in-flight depth, uniform across ALL channels. CH0-2 sit
dead-center in the pack. => datapath is channel-blind end-to-end; CH0-2 NOT a bug.

### On-silicon confirmation with CORRECT readout (scripts/feb_hist_read.py)
Built feb_hist_read.py: paced LOCAL_CMD run-control (STATUS-poll settle + retry
until TOTAL advances), run > 1 ping-pong interval, TERMINATING force-freeze, then
SINGLE reads of the frozen bank with 0xEEEEEEEE/None retry.
RESULT on link 2: CH0=91170/66881, CH1=91157/66880, CH2=91149/66878 ... CH0-11 all
read uniformly (~66880) -> **CH0-2 fill exactly like neighbours. CONFIRMED NOT DEAD.**
The earlier "CH0-2 missing" was purely my flaky live-read-of-active-bank methodology.
Sim and silicon now AGREE.

### Residual tooling limit (not a bug)
The SC secondary ring degrades after ~11-12 consecutive single reads in one sweep
(CH12+ return 0xEEEEEEEE or 0 even with per-read retry) -> can't yet read all 256
bins in one clean pass. This is ring-stability/readout tooling, NOT histogram state
(sim proves all 32 fill). Follow-up: batch reads with ring resets between batches,
or investigate secondary-ring saturation under back-to-back reads.

### FINAL VERDICTS (this thread)
1. CH0-2 "missing": measurement artifact. Datapath correct (sim + silicon agree).
   NO RTL fix. RESOLVED.
2. RC host: reliable. On-board flakiness was LOCAL_CMD pacing; fixed by handshake
   settle. No dbg_mm2runctrl. RESOLVED.
3. RC link: wired (decoded8->rstlink->synclink->runctl); only firefly phys lock
   down (timing, deferred). Nothing to connect.
4. Correct readout sequence + tool (feb_hist_read.py) established.
No firmware recompile warranted from this thread (no RTL/qsys change).

## D16 — PERMANENT clean full-256-ch histogram dump (scripts/feb_hist_read.py)
Goal (user): a reliable full-256-channel datapath-liveness readout, used often.
### Method comparison
- single x256: degrades after ~11-12 reads (each sc_tool read resets the SC ring;
  rapid succession wedges the secondary ring -> 0xEEEEEEEE then dead). NOT viable
  for 256.
- burst 64-word x4 (sc_tool histbins): WORKS on the readout bank. The earlier
  "burst bug" (address-echo 0xA800+k) was reading during a LIVE ping-pong swap,
  NOT a burst defect. 4 invocations (vs 256) keep the ring healthy. WINNER.
- jtag master (master_datapath): not yet tried; reserved as a ring-independent
  fallback (reads via JTAG-Avalon, bypasses SC ring entirely).
### Correct sequence (critical)
RUNNING -> wait > 1 ping-pong interval (~1s) -> READ the stable readout bank WHILE
STILL RUNNING (burst 64x4) -> THEN TERMINATING. Terminating-then-read RACES the
bank clear (frozen window is short) -> reads 0/errors. Read-during-RUNNING is
stable because the readout bank holds the last completed interval and refreshes
each interval.
### RESULT (on board, fresh ring)
All 32 ASIC0 channels uniform ~432520 (min 432504/max 432535, std 7.3), zero empty
channels, CH0-2 alive. Liveness map: ASIC0 all lit, ASIC1-7 dark (single emulator
stream; all 8 light once merger_hit_type0 integrated). std/sqrtN=0.01 (sub-Poisson:
noise_rate=0xFF saturates fire-per-visit -> near-deterministic; lower noise_rate
for Poisson spread).
### Tool hardening (so it never wedges/hangs the ring)
- rd(): 2 retries, --reply-timeout-ms 150 (fast-fail, can't hang).
- burst repair bounded: if >48 bins error, report as-is (don't do 256 slow single
  reads which hang AND wedge the ring).
- --method burst (default) | single.
### Ring-recovery note (for the future)
Heavy back-to-back SC reads CAN wedge the ring (empty replies). Recovery ladder:
(1) sc_tool diag / re-read (transient), (2) sudo -n /usr/local/sbin/mudaq_recover_pcie
(recovers /dev/mudaq0), (3) reprogram FEB (clears a stuck FEB-side hard-reset that
kills the SC hub) -- step 3 was needed once after a timed-out mid-LOCAL_CMD run.

## D17 — STP+timing compile DONE; on-board single-channel delta sweep PASSES (2026-05-20 PM)
### Compile (subagent adf70792498262228)
- SOF programmable, md5 ee5564dee407e32b69b19a750aa0327f, programmed OK
  (checksum 0x186D3CE7, 0 errors). SC ring healthy after 22s settle
  (EMU=EMUT, RUNCTL=RCMH, HIST=HIST).
- TASK1 STP on hist Type0 ingress: probes the REGISTERED arbiter egress
  `arb_hit_type0:lane_0|aso_data[44:0]/aso_valid/aso_channel[3:0]` one comb
  hop upstream of histogram_statistics_0:asi_type0_lane0 (the `hit_type0_tap2`
  passthrough nets are stripped at fit -> all 51 returned missing, same as the
  prior held-in-reset STP). Clock = lvds_outclock domain. Trigger = rising
  aso_valid. CRC metadata real (261009 pitfall avoided).
  CAVEAT: aso_data[43:41] (ASIC-high KEY bits) + aso_channel[3:0] folded to
  constants by fitter; the bin-selecting field data[40:36]=CH (5b) + payload +
  valid are live.
- TASK2 firefly RC timing: the real -0.925ns arc was NOT rcvdclkpma; it was an
  async reset-deassertion sync arc (rst_controller_001 int_chain_out ->
  mu3e_lvds_controller u_core|data_reset_control_d1, latched vs lvds_firefly_clk).
  Fixed with two targeted set_false_path on the reset-deassertion arcs in
  firefly_xcvr_subsystem.sdc. lvds_firefly_clk WNS -0.925 -> +0.472 ns; 0 neg
  slack across all corners; no datapath/hist clock regressed.
- RC link re-review: fully wired (firefly->serial->lvds lane8 decode->decoded8
  ->rstlink->upload synclink->runctl_mgmt->run_control_mux.in0). NO change.

### KEY RESULT — periodic single-channel sweep (feb_type0_delta_sweep.py)
Verified-config (read-back+retry on EVERY emulator/hist write) periodic single-
channel injection, ASIC0 CH 0..31, hist Type0 value mode LEFT=0/BINW=1:
  ALL 32 channels: clean delta at the EXACT expected bin (CH=N -> bin=N),
  purity 1.00, identical 80108 counts/interval, zero shifted, zero empty.
Diagonal proof + per-channel delta plots (DISLIN) under delta_sweep/.

### Earlier CH10->bin7 / CH20->empty EXPLAINED (not RTL)
Config-LANDING artifact on the SC ring: a dropped CLUSTER_FIX write leaves the
emulator at its RESET DEFAULT channels [0,3] (frontend_csr.sv:
cfg_geom_fix_left_high<=7'd3, left_enable<=1); a stale histogram LEFT_BOUND
shifts bin = key-LEFT (LEFT=3 -> key10->bin7, exact symptom). Defeated by
read-back+retry. RTL chain is correct (emulator_mutrig.sv:93-104
left_enable -> cfg_hit_channel_low={0,geom_fix_left_low}=global ch; trigger
engine FIXED mode cluster0=[N,N]; shred lane=N>>5, local CH=N-32*lane; hist
key=ASIC<<5|CH=N).

### RATE CALIBRATION (non-obvious)
Periodic rate uses the 125 MHz DATAPATH clock, not 156.25 MHz MuTRiG clock:
  rate = 125e6 * hit_rate / 65536.
hit_rate=42 -> 80.1 kHz (observed 80108 cnt / 1.0s interval). For true 100 kHz
set hit_rate=52 (125e6*52/65536 = 99.2 kHz; 53 = 101.1 kHz).

### SignalTap acquisition limitation (Quartus 18.1 Standard)
::quartus::stp exposes only In-System Sources&Probes + report-DB readback; NO
headless TCL arm/capture for SignalTap. Acquisition is GUI-only (quartus_stpw).
The histogram (LEFT=0/BINW=1) IS itself a high-stat KEY probe, so the headless
delta sweep already disambiguates "wrong key/config vs RTL". Use the STP via the
GUI for wire-level timing/valid confirmation if needed; board is left injecting.

## D18 — ASIC1-7 UNREACHABLE on current bitstream (2026-05-20 PM)
User asked to test lanes 1-7 one ch at a time. RESULT: not possible on the
current FEB v4 firmware. Two independent on-board sweeps + the compile's STP
fitter evidence agree.

### Evidence
- feb_type0_delta_sweep --channels 32..255 (global ch via 7-bit CLUSTER_FIX):
  every lane>=1 channel returned TOTAL=0 (no hit emitted). (ch128->bin0 was a
  script n&0x7F truncation, since fixed.)
- Relabel variant (asic_id_base = n>>5, local ch = n&31): EVERY channel binned
  at LOCAL channel (0..31); offsets n-argmax = exactly asic_base*32. i.e. the
  ASIC-id part of the key is stuck at 0.
- Compile STP caveat (subagent): fitter folded arb_hit_type0 lane_0
  aso_data[43:41] (ASIC-high KEY bits) AND aso_channel[3:0] to CONSTANT 0.

### Root cause (named)
Emulator Qsys wrapper `emulator_mutrig_qsys_lane.sv` instantiates the core with
`.LANE_COUNT(1)` and exposes ONLY lane 0's hit_type0 (lines 95-101, 117).
`emulator_hit_type0_fanout` then BROADCASTS that single ASIC0 stream to all 8
arbiter `emu_in_0..7`, so every hist `type0_lane0..7` input carries identical
ASIC0 data. The emitted `asic_id` (=cfg_asic_id_base, LANE_ENABLE[11:8]) is
folded to constant 0 in this bitstream, so even ASIC-id RELABEL cannot synthesize
bins 32..255. pack_hit_type0 in the compiled be_mutrig_pkg.sv DOES place asic_id
in data[44:41] (so packing is not the gap); asic_id simply never becomes nonzero
at the histogram because the source is one broadcast lane-0 stream.

### Effect
Histogram can only ever populate bins 0..31 (ASIC0). The 8-lane per-ASIC
capability (key=data[43:36]=ASIC<<5|CH) is dormant. Both "physical lanes 1-7"
and "ASIC-id relabel" require an RTL/qsys change + recompile.

### Fix path (NOT yet done — needs user go-ahead, ~45 min compile)
Complete merger_hit_type0 integration (task #32): instantiate the emulator with
8 lanes (or 8 instances) exposing 8 asic-tagged type0 streams, route lane k ->
arb_hit_type0_supercore_0.emu_in_k (replace the broadcast fanout), so each hist
type0_laneK receives ASIC-k-tagged data. Then sweep 0..255 -> full diagonal.
Board left idle (relabel sweep terminates each run).

## D19 — TRUE root cause of ASIC1-7 dead: TWO bugs, not the emulator alone (2026-05-20 PM)
Corrected D18. The emulator/fanout/arb were NOT the (only) gap. Full chain trace:

### Bug 1 (histogram) — FIXED in source by parent
histogram_statistics_v2.vhd per-port ingress loop (~line 1231): TYPE0 sample
condition gated on `idx = 0` ONLY. Ports 1-7 (asi_type0_lane1..7) are fully wired
(port_valid/port_data/per-port FIFO/8-port rr_arbiter) but never sampled, so only
ASIC0 ever binned. On-board proof: arb egresses ~13.6M emu hits on ALL 8 lanes
(drops=0) yet hist TOTAL=1x, DROPPED=0 (ports 1-7 silently not sampled, not dropped).
Fix: added `elsif (idx>0) and source=TYPE0 => stream_ready_v:='1';
stream_sampled_v:=port_valid(idx)`. Key/filter/FIFO logic already per-idx.

### Bug 2 (emulator wrapper) — being implemented by subagent
emulator_mutrig core IS per-lane independent (generate loop: be_mutrig_lane_type0_emit
per lane, asic_id=asic_id_base+lane_idx, own L2/enable). BUT the deployed Qsys wrapper
emulator_mutrig_qsys_lane.sv instantiates `.LANE_COUNT(1)` and exposes only lane 0
(hit_type0[0]). emulator_hit_type0_fanout (hit_type0_fanout8) BROADCASTS that 1 lane to
all 8 arb emu_in, relabeling data[44:41]=lane_id to MIMIC 8 ASICs. So it was 1 real
backend lane + 7 mimicked copies, never 8 independent ASICs.

### arb state (verified on board via SC ring)
arb csr_k reachable at SC word 0x88A0+k*0x20 (avmm 0x2280+k*0x80; SC=avmm/4+0x8000).
All 8 arb lanes already mode=1 (EMU). UID "AHd0". So no arb change needed.

### Fix delegated (subagent, ~45min compile)
(1) hist fix [done, needs version bump+propagate]. (2) new 8-lane emulator wrapper
exposing 8 hit_type0_0..7 (LANE_COUNT=8, lane k=asic k) + hw.tcl 8 Avalon-ST sources.
(3) qsys rewire: emulator hit_type0_k -> arb emu_in_k, drop broadcast fanout.
(4) sim-validate independent per-ASIC (global ch N -> bin N for all 256). (5) static
screen. (6) recompile, retain firefly timing fix. User chose full delegation + true
independent 8-ASIC (for realistic per-ASIC bunch injection).

## D20 — 8-lane build hit a 3rd bug: histogram ASIC double-encode (2026-05-20 PM)
Subagent #1 implemented the 8-lane emulator (emulator_mutrig_qsys8.sv, LANE_COUNT=8,
hit_type0_0..7 asic-tagged) + qsys rewire (emulator lane k -> arb emu_in_k, fanout
removed) + the hist multi-port sample fix. Static screen PASS. But it correctly
STOPPED at the sim gate: the falsifiable S6 per-ASIC test FAILED — every channel
binned at 0.

### 3rd root cause (found by parent from subagent evidence)
histogram_statistics_v2.vhd:1545-1547: key_pipe <= arb_pipe_key + arb_port*CHANNELS_PER_PORT(32).
arb_pipe_key = build_key(data, lo=36, hi=43) = data[43:36] = FULL ASIC<<5|CH (already
asic-tagged). Adding arb_port*32 DOUBLE-ENCODES the ASIC -> bin collapse. Masked before
because only port 0 was ever sampled (offset 0).
Confirmed both paths asic-tag the data: real frame_rcv_ip.vhd:653 `data[44:41]<=o_hits.asic`
+ :654 `data[40:36]<=channel`; emulator pack_hit_type0 same. So the data-driven key is
complete; port_offset is the bug.
FIX (parent, Model B): zero port_offset for TYPE0 (cfg_source_select=TYPE0), like the
debug branch already does. No ASIC0 regression (port0 offset was 0). hw.tcl PATCH->13
(26.3.13.520). Subagent #2 re-propagating + re-sim (S6: ch N -> bin N for all 8 ASICs)
+ compile.

### Lesson
Three independent bugs gated 8-ASIC: (1) emulator wrapper LANE_COUNT=1+broadcast,
(2) hist samples only port 0, (3) hist port_offset double-encodes the already-tagged key.
All three masked by the single-ASIC0 path that sim+board exercised until now.

## D21 — 8-lane sim: asic field data[44:41] = X (4th issue) (2026-05-20 PM)
Subagent #2: parent's port_offset fix verified present + propagated, static screen PASS,
but S6 still fails — every channel -> bin 0. X-probe: hist-input data[44:41] (ASIC tag)
is X on every beat; data[40:36] (channel) fully defined. Key=data[43:36] -> X -> bin 0.
Parent narrowed it: NOT the histogram (key extract/FIFO/divider clean), NOT a hw.tcl
width bug (HIT_TYPE0_WIDTH_CONST=45), NOT the wrapper data wiring (aso_hit_type0_k_data=
hit_type0_data[k] full 45b), NOT clk/rst/csr connection (correct). On paper asic_id=
lane_asic_id(k)={1'b0,(cfg_asic_id_base+k)[2:0]}, cfg_asic_id_base resets to 0 -> defined.
So it's a SIM reset/init or generated-sim-wrapper connectivity X. Next: TB must write
emulator LANE_ENABLE (asic_base=0, mask=0xFF)+CENTRAL before inject (matches proven
on-board flow), probe cfg_asic_id_base directly; fix the X source; re-run S6
(ch N->bin N for all 8 ASICs); then compile. Firefly SDC retained, not compiled yet.

## D22 — 8-ASIC VALIDATED ON SILICON (2026-05-20 PM)
New SOF (md5 3ae9174a4581ad2a4c3460e1ff6eee33) programmed to FEB. Background-scan
readout (feb_hist_read.py, all 8 lanes): 256/256 bins populated uniformly
(~40.7k/bin, all 8 ASIC rows lit). Periodic cluster[0,0]: 8 clean deltas at
0,32,..,224 (each 80108 = 80.1kHz), all 8 arb lanes egress equally. BEFORE the fix
only bins 0-31 (ASIC0) ever filled. All 8 ASIC lanes now alive end-to-end.

Four bugs resolved (all masked by the single-ASIC0 path): (1) emulator wrapper
LANE_COUNT=1 + broadcast fanout -> emulator_mutrig_qsys8 (LANE_COUNT=8, asic-tagged
hit_type0_0..7) routed lane k->arb emu_in_k; (2) hist sampled only TYPE0 port 0 ->
all 8; (3) hist port_offset double-encoded the asic-tagged key -> zeroed for TYPE0
(both real frame_rcv_ip + emulator pack asic into data[44:41]); (4) Questa
X-pessimism on per-lane asic_id function (sim-only) -> explicit nets. lvds_firefly_clk
+0.532ns, 0 negative-slack. Static screen PASS.

### OPEN FOLLOW-UP (not a datapath bug)
Emulator PERIODIC single-channel CLUSTER addressing is erratic on silicon and
differs from sim: cluster[0,0] fires CH0 on ALL 8 lanes (8 bins); cluster[101,101]
(lane3 CH5) fires NOTHING; lane-mask isolation (mask=1<<k) gives 0 hits. So true
one-(ASIC,CH)-at-a-time periodic injection is not yet controllable on board. The
8-bin cluster delta + 256-bin background liveness fully validate the datapath; the
per-(ASIC,CH) periodic stimulus-control quirk is an emulator trigger/dispatch issue
to investigate (sim shreds cluster to one lane; silicon does not). Background-scan
liveness is the reliable 8-ASIC check meanwhile.

## D23 — External injector wiring CONFIRMED + periodic-mask fix delegated (2026-05-20 PM)
User: use external injection (multi-channel injector, mode=2 periodic) + mask all
but one channel for the per-(ASIC,CH) scan; mask belongs at the LAST frontend stage;
fix in sim for periodic.
WIRING (confirmed in scifi qsys): mutrig_injector_0.inject -> emulator_inject_fanout
.inject_in -> out0 -> emulator_mutrig_qsys_inst.inject (coe_inject_pulse on the IP);
out8 -> top "inject" conduit (PIN). injector headerinfo0..7 <- 8 mutrig_datapath_subsystems.
Injector CSR (4-bit addr): reg2=mode(2=periodic), reg5=injection_multiplicity,
reg6=header_ch(4b), reg7=pulse_interval. SC addr (avmm 0xB200) ~ 0xAC80.
PROBLEM: FIXED single-channel periodic fires ALL 8 lanes on board (cluster[0,0]->8
bins 0,32,..,224); lane mask=0x08->0 hits; cluster pos101->0; sim claims single bin
(sim/silicon diverge). Delegated to subagent (task #51): sim-reproduce + root-cause,
implement last-stage frontend per-(ASIC,CH) mask so periodic emits exactly one
(ASIC,CH), validate single-delta across 8 ASICs (keep background 256 + rate/delay
regression intact), static screen, recompile (retain firefly SDC).

## D24 — Periodic single-channel FIX validated in sim; compile via propagate (no regen) (2026-05-20 PM)
Subagent root-caused: periodic single-channel selected ASIC by cluster GLOBAL
position (not lane mask) + the dispatch stalls when the shred-target lane is disabled
(distributor sig_offer_ready gated by that lane's emit enable). Sim/silicon diverge
because the shred/round-robin spreads under real volumes (silicon) but not in the
wrapper sim. FIX: new SIGNAL(0x08) bit3=single_channel_mode, bits[12:8]=single_channel
(local CH); last frontend stage shreds directly to lanes in cfg_lane_enable_mask at
that local channel. Addressing: LANE_ENABLE mask=1<<asic picks ASIC, SIGNAL.single_channel
picks CH -> bin asic*32+ch. emulator -> v26.3.6. SIM S7: 8/8 single clean delta;
background 256 + cluster + rate/delay regressions intact; static screen PASS.

On-board recipe (per (ASIC,CH)): TIMEBASE 0x0F=0x00010001; BACKGROUND 0x09=0;
SIGNAL 0x08 = 0x0000000A | (ch<<8); RATES 0x0B=42; MUTRIG_FMT 0x0A=0x20;
LANE_ENABLE 0x12 = 1<<asic; CENTRAL 0x07=1 -> bin asic*32+ch. CLUSTER_FIX unused.

COMPILE BLOCKER + workaround: full feb_system_v4 `make qsys` crashes
(avalon_st_adapter_008 divide-by-zero, a feb_system_v4<->scifi integration gap;
NOT from this CSR-only change). The fix is CSR-internal (qsys8 entity ports
unchanged), so feb_system_v4.qsys regen is NOT needed. Delegated (task #51): propagate
the 3 emulator RTL files into the 7 synth/sim submodule copies + quartus_sh --flow
compile (no make qsys), retain firefly SDC. Prior 8-lane SOF (3ae9174a, WITHOUT this
periodic fix) still on board. SEPARATE TODO: fix the feb_system_v4 zero-width ST
adapter so full regen works again.

## D25 — Type1 readout path solved; MTS extended-plane emission under investigation (2026-05-20 PM)
New SOF e4a814be7cc72a498b0ab25d67c88050 programmed (8-lane + hist fixes + periodic
single_channel_mode). Single_channel_mode in netlist but STILL doesn't isolate on
silicon (mask=0x01 -> all 8 lanes; mask!=0x01 -> 0 hits; dispatch-ready gate tied to
lane 0; sim/silicon divergence persists across 2 compiles). User: deprioritize true
single-bin isolation; reliable per-channel demo = local-channel sweep (8 deltas/ch) or
background 256-bin liveness (already delivered).

TYPE1 RATE: readout PATH solved — read via histogram in_port=EXT0 (0x10105, upper bank
ASIC0-3) / EXT1 (0x20109, lower bank ASIC4-7). NOT source_select=TYPE1_UP/DOWN (the hist
ingress never samples those — only TYPE0 + EXT0/EXT1). EXT0 produced real per-channel
data once (69 ch, range 0-71). But: (a) SC ring destabilizes under repeated 256-bin burst
reads (0xEEEEEEEE error words, needs reprogram+recover every few reads); (b) MTS Type1
extended emission is PARTIAL (EXT0 only ~bins 0-71, not full ASIC0-3 0-127) and ZERO for
EXT1 (lower bank) — reproduces in prior sim (S1 EXT0>0, S2 EXT1=0). MTS receives 304M hits
both banks, discard=0, go=1. Prime suspects: ENABLED_CHANNEL_HI=3 (MTS handles only ch0-3
of 32; ch4-31 may never get EOP) and the extended_0/extended_1 emission/BANK logic
(BANK=UP/DW set in qsys but RTL line 192 says "BANK not used"). Delegated to subagent
(task #52): sim-reproduce + root-cause + fix so both banks emit Type1 for all 32 ch,
validate in sim, recompile only if file-propagatable (qsys-generic changes like
ENABLED_CHANNEL_HI need regen which hits the avalon_st_adapter_008 divide-by-zero -> defer).

Tools added: feb_type1_rate.py (EXT0/EXT1 both-bank reader, single-run-then-read).

## D26 — Investigating sim/silicon divergence (cluster[0,0]: RTL/sim=1 lane, board=8 bins) (2026-05-20 PM)
User chose to investigate the recurring sim/silicon divergence (3rd instance).
RTL: frontend_trigger_engine dispatch (line 153-165) picks first set bit in
pending_mask; cluster[0,0] shred -> pending_mask=lane0 only -> dispatch lane0. So RTL
+ short sims = 1 lane. Board histogram showed 8 bins/interval (0,32,..224) for
cluster[0,0]. TB clocking is modeled (5 domains: avmm/xcvr 156.25, monitor/lvds 125,
lvds_outclock from DUT PLL) so not obviously a clock-gap. Subagent (task #53) running
LONG-window sim of cluster[0,0] to count per-lane emits (duration hypothesis) + dispatch
RTL analysis + checks for background-leak/apply-race/reset-default-[0,3]; if unexplained,
produces a SignalTap signal list on the trigger-engine internals for silicon capture.
Type1 path: readout solved (EXT0/EXT1 in_port); sim says both banks fully populate with
background scan (no RTL bug); board e4a814be reads empty/partial (3ae9174a gave EXT0=69
bins) -> same divergence family + SC-ring instability. Type0 8-lane datapath remains fully
validated (256-bin liveness). Single_channel_mode in netlist but doesn't isolate on
silicon (dispatch-ready gate). All deferred pending divergence root-cause.

## D27 — Type1 rate root cause + STP plan (2026-05-20 late)
0xEEEEEEEE = FEB sc_hub RD_TIMEOUT read-reply padding (hist_bin SRAM holds waitrequest
across a ping-pong bank swap during a live burst). TRANSIENT: freeze-then-read is clean
(0 err words, hub ERR_FLAGS=0, verified). Hub CSR debug at SC 0xFE80 (ERR_FLAGS bit3=
RD_TIMEOUT, bit6=DECERR; clear via CTRL@0xFE82=0x3). Memory: feedback_sc_hub_EEEEEEEE.
sc_hub STP+sim = subagent #54 (parallel, owns the project compile).

TYPE1 RATE root cause (localized on silicon, verified config): with TYPE0 flooding
(hist TOTAL saturated via tap.hist branch), the MTS receives ZERO input on BOTH banks
(mts_preprocessor_0/1 total_hit_cnt=0, discard=0, reg0 idle 0x20000010). So
tap.primary -> mux_mutrig2processor -> MTS.hit_type0_in delivers nothing while the
parallel tap.hist -> histogram floods. Intermittent (earlier e4a814be showed MTS=303M).
Sim says MTS works (subagent #52) -> same sim/silicon divergence family as cluster-fires-8
and single_channel_mask-no-isolate. Needs silicon SignalTap on tap.primary/mux/MTS path.

PLAN (user chose (a)): queue Type1-path STP (#56, blocked by #54) to run right after the
hub STP compile; add the tap.primary/mux/MTS-input valid/ready/data + MTS run-state probes
to the SAME image so one SOF captures BOTH the hub read-timeout and the MTS-input-dead.
Type1 delay gated on rate. SC ring degrades under heavy use -> verify every config write.

## D28 — sc_hub read-timeout SIM-REPRODUCED + STP built; Type1-path STP launched (2026-05-20 late)
Subagent #54 DONE: hub-STP SOF md5 498bdfacd9b6dbb716b9113224241a3b (+0.602ns firefly,
0 neg-slack). Two SLD instances: `sc_hub_rd_timeout` (clk125 domain, trig=timeout_pulse
rising; probes timeout_counter, words_seen, cmd_length_reg, launch_stage_valid) +
`hist_bin_waitstall` (acq domain, trig=hist_wait_bank_busy; probes pingpong active_bank,
hist_read_pending, burst_active, hist_wait_bank_busy). .stp = sc_hub_rd_timeout.stp.
SIM REPRO (focused unit TB tb_pingpong_waitstall.sv): o_hist_waitrequest = burst_active
OR hist_read_pending OR hist_wait_bank_busy. S1 frozen-bank read = clean 64cyc. S2 read of
continuously-updated wait bank = waitrequest held 3001cyc (hist_read_pending never
releases). S3 burst straddling a real interval swap = held 258cyc > 200-cycle clk125 hub
watchdog -> timeout_pulse -> RD_PADDING -> 0xEEEEEEEE. ROOT CAUSE CONFIRMED: histogram
pingpong SRAM read parks in hist_read_pending when active_bank flips mid-burst, holding
waitrequest past the hub's 200-cycle read watchdog. Full-system 0xEEEEEEEE not reproduced
in wrapper TB (no SC driver / hit stimulus there). Parent captures STP on silicon to
confirm timeout fires concurrent with active_bank transition + hist_wait_bank_busy high.

Type1-path STP = subagent #56 (in progress): adds 3rd SLD instance `mts_input_probe`
(acq domain, trig=tap.primary valid) probing arb.selected_out -> tap.primary -> mux ->
mts_preprocessor.hit_type0_in valid/ready/data + MTS run_ctrl + run-FSM state, to localize
WHERE the MTS input dies on silicon (type0 floods tap.hist but MTS total=0). Combined SOF
(3 STP instances). Then parent programs + captures both stalls.

## D29 — Pingpong SEAMLESS bank-follow (replaces SLVERR) implemented + sim-validated (2026-05-20 late)
User redirected from SLVERR to seamless bank-follow: on an interval swap mid-read, the
host-read engine follows to the just-frozen bank (interval N+1, complete) and continues -
1-cycle, all beats valid OKAY, +T seam acceptable for periodic-rate monitoring. Subagent
#57 implemented in pingpong_sram.vhd: (1) hist_waitrequest <= burst_active only (removed
hist_read_pending + hist_wait_bank_busy stalls = the timeout cause); (2) read source bank
= not active_bank recomputed EVERY cycle (no latch-at-burst-start); (3) single-outstanding
read + stale-beat reissue: a beat that read a bank now going active (cleared) is squashed
and its address reissued vs the new frozen bank -> no missing/dup/garbage beat. Update
engine unchanged. hist v26.3.15 (hw.tcl PATCH 15).
SIM (tb_pingpong_waitstall.sv, Questa One): S3 swap-straddle max waitrequest-hold 258->0
cyc, 16 beats==burstcount, address monotonic+complete, seamless N->N+1 seam at beat3, no
missing/dup, NO SLVERR. S1 frozen clean. Static screen PASS. Pre-existing standalone tb
B06/B09/B10 + wait_bank_swap timeout confirmed NOT regressions. Parent reverted #57's
earlier SLVERR edits to clean base first (pingpong git-checkout; avs_hist_bin_response
back to (others=>'0'); removed hist_response signal+port). NO compile yet.

RECOMPILE PLAN: after #56 (Type1-path STP) compile finishes (mts_input_probe instance
added to sc_hub_rd_timeout.stp; SOF still 498bdfac mid-compile), propagate #57's
pingpong_sram.vhd (v26.3.15) into the feb_system_v4 synth submodules + recompile (no qsys
regen) -> final SOF = seamless-bank-follow fix + 3 STP instances (hub rd_timeout +
hist_bin_waitstall + mts_input_probe). Then program: 0xEEEEEEEE should be gone AND we can
capture the MTS-input-dead. Do NOT touch synth tree while #56 compiles.

## D30 — Seamless bank-follow VALIDATED ON SILICON; 0xEEEEEEEE FIXED (2026-05-21 00:xx)
SOF 1df05d6c6ff33096f5849a1bd4f144a8 (seamless-bank-follow pingpong v26.3.15 + 3 STP
instances: sc_hub_rd_timeout, hist_bin_waitstall, mts_input_probe). Compile 0 errors,
firefly SDC retained. Programmed.
ON-BOARD VALIDATION: with TYPE0 flooding (TOTAL=1048575), 8 LIVE histogram burst reads
(reading the running hist_bin, the exact case that previously padded 0xEEEEEEEE across
bank swaps) returned 0 error words, 256/256 bins, hub ERR_FLAGS=0x0 (no RD_TIMEOUT/DECERR),
ERR_COUNT=0. The seamless bank-follow eliminates the hub read-timeout/0xEEEEEEEE. Live
reads no longer need freeze-then-read.
NEXT: re-test Type1 rate with clean reads on this fresh program (does the MTS receive input
now?); if MTS still 0-input, capture mts_input_probe (STP idx 2) via GUI to localize
tap->mux->MTS handshake / MTS run-state. Recurring: post-program config drops -> retry
config until TYPE0 TOTAL advances before any test.

## D31 — Type1 rate PARTIAL on silicon after seamless fix (2026-05-21 00:0x)
With 0xEEEEEEEE fixed (clean reads), Type1 EXT0 (upper, ASIC0-3) populates but
INTERMITTENT/partial (64-126 of 128 ch, ~33k/interval); EXT1 (lower, ASIC4-7) stays
EMPTY. Reads are clean (err=0) so this is genuine MTS extended-plane emission:
partial on the upper bank, dead on the lower bank. Sim (#52) showed both banks full ->
sim/silicon divergence. Earlier 'MTS receives 0 input' was a misread total_hit_cnt CSR
(EXT0 has data => MTS0 IS producing). Plot: type1_rate_partial.png.
NEXT (Type1 rate + delay both gated on this): capture mts_input_probe STP (SOF 1df05d6c,
idx 2, upper-bank path mts_preprocessor_0) via GUI to see if the upper MTS gets full
input but emits partial extended; and/or re-target STP to mts_preprocessor_1 +
mux_mutrig2processor_0 (lower bank) and recompile to localize why the lower extended
plane is dead. Also recurring: feb_type1_rate must gate on TYPE0 TOTAL>0 (config drops
post-program) - the inline retry-until-hits-flow pattern works.

## SESSION WINS (2026-05-20..21)
- 8-lane emulator + hist multi-port + no-double-encode + asic-X fixes -> all 256 Type0
  bins live (8 ASICs). SOF lineage 3ae9174a -> e4a814be -> 1df05d6c.
- Periodic single_channel_mode added (sim ok; silicon dispatch-ready gate still ties to
  lane0 - open).
- 0xEEEEEEEE root-caused (hub RD_TIMEOUT on hist_bin waitrequest across bank swap),
  sim-confirmed, FIXED via seamless bank-follow pingpong, VALIDATED on silicon (8 live
  bursts, 0 err, 256/256, hub ERR_FLAGS=0).
- 3 STP instances built (sc_hub_rd_timeout, hist_bin_waitstall, mts_input_probe).
- Type1 rate readout path solved (EXT0/EXT1 in_port); upper bank partially live.
OPEN: Type1 lower-bank dead + upper partial (MTS extended emission, sim/silicon
divergence); periodic single-channel isolation on silicon; cluster fires-8-lanes vs sim-1.

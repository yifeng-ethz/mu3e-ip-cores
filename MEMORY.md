# MEMORY.md - mu3e-ip-cores operational notes

This file is project-scoped persistent memory. It records workflow lessons that
save compile and hardware iteration time. Formal contracts still live in
`AGENTS.md` and `firmware_builds/doc/*.md`; if this file conflicts with a
test plan, follow the test plan and update this file.

## Phase 5 FEB SciFi timing, SignalTap, and board lessons - 2026-04-29

Primary evidence:
`firmware_builds/systems/system_20260427_testplanphase5/reports/phase5_nostp_pipe_rebuild_datapath_followup_20260429.md`.

### Tools and fast path after FEB programming

- Serialize hardware access. Do not run `quartus_pgm`, `quartus_stp`, and board
  scripts against the same JTAG/SC path concurrently.
- Treat Mu3e online software as reference-only. Do not trust `rw`,
  `swb_dmatest`, MIDAS, `libmudaq`, or production cleanup flows for closure;
  use repo-owned direct tools under `tools/` and keep their raw-register and
  disk artifacts.
- Program the FEB image with `quartus_pgm`; then recover the SWB PCIe path with
  `sudo -n /usr/local/sbin/mudaq_recover_pcie` before trusting `/dev/mudaq0`.
- Run `rc_tool stop-reset --device /dev/mudaq0 --feb 7 --settle-us 5000`.
  Expected echo is `0x31`.
- Run `check_sc_bridges.py --link 2 --skip-jtag --json`. If a quiet histogram
  UID read fails once after reprogramming, retry only the UID with bounded
  verbose `sc_tool 2 read 0x0A900 4`; expected payload word is `0x48495354`.
  Then rerun the bridge check.
- Run `check_environment_monitors.py --link 2 --onewire-settle-seconds 3`.
  The accepted 2026-04-29 gate was 62 PASS / 1 WARN / 0 FAIL: OneWire UID
  `0x4F574D43`, all six temperatures live and not stuck at 1 C, Firefly 1 live,
  and Firefly 2 correctly absent/sentinel.
- If the SWB has been used or reprogrammed by another agent, reprogram/recover
  before trusting stale counters. Expected good behavior is `/dev/mudaq0`
  present, reset echo `0x31`, SC-hub error/drop flags zero, and histogram/MTS/
  frame counters advancing together.

### Compile settings that worked

- Quartus 18.1 Standard, revision `top_nostp_pipe`, command:
  `quartus_sh --flow compile top -c top_nostp_pipe`.
- QSF settings used by the working no-STP and STP revisions:
  `OPTIMIZATION_MODE BALANCED`, `FITTER_EFFORT "STANDARD FIT"`, `SEED 4`,
  `ALLOW_REGISTER_DUPLICATION ON`, `OPTIMIZE_MULTI_CORNER_TIMING ON`,
  `ROUTER_LCELL_INSERTION_AND_LOGIC_DUPLICATION AUTO`,
  `ROUTER_REGISTER_DUPLICATION AUTO`, and `ADVANCED_PHYSICAL_OPTIMIZATION ON`.
- The timing-clean no-STP rebuild programmed checksum `0x13C7FEDB`, compiled in
  00:45:40 with 0 errors / 1731 warnings, used 63,112 / 91,680 ALMs (69%),
  82,925 registers, and 546 / 1,366 RAM blocks. STA passed with slow 85 C WNS
  `+0.080 ns`, LVDS `pll_sclk` setup slack `+0.216 ns`, and all shown TNS
  `0.000`.
- Practical margin rule from this iteration: WNS around `+0.05` to `+0.10 ns`
  with all relevant TNS at zero is acceptable for board-debug iteration on the
  exact compiled image. Prefer at least `+0.20 ns` WNS for a comfortable
  non-debug baseline. Any negative-WNS image is debug-only, not a soak/signoff
  image.
- 2026-04-30 FEB/Arria V clarification: a directed debug image with setup WNS
  inside roughly `-0.200 ns` is acceptable when the worst paths are understood
  and not part of the ambiguous/collective performance signal being judged.
  Mark it debug-only. This exception does not apply to the SWB Arria 10 path;
  the SWB image must close timing in all checked corners before its evidence is
  trusted.

### SignalTap complexity guidance

- Use the no-STP timing-clean image for soak and signoff claims.
- The injector micro STP profile is the largest timing-clean profile proven in
  this round: 31 requested probes, 95/95 post-map pins, slow 85 C WNS
  `+0.337 ns` overall / `+0.447 ns` LVDS, and all listed TNS `0.000`.
- The compact injector STP profile before the histogram timing fix had 84
  requested probes and 201/201 connected pins but failed STA. Rebuild/check it
  from the current timing-clean database before programming.
- The frame/MTS/histogram STP profile with 1180/1180 probes is useful for local
  debug but not timing signoff; it had slow 85 C WNS `-0.860 ns` on LVDS.
- The run-control/MTS-stage hit-error debug image, checksum `0x145AA92C`, had
  WNS `-0.109 ns` and is also debug-only. It was enough for a directed trigger
  timeout proof, not for closure.
- Runtime trigger edits are cheap only when the tap list, order, storage depth,
  and clock are unchanged. New taps, changed width/depth, or changed capture
  clock require Node Finder validation, STP import, full compile, and a fresh
  programmed image.

### Timing-closure tricks to try next

- Add false paths or clock-group constraints scoped to SignalTap/SLD capture
  paths so debug instrumentation does not dominate functional hardware timing.
  Keep the exception scoped to the debug instance; do not hide real CDC,
  exported interfaces, or datapath boundaries.
- Use formal reachability checks for suspected rare blocker states. Insert a
  small cover property at the interface or inter-module boundary and ask the
  tool whether the failing case can happen at all before spending another
  board compile. For states that should be impossible by contract, write the
  environment assumptions and the matching assertion together; this applies to
  internal module-to-module handshakes as much as explicit SystemVerilog
  interfaces.
- Try Quartus design partitions or incremental block design to reduce debug
  compile time. Periodically run a full clean compile anyway; stale partitions
  can preserve old congestion and make routing worse after enough design drift.
- For very wide STP scopes, generate a truncated Qsys/debug design that is
  isomorphic at the tested boundary and mirrored in `tb_int` agents and
  scoreboards. Treat the truncated design as a debug derivative only; closure
  evidence still needs the authentic FEB firmware and the authentic `tb_int`
  boundary behavior.
- Start with SC counters and small STP profiles. Escalate to broad STP only
  after source mux, run-control, SC bridge, environment, and reset gates pass.

### Known failure boundaries

- The stale no-STP checksum `0x13B82BDB` was misleading: emulator frames
  advanced but MTS/histogram stayed zero, and mixed real lanes 0/3 had selected
  source-mux beats but zero frame/MTS/histogram deltas. Rebuild before debugging
  RTL if checksum/source age is suspect.
- For Phase-5 histogram closure, quick iteration can use direct SC-hub CSR
  reads through `run_phase5_histogram_matrix.py`; final closure still needs the
  System Console screenshot plus the raw CSR/bin dump and matching authentic
  `tb_int` run.
- The 2026-04-29 hist-merge image proved lower lane rate visibility but exposed
  a separate delay-debug gap: lane4 emulator 100 kHz/10 kHz rate passed
  (`264932` / `26662` hits, ratio `9.94`), lane0 delay-debug passed
  (`262220` hits), and lane4 delay-debug failed cleanly (`hist=0` while MTS
  advanced). Root cause: only `mts_preprocessor_0.ts_delta` was wired to
  `histogram_statistics_0.debug_1`; lower `mts_preprocessor_1.ts_delta` was
  open. The 2026-05-01 pipe regeneration fixes this class for simulation:
  debug_1 is upper MTS delta, debug_2 is lower MTS delta, and the rate path has
  a lower pre-RBCAM splitter feeding `histogram_ingress_bridge_1`.
- For regenerated Qsys scripts in this worktree, use an isolated `HOME` and an
  explicit search path that starts with
  `run-control_mgmt/reference/feb_system_v2_snapshot_20260415` and the active
  source-IP directories. Do not let the normal global catalog select the dirty
  base checkout `mutrig_timestamp_processor` 26.0.9 when the worktree expects
  26.0.8; that produces a plausible but untrustworthy generated system.
- A 1 s rate PNG is not automatically evidence. The 2026-05-01 rate plot was
  rendered correctly but all `647881` hits landed in bin 0. Treat any
  collapsed-bin/all-one-ASIC rate shape as an observation bug until a mask
  sanity check proves masked channels vanish and all active ASICs distribute
  into the expected global `{ASIC, channel}` bins.
- If the emulator path passes but the real path is zero, suspect MuTRiG XML/SPI
  configuration, LVDS lane training, physical lane mapping, or frame-deassembly
  lock/errors before changing histogram/MTS logic.
- If real traffic reaches MTS/histogram but MTS discard or ring error counters
  increment, inspect `mutrig_frame_deassembly` error outputs first. The previous
  discard symptom was already visible upstream as `aso_hit_type0_error[*]`.
- 2026-04-30 Phase-6 lower-side update: on the timing-clean no-STP image,
  ASIC5/lane5 and ASIC6/lane6 each pass one-channel pulse-high 4 alone, but
  the two real lanes together fail with MTS-forwarded ring input errors and
  zero LVDS error/DPA-unlock deltas. ASIC6 `ext_trig_offset=0..15` did not
  clear the pair. A two-lane emulator reference through the same lower MTS/ring
  path passes after 50 ms post-sync/pre-inject settle. Treat the current
  blocker as real MuTRiG cross-ASIC timestamp/epoch/order coherence before
  or inside lower MTS, not LVDS training or SWB/DMA.
- Do not claim full Phase-5 real-source closure until lanes 1/2/4/5/6/7 are
  recovered or explicitly waived in the scoreboard.

# MUTRIG.md - MuTRiG3 configuration and lock notes

Date: 2026-04-29

## Physical Mapping

- SMB3 is the upper side and maps to lanes 0..3.
- SMB5 is the down side and maps to lanes 4..7.
- Each SMB carries four MuTRiG3 ASICs.
- Each MuTRiG3 ASIC uses one 1.25 Gbps LVDS link into the FEB.
- The FEB datapath keeps two hit-stack subsystems, one per SMB.

## Configuration Flow

The MuTRiG Controller IP does not parse human configuration files. Host
software converts `.txt` or `.xml` ASIC settings into an SPI bitmap and a simple
write/toggle sequence for the controller.

Use these configs as known references:

| Mode | SMB | Config |
|---|---|---|
| TDC injection | SMB3 | `board_test_system/trash_bin/good_ribbon_0/config_smb3_tdc.txt` |
| TDC injection | SMB3 | `board_test_system/trash_bin/ribbon_eth_0/config_smb003_tdc_all_OK.xml` |
| TDC injection | SMB5 | `board_test_system/trash_bin/good_ribbon_0/config_smb5_tdc.txt` |
| Analog frontend | SMB3 | `board_test_system/trash_bin/good_ribbon_0/config_smb3_ana_asic-0123.txt` |
| Analog frontend | SMB5 | `board_test_system/trash_bin/good_ribbon_0/config_smb5_ana_alt-asic2-fineTune.txt` |

### ASIC/XML Mapping Contract

Each SMB configuration file describes exactly four MuTRiG ASICs, with local
`<mutrig><index>` values `0..3`. Do not apply one SMB file to all eight ASICs.
The host-side ASIC map is:

| Global ASIC | Physical side | Config file | Local XML index | LVDS lane |
|---:|---|---|---:|---:|
| 0 | SMB3 upper | `config_smb3_tdc.txt` | 0 | 0 |
| 1 | SMB3 upper | `config_smb3_tdc.txt` | 1 | 1 |
| 2 | SMB3 upper | `config_smb3_tdc.txt` | 2 | 2 |
| 3 | SMB3 upper | `config_smb3_tdc.txt` | 3 | 3 |
| 4 | SMB5 down | `config_smb5_tdc.txt` | 0 | 4 |
| 5 | SMB5 down | `config_smb5_tdc.txt` | 1 | 5 |
| 6 | SMB5 down | `config_smb5_tdc.txt` | 2 | 6 |
| 7 | SMB5 down | `config_smb5_tdc.txt` | 3 | 7 |

The Phase-5 config runner implements this as `local = asic % 4`, selecting the
SMB3 XML for ASICs `0..3` and the SMB5 XML for ASICs `4..7`. For full 256-channel
TDC injection, use all eight ASICs plus all 32 channels per ASIC:

```text
--configure-asics 0-7 --channel-enable-mask 0xffffffff --tdctest-channel-mask 0xffffffff
```

That command only overrides per-channel `mask` and `tdctest_n` inside each
ASIC's local XML entry. It must not change the SMB3/SMB5 file split.

Always configure MuTRiG from the `IDLE` run-control state: issue `reset`,
`address`, and `stop-reset`, load the ASIC XML/SPI bitmap, then enter data
taking through the full `run-prepare`, `sync`, `start-run` sequence. Do not use
an isolated `RUN_PREPARE` toggle from `IDLE` as a shortcut to `RUNNING`;
skipping `RUN_SYNC` leaves counter-clear behavior ambiguous, so the following
rate or delay histogram is not valid Phase-6 evidence.

After every MuTRiG load/loss configuration for TDC injection, run the channel
CML charge flush before taking data:

1. Load the intended ASIC XML/SPI bitmap with the selected channel mask,
   `tdctest_n=0`, PLL/TDC tuning, and channel `cml=0`, `cml_sc=0`.
2. Reload the same selected ASICs/channels with channel `cml=8` and
   `cml_sc=0`.
3. Reload the same selected ASICs/channels with channel `cml=0` and
   `cml_sc=0`, then enter `run-prepare`, `sync`, and `start-run`.

This flush removes residual charge between the digital and analog sides so the
TDC-injection interception line responds uniformly. Repeat it after any FEB
reconfiguration or other MuTRiG clock/configuration loss.

Current `good_ribbon_0` TDC XML PLL-search defaults are:

| ASIC | SMB | Local index | `cnt` | `vcodelay` | `hitlogic` | `cnt/vcodelay/hitlogic` offsets |
|---:|---|---:|---:|---:|---:|---|
| 0 | SMB3 | 0 | 48 | 20 | 30 | `3/3/3` |
| 1 | SMB3 | 1 | 43 | 30 | 30 | `3/3/3` |
| 2 | SMB3 | 2 | 45 | 35 | 20 | `3/3/3` |
| 3 | SMB3 | 3 | 41 | 10 | 20 | `3/3/0` |
| 4 | SMB5 | 0 | 43 | 15 | 20 | `3/3/3` |
| 5 | SMB5 | 1 | 42 | 20 | 25 | `3/3/3` |
| 6 | SMB5 | 2 | 37 | 27 | 15 | `3/3/3` |
| 7 | SMB5 | 3 | 40 | 20 | 25 | `3/3/0` |

If either XML file is retuned, regenerate this audit before interpreting
lane-by-lane PLL or timestamp-delay evidence. A copied upper-side config on the
down side is a bad test: it can make the SPI transaction pass while the physical
ASIC tuning is wrong.

The current Phase-6 restore-load tuning ledger is:

| ASIC | Default `cnt/vcodelay/hitlogic` | Restore-load `cnt/vcodelay/hitlogic` | Extra diagnostic setting | Evidence |
|---:|---|---|---|---|
| 0 | `48/20/30` | `48/20/40` | none | `phase5_mutrig_restore_full32_tuned_baseline_20260430e.json` |
| 1 | `43/30/30` | `43/30/30` | none | `phase5_mutrig_restore_full32_tuned_baseline_20260430e.json` |
| 2 | `45/35/20` | `40/30/30` | none | `phase5_mutrig_restore_full32_tuned_baseline_20260430e.json` |
| 3 | `41/10/20` | `35/12/25` | none | `phase5_mutrig_restore_full32_tuned_baseline_20260430e.json` |
| 4 | `43/15/20` | `43/15/20` | none | `phase5_mutrig_restore_full32_tuned_baseline_20260430e.json` |
| 5 | `42/20/25` | `52/18/25` | production-lapse still splits; bypass-lapse gives a one-bin head-sync delta | `phase6_headsync_lane5_cnt52_vcd18_bypasslapse_jtag_nodisplay_20260501.csv` |
| 6 | `37/27/15` | `37/27/15` | default production-lapse gives a one-bin head-sync delta | `phase6_headsync_lane6_default_jtag_nodisplay_20260501.csv` |
| 7 | `40/20/25` | `30/14/40` | none | `phase5_mutrig_restore_full32_tuned_baseline_20260430e.json` |

Per-ASIC head-sync delay histogram artifacts are now tracked for ASIC5 and
ASIC6 in `reports/assets/phase5_mutrig_tuning_20260430/`; ASICs 0..4 and 7
still need the same plotted treatment before all-eight-ASIC tuning closure. The
required artifacts for the remaining tuning pass are one plot per ASIC under
`reports/screenshots/phase6_mutrig_headsync_YYYYMMDD/`, named
`asicN_cntC_vcodelayV_hitlogicH.png`, plus the matching JSON/Markdown manifest.
Do not replace these with the stale `vco000` captures; those are invalidated as
PLL-lock evidence by the zero-vcodelay rule below.

### Active Phase-5 Injection Path

For `system_20260427_testplanphase5`, the physical MuTRiG injection pins are
driven from `feb_inject_pulse` in top-level RTL:

- `src/top.vhd`: `scifi_inject`, `scifi_inject2`, and `scifi_ainj` are driven by
  `feb_inject_pulse`
- `src/wrappers/feb_system_v3/feb_system_pipe_top.vhd`: `o_inject_pulse` drives
  `feb_inject_pulse`
- `syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem.vhd`:
  `mutrig_injector_0` drives `emulator_inject_fanout`, whose out8 pulse drives
  the exported physical `inject_pulse`

Use the Phase-5 injector CSR path for external 100 kHz tests. In the current
board-test scripts this is `mutrig_injector_0` at SC word base `0x0AC80`, with
periodic mode `2`, interval `1250` cycles, and the mode register forced back to
`0` after the measurement window.

For real-MuTRiG rate-mode injection, start with `pulse_high_cycles=5`. Treat
the pulse width as a live tuning knob over `1..15` cycles: too short can
underfill channels, while too long can worsen timing sidebands or timestamp
errors. A non-optimal high time can also ring the TDC injection line; some
channels may see two rising edges and report close to twice the intended rate,
or an intermediate overcount if the second edge is marginal. Keep
`pulse_interval=1250` for 100 kHz at the 125 MHz injector clock.

The 2026-05-01 post-histogram-26.1.8 sweep is the current reference for this
board state after all-ASIC CML `0-8-0`:

| `pulse_high_cycles` | 1 s rate behavior |
|---:|---|
| 1..2 | no TDC-test hits |
| 3 | only four channels respond; underfilled |
| 4 | many channels respond but not all; underfilled |
| 5 | all 256 channels respond, aggregate near 100 kHz/channel with one low-rate notch |
| 6..7 | best current plateau: all 256 channels, mean about 99.8 kHz/channel, CV about 0.006 |
| 8 | first clear overcount/ringing sidebands; some channels approach double rate |
| 9..15 | overfilled; many channels approach the double-edge/ringing regime |

Use `pulse_high_cycles=6` or `7` as the current rate-mode starting point, then
verify downstream MTS/RBCAM behavior separately. A flat rate histogram only
proves the MuTRiG TDC-test source; it does not by itself clear the hit
timestamp-delay gate.

For physical mask-response sanity at `pulse_high_cycles=5`, the 2026-05-01
seeded random sweep passed the expected source behavior:

- LVDS-controller ASIC masks remove whole 32-channel global-channel blocks,
  while enabled ASIC bins stay near 100 kHz/channel.
- MuTRiG channel masks, applied identically to all eight ASICs with the CML
  `0-8-0` flush after each reload, remove the repeated per-ASIC channel
  pattern. The enabled-channel totals scale with the requested `11..22`
  channels per ASIC and show zero histogram drops.
- The raw CSV check must compare the observed nonzero global-channel set
  against the intended mask. For the seeded sweep, all `16/16` cases matched
  exactly, every intended off-bin stayed at zero, and every intended on-bin was
  above the 50k-count sanity gate.

This is a source-rate and masking check only. The same high-rate cases can
still expose the separate MTS/RBCAM timestamp/ring-buffer blocker.

### LVDS Controller Register Observability

The active FEB datapath exposes `lvds_rx_controller_pro_0.csr` through the
downstream datapath bridge at SC word base `0x08000`. Use the
`mu3e_lvds_controller` SVD-backed map, not ad hoc word guesses:

| Word offset | Register | Debug use |
|---:|---|---|
| 0 | `capability` | sync pattern and lane count |
| 1 | `mode_mask` | per-lane adaptive alignment (`1`) vs bit-slip (`0`) |
| 2 | `soft_reset_req` | per-lane soft reset request |
| 3 | `dpa_hold` | per-lane DPA hold control |
| 4 | `lane_go` | per-lane enable/readback |
| 5..13 | `error_counter_lane0..8` | decode/parity/fatal training evidence |
| 14 | `lane_selection` | selects the lane for indirect debug reads |
| 15 | `lane_dpa_unlocks` | DPA unlock count for selected lane |

The active Qsys aperture is 16 words. The newer SVD also describes
`lane_word_aligner_chosen` at word 16, but that word is outside the current
`0x0..0x3f` Platform Designer address range and must not be read until the
component aperture is widened and the system is rebuilt.

For live tuning, run the injector sanity path with `--capture-lvds
--read-lvds-dpa-unlocks` or run `phase5_real_mutrig_link_debug.py
--read-dpa-unlocks`. The DPA-unlock probe restores the original
`lane_selection` value after the per-lane reads.

Do not swap in a new LVDS-controller build just because a timestamp error is
visible downstream. First prove whether LVDS error counters or DPA unlocks move
during the failing lower-pair full-channel case. If those counters stay flat
while MTS/ring errors advance, the next debug scope is MTS timestamp/epoch
causality. If LVDS errors correlate, build a Platform Designer A/B candidate
that preserves the old external PHY, `lvds_rx_controller_pro_0.csr` base, lane
streams, clocks, and reset contract before trying any absorbed/full LVDS IP.

Do not use deprecated pulse-control constants such as `0x4502`,
`MUTRIG_CNT_CTRL_REGISTER_W = 0x4100`, `pll_test_mode(0)`, or `o_pll_test` for
Phase-5 injector tests. They are not mapped as the active injector control path
in this Qsys image. A stale or disconnected slow-control address can ACK while
driving no physical MuTRiG injection, which turns a per-ASIC pulse test into a
false zero-hit result.

Important caveat: `config_smb003_tdc_all_OK.xml` is upper-side only. It is fine
for rate and channel alive/dead tests on lanes 0..3, but it does not always
produce a locked PLL. For down-side PLL-lock work, start from the SMB5 TDC
config.

### Phase-5 Tuning Command Controls

Use `configure_mutrig_from_xml.py` for controlled ASIC-by-ASIC perturbations.
The runner keeps the SMB3/SMB5 split above and only changes the selected XML
fields before packing the SPI bitmap.

Useful live-debug switches:

- `--allow-idle-after-config`: accepts final MuTRiG controller status `0` even
  when the frame counter is idle immediately after SPI load.
- `--set-tdc ASIC:FIELD=VALUE`: changes one TDC field for one global ASIC, for
  example `7:vnvcodelay=14`.
- `--set-header ASIC:FIELD=VALUE`: changes one Header field for one global ASIC,
  for example `6:ext_trig_offset=1`.
- `--set-channel FIELD=VALUE`: changes one Channel field on all 32 channels of
  each selected ASIC, for example `recv_all=0`.

For full-channel rate accounting, pass `--real-hits-per-lane 32` to the
Phase-5 injector sanity or matrix runners after loading all 32 TDC-test
channels per ASIC. With the 125 MHz injector clock, 100 kHz is
`--pulse-intervals 1250`.

For the accepted latency gate, pass `--mts-expected-latency 2000
--mts-delay-ts-field t`. A measurement with ring-buffer CAM input latency
outside `0..2000` cycles is rejected even if the hit counters advance.

For images using `mts_preprocessor` version `26.0.9.501` or newer, MTS CSR word
5 exposes `overflow_lookback_8ns`. This is not the accepted-latency gate.
`expected_latency_8ns` still decides whether a hit reaches the ring-buffer CAM;
`overflow_lookback_8ns` only changes the post-wrap epoch/lapse disambiguation
used before that gate. The 2026-05-01 Phase-6 Qsys rebuild stamps both upper
and lower MTS instances with compile defaults `expected_latency_8ns=2000` and
`overflow_lookback_8ns=2000`. Use runtime `--mts-overflow-lookback` only for the
P6-BUG-008 ASIC5/ASIC6 A/B sweep, and keep bypass-lapse as a diagnostic control,
not as a closure setting.

### MuTRiG Wiki References for Tuning

The online wiki is part of the `online_sc` checkout as the `online/wiki`
submodule. The intended path is:

```text
/home/yifeng/packages/online_sc/online/wiki
```

If that path is empty, initialize or update the submodule from the `online`
checkout with Bitbucket credentials. A populated local mirror used for the
2026-04-30 tuning notes is:

```text
/home/yifeng/packages/online_sc/online/wiki
```

Useful wiki pages for MuTRiG3 tuning:

- `mutrig_hitTxData.md`: LVDS hit/scaler frame modes and frame format.
- `mutrig_dmon.md`: digital monitor and TDC-injection signal semantics.
- `mutrig_settings.md`: parameter meanings and MIDAS-to-MuTRiG name mapping.
- `mutrig_clock_reset.md`: clock-domain and reset-tree behavior.
- `mutrig_spi.md`: 2662-bit MuTRiG3 SPI shift-register behavior.

Tuning consequences for Phase-5:

- `tx_mode=4` is short-event transmission. It uses fixed 12.4 us frames and the
  frame header hit counter is the number of real hits in that frame. If a
  100 kHz/channel TDC-injection run does not produce the expected count, inspect
  the MuTRiG frame hit counter and mode before blaming DMA or the FEB ring.
- TDC injection enters through the DMON/TDC-test path. A rising edge on the
  DMON0/Q input creates a timestamp; the DMON1/flag input selects timestamp
  type. With no DMON1 pulse, `recv_all=1` is required to generate a hit for
  each DMON0 rising edge. `recv_all=0` expects an energy/flag relation and is a
  different test, not a fix for full-channel 100 kHz closure.
- For TDC injection, the wiki says to disable channel digital monitoring
  (`dmon_select=-1`, packed as `dmon_sel_enable=0`), enable TDC test input
  (`tdctest_n=0`), and disable the analog frontend path with `cml=0`. It also
  states `cml_sc=1`; the current `good_ribbon_0` TDC XML uses `cml=0` with
  `cml_sc=0`, so audit the packed meaning before making `cml_sc` the next
  hardware lever. Operationally, still perform the post-load CML flush
  (`cml=0`, then `cml=8`, then `cml=0`) before data taking; this is a
  charge-reset step, not a new final analog-mode setting.
- `vnhitlogic` is not an arbitrary noise knob. It biases the TDC hitlogic input
  receiver. Wrong input swing, wrong CML/TDC-test setup, or wrong `vnhitlogic`
  can cause no hits, extra noise hits, or poor timing. Treat it together with
  injection pulse width and CML settings.
- `vncnt=0` belongs to the deliberate no-hit reset/control point together with
  `vnvcodelay=0`; it is not a passable lock setting. Once a lock point exists,
  keep `vncnt` near the ASIC-specific XML/default value and perturb it only as
  a secondary fine-tuning knob.
- `vnvcodelay` tunes the VCO base-current path and is the primary PLL-frequency
  search parameter when the lock point is wrong.
- `ms_limits` and `ms_switch_sel` affect coarse-counter selection from the fine
  counter. Use them only after the basic PLL/TDC-test source is sane; they are
  candidates when delay histograms show side peaks around one coarse-counter
  period.
- The MuTRiG3 SPI bitmap is 2662 bits and is latched when chip-select returns
  high. MISO reports the previous configuration stream, so response comparisons
  must account for padding/shift alignment rather than treating any nonzero SPI
  response as a new config echo.
- The TDC PLL clock is asynchronous to the serializer/core clocks. The reset
  input must be pulsed for at least 16 ns, and `sync_ch_rst=1` selects the
  internally synchronized reset path for the coarse-counter reset. Keep reset
  ordering tied to run-control evidence; configuration ACK alone does not prove
  timestamp phase alignment.

### Reset and Run-Control State During SPI Load

The MuTRiG reset input must be held at the inactive low level while the SPI
bitmap is loaded. In the FEB run-control sequence, `RUN_SYNC` asserts the
MuTRiG reset, so do not issue `CMD_MUTRIG_ASIC_CFG` while the system is in
`RUN_SYNC` or transitioning through it. The safe host sequence is `rc_tool reset`
followed by `rc_tool stop-reset`, wait for the stop-reset settle time, and only
then issue `CMD_MUTRIG_ASIC_CFG`.

This run-state ordering is a synchronization-quality rule, not a hard
rate-monitoring rule. If the ASICs are configured or reset-released at different
times, their MuTRiG frame headers and timestamps may no longer line up across
ASICs. That is unacceptable for delay/PLL-lock closure, but it can still be used
for rate-only monitoring when the hit processor is configured to bypass or
ignore the latency check and the resulting timestamp errors are not credited as
delay evidence.

After SPI configuration, execute the normal full run sequence before taking
rate or delay evidence: `reset`, `stop-reset`, `run-prepare`, `sync`, and
`start-run`. This restarts the MuTRiG TDC counters from a known global point and
is the sequence expected for aligned headers across ASICs.

After an FEB reconfiguration, assume every MuTRiG lost its useful configuration.
During FEB configuration the Nios reprograms the Si clock chip that provides
the 625 MHz MuTRiG clock, so the ASICs can lose clock/configuration state.
Reload the SMB3/SMB5 MuTRiG XMLs and run the full sequence again before any
rate, delay, or histogram claim.

## Injection Mode

With TDC injection enabled, the MuTRiG cuts off the analog frontend input. The
shared external trigger bus injects into the digital TDC counters and generates
hits with deterministic or rate-controlled timing.

Recommended debug interpretation:

- Locked and deterministic header-synchronous injection should produce a narrow
  delay peak.
- Partly unlocked or noisy channels create hits with bad timestamps. If those
  hits are allowed through the histogram, they appear as broad or random delay.
- Fully unlocked links create timestamp values that are essentially not useful
  for delay validation.

Rate-only testing should keep the MTS timestamp-delay error sideband asserted
and forwarded. Trim policy belongs downstream, usually in the ring-buffer CAM
`filter_inerr` control bit. PLL-lock testing must never hide the error sideband.

## PLL Lock Search

The practical lock search uses three MuTRiG settings:

| Setting | Role |
|---|---|
| `hitlogic` | noise rejection around the central delay peak |
| `vcodelay` | main PLL-lock search parameter |
| `cnt` | lock sensitivity / threshold helper |

Operational procedure:

1. Start from the explicit no-lock point: set TDC-related values to zero,
   especially `vnvcodelay=0`. At this point the MuTRiG should generate no TDC
   injection hits. If hits appear with `vnvcodelay=0`, treat the run as a
   stale configuration, bad override, or run-sequence artifact, not as lock
   evidence.
2. Load the ASIC-specific XML/default value from the table above. A blind
   monotonic sweep from zero is a bad MuTRiG tuning method because many points
   are not lock candidates. Use the known board range first, then fine tune.
3. After cold configuration, FEB reconfiguration, or any clock-loss event, run
   the full sequence through `RUN_PREPARE` before judging the delay offset. The
   PLL can be locked while the TDC phase is still not synchronized to the FPGA;
   without `RUN_PREPARE`, a delta-like histogram can sit at the wrong offset.
4. Once the run is already in `RUNNING` and the PLL is locked, small
   `vnvcodelay`, `vncnt`, and `vnhitlogic` perturbations can be tested without
   a full run restart. If the histogram collapses to the unlocked signature,
   back out to the last safe `vnvcodelay`.
5. Use `vnvcodelay` as the primary lock knob. Increase `vncnt` only when the
   PLL is already near a stable region or when coarse-counter behavior demands
   it. Increase `vnhitlogic` modestly for analog/noise cleanup; too much
   `vnhitlogic` can remove useful hits or destabilize the setting.
6. If a locked ASIC shows a narrow delta plus sideband delay population, do a
   physical channel-mask scan before changing global PLL knobs aggressively.
   Mask one MuTRiG channel at a time in the ASIC XML/config, restart the normal
   run sequence, and replot the delay histogram. The useful signature is:
   delta population stays at the same delay, total rate drops by the masked
   channel fraction, and the sideband disappears or strongly shrinks. That
   identifies a bad/noisy/marginal channel. If the sideband remains under every
   single-channel mask, treat it as ASIC-level PLL/phase behavior or an upstream
   decode/source issue. Do not rely on the histogram debug input as a per-channel
   reject filter unless the exact CSR path has been proven; the controlled
   experiment is MuTRiG-side channel masking followed by a run restart.

Histogram interpretation:

- `vnvcodelay=0`: expected no TDC injection hits.
- Unlocked PLL: expect a broad/random delay distribution; in the current
  15-bit timestamp path this can look like roughly half of hits inside the
  accepted delay window and half outside because of timestamp aliasing. That is
  an unlock signature, not a partial pass.
- Locked but not tuned: expect a dominant in-band delta plus possible sideband
  hits. A workable but not final point can have about 90% in the delta and a
  flat out-of-band sideband.
- Tuned: target a stable delta with only small accounted loss. About
  1000 ppm out-of-band/lost hits is acceptable for a good ASIC; a bad ASIC may
  need an explicit waiver up to about 1% if the loss is stable, documented, and
  not caused by the FEB/SWB datapath.
- Over-tuned or lost lock: if a small `vnvcodelay`/`vncnt` increase turns the
  distribution back into the roughly 50/50 alias pattern, the PLL was lost.
  Return to the last safer `vnvcodelay`.

The old `vco000` Phase-6 captures are not PLL-lock evidence. A label that says
`vncnt=0`, `vnvcodelay=0`, and `vnhitlogic=0` must produce no hits. If a report
shows hits under that label, debug the configuration manifest and run sequence
before using the capture.

Observed Phase-5 update on 2026-04-30:

- Single-lane 2000-cycle delay runs can be made clean on all eight lanes with
  ASIC-specific PLL/hitlogic overrides.
- Scoped real-source runs must leave parked emulator lanes disabled. In
  `run_phase5_injector_datapath_sanity.py`, this is now the default for
  `--source real`; older manual runs used `--active-lanes-mask 0x00`.
- Upper pair `lanes1+2` passes when ASIC1/2 are reduced to one TDC-test channel
  and the parked emulators are quiet, but the full 32-channel pair still
  produces ring-buffer CAM input errors. Treat that as a multiplicity/rate
  problem, not as proof of an ASIC1/2 phase offset.
- Lower pair `lanes5+6` one-channel is not a stable pass. An early
  good-ribbon restore run passed, but the later timing-closed Phase-6 image with
  explicit SMB5 XML reload reproduced P6B010 ring input errors while LVDS error
  and DPA-unlock deltas stayed zero. Treat the earlier pass as stale/reset- or
  image-sensitive until the same image passes after a clean reconfigure.
- The follow-up Phase-6 isolation sweep on the timing-clean no-STP image proves
  the lower blocker is cross-stream, not lane-local. ASIC5/lane5 and
  ASIC6/lane6 each pass one-channel pulse-high 4/5 runs alone with zero ring
  input errors. The two real lanes together fail at pulse-high 4/5, while
  pulse-high 3 produces no useful one-channel histogram traffic. A two-lane
  emulator reference through the same lower MTS/ring path passes after 50 ms
  post-sync/pre-inject settle.
- Sweeping ASIC6 `ext_trig_offset` through the full 4-bit range `0..15` against
  ASIC5 offset 0 did not find a clean lower one-channel pair point. Every
  offset still failed as `ring_input_errors_with_histogram_hits` with zero LVDS
  error-counter and DPA-unlock deltas. Do not retry `ext_trig_offset` blindly;
  the next useful lever must explain real MuTRiG cross-ASIC timestamp/epoch or
  lower-MTS input ordering.
- Lower pair `lanes5+6` still fails with all 32 TDC-test channels enabled on
  ASIC5 and ASIC6. Opening the MTS expected-latency window to `65535` does not
  remove the ring input errors, so the failure is not just a small positive
  latency tail above `2000` cycles.
- ASIC5/lane5 and ASIC6/lane6 each pass full 32-channel injection alone with
  `vnhitlogic=60`, but the two-ASIC pair fails. Channel-mask scans show some
  four/eight-channel groups pass alone while the union of individually clean
  groups still fails. Treat the lower full-channel blocker as a cross-ASIC
  timestamp ordering/epoch issue until a SignalTap or focused MTS simulation
  proves otherwise.
- Header `ext_trig_offset=1` on either ASIC5 or ASIC6 worsens the full-channel
  lower pair. Raising `vnhitlogic` to `40`, `50`, or `60` does not clear the
  pair; reducing the injector rate to 10 kHz/channel also still fails. Those
  are negative tuning results and should not be retried without a new
  hypothesis.
- The lower full-channel pair has a sharp integer pulse-width edge. Pulse high
  `3` can be clean at the MTS/ring gate, but it is far below the required
  32-channel multiplicity; pulse high `4` produces enough hits but brings back
  MTS delay errors. Scanning ASIC5/6 `vnhitlogic=0`, `5`, and `10` at pulse high
  `3` kept the run clean but underfilled, and `vnhitlogic=5` at pulse high `4`
  still failed. The wiki `cml_sc=1` setting at pulse high `3` reduced accepted
  counts further. Do not treat pulse high `3` PASS as rate closure.
- The ring error is forwarded MTS `tserr`, meaning the hit reaches the ring
  outside the accepted timestamp-delay rule before the ring-buffer CAM decides
  whether to filter it. The Phase-5 sanity runner now has a diagnostic
  `--mts-bypass-lapse` switch for isolating the MTS GTS/lapse transform; that
  diagnostic did not clear the lower full-channel pair. Using the E timestamp
  field also made the full-channel pair worse, which matches the short-mode
  TDC-injection expectation that `recv_all=1` should use T.
- Enabling MTS `drop_delay_error` makes the lower pair a clean downstream
  diagnostic by removing the offending hits before the ring, but that is not
  latency closure. It only confirms the ring-buffer CAM is reacting to upstream
  MTS delay errors rather than creating the errors locally.
- The lower MTS/ring SignalTap capture on 2026-04-30 shows
  `mts_preprocessor_1.aso_hit_type1_error` and
  `hit_stack_subsystem_1.hit_type_1_error[0]` both rising in the exported
  window. That puts the failure at or before the lower MTS timestamp-delay
  decision; it is not just a ring-local reject.
- The 2026-05-01 ASIC5 head-sync JTAG histograms separate physical TDC behavior
  from the MTS lapse transform. With production lapse enabled, the XML default
  `42/20/25` has six nonzero delay bins and only a `44.914%` peak. Tuning to
  `52/18/25` improves the shape, but production lapse still splits into two
  bins: `79.171%` at 8 cycles and `20.829%` at 408 cycles. The same
  `52/18/25` ASIC5 setting with `--mts-bypass-lapse on` becomes a one-bin
  delta at 8 cycles, while ASIC6 default production-lapse is already a one-bin
  delta at 904 cycles. Therefore the next useful lever is MTS
  lapse/overflow-lookback behavior, not more blind ASIC5 VCO sweeping.
- Runtime `--mts-expected-latency` writes do not tune the active lapse
  lookback. The MTS source patch in commit `4951341` adds CSR word `5`,
  `overflow_lookback_8ns`, so the Phase-6 runners now expose
  `--mts-overflow-lookback` as the control for this hypothesis. Keep
  `--mts-expected-latency 2000` as the downstream timestamp-error gate and
  sweep `--mts-overflow-lookback` separately. A valid ASIC5 rerun must rebuild
  the full FEB image with MTS `26.0.9.0501`, then compare production lapse
  against the diagnostic bypass-lapse case using the same nonzero
  `52/18/25` physical setting.
- A Phase-6 LVDS SVD probe on 2026-04-30 reproduced the lower full-channel
  blocker with `2052049` ring input errors while lanes 5 and 6 had zero LVDS
  error-counter delta and zero DPA-unlock delta. Do not treat the new LVDS
  controller IP as the next primary fix unless a future run shows LVDS deltas
  correlated with the MTS/ring failure.
- The quick `rate` profile's `LAST_INTERVAL_TOTAL_HITS` is not closure evidence
  in the current live runs; it stayed near `66560` for one-channel lane5 while
  live/MTS counters changed with run duration. Use raw DMA/hit decode or a fixed
  histogram-bin capture before claiming 100 kHz/channel rate closure.

Do not claim 256-channel FEB/SWB end-to-end closure until the lower-pair MTS
`tserr` source is removed and the host-disk capture shows 256 same-timestamp
hits per bunch with 100 kHz bunch spacing.

## Analog Mode

Analog testing starts after rate and PLL-lock tests are understood. Enable the
analog CML driver by changing XML `<cml>0</cml>` to `<cml>1</cml>` or by using
one of the analog reference configs listed above.

Expect some ASICs to require PLL tuning before the analog-hit timestamps are
useful. Use the delay shape in `histogram_statistics_0` as the first live
diagnostic, then confirm with SignalTap if the delay PDF is broad or aliased.

## Goodness Criteria

For a good TDC-injection lock case:

- LVDS decoder reports stable frame reception.
- `mutrig_frame_deassembly_N` counters advance with low or zero CRC/frame
  errors.
- MTS timestamp-delay error remains low without local trimming.
- `histogram_statistics_0` total hits advances with `DROPPED_HITS=0` and
  coalescing queue overflow zero.
- Deterministic injection produces a narrow delay feature rather than a broad
  random distribution.

For rate-only acceptance:

- Forward MTS timestamp-delay errors to monitors and downstream filters.
- Do not use locally trimmed measurements as PLL-lock or latency evidence.

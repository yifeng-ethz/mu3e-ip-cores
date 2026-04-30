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

Current `good_ribbon_0` TDC XML PLL-search values are:

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

### MuTRiG Wiki References for Tuning

The online wiki is part of the `online_sc` checkout as the `online/wiki`
submodule. The intended path is:

```text
/home/yifeng/packages/online_sc/online/wiki
```

If that path is empty, initialize or update the submodule from the `online`
checkout with Bitbucket credentials. A populated local mirror used for the
2026-04-29 tuning notes is:

```text
/home/yifeng/packages/online_si/online/wiki
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
  hardware lever.
- `vnhitlogic` is not an arbitrary noise knob. It biases the TDC hitlogic input
  receiver. Wrong input swing, wrong CML/TDC-test setup, or wrong `vnhitlogic`
  can cause no hits, extra noise hits, or poor timing. Treat it together with
  injection pulse width and CML settings.
- `vncnt=0` is a deliberate PLL-unlock setting. Use it before testing a new
  `vnvcodelay` point. Increase `vncnt` if coarse-counter distributions show
  spikes.
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

1. Reduce `cnt` when searching for a lock at lower `vcodelay`.
2. Increase `hitlogic` when the central delay peak is surrounded by noise.
3. Before testing a new `vcodelay`, first write `vcodelay = 0x0+0` to fully unlock the PLL, then write the target value in the `<value>x<scale> + <offset>` form. The lock state can be sticky; skipping the explicit unlock can make a historically good `vcodelay` fail to re-lock.

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
- Lower pair `lanes5+6` now passes at one TDC-test channel per ASIC after a
  clean good-ribbon restore of ASIC5/6. The earlier one-channel failure should
  be treated as a stale/reset-sensitive observation, not the current blocker.
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

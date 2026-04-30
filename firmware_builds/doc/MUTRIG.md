# MUTRIG.md - MuTRiG3 configuration and lock notes

Date: 2026-04-30

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

Important caveat: `config_smb003_tdc_all_OK.xml` is upper-side only. It is fine
for rate and channel alive/dead tests on lanes 0..3, but it does not always
produce a locked PLL. For down-side PLL-lock work, start from the SMB5 TDC
config.

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

The Phase-5/Phase-6 config runner must implement this as `local = asic % 4`,
selecting the SMB3 XML for ASICs `0..3` and the SMB5 XML for ASICs `4..7`.
For full 256-channel TDC injection, use all eight ASICs plus all 32 channels
per ASIC:

```text
--configure-asics 0-7 --channel-enable-mask 0xffffffff --tdctest-channel-mask 0xffffffff
```

That command only overrides per-channel `mask` and `tdctest_n` inside each
ASIC's local XML entry. It must not change the SMB3/SMB5 file split.

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
down side is a bad test: it can make the SPI transaction pass while the
physical ASIC tuning is wrong.

The current Phase-6 restore-load tuning ledger is:

| ASIC | Default `cnt/vcodelay/hitlogic` | Restore-load `cnt/vcodelay/hitlogic` | Extra diagnostic setting | Evidence |
|---:|---|---|---|---|
| 0 | `48/20/30` | `48/20/40` | none | `phase5_mutrig_restore_full32_tuned_baseline_20260430e.json` |
| 1 | `43/30/30` | `43/30/30` | none | `phase5_mutrig_restore_full32_tuned_baseline_20260430e.json` |
| 2 | `45/35/20` | `40/30/30` | none | `phase5_mutrig_restore_full32_tuned_baseline_20260430e.json` |
| 3 | `41/10/20` | `35/12/25` | none | `phase5_mutrig_restore_full32_tuned_baseline_20260430e.json` |
| 4 | `43/15/20` | `43/15/20` | none | `phase5_mutrig_restore_full32_tuned_baseline_20260430e.json` |
| 5 | `42/20/25` | `42/20/25` | `42/20/60` passes lane5 alone, fails with lane6 | `phase5_real_lane5_full32_hl60_latency2000_pulse4_20260430.json` |
| 6 | `37/27/15` | `37/27/15` | `37/27/60` passes lane6 alone, fails with lane5 | `phase5_real_lane6_full32_hl60_latency2000_pulse4_20260430.json` |
| 7 | `40/20/25` | `30/14/40` | none | `phase5_mutrig_restore_full32_tuned_baseline_20260430e.json` |

No per-ASIC head-sync delay histogram PNG/SVG is closure-grade yet in this
tree. The required artifacts for the next tuning pass are one plot per ASIC
under `reports/screenshots/phase6_mutrig_headsync_YYYYMMDD/`, named
`asicN_cntC_vcodelayV_hitlogicH.png`, plus the matching JSON/Markdown manifest.
Do not replace these with stale `vco000` captures; those are invalidated as
PLL-lock evidence by the zero-vcodelay rule below.

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
| `vcodelay` | main PLL-lock search parameter |
| `cnt` | secondary lock sensitivity / threshold helper |
| `hitlogic` | hitlogic input bias and noise cleanup knob |

Operational procedure:

1. Start from the explicit no-hit control point: set TDC-related values to zero,
   especially `vnvcodelay=0`. At this point the MuTRiG should generate no
   TDC-injection hits. If hits appear with `vnvcodelay=0`, treat the run as a
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

Histogram interpretation:

- `vnvcodelay=0`: expected no TDC-injection hits.
- Unlocked PLL: expect a broad/random delay distribution. In the current
  15-bit, 1.6 ns timestamp path, the 0..2000-cycle accepted latency window can
  alias into a roughly half in-band / half out-of-band result. That is an
  unlock signature, not a partial pass.
- Locked but not tuned: expect a dominant in-band delta plus possible sideband
  hits. A workable but not final point can have about 90% in the delta and a
  flat out-of-band sideband.
- Tuned: target a stable delta with only small accounted loss. About 1000 ppm
  out-of-band/lost hits is acceptable for a good ASIC; a bad ASIC may need an
  explicit waiver up to about 1% if the loss is stable, documented, and not
  caused by the FEB/SWB datapath.
- Over-tuned or lost lock: if a small `vnvcodelay`/`vncnt` increase turns the
  distribution back into the roughly 50/50 alias pattern, the PLL was lost.
  Return to the last safer `vnvcodelay`.

The old `vco000` Phase-6 captures are not PLL-lock evidence. A label that says
`vncnt=0`, `vnvcodelay=0`, and `vnhitlogic=0` must produce no hits. If a report
shows hits under that label, debug the configuration manifest and run sequence
before using the capture. This is the specific correction for P6-BUG-004-H.

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

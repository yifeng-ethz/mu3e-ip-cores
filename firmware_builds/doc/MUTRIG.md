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

# MUTRIG.md - MuTRiG3 configuration and lock notes

Date: 2026-04-27

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

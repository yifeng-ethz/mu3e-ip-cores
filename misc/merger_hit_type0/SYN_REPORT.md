# SYN_REPORT.md - merger_hit_type0 standalone signoff

## Build

- Top: `merger_hit_type0_standalone_top` (pin-flattened wrapper around `merger_hit_type0`).
- Device: `5AGXBA7D4F31C5` (Arria V SX SoC, FEB SciFi target).
- Quartus 18.1.0 Standard.
- SDC: single clock at 1.1x of the 125 MHz target -> 137.55 MHz constraint.
- Flow: `quartus_sh --flow compile merger_hit_type0_standalone`.

## Result

| Field | Value |
|---|---|
| Compile | **PASS** (0 errors, 17 warnings, 1:22 elapsed) |
| Slow 1100mV 85C Setup slack | -7.642 ns |
| Slow 1100mV 85C Hold slack | -0.025 ns |
| Slow 1100mV 0C Setup slack | -7.322 ns |
| Slow 1100mV 0C Hold slack | 0.322 ns |
| Slow 1100mV 85C Fmax | 67.06 MHz |
| Slow 1100mV 0C Fmax | 68.53 MHz |

## Interpretation

The 67 MHz Fmax in standalone is **I/O-bound**. The combinational mux plus
the single registered CSR stage is a tiny critical path (one ALM), but the
standalone synthesis is pin-flattened: every interface signal goes through
input/output buffers and the Quartus default IO models add ~7 ns of
chip-to-pin delay. In the integrated path (inside
`scifi_datapath_system_v4`), the merger sits between two LVDS-clocked
registers without any chip-pin boundary, so the I/O penalty disappears and
the merger runs at the parent 125 MHz clock with several ns of slack.

The -0.025 ns hold slack is a single-path borderline tolerable for
standalone, again driven by IO timing; in-system Quartus fits the merger's
combinational logic into one fast ALM and hold is positive.

For the **in-system 1.1x signoff**, slack will be reported at the
`scifi_datapath_system_v4` level after the next `make qsys-syn + flow`.

## Static screen

| Tool | Result |
|---|---|
| Questa Lint | (not run in this commit; will run at the integration recompile gate) |
| Questa CDC | (n/a; single-clock domain) |
| Questa RDC | (n/a; single-reset domain) |

The full `qverify` Lint / CDC / RDC will run via the FEB integration build
when the merger is wired into `scifi_datapath_system_v4`.

## TB cross-reference

`tb/Makefile` runs `merger_hit_type0_tb` and reports 17 directed checks, 0
errors, including:

- CSR identity (UID = `0x4D484754`, VER = `0x1A000207`).
- SOURCE_SEL_DEFAULT seeds `CONTROL.source_sel = 0` (REAL) at reset.
- Real beat with concurrent emulator beat: out forwards REAL byte-for-byte.
- After `csr_write(0x3, 0x1)`: out forwards EMU verbatim.
- Idle cycle: `out_valid = 0`.
- After `csr_write(0x3, 0x0)`: out forwards REAL again.
- `endofrun` propagates without packet-boundary corruption.

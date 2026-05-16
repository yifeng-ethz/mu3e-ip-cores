# arb_hit_type0 Standalone Synthesis Report

Date: 2026-05-16

## Scope

This report compares the original full diagnostic `arb_hit_type0` build against the FEB resource-trim build.

Both compiles use the same standalone pin-level harness, Arria V `5AGXBA7D4F31C5`, Quartus Prime 18.1 Standard, and a 7.273 ns clock constraint (137.5 MHz).

| Revision | Key parameters | ALMs | Registers | Comb ALUTs | RAM bits | Worst setup slack | Worst hold slack |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `arb_hit_type0_full16` | `FIFO_DEPTH=16`, `COUNTER_PROFILE=0` | 1,956 | 3,039 | 2,914 | 0 | +0.367 ns | +0.142 ns |
| `arb_hit_type0_trim3_fifo2` | `FIFO_DEPTH=2`, `COUNTER_PROFILE=1` | 558 | 718 | 950 | 0 | +0.856 ns | +0.141 ns |
| Delta | trim3_fifo2 minus full16 | -1,398 | -2,321 | -1,964 | 0 | +0.489 ns | -0.001 ns |
| Delta percent | relative to full16 | -71.5% | -76.4% | -67.4% | 0% |  |  |

Both full compiles completed successfully:

```sh
quartus_sh --flow compile arb_hit_type0_standalone -c arb_hit_type0_full16
quartus_sh --flow compile arb_hit_type0_standalone -c arb_hit_type0_trim3_fifo2
```

## Hierarchy Readback

Post-fit hierarchy from `*.fit.rpt` shows the resource reduction is dominated by the CSR bank and per-source FIFOs:

| Entity | Full16 ALMs | Trim3/FIFO2 ALMs | Delta |
| --- | ---: | ---: | ---: |
| CSR profile | 1,175.5 | 354.5 | -821.0 |
| Real FIFO | 346.8 | 29.5 | -317.3 |
| Emulator FIFO | 332.9 | 41.7 | -291.2 |
| Arbiter | 22.0 | 20.9 | -1.1 |
| Run-control | 6.8 | 7.3 | +0.5 |
| Watchdog | 35.3 | 35.5 | +0.2 |

The full build was high because the full CSR bank carries many 64-bit counters, coherent high-word snapshots, error counters, syndrome registers, sticky status, and a wide read mux. The 16-deep FIFOs are also register/LUTRAM-heavy in this small standalone fit.

The trim3 profile removes the syndrome/error-counter bank and keeps only three 64-bit counters:

- ingress real hits
- ingress emulator hits
- total egress hits

## Target Check

The trim3/FIFO2 build is much smaller but still above the 300 ALM per-unit target in standalone Quartus: 558 ALMs fitted.

The remaining fitted cost is mainly the three 64-bit counters plus their CSR read path (`arb_hit_type0_csr_trim3`: 354.5 ALMs) and the two 2-deep stream FIFOs/control logic (about 71.2 ALMs for FIFO entities plus top-level glue). Hitting 300 ALMs with three full 64-bit counters likely needs a more aggressive CSR contract, for example dropping coherent high-word snapshots, trimming status/control/watchdog visibility, or reducing counter width.

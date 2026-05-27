# MTS Type1 ASIC-ID Phase 5 Histogram Verification
## Build And Board Setup
- Programmed SOF: `output_files/top.sof`, Quartus programmer checksum `0x1A016D0F`, file CRC32 `0x59B71324`.
- MTS generated synthesis RTL checked at version `26.3.8` before compile.
- Compile: 0 errors; fitter resources 55,940 ALMs, 93,359 registers, 910 RAM blocks, 0 DSP blocks.
- Timing: slow85 setup WNS `-0.194 ns` on `lvds_firefly_clk`; slow85 hold WNS `+0.249 ns` on `lvds_firefly_clk`.
- Post-program: one `mudaq_recover_pcie` was required after the first SC soft-reset write timed out; retry of `sc_tool 2 write 0x04006 0x00000100` returned `rsp=OK`.
- MuTRiG configure: `SUMMARY pass=24 fail=0` in `configure_mutrig.log`.

## Canonical Histogram Config
- Range: `LEFT_BOUND=-1000` (`0xFFFFFC18`), `RIGHT_BOUND=3096` (`0x00000C18`), `BIN_WIDTH=16`, `N_BINS=256`.
- Injector: mode=1 header-sync, header_interval=1, multiplicity=1, header_delay=100, header_ch=0, pulse_high=5.
- Filter: `KEY_VALUE = ASIC_INDEX << 16`, filter enabled.
- Type1-up ASIC0..3 control: `0x00011015`; Type1-down ASIC4..7 control: `0x00021019`.

## Per-ASIC Results
| ASIC | Bank | KEY_VALUE | Peak cycle | Weighted center | FWHM cycles | Total counts | Active TOTAL_HITS | Active LAST_INTERVAL_TOTAL_HITS | Classification |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | Type1-up | `0x00000000` | 992.0 | 1103.7 | 976 | 2987347 | 1048575 | 1048575 | BROAD_MULTI_PEAK |
| 1 | Type1-up | `0x00010000` | NA | NA | NA | 0 | 1048575 | 1048575 | NO_HITS |
| 2 | Type1-up | `0x00020000` | NA | NA | NA | 0 | 1048575 | 1048575 | NO_HITS |
| 3 | Type1-up | `0x00030000` | NA | NA | NA | 0 | 1048575 | 1048575 | NO_HITS |
| 4 | Type1-down | `0x00040000` | NA | NA | NA | 0 | 0 | 0 | NO_HITS |
| 5 | Type1-down | `0x00050000` | NA | NA | NA | 0 | 0 | 0 | NO_HITS |
| 6 | Type1-down | `0x00060000` | NA | NA | NA | 0 | 0 | 0 | NO_HITS |
| 7 | Type1-down | `0x00070000` | NA | NA | NA | 0 | 0 | 0 | NO_HITS |

## Type1-Down Bank Smoke
- Control: `0x00020019` with filter disabled (`KEY_VALUE=0x00000000`).
- TOTAL_HITS active: `0`, LAST_INTERVAL_TOTAL_HITS active: `0`, bin total: `0`.
- Verdict: `BANK_SILENT`.

## Overall Verdict
`PARTIAL`
- Zero-count ASICs: 1, 2, 3, 4, 5, 6, 7.
- Type1-up front-end activity is present for ASIC1..3 (`TOTAL_HITS=1048575`) but the filtered bins are zero for `KEY_VALUE=1<<16`, `2<<16`, and `3<<16`. That means the integrated image still presents Type1 filter key `0` for the Type1-up bank under the header-sync injector setup.
- This is consistent with the RTL fix deriving ASIC ID from `asi_hit_type0_channel[5:4]`: the injector is configured with `header_ch=0`, so those channel bits are `00` for every ASIC hit. The next RTL fix should carry the mux/source slot explicitly rather than inferring ASIC ID from the hit channel field.
- Type1-down remains a separate path bug: even with filter disabled, `TOTAL_HITS=0` and the bins are empty.

## Artifacts
- ASIC0: `ASIC0/bins.csv` and `ASIC0/result.json`
- ASIC1: `ASIC1/bins.csv` and `ASIC1/result.json`
- ASIC2: `ASIC2/bins.csv` and `ASIC2/result.json`
- ASIC3: `ASIC3/bins.csv` and `ASIC3/result.json`
- ASIC4: `ASIC4/bins.csv` and `ASIC4/result.json`
- ASIC5: `ASIC5/bins.csv` and `ASIC5/result.json`
- ASIC6: `ASIC6/bins.csv` and `ASIC6/result.json`
- ASIC7: `ASIC7/bins.csv` and `ASIC7/result.json`
- Type1-down no-filter smoke: `TYPE1_DOWN_NOFILTER/bins.csv` and `TYPE1_DOWN_NOFILTER/result.json`

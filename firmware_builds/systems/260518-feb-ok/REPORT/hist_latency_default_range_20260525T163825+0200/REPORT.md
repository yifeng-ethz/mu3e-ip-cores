# Default-Range Header-Sync Histogram Latency - 2026-05-25

## Scope

No compile, reprogram, RTL edit, commit, push, or LVDS CSR read was performed. Every `sc_tool` and `rc_tool` command was wrapped with `~/.local/bin/swb_ring_lock`.

## Unit A - Signed Range Verdict

Verdict: **SIGNED_OK**. The histogram supports a negative `LEFT_BOUND` for mode-1 delay binning.

| Evidence | Source |
|---|---|
| `csr_left_bound`, `csr_right_bound`, `cfg_left_bound`, and `cfg_right_bound` are `tick_t`, a signed subtype. | `histogram_statistics/rtl/histogram_statistics_v2.vhd:579-580`, `:616-618` |
| CSR writes sign-resize `LEFT_BOUND` and `RIGHT_BOUND`. | `histogram_statistics/rtl/histogram_statistics_v2.vhd:2138-2141` |
| Mode 1 builds the key as `GTS - ts_sideband[47:0]`, trimmed into `tick_t`. | `histogram_statistics/rtl/histogram_statistics_v2.vhd:889-909`, `:1375-1379` |
| Divider ports and range comparisons are signed. | `histogram_statistics/rtl/bin_divider.vhd:43-49`, `:139-147` |
| The key entering the divider is converted to signed before range check. | `histogram_statistics/rtl/histogram_statistics_v2.vhd:1547-1569`, `:1581-1598` |

Therefore `LEFT_BOUND=-1000` is programmed as `0xFFFFFC18`, and `RIGHT_BOUND=3096` as `0x00000C18`.

## Canonical Default Delay-Hist Configuration

| Field | Value |
|---|---:|
| `LEFT_BOUND` | `-1000` / `0xFFFFFC18` |
| `RIGHT_BOUND` | `3096` / `0x00000C18` |
| `BIN_WIDTH` | `16` cycles |
| `N_BINS` | `256` |
| Covered range | `-1000..3095` cycles |
| Expected ASIC0 peak bin | `(1024 - (-1000))/16 ~= 127` |
| Type1-up control, filter on, signed | `0x00011015` write, expected readback `0x00011014` |
| Type1-down control, filter on, signed | `0x00021019` write, expected readback `0x00021018` |
| Injector | mode 1, header interval 1, multiplicity 1, header delay 100, header ch 0, pulse high 5 |

Important: `RIGHT_BOUND` must be written explicitly before `CONTROL.apply`; the loaded RTL copies the staged `RIGHT_BOUND` and does not recompute it from `LEFT_BOUND + BIN_WIDTH*N_BINS`.

## Per-ASIC Results

| ASIC | Path | Peak bin | Peak center cycle | Weighted center | FWHM | Bin total | Active underflow | Active overflow | Verdict | CSV |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| 0 | Type1-up / EXT0 | 126 | 1024.0 | 1122.00 | 928 | 2093579 | 0 | 0 | WIDER_THAN_EXPECTED | `ASIC0/bins.csv` |
| 1 | Type1-up / EXT0 | NA | NA | NA | NA | 0 | 0 | 0 | FRONTEND_ACCEPTED_BUT_NO_BINS | `ASIC1/bins.csv` |
| 2 | Type1-up / EXT0 | NA | NA | NA | NA | 0 | 0 | 0 | FRONTEND_ACCEPTED_BUT_NO_BINS | `ASIC2/bins.csv` |
| 3 | Type1-up / EXT0 | NA | NA | NA | NA | 0 | 0 | 0 | FRONTEND_ACCEPTED_BUT_NO_BINS | `ASIC3/bins.csv` |
| 4 | Type1-down / EXT1 | NA | NA | NA | NA | 0 | 0 | 0 | NO_HITS | `ASIC4/bins.csv` |
| 5 | Type1-down / EXT1 | NA | NA | NA | NA | 0 | 0 | 0 | NO_HITS | `ASIC5/bins.csv` |
| 6 | Type1-down / EXT1 | NA | NA | NA | NA | 0 | 0 | 0 | NO_HITS | `ASIC6/bins.csv` |
| 7 | Type1-down / EXT1 | NA | NA | NA | NA | 0 | 0 | 0 | EXPECTED_EMPTY_ASIC7 | `ASIC7/bins.csv` |

Interpretation:

- ASIC0 proves the canonical signed range and explicit `RIGHT_BOUND` programming work with the filtered Type1-up path.
- ASIC1..3 still show saturated front-end acceptance counters but zero bins and zero range errors. Because `TOTAL_HITS` / `LAST_INTERVAL_TOTAL_HITS` count `accept_pulse` before fixed-filter/bin-write, this is most consistent with `KEY_VALUE[31:16]=i` not matching the Type1-up ASIC field for those streams, or a filter/data-label encoding mismatch.
- ASIC4..6 have zero front-end acceptance counters on Type1-down / EXT1, so the Type1-down bank remains silent independently of the `RIGHT_BOUND` bug.
- ASIC7 is empty as expected from the known lane-7 BITSLIPPING issue.

## Single-ASIC Sanity

ASIC0 sanity peak bin was `126` with peak center `1024.0` cycles and weighted center `1122.00` cycles. This matches the expected bin near `127`.

## Type1-Down Verdict

Verdict: **TYPE1_DOWN_STILL_SILENT**.

ASIC4..6 have `TOTAL_HITS=0`, `LAST_INTERVAL_TOTAL_HITS=0`, and empty bins even with explicit `RIGHT_BOUND`. Therefore the earlier Type1-down silence was not only the range-bound bug; a separate Type1-down source/wiring/enable issue remains.

## Overall Verdict

**PARTIAL: ASIC1,ASIC2,ASIC3,ASIC4,ASIC5,ASIC6**

## Permanent Config Snippet

```text
hist_bin write 0x06800 = 0x00000000   # measure_clear_pulse
hist_csr write 0x06903 = 0xFFFFFC18   # LEFT_BOUND = -1000
hist_csr write 0x06904 = 0x00000C18   # RIGHT_BOUND = 3096
hist_csr write 0x06905 = 0x00000010   # BIN_WIDTH = 16
hist_csr write 0x06907 = ASIC_INDEX << 16
hist_csr write 0x06902 = 0x00011015   # ASIC0..3 Type1-up / EXT0 / mode1 / signed / filter on
hist_csr write 0x06902 = 0x00021019   # ASIC4..7 Type1-down / EXT1 / mode1 / signed / filter on
```

Final reset-link status:

```text
RESET_LINK_CTL_REGISTER_W        = 0x00000000
RESET_LINK_STATUS_REGISTER_R     = 0x13000000
RESET_LINK_RUN_NUMBER_REGISTER_W = 0x00000197
last state byte              = 0x13 (end-run)
```

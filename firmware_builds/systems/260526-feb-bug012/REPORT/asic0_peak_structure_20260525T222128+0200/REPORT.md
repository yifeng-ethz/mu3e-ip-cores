# ASIC0 Peak-Structure Post-Processing

Date: 2026-05-25

Scope: pure post-processing after cleanup. No compile, no RTL edit, no commit. Board cleanup only restored the full-8 MuTRiG configuration and took one DPALOCK sanity read.

## Cleanup Confirmation

- `rc_tool send stop-sequence` left SWB status at `0x13000000`.
- Full-8 MuTRiG restore used canonical `--asics 0,1,2,3,4,5,6,7`.
- Configure result: `SUMMARY pass=24 fail=0`.
- Single post-restore `PHY_DPALOCK_STATUS @ 0x0400E = 0x000001FF`.
- No LVDS soft-reset was needed in this cleanup pass.

## Loaded CSV

Primary high-statistics CSV: `/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_main_20260518/firmware_builds/systems/260518-feb-ok/REPORT/full_sequence_remeasure_20260525T183527+0200/ASIC0_full_sequence_direct_header_delay100/bins.csv`

Requested soft-reset-round CSV was cross-checked: `/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_main_20260518/firmware_builds/systems/260518-feb-ok/REPORT/softreset_hist_20260525T220520+0200/ASIC0_bins.csv`

| CSV | Total counts | Mode cycle | Raw FWHM | Background-subtracted FWHM | Shape |
|---|---:|---:|---:|---:|---|
| primary high-stat | 8273583 | 1024.0 | 928 | 864 | `MULTI_PEAK` |
| requested softreset | 3171167 | 1008.0 | 928 | 864 | `MULTI_PEAK` |

## Top 20 Bins

| Rank | Bin | Cycle center | Count |
|---:|---:|---:|---:|
| 1 | 126 | 1024.0 | 147519 |
| 2 | 141 | 1264.0 | 146716 |
| 3 | 128 | 1056.0 | 146608 |
| 4 | 127 | 1040.0 | 146452 |
| 5 | 125 | 1008.0 | 146419 |
| 6 | 140 | 1248.0 | 146290 |
| 7 | 153 | 1456.0 | 145823 |
| 8 | 129 | 1072.0 | 145653 |
| 9 | 142 | 1280.0 | 145467 |
| 10 | 149 | 1392.0 | 144572 |
| 11 | 139 | 1232.0 | 144362 |
| 12 | 152 | 1440.0 | 144145 |
| 13 | 160 | 1568.0 | 144002 |
| 14 | 159 | 1552.0 | 143729 |
| 15 | 150 | 1408.0 | 143651 |
| 16 | 158 | 1536.0 | 143515 |
| 17 | 138 | 1216.0 | 143512 |
| 18 | 148 | 1376.0 | 143350 |
| 19 | 143 | 1296.0 | 143074 |
| 20 | 145 | 1328.0 | 142927 |

## Background Estimate

The all-bin 25th percentile is zero because 176 of 256 bins are empty padding outside the occupied latency range. For the headline calculation I excluded that zero padding and used the 25th percentile of the 80 occupied nonzero bins.

| Background method | B |
|---|---:|
| all-bin p25 | 0.0 |
| occupied-bin lowest-10-percent median | 295.0 |
| occupied-bin p25, primary | 58632.0 |
| occupied-bin median, aggressive plateau subtraction | 139636.5 |

Primary background `B = 58632.0` counts/bin.

## Peak-Only Metrics

| Metric | Value |
|---|---:|
| Main peak bin | 126 |
| Main peak center | 1024.0 cycles |
| Raw peak height | 147519 counts |
| Background-subtracted peak height | 88887.0 counts |
| Peak-to-background ratio, raw/B | 2.52 |
| Peak excess/background ratio | 1.52 |
| Original raw FWHM | 928 cycles |
| Peak-only FWHM after primary background subtraction | 864 cycles |

Sensitivity of FWHM to background definition:

| Method | B | Peak signal | FWHM |
|---|---:|---:|---:|
| `all_bin_p25` | 0.0 | 147519.0 | 928 |
| `occupied_low10_median` | 295.0 | 147224.0 | 928 |
| `occupied_p25_primary` | 58632.0 | 88887.0 | 864 |
| `occupied_median_aggressive` | 139636.5 | 7882.5 | 80 |

The only way to obtain a narrow residual peak is to subtract the occupied-bin median as a high plateau background. That leaves an 80-cycle residual, but the raw peak is only 1.06x the median occupied level, so this is an aggressive decomposition rather than a robust standalone peak-width measurement.

## Percentile Widths

| Fraction | Raw histogram window | Background-subtracted window |
|---:|---|---|
| 90% | 864 cycles (bins 108..161) | 784 cycles (bins 112..160) |
| 95% | 928 cycles (bins 104..161) | 848 cycles (bins 108..160) |
| 99% | 1056 cycles (bins 97..162) | 912 cycles (bins 105..161) |

## Secondary Peak Structure

Local peaks above 90% of the background-subtracted peak: `9`.

| Rank | Bin | Cycle center | Background-subtracted height |
|---:|---:|---:|---:|
| 1 | 126 | 1024.0 | 88887.0 |
| 2 | 141 | 1264.0 | 88084.0 |
| 3 | 128 | 1056.0 | 87976.0 |
| 4 | 153 | 1456.0 | 87191.0 |
| 5 | 149 | 1392.0 | 85940.0 |
| 6 | 160 | 1568.0 | 85370.0 |
| 7 | 145 | 1328.0 | 84295.0 |
| 8 | 119 | 912.0 | 83767.0 |
| 9 | 135 | 1168.0 | 82332.0 |

## ASCII Histogram

Flags: `B+` means count is above the primary background level. `H+` means count is above the half-max threshold used for the peak-only FWHM.

```text
086   384.0        9 --    |
087   400.0       52 --    |
088   416.0      258 --    |
089   432.0      572 --    |
090   448.0     1260 --    |
091   464.0     2652 --    | #
092   480.0     4536 --    | #
093   496.0     7265 --    | ##
094   512.0    10543 --    | ###
095   528.0    13369 --    | ####
096   544.0    17680 --    | #####
097   560.0    23442 --    | #######
098   576.0    28804 --    | #########
099   592.0    35085 --    | ##########
100   608.0    43118 --    | #############
101   624.0    51510 --    | ###############
102   640.0    61006 B+    | ##################
103   656.0    71249 B+    | #####################
104   672.0    79034 B+    | ########################
105   688.0    85064 B+    | #########################
106   704.0    91880 B+    | ###########################
107   720.0    99042 B+    | ##############################
108   736.0   106228 B+,H+ | ################################
109   752.0   112829 B+,H+ | ##################################
110   768.0   118755 B+,H+ | ###################################
111   784.0   124429 B+,H+ | #####################################
112   800.0   127326 B+,H+ | ######################################
113   816.0   130769 B+,H+ | #######################################
114   832.0   133931 B+,H+ | ########################################
115   848.0   137777 B+,H+ | #########################################
116   864.0   139374 B+,H+ | ##########################################
117   880.0   139899 B+,H+ | ##########################################
118   896.0   141992 B+,H+ | ##########################################
119   912.0   142399 B+,H+ | ##########################################
120   928.0   141829 B+,H+ | ##########################################
121   944.0   138453 B+,H+ | #########################################
122   960.0   137781 B+,H+ | #########################################
123   976.0   138091 B+,H+ | #########################################
124   992.0   142813 B+,H+ | ###########################################
125  1008.0   146419 B+,H+ | ############################################
126  1024.0   147519 B+,H+ | ############################################
127  1040.0   146452 B+,H+ | ############################################
128  1056.0   146608 B+,H+ | ############################################
129  1072.0   145653 B+,H+ | ###########################################
130  1088.0   142837 B+,H+ | ###########################################
131  1104.0   142468 B+,H+ | ##########################################
132  1120.0   141730 B+,H+ | ##########################################
133  1136.0   141015 B+,H+ | ##########################################
134  1152.0   140753 B+,H+ | ##########################################
135  1168.0   140964 B+,H+ | ##########################################
136  1184.0   140742 B+,H+ | ##########################################
137  1200.0   142167 B+,H+ | ##########################################
138  1216.0   143512 B+,H+ | ###########################################
139  1232.0   144362 B+,H+ | ###########################################
140  1248.0   146290 B+,H+ | ############################################
141  1264.0   146716 B+,H+ | ############################################
142  1280.0   145467 B+,H+ | ###########################################
143  1296.0   143074 B+,H+ | ###########################################
144  1312.0   142899 B+,H+ | ###########################################
145  1328.0   142927 B+,H+ | ###########################################
146  1344.0   141725 B+,H+ | ##########################################
147  1360.0   141112 B+,H+ | ##########################################
148  1376.0   143350 B+,H+ | ###########################################
149  1392.0   144572 B+,H+ | ###########################################
150  1408.0   143651 B+,H+ | ###########################################
151  1424.0   141493 B+,H+ | ##########################################
152  1440.0   144145 B+,H+ | ###########################################
153  1456.0   145823 B+,H+ | ###########################################
154  1472.0   141448 B+,H+ | ##########################################
155  1488.0   139295 B+,H+ | ##########################################
156  1504.0   140584 B+,H+ | ##########################################
157  1520.0   141661 B+,H+ | ##########################################
158  1536.0   143515 B+,H+ | ###########################################
159  1552.0   143729 B+,H+ | ###########################################
160  1568.0   144002 B+,H+ | ###########################################
161  1584.0   104223 B+,H+ | ###############################
162  1600.0    22472 --    | #######
163  1616.0     3758 --    | #
164  1632.0      332 --    |
165  1648.0       14 --    |
```

## Classification

Final classification: **MULTI_PEAK**.

Compared to the expected ~200-cycle delta-function: **PEAK_WIDER**.

Interpretation: after a reasonable low-tail background subtraction, the headline peak-only FWHM is still `864` cycles and there are 9 local maxima above 90% of the subtracted peak height. The existing bank-level ASIC0 histogram is therefore not a single narrow central peak plus weak long background. It is still structurally broad/multi-peak in this measurement. The aggressive median-occupied subtraction can expose an 80-cycle residual, but that residual sits on a high plateau and has low contrast.

## Artifacts

- `analysis.json`
- `configure_mutrig.log` / `.md` / `.json`
- `final_cleanup_status.log`

# Next-step plan — SignalTap-based debug of held-in-reset triplet

**Session checkpoint date:** 2026-05-19 01:25 CEST
**Status:** v4 LVDS swap landed on-board (commit `0f929e58`); new `mu3e_lvds_controller` CSR fully alive (UID + 9 registers match SVD), but `mutrig_injector_0` / `emulator_mutrig_qsys_inst` / `histogram_statistics_0` still return all-zero on every CSR offset and reject all RW writes — same symptom as before the LVDS swap.

## What we know from sc_tool (no STP yet)

1. New `mu3e_lvds_controller_0` CSR is on `control_clock = monitor_clock_125.clk`. It returns correct UID `0x4C564453` ("LVDS") + the 8 documented health registers match SVD reset values exactly.
2. LVDS CSR registers above offset `0x024` (lane status / DPA / aligner) all read `0x00000000`. If there is a PLL_LOCKED bit in that block, it reads 0.
3. Liveness-probe write `0xCAFE` to `mutrig_injector_0` `HEADER_DELAY` (sc-byte 0x02A00C, RW per SVD) → read returns `0x00000000`. Write did NOT stick.
4. Same liveness-probe write `0xBEEF` to `mutrig_cfg_ctrl_0` `OFFSET` (sc-byte 0x005004, RW per SVD) → read returns `0x0000BEEF`. **Control-path IP is alive; data-path IPs are not.**
5. The held-in-reset triplet all share `mu3e_lvds_controller_0.outclock` as their CSR clock, and `monitor_reset_sync.reset_out` as their reset.
6. The OLD `lvds_rx_28nm_0` PHY → OLD `lvds_rx_controller_pro_0` chain had the SAME symptom before the swap. Architecture of the new IP folds the same `altera_lvds_rx_28nm` PHY internally (just wrapped); `outclock_bridge.out_clk = phy.outclock` is a direct passthrough. **The swap is therefore not expected to change outclock behavior.**

## Hypothesis (un-confirmed; STP needed)

**Primary**: the LVDS PHY's PLL is not locking to `i_lvds_pll_refclk`, so `phy.outclock` is not producing a stable 125 MHz, and every downstream IP that uses `outclock` as its CSR clock cannot complete an Avalon-MM read pulse. The slave's `avs_csr_readdata` register stays at its reset value (0) and the bridge returns 0 to the master after its waitrequest timeout (note: bridge does not propagate timeout to sc_hub; it returns 0 with rsp=OK).

**Secondary (less likely)**: `monitor_reset_sync.reset_out` is permanently asserted for the triplet, even though `control_clock`-domain IPs (LVDS itself, mutrig_cfg_ctrl) are working. This would require the data-path subsystem reset chain to be different from the control-path reset chain — possible if there's a dedicated `mclk125_reset_sync` for data-path that hasn't released.

## Minimum-info STP to disambiguate

**STP instance clock:** `monitor_clock_125.clk` (known-running; the LVDS CSR works at this rate).

**Probes (10-12 signals total, fits trivially in any STP memory budget):**

| group | signal | bits | purpose |
|---|---|---|---|
| 00 Clock + Reset | `monitor_reset_sync.reset_out` | 1 | reset to the triplet — asserted? |
| 00 Clock + Reset | `mu3e_lvds_controller_0.outclock` | 1 (sampled) | is outclock toggling at all? |
| 00 Clock + Reset | `mclk125_souce.clk_reset` | 1 | upstream-reset trace |
| 01 LVDS CSR | `mu3e_lvds_controller_0.csr.avs_csr_read` | 1 | confirm SC bridge alive (we know this works) |
| 02 Injector CSR | `mutrig_injector_0.avs_csr_read` | 1 | does read pulse reach the slave? |
| 02 Injector CSR | `mutrig_injector_0.avs_csr_waitrequest` | 1 | does it deassert waitrequest? |
| 02 Injector CSR | `mutrig_injector_0.avs_csr_readdata[7:0]` | 8 | low byte of readback |
| 03 Histogram CSR | `histogram_statistics_0.avs_csr_read` | 1 | same |
| 03 Histogram CSR | `histogram_statistics_0.avs_csr_readdata[7:0]` | 8 | same |

**Trigger:** `mutrig_injector_0.avs_csr_read` rising edge. Sample depth 1024. Pre-trigger 25%.

## Interpretation matrix

| outclock toggling? | reset_out asserted? | injector avs_csr_read? | verdict |
|---|---|---|---|
| NO | — | — | **PHY PLL unlocked**: fix `i_lvds_pll_refclk` source or PLL parameters. Same root-cause that affected OLD setup. |
| YES | YES | — | **Reset stuck**: trace upstream from `monitor_reset_sync.reset_in0` ← `monitor_clock_125.clk_reset` ← `mclk125_souce.clk_reset`. Some clock_source's reset isn't releasing on data-path. |
| YES | NO | NO | **Bridge doesn't deliver read pulse** to slave: bridge between sc_hub and slave has a stall. Trace `mm_clock_crossing_bridge.m0_*` signals. |
| YES | NO | YES (pulses) | **Slave logic doesn't latch readdata**: avs_csr_readdata stays at reset default. Add CSR-internal probes (csr_q registers) to see why. |

## How to build the STP

The existing v3-era generator at `firmware_builds/systems/260518-feb-ok/script/signaltap/generate_phase4_pre_hss_gap_stp.py` shows the XML pattern. For v4 hierarchy, swap the prefix from
`feb_system:u_feb_system|feb_system_v3:u_qsys|feb_system_v3_data_path_subsystem:data_path_subsystem|`
to
`feb_system:u_feb_system|feb_system_v4:u_qsys|feb_system_v4_data_path_subsystem:data_path_subsystem|`

then under the data-path prefix, the new instance is `mu3e_lvds_controller:mu3e_lvds_controller_0` instead of `lvds_rx_28nm:lvds_rx_28nm_0` + `lvds_rx_controller_pro:lvds_rx_controller_pro_0`.

Validate node names with `~/.codex/skills/signaltap-creation-co-debug/scripts/check_stp_nodes.py` BEFORE incremental fit. Once names check, add the .stp to the qsf via `set_global_assignment -name SIGNALTAP_FILE <name>.stp` and run `make flow` (~45 min).

## Histogram sim infrastructure (parallel work)

The histogram standalone sim (the v3-contract `histogram_statistics_v2` IP) has been restored to `tb_int/hist_v3/` on this build. The legacy `tb_hist_direct_v3.sv` runs but fails with `ready_miss` on all 5 cases — the tb's stimulus model is more aggressive than the DUT can accept. The official UVM `hist_v3_direct_input_test` (in submodule `histogram_statistics/tb/uvm/`) ran for 11+ min generating steady `divider bin mismatch dut=N ref=M` errors (paired N↔M swap pattern) before being killed.

These are independent issues from the on-board held-in-reset. They need their own debug pass once the on-board chain is unblocked.

## Recommended next session order

1. Build the minimum-info STP from the table above, validate node names with `check_stp_nodes.py`.
2. Incremental fit + program (~45 min round). Capture 1024-sample window triggered on injector `avs_csr_read`.
3. Read the interpretation matrix above against the capture; pick the next-narrowest probe set for the indicated quadrant.
4. Iterate at most 2-3 times to pinpoint the stall location.
5. Apply the fix (RTL or qsys-level), rebuild, re-program, re-verify the triplet now responds.
6. ONLY THEN tackle the histogram bin-divider sim regression; commit hist_v3 sim restoration; build the rate+delay plots.

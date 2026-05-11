# v3_pretest-260511 - FEB SciFi v3 build snapshot (post-rdma integration)

HW: Mu3e SciFi FEB. Snapshot of `feb_system_v3` build at 2026-05-11 10:35:17 with `rdma_subsystem`-aware `upload_system_v3` and `runctl_mgmt_host` v26.3.0.0505 integrated.

| Item | Value |
| --- | --- |
| Hardware | Mu3e SciFi FEB |
| Device | `5AGXBA7D4F31C5` |
| Quartus | `18.1.0 Build 625 09/12/2018 SJ Standard Edition` |
| Fitter status | `Successful - Mon May 11 10:35:17 2026` |
| Worst setup WNS | `-2.439 ns` on `lvds_firefly_clk` (`Slow 1100mV 85C Model Setup`) |

This directory is a snapshot, not a rebuild target. The source Quartus project remains read-only in the `online_dpv2` FEB tree; the files here are copied evidence for loading, audit, and follow-up timing/resource review.

## 2. Build summary

Source: [`syn/top.fit.summary`](syn/top.fit.summary).

| Metric | Value |
| --- | --- |
| ALMs | **78,962 / 91,680 ( 86 % )** |
| Registers | 92961 |
| Pins | 218 / 426 ( 51 % ) |
| Block memory bits | 4,870,668 / 13,987,840 ( 35 % ) |
| RAM blocks | 638 / 1,366 ( 47 % ) |
| DSP blocks | 0 / 800 ( 0 % ) |
| HSSI RX PCSs | 4 / 9 ( 44 % ) |
| HSSI PMA RX deserializers | 4 / 9 ( 44 % ) |
| HSSI TX PCSs | **8 / 9 ( 89 % )** |
| HSSI PMA TX serializers | **8 / 9 ( 89 % )** |
| PLLs | 7 / 21 ( 33 % ) |
| DLLs | 0 / 4 ( 0 % ) |

Cells are bold when utilization is greater than 80 percent.

## 3. Subsystem map

```
                  +-----------------------------+
                  |        feb_system_v3        |
                  |  (top-level Qsys wrapper)   |
                  +--+--------+-----------+-----+
                     |        |           |
       +-------------+        |           +-------------+
       |                      |                         |
+------v-----------+   +------v---------+      +--------v---------+
|  data_path       |   |  control_path  |      |  upload          |
|  subsystem (v3)  |   |  subsystem (v3)|      |  subsystem (v3)  |
| scifi_datapath_  |   | debug_sc_      |      | upload_system_v3 |
| system_v3.qsys   |   | system_v3.qsys |      |                  |
+------------------+   +----------------+      +------------------+
       |                      |                         |
       |  hits/headerinfo     |  CSR slow control       |  pkt up
       +---------+            |                         +---+
                 |            |                             |
            (AVST hit_type0)  (Avalon-MM via sc_hub)        |
                 |            |                             |
                 +------------+-----+                       |
                                    v                       v
                              feb_bringup_system    SWB optical link
                              (rst + LVDS PLL +      (sc_hub TX +
                               JTAG, link housekeep)  upload TX +
                                                      synclink RX)
```

## 4. Per-subsystem resource + WNS table

Resources come from `syn/reports/top.fit.rpt`, section `Fitter Resource Utilization by Entity`. WNS cells use worst setup slack per clock from `syn/reports/top.sta.rpt` and are populated only when the TimeQuest clock path maps to the entity hierarchy; `-` means the fit entity is present but that clock has no entity-scoped setup row in this report. `M20K` is reported as `0` because the Arria V target reports M10K blocks, not M20K blocks.

### 4.1 Top wrapper

| Entity (hierarchy) | ALM | M10K | M20K | lvds_firefly_clk WNS | lvds_rx_sclk WNS | transceiver_pll[0] WNS | rx_pcs_rcvdclkpma WNS | max10_spi WNS | spare_clk_osc WNS | pll_156t40 WNS | altera_reserved_tck WNS |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| top.feb_system_v3 (top wrapper) | 74463.6 | 473 | 0 | $\textcolor{red}{-2.439}$ | $\textcolor{red}{-0.910}$ | $\textcolor{green}{+0.347}$ | $\textcolor{green}{+0.389}$ | $\textcolor{green}{+0.692}$ | $\textcolor{green}{+4.327}$ | $\textcolor{green}{+6.010}$ | $\textcolor{green}{+7.723}$ |
|   data_path_subsystem (scifi_datapath_system_v3) | 55357 | 353 | 0 | - | $\textcolor{red}{-0.910}$ | - | - | - | - | - | - |
|   control_path_subsystem (debug_sc_system_v3) | 16582.4 | 43 | 0 | - | - | - | - | - | - | $\textcolor{green}{+6.010}$ | - |
|   upload_subsystem (upload_system_v3) | 1410.1 | 7 | 0 | - | - | - | - | - | - | - | - |
|   feb_bringup_system (bringup_subsystem) | 970.8 | 69 | 0 | - | - | - | - | - | - | - | - |

### 4.2 Data path subsystem

| Entity (hierarchy) | ALM | M10K | M20K | lvds_firefly_clk WNS | lvds_rx_sclk WNS | transceiver_pll[0] WNS | rx_pcs_rcvdclkpma WNS | spare_clk_osc WNS |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| data_path_subsystem (scifi_datapath_system_v3) | 55357 | 353 | 0 | - | $\textcolor{red}{-0.910}$ | - | - | - |
|   mutrig_datapath_subsystem_0 (x8 - first only) | 361.6 | 2 | 0 | - | - | - | - | - |
|   emulator_mutrig_0 (x8 - first only) | 154.1 | 0 | 0 | - | - | - | - | - |
|   mts_preprocessor_0 (x2 - first only) | 1158.6 | 60 | 0 | - | - | - | - | - |
|   histogram_statistics_0 | 11133.8 | 2 | 0 | - | - | - | - | - |
|   hit_stack_subsystem_0 (x2 - first only) | 11510 | 123 | 0 | - | - | - | - | - |
|   lvds_rx_controller_pro_0 | 6690.8 | 0 | 0 | - | $\textcolor{red}{-0.910}$ | - | - | - |
|   mutrig_injector_0 | 818.3 | 0 | 0 | - | - | - | - | - |
|   mutrig_reset_controller_0 | 15.2 | 0 | 0 | - | - | - | - | - |
|   decoded_lane_mux_0 (x8 - first only) | 4.7 | 0 | 0 | - | - | - | - | - |
|   emulator_inject_fanout | - | - | - | - | - | - | - | - |
|   run_control_mux | 6.2 | 0 | 0 | - | - | - | - | - |
|   dbg_mm2runctrl_0 | 96.7 | 0 | 0 | - | - | - | - | - |

### 4.3 Control path subsystem

| Entity (hierarchy) | ALM | M10K | M20K | pll_156t40 WNS | max10_spi WNS | spare_clk_osc WNS | altera_reserved_tck WNS | transceiver_pll[0] WNS |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| control_path_subsystem (debug_sc_system_v3) | 16582.4 | 43 | 0 | $\textcolor{green}{+6.010}$ | - | - | - | - |
|   sc_hub (sc_hub_v2) | 5299.6 | 4 | 0 | - | - | - | - | - |
|   mutrig_cfg_ctrl_0 | 527.8 | 36 | 0 | - | - | - | - | - |
|   charge_injection_pulser_0 | 15.7 | 0 | 0 | - | - | - | - | - |
|   firefly_xcvr_ctrl_0 | 252.2 | 0 | 0 | - | - | - | - | - |
|   max10_prog_avmm_0 | 6799.5 | 0 | 0 | - | $\textcolor{green}{+0.692}$ | - | - | - |
|   on_die_temp_sense_ctrl | 7 | 0 | 0 | - | - | - | - | - |
|   onewire_master_controller_0 | 984.8 | 0 | 0 | - | - | - | - | - |
|   onewire_master_0 | 270.7 | 0 | 0 | - | - | - | - | - |
|   pll_156t40 | 0 | 0 | 0 | $\textcolor{green}{+6.010}$ | - | - | - | - |

### 4.4 Upload subsystem

| Entity (hierarchy) | ALM | M10K | M20K | transceiver_pll[0] WNS | lvds_firefly_clk WNS | pll_156t40 WNS |
| --- | --- | --- | --- | --- | --- | --- |
| upload_subsystem (upload_system_v3) | 1410.1 | 7 | 0 | - | - | - |
|   runctl_mgmt_host_0 (v26.3.0.0505) | 920.9 | 4 | 0 | - | - | - |
|   upload_pkt_mux | 32.1 | 0 | 0 | - | - | - |

### 4.5 FEB bringup system

| Entity (hierarchy) | ALM | M10K | M20K | spare_clk_osc WNS | altera_reserved_tck WNS | max10_spi WNS |
| --- | --- | --- | --- | --- | --- | --- |
| feb_bringup_system (bringup_subsystem) | 970.8 | 69 | 0 | - | - | - |
|   clocks + reset controller | 3.2 | 0 | 0 | - | - | - |
|   cpu / JTAG master / link housekeep | 532.4 | 3 | 0 | - | - | - |
|   JTAG UART | 66.5 | 2 | 0 | - | - | - |
|   on-chip RAM | 5.5 | 64 | 0 | - | - | - |
|   timers / timestamp housekeep | 71.6 | 0 | 0 | - | - | - |

## 5. Worst paths (top 5)

Source: [`syn/top.sta.summary`](syn/top.sta.summary). The summary file reports worst setup slack by clock, so the endpoint module below is derived from the reported clock hierarchy.

| Endpoint module | Slack | Clock | Corner |
| --- | --- | --- | --- |
| top port lvds_firefly_clk | $\textcolor{red}{-2.439}$ | `lvds_firefly_clk` | `Slow 1100mV 85C Model Setup` |
| top port lvds_firefly_clk | $\textcolor{red}{-2.360}$ | `lvds_firefly_clk` | `Slow 1100mV 0C Model Setup` |
| top port lvds_firefly_clk | $\textcolor{red}{-1.126}$ | `lvds_firefly_clk` | `Fast 1100mV 85C Model Setup` |
| data_path_subsystem/lvds_rx_28nm_0 | $\textcolor{red}{-0.910}$ | `\g_feb_system_v3:q_feb_system|u_feb_system_v3|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `Slow 1100mV 85C Model Setup` |
| top port lvds_firefly_clk | $\textcolor{red}{-0.721}$ | `lvds_firefly_clk` | `Fast 1100mV 0C Model Setup` |

## 6. Loadable bitstream

Bitstream path: [`syn/top.sof`](syn/top.sof).

```bash
quartus_pgm -c "USB-BlasterII [7-2]" -m JTAG -o "p;firmware_builds/systems/v3_pretest-260511/syn/top.sof"
```

## 7. Rebuild instructions

The source Quartus project for this snapshot is `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/`. Rebuilds should happen there with its active project files and generated `feb_system_v3/synthesis/feb_system_v3.qip`; this `v3_pretest-260511` directory is intentionally a copied snapshot and should not be regenerated in place.

Legacy Qsys Tcl generators from that project are consolidated in [`../../../quartus_systems/`](../../../quartus_systems/) for archive visibility. New Platform Designer system changes still have to go through Tcl regenerator recipes, not raw XML edits.

## 8. Cross-references

- Source FEB SciFi README: `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/README.md`.
- Parent mu3e-ip-cores README IP table: [`../../../README.md`](../../../README.md).
- Iterative debug workflow for the 2-of-4 corner FEB acceptance gate: `~/.codex/skills/iterative-debug/SKILL.md`.
- Parser audit log for this README: [`syn/reports/parse_v3_pretest_readme.log`](syn/reports/parse_v3_pretest_readme.log).

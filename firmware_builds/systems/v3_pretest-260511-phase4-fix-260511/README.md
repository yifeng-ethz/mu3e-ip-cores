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
| ALMs | 61,385 / 91,680 ( 67 % ) |
| Registers | 91888 |
| Pins | 218 / 426 ( 51 % ) |
| Block memory bits | 4,032,202 / 13,987,840 ( 29 % ) |
| RAM blocks | 540 / 1,366 ( 40 % ) |
| DSP blocks | 0 / 800 ( 0 % ) |
| HSSI RX PCSs | 4 / 9 ( 44 % ) |
| HSSI PMA RX deserializers | 4 / 9 ( 44 % ) |
| HSSI TX PCSs | **8 / 9 ( 89 % )** |
| HSSI PMA TX serializers | **8 / 9 ( 89 % )** |
| PLLs | 7 / 21 ( 33 % ) |
| DLLs | 0 / 4 ( 0 % ) |

Cells are bold when utilization is greater than 80 percent.

Last refresh: `Successful - Mon May 11 17:21:23 2026`.

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
| data_path_subsystem/lvds_rx_28nm_0 | $\textcolor{red}{-1.080}$ | `u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `Slow 1100mV 85C Model Setup` |
| data_path_subsystem/lvds_rx_28nm_0 | $\textcolor{red}{-0.877}$ | `u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk` | `Slow 1100mV 0C Model Setup` |
| top port lvds_firefly_clk | $\textcolor{green}{+0.125}$ | `lvds_firefly_clk` | `Slow 1100mV 85C Model Setup` |
| top port lvds_firefly_clk | $\textcolor{green}{+0.276}$ | `lvds_firefly_clk` | `Slow 1100mV 0C Model Setup` |
| rcvdclkpma | $\textcolor{green}{+0.489}$ | `u_feb_system|u_firefly_xcvr|u_xcvr_native|ip_altera_xcvr_native_av_inst|gen_native_inst.av_xcvr_native_insts[1].gen_bonded_group_native.av_xcvr_native_inst|inst_av_pcs|ch[0].inst_av_pcs_ch|inst_av_hssi_8g_rx_pcs|wys|rcvdclkpma` | `Slow 1100mV 85C Model Setup` |

## 6. Loadable bitstream

Bitstream path: [`syn/top.sof`](syn/top.sof).

```bash
quartus_pgm -c "USB-BlasterII [7-2]" -m JTAG -o "p;firmware_builds/systems/v3_pretest-260511/syn/top.sof"
```

## 7. Rebuild instructions

The source Quartus project for this snapshot is `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/`. Rebuilds should happen there with its active project files and generated `feb_system_v3/synthesis/feb_system_v3.qip`; this `v3_pretest-260511` directory is intentionally a copied snapshot and should not be regenerated in place.

Legacy Qsys Tcl generators from that project are consolidated in [`../../../quartus_systems/`](../../../quartus_systems/) for archive visibility. New Platform Designer system changes still have to go through Tcl regenerator recipes, not raw XML edits.

## 8. SC Address Map

Audit date: 2026-05-11. Parent commit at audit time:
`1ea7940114d996ed79b1147298880fd0b66d9c20` ("[NEW] FEB v3_pretest-260511 fit
clean with rbCAM M10K closure"). Source of truth is the Qsys hierarchy under
`firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3.qsys` plus the
three v3 subsystem Qsys files in `quartus_systems/`.

### Top-level subsystem layout

`feb_system_v3.qsys` instantiates four subsystems (top qsys lines 254-417):

| Instance | Kind | Role |
|---|---|---|
| `control_path_subsystem` | `debug_sc_system_v3` | SC hub + JTAG master + slow-control slaves. |
| `data_path_subsystem` | `scifi_datapath_system_v3` | MuTRiG datapath, hit stack, frame assembly, run-control fanout. |
| `upload_subsystem` | `upload_system_v3` | LVDS upload muxer + `runctl_mgmt_host_0` (SWB-side run-control endpoint). |
| `bringup_subsystem` | `feb_bringup_system` | Isolated bring-up Nios II + onchip RAM + PIO + JTAG-UART. |

### Nios status (v3)

No Nios participates in the SC ring or the datapath. The only Nios in the
build is the bring-up Nios at `feb_bringup_system.qsys:147`
(`cpu`, kind=`altera_nios2_gen2`), whose memory map is private
(`ram` @ `0x10000000`, debug slave @ `0x70000000`, peripherals at `0x700F....`
— `feb_bringup_system.qsys` `dataSlaveMapParam`). The bring-up subsystem
exports only `clk_in`, `reset_in`, `si_gpio_out`, `si_status_in`
(`feb_bringup_system.qsys:129-140`) and is wired to only those at the top
(`feb_system_v3.qsys:210-217,505,550`). No AVMM, no avalon_streaming, no SC.

Slow control flows through `control_path_subsystem` only:
`sc_hub_v2` (`debug_sc_system_v3.qsys:664`) -> `sc_hub_cmd_pipe` (mm_bridge,
addr_width=18, `debug_sc_system_v3.qsys:360-377`) -> direct AVMM slaves and
two exported AVMM bridges (`mm_bridge.s0`, `upload_mm_bridge.s0`). A second
master path (`jtag_master`, `debug_sc_system_v3.qsys:267-280`) is wired in
parallel to the same slaves for System Console / `quartus_stp` access.

### Run-control connectivity (v3)

Verdict: **complete**. Primary path is SWB -> LVDS upload link ->
`upload_subsystem.runctl_mgmt_host` -> `data_path_subsystem.runctl_mgmt_host`
-> mux/splitter -> 14 datapath sinks.

Evidence:

- Top-level connection `upload_subsystem.runctl_mgmt_host -> data_path_subsystem.runctl_mgmt_host`
  is wired (`feb_system_v3.qsys:451-455`, `kind=avalon_streaming`).
- `upload_subsystem` instantiates `runctl_mgmt_host_0` of kind
  `runctl_mgmt_host` version `26.2.6.425`
  (`upload_system_v3.qsys:226-235`). It exports
  `runctl` (start, AVST, `upload_system_v3.qsys:154-158`) and `synclink`
  (end, AVST, `upload_system_v3.qsys:159-163`); the synclink endpoint is the
  SWB-driven LVDS run-control stream.
- `data_path_subsystem` exposes `runctl_mgmt_host` end -> `run_control_mux.in0`
  (`scifi_datapath_system_v3.qsys:883-887`). The 9-bit splitter
  `run_control_splitter` (16 outputs, 9 bits/symbol,
  `scifi_datapath_system_v3.qsys:1828-1848`) fans out to:
  `histogram_statistics_0.ctrl`, `mts_preprocessor_0.run_ctrl`,
  `mutrig_datapath_subsystem_0..7.run_ctrl`,
  `hit_stack_subsystem_0..1.run_control_signal`,
  `mts_preprocessor_1.run_ctrl`, `mutrig_injector_0.runctl`
  (`scifi_datapath_system_v3.qsys:2829-2955`).
- A secondary debug source `dbg_mm2runctrl_0.ctrl` is wired to
  `run_control_mux.in1` (`scifi_datapath_system_v3.qsys:2823-2825`). Its
  CSR is reachable on the SC ring at SC byte `0x22200`
  (`mm_bridge` base `0x20000` + inner `0x2200`; evidence
  `scifi_datapath_system_v3.qsys:2026-2027` and the avmm_port routing at
  `scifi_datapath_system_v3.qsys:809-810`).
- `control_path_subsystem` (`debug_sc_system_v3.qsys`) carries no
  `runctl_mgmt` instance and no run-control wires. This is by design — FEB
  run-control state is set by SWB via the LVDS sync-link path, not by the
  SWB-to-FEB SC ring.

No missing legs.

### SC slaves on the FEB v3 ring

Slaves below are reached via the FEB-side `sc_hub_v2` (`ADDR_WIDTH=18`,
`debug_sc_system_v3.qsys:664-700`). Qsys-byte addresses are taken from the
`sc_hub_cmd_pipe.m0 -> <slave>` connections inside `debug_sc_system_v3.qsys`.
Packet word address = Qsys byte / 4 per the sc_hub v2 word-addressing
convention. `sc_tool` accepts the Qsys byte address aligned to 4 (it widens
to 18-bit input and divides by 4 internally).

| # | Slave | Module kind | Qsys byte | Packet word | sc_tool input | Evidence |
|---|---|---|---|---|---|---|
|  1 | `scratch_pad_ram.s1` | `altera_avalon_onchip_memory2` | `0x00000` | `0x00000` | `0x00000` | `debug_sc_system_v3.qsys:851-853` |
|  2 | `onewire_master_controller_0.csr` | `onewire_master_controller` | `0x11000` | `0x04400` | `0x11000` | `debug_sc_system_v3.qsys:780-786` |
|  3 | `max10_prog_avmm_0.csr_avmm` | `max10_prog_avmm` | `0x12000` | `0x04800` | `0x12000` | `debug_sc_system_v3.qsys:798-804` |
|  4 | `charge_injection_pulser_0.csr_avmm` (WO) | `charge_injection_pulser` | `0x13000` | `0x04C00` | `0x13000` | `debug_sc_system_v3.qsys:807-813` |
|  5 | `firefly_xcvr_ctrl_0.firefly` | `firefly_xcvr_ctrl` | `0x14000` | `0x05000` | `0x14000` | `debug_sc_system_v3.qsys:816-822` |
|  6 | `on_die_temp_sense_ctrl.csr` | `altera_temp_sense_ctrl` | `0x15000` | `0x05400` | `0x15000` | `debug_sc_system_v3.qsys:789-795` |
|  7 | `legacy_firefly_bridge.s0` (-> `legacy_firefly_mon`) | `altera_avalon_mm_bridge` | `0x16000` | `0x05800` | `0x16000` | `debug_sc_system_v3.qsys:825-831` |
|  8 | `mm_bridge.s0` (-> `data_path_subsystem.avmm_port`) | `altera_avalon_mm_bridge` | `0x20000`-`0x2FFFF` | `0x08000`-`0x0BFFF` | window | `debug_sc_system_v3.qsys:842-845` + top qsys `feb_system_v3.qsys:421-426` |
|  9 | `upload_mm_bridge.s0` (-> `upload_subsystem.csr`) | `altera_avalon_mm_bridge` | `0x30000`-`0x3007F` | `0x0C000`-`0x0C01F` | window | `debug_sc_system_v3.qsys:836-840` + top qsys `feb_system_v3.qsys:430-434` |
| 10 | `mutrig_cfg_ctrl_0.avmm_csr` | `mutrig_cfg_ctrl` | `0x3F010` | `0x0FC04` | N/A (see note) | `debug_sc_system_v3.qsys:771-777` |

Notes:

- Slave count = **10** direct slaves on `sc_hub_cmd_pipe.m0` (the SC-hub
  command pipe's AVMM master). The sc_hub's own overlay CSR (HUB_CAP, etc.,
  `HUB_CAP_ENABLE=true` at `debug_sc_system_v3.qsys:678`) is exposed via the
  hub's reserved-address window — historically at packet word `0xFE80` per
  the `sc_hub v2` overlay map — and is not a Qsys-routed slave on this
  master. The legacy `test_slowcontrol` tool used this overlay; `sc_tool`
  does not.
- `mutrig_cfg_ctrl_0.avmm_csr` was placed at Qsys byte `0x3F010` — that
  word address `0xFC04` is outside the `sc_tool` 16-bit-input legacy reach,
  but **inside** the widened 18-bit input (sc_tool widened on 2026-04-13).
  Past practice for this slave used `test_slowcontrol`; current sc_tool can
  reach it at byte `0x3F010` (must be 4-aligned — `0x3F010` is aligned).
- Bridge windows (`mm_bridge`, `upload_mm_bridge`) are address ranges. The
  child slave maps below define what each byte offset inside the window
  reaches.

#### `mm_bridge` (window `0x20000`-`0x2FFFF`) — datapath AVMM map

The window enters `data_path_subsystem.avmm_port` (top qsys
`feb_system_v3.qsys:421-426`) and lands on the data_path
`mm_clock_crossing_bridge.s0` (`scifi_datapath_system_v3.qsys:805-815`).
Inner address map is published as `AUTO_AVMM_PORT_ADDRESS_MAP` on the
control_path module instantiation in the top qsys
(`feb_system_v3.qsys:259`). Inner offsets and their absolute SC byte:

| Inner module | Inner offset | SC byte = `0x20000` + inner |
|---|---|---|
| `lvds_rx_controller_pro_0.csr` | `0x0000`-`0x003F` | `0x20000`-`0x2003F` |
| `mutrig_datapath_subsystem_<k>.backpressure_fifo.csr` (k=0..7) | `0xk860`-`0xk86F` | `0x20860`+k*0x1000 |
| `mutrig_datapath_subsystem_<k>.mutrig_frame_deassembly_0.csr` (k=0..7) | `0xk900`-`0xk90F` | `0x20900`+k*0x1000 |
| `dbg_mm2runctrl_0.csr` (not in AUTO map; live connection) | `0x2200` | `0x22200` (evidence `scifi_datapath_system_v3.qsys:2026-2027`) |
| `mts_preprocessor_0.csr` | `0x4000`-`0x401F` | `0x24000` |
| `mts_preprocessor_1.csr` | `0x8000`-`0x801F` | `0x28000` |
| `histogram_statistics_0.hist_bin` | `0xA000`-`0xA3FF` | `0x2A000` |
| `histogram_statistics_0.csr` | `0xA400`-`0xA47F` | `0x2A400` |
| `histogram_statistics_1.hist_bin` | `0xA800`-`0xABFF` | `0x2A800` |
| `histogram_statistics_1.csr` | `0xAC00`-`0xAC7F` | `0x2AC00` |
| `hit_stack_subsystem_<n>.ring_buffer_cam_<k>.csr` (n=0..1, k=0..3) | `0xB000`+n*0x400+k*0x80 | `0x2B000`+n*0x400+k*0x80 |
| `mutrig_injector_0.csr` | `0xB200` | `0x2B200` |
| `hit_stack_subsystem_<n>.feb_frame_assembly_0.csr` (n=0..1) | `0xD000`+n*0x40 | `0x2D000`, `0x2D040` |

(Source: AUTO_AVMM_PORT_ADDRESS_MAP at `feb_system_v3.qsys:259`, plus the
live `dbg_mm2runctrl_0.csr` connection at
`scifi_datapath_system_v3.qsys:2023-2030` which is wired but not echoed in
the published AUTO map.)

#### `upload_mm_bridge` (window `0x30000`-`0x3007F`) — upload AVMM map

Enters `upload_subsystem.csr` (top qsys `feb_system_v3.qsys:430-434`) ->
`csr_bridge.s0` (`upload_system_v3.qsys:149-153, 210-225`) -> `csr_bridge.m0`
-> `runctl_mgmt_host_0.csr` (`upload_system_v3.qsys:297-305`).

| Inner module | Inner offset | SC byte |
|---|---|---|
| `runctl_mgmt_host_0.csr` | `0x0000` | `0x30000` |

### Datapath sub-AVMM access (System Console only)

`scifi_datapath_system_v3` also carries an internal `master_datapath` of kind
`altera_jtag_avalon_master` (`scifi_datapath_system_v3.qsys:1542-1555`)
that reaches the same data_path slave set without going through the SC ring.
It is reachable only from `quartus_stp` / System Console on the FEB JTAG
chain and is **not** an SC slave; listed here for completeness.

### Things to flag

- `dbg_mm2runctrl_0.csr` at SC byte `0x22200` is a live connection but is
  not echoed in the `AUTO_AVMM_PORT_ADDRESS_MAP` parameter on the
  `control_path_subsystem` instance (`feb_system_v3.qsys:259`). The
  parameter looks stale relative to the actual data_path connection set.
  Address routing still works (qsys-generate uses the live connections, not
  this label-only parameter), but the table at `feb_system_v3.qsys:259`
  should be regenerated next time the data_path subsystem is rebuilt to
  avoid confusion when reading the top qsys directly.
- `bringup_subsystem` is fully isolated — there is no path for SC, the
  data plane, or the SWB to touch the bring-up Nios. If the user expects
  to drive the bring-up Nios from the host, an explicit AVMM or
  avalon_streaming export must be added; today only conduits
  (`si_gpio_out`/`si_status_in`) leave the subsystem.
- The CLAUDE.md SC-map snippet was the FEB SciFi v2 map (16-bit
  addresses, slave count 8 plus the legacy `sc_hub` overlay slot). The v3
  ring uses 18-bit addresses end-to-end (`sc_hub_v2.ADDR_WIDTH=18`,
  `debug_sc_system_v3.qsys:665`), and `mutrig_cfg_ctrl_0.avmm_csr` is now
  reachable by current sc_tool at byte `0x3F010` rather than requiring
  `test_slowcontrol`.

## 9. Cross-references

- Source FEB SciFi README: `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/README.md`.
- Parent mu3e-ip-cores README IP table: [`../../../README.md`](../../../README.md).
- Iterative debug workflow for the 2-of-4 corner FEB acceptance gate: `~/.codex/skills/iterative-debug/SKILL.md`.
- Parser audit log for this README: [`syn/reports/parse_v3_pretest_readme.log`](syn/reports/parse_v3_pretest_readme.log).


<span id="readme-top"></span>

# Mu3e IP Library
<p>
  <a href="#license">
    <img src="https://img.shields.io/badge/license-Academic%20Evaluation-lightgrey.svg" alt="License badge" height="30" />
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/build-passing-brightgreen.svg" alt="Build status badge" height="30" />
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/platform-FPGA-blue.svg" alt="Platform badge" height="30" />
  </a>
</p>

<p align="middle">
  <a href="https://github.com/yifeng-ethz/mu3e-ip-cores">
    <img src="./quartus_system/logo/Logo_drawing300.png" alt="Mu3e Logo" width="150" />
  </a>
</p>


---

## Mu3e Experiment

The [Mu3e experiment](https://www.psi.ch/de/mu3e) at PSI pursues one of the most sensitive tests of charged lepton flavour violation: the decay $\mu^{+} \rightarrow e^{+} e^{-} e^{+}$. Within the Standard Model this channel is suppressed to branching ratios below $10^{-54}$, so any observation would point directly to new physics such as heavy neutral leptons, supersymmetric particles, or multi-TeV gauge bosons. Mu3e therefore aims for single-event sensitivities close to $\mathcal{O}(10^{-16})$ in Phase I and below $\mathcal{O}(10^{-16})$ in the Phase II upgrade, advancing $\mathcal{O}(10^{4})$ comparing to latest experiment SINDRUM in 1980s.

The collaboration also records so-called candle modes that are predicted by the Standard Model and serve as in-situ calibrations. The internal-conversion decay $\mu^{+} \rightarrow e^{+} e^{-} e^{+} \nu \bar{\nu} |\ B \approx 3.4 \times 10^{-5}$ ($3e2\nu$) and the rarer five-charged-lepton channel $\mu^{+} \rightarrow e^{+} e^{-} e^{+} e^{-} e^{+} \nu \bar{\nu}\ |\ B \approx (3.9–4.0) \times 10^{-10}$ ($5e2\nu$) provide precise control samples to validate momentum reconstruction, timing alignment, and background modelling. To note, $5e2\nu$ is the rarest measurable muon decay and Mu3e will be the first to observe it.

Achieving the design sensitivity requires an ultra-light detector composed of HV-MAPS MuPix pixels, scintillating fibre and tile timing layers, and a 1 T solenoidal field for momemtum and vertex resoluting on track-by-track bases (acceptance close to cover the full Michel spectrum, i.e., 10 MeV to 53 MeV) of $10^{8}$ muons per second in Phase I. The planned Phase II upgrade pushes the rate to $10^{9}$ muons per second using the High-Intensity Muon Beam (HiMB) line, demanding redesign part of the front-end chip with higher bandwidth and upgrade our triggerless DAQ capable to real-time reconstruct multi-terabit-per-second data streams. The IP cores in this repository includes the FPGA building blocks that make that readout strategy feasible.

---

## IP List

Each Mu3e IP core resides in its own subdirectory of this repository or in an external submodule. Cores marked as **Prototype** have no `VERSION` property and are still under development.

| IP Name | Description | Version / Status | Signoff |
|---|---|---|---|
| [**Slow‑Control Hub**](https://github.com/yifeng-ethz/slow-control_hub) | Converts Mu3e slow‑control packets into Avalon Memory‑Mapped transactions and handles burst count, address and response timing. | <img src="https://img.shields.io/badge/version-26.3.0-blue" alt="version 26.3.0 badge" width="200" /> | — |
| [**Onewire Temperature Sensor Controller**](https://github.com/yifeng-ethz/onewire_temp_sense) | Periodically polls 1‑Wire temperature sensors; implements reset, presence detect and bit‑level timing. | <img src="https://img.shields.io/badge/version-24.0.918-blue" alt="version 24.0.918 badge" width="200" /> | — |
| [**MuTRiG Frame Deassembly**](https://github.com/yifeng-ethz/mutrig_frame_deassembly) | Parses MuTRiG frames into header and hit payloads and flags individual hit errors and frame CRC errors. | <img src="https://img.shields.io/badge/version-26.0.0402-blue" alt="version 26.0.0402 badge" width="200" /> | — |
| [**CAM (Content Addressable Memory)**](https://github.com/yifeng-ethz/CAM) | Primitive content‑addressable memory core.  Use as a building block for caches, correlators and address decoders. | <img src="https://img.shields.io/badge/version-17.0.2-blue" alt="version 17.0.2 badge" width="200" /> | — |
| [**MuTRiG Timestamp Processor**](https://github.com/yifeng-ethz/mutrig_timestamp_processor) | Tracks MuTRiG timestamp overflow and maps MuTRiG‑local timestamps to global timestamps. | <img src="https://img.shields.io/badge/version-25.0.1031-blue" alt="version 25.0.1031 badge" width="200" /> | — |
| [**Histogram Statistics**](https://github.com/yifeng-ethz/histogram_statistics) | Builds histograms from a selected data stream using SAR bin calculation and DP‑RAM counters. | <img src="https://img.shields.io/badge/version-26.0.0321-blue" alt="version 26.0.0321 badge" width="200" /> | [DV](histogram_statistics/VERIFICATION_SIGNOFF.md) / [Syn](histogram_statistics/SYNTHESIS_SIGNOFF.md) |
| [**MuTRiG Controller**](https://github.com/yifeng-ethz/mutrig_controller) | SPI master for configuring MuTRiG ASICs.  Automatically scans T‑ and E‑thresholds and stores results locally. | <img src="https://img.shields.io/badge/version-24.0.0816-blue" alt="version 24.0.0816 badge" width="200" /> | — |
| [**Charge Injection (Analog Pulser)**](https://github.com/yifeng-ethz/charge_injection) | Generates calibration pulses with arbitrary frequency and duration for TDC injection tests. | <img src="https://img.shields.io/badge/version-4.0.5-blue" alt="version 4.0.5 badge" width="200" /> | — |
| [**Charge Injection (MuTRiG Injector)**](https://github.com/yifeng-ethz/charge_injection) | Produces digital and analog pulses to verify MuTRiG operation when used with DAB boards. | <img src="https://img.shields.io/badge/version-26.0.0326-blue" alt="version 26.0.0326 badge" width="200" /> | — |
| [**Altera Temperature Sensor Controller**](https://github.com/yifeng-ethz/alt_temp_sense_controller) | Wraps the on‑chip `alt_temp_sense` IP on 28 nm devices and stores the last temperature result. | <img src="https://img.shields.io/badge/version-1.0-blue" alt="version 1.0 badge" width="200" /> | — |
| [**High Performance Counter Array**](https://github.com/yifeng-ethz/high_performance_counter_array) | Parallel counters supporting concurrent inputs with Avalon‑MM readout.  Features synchronous clear and reset. | <img src="https://img.shields.io/badge/version-1.4.1-blue" alt="version 1.4.1 badge" width="200" /> | — |
| [**MuTRiG Channel Counter Fabric**](https://github.com/yifeng-ethz/mutrig_channel_counter_fabric) | Connects *hit type 0* from the frame deassembly IP to the counter array.  Decodes channel IDs into one‑hot update signals. | <img src="https://img.shields.io/badge/version-1.0.12-blue" alt="version 1.0.12 badge" width="200" /> | — |
| [**LVDS Error Counter Fabric**](https://github.com/yifeng-ethz/lvds_error_counter_fabric) | Accumulates parity and decode error counts from the LVDS receiver sideband. | <img src="https://img.shields.io/badge/version-1.0.5-blue" alt="version 1.0.5 badge" width="200" /> | — |
| [**Firefly Transceiver I2C Master**](https://github.com/yifeng-ethz/firefly_xcvr_i2c_master) | Interfaces with the Samtec Firefly optical transceiver module via I2C.  Periodically reads temperature and RX power and can be halted. | <img src="https://img.shields.io/badge/version-26.0.0330-blue" alt="version 26.0.0330 badge" width="200" /> | — |
| [**IP 8b/10b Decoder**](https://github.com/yifeng-ethz/ip_8b10b_decoder) | Standard 8b/10b decoder for parallel LVDS `rxout` data.  Derives parity and decoding errors. | <img src="https://img.shields.io/badge/version-1.3.1-blue" alt="version 1.3.1 badge" width="200" /> | — |
| [**MuTRiG Reset Controller**](https://github.com/yifeng-ethz/mutrig_reset_controller) | Issues reset pulses for the MuTRiG based on run‑state changes.  Provides programmable phase shift via `alt_pll_reconfig`. | <img src="https://img.shields.io/badge/version-1.0.8-blue" alt="version 1.0.8 badge" width="200" /> | — |
| [**Ring‑buffer CAM**](https://github.com/yifeng-ethz/ring-buffer_cam) | Circular buffer variant of CAM with push‑to‑stack write semantics and cache‑like read‑through.  Used to build the hit stack. | <img src="https://img.shields.io/badge/status-Protected-red" alt="Protected badge" width="200" /> | [Standalone](ring-buffer_cam/SIGNOFF.md) |
| [**Frontend‑Board Frame Assembly**](https://github.com/yifeng-ethz/feb_frame_assembly) | Assembles time‑interleaved subframes from the ring‑buffer CAM into Mu3e‑standard data frames and schedules packet transmission. | <img src="https://img.shields.io/badge/version-26.0.0328-blue" alt="version 26.0.0328 badge" width="200" /> | — |
| [**FEB MAX10 Communication Bridge**](https://github.com/yifeng-ethz/feb_max10_comm) | FEB-side Arria V bridge that stages one flash page, crosses it into the MAX10 link domain, and preserves the downstream FEBSPI programming contract. | <img src="https://img.shields.io/badge/version-0.1.0-blue" alt="version 0.1.0 badge" width="200" /> | — |
| [**Mu3e LVDS Controller**](https://github.com/yifeng-ethz/mu3e_lvds_controller) | Provides high‑speed LVDS links to the MuPix sensors using FPGA vendor IP.  Includes 28 nm LVDS RX and Pro variants. | <img src="https://img.shields.io/badge/version-25.1.0630-blue" alt="version 25.1.0630 badge" width="200" /> | — |
| [**MuPix Inbound**](https://github.com/yifeng-ethz/mupix_inbound) | Deserializes data from MuPix chips, decodes and buffers hits. | <img src="https://img.shields.io/badge/status-Prototype-lightgrey" alt="Prototype badge" width="200" /> | — |
| [**Packet Scheduler**](https://github.com/yifeng-ethz/packet_scheduler) | Orders packets via an interface adapter and an ordered priority queue to achieve deterministic throughput. | <img src="https://img.shields.io/badge/version-25.0.0723-blue" alt="version 25.0.0723 badge" width="200" /> | — |
| [**MuTRiG Emulator**](https://github.com/yifeng-ethz/emulator_mutrig) | FPGA emulator of MuTRiG 3 ASIC digital output. Produces 8b/1k frames bit‑compatible with real ASIC output for FPGA‑internal verification. | <img src="https://img.shields.io/badge/version-26.0.1.0412-blue" alt="version 26.0.1.0412 badge" width="200" /> | [Standalone](emulator_mutrig/SIGNOFF.md) |
| [**Run‑Control Management**](https://github.com/yifeng-ethz/run-control_mgmt) | Manages run‑state transitions for Mu3e subsystems and issues control signals. | <img src="https://img.shields.io/badge/version-24.0.1125-blue" alt="version 24.0.1125 badge" width="200" /> | — |

`Signoff` links point to checked-in standalone evidence. `—` means no signoff document is currently indexed from this top-level catalog.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## About the Project

The Mu3e detector relies on fully monolithic HV-MAPS MuPix sensors with $\mathbf{80 \times 80\ \mu m^{2}}$ pixels, providing per-hit timestamps of $\sigma\approx 20\ \mathrm{ns}$ with $\mathbf{50\ \mu m}$ thickness and serialising zero-suppressed data at up to $\mathbf{1.25\ \mathrm{Gbit/s}}$ per link. Timing layers combine $\sim 250\ \mu\mathrm{m}$ scintillating fibres read by SiPM arrays and fast plastic scintillator tiles to reach $\mathbf{< 100\ \mathrm{ps}}$ time-of-flight resolution. On L2 and L3, all sub-detectors **Front-End Boards** (FEBs) feed custom **Detector Adapter Boards** (DABs) that fan out 3380 1.25 Gbps low-voltage differential links (LVDS). These FEBs upload via optical FireFly transceivers on L4 to route traffic to **Switching Boards** (SWBs) populated with Arria 10 FPGAs for link aggregation. A full detector slice already moves in excess of $\mathbf{1.5\ \mathrm{Tbit/s}}$ during Phase I operation, with Phase II designs targeting several multi-terabit fabrics to handle the HiMB rate.

The firmware stack orchestrated by this repository spans the complete readout chain: packet schedulers for G/D/1 deterministic multiplexing, MuTRiG slow-control SPI and configuration hardware core, timestamp processors that unify the MuTRiG counting scheme (625 MHz) into the Mu3e counting scheme (125 MHz), histogramming for online monitoring, and Altera Network-on-Chip (NoC) that stitch the system together. Reference Platform Designer TCL scripts and hardware abstraction packages ensure each IP can be regenerated reproducibly, while synthesizable testbenches and Python drivers enable continuous regression testing in ModelSim/Questa environments. The codebase currently comprises more than $\mathbf{300 k}$ lines of HDL, TCL, and support scripts spread across the IP submodules. After system generation, each subdetector typically end up with synthesis RTL of $\mathcal{O}(1 M)$. 

---

## Built With

- **Intel Quartus Prime** – for FPGA synthesis and Platform Designer integration
- **ModelSim / Questa** – for simulation and verification
- **Python** – used in simulation testbenches and tooling
- **Tcl** – for Platform Designer scripts and System Console debugging

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Directory Structure

```text
mu3e-ip-cores/
├── CAM/                        # Content addressable memory core
├── alt_temp_sense_controller/  # On‑chip temperature diode wrapper
├── charge_injection/           # Analog pulser and MuTRiG injector variants
├── feb_frame_assembly/         # Frontend-board frame assembly
├── feb_max10_comm/             # FEB-side MAX10 flash programming bridge
├── firefly_xcvr_i2c_master/    # I2C master for Samtec Firefly transceiver
├── high_performance_counter_array/
├── histogram_statistics/
├── ip_8b10b_decoder/
├── lvds_error_counter_fabric/
├── emulator_mutrig/            # MuTRiG 3 ASIC emulator (8b/1k frame generator)
├── misc/                       # Local debug/helper IPs kept outside submodules
├── mu3e_lvds_controller/
├── mupix_inbound/
├── mutrig_channel_counter_fabric/
├── mutrig_controller/
├── mutrig_frame_assembly/
├── mutrig_frame_deassembly/
├── mutrig_reset_controller/
├── mutrig_timestamp_processor/
├── onewire_temp_sense/         # 1-Wire controllers plus FEB v1 bridge helper
├── packet_scheduler/
├── quartus_system/             # Qsys wrapper, IP catalogs, and catalog scripts
├── ring-buffer_cam/
├── run-control_mgmt/
└── slow-control_hub/
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Getting Started

### Prerequisites

- **Quartus Prime 18.1** or later (18.1 recommended)
- **Python 3.10+** (for testbenches)
- **ModelSim / Questa** for simulation
- **Tcl 8.5+** for integration scripts

### Installation

1. Clone this repository and its submodules:
   ```bash
   git clone --recursive https://github.com/yifeng-ethz/mu3e-ip-cores.git
   cd mu3e-ip-cores
   ```
2. (optional) Regenerate the normalized Platform Designer catalogs used by Quartus and downstream tooling.
   ```bash
   ./quartus_system/regenerate_ipx_catalog.sh
   ```
   This refreshes `quartus_system/components.ipx` and `quartus_system/mu3e_ip_cores.ipx`.
3. Add environment variable to provided Platform Designer (mainly `*_hw.tcl` file) the IPs.
   ```bash
   export QSYS_IP_FILE_PATH=$QSYS_IP_FILE_PATH:$(pwd)/quartus_system
   ```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Usage

Detailed integration instructions are provided in each core’s subdirectory.  In general:
- GUI:
  1. Open Platform Designer (formerly Qsys) in Quartus.
  2. Select **IP search path** to source the corresponding `*_hw.tcl` script to instantiate the IP.
- CLI:
  1. Configure parameters (e.g., burst widths, channel counts) as required for your design.
    ```bash
    qsys-edit <path_to_your_system>.qsys # or leave it empty
    ```
  2. Export generated system top RTL file and connect the IP into your top‑level design or testbench.
    ```bash
    qsys-generate <path_to_your_system>.qsys --search-path="$(pwd)/quartus_system,$" --synthesis=VHDL --output-directory=./generated
    ```

    

    

For simulation, the subdirectories include VHDL testbenches and Python scripts demonstrating correct operation.

---

## Contributing

Contributions to the Mu3e IP Library are welcome for academic and research purposes under the Academic Evaluation License.

As several cores and algorithms are under active patent filing, contributions must follow the rules below:

1.	Scope — Contributions are accepted for research, validation, and reproducibility. Commercial or derivative use is not permitted without written consent.
2.	Fork and Branch — Fork this repository under your academic or institutional account. Create a feature branch (e.g., feature/my_lab_fix).
3.	Document Clearly — Use descriptive commit messages. Include a concise technical summary of changes and your institutional affiliation.
4.	Submit a Pull Request — Open a PR describing your improvement, test results, or bug fix. The maintainer will review for technical compatibility and possible overlap with ongoing patent filings.
5.	Contributor Agreement — By submitting a contribution, you agree that:
	- You retain copyright of your original code.
	- You grant us a perpetual, non-exclusive right to incorporate, modify, or relicense your contribution under the same Academic Evaluation License.
	- You acknowledge that no patent rights are transferred or implied and that underlying Mu3e IP patent rights remain solely with us.

For commercial collaboration or technology-transfer discussions, please contact one of us:

  yifenwan@phys.ethz.ch \
  rwallny@phys.ethz.ch \
  mkoepp@phys.ethz.ch \
  schoning@physi.uni-heidelberg.de \
  niberger@uni-mainz.de \
    ...
    
---

## License

Mu3e IP Cores — Academic Evaluation License
Copyright (c) 2025 Mu3e Collaboration, Yifeng Wang, et al. All rights reserved.

Permission is hereby granted, free of charge, to academic researchers,
universities, and non-commercial institutions to use and evaluate this
source code for research, teaching, and internal experimental purposes only.

The following conditions apply:

1. Redistribution of this source code, in whole or in part, is prohibited.
2. Use, modification, or integration of this source code or any derivative
   work in a commercial product, service, or hardware design is strictly
   prohibited without prior written consent from the copyright holder.
3. Any publication, report, or presentation using results obtained from
   this code must include the acknowledgment:
       “Mu3e IP Cores © 2025 Mu3e Collaboration, used under Academic Evaluation License.”
4. No patent rights are granted, explicitly or implicitly. All patent rights
   related to the algorithms, architectures, and designs implemented in this
   repository are fully reserved by the author. Patent filings are ongoing.
5. This software is provided “AS IS”, without warranty of any kind,
   express or implied, including but not limited to the warranties of
   merchantability, fitness for a particular purpose, and non-infringement.

For commercial licensing, technology transfer, or collaboration inquiries,
please contact yifenwan@phys.ethz.ch or visit https://transfer.ethz.ch 

---

## Acknowledgments

- Mu3e Collaboration at PSI
  - [**ETH Zürich – Rainer Wallny Group**](https://wallny-group.phys.ethz.ch)
  - Université de Genève
  - Universität Zürich
  - Paul Scherrer Institut
  - Universität Heidelberg
  - Karlsruhe Institut für Technologie
  - Johannes Gutenberg-Universität Mainz
  - University of Bristol
  - University of Liverpool
  - University of Oxford
  - University College London

<p align="right">(<a href="#readme-top">back to top</a>)</p>

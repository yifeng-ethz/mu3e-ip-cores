# Mu3e IP Library

## IP List

|IP Name|IP Description|Status|
|:-----:|:------------:|:----:|
|Slow-Control Hub|Translate the **Mu3e Slow-Control packet** into **Avalon Memory-Mapped** transations.|Release|
|Onewire Temperature Sensor Controller|Periodically read the temperature sensor with **1-Wire** protocol.|Release| 
|MuTRiG Frame Deassembly|Dismantle the MuTRiG frame into header and hits. Derive individual **hit error** and **frame CRC error**.|Release|
|CAM (Content Addressable Memory)|Primitive of CAM. Use an template for user to construct their own complex system. *For example, build a CPU-cache, bookkeeping roster, correlator, IP-address to MAC address decoder, etc...*|Minor Debug|
|MuTRiG Timestamp Processor|Process the timestamp of the MuTRiG (i.e. tracking overflow and mapping **MuTRiG timestamp to Global timestamp**)|Release|
|Histogram Statistics|Build histogram with update/filter key from selected data segment. Snoop on the data stream. High-performace: SAR bin-calculation and DP-RAM counter.|Release|
|MuTRiG Controller|Perform **SPI** configuration of the attached MuTRiG(s) and automatically scan the T-Threshold values (use their last configs). Scan results for all channels are stored locally.|Release|
|Charge Injection|Generate digital pulse with **arbitary** frequency and duration. Use in pair with correct hardware (e.g. **DAB2.1** or older for TDC injection or **DAB2.2** or newer for TDC and analog injection). Targeted to functionally verify the MuTRiG given the test pulse.|Release|
|Altera Temperature Sensor Controller|Interfacing with the official `alt_temp_sense` IP on **28 nm** device. Store the last result. Can be halted|Release|
|High Performace Counter Array|Parallel counters allowing **concurrent inputs**. Read out with Avalon Memory-Mapped Interface. Feat. `sync clear` and `sync reset`|Release|
|MuTRiG Channel Counter Fabric|Connect **hit type 0** from `MuTRiG Frame Deassembly` IP to the `High Performace Counter Array` IP. Decode binary channel ID into one-hot update signals to the counter array.|Release| 
|LVDS Error Counter Fabric|Connect to **Streaming Error** sideband for collecting decoding and parity error counts.|Release|
|Firefly Tranceiver I2C Master|Interfacing with the **Samtec Firefly Optical Tranceiver Module**, including the **I2C** master. Peridically readout the temperature and RX power. Can be Halted.|Release|
|IP 8b10b Decoder|Standard **8b10b decoder** for parallel lvds `rxout` data. Derive parity and decoding error.|Release|
|MuTRiG Reset Controller|Issue reset for the MuTRiG from **`run state`** signal of the `run control mgmt` interface. Arbitary phase shift of the reset pulse utilizing the `alt_pll_reconfig` module.|Debug|
|Ring-buffer CAM|The **ring-buffer shaped CAM**. Write is similar to *push to stack*, read is similar to *cache write-through*. Used as an primitive to construct the `hit_stack` subsystem.|Release|


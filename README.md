# Mu3e IP Library

## IP List

|IP Name|IP Description|Status|
|:-----:|:------------:|:----:|
|Slow-Control Hub|Translate the Mu3e Slow-Control packet into Avalon Memory-Mapped transations.|Release|
|Onewire Temperature Sensor Controller|Periodically read the temperature sensor with onewire protocol.|Release| 
|MuTRiG Frame Deassembly|Dismantle the MuTRiG frame into header and hits. Derive individual hit error and frame CRC error.|Release|
|CAM (Content Addressable Memory)|Primitive of CAM. Use an template for user to construct their own complex system. For example, build a CPU-cache, bookkeeping roster, correlator, IP-address to MAC address decoder, etc...|Minor Debug|
|MuTRiG Timestamp Processor|Process the timestamp of the MuTRiG (i.e. tracking overflow and mapping MuTRiG timestamp to Global timestamp)|Release|
|Histogram Statistics|Build histogram with update/filter key from selected data segment. Snoop on the data stream. High-performace: SAR bin-calculation and DP-RAM counter.|Release|
|MuTRiG Controller|Perform SPI configuration of the attached MuTRiG(s) and automatically scan the T-Threshold values (use their last configs). Scan results for all channels are stored locally.|Release|


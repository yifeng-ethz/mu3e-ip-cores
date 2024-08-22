# Mu3e IP Library

## IP List

|IP Name|IP Description|Status|
|:-----:|:------------:|:----:|
|Slow-Control Hub|Translate the Mu3e Slow-Control packet into Avalon Memory-Mapped transations.|Release|
|Onewire Temperature Sensor Controller|Periodically read the temperature sensor with onewire protocol.|Release| 
|MuTRiG Frame Deassembly|Dismantle the MuTRiG frame into header and hits, derive individual hit error and frame CRC error.|Release|
|CAM (Content Addressable Memory)|Primitive of CAM, as an template for user to construct complex system for the needed functionality. For example, build as a CPU-cache, bookkeeping roster, correlator, IP-address to MAC address decoder, etc...|Minor Debug|
|MuTRiG Timestamp Processor|Process the timestamp of the MuTRiG (i.e. tracking overflow and mapping MuTRiG timestamp to Global timestamp)|Release|
|Histogram Statistics|Snoop on the data stream and build histogram with update/filter key from selected data segment. High-performace: SAR bin-calculation and DP-RAM counter.|Release|
|MuTRiG Controller|Perform configuration of the attached MuTRiG(s) and automatically scan the T-Threshold (use the last config). Scan result for all channels are stored locally.|Release|


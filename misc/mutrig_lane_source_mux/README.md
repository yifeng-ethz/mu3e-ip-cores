# MuTRiG Lane Source Mux

`mutrig_lane_source_mux` is a per-lane source combiner for FE SciFi MuTRiG
bring-up. It accepts the real decoded LVDS stream and the local
`emulator_mutrig` stream, then forwards one Avalon-ST decoded stream into the
lane datapath.

The source mode is runtime-controlled through a 16-word Avalon-MM CSR aperture.
Each lane has its own instance and can be configured independently:

| Mode | CONTROL | Behavior |
|---|---:|---|
| Real | `0x0` | Forward only the real MuTRiG stream. |
| Emulator | `0x1` | Forward only the emulator stream. |
| Mixed RR | `0x4` | Buffer both inputs and arbitrate non-empty FIFOs round-robin. |

`CONTROL[1]` is a write-one pulse that clears counters and mixed-mode FIFOs.
Entering or leaving mixed mode also flushes the mixed-mode FIFOs.

Mixed mode is intended for debug and controlled tests. The input streams have
no backpressure, so each input has a shallow FIFO and exposes overflow drop
counters at `REAL_DROPS` and `EMU_DROPS`.

# Mu3e Packet Format Notes

This note captures the packet-field semantics used by the packet transaction traffic analyzer.
The source of truth is `Mu3eSpecBook-4.pdf`, pages 147-148.

## Scope

The analyzer keeps two decode modes:

- `mu3e-spec`
  - uses the Mu3e spec-book naming and 32-bit hit layouts
- `musip-demo`
  - preserves the older local replay/demo overlay for comparison with existing workspace examples

Only `mu3e-spec` should be treated as the protocol reference.

## Front-End Packet Structure

The spec-book states that front-end data words are 32 bits.
Packets begin with a preamble word containing `K28.5` in bits `[7:0]` and end with a trailer word containing `K28.4` in bits `[7:0]`.

Preamble:

- `[31:26]` packet type
- `[25:24]` slow-control subtype for slow-control packets, otherwise unused
- `[23:8]` FPGA ID
- `[7:0]` `K28.5`

The packet header/debug words then carry:

- timestamp `[47:16]`
- timestamp `[15:0]` plus package counter
- subheader counter plus hit counter
- send timestamp counter

Subheader:

- `[31:24]` `ts(11:4)`
- `[23:8]` overflow indicators
- `[7:0]` `K23.7`

Trailer:

- `[31:8]` remaining overflow indicators
- `[7:0]` `K28.4`

## 32-Bit Hit Layouts

MuPix hit:

- `[31:28]` `ts(3:0)`
- `[27:22]` `chip id`
- `[21:14]` `col`
- `[13:5]` `row`
- `[4:1]` `tot`
- `[0]` reserved

SciFi / Tile hit:

- `[31:28]` `ts(3:0)`
- `[27:22]` `chip id`
- `[21:16]` `channel id`
- `[15:8]` `ts 50ps`
- `[7:0]` `energy`

Additional notes from the same section:

- Tile MuTRiG ASIC number is `0..12`
- SciFi MuTRiG ASIC number is `0..7`
- the `ts 50ps` byte carries the fine counter plus the coarse-counter remainder described in the spec-book

## Analyzer Mapping

The analyzer derives the hit layout from the packet type in the preamble:

- MuPix and MuPix Debug use the MuPix 32-bit hit layout
- SciFi, SciFi Debug, Tile, and Tile Debug use the SciFi/Tile 32-bit hit layout
- other packet classes fall back to raw-word display

`FEB_DATA_FRAME` exports both the raw 32-bit word and the spec-derived decoded fields so the HTML view, WaveDrom annotations, and later Electron packaging can share the same decode contract.

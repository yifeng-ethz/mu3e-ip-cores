# Packet Transaction Traffic Analyzer

HTML-first packet-analyzer tooling for MuSiP / Mu3e packet-level transaction traces.

This tool is intended to stay git-tracked under `mu3e-ip-cores/tools/` while the
generated demo outputs continue to live in the active workspace.

## Contents

- `assets/packet-analyzer/`
  - static browser app, styles, and HTML template
- `assets/wavedrom/`
  - vendored WaveDrom runtime used by the local waveform surface
- `references/mu3e_packet_format.md`
  - checked-in summary of the Mu3eSpecBook packet and 32-bit hit layouts used by `mu3e-spec`
- `scripts/feb_data_frame.py`
  - export the shared `FEB_DATA_FRAME` JSON model from a replay VCD, including spec-derived subheader and hit decode fields
- `scripts/generate_musip_packet_analyzer.py`
  - generate an analyzer bundle from a replay VCD
- `scripts/run_packet_analyzer_visual_debug.py`
  - Selenium click-depth validation with screenshots and browser/app error capture
- `scripts/serve_packet_analyzer.py`
  - serve a generated analyzer bundle over HTTP

## Typical Flow

Generate:

```bash
python3 tools/packet_transaction_traffic_analyzer/scripts/generate_musip_packet_analyzer.py \
  --vcd tb_int/report/wave/opq_twoframe_260422/sim/opq_twoframe_replay.vcd \
  --out-dir tb_int/report/wave/opq_twoframe_260422/packet_analyzer \
  --frame-start 1 \
  --frame-count 2
```

Optional raw export:

```bash
python3 tools/packet_transaction_traffic_analyzer/scripts/feb_data_frame.py \
  --vcd tb_int/report/wave/opq_twoframe_260422/sim/opq_twoframe_replay.vcd \
  --out-json tb_int/report/wave/opq_twoframe_260422/packet_analyzer/feb-data-frame.json \
  --frame-start 1 \
  --frame-count 2
```

Serve:

```bash
python3 tools/packet_transaction_traffic_analyzer/scripts/serve_packet_analyzer.py \
  --dir tb_int/report/wave/opq_twoframe_260422/packet_analyzer \
  --port 8765
```

Visual debug:

```bash
python3 tools/packet_transaction_traffic_analyzer/scripts/run_packet_analyzer_visual_debug.py \
  --url http://127.0.0.1:8765/ \
  --out-dir tb_int/report/wave/opq_twoframe_260422/packet_analyzer/visual_debug
```

## Current Correlation Surface

The analyzer now renders its own local WaveDrom surface directly inside the page.
That surface is fed from the same generated `FEB_DATA_FRAME` hierarchy as the packet trace:

1. ingress `FEB_DATA_FRAME` view for the selected lane or `All Lanes`
2. merged OPQ egress view from `opq_if`
3. downstream DMA payload view correlated back to the selected frame pair

Frame rows are top-level packets.
Each subheader plus its hit words is emitted as one integral subpacket row.
WaveDrom annotation tags support hover tooltips, click-to-select, and right-click navigation into the packet analyzer views.

## Decode Source Of Truth

`mu3e-spec` is anchored to `Mu3eSpecBook-4.pdf` pages 147-148.
That includes the 32-bit hit layouts:

- MuPix: `[31:28] ts(3:0)`, `[27:22] chip id`, `[21:14] col`, `[13:5] row`, `[4:1] tot`, `[0] reserved`
- SciFi/Tile: `[31:28] ts(3:0)`, `[27:22] chip id`, `[21:16] channel id`, `[15:8] ts 50ps`, `[7:0] energy`

The checked-in note at `references/mu3e_packet_format.md` is the local repo summary of that mapping.

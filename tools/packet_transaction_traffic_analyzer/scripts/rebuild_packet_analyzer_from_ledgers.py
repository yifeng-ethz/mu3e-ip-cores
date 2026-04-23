#!/usr/bin/env python3
"""Rebuild packet analyzer bundles from checked-in ledger HTML outputs.

The original VCD-backed packet analyzer generator backend is unavailable in
this workspace. This script recovers static analyzer bundles from the promoted
`index.ledger.*.html` artifacts that still exist under `wave_reports/`.
"""

from __future__ import annotations

import argparse
import copy
import html
import json
import os
import re
import shutil
from collections import OrderedDict
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[3]
ASSET_DIR = ROOT / "tools/packet_transaction_traffic_analyzer/assets/packet-analyzer"
WAVEDROM_ASSET_DIR = ROOT / "tools/packet_transaction_traffic_analyzer/assets/wavedrom"

STREAM_ROW_RE = re.compile(r"<tr>(.*?)</tr>", re.S)
CELL_RE = re.compile(r"<t[dh]>(.*?)</t[dh]>", re.S)
TAG_RE = re.compile(r"<.*?>", re.S)
PAYLOAD_WORDS_RE = re.compile(r"expected_words=(\d+)")
SLOT_RE = re.compile(r"s(?P<slot>\d+):\s*(?P<body>.*?)(?=(?:\s*\|\s*s\d+:)|$)")
PANEL_CHUNK_FILE_RE = re.compile(r"index\.panel\.(?P<panel>[A-Za-z0-9_]+)\.chunk(?P<chunk>\d+)\.json$")
PANEL_CYCLE_RE = re.compile(r"cycles\s+(?P<start>\d+)\.\.(?P<end>\d+)", re.I)
PANEL_HEAD_RE = re.compile(r"^(?P<title>.*?)(?:\s+chunk\s+(?P<chunk>\d+)/(?P<count>\d+))?(?::\s*(?P<detail>.*))?$", re.I)

TONES = {
    "frontend": {"label": "#a8c0ff", "value": "#edf3ff", "text": "#11264d", "border": "#7896dc"},
    "fpga": {"label": "#f1c19b", "value": "#fff0e5", "text": "#5a2e12", "border": "#ca8d62"},
    "timestamp": {"label": "#95d9d5", "value": "#e9fbfa", "text": "#113c39", "border": "#68a6a2"},
    "count": {"label": "#f0d28c", "value": "#fff6de", "text": "#5a4211", "border": "#c5a45a"},
    "index": {"label": "#d1c1f1", "value": "#f7f1ff", "text": "#38245d", "border": "#9b88c8"},
    "preview": {"label": "#efb4c1", "value": "#fff0f3", "text": "#5d1f31", "border": "#c57d90"},
    "control": {"label": "#b6e3a7", "value": "#effbea", "text": "#234718", "border": "#81af72"},
    "reserved": {"label": "#d2d7df", "value": "#f7f8fa", "text": "#2f3641", "border": "#97a2b0"},
    "col": {"label": "#a8c0ff", "value": "#edf3ff", "text": "#11264d", "border": "#7896dc"},
    "row": {"label": "#f0d28c", "value": "#fff6de", "text": "#5a4211", "border": "#c5a45a"},
    "chip": {"label": "#f1c19b", "value": "#fff0e5", "text": "#5a2e12", "border": "#ca8d62"},
    "tot": {"label": "#efb4c1", "value": "#fff0f3", "text": "#5d1f31", "border": "#c57d90"},
    "slots": {"label": "#b7e6c6", "value": "#eefcf2", "text": "#1f4a2b", "border": "#81b793"},
}

FAMILIES = [
    {"id": "frame", "label": "Frames"},
    {"id": "subpacket", "label": "SubPkts"},
]

DECODE_MODES = [
    {"id": "mu3e-spec", "label": "Mu3e Spec Decode"},
]

LEGACY_WAVE_PANEL_ORDER = ["ingress", "egress", "dma"]
LEGACY_WAVE_PANEL_TITLES = {
    "ingress": "Ingress to OPQ",
    "egress": "Merged OPQ egress",
    "dma": "PCIe app payload",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--wave-reports-root",
        type=Path,
        default=Path("/home/yifeng/packages/musip_2604/tb_int/wave_reports"),
        help="Root containing bucket/case wave report bundles.",
    )
    parser.add_argument(
        "--landing-case",
        default="PROF/P041",
        help="Bucket/case to treat as the primary served bundle for the /cases alias tree.",
    )
    return parser.parse_args()


def strip_html(text: str) -> str:
    return html.unescape(TAG_RE.sub("", text)).strip()


def parse_table_rows(path: Path, first_header: str) -> list[list[str]]:
    text = path.read_text()
    rows: list[list[str]] = []
    for tr in STREAM_ROW_RE.findall(text):
        cells = [strip_html(cell) for cell in CELL_RE.findall(tr)]
        if not cells or cells[0].lower() == first_header.lower():
            continue
        rows.append(cells)
    return rows


def parse_time_ps(text: str) -> int:
    return int(round(float(text.replace(" ns", "").strip()) * 1000))


def format_ns(time_ps: int) -> str:
    return f"{time_ps / 1000:.3f} ns"


def grouped_bits(value: int, width: int) -> str:
    bits = f"{value:0{width}b}"
    return " ".join(bits[index:index + 4] for index in range(0, len(bits), 4))


def hex_width(width: int) -> int:
    return max(1, (width + 3) // 4)


def format_hex(value: int, width: int) -> str:
    return "0x" + format(value, f"0{hex_width(width)}X")


def classify_wave_panel_section(panel_name: str) -> str:
    lowered = panel_name.lower()
    if "dma" in lowered:
        return "dma"
    if "egress" in lowered or "opq" in lowered:
        return "egress"
    return "ingress"


def legacy_wave_slot_count(signal: list) -> int:
    for entry in signal or []:
        if isinstance(entry, list):
            nested = legacy_wave_slot_count(entry[1:])
            if nested > 0:
                return nested
        elif isinstance(entry, dict) and isinstance(entry.get("wave"), str):
            return len(entry["wave"])
    return 0


def parse_legacy_panel_chunk(path: Path) -> dict | None:
    match = PANEL_CHUNK_FILE_RE.fullmatch(path.name)
    if not match:
        return None
    payload = json.loads(path.read_text())
    head_text = str(((payload.get("head") or {}).get("text")) or "").strip()
    head_match = PANEL_HEAD_RE.match(head_text)
    cycle_match = PANEL_CYCLE_RE.search(head_text)
    cycle_start = int(cycle_match.group("start")) if cycle_match else None
    cycle_end = int(cycle_match.group("end")) if cycle_match else None
    detail = (head_match.group("detail") if head_match else "") or ""
    if cycle_match:
        detail = PANEL_CYCLE_RE.sub("", detail).strip(" ,:")
    slot_count = (
        max(1, cycle_end - cycle_start + 1)
        if cycle_start is not None and cycle_end is not None and cycle_end >= cycle_start
        else legacy_wave_slot_count(payload.get("signal") or [])
    )
    return {
        "panelName": match.group("panel"),
        "panelSection": classify_wave_panel_section(match.group("panel")),
        "chunkIndex": int(match.group("chunk")),
        "title": ((head_match.group("title") if head_match else "") or "").strip(),
        "detail": detail,
        "cycleStart": cycle_start,
        "cycleEnd": cycle_end,
        "slotCount": slot_count,
        "src": f"./{path.name}",
    }


def collect_legacy_wave_panels(out_dir: Path, source_id: str, source_label: str) -> dict[str, dict]:
    grouped: OrderedDict[str, dict] = OrderedDict()
    for chunk_path in sorted(out_dir.glob("index.panel.*.chunk*.json")):
        chunk_meta = parse_legacy_panel_chunk(chunk_path)
        if not chunk_meta:
            continue
        section = chunk_meta["panelSection"]
        if section not in grouped:
            grouped[section] = {
                "panelId": section,
                "title": chunk_meta["title"] or LEGACY_WAVE_PANEL_TITLES.get(section, section.title()),
                "subtitle": chunk_meta["detail"] or "Recovered legacy WaveDrom panel view",
                "renderIndex": 0,
                "chunkCount": 0,
                "defaultVisibleSlots": max(1, chunk_meta["slotCount"] or 16),
                "sourceId": source_id,
                "sourceLabel": source_label,
                "legacyMode": True,
                "decodeEnabled": False,
                "legend": [],
                "chunks": [],
            }
        panel = grouped[section]
        if chunk_meta["title"]:
            panel["title"] = chunk_meta["title"]
        if chunk_meta["detail"] and panel["subtitle"] == "Recovered legacy WaveDrom panel view":
            panel["subtitle"] = chunk_meta["detail"]
        panel["defaultVisibleSlots"] = max(panel["defaultVisibleSlots"], max(1, chunk_meta["slotCount"] or 16))
        panel["chunks"].append(
            {
                "src": chunk_meta["src"],
                "cycleStart": chunk_meta["cycleStart"],
                "cycleEnd": chunk_meta["cycleEnd"],
                "slotCount": chunk_meta["slotCount"],
                "_chunkIndex": chunk_meta["chunkIndex"],
            }
        )

    ordered_sections = [section for section in LEGACY_WAVE_PANEL_ORDER if section in grouped]
    ordered_sections.extend(section for section in grouped if section not in ordered_sections)
    result: dict[str, dict] = {}
    for render_index, section in enumerate(ordered_sections):
        panel = grouped[section]
        panel["chunks"].sort(key=lambda item: item["_chunkIndex"])
        for chunk in panel["chunks"]:
            chunk.pop("_chunkIndex", None)
        panel["chunkCount"] = len(panel["chunks"])
        panel["renderIndex"] = render_index
        result[section] = panel
    return result


def numeric_field(
    field_id: str,
    label: str,
    msb: int,
    lsb: int,
    value: int,
    tone_key: str,
    description: str,
    *,
    default_visible: bool = True,
    card_value: str | None = None,
    bits: str | None = None,
    link_word_id: str = "",
    link_field_id: str = "",
) -> dict:
    width = msb - lsb + 1
    return {
        "id": field_id,
        "label": label,
        "msb": msb,
        "lsb": lsb,
        "width": width,
        "bits": bits or f"[{msb}:{lsb}]" if msb != lsb else f"[{msb}]",
        "value": value,
        "valueHex": format_hex(value, width),
        "valueDec": str(value),
        "valueBin": grouped_bits(value, width),
        "cardValue": card_value or format_hex(value, width),
        "description": description,
        "tone": TONES[tone_key],
        "defaultVisible": default_visible,
        "linkWordId": link_word_id,
        "linkFieldId": link_field_id,
    }


def meta_field(
    field_id: str,
    label: str,
    value: str,
    tone_key: str,
    description: str,
    *,
    default_visible: bool = True,
    link_word_id: str = "",
    link_field_id: str = "",
) -> dict:
    return {
        "id": field_id,
        "label": label,
        "msb": 0,
        "lsb": 0,
        "width": 1,
        "bits": "meta",
        "value": 0,
        "valueHex": value,
        "valueDec": value,
        "valueBin": value,
        "cardValue": value,
        "description": description,
        "tone": TONES[tone_key],
        "defaultVisible": default_visible,
        "linkWordId": link_word_id,
        "linkFieldId": link_field_id,
    }


def packet_no(counter: list[int]) -> int:
    counter[0] += 1
    return counter[0]


def parse_kv_summary(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for match in re.finditer(r"([A-Za-z0-9_]+)=([^\s|]+)", text):
        values[match.group(1)] = match.group(2)
    return values


def parse_stream_rows(path: Path) -> OrderedDict[str, list[dict]]:
    rows = parse_table_rows(path, "frame")
    grouped: OrderedDict[str, list[dict]] = OrderedDict()
    for frame, cycle, time_text, kind, datak, data, decode in rows:
        grouped.setdefault(frame, []).append(
            {
                "frame": frame,
                "cycle": int(cycle),
                "timePs": parse_time_ps(time_text),
                "timeLabel": time_text,
                "kind": kind,
                "datak": int(datak, 16),
                "datakHex": datak,
                "data": int(data, 16),
                "rawHex": data,
                "rawBin": grouped_bits(int(data, 16), 32),
                "decode": decode,
            }
        )
    return grouped


def parse_dma_rows(path: Path) -> list[dict]:
    rows = parse_table_rows(path, "word")
    parsed: list[dict] = []
    for word_label, cycle, time_text, eoe, raw256, decoded_slots in rows:
        slots = []
        for match in SLOT_RE.finditer(decoded_slots):
            slot_body = match.group("body").strip()
            frame_match = re.search(r"\bF(\d+)\b", slot_body)
            raw_match = re.search(r"raw64=(0x[0-9A-Fa-f]+)", slot_body)
            attrs = parse_kv_summary(slot_body)
            slots.append(
                {
                    "slot": int(match.group("slot")),
                    "frameId": int(frame_match.group(1)) if frame_match else None,
                    "raw64": raw_match.group(1) if raw_match else "",
                    "col": attrs.get("col", ""),
                    "row": attrs.get("row", ""),
                    "pri": attrs.get("pri", ""),
                    "ts": attrs.get("ts", ""),
                    "text": slot_body,
                }
            )
        frame_ids = [slot["frameId"] for slot in slots if slot["frameId"] is not None]
        parsed.append(
            {
                "wordLabel": word_label,
                "cycle": int(cycle),
                "timePs": parse_time_ps(time_text),
                "timeLabel": time_text,
                "eoe": eoe == "1",
                "raw256": raw256,
                "decodedSlots": slots,
                "frameId": frame_ids[0] if frame_ids else None,
                "decode": decoded_slots,
            }
        )
    return parsed


def frontend_from_sop(data: int) -> tuple[str, str]:
    packet_type = (data >> 26) & 0x3F
    if packet_type in {0x3A, 0x39, 0x38, 0x37}:
        return ("mupix", "MuPix")
    return ("frontend", "Frontend")


def parse_frame_header(rows: list[dict]) -> dict:
    by_kind = {row["kind"]: row for row in rows}
    sop = by_kind.get("sop")
    ts_high_row = by_kind.get("ts_high")
    ts_low_pkg_row = by_kind.get("ts_low_pkg")
    debug0_row = by_kind.get("debug0")
    debug1_row = by_kind.get("debug1")
    sop_data = sop["data"] if sop else 0
    frontend_id, frontend_label = frontend_from_sop(sop_data)
    kv_low = parse_kv_summary(ts_low_pkg_row["decode"] if ts_low_pkg_row else "")
    kv_debug0 = parse_kv_summary(debug0_row["decode"] if debug0_row else "")
    ts_high = ts_high_row["data"] if ts_high_row else 0
    ts_low = int(kv_low.get("ts_low", "0"), 16) if kv_low.get("ts_low") else ((ts_low_pkg_row["data"] >> 16) & 0xFFFF if ts_low_pkg_row else 0)
    pkg = int(kv_low.get("pkg", "0"), 16) if kv_low.get("pkg") else (ts_low_pkg_row["data"] & 0xFFFF if ts_low_pkg_row else 0)
    subheaders = int(kv_debug0.get("subheaders", "0")) if kv_debug0.get("subheaders") else ((debug0_row["data"] >> 16) & 0xFFFF if debug0_row else 0)
    hits = int(kv_debug0.get("hits", "0")) if kv_debug0.get("hits") else ((debug0_row["data"]) & 0xFFFF if debug0_row else 0)
    return {
        "frontendId": frontend_id,
        "frontendLabel": frontend_label,
        "fpgaId": (sop_data >> 8) & 0xFFFF,
        "timestamp48": (ts_high << 16) | ts_low,
        "pkgCounter": pkg,
        "subheaderCount": subheaders,
        "hitCount": hits,
        "debug1": debug1_row["data"] if debug1_row else 0,
    }


def parse_hit_fields(data: int) -> dict[str, int]:
    return {
        "ts_3_0": (data >> 28) & 0xF,
        "chip_id": (data >> 22) & 0x3F,
        "col": (data >> 14) & 0xFF,
        "row": (data >> 5) & 0x1FF,
        "tot": (data >> 1) & 0xF,
        "spec_lsb": data & 0x1,
    }


def hit_summary(data: int) -> str:
    fields = parse_hit_fields(data)
    return (
        f"ts(3:0)={format_hex(fields['ts_3_0'], 4)} "
        f"chip_id={fields['chip_id']} "
        f"col={fields['col']} "
        f"row={fields['row']} "
        f"tot={fields['tot']}"
    )


def build_sop_word(word_id: str, row: dict) -> dict:
    data = row["data"]
    return build_word(
        word_id,
        "Preamble",
        row,
        [
            numeric_field("type", "Type", 31, 26, (data >> 26) & 0x3F, "frontend", "6-bit packet type from the Mu3e preamble word."),
            numeric_field("slow_subtype", "Subtype", 25, 24, (data >> 24) & 0x3, "index", "Slow-control subtype field.", default_visible=False),
            numeric_field("fpga_id", "FPGA ID", 23, 8, (data >> 8) & 0xFFFF, "fpga", "Frontend / FPGA identifier encoded in the preamble."),
            numeric_field("k285", "K28.5", 7, 0, data & 0xFF, "control", "Control character K28.5 marking packet start."),
        ],
        row["decode"],
    )


def build_ts_high_word(word_id: str, row: dict) -> dict:
    return build_word(
        word_id,
        "TS High",
        row,
        [
            numeric_field("ts_high", "TS High", 31, 0, row["data"], "timestamp", "Upper 32 bits of the 48-bit frame timestamp."),
        ],
        row["decode"],
    )


def build_ts_low_pkg_word(word_id: str, row: dict) -> dict:
    kv = parse_kv_summary(row["decode"])
    ts_low = int(kv.get("ts_low", "0"), 16) if kv.get("ts_low") else (row["data"] >> 16) & 0xFFFF
    pkg = int(kv.get("pkg", "0"), 16) if kv.get("pkg") else row["data"] & 0xFFFF
    return build_word(
        word_id,
        "TS Low / Pkg",
        row,
        [
            numeric_field("ts_low", "TS Low", 31, 16, ts_low, "timestamp", "Low 16 bits of the frame timestamp."),
            numeric_field("pkg_counter", "Pkg", 15, 0, pkg, "count", "Package counter from the packet header."),
        ],
        row["decode"],
    )


def build_debug0_word(word_id: str, row: dict) -> dict:
    data = row["data"]
    return build_word(
        word_id,
        "Debug0",
        row,
        [
            numeric_field("subheader_count", "SubHdrs", 31, 16, (data >> 16) & 0xFFFF, "index", "Observed subheader count in this frame."),
            numeric_field("hit_count", "Hits", 15, 0, data & 0xFFFF, "count", "Observed hit count in this frame."),
        ],
        row["decode"],
    )


def build_debug1_word(word_id: str, row: dict) -> dict:
    return build_word(
        word_id,
        "Debug1",
        row,
        [
            numeric_field("debug1", "Debug1", 31, 0, row["data"], "timestamp", "Later dispatch timestamp sampled from the live global counter."),
        ],
        row["decode"],
    )


def build_subheader_word(word_id: str, label: str, row: dict) -> tuple[dict, int, int]:
    data = row["data"]
    shd_ts = (data >> 24) & 0xFF
    hit_count = (data >> 8) & 0xFFFF
    return (
        build_word(
            word_id,
            label,
            row,
            [
                numeric_field("shd_ts", "shd_ts", 31, 24, shd_ts, "timestamp", "Subheader timestamp byte carried with this hit group."),
                numeric_field("declared_hits", "Hit Cnt", 23, 8, hit_count, "count", "Declared hit count grouped under this subheader."),
                numeric_field("k237", "K23.7", 7, 0, data & 0xFF, "control", "Control character K23.7 marking a subheader."),
            ],
            row["decode"],
        ),
        shd_ts,
        hit_count,
    )


def build_hit_word(word_id: str, label: str, row: dict) -> tuple[dict, dict[str, int]]:
    parsed = parse_hit_fields(row["data"])
    return (
        build_word(
            word_id,
            label,
            row,
            [
                numeric_field("ts_3_0", "ts(3:0)", 31, 28, parsed["ts_3_0"], "timestamp", "Low timestamp nibble in the MuPix hit word."),
                numeric_field("chip_id", "Chip ID", 27, 22, parsed["chip_id"], "chip", "MuPix chip identifier."),
                numeric_field("col", "Col", 21, 14, parsed["col"], "col", "MuPix column number."),
                numeric_field("row", "Row", 13, 5, parsed["row"], "row", "MuPix row number."),
                numeric_field("tot", "ToT", 4, 1, parsed["tot"], "tot", "MuPix time-over-threshold field."),
                numeric_field("spec_lsb", "Reserved", 0, 0, parsed["spec_lsb"], "reserved", "Reserved low bit in the MuPix hit word.", default_visible=False),
            ],
            hit_summary(row["data"]),
        ),
        parsed,
    )


def build_eop_word(word_id: str, row: dict) -> dict:
    data = row["data"]
    return build_word(
        word_id,
        "Trailer",
        row,
        [
            numeric_field("reserved", "Reserved", 31, 8, (data >> 8) & 0xFFFFFF, "reserved", "Unused trailer bits.", default_visible=False),
            numeric_field("k284", "K28.4", 7, 0, data & 0xFF, "control", "Control character K28.4 marking packet end."),
        ],
        row["decode"],
    )


def build_word(word_id: str, label: str, row: dict, fields: list[dict], decode_summary: str) -> dict:
    return {
        "wordId": word_id,
        "wordLabel": label,
        "kind": row["kind"],
        "cycle": row["cycle"],
        "timePs": row["timePs"],
        "timeLabel": row["timeLabel"],
        "datak": row["datak"],
        "datakHex": row["datakHex"],
        "data": row["data"],
        "rawHex": row["rawHex"],
        "rawBin": row["rawBin"],
        "decodeSummaryByMode": {"mu3e-spec": decode_summary},
        "fieldsByMode": {"mu3e-spec": fields},
    }


def build_frame_fields(header: dict) -> list[dict]:
    return [
        meta_field("frontend", "Frontend", header["frontendLabel"], "frontend", "Front-end type decoded from the preamble word.", link_word_id="sop", link_field_id="type"),
        meta_field("fpga_id", "FPGA", format_hex(header["fpgaId"], 16), "fpga", "Frontend / FPGA identifier from the preamble.", link_word_id="sop", link_field_id="fpga_id"),
        meta_field("timestamp", "TS 48b", "0x" + format(header["timestamp48"], "012X"), "timestamp", "48-bit frame timestamp built from ts_high and ts_low words.", link_word_id="ts_high", link_field_id="ts_high"),
        meta_field("pkg_counter", "Pkg", str(header["pkgCounter"]), "count", "Package counter from the second header word.", link_word_id="ts_low_pkg", link_field_id="pkg_counter"),
        meta_field("subpkt_count", "SubPkts", str(header["subheaderCount"]), "index", "Observed subpacket count in this frame.", link_word_id="debug0", link_field_id="subheader_count"),
        meta_field("hit_count", "Hits", str(header["hitCount"]), "preview", "Observed hit count across all subpackets in this frame.", link_word_id="debug0", link_field_id="hit_count"),
    ]


def build_subpacket_fields(subpkt_index: int, shd_ts: int, hit_count: int, preview: str, frontend_label: str) -> list[dict]:
    return [
        meta_field("subpkt_index", "SubPkt", f"S{subpkt_index:03d}", "index", "Subpacket index within the frame.", link_word_id="subheader", link_field_id="shd_ts"),
        meta_field("shd_ts", "shd_ts", format_hex(shd_ts, 8), "timestamp", "Subheader timestamp byte.", link_word_id="subheader", link_field_id="shd_ts"),
        meta_field("declared_hits", "Hit Cnt", str(hit_count), "count", "Number of hit words grouped under this subpacket.", link_word_id="subheader", link_field_id="declared_hits"),
        meta_field("frontend", "Frontend", frontend_label, "frontend", "Front-end type inherited from the parent frame header.", link_word_id="subheader", link_field_id="k237"),
        meta_field("preview", "Preview", preview, "preview", "Preview decode of the first hit payload in this subpacket.", default_visible=False),
    ]


def build_hit_fields(parsed: dict[str, int]) -> list[dict]:
    return [
        meta_field("ts_3_0", "ts(3:0)", format_hex(parsed["ts_3_0"], 4), "timestamp", "Low timestamp nibble in the MuPix hit word.", link_word_id="hit", link_field_id="ts_3_0"),
        meta_field("chip_id", "Chip ID", str(parsed["chip_id"]), "chip", "MuPix chip identifier.", link_word_id="hit", link_field_id="chip_id"),
        meta_field("col", "Col", str(parsed["col"]), "col", "MuPix column number.", link_word_id="hit", link_field_id="col"),
        meta_field("row", "Row", str(parsed["row"]), "row", "MuPix row number.", link_word_id="hit", link_field_id="row"),
        meta_field("tot", "ToT", str(parsed["tot"]), "tot", "MuPix time-over-threshold field.", link_word_id="hit", link_field_id="tot"),
    ]


def clone_words(words: list[dict]) -> list[dict]:
    return [copy.deepcopy(word) for word in words]


def build_stream_packets(
    rows_by_frame: OrderedDict[str, list[dict]],
    prefix: str,
    lane: int,
    section: str,
    packet_counter: list[int],
) -> list[dict]:
    packets: list[dict] = []
    for frame_key, rows in rows_by_frame.items():
        frame_id = int(frame_key.lstrip("F"))
        header_rows: list[dict] = []
        current_subheader: dict | None = None
        subpackets: list[dict] = []
        trailer_row: dict | None = None
        frame_words: list[dict] = []

        for row in rows:
            kind = row["kind"]
            if kind == "subheader":
                if current_subheader is not None:
                    subpackets.append(current_subheader)
                current_subheader = {"header": row, "hits": []}
            elif kind == "hit":
                if current_subheader is None:
                    current_subheader = {"header": None, "hits": []}
                current_subheader["hits"].append(row)
            elif kind == "eop":
                trailer_row = row
            else:
                header_rows.append(row)

        if current_subheader is not None:
            subpackets.append(current_subheader)

        header = parse_frame_header(header_rows)
        frame_row_id = f"{prefix}-F{frame_id}"
        child_row_ids: list[str] = []
        subpacket_table: list[dict] = []
        descendants: list[dict] = []

        for header_row in header_rows:
            if header_row["kind"] == "sop":
                frame_words.append(build_sop_word("sop", header_row))
            elif header_row["kind"] == "ts_high":
                frame_words.append(build_ts_high_word("ts_high", header_row))
            elif header_row["kind"] == "ts_low_pkg":
                frame_words.append(build_ts_low_pkg_word("ts_low_pkg", header_row))
            elif header_row["kind"] == "debug0":
                frame_words.append(build_debug0_word("debug0", header_row))
            elif header_row["kind"] == "debug1":
                frame_words.append(build_debug1_word("debug1", header_row))

        for subpkt_index, subpkt in enumerate(subpackets):
            header_row = subpkt["header"]
            header_word_id = f"subheader_{subpkt_index:03d}"
            if header_row is None:
                continue
            header_word, shd_ts, hit_count = build_subheader_word(header_word_id, f"Subheader {subpkt_index:03d}", header_row)
            frame_words.append(header_word)
            preview = "empty"
            hit_words: list[dict] = [build_subheader_word("subheader", "Subheader", header_row)[0]]
            hit_rows: list[dict] = []

            for hit_index, hit_row in enumerate(subpkt["hits"]):
                frame_hit_word, parsed = build_hit_word(
                    f"hit_{subpkt_index:03d}_{hit_index:03d}",
                    f"Hit {subpkt_index:03d}.{hit_index:03d}",
                    hit_row,
                )
                frame_words.append(frame_hit_word)
                subpkt_hit_word, parsed_again = build_hit_word(f"hit{hit_index:03d}", f"Hit {hit_index}", hit_row)
                hit_words.append(subpkt_hit_word)
                if hit_index == 0:
                    preview = hit_summary(hit_row["data"])
                hit_row_id = f"{prefix}-F{frame_id}-S{subpkt_index:03d}-H{hit_index:03d}"
                hit_rows.append(
                    {
                        "rowId": hit_row_id,
                        "packetNo": packet_no(packet_counter),
                        "packetLabel": f"H{hit_index:03d}",
                        "lane": lane,
                        "frameId": frame_id,
                        "rowType": "hit",
                        "parentRowId": f"{prefix}-F{frame_id}-S{subpkt_index:03d}",
                        "depth": 2,
                        "expandable": False,
                        "childRowIds": [],
                        "kind": "hit",
                        "kindLabel": f"Hit {hit_index:03d}",
                        "kindFamily": "subpacket",
                        "frontendId": header["frontendId"],
                        "frontendLabel": header["frontendLabel"],
                        "section": section,
                        "cycle": hit_row["cycle"],
                        "startCycle": hit_row["cycle"],
                        "endCycle": hit_row["cycle"],
                        "timePs": hit_row["timePs"],
                        "timeLabel": hit_row["timeLabel"],
                        "decodeSummaryByMode": {"mu3e-spec": hit_summary(hit_row["data"])},
                        "fieldsByMode": {"mu3e-spec": build_hit_fields(parsed_again)},
                        "detailWordsByMode": {"mu3e-spec": [subpkt_hit_word]},
                        "subpacketTable": [],
                    }
                )

            subpacket_row_id = f"{prefix}-F{frame_id}-S{subpkt_index:03d}"
            child_row_ids.append(subpacket_row_id)
            subpacket_table.append(
                {
                    "rowId": subpacket_row_id,
                    "subpktIndex": subpkt_index,
                    "shdTs": shd_ts,
                    "hitCount": hit_count,
                    "startCycle": header_row["cycle"],
                    "endCycle": subpkt["hits"][-1]["cycle"] if subpkt["hits"] else header_row["cycle"],
                }
            )
            descendants.append(
                {
                    "rowId": subpacket_row_id,
                    "packetNo": packet_no(packet_counter),
                    "packetLabel": f"S{subpkt_index:03d}",
                    "lane": lane,
                    "frameId": frame_id,
                    "rowType": "subpkt",
                    "parentRowId": frame_row_id,
                    "depth": 1,
                    "expandable": bool(hit_rows),
                    "childRowIds": [row["rowId"] for row in hit_rows],
                    "kind": "subpkt",
                    "kindLabel": f"SubPkt {subpkt_index:03d}",
                    "kindFamily": "subpacket",
                    "frontendId": header["frontendId"],
                    "frontendLabel": header["frontendLabel"],
                    "section": section,
                    "cycle": header_row["cycle"],
                    "startCycle": header_row["cycle"],
                    "endCycle": hit_rows[-1]["endCycle"] if hit_rows else header_row["cycle"],
                    "timePs": header_row["timePs"],
                    "timeLabel": header_row["timeLabel"],
                    "decodeSummaryByMode": {
                        "mu3e-spec": f"SubPkt {subpkt_index:03d} | hit_count={hit_count} | {preview}"
                    },
                    "fieldsByMode": {"mu3e-spec": build_subpacket_fields(subpkt_index, shd_ts, hit_count, preview, header["frontendLabel"])},
                    "detailWordsByMode": {"mu3e-spec": hit_words},
                    "subpacketTable": [],
                }
            )
            descendants.extend(hit_rows)

        if trailer_row is not None:
            frame_words.append(build_eop_word("eop", trailer_row))

        frame_start = rows[0]["cycle"] if rows else 0
        frame_end = rows[-1]["cycle"] if rows else frame_start
        frame_time = rows[0]["timePs"] if rows else 0
        frame_time_label = rows[0]["timeLabel"] if rows else "0.000 ns"
        packets.append(
            {
                "rowId": frame_row_id,
                "packetNo": packet_no(packet_counter),
                "packetLabel": f"{prefix} F{frame_id}",
                "lane": lane,
                "frameId": frame_id,
                "rowType": "frame",
                "parentRowId": "",
                "depth": 0,
                "expandable": bool(child_row_ids),
                "childRowIds": child_row_ids,
                "kind": "frame",
                "kindLabel": "Frame",
                "kindFamily": "frame",
                "frontendId": header["frontendId"],
                "frontendLabel": header["frontendLabel"],
                "section": section,
                "cycle": frame_start,
                "startCycle": frame_start,
                "endCycle": frame_end,
                "timePs": frame_time,
                "timeLabel": frame_time_label,
                "decodeSummaryByMode": {
                    "mu3e-spec": f"{header['frontendLabel']} frame | {header['subheaderCount']} subpkts | {header['hitCount']} hits | ts=0x{header['timestamp48']:012X}"
                },
                "fieldsByMode": {"mu3e-spec": build_frame_fields(header)},
                "detailWordsByMode": {"mu3e-spec": clone_words(frame_words)},
                "subpacketTable": subpacket_table,
            }
        )
        packets.extend(descendants)
    return packets


def build_dma_packets(rows: list[dict], packet_counter: list[int]) -> list[dict]:
    grouped: OrderedDict[int, list[dict]] = OrderedDict()
    for row in rows:
        frame_id = row["frameId"] if row["frameId"] is not None else -1
        grouped.setdefault(frame_id, []).append(row)

    packets: list[dict] = []
    for frame_id, frame_rows in grouped.items():
        frame_row_id = f"DMA-F{frame_id}"
        child_ids: list[str] = []
        descendants: list[dict] = []
        for row in frame_rows:
            preview = " | ".join(slot["text"] for slot in row["decodedSlots"][:2]) or row["decode"]
            word_row_id = f"DMA-F{frame_id}-{row['wordLabel']}"
            child_ids.append(word_row_id)
            descendants.append(
                {
                    "rowId": word_row_id,
                    "packetNo": packet_no(packet_counter),
                    "packetLabel": row["wordLabel"],
                    "lane": -1,
                    "frameId": frame_id,
                    "rowType": "subpkt",
                    "parentRowId": frame_row_id,
                    "depth": 1,
                    "expandable": False,
                    "childRowIds": [],
                    "kind": "dma_word",
                    "kindLabel": f"DMA Word {row['wordLabel']}",
                    "kindFamily": "subpacket",
                    "frontendId": "mupix",
                    "frontendLabel": "MuPix",
                    "section": "dma",
                    "cycle": row["cycle"],
                    "startCycle": row["cycle"],
                    "endCycle": row["cycle"],
                    "timePs": row["timePs"],
                    "timeLabel": row["timeLabel"],
                    "decodeSummaryByMode": {"mu3e-spec": row["decode"]},
                    "fieldsByMode": {
                        "mu3e-spec": [
                            meta_field("word", "Word", row["wordLabel"], "index", "DMA payload word index."),
                            meta_field("slots", "Slots", str(len(row["decodedSlots"])), "slots", "Number of decoded packed hit slots in this 256-bit word."),
                            meta_field("eoe", "EOE", "1" if row["eoe"] else "0", "count", "End-of-event marker carried by the DMA stream."),
                            meta_field("preview", "Preview", preview, "preview", "Preview of the packed slot decodes.", default_visible=False),
                        ]
                    },
                    "detailWordsByMode": {"mu3e-spec": []},
                    "subpacketTable": [],
                }
            )

        packets.append(
            {
                "rowId": frame_row_id,
                "packetNo": packet_no(packet_counter),
                "packetLabel": f"DMA F{frame_id}",
                "lane": -1,
                "frameId": frame_id,
                "rowType": "frame",
                "parentRowId": "",
                "depth": 0,
                "expandable": bool(child_ids),
                "childRowIds": child_ids,
                "kind": "dma_frame",
                "kindLabel": "DMA Frame",
                "kindFamily": "frame",
                "frontendId": "mupix",
                "frontendLabel": "MuPix",
                "section": "dma",
                "cycle": frame_rows[0]["cycle"],
                "startCycle": frame_rows[0]["cycle"],
                "endCycle": frame_rows[-1]["cycle"],
                "timePs": frame_rows[0]["timePs"],
                "timeLabel": frame_rows[0]["timeLabel"],
                "decodeSummaryByMode": {
                    "mu3e-spec": f"DMA frame F{frame_id} | {len(frame_rows)} payload words | {sum(len(row['decodedSlots']) for row in frame_rows)} packed slots"
                },
                "fieldsByMode": {
                    "mu3e-spec": [
                        meta_field("frame_id", "Frame", f"F{frame_id}", "index", "Frame identifier inferred from the decoded DMA slots."),
                        meta_field("word_count", "Words", str(len(frame_rows)), "count", "Number of 256-bit DMA words in this frame."),
                        meta_field("slot_count", "Slots", str(sum(len(row["decodedSlots"]) for row in frame_rows)), "slots", "Total decoded packed hit slots in this frame."),
                    ]
                },
                "detailWordsByMode": {"mu3e-spec": []},
                "subpacketTable": [],
            }
        )
        packets.extend(descendants)
    return packets


def grouped_lane_packets(lane_packets: dict[int, list[dict]]) -> list[dict]:
    groups: list[tuple[int, int, list[dict]]] = []
    for lane, packets in lane_packets.items():
        index = 0
        while index < len(packets):
            packet = packets[index]
            if packet["parentRowId"]:
                index += 1
                continue
            group = [packet]
            index += 1
            while index < len(packets) and packets[index]["parentRowId"]:
                group.append(packets[index])
                index += 1
            groups.append((packet["startCycle"], lane, group))
    groups.sort(key=lambda item: (item[0], item[1]))
    combined: list[dict] = []
    for _, _, group in groups:
        combined.extend(copy.deepcopy(group))
    return combined


def count_families(all_packets: Iterable[dict]) -> dict[str, int]:
    counts = {family["id"]: 0 for family in FAMILIES}
    for packet in all_packets:
        family = packet.get("kindFamily")
        if family in counts:
            counts[family] += 1
    return counts


def count_kinds(all_packets: Iterable[dict]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for packet in all_packets:
        kind = packet.get("kind")
        counts[kind] = counts.get(kind, 0) + 1
    return counts


def parse_out_dir_case_key(out_dir: Path) -> tuple[str, str]:
    case_dir = out_dir.parent
    return (case_dir.parent.name, case_dir.name)


def find_wave_reports_root(path: Path) -> Path | None:
    resolved = path.resolve()
    for candidate in [resolved, *resolved.parents]:
        if candidate.name == "wave_reports" and (candidate / "README.md").exists():
            return candidate
    return None


def parse_wave_report_intents(readme_path: Path) -> dict[tuple[str, str], str]:
    intents: dict[tuple[str, str], str] = {}
    if not readme_path.exists():
        return intents
    in_table = False
    for raw_line in readme_path.read_text().splitlines():
        line = raw_line.strip()
        if line.startswith("| bucket | case | intent |"):
            in_table = True
            continue
        if not in_table:
            continue
        if not line.startswith("|"):
            if intents:
                break
            continue
        cols = [col.strip() for col in line.strip("|").split("|")]
        if len(cols) < 4:
            continue
        bucket = cols[0].strip("` ")
        case_id = cols[1].strip("` ")
        intent = cols[2].strip("` ")
        if bucket.lower() == "bucket" or set(bucket) == {"-"}:
            continue
        intents[(bucket, case_id)] = intent
    return intents


def parse_payload_words(case_line: str) -> int | None:
    match = PAYLOAD_WORDS_RE.search(case_line or "")
    return int(match.group(1)) if match else None


def build_case_description(intent: str, bundle_meta: dict) -> str:
    parts: list[str] = []
    if intent:
        parts.append(intent.replace("`", ""))
    profile_name = str(bundle_meta.get("profile_name") or "").strip()
    if profile_name:
        parts.append(f"profile={profile_name}")
    payload_words = parse_payload_words(((bundle_meta.get("summary_lines") or {}).get("case") or ""))
    if payload_words is not None:
        parts.append(f"payload_words={payload_words}")
    mask = str(bundle_meta.get("feb_enable_mask") or "").strip()
    if mask and mask.lower() not in {"0xf", "0x0f"}:
        parts.append(f"mask={mask}")
    dma_half_full_pct = bundle_meta.get("dma_half_full_pct")
    if isinstance(dma_half_full_pct, int) and dma_half_full_pct > 0:
        parts.append(f"dma_half_full={dma_half_full_pct}%")
    seed = bundle_meta.get("seed")
    if isinstance(seed, int):
        parts.append(f"seed={seed}")
    return " | ".join(parts)


def build_catalog_entries(wave_reports_root: Path) -> list[dict]:
    intent_map = parse_wave_report_intents(wave_reports_root / "README.md")
    entries: list[dict] = []
    for bundle_path in sorted(wave_reports_root.glob("*/*/bundle.json")):
        bundle_meta = json.loads(bundle_path.read_text())
        case_dir = bundle_path.parent
        packet_analyzer_dir = case_dir / (((bundle_meta.get("artifacts") or {}).get("packet_analyzer")) or "packet_analyzer")
        if not packet_analyzer_dir.is_dir():
            continue
        bucket = str(bundle_meta.get("bucket") or case_dir.parent.name)
        case_id = str(bundle_meta.get("case_id") or case_dir.name)
        entries.append(
            {
                "bucket": bucket,
                "caseId": case_id,
                "label": f"{bucket} / {case_id}",
                "profileName": str(bundle_meta.get("profile_name") or ""),
                "description": build_case_description(intent_map.get((bucket, case_id), ""), bundle_meta),
                "url": f"/cases/{bucket}/{case_id}/",
                "targetDir": str(packet_analyzer_dir.resolve()),
            }
        )
    return entries


def write_case_catalog_and_aliases(out_dir: Path, entries: list[dict]) -> None:
    payload = []
    for entry in entries:
        data = {key: value for key, value in entry.items() if key != "targetDir"}
        data["current"] = Path(entry["targetDir"]).resolve() == out_dir.resolve()
        payload.append(data)
    (out_dir / "case-catalog.js").write_text(
        "window.__PACKET_ANALYZER_CASE_CATALOG__ = "
        + json.dumps(payload, separators=(",", ":"))
        + ";\n"
    )

    cases_root = out_dir / "cases"
    cases_root.mkdir(exist_ok=True)
    for entry in entries:
        alias_path = cases_root / entry["bucket"] / entry["caseId"]
        alias_path.parent.mkdir(parents=True, exist_ok=True)
        if alias_path.is_symlink():
            alias_path.unlink()
        elif alias_path.exists():
            continue
        os.symlink(entry["targetDir"], alias_path, target_is_directory=True)


def render_index_html(title: str) -> str:
    template = (ASSET_DIR / "template.html").read_text()
    return template.replace("{{TITLE}}", title)


def copy_static_assets(out_dir: Path) -> None:
    shutil.copy2(ASSET_DIR / "app.js", out_dir / "app.js")
    shutil.copy2(ASSET_DIR / "styles.css", out_dir / "styles.css")
    shutil.copy2(WAVEDROM_ASSET_DIR / "default.js", out_dir / "default.js")
    shutil.copy2(WAVEDROM_ASSET_DIR / "wavedrom.min.js", out_dir / "wavedrom.min.js")


def build_lane_info(lane: int, packets: list[dict], script_name: str) -> dict:
    top_frames = [packet for packet in packets if packet["rowType"] == "frame"]
    hit_count = sum(1 for packet in packets if packet["kind"] == "hit")
    return {
        "lane": lane,
        "label": "All Lanes" if lane == -1 else f"Lane {lane}",
        "frameIds": sorted({packet["frameId"] for packet in top_frames}),
        "packetCount": len(packets),
        "hitCount": hit_count,
        "laneScript": script_name,
        "wavePanels": {},
    }


def write_js_assignment(path: Path, variable: str, payload: dict) -> None:
    path.write_text(f"{variable} = {json.dumps(payload, separators=(',', ':'))};\n")


def rebuild_case(case_dir: Path) -> Path:
    out_dir = case_dir / "packet_analyzer"
    bundle_meta = json.loads((case_dir / "bundle.json").read_text())
    ingress_by_lane: dict[int, list[dict]] = {}
    packet_counter = [0]

    for lane in range(4):
        ledger_path = out_dir / f"index.ledger.ingress.lane{lane}.html"
        rows_by_frame = parse_stream_rows(ledger_path)
        ingress_by_lane[lane] = build_stream_packets(rows_by_frame, f"L{lane}", lane, "ingress", packet_counter)

    all_lane_packets = grouped_lane_packets(ingress_by_lane)

    egress_packets = build_stream_packets(parse_stream_rows(out_dir / "index.ledger.egress.html"), "OPQ", -1, "egress", packet_counter)
    dma_packets = build_dma_packets(parse_dma_rows(out_dir / "index.ledger.dma.html"), packet_counter)
    global_packets = egress_packets + dma_packets

    bundle_packets = all_lane_packets + global_packets
    frame_ids = sorted({packet["frameId"] for packet in bundle_packets if packet["rowType"] == "frame" and packet["frameId"] is not None})
    case_key = parse_out_dir_case_key(out_dir)
    source_vcd = (case_dir / ((bundle_meta.get("artifacts") or {}).get("vcd") or "")).resolve()
    source_id = f"{case_key[0]}/{case_key[1]}"
    legacy_wave_panels = collect_legacy_wave_panels(out_dir, source_id, source_id)

    lanes_payload = {
        -1: {
            "lane": -1,
            "label": "All Lanes",
            "frameIds": sorted({packet["frameId"] for packet in all_lane_packets if packet["rowType"] == "frame"}),
            "packetCount": len(all_lane_packets),
            "hitCount": sum(1 for packet in all_lane_packets if packet["kind"] == "hit"),
            "packets": all_lane_packets,
            "wavePanels": {},
        }
    }
    for lane, packets in ingress_by_lane.items():
        lanes_payload[lane] = {
            "lane": lane,
            "label": f"Lane {lane}",
            "frameIds": sorted({packet["frameId"] for packet in packets if packet["rowType"] == "frame"}),
            "packetCount": len(packets),
            "hitCount": sum(1 for packet in packets if packet["kind"] == "hit"),
            "packets": packets,
            "wavePanels": {},
        }

    lane_infos = [
        build_lane_info(-1, lanes_payload[-1]["packets"], "packet-lane-all.js"),
        *(build_lane_info(lane, lanes_payload[lane]["packets"], f"packet-lane{lane}.js") for lane in range(4)),
    ]

    manifest = {
        "meta": {
            "htmlTitle": "Mu3e IP Core Toolkit: Packet Transaction Traffic Analyzer",
            "title": "Mu3e IP Core Toolkit",
            "subtitle": "Packet Transaction Traffic Analyzer",
            "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"),
            "sourceVcd": str(source_vcd),
            "frameStart": min(frame_ids) if frame_ids else 0,
            "frameCount": len(frame_ids),
            "selectedFrames": frame_ids,
            "defaultLane": -1,
            "defaultDecodeMode": "mu3e-spec",
            "referenceVideoTitle": "Teledyne LeCroy Voyager USB 3.0 Analyzer packet display workflow",
            "specReference": "Mu3eSpecBook-4.pdf pages 147-148 (32-bit frontend packet and hit layouts)",
            "familyCounts": count_families(bundle_packets),
            "kindCounts": count_kinds(bundle_packets),
            "notes": [
                "Recovered packet-analyzer bundle rebuilt from checked-in ingress, egress, and DMA ledgers.",
                "Frames are top-level rows, subheaders are integral subpacket rows, and hit rows preserve per-word decode.",
                "Legacy WaveDrom panel chunks are restored as a left-side waveform viewer surface beside the packet trace.",
            ],
            "globalPackets": global_packets,
            "globalWavePanels": legacy_wave_panels,
            "bucket": case_key[0],
            "caseId": case_key[1],
        },
        "decodeModes": DECODE_MODES,
        "families": FAMILIES,
        "lanes": lane_infos,
    }

    write_js_assignment(out_dir / "packet-manifest.js", "window.__PACKET_ANALYZER_MANIFEST__", manifest)
    write_js_assignment(out_dir / "packet-lane-all.js", "window.__PACKET_ANALYZER_LANES__", {"-1": lanes_payload[-1]})
    for lane in range(4):
        write_js_assignment(out_dir / f"packet-lane{lane}.js", "window.__PACKET_ANALYZER_LANES__", {str(lane): lanes_payload[lane]})

    copy_static_assets(out_dir)
    (out_dir / "index.html").write_text(render_index_html(manifest["meta"]["htmlTitle"]))
    return out_dir


def main() -> int:
    args = parse_args()
    wave_reports_root = args.wave_reports_root.resolve()
    case_dirs = [
        bundle_path.parent
        for bundle_path in sorted(wave_reports_root.glob("*/*/bundle.json"))
        if (bundle_path.parent / "packet_analyzer").is_dir()
        and ((json.loads(bundle_path.read_text()).get("artifacts") or {}).get("vcd"))
    ]
    if not case_dirs:
        raise SystemExit("No canonical case bundles with ledger-backed packet_analyzer directories were found.")

    rebuilt_dirs = [rebuild_case(case_dir) for case_dir in case_dirs]
    entries = build_catalog_entries(wave_reports_root)
    for out_dir in rebuilt_dirs:
        write_case_catalog_and_aliases(out_dir, entries)

    landing_bucket, landing_case = args.landing_case.split("/", 1)
    landing_dir = wave_reports_root / landing_bucket / landing_case / "packet_analyzer"
    if landing_dir not in rebuilt_dirs:
        raise SystemExit(f"Landing bundle {args.landing_case} was not rebuilt.")

    print(f"rebuilt {len(rebuilt_dirs)} bundles")
    print(f"landing_bundle={landing_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Parse Mu3e/MuSiP ingress VCD streams into FEB_DATA_FRAME JSON.

The exported model is intentionally UI-friendly:
- a frame is the top-level packet
- each subheader plus its hits is a subpacket
- the same structure can feed packet-trace rows, WaveDrom annotations, and
  later Electron packaging without changing the decode contract
"""

from __future__ import annotations

import argparse
import importlib.util
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


SWB_K285 = 0xBC
SWB_K284 = 0x9C
SWB_K237 = 0xF7
SPEC_REFERENCE = "Mu3eSpecBook-4.pdf pages 147-148"

PACKET_TYPE_INFO: dict[int, dict[str, str]] = {
    0b111010: {
        "id": "mupix",
        "label": "MuPix",
        "hitFormat": "mupix",
        "description": "MuPix front-end data packet.",
    },
    0b111000: {
        "id": "scifi",
        "label": "SciFi",
        "hitFormat": "scifi-tile",
        "description": "SciFi front-end data packet.",
    },
    0b110100: {
        "id": "tile",
        "label": "Tile",
        "hitFormat": "scifi-tile",
        "description": "Tile front-end data packet.",
    },
    0b111011: {
        "id": "mupix-debug",
        "label": "MuPix Debug",
        "hitFormat": "mupix",
        "description": "MuPix debug packet.",
    },
    0b111001: {
        "id": "scifi-debug",
        "label": "SciFi Debug",
        "hitFormat": "scifi-tile",
        "description": "SciFi debug packet.",
    },
    0b110101: {
        "id": "tile-debug",
        "label": "Tile Debug",
        "hitFormat": "scifi-tile",
        "description": "Tile debug packet.",
    },
    0b000111: {
        "id": "slow-control",
        "label": "SlowControl",
        "hitFormat": "raw",
        "description": "Slow-control packet.",
    },
    0b000010: {
        "id": "berts",
        "label": "BERTs",
        "hitFormat": "raw",
        "description": "BERT packet.",
    },
    0b000000: {
        "id": "idle",
        "label": "Idle",
        "hitFormat": "raw",
        "description": "Idle packet.",
    },
}


@dataclass
class Beat:
    cycle: int
    time_ps: int
    data: int
    datak: int
    kind: str
    frame_id: int
    lane: int
    packet_type_code: int
    packet_type_id: str
    packet_type_label: str
    packet_hit_format: str
    fpga_id: int
    packet_timestamp: int
    package_counter: int
    debug_subheader_count: int
    debug_hit_count: int
    send_ts_counter: int
    shd_ts: int | None = None
    hit_count: int | None = None
    hit_idx: int | None = None
    subpkt_index: int | None = None


@dataclass
class Subpacket:
    lane: int
    frame_id: int
    subpkt_index: int
    subheader: Beat
    hits: list[Beat] = field(default_factory=list)

    @property
    def words(self) -> list[Beat]:
        return [self.subheader] + self.hits

    @property
    def start_cycle(self) -> int:
        return self.subheader.cycle

    @property
    def end_cycle(self) -> int:
        return self.hits[-1].cycle if self.hits else self.subheader.cycle

    @property
    def time_ps(self) -> int:
        return self.subheader.time_ps


@dataclass
class Frame:
    lane: int
    frame_id: int
    preamble: Beat
    ts_high: Beat
    ts_low_pkg: Beat
    debug0: Beat
    debug1: Beat
    subpackets: list[Subpacket]
    trailer: Beat

    @property
    def words(self) -> list[Beat]:
        beats = [self.preamble, self.ts_high, self.ts_low_pkg, self.debug0, self.debug1]
        for subpkt in self.subpackets:
            beats.extend(subpkt.words)
        beats.append(self.trailer)
        return beats

    @property
    def frontend_code(self) -> int:
        return self.preamble.packet_type_code

    @property
    def frontend_id(self) -> str:
        return self.preamble.packet_type_id

    @property
    def frontend_label(self) -> str:
        return self.preamble.packet_type_label

    @property
    def hit_format(self) -> str:
        return self.preamble.packet_hit_format

    @property
    def fpga_id(self) -> int:
        return self.preamble.fpga_id

    @property
    def packet_timestamp(self) -> int:
        return self.preamble.packet_timestamp

    @property
    def package_counter(self) -> int:
        return self.preamble.package_counter

    @property
    def declared_subheader_count(self) -> int:
        return self.preamble.debug_subheader_count

    @property
    def declared_hit_count(self) -> int:
        return self.preamble.debug_hit_count

    @property
    def send_ts_counter(self) -> int:
        return self.preamble.send_ts_counter

    @property
    def start_cycle(self) -> int:
        return self.preamble.cycle

    @property
    def end_cycle(self) -> int:
        return self.trailer.cycle

    @property
    def time_ps(self) -> int:
        return self.preamble.time_ps


def load_vcd_module() -> Any:
    candidates = [
        Path.home() / ".codex/skills/wavedrom-viewer/vcd2wavedrom.py",
        Path.home() / ".claude/skills/wavedrom-viewer/vcd2wavedrom.py",
    ]
    for candidate in candidates:
        if candidate.exists():
            spec = importlib.util.spec_from_file_location("wavedrom_vcd", candidate)
            if spec and spec.loader:
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                return module
    raise FileNotFoundError("Unable to locate wavedrom-viewer/vcd2wavedrom.py in ~/.codex or ~/.claude")


def bits_to_int(bits: str) -> int | None:
    lowered = bits.lower()
    if "x" in lowered or "z" in lowered:
        return None
    return int(lowered, 2)


def exact_signal_id(vcd: Any, full_path: str) -> str:
    for sid, sig in vcd.signals.items():
        if sig.full_path == full_path:
            return sid
    raise KeyError(f"Signal not found in VCD: {full_path}")


def extract_stream(vcd: Any, edges: list[int], prefix: str) -> list[dict[str, int]]:
    valid_id = exact_signal_id(vcd, f"tb_top.{prefix}.valid")
    data_id = exact_signal_id(vcd, f"tb_top.{prefix}.data")
    datak_id = exact_signal_id(vcd, f"tb_top.{prefix}.datak")

    rows: list[dict[str, int]] = []
    for cycle, time_vcd in enumerate(edges):
        valid = bits_to_int(vcd.get_value_at(valid_id, time_vcd))
        if valid != 1:
            continue
        data = bits_to_int(vcd.get_value_at(data_id, time_vcd))
        datak = bits_to_int(vcd.get_value_at(datak_id, time_vcd))
        if data is None or datak is None:
            raise ValueError(f"{prefix} produced X/Z during valid beat at cycle {cycle}")
        rows.append(
            {
                "cycle": cycle,
                "time_ps": int(round(time_vcd * vcd.timescale_ps)),
                "data": data,
                "datak": datak,
            }
        )
    return rows


def decode_packet_type(code: int) -> dict[str, str]:
    return PACKET_TYPE_INFO.get(
        code,
        {
            "id": f"unknown-0x{code:02x}",
            "label": f"Unknown 0x{code:02X}",
            "hitFormat": "raw",
            "description": "Unknown packet type.",
        },
    )


def is_preamble_word(data: int, datak: int) -> bool:
    return datak == 0x1 and (data & 0xFF) == SWB_K285


def is_subheader_word(data: int, datak: int) -> bool:
    return datak == 0x1 and (data & 0xFF) == SWB_K237


def is_trailer_word(data: int, datak: int) -> bool:
    return datak == 0x1 and (data & 0xFF) == SWB_K284


def make_beat(
    row: dict[str, int],
    *,
    lane: int,
    frame_id: int,
    kind: str,
    packet_type_code: int,
    packet_type_info: dict[str, str],
    fpga_id: int,
    packet_timestamp: int,
    package_counter: int,
    debug_subheader_count: int,
    debug_hit_count: int,
    send_ts_counter: int,
    shd_ts: int | None = None,
    hit_count: int | None = None,
    hit_idx: int | None = None,
    subpkt_index: int | None = None,
) -> Beat:
    return Beat(
        cycle=row["cycle"],
        time_ps=row["time_ps"],
        data=row["data"],
        datak=row["datak"],
        kind=kind,
        frame_id=frame_id,
        lane=lane,
        packet_type_code=packet_type_code,
        packet_type_id=packet_type_info["id"],
        packet_type_label=packet_type_info["label"],
        packet_hit_format=packet_type_info["hitFormat"],
        fpga_id=fpga_id,
        packet_timestamp=packet_timestamp,
        package_counter=package_counter,
        debug_subheader_count=debug_subheader_count,
        debug_hit_count=debug_hit_count,
        send_ts_counter=send_ts_counter,
        shd_ts=shd_ts,
        hit_count=hit_count,
        hit_idx=hit_idx,
        subpkt_index=subpkt_index,
    )


def parse_framed_stream(rows: list[dict[str, int]], lane: int) -> list[Frame]:
    frames: list[Frame] = []
    idx = 0

    while idx < len(rows):
        frame_id = len(frames)
        sop = rows[idx]
        data = sop["data"]
        datak = sop["datak"]
        if not is_preamble_word(data, datak):
            raise ValueError(
                f"Expected preamble at row {idx}, got data=0x{data:08X} datak=0x{datak:X}"
            )

        packet_type_code = (data >> 26) & 0x3F
        packet_type_info = decode_packet_type(packet_type_code)
        fpga_id = (data >> 8) & 0xFFFF

        if idx + 4 >= len(rows):
            raise ValueError(f"Frame {frame_id} in lane {lane} ended before fixed header words were complete")

        ts_high_row = rows[idx + 1]
        ts_low_pkg_row = rows[idx + 2]
        debug0_row = rows[idx + 3]
        debug1_row = rows[idx + 4]

        packet_timestamp = ((ts_high_row["data"] & 0xFFFF_FFFF) << 16) | ((ts_low_pkg_row["data"] >> 16) & 0xFFFF)
        package_counter = ts_low_pkg_row["data"] & 0xFFFF
        debug_subheader_count = (debug0_row["data"] >> 16) & 0x7FFF
        debug_hit_count = debug0_row["data"] & 0xFFFF
        send_ts_counter = debug1_row["data"] & 0x7FFF_FFFF

        preamble = make_beat(
            sop,
            lane=lane,
            frame_id=frame_id,
            kind="sop",
            packet_type_code=packet_type_code,
            packet_type_info=packet_type_info,
            fpga_id=fpga_id,
            packet_timestamp=packet_timestamp,
            package_counter=package_counter,
            debug_subheader_count=debug_subheader_count,
            debug_hit_count=debug_hit_count,
            send_ts_counter=send_ts_counter,
        )
        ts_high = make_beat(
            ts_high_row,
            lane=lane,
            frame_id=frame_id,
            kind="ts_high",
            packet_type_code=packet_type_code,
            packet_type_info=packet_type_info,
            fpga_id=fpga_id,
            packet_timestamp=packet_timestamp,
            package_counter=package_counter,
            debug_subheader_count=debug_subheader_count,
            debug_hit_count=debug_hit_count,
            send_ts_counter=send_ts_counter,
        )
        ts_low_pkg = make_beat(
            ts_low_pkg_row,
            lane=lane,
            frame_id=frame_id,
            kind="ts_low_pkg",
            packet_type_code=packet_type_code,
            packet_type_info=packet_type_info,
            fpga_id=fpga_id,
            packet_timestamp=packet_timestamp,
            package_counter=package_counter,
            debug_subheader_count=debug_subheader_count,
            debug_hit_count=debug_hit_count,
            send_ts_counter=send_ts_counter,
        )
        debug0 = make_beat(
            debug0_row,
            lane=lane,
            frame_id=frame_id,
            kind="debug0",
            packet_type_code=packet_type_code,
            packet_type_info=packet_type_info,
            fpga_id=fpga_id,
            packet_timestamp=packet_timestamp,
            package_counter=package_counter,
            debug_subheader_count=debug_subheader_count,
            debug_hit_count=debug_hit_count,
            send_ts_counter=send_ts_counter,
        )
        debug1 = make_beat(
            debug1_row,
            lane=lane,
            frame_id=frame_id,
            kind="debug1",
            packet_type_code=packet_type_code,
            packet_type_info=packet_type_info,
            fpga_id=fpga_id,
            packet_timestamp=packet_timestamp,
            package_counter=package_counter,
            debug_subheader_count=debug_subheader_count,
            debug_hit_count=debug_hit_count,
            send_ts_counter=send_ts_counter,
        )
        idx += 5

        subpackets: list[Subpacket] = []
        while idx < len(rows):
            beat = rows[idx]
            data = beat["data"]
            datak = beat["datak"]

            if is_trailer_word(data, datak):
                trailer = make_beat(
                    beat,
                    lane=lane,
                    frame_id=frame_id,
                    kind="eop",
                    packet_type_code=packet_type_code,
                    packet_type_info=packet_type_info,
                    fpga_id=fpga_id,
                    packet_timestamp=packet_timestamp,
                    package_counter=package_counter,
                    debug_subheader_count=debug_subheader_count,
                    debug_hit_count=debug_hit_count,
                    send_ts_counter=send_ts_counter,
                )
                idx += 1
                frames.append(
                    Frame(
                        lane=lane,
                        frame_id=frame_id,
                        preamble=preamble,
                        ts_high=ts_high,
                        ts_low_pkg=ts_low_pkg,
                        debug0=debug0,
                        debug1=debug1,
                        subpackets=subpackets,
                        trailer=trailer,
                    )
                )
                break

            if not is_subheader_word(data, datak):
                raise ValueError(
                    f"Expected subheader/EOP at row {idx}, got data=0x{data:08X} datak=0x{datak:X}"
                )

            subpkt_index = len(subpackets)
            shd_ts = (data >> 24) & 0xFF
            hit_count = (data >> 8) & 0xFF
            subheader = make_beat(
                beat,
                lane=lane,
                frame_id=frame_id,
                kind="subheader",
                packet_type_code=packet_type_code,
                packet_type_info=packet_type_info,
                fpga_id=fpga_id,
                packet_timestamp=packet_timestamp,
                package_counter=package_counter,
                debug_subheader_count=debug_subheader_count,
                debug_hit_count=debug_hit_count,
                send_ts_counter=send_ts_counter,
                shd_ts=shd_ts,
                hit_count=hit_count,
                subpkt_index=subpkt_index,
            )
            idx += 1

            hits: list[Beat] = []
            for hit_idx in range(hit_count):
                if idx >= len(rows):
                    raise ValueError(
                        f"Lane {lane} frame {frame_id} subpacket {subpkt_index} ended before all hits arrived"
                    )
                hit_row = rows[idx]
                if hit_row["datak"] != 0:
                    raise ValueError(
                        f"Expected hit payload at row {idx}, got data=0x{hit_row['data']:08X} datak=0x{hit_row['datak']:X}"
                    )
                hits.append(
                    make_beat(
                        hit_row,
                        lane=lane,
                        frame_id=frame_id,
                        kind="hit",
                        packet_type_code=packet_type_code,
                        packet_type_info=packet_type_info,
                        fpga_id=fpga_id,
                        packet_timestamp=packet_timestamp,
                        package_counter=package_counter,
                        debug_subheader_count=debug_subheader_count,
                        debug_hit_count=debug_hit_count,
                        send_ts_counter=send_ts_counter,
                        shd_ts=shd_ts,
                        hit_idx=hit_idx,
                        subpkt_index=subpkt_index,
                    )
                )
                idx += 1

            subpackets.append(
                Subpacket(
                    lane=lane,
                    frame_id=frame_id,
                    subpkt_index=subpkt_index,
                    subheader=subheader,
                    hits=hits,
                )
            )
        else:
            raise ValueError(f"Frame {frame_id} in lane {lane} terminated without trailer")

    return frames


def parse_lane_frames(
    vcd_path: Path,
    lanes: list[int],
    frame_start: int,
    frame_count: int,
) -> dict[int, list[Frame]]:
    vcd_module = load_vcd_module()
    vcd = vcd_module.VCDParser().parse(str(vcd_path))
    clock_id = vcd.match_clock("tb_top.clk")
    if clock_id is None:
        raise ValueError("Clock tb_top.clk not found in VCD")
    edges = vcd.find_rising_edges(clock_id, 0, vcd.max_time)

    lane_frames: dict[int, list[Frame]] = {}
    for lane in lanes:
        all_frames = parse_framed_stream(extract_stream(vcd, edges, f"feb_if{lane}"), lane)
        selected = all_frames[frame_start : frame_start + frame_count]
        if len(selected) < frame_count:
            raise ValueError(
                f"Lane {lane} only has {len(selected)} frames in requested slice "
                f"[{frame_start}:{frame_start + frame_count}]"
            )
        lane_frames[lane] = selected
    return lane_frames


def decode_subheader_fields(subheader: Beat) -> dict[str, Any]:
    return {
        "reference": SPEC_REFERENCE,
        "layout": "mu3e-subheader32",
        "ts11_4": (subheader.data >> 24) & 0xFF,
        "overflow": (subheader.data >> 8) & 0xFFFF,
        "k237": subheader.data & 0xFF,
    }


def decode_mupix_hit_fields(hit: Beat) -> dict[str, Any]:
    return {
        "reference": SPEC_REFERENCE,
        "layout": "mupix-hit32",
        "ts3_0": (hit.data >> 28) & 0xF,
        "chipId": (hit.data >> 22) & 0x3F,
        "col": (hit.data >> 14) & 0xFF,
        "row": (hit.data >> 5) & 0x1FF,
        "tot": (hit.data >> 1) & 0xF,
        "reserved": hit.data & 0x1,
    }


def decode_scifi_tile_hit_fields(hit: Beat) -> dict[str, Any]:
    return {
        "reference": SPEC_REFERENCE,
        "layout": "scifi-tile-hit32",
        "ts3_0": (hit.data >> 28) & 0xF,
        "chipId": (hit.data >> 22) & 0x3F,
        "channelId": (hit.data >> 16) & 0x3F,
        "ts50ps": (hit.data >> 8) & 0xFF,
        "energy": hit.data & 0xFF,
    }


def decode_hit_fields(hit: Beat) -> dict[str, Any]:
    if hit.packet_hit_format == "mupix":
        return decode_mupix_hit_fields(hit)
    if hit.packet_hit_format == "scifi-tile":
        return decode_scifi_tile_hit_fields(hit)
    return {
        "reference": SPEC_REFERENCE,
        "layout": "raw32",
        "raw": hit.data,
    }


def serialize_hit(hit: Beat) -> dict[str, Any]:
    return {
        "cycle": hit.cycle,
        "timePs": hit.time_ps,
        "rawHex": f"0x{hit.data:08X}",
        "rawBin": f"{hit.data:032b}",
        "hitIndex": hit.hit_idx,
        "packetType": hit.packet_type_label,
        "hitFormat": hit.packet_hit_format,
        "decodedSpec": decode_hit_fields(hit),
    }


def serialize_subpacket(subpkt: Subpacket) -> dict[str, Any]:
    return {
        "subpktIndex": subpkt.subpkt_index,
        "startCycle": subpkt.start_cycle,
        "endCycle": subpkt.end_cycle,
        "timePs": subpkt.time_ps,
        "subheader": {
            "cycle": subpkt.subheader.cycle,
            "timePs": subpkt.subheader.time_ps,
            "rawHex": f"0x{subpkt.subheader.data:08X}",
            "rawBin": f"{subpkt.subheader.data:032b}",
            "shdTs": subpkt.subheader.shd_ts,
            "hitCount": subpkt.subheader.hit_count,
            "decodedSpec": decode_subheader_fields(subpkt.subheader),
        },
        "hits": [serialize_hit(hit) for hit in subpkt.hits],
    }


def serialize_frame(frame: Frame) -> dict[str, Any]:
    return {
        "lane": frame.lane,
        "frameId": frame.frame_id,
        "frontendCode": frame.frontend_code,
        "frontendId": frame.frontend_id,
        "frontendLabel": frame.frontend_label,
        "hitFormat": frame.hit_format,
        "specReference": SPEC_REFERENCE,
        "fpgaId": frame.fpga_id,
        "packetTimestamp": frame.packet_timestamp,
        "packetTimestampHex": f"0x{frame.packet_timestamp:012X}",
        "packageCounter": frame.package_counter,
        "declaredSubheaders": frame.declared_subheader_count,
        "declaredHits": frame.declared_hit_count,
        "sendTsCounter": frame.send_ts_counter,
        "startCycle": frame.start_cycle,
        "endCycle": frame.end_cycle,
        "timePs": frame.time_ps,
        "subpackets": [serialize_subpacket(subpkt) for subpkt in frame.subpackets],
    }


def parse_lanes_arg(text: str) -> list[int]:
    lanes = sorted({int(part.strip()) for part in text.split(",") if part.strip()})
    if not lanes:
        raise ValueError("At least one lane must be selected")
    for lane in lanes:
        if lane < 0 or lane > 3:
            raise ValueError(f"Lane must be in range 0..3, got {lane}")
    return lanes


def build_export_payload(
    vcd_path: Path,
    lane_frames: dict[int, list[Frame]],
    frame_start: int,
    frame_count: int,
) -> dict[str, Any]:
    return {
        "format": "FEB_DATA_FRAME",
        "meta": {
            "sourceVcd": str(vcd_path),
            "specReference": SPEC_REFERENCE,
            "frameStart": frame_start,
            "frameCount": frame_count,
            "selectedFrames": list(range(frame_start, frame_start + frame_count)),
        },
        "lanes": [
            {
                "lane": lane,
                "frameCount": len(frames),
                "frames": [serialize_frame(frame) for frame in frames],
            }
            for lane, frames in sorted(lane_frames.items())
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Export selected ingress frames as FEB_DATA_FRAME JSON.")
    parser.add_argument("--vcd", required=True, help="Replay-mode VCD path")
    parser.add_argument("--out-json", required=True, help="Output FEB_DATA_FRAME JSON path")
    parser.add_argument("--frame-start", type=int, default=1, help="First frame index to export (default: 1)")
    parser.add_argument("--frame-count", type=int, default=2, help="Number of frames to export per lane (default: 2)")
    parser.add_argument("--lanes", default="0,1,2,3", help="Comma-separated ingress lanes (default: 0,1,2,3)")
    args = parser.parse_args()

    vcd_path = Path(args.vcd)
    out_json = Path(args.out_json)
    lanes = parse_lanes_arg(args.lanes)
    lane_frames = parse_lane_frames(vcd_path, lanes, args.frame_start, args.frame_count)
    payload = build_export_payload(vcd_path, lane_frames, args.frame_start, args.frame_count)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(payload, indent=2))
    print(f"Wrote FEB_DATA_FRAME JSON to {out_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Decode Mu3e FEB/SWB frame streams from SignalTap VCD exports.

The decoder expects SignalTap probes to export bitwise 32-bit data plus a
4-bit datak sideband, or a packed 36-bit stream with datak in bits 35:32.
It keeps Idle SOPs out of the frame scan so K28.5 idles do not look like data
frames.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


INDEX_RE = re.compile(r"^(?P<base>.+)\[(?P<index>\d+)\]$")
K285 = 0xBC
K284 = 0x9C
K237 = 0xF7


@dataclass(frozen=True)
class StreamSpec:
    name: str
    data_suffix: str
    datak_suffix: str | None = None
    valid_suffix: str | None = None
    ready_suffix: str | None = None
    idle_suffix: str | None = None
    sop_suffix: str | None = None
    eop_suffix: str | None = None
    packed36: bool = False
    lane: int | None = None
    infer_datak: bool = False
    expected_subheaders: int = 128
    wide_slots: int = 1


FEB_QSYS = "feb_system:u_feb_system|feb_system_v3:u_qsys|"
FEB_DP = f"{FEB_QSYS}feb_system_v3_data_path_subsystem:data_path_subsystem|"
FEB_FIREFLY = "feb_system:u_feb_system|firefly_xcvr_subsystem:u_firefly_xcvr|"
SWB = "swb_block:e_swb_block|"
SWB_A10 = "a10_block:e_a10_block|"
ADAPT = f"{SWB}ingress_egress_adaptor:e_ingress_egress_adaptor|"
PIPE = f"{SWB}swb_opq_dma_pipeline:e_opq_dma_pipeline|"


def feb_profile() -> list[StreamSpec]:
    return [
        StreamSpec(
            "feb_frame_upper_bank",
            f"{FEB_DP}hit_type3_upper_data",
            valid_suffix=f"{FEB_DP}hit_type3_upper_valid",
            sop_suffix=f"{FEB_DP}hit_type3_upper_startofpacket",
            eop_suffix=f"{FEB_DP}hit_type3_upper_endofpacket",
            packed36=True,
        ),
        StreamSpec(
            "feb_frame_lower_bank",
            f"{FEB_DP}hit_type3_lower_data",
            valid_suffix=f"{FEB_DP}hit_type3_lower_valid",
            sop_suffix=f"{FEB_DP}hit_type3_lower_startofpacket",
            eop_suffix=f"{FEB_DP}hit_type3_lower_endofpacket",
            packed36=True,
        ),
        StreamSpec(
            "qsys_upload_data1_lower_bank",
            f"{FEB_QSYS}upload_data1_data",
            valid_suffix=f"{FEB_QSYS}upload_data1_valid",
            sop_suffix=f"{FEB_QSYS}upload_data1_startofpacket",
            eop_suffix=f"{FEB_QSYS}upload_data1_endofpacket",
            packed36=True,
        ),
        StreamSpec(
            "qsys_upload_data0_upper_sc_rc_bank",
            f"{FEB_QSYS}upload_data0_sc_rc_data",
            valid_suffix=f"{FEB_QSYS}upload_data0_sc_rc_valid",
            sop_suffix=f"{FEB_QSYS}upload_data0_sc_rc_startofpacket",
            eop_suffix=f"{FEB_QSYS}upload_data0_sc_rc_endofpacket",
            packed36=True,
        ),
        StreamSpec(
            "firefly_upload_data1_lower_bank",
            f"{FEB_FIREFLY}i_upload_data1_data",
            valid_suffix=f"{FEB_FIREFLY}i_upload_data1_valid",
            packed36=True,
        ),
        StreamSpec(
            "firefly_upload_data0_upper_sc_rc_bank",
            f"{FEB_FIREFLY}i_upload_data0_sc_rc_data",
            valid_suffix=f"{FEB_FIREFLY}i_upload_data0_sc_rc_valid",
            packed36=True,
        ),
    ]


def swb_profile() -> list[StreamSpec]:
    streams: list[StreamSpec] = []
    for physical in range(16):
        streams.append(
            StreamSpec(
                f"xcvr_physical_lane{physical}",
                f"{SWB_A10}o_xcvr0_rx_data[{physical}]",
                datak_suffix=f"{SWB_A10}o_xcvr0_rx_datak[{physical}]",
            )
        )
    for logical in range(8):
        base = f"{SWB}i_feb_rx[{logical}]"
        streams.append(
            StreamSpec(
                f"swb_logical_feb_rx{logical}",
                f"{base}.data",
                datak_suffix=f"{base}.datak",
                idle_suffix=f"{base}.idle",
                sop_suffix=f"{base}.sop",
                eop_suffix=f"{base}.eop",
                lane=logical,
            )
        )
    for lane in range(4):
        base = f"{SWB}rx_data_sim_opq[{lane}]"
        streams.append(
            StreamSpec(
                f"masked_opq_input_lane{lane}",
                f"{base}.data",
                datak_suffix=f"{base}.datak",
                idle_suffix=f"{base}.idle",
                sop_suffix=f"{base}.sop",
                eop_suffix=f"{base}.eop",
                lane=lane,
            )
        )
    for lane in range(4):
        streams.append(
            StreamSpec(
                f"opq_ingress_lane{lane}",
                f"{ADAPT}ingress_data[{lane}]",
                valid_suffix=f"{ADAPT}ingress_valid[{lane}]",
                sop_suffix=f"{ADAPT}ingress_startofpacket[{lane}]",
                eop_suffix=f"{ADAPT}ingress_endofpacket[{lane}]",
                packed36=True,
                lane=lane,
            )
        )
    streams.extend(
        [
            StreamSpec(
                "opq_egress_raw",
                f"{ADAPT}opq_egress_data",
                datak_suffix=f"{ADAPT}opq_egress_datak",
                valid_suffix=f"{ADAPT}opq_egress_valid",
                sop_suffix=f"{ADAPT}opq_egress_sop",
                eop_suffix=f"{ADAPT}opq_egress_eop",
            ),
            StreamSpec(
                "opq_dma_input",
                f"{SWB}opq_dma_input_data",
                datak_suffix=f"{SWB}opq_dma_input_datak",
                valid_suffix=f"{SWB}opq_dma_input_valid",
                sop_suffix=f"{PIPE}i_opq_sop",
                eop_suffix=f"{PIPE}i_opq_eop",
            ),
            StreamSpec(
                "opq_dma_output_256b",
                f"{PIPE}o_dma_data",
                datak_suffix=f"{PIPE}o_dma_datak",
                valid_suffix=f"{PIPE}o_dma_wen",
                eop_suffix=f"{PIPE}o_end_of_event",
                wide_slots=8,
            ),
        ]
    )
    return streams


def feb_focused_profile() -> list[StreamSpec]:
    """Short-name profile for focused CSV-to-VCD SignalTap exports.

    Older focused captures only carried 32-bit data_observed plus
    valid/ready/SOP/EOP.  They did not carry datak, so the decoder can only
    infer control symbols from K28.5/K28.4/K23.7 low bytes.  New captures
    should still tap datak explicitly and use the normal feb/swb profile.
    """
    return [
        StreamSpec(
            "inner_upper",
            "inner_upper_data_observed",
            valid_suffix="inner_upper_valid",
            ready_suffix="inner_upper_ready",
            sop_suffix="inner_upper_sop",
            eop_suffix="inner_upper_eop",
            infer_datak=True,
        ),
        StreamSpec(
            "inner_lower",
            "inner_lower_data_observed",
            valid_suffix="inner_lower_valid",
            ready_suffix="inner_lower_ready",
            sop_suffix="inner_lower_sop",
            eop_suffix="inner_lower_eop",
            infer_datak=True,
        ),
        StreamSpec(
            "top_upper",
            "top_upper_data_observed",
            valid_suffix="top_upper_valid",
            ready_suffix="top_upper_ready",
            sop_suffix="top_upper_sop",
            eop_suffix="top_upper_eop",
            infer_datak=True,
        ),
        StreamSpec(
            "top_lower",
            "top_lower_data_observed",
            valid_suffix="top_lower_valid",
            ready_suffix="top_lower_ready",
            sop_suffix="top_lower_sop",
            eop_suffix="top_lower_eop",
            infer_datak=True,
        ),
    ]


def parse_vcd(path: Path) -> tuple[list[dict[str, Any]], dict[str, str], dict[str, int]]:
    scopes: list[str] = []
    names_by_id: dict[str, str] = {}
    widths_by_id: dict[str, int] = {}
    current: dict[str, str] = {}
    samples: list[dict[str, Any]] = []
    now: int | None = None

    def snapshot() -> None:
        if now is not None:
            samples.append({"time_ps": now, "values": dict(current)})

    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("$scope"):
                parts = line.split()
                if len(parts) >= 3:
                    scopes.append(parts[2])
                continue
            if line.startswith("$upscope"):
                if scopes:
                    scopes.pop()
                continue
            if line.startswith("$var"):
                parts = line.split()
                if len(parts) >= 6:
                    width = int(parts[2])
                    ident = parts[3]
                    ref = " ".join(parts[4:-1])
                    names_by_id[ident] = ".".join([*scopes, ref]) if scopes else ref
                    widths_by_id[ident] = width
                    current.setdefault(ident, "x")
                continue
            if line.startswith("#"):
                snapshot()
                now = int(line[1:])
                continue
            if line.startswith("$"):
                continue
            if line[0] in "01xXzZ":
                current[line[1:].strip()] = line[0].lower()
                continue
            if line[0] in "bB":
                fields = line.split()
                if len(fields) == 2:
                    current[fields[1]] = fields[0][1:].lower()
    snapshot()
    return samples, names_by_id, widths_by_id


def find_signal(names_by_id: dict[str, str], suffix: str) -> str:
    matches = [ident for ident, name in names_by_id.items() if name.endswith(suffix)]
    if len(matches) != 1:
        raise RuntimeError(f"expected one signal ending {suffix!r}, found {len(matches)}")
    return matches[0]


def find_optional_signal(names_by_id: dict[str, str], suffix: str | None) -> str | None:
    if not suffix:
        return None
    return find_signal(names_by_id, suffix)


def find_bus(names_by_id: dict[str, str], widths_by_id: dict[str, int], suffix: str, width: int) -> dict[Any, str]:
    vector_matches = [
        ident
        for ident, name in names_by_id.items()
        if name.endswith(suffix) and widths_by_id.get(ident) == width
    ]
    if len(vector_matches) == 1:
        return {"__vector__": vector_matches[0]}
    if len(vector_matches) > 1:
        raise RuntimeError(f"expected one vector ending {suffix!r}, found {len(vector_matches)}")

    bus: dict[Any, str] = {}
    for ident, name in names_by_id.items():
        match = INDEX_RE.match(name)
        if match and match.group("base").endswith(suffix):
            bus[int(match.group("index"))] = ident
    missing = [idx for idx in range(width) if idx not in bus]
    if missing:
        raise RuntimeError(f"bus {suffix!r} missing indexes: {missing[:8]}")
    return bus


def bus_value(values: dict[str, str], bus: dict[Any, str], width: int) -> int | None:
    if "__vector__" in bus:
        raw = values.get(bus["__vector__"], "x")
        if len(raw) == 1:
            if raw not in {"0", "1"}:
                return None
            return 1 if raw == "1" else 0
        if any(bit not in {"0", "1"} for bit in raw):
            return None
        if len(raw) > width:
            raw = raw[-width:]
        return int(raw, 2)

    value = 0
    for idx in range(width):
        bit = values.get(bus[idx], "x")
        if bit not in {"0", "1"}:
            return None
        if bit == "1":
            value |= 1 << idx
    return value


def scalar_value(values: dict[str, str], ident: str | None) -> int | None:
    if ident is None:
        return None
    bit = values.get(ident, "x")
    if bit not in {"0", "1"}:
        return None
    return 1 if bit == "1" else 0


def is_idle_word(data: int, datak: int) -> bool:
    return bool(datak & 0x1) and (data & 0xFF) == K285 and ((data >> 26) & 0x3F) == 0


def infer_datak_from_data(data: int, sop: int | None, eop: int | None) -> int:
    low = data & 0xFF
    if low == K237:
        return 0x1
    if low == K285 and (sop is None or sop == 1):
        return 0x1
    if low == K284 and (eop is None or eop == 1):
        return 0x1
    return 0x0


class Mu3eFrameContract:
    def __init__(self, stream_name: str, lane: int | None, expected_subheaders: int) -> None:
        self.stream_name = stream_name
        self.lane = 0 if lane is None else lane
        self.expected_subheaders = expected_subheaders
        self.errors: list[dict[str, Any]] = []
        self.frames: list[dict[str, Any]] = []
        self.in_frame = False
        self.header_ts_valid = False
        self.current_subheader_valid = False
        self.first_subheader_seen = False
        self.word_index = 0
        self.declared_subheaders = 0
        self.seen_subheaders = 0
        self.declared_hits = 0
        self.seen_hits = 0
        self.frame_accepted_words = 0
        self.subheader_declared_hit_sum = 0
        self.current_subheader_declared_hits = 0
        self.current_subheader_seen_hits = 0
        self.header_page_base = 0
        self.header_ts_high_word = 0
        self.header_ts_low_word = 0
        self.current_subheader_ts = 0
        self.last_subheader_ts = 0
        self.last_subheader_valid = False
        self.last_packet_ts = 0
        self.last_packet_ts_valid = False
        self.frame_start_time_ps: int | None = None

    def reset_frame_state(self) -> None:
        self.in_frame = False
        self.header_ts_valid = False
        self.current_subheader_valid = False
        self.first_subheader_seen = False
        self.word_index = 0
        self.declared_subheaders = 0
        self.seen_subheaders = 0
        self.declared_hits = 0
        self.seen_hits = 0
        self.frame_accepted_words = 0
        self.subheader_declared_hit_sum = 0
        self.current_subheader_declared_hits = 0
        self.current_subheader_seen_hits = 0
        self.header_page_base = 0
        self.header_ts_high_word = 0
        self.header_ts_low_word = 0
        self.current_subheader_ts = 0
        self.last_subheader_ts = 0
        self.last_subheader_valid = False
        self.last_packet_ts = 0
        self.last_packet_ts_valid = False
        self.frame_start_time_ps = None

    def flag_error(self, word: dict[str, Any], reason: str) -> None:
        self.errors.append(
            {
                "time_ps": word.get("time_ps"),
                "word_index": self.word_index,
                "data": f"0x{int(word['data']):08X}",
                "datak": f"0x{int(word['datak']):X}",
                "reason": reason,
                "declared_subheaders": self.declared_subheaders,
                "seen_subheaders": self.seen_subheaders,
                "declared_hits": self.declared_hits,
                "seen_hits": self.seen_hits,
                "frame_accepted_words": self.frame_accepted_words,
                "subheader_declared_hit_sum": self.subheader_declared_hit_sum,
            }
        )

    def check_open_subheader(self, word: dict[str, Any]) -> None:
        if not self.current_subheader_valid:
            return
        if self.current_subheader_seen_hits != self.current_subheader_declared_hits:
            self.flag_error(
                word,
                (
                    f"subheader_ts=0x{self.current_subheader_ts:02X} "
                    f"declared_hits={self.current_subheader_declared_hits} "
                    f"seen_hits={self.current_subheader_seen_hits}"
                ),
            )

    def subheader_sequence_reason(self, subheader_ts: int, expected_ts: int) -> str:
        if self.last_subheader_valid and subheader_ts == self.last_subheader_ts:
            return "duplicate"
        if self.last_subheader_valid and ((subheader_ts - self.last_subheader_ts) & 0xFF) != 1:
            if ((subheader_ts - self.last_subheader_ts) & 0x80) != 0:
                return "backward"
            return "gap"
        return "nonconsecutive"

    def close_frame(self, word: dict[str, Any]) -> None:
        self.check_open_subheader(word)
        expected_frame_words = 5 + self.declared_subheaders + self.declared_hits + 1
        if self.frame_accepted_words != expected_frame_words:
            self.flag_error(
                word,
                (
                    "broken packet length "
                    f"accepted_words={self.frame_accepted_words} "
                    f"expected_words={expected_frame_words} "
                    f"header_words=5 declared_subheaders={self.declared_subheaders} "
                    f"declared_hits={self.declared_hits} trailer_words=1"
                ),
            )
        if self.declared_subheaders != self.expected_subheaders:
            self.flag_error(
                word,
                f"declared_subheaders={self.declared_subheaders} expected={self.expected_subheaders}",
            )
        if self.seen_subheaders != self.declared_subheaders:
            self.flag_error(
                word,
                f"seen_subheaders={self.seen_subheaders} declared_subheaders={self.declared_subheaders}",
            )
        if self.seen_hits != self.declared_hits:
            self.flag_error(word, f"seen_hits={self.seen_hits} declared_hits={self.declared_hits}")
        if self.subheader_declared_hit_sum != self.declared_hits:
            self.flag_error(
                word,
                (
                    f"subheader_declared_hit_sum={self.subheader_declared_hit_sum} "
                    f"declared_hits={self.declared_hits}"
                ),
            )
        self.frames.append(
            {
                "start_time_ps": self.frame_start_time_ps,
                "end_time_ps": word.get("time_ps"),
                "word_count": self.frame_accepted_words,
                "expected_word_count": expected_frame_words,
                "declared_subheaders": self.declared_subheaders,
                "seen_subheaders": self.seen_subheaders,
                "declared_hits": self.declared_hits,
                "seen_hits": self.seen_hits,
                "subheader_declared_hit_sum": self.subheader_declared_hit_sum,
                "header_page_base": self.header_page_base,
            }
        )

    def sample(self, word: dict[str, Any]) -> str:
        data = int(word["data"])
        datak = int(word["datak"])
        side_sop = word.get("sop")
        side_eop = word.get("eop")
        sample_sop = bool(datak & 0x1) and (data & 0xFF) == K285
        sample_eop = bool(datak & 0x1) and (data & 0xFF) == K284
        sample_subheader = bool(datak & 0x1) and (data & 0xFF) == K237

        if is_idle_word(data, datak):
            self.reset_frame_state()
            return "idle"

        if side_sop is not None and side_sop == 1 and not sample_sop:
            self.flag_error(word, f"SOP asserted without K28.5 data=0x{data:08X} datak=0x{datak:X}")
        if side_eop is not None and side_eop == 1 and not sample_eop:
            self.flag_error(word, f"EOP asserted without K28.4 data=0x{data:08X} datak=0x{datak:X}")

        if sample_sop:
            self.reset_frame_state()
            self.in_frame = True
            self.frame_accepted_words = 1
            self.frame_start_time_ps = int(word["time_ps"])
            return "sop"

        if not self.in_frame:
            if not sample_eop:
                self.flag_error(word, f"data outside frame data=0x{data:08X} datak=0x{datak:X}")
            return "unknown"

        self.word_index += 1
        self.frame_accepted_words += 1

        if self.word_index == 1:
            self.header_ts_high_word = data
            return "header_ts_hi"
        if self.word_index == 2:
            self.header_ts_low_word = data
            self.header_ts_valid = True
            return "header_ts_lo"
        if self.word_index == 3:
            self.declared_subheaders = (data >> 16) & 0x7FFF
            self.declared_hits = data & 0xFFFF
            if data & 0x80000000:
                self.flag_error(word, f"debug count word bit31 set data=0x{data:08X}")
            return "debug_counts"
        if self.word_index == 4:
            return "debug_time"

        if sample_subheader:
            self.check_open_subheader(word)
            subheader_ts = (data >> 24) & 0xFF
            self.current_subheader_ts = subheader_ts
            self.current_subheader_declared_hits = (data >> 8) & 0xFF
            self.current_subheader_seen_hits = 0
            self.current_subheader_valid = True
            self.subheader_declared_hit_sum += self.current_subheader_declared_hits
            if not self.first_subheader_seen:
                self.header_page_base = 128 if (subheader_ts & 0x80) else 0
                self.first_subheader_seen = True
                if subheader_ts != self.header_page_base:
                    self.flag_error(
                        word,
                        f"first subheader=0x{subheader_ts:02X} expected page base=0x{self.header_page_base:02X}",
                    )
            expected_ts = (self.header_page_base + self.seen_subheaders) & 0xFF
            if subheader_ts != expected_ts:
                reason = self.subheader_sequence_reason(subheader_ts, expected_ts)
                prev = f"0x{self.last_subheader_ts:02X}" if self.last_subheader_valid else "none"
                self.flag_error(
                    word,
                    (
                        f"subheader {reason} sequence got=0x{subheader_ts:02X} "
                        f"expected=0x{expected_ts:02X} prev={prev}"
                    ),
                )
            self.last_subheader_ts = subheader_ts
            self.last_subheader_valid = True
            self.seen_subheaders += 1
            return "subheader"

        if sample_eop:
            self.close_frame(word)
            self.reset_frame_state()
            return "trailer"

        if self.header_ts_valid and self.current_subheader_valid and datak == 0:
            hit_ts_nibble = (data >> 28) & 0xF
            packet_ts = (
                (self.header_ts_high_word << 16)
                | (((self.header_ts_low_word >> 28) & 0xF) << 12)
                | (self.current_subheader_ts << 4)
                | hit_ts_nibble
            ) & 0xFFFFFFFFFFFF
            if self.current_subheader_seen_hits >= self.current_subheader_declared_hits:
                self.flag_error(
                    word,
                    (
                        f"subheader_ts=0x{self.current_subheader_ts:02X} hit overrun "
                        f"declared_hits={self.current_subheader_declared_hits} "
                        f"next_hit_index={self.current_subheader_seen_hits + 1}"
                    ),
                )
            if self.seen_hits >= self.declared_hits:
                self.flag_error(
                    word,
                    f"frame hit overrun declared_hits={self.declared_hits} next_hit_index={self.seen_hits + 1}",
                )
            self.current_subheader_seen_hits += 1
            self.seen_hits += 1
            if self.last_packet_ts_valid and packet_ts < self.last_packet_ts:
                self.flag_error(
                    word,
                    f"packet timestamp decreased prev=0x{self.last_packet_ts:012X} now=0x{packet_ts:012X}",
                )
            self.last_packet_ts = packet_ts
            self.last_packet_ts_valid = True
            return "hit"

        self.flag_error(word, f"unknown in-frame word data=0x{data:08X} datak=0x{datak:X}")
        return "unknown"


def check_contract(words: list[dict[str, Any]], spec: StreamSpec) -> dict[str, Any]:
    checker = Mu3eFrameContract(spec.name, spec.lane, spec.expected_subheaders)
    kinds: dict[str, int] = {}
    inferred_datak_words = 0
    for word in words:
        if word.get("datak_source") == "inferred":
            inferred_datak_words += 1
        kind = checker.sample(word)
        kinds[kind] = kinds.get(kind, 0) + 1
        word["contract_kind"] = kind
    error_reason_counts: dict[str, int] = {}
    for error in checker.errors:
        reason = str(error.get("reason", "unknown"))
        if reason.startswith("broken packet length"):
            bucket = "broken_packet_length"
        elif reason.startswith("subheader ") and " sequence " in reason:
            bucket = "subheader_sequence"
        elif reason.startswith("subheader_ts=") and "declared_hits" in reason:
            bucket = "subframe_declared_hit_count"
        elif reason.startswith("subheader_declared_hit_sum="):
            bucket = "subheader_declared_hit_sum"
        elif reason.startswith("seen_hits="):
            bucket = "frame_declared_hit_count"
        elif reason.startswith("seen_subheaders=") or reason.startswith("declared_subheaders="):
            bucket = "subheader_count"
        elif "overrun" in reason:
            bucket = "hit_overrun"
        else:
            bucket = "other"
        error_reason_counts[bucket] = error_reason_counts.get(bucket, 0) + 1
    return {
        "status": "pass" if not checker.errors else "fail",
        "error_count": len(checker.errors),
        "errors": checker.errors[:32],
        "last_errors": checker.errors[-16:] if len(checker.errors) > 32 else [],
        "error_reason_counts": error_reason_counts,
        "accepted_words": len(words),
        "frame_count": len(checker.frames),
        "frames": checker.frames[:16],
        "hit_count": sum(frame["seen_hits"] for frame in checker.frames),
        "declared_hit_count": sum(frame["declared_hits"] for frame in checker.frames),
        "kind_counts": kinds,
        "inferred_datak_words": inferred_datak_words,
        "inferred_datak_note": (
            "datak was inferred from K-symbol low bytes; capture datak explicitly for final signoff"
            if inferred_datak_words
            else None
        ),
    }


def decode_stream(
    samples: list[dict[str, Any]],
    names_by_id: dict[str, str],
    widths_by_id: dict[str, int],
    spec: StreamSpec,
) -> dict[str, Any]:
    width = 36 if spec.packed36 else 32 * spec.wide_slots
    data_bus = find_bus(names_by_id, widths_by_id, spec.data_suffix, width)
    datak_bus = None
    if not spec.packed36 and not spec.infer_datak:
        datak_bus = find_bus(names_by_id, widths_by_id, spec.datak_suffix or "", 4 * spec.wide_slots)
    valid_id = find_optional_signal(names_by_id, spec.valid_suffix)
    ready_id = find_optional_signal(names_by_id, spec.ready_suffix)
    idle_id = find_optional_signal(names_by_id, spec.idle_suffix)
    sop_id = find_optional_signal(names_by_id, spec.sop_suffix)
    eop_id = find_optional_signal(names_by_id, spec.eop_suffix)

    words: list[dict[str, Any]] = []
    last_no_valid_key: tuple[int, int, int | None, int | None] | None = None
    for sample in samples:
        values = sample["values"]
        valid = scalar_value(values, valid_id)
        if valid_id is not None and valid != 1:
            continue
        ready = scalar_value(values, ready_id)
        if ready_id is not None and ready != 1:
            continue
        idle = scalar_value(values, idle_id)
        if idle_id is not None and idle == 1:
            continue

        raw = bus_value(values, data_bus, width)
        if raw is None:
            continue
        if spec.wide_slots > 1:
            datak_raw = bus_value(values, datak_bus or {}, 4 * spec.wide_slots)
            if datak_raw is None:
                continue
            eop_side = scalar_value(values, eop_id)
            for slot in range(spec.wide_slots):
                data = (raw >> (slot * 32)) & 0xFFFFFFFF
                datak = (datak_raw >> (slot * 4)) & 0xF
                is_eop_symbol = bool(datak & 0x1) and (data & 0xFF) == K284
                words.append(
                    {
                        "time_ps": sample["time_ps"],
                        "data": data,
                        "datak": datak,
                        "low_byte": data & 0xFF,
                        "sop": 1 if slot == 0 and bool(datak & 0x1) and (data & 0xFF) == K285 else None,
                        "eop": 1 if eop_side == 1 and (is_eop_symbol or slot == spec.wide_slots - 1) else None,
                        "ready": ready,
                        "datak_source": "wide_datak",
                        "wide_slot": slot,
                    }
                )
                if is_eop_symbol:
                    break
            continue
        if spec.packed36:
            data = raw & 0xFFFFFFFF
            datak = (raw >> 32) & 0xF
            datak_source = "packed36"
        elif spec.infer_datak:
            sop = scalar_value(values, sop_id)
            eop = scalar_value(values, eop_id)
            data = raw
            datak = infer_datak_from_data(data, sop, eop)
            datak_source = "inferred"
        else:
            datak_raw = bus_value(values, datak_bus or {}, 4)
            if datak_raw is None:
                continue
            data = raw
            datak = datak_raw
            datak_source = "datak"

        if valid_id is None and idle_id is None and is_idle_word(data, datak):
            continue
        sop = scalar_value(values, sop_id)
        eop = scalar_value(values, eop_id)
        if valid_id is None:
            key = (data, datak, sop, eop)
            if key == last_no_valid_key:
                continue
            last_no_valid_key = key

        words.append(
            {
                "time_ps": sample["time_ps"],
                "data": data,
                "datak": datak,
                "low_byte": data & 0xFF,
                "sop": sop,
                "eop": eop,
                "ready": ready,
                "datak_source": datak_source,
            }
        )

    frames = decode_frames(words)
    contract = check_contract(words, spec)
    k285 = sum(1 for word in words if (word["datak"] & 0x1) and word["low_byte"] == K285)
    idle_sop = sum(1 for word in words if is_idle_word(word["data"], word["datak"]))
    k284 = sum(1 for word in words if (word["datak"] & 0x1) and word["low_byte"] == K284)
    k237 = sum(1 for word in words if (word["datak"] & 0x1) and word["low_byte"] == K237)
    role_counts: dict[str, int] = {}
    for word in words:
        role = classify_word(word)
        role_counts[role] = role_counts.get(role, 0) + 1

    return {
        "name": spec.name,
        "lane": spec.lane,
        "word_count": len(words),
        "k285_word_count": k285,
        "idle_sop_count": idle_sop,
        "k284_word_count": k284,
        "k237_word_count": k237,
        "role_counts": role_counts,
        "decoded_frame_count": len(frames),
        "closed_frame_count": sum(1 for frame in frames if frame["closed_by_k284"]),
        "contract": contract,
        "frames": frames[:16],
        "first_words": compact_words(words[:32]),
        "_words": words,
    }


def classify_word(word: dict[str, Any]) -> str:
    data = int(word["data"])
    datak = int(word["datak"])
    low = data & 0xFF
    is_k = bool(datak & 0x1)
    if is_idle_word(data, datak):
        return "idle"
    if is_k and low == K285:
        return "header"
    if is_k and low == K284:
        return "trailer"
    if is_k and low == K237:
        return "subheader"
    if ((data >> 24) & 0xFF) == 0xFE:
        return "subheader_alias"
    return "hit_or_payload"


def decode_frames(words: list[dict[str, Any]]) -> list[dict[str, Any]]:
    frames: list[dict[str, Any]] = []
    active: list[dict[str, Any]] | None = None
    start_index = 0
    for index, word in enumerate(words):
        role = classify_word(word)
        if role == "idle":
            continue
        if role == "header":
            if active:
                frames.append(frame_summary(start_index, active, closed=False))
            active = [word]
            start_index = index
            continue
        if active is None:
            continue
        active.append(word)
        if role == "trailer":
            frames.append(frame_summary(start_index, active, closed=True))
            active = None
    if active:
        frames.append(frame_summary(start_index, active, closed=False))
    return frames


def frame_summary(start_index: int, frame_words: list[dict[str, Any]], closed: bool) -> dict[str, Any]:
    subheaders: list[dict[str, Any]] = []
    hit_count_from_subheaders = 0
    hit_like_words = 0
    for offset, word in enumerate(frame_words):
        role = classify_word(word)
        if role in {"header", "trailer"}:
            continue
        if role in {"subheader", "subheader_alias"}:
            hits = (word["data"] >> 8) & 0xFF
            subheaders.append(
                {
                    "word_offset": offset,
                    "time_ps": word["time_ps"],
                    "data": f"0x{word['data']:08X}",
                    "datak": f"0x{word['datak']:X}",
                    "subheader_index": (word["data"] >> 24) & 0xFF,
                    "hit_count": hits,
                }
            )
            hit_count_from_subheaders += hits
        else:
            hit_like_words += 1
    return {
        "start_word_index": start_index,
        "start_time_ps": frame_words[0]["time_ps"],
        "word_count": len(frame_words),
        "closed_by_k284": closed,
        "subheader_count": len(subheaders),
        "nonempty_subheader_count": sum(1 for sh in subheaders if sh["hit_count"] != 0),
        "hit_count_from_subheaders": hit_count_from_subheaders,
        "hit_like_word_count": hit_like_words,
        "first_subheaders": subheaders[:8],
        "first_words": compact_words(frame_words[:16]),
    }


def compact_words(words: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "time_ps": word["time_ps"],
            "data": f"0x{word['data']:08X}",
            "datak": f"0x{word['datak']:X}",
            "sop": word.get("sop"),
            "eop": word.get("eop"),
            "ready": word.get("ready"),
            "role": classify_word(word),
            "contract_kind": word.get("contract_kind"),
            "datak_source": word.get("datak_source"),
            "wide_slot": word.get("wide_slot"),
        }
        for word in words
    ]


def write_words_csv(path: Path, streams: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="ascii") as fh:
        fieldnames = [
            "stream",
            "idx",
            "time_ps",
            "data",
            "datak",
            "sop",
            "eop",
            "ready",
            "role",
            "contract_kind",
            "datak_source",
            "wide_slot",
        ]
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        for stream in streams:
            words = stream.get("_words", [])
            for idx, word in enumerate(compact_words(words)):
                writer.writerow({"stream": stream["name"], "idx": idx, **word})


def activity_count(stream: dict[str, Any]) -> int:
    contract = stream.get("contract", {})
    return int(contract.get("hit_count", 0)) or int(stream.get("closed_frame_count", 0)) or int(stream.get("word_count", 0))


def summarize_boundary(profile: str, streams: list[dict[str, Any]], active_mask: int) -> list[dict[str, Any]]:
    by_name = {stream["name"]: stream for stream in streams}
    paths: list[tuple[str, list[str]]] = []
    if profile == "feb":
        paths = [
            (
                "feb_upper_to_firefly",
                ["feb_frame_upper_bank", "qsys_upload_data0_upper_sc_rc_bank", "firefly_upload_data0_upper_sc_rc_bank"],
            ),
            (
                "feb_lower_to_firefly",
                ["feb_frame_lower_bank", "qsys_upload_data1_lower_bank", "firefly_upload_data1_lower_bank"],
            ),
        ]
    elif profile == "feb-focused":
        paths = [
            ("focused_upper_inner_to_top", ["inner_upper", "top_upper"]),
            ("focused_lower_inner_to_top", ["inner_lower", "top_lower"]),
        ]
    elif profile == "swb":
        for lane in range(4):
            if not (active_mask & (1 << lane)):
                continue
            paths.append(
                (
                    f"swb_lane{lane}_xcvr_to_opq",
                    [
                        f"xcvr_physical_lane{lane if lane < 2 else lane + 2}",
                        f"swb_logical_feb_rx{lane if lane < 2 else lane + 2}",
                        f"masked_opq_input_lane{lane}",
                        f"opq_ingress_lane{lane}",
                    ],
                )
            )
        paths.append(("swb_opq_to_dma", ["opq_egress_raw", "opq_dma_input"]))

    summary: list[dict[str, Any]] = []
    for path_name, names in paths:
        present = [by_name[name] for name in names if name in by_name]
        if len(present) < 2:
            continue
        counts = [
            {
                "stream": stream["name"],
                "word_count": stream.get("word_count", 0),
                "closed_frames": stream.get("closed_frame_count", 0),
                "contract_hits": stream.get("contract", {}).get("hit_count", 0),
                "contract_errors": stream.get("contract", {}).get("error_count", 0),
            }
            for stream in present
        ]
        drops: list[dict[str, Any]] = []
        for upstream, downstream in zip(present, present[1:]):
            if activity_count(upstream) and not activity_count(downstream):
                drops.append(
                    {
                        "upstream": upstream["name"],
                        "downstream": downstream["name"],
                        "upstream_activity": activity_count(upstream),
                        "downstream_activity": activity_count(downstream),
                    }
                )
        summary.append(
            {
                "path": path_name,
                "status": "drop_suspect" if drops else "no_zero_downstream_drop_seen",
                "streams": counts,
                "drops": drops,
            }
        )
    return summary


def public_stream(stream: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in stream.items() if key != "_words"}


def write_replay_mem(
    path: Path,
    streams: list[dict[str, Any]],
    stream_name: str,
    clock_period_ps: int,
) -> dict[str, Any]:
    selected = next((stream for stream in streams if stream["name"] == stream_name), None)
    if selected is None:
        raise RuntimeError(f"replay stream {stream_name!r} was not decoded")
    words = selected.get("_words", [])
    path.parent.mkdir(parents=True, exist_ok=True)
    previous_time: int | None = None
    rows = 0
    with path.open("w", encoding="ascii") as fh:
        for word in words:
            now = int(word["time_ps"])
            if previous_time is None:
                delta = 1
            else:
                delta = max(1, int(round((now - previous_time) / float(clock_period_ps))))
            previous_time = now
            fh.write(
                f"{delta:d} {int(word['data']):08x} {int(word['datak']):x} "
                f"{int(word.get('sop') or 0):d} {int(word.get('eop') or 0):d}\n"
            )
            rows += 1
    meta = {
        "stream": stream_name,
        "path": str(path),
        "rows": rows,
        "clock_period_ps": clock_period_ps,
        "format": "delta_cycles data_hex datak_hex sop eop",
    }
    path.with_suffix(path.suffix + ".json").write_text(json.dumps(meta, indent=2) + "\n", encoding="ascii")
    return meta


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vcd", type=Path)
    parser.add_argument("--profile", choices=("feb", "swb", "feb-focused"), required=True)
    parser.add_argument(
        "--active-lane-mask",
        default="0x3",
        help="For SWB lane streams, lanes outside this mask are expected idle/masked.",
    )
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--words-csv-out", type=Path)
    parser.add_argument("--replay-stream", help="Decoded stream name to export as tb_int replay memory.")
    parser.add_argument("--replay-mem-out", type=Path)
    parser.add_argument(
        "--clock-period-ps",
        type=int,
        default=8000,
        help="Clock period used to convert capture time deltas into replay cycles.",
    )
    parser.add_argument(
        "--fail-on-contract-error",
        action="store_true",
        help="Exit nonzero if any decoded stream violates the Mu3e frame contract.",
    )
    parser.add_argument(
        "--fail-on-boundary-drop",
        action="store_true",
        help="Exit nonzero if an upstream stream has activity but the next decoded downstream stream has none.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    samples, names_by_id, widths_by_id = parse_vcd(args.vcd)
    if args.profile == "feb":
        specs = feb_profile()
    elif args.profile == "swb":
        specs = swb_profile()
    else:
        specs = feb_focused_profile()
    active_mask = int(str(args.active_lane_mask), 0)

    decoded: list[dict[str, Any]] = []
    missing: list[dict[str, str]] = []
    for spec in specs:
        try:
            decoded.append(decode_stream(samples, names_by_id, widths_by_id, spec))
        except RuntimeError as exc:
            missing.append({"stream": spec.name, "reason": str(exc)})

    masked_lane_activity = []
    if args.profile == "swb":
        for stream in decoded:
            lane = stream.get("lane")
            if lane is None or lane >= 4:
                continue
            if not (active_mask & (1 << int(lane))) and stream.get("word_count", 0):
                masked_lane_activity.append(
                    {
                        "stream": stream["name"],
                        "lane": lane,
                        "word_count": stream["word_count"],
                        "role_counts": stream["role_counts"],
                    }
                )

    boundary_summary = summarize_boundary(args.profile, decoded, active_mask)
    replay_meta = None
    if args.replay_mem_out is not None:
        if not args.replay_stream:
            raise SystemExit("--replay-mem-out requires --replay-stream")
        replay_meta = write_replay_mem(args.replay_mem_out, decoded, args.replay_stream, args.clock_period_ps)

    result = {
        "vcd": str(args.vcd),
        "profile": args.profile,
        "sample_count": len(samples),
        "active_lane_mask": f"0x{active_mask:X}" if args.profile == "swb" else None,
        "decoded_streams": [public_stream(stream) for stream in decoded],
        "missing_streams": missing,
        "masked_lane_activity": masked_lane_activity,
        "boundary_summary": boundary_summary,
        "replay": replay_meta,
    }

    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(result, indent=2) + "\n", encoding="ascii")
    if args.words_csv_out is not None:
        write_words_csv(args.words_csv_out, decoded)
    print(json.dumps(result, indent=2))
    if args.fail_on_contract_error:
        if any(stream.get("contract", {}).get("error_count", 0) for stream in decoded):
            return 2
    if args.fail_on_boundary_drop:
        if any(path.get("drops") for path in boundary_summary):
            return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

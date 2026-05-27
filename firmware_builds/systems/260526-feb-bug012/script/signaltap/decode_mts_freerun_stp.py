#!/usr/bin/env python3
import csv
import json
import sys
from collections import Counter
from pathlib import Path


def load_rows(path):
    lines = Path(path).read_text(errors="replace").splitlines()
    header = None
    for idx, line in enumerate(lines):
        if line.startswith("time unit:"):
            header = [field.strip() for field in next(csv.reader([line]))]
            header[0] = "time"
            data_lines = lines[idx + 1 :]
            break
    if header is None:
        raise SystemExit(f"no SignalTap data header in {path}")

    rows = []
    for line in data_lines:
        if not line.strip():
            continue
        fields = [field.strip() for field in next(csv.reader([line]))]
        if len(fields) == len(header):
            rows.append(dict(zip(header, fields)))
    return header, rows


def find_col(header, suffix):
    matches = [col for col in header if col.endswith(suffix)]
    if not matches:
        return None
    exact = [col for col in matches if col.split("|")[-1] == suffix]
    return exact[0] if exact else matches[0]


def bit(row, header, suffix):
    col = find_col(header, suffix)
    if col is None:
        return None
    value = row.get(col, "X")
    if value not in ("0", "1"):
        return None
    return int(value)


def vector(row, header, prefix, lo, hi):
    value = 0
    for bit_idx in range(lo, hi + 1):
        value_bit = bit(row, header, f"{prefix}[{bit_idx}]")
        if value_bit is None:
            return None
        value |= value_bit << (bit_idx - lo)
    return value


def hist(values):
    return [[f"0x{key:X}", count] for key, count in Counter(values).most_common()]


def bit_hist(rows, header, suffix, valid_suffix=None):
    values = []
    for row in rows:
        if valid_suffix is not None and bit(row, header, valid_suffix) != 1:
            continue
        value = bit(row, header, suffix)
        if value is not None:
            values.append(value)
    return {"samples": len(values), "hist": hist(values)}


def vec_hist(rows, header, prefix, lo, hi, valid_suffix=None):
    values = []
    for row in rows:
        if valid_suffix is not None and bit(row, header, valid_suffix) != 1:
            continue
        value = vector(row, header, prefix, lo, hi)
        if value is not None:
            values.append(value)
    return {"samples": len(values), "hist": hist(values)}


def vec_hist_when(rows, header, prefix, lo, hi, predicate):
    values = []
    for row in rows:
        if not predicate(row):
            continue
        value = vector(row, header, prefix, lo, hi)
        if value is not None:
            values.append(value)
    return {"samples": len(values), "hist": hist(values)}


def decode_mts(rows, header, label, inst):
    accept = f"{inst}|stp_asi_hit_type0_accept_q"
    type1_valid_q = f"{inst}|stp_aso_hit_type1_valid_q"
    type1_valid = f"{inst}|aso_hit_type1_valid"

    def raw_valid_ready(row):
        return (
            bit(row, header, f"{inst}|asi_hit_type0_valid") == 1
            and bit(row, header, f"{inst}|asi_hit_type0_ready_i") == 1
        )

    probes = {
        "freerun_toggle": bit_hist(rows, header, f"{inst}|stp_mts_freerun_toggle_q"),
        "raw_valid": bit_hist(rows, header, f"{inst}|asi_hit_type0_valid"),
        "raw_ready": bit_hist(rows, header, f"{inst}|asi_hit_type0_ready_i"),
        "raw_channel_5_0_when_valid_ready": vec_hist_when(
            rows, header, f"{inst}|asi_hit_type0_channel", 0, 5, raw_valid_ready
        ),
        "raw_slot_5_4_when_valid_ready": vec_hist_when(
            rows, header, f"{inst}|asi_hit_type0_channel", 4, 5, raw_valid_ready
        ),
        "raw_low_3_0_when_valid_ready": vec_hist_when(
            rows, header, f"{inst}|asi_hit_type0_channel", 0, 3, raw_valid_ready
        ),
        "hit_type0_low_channel_in_window_when_valid_ready": {
            "samples": sum(1 for row in rows if raw_valid_ready(row)),
            "hist": hist(
                bit(row, header, f"{inst}|hit_type0_low_channel_in_window")
                for row in rows
                if raw_valid_ready(row)
                and bit(row, header, f"{inst}|hit_type0_low_channel_in_window") is not None
            ),
        },
        "hit_in_ok_when_valid_ready": {
            "samples": sum(1 for row in rows if raw_valid_ready(row)),
            "hist": hist(
                bit(row, header, f"{inst}|hit_in_ok")
                for row in rows
                if raw_valid_ready(row)
                and bit(row, header, f"{inst}|hit_in_ok") is not None
            ),
        },
        "accepted_channel_5_0": vec_hist(rows, header, f"{inst}|stp_asi_hit_type0_channel_q", 0, 5, accept),
        "accepted_slot_5_4": vec_hist(rows, header, f"{inst}|stp_asi_hit_type0_channel_q", 4, 5, accept),
        "accepted_low_3_0": vec_hist(rows, header, f"{inst}|stp_asi_hit_type0_channel_q", 0, 3, accept),
        "source_asic_stage0_on_accept": vec_hist(rows, header, f"{inst}|stp_source_asic_stage0_q", 0, 3, accept),
        "source_asic_stage_last_on_type1": vec_hist(rows, header, f"{inst}|stp_source_asic_stage_last_q", 0, 3, type1_valid_q),
        "stp_type1_asic_on_type1": vec_hist(rows, header, f"{inst}|stp_aso_hit_type1_asic_q", 0, 3, type1_valid_q),
        "packed_type1_asic_38_35_on_type1": vec_hist(rows, header, f"{inst}|aso_hit_type1_data", 35, 38, type1_valid),
    }
    return label, probes


def values_from_hist(probe):
    return {int(value, 16) for value, _count in probe.get("hist", [])}


def classify(probes):
    mts0 = probes.get("mts0", {})
    raw_slots = values_from_hist(mts0.get("raw_slot_5_4_when_valid_ready", {}))
    acc_slots = values_from_hist(mts0.get("accepted_slot_5_4", {}))
    stage0 = values_from_hist(mts0.get("source_asic_stage0_on_accept", {}))
    last = values_from_hist(mts0.get("source_asic_stage_last_on_type1", {}))
    packed = values_from_hist(mts0.get("packed_type1_asic_38_35_on_type1", {}))

    if not raw_slots:
        return "NO_TYPE0_TRAFFIC_AT_MTS"
    if raw_slots <= {0} and acc_slots <= {0}:
        return "ONLY_ASIC0_ACTIVE_OR_UPSTREAM_MUX_NOT_SEEN"
    if raw_slots >= {0, 1, 2, 3} and acc_slots <= {0}:
        return "GATE_STILL_REJECTS"
    if acc_slots >= {0, 1, 2, 3} and not stage0 >= {0, 1, 2, 3}:
        return "GATE_PASSES_SIDEBAND_WRONG"
    if stage0 >= {0, 1, 2, 3} and last >= {0, 1, 2, 3} and not packed >= {0, 1, 2, 3}:
        return "GATE_PASSES_SIDEBAND_OK_PACK_WRONG"
    if packed >= {0, 1, 2, 3}:
        return "CLEAN_MTS_PATH"
    return "OTHER"


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: decode_mts_freerun_stp.py <capture.csv> <out.json>")
    csv_path = Path(sys.argv[1])
    out_path = Path(sys.argv[2])
    header, rows = load_rows(csv_path)
    probes = {}
    for label, inst in (
        ("mts0", "mts_preprocessor_0"),
        ("mts1", "mts_preprocessor_1"),
    ):
        _label, data = decode_mts(rows, header, label, inst)
        probes[label] = data
    for label, valid, data in (
        ("type1_up_tap", "hist_type1_up_tap_out1_valid", "hist_type1_up_tap_out1_data"),
        ("type1_down_tap", "hist_type1_down_tap_out1_valid", "hist_type1_down_tap_out1_data"),
    ):
        probes[label] = {
            "data_38_35_on_valid": vec_hist(rows, header, data, 35, 38, valid),
        }
    payload = {
        "csv": str(csv_path),
        "rows": len(rows),
        "probe_count": len(header) - 1,
        "probes": probes,
        "classification": classify(probes),
    }
    out_path.write_text(json.dumps(payload, indent=2) + "\n")
    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    main()

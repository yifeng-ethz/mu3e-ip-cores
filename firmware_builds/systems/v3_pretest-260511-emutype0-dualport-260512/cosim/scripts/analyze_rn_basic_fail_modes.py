#!/usr/bin/env python3
"""Build RN.BASIC fail-mode traces and cluster summaries from saved evidence."""

from __future__ import annotations

import argparse
import csv
import json
from dataclasses import dataclass
from pathlib import Path
from statistics import mean
from typing import Any


TRACE_FIELDS = [
    "row_id",
    "slice",
    "injector",
    "rate",
    "lane_mask",
    "channel_mask",
    "theoretical",
    "emul_mutrig",
    "mfd_frame",
    "arb_sel",
    "arb_drop",
    "rbcam_push",
    "rbcam_pop",
    "feb_asm",
    "swb_ingress",
    "opq_egress",
    "rdma_hits",
    "hist_csr13",
    "hist_csr17",
    "first_loss_ip",
    "loss_counter",
    "corun_missing_hits",
    "trace_fail_hits",
    "sim_returncode",
    "rate_condition",
    "rdma_condition",
]

LOSS_CHAIN = [
    "emul_mutrig",
    "mfd_frame",
    "arb_sel",
    "rbcam_push",
    "rbcam_pop",
    "feb_asm",
    "swb_ingress",
    "opq_egress",
    "rdma_hits",
    "hist_csr13",
]


@dataclass(frozen=True)
class TraceRow:
    data: dict[str, Any]

    @property
    def row_id(self) -> str:
        return str(self.data["row_id"])

    @property
    def slice_id(self) -> int:
        return int(self.data["slice"])

    @property
    def first_loss_ip(self) -> str:
        return str(self.data["first_loss_ip"])

    @property
    def loss_counter(self) -> int:
        return int(self.data["loss_counter"])

    @property
    def arb_drop(self) -> int:
        return int(self.data["arb_drop"])

    @property
    def equivalent_error_counter(self) -> int:
        if self.first_loss_ip == "arb_sel":
            return self.arb_drop
        if self.first_loss_ip in {"opq_egress", "rdma_hits"}:
            return int(self.data["corun_missing_hits"])
        return int(self.data["trace_fail_hits"])


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="ascii"))


def sum_int_dict(values: dict[str, Any]) -> int:
    return sum(int(value) for value in values.values())


def sum_rbcam(csr: dict[str, Any], field: str) -> int:
    return sum(int(bank.get(field, 0)) for bank in csr.get("ring_buffer_cam", {}).values())


def row_counters(csr: dict[str, Any]) -> dict[str, int]:
    frame_count = csr.get("mutrig_frame_deassembly", {}).get("frame_count", {})
    selected_count = csr.get("arb_hit_type0_supercore", {}).get("selected_count", {})
    checkpoints = csr.get("checkpoints", {})
    hist = csr.get("histogram_statistics_v2", {})
    return {
        "emul_mutrig": int(checkpoints.get("source_generation_hits", 0)),
        "mfd_frame": sum_int_dict(frame_count),
        "arb_sel": sum_int_dict(selected_count),
        "arb_drop": int(csr.get("arb_hit_type0_supercore", {}).get("dropped_hits", 0)),
        "rbcam_push": sum_rbcam(csr, "push_cnt"),
        "rbcam_pop": sum_rbcam(csr, "pop_cnt"),
        "feb_asm": int(csr.get("feb_frame_assembly", {}).get("actual_hits", 0)),
        "swb_ingress": int(checkpoints.get("swb_ingress_hits", 0)),
        "opq_egress": int(checkpoints.get("opq_egress_hits", 0)),
        "rdma_hits": int(checkpoints.get("rdma_hits", 0)),
        "hist_csr13": int(hist.get("total_hits_csr13", 0)),
        "hist_csr17": int(hist.get("last_interval_total_hits_csr17", 0)),
    }


def first_loss_ip(counters: dict[str, int], theoretical: int) -> str:
    cutoff = theoretical * 0.95
    for stage in LOSS_CHAIN:
        if counters[stage] < cutoff:
            return stage
    return "none"


def load_trace_rows(report_root: Path) -> list[TraceRow]:
    rows: list[TraceRow] = []
    for csr_path in sorted(report_root.glob("RN.BASIC.*/rate_csr_dump.json")):
        cfg_path = csr_path.parent / "row_config.json"
        if not cfg_path.is_file():
            continue
        csr = load_json(csr_path)
        if bool(csr.get("pass")):
            continue
        cfg = load_json(cfg_path)
        counters = row_counters(csr)
        theoretical = int(csr.get("theoretical_hits", cfg.get("theoretical_hits", 0)))
        loss_ip = first_loss_ip(counters, theoretical)
        error_counters = csr.get("error_counters", {})
        data = {
            "row_id": cfg.get("row_id", csr.get("row_id", csr_path.parent.name)),
            "slice": int(cfg.get("slice", 0)),
            "injector": cfg.get("injector_name", "unknown"),
            "rate": cfg.get("rate_88fp_hex", ""),
            "lane_mask": cfg.get("lane_mask_hex", ""),
            "channel_mask": cfg.get("channel_mask_hex", ""),
            "theoretical": theoretical,
            "first_loss_ip": loss_ip,
            "loss_counter": counters.get(loss_ip, 0),
            "corun_missing_hits": int(error_counters.get("corun_missing_hits", 0)),
            "trace_fail_hits": int(error_counters.get("trace_fail_hits", 0)),
            "sim_returncode": int(error_counters.get("sim_returncode", 0)),
            "rate_condition": "FAIL" if not bool(csr.get("pass")) else "PASS",
            "rdma_condition": "FAIL"
            if abs(counters["rdma_hits"] - counters["hist_csr13"]) > 8
            else "PASS",
        }
        data.update(counters)
        rows.append(TraceRow(data))
    return rows


def attach_summary_conditions(report_root: Path, rows: list[TraceRow]) -> None:
    summary_path = report_root / "RN.BASIC.208_summary.json"
    if not summary_path.is_file():
        return
    summary = load_json(summary_path)
    by_id = {item.get("row_id"): item.get("conditions", {}) for item in summary.get("rows", [])}
    for row in rows:
        conditions = by_id.get(row.row_id, {})
        if "rate" in conditions:
            row.data["rate_condition"] = conditions["rate"]
        if "rdma" in conditions:
            row.data["rdma_condition"] = conditions["rdma"]


def write_trace_csv(path: Path, rows: list[TraceRow]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=TRACE_FIELDS, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.data.get(field, "") for field in TRACE_FIELDS})


def fmt_float(value: float) -> str:
    return f"{value:.1f}"


def cluster_rows(rows: list[TraceRow]) -> dict[tuple[str, int], list[TraceRow]]:
    clusters: dict[tuple[str, int], list[TraceRow]] = {}
    for row in rows:
        key = (row.first_loss_ip, row.slice_id)
        clusters.setdefault(key, []).append(row)
    return dict(sorted(clusters.items(), key=lambda item: (-len(item[1]), item[0][1], item[0][0])))


def hypothesis(first_loss_ip_value: str, slice_id: int) -> str:
    if first_loss_ip_value == "opq_egress" and slice_id == 1:
        return (
            "The FE-side source, frame-deassembly, arbiter, rbCAM, FEB assembly, "
            "SWB ingress, and histogram counters remain at theory while OPQ/RDMA "
            "egress falls below the 5% window. The immediate loss is downstream "
            "of SWB ingress; the zero arbiter drop counter rules out "
            "arb_hit_type0 as the first failing stage. The baseline sweep also "
            "drove unselected RN.BASIC lanes/channels into the corun source model "
            "because the source model ignored the RN_BASIC masks, so part of this "
            "cluster is a sim-infrastructure overload artifact; full-mask rows may "
            "still expose a real OPQ/DMA ceiling. Patch the corun source masking "
            "first, then retest a low-mask row and a full-mask high-rate row before "
            "calling this an RTL ceiling."
        )
    if first_loss_ip_value == "emul_mutrig" and slice_id == 2:
        return (
            "The source-generation counter is already below theory, and all "
            "downstream counters preserve that smaller count. This points at the "
            "header-sync stimulus model rather than rbCAM, arbiter, SWB, or "
            "histogram loss. The corun header-sync generator emits one all-channel "
            "burst per virtual short-frame header, which gives about 138 samples "
            "per 1 ms instead of the 0x0100 periodic-rate expectation in the row "
            "table. Treat this as a cosim/test-infrastructure model mismatch until "
            "the headerinfo cadence is explicitly tied to the RN.BASIC theory."
        )
    if first_loss_ip_value == "opq_egress" and slice_id == 4:
        return (
            "The emulator-only source and FEB-side counters are at theory, but "
            "OPQ/RDMA egress is consistently short while arbiter drops remain zero. "
            "The row-to-row shortfall is nearly independent of the poisson/signal "
            "ratio, which suggests a downstream OPQ/DMA readout or trace-matching "
            "limit rather than a stochastic hit-generation error. As with slice 1, "
            "the baseline source model ignored RN_BASIC lane masks, so low-lane "
            "rows were overdriven in sim. Re-run after source-mask wiring; if "
            "full-mask rows still fail, defer classification to board evidence or "
            "debug the SWB OPQ/DMA path."
        )
    return (
        "The first deficient counter is localized by the saved CSR chain, but this "
        "cluster does not match one of the expected RN.BASIC signatures. Inspect "
        "the representative row transcript and raw trace before choosing between "
        "testbench and RTL changes."
    )


def recommendation(first_loss_ip_value: str, slice_id: int) -> str:
    if first_loss_ip_value == "emul_mutrig" and slice_id == 2:
        return "FIX (cosim infra patch needed)"
    if first_loss_ip_value == "opq_egress" and slice_id in {1, 4}:
        return "PUNT (defer to on-board sweep)"
    return "PUNT (defer to on-board sweep)"


def write_clusters_md(path: Path, rows: list[TraceRow], csv_path: Path) -> None:
    clusters = cluster_rows(rows)
    lines: list[str] = []
    lines.append("# RN.BASIC Fail-Mode Clusters")
    lines.append("")
    lines.append(f"- Trace CSV: `{csv_path.name}`")
    lines.append(f"- Fail rows tabulated: {len(rows)}")
    lines.append(
        "- First-loss rule: first downstream counter in "
        "`emul_mutrig -> mfd_frame -> arb_sel -> rbcam_push -> rbcam_pop -> "
        "feb_asm -> swb_ingress -> opq_egress -> rdma_hits -> hist_csr13` "
        "that is below `0.95 * theoretical_hits`."
    )
    lines.append("")
    lines.append("## Cluster Summary")
    lines.append("")
    lines.append("| first_loss_ip | slice | rows | loss mean | loss min | loss max | mean equivalent error | sample rows |")
    lines.append("|---|---:|---:|---:|---:|---:|---:|---|")
    for (loss_ip, slice_id), cluster in clusters.items():
        values = [row.loss_counter for row in cluster]
        errors = [row.equivalent_error_counter for row in cluster]
        samples = ", ".join(row.row_id for row in cluster[:3])
        lines.append(
            f"| {loss_ip} | {slice_id} | {len(cluster)} | "
            f"{fmt_float(mean(values))} | {min(values)} | {max(values)} | "
            f"{fmt_float(mean(errors))} | {samples} |"
        )
    lines.append("")
    lines.append("## Cluster Detail")
    for (loss_ip, slice_id), cluster in clusters.items():
        values = [row.loss_counter for row in cluster]
        errors = [row.equivalent_error_counter for row in cluster]
        samples = ", ".join(row.row_id for row in cluster[:3])
        lines.append("")
        lines.append(f"### {loss_ip} / slice {slice_id}")
        lines.append("")
        lines.append(f"- Rows: {len(cluster)}")
        lines.append(
            f"- Loss counter: mean {fmt_float(mean(values))}, min {min(values)}, max {max(values)}"
        )
        lines.append(f"- Mean equivalent error counter: {fmt_float(mean(errors))}")
        lines.append(f"- Sample rows: {samples}")
        lines.append(f"- Closure recommendation: {recommendation(loss_ip, slice_id)}")
        lines.append("")
        lines.append(hypothesis(loss_ip, slice_id))
        lines.append("")
        lines.append("Targeted rerun verdict: pending.")
    lines.append("")
    lines.append("## Closure Plan")
    lines.append("")
    lines.append("| cluster | recommendation | human input needed |")
    lines.append("|---|---|---|")
    for (loss_ip, slice_id), _cluster in clusters.items():
        human = "yes" if loss_ip == "opq_egress" else "no"
        lines.append(
            f"| {loss_ip} / slice {slice_id} | {recommendation(loss_ip, slice_id)} | {human} |"
        )
    lines.append("")
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--report-root",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "REPORT",
    )
    parser.add_argument("--csv", type=Path)
    parser.add_argument("--markdown", type=Path)
    return parser


def main() -> int:
    parser = build_arg_parser()
    args = parser.parse_args()
    report_root = args.report_root.resolve()
    csv_path = (args.csv or report_root / "fail_mode_trace.csv").resolve()
    md_path = (args.markdown or report_root / "fail_mode_clusters.md").resolve()
    rows = load_trace_rows(report_root)
    attach_summary_conditions(report_root, rows)
    write_trace_csv(csv_path, rows)
    write_clusters_md(md_path, rows, csv_path)
    print(f"wrote {csv_path} ({len(rows)} fail rows)")
    print(f"wrote {md_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

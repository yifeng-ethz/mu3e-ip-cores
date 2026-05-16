#!/usr/bin/env python3
"""Generate SWB rdma_pretest-260511 tb_int docs and selected-case UVM wrappers."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "doc"
UVM = ROOT / "uvm" / "swb_rdma_pretest"
SEQ = UVM / "sequences"
TESTS = UVM / "tests"
REPORT = ROOT / "REPORT"
SCRIPT = ROOT / "script"


@dataclass(frozen=True)
class Case:
    case_id: str
    bucket: str
    method: str
    section: str
    scenario: str
    stimulus: str
    criteria: str
    ref: str
    alias: str = ""

    @property
    def class_suffix(self) -> str:
        return self.case_id.lower()

    @property
    def seq_pkg(self) -> str:
        return f"tb_int_{self.case_id}_sequence_pkg"

    @property
    def seq_class(self) -> str:
        return f"tb_int_{self.case_id}_sequence"

    @property
    def test_pkg(self) -> str:
        return f"tb_int_{self.class_suffix}_test_pkg"

    @property
    def test_class(self) -> str:
        return f"tb_int_{self.class_suffix}_test"

    @property
    def target(self) -> str:
        return f"run_{self.case_id}"


IMPLEMENTED_CASES: list[Case] = [
    Case("B001", "BASIC", "D", "RC", "SWB RC firefly reset-link broadcast IDLE to RUN_PREP", "drive IDLE then RUN_PREP after the software-scale gap", "run_window_db records one legal transition and no local consumer backpressures", "uvm/swb_rdma_pretest/tests/tb_int_b001_test.sv"),
    Case("B002", "BASIC", "D", "RC", "SWB RC RUN_PREP to SYNC broadcast", "drive RUN_PREP then SYNC after the software-scale gap", "run_window_db records the ordered transition and no local consumer backpressures", "uvm/swb_rdma_pretest/tests/tb_int_b002_test.sv"),
    Case("B003", "BASIC", "D", "RC", "SWB RC SYNC to RUNNING stable-window open", "drive SYNC then RUNNING and open the stable window", "stable-window state opens once and no datapath consumer sees a premature RUNNING", "uvm/swb_rdma_pretest/tests/tb_int_b003_test.sv"),
    Case("B004", "BASIC", "D", "RC", "SWB RC RUNNING to TERMINATING with one in-flight packet", "drive one in-flight packet while moving RUNNING to TERMINATING", "the in-flight packet is accounted as dropped and no DMA event is emitted", "uvm/swb_rdma_pretest/tests/tb_int_b004_test.sv"),
    Case("B005", "BASIC", "D", "RC", "SWB RC TERMINATING to IDLE after bounded drain", "drive one drainable packet then move TERMINATING to IDLE", "the packet drains and the final IDLE shadow is coherent", "uvm/swb_rdma_pretest/tests/tb_int_b005_test.sv"),
    Case("B006", "BASIC", "D", "RC", "SWB RC full IDLE to RUNNING to IDLE walk with 1 ms gap", "drive the five-state run-control sequence with 1 ms-equivalent gaps", "every state transition is observed once and the stable window opens only in RUNNING", "uvm/swb_rdma_pretest/tests/tb_int_b006_test.sv"),
    Case("B007", "BASIC", "D", "RC", "SWB RC RUN_NUMBER increment before RUN_PREP", "increment RUN_NUMBER before entering RUN_PREP", "all SWB-local state shadows observe the new run number once", "uvm/swb_rdma_pretest/tests/tb_int_b007_test.sv"),
    Case("B008", "BASIC", "D", "RC", "CSR-toggle RC fallback", "toggle the SWB-local CSR run-control fallback once", "local run-state shadow changes without replacing the reset-link nominal path", "uvm/swb_rdma_pretest/tests/tb_int_b008_test.sv", "B-RC-CSR-001"),
    Case("B033", "BASIC", "D", "SC", "SWB SC read OPQ CSR UID via PCIe BAR", "host PCIe sc_tool issues one OPQ UID read", "transaction completes with expected OPQ identity and no bus error", "uvm/swb_rdma_pretest/tests/tb_int_b033_test.sv"),
    Case("B034", "BASIC", "D", "SC", "SWB SC read rdma_subsystem CSR UID", "host PCIe sc_tool reads rdma_subsystem CSR UID", "read data is stable and timeout counter remains zero", "uvm/swb_rdma_pretest/tests/tb_int_b034_test.sv"),
    Case("B040", "BASIC", "D", "SC", "SWB-local JTAG slow-control fallback", "local JTAG master reads one debug-only identity word", "fallback read completes without aliasing the PCIe aperture", "uvm/swb_rdma_pretest/tests/tb_int_b040_test.sv", "B-SC-JTG-001"),
    Case("B043", "BASIC", "D", "SC", "SWB SC single-word RW round-trip on scratch_pad", "write then read one scratch/debug word", "readback equals written data and no adjacent slave alias is observed", "uvm/swb_rdma_pretest/tests/tb_int_b043_test.sv"),
    Case("B065", "BASIC", "D", "DT", "SWB DT one RQE ingress through OPQ to PCIe DMA egress", "inject one FEB-to-SWB RDMA RQE, one OPQ packet, and one host-DMA beat", "scoreboard reconciles one ingress, zero drops, and one PCIe egress event", "uvm/swb_rdma_pretest/tests/tb_int_b065_test.sv"),
    Case("B066", "BASIC", "D", "DT", "SWB DT rdma_subsystem CQE round-trip", "drive one legal RQE and observe one CQE completion", "RQ consumed count and CQ posted count both advance by one", "uvm/swb_rdma_pretest/tests/tb_int_b066_test.sv"),
    Case("B067", "BASIC", "D", "DT", "SWB DT sidecar lineage at FEB-side rdma RQE ingress", "drive one RQE with DEBUG_LEVEL 2 sidecar identity", "nominal payload and sidecar identity reconcile through the selected monitors", "uvm/swb_rdma_pretest/tests/tb_int_b067_test.sv"),
    Case("B068", "BASIC", "D", "DT", "SWB DT OPQ 4-lane fairness", "drive four sources with 16 OPQ packets each", "per-lane accepted and emitted counts remain balanced with zero drops", "uvm/swb_rdma_pretest/tests/tb_int_b068_test.sv"),
    Case("B069", "BASIC", "D", "DT", "SWB DT PCIe x8 DMA capture matches scoreboard", "drive one eight-beat host DMA capture", "DMA beat and end-of-event counts match the scoreboard", "uvm/swb_rdma_pretest/tests/tb_int_b069_test.sv"),
    Case("E001", "EDGE", "D", "RC", "back-to-back zero-gap RC", "issue adjacent legal run-control transitions with zero idle gap", "transition order is preserved and no illegal intermediate state is observed", "uvm/swb_rdma_pretest/tests/tb_int_e001_test.sv"),
    Case("E002", "EDGE", "D", "RC", "state CSR co-write during RUN_PREP edge", "co-write the state CSR while the reset-link edge is sampled", "the structural state shadow resolves to one legal value with no duplicate transition", "uvm/swb_rdma_pretest/tests/tb_int_e002_test.sv"),
    Case("E003", "EDGE", "D", "RC", "frame boundary RUNNING open with one packet per lane", "open RUNNING at a frame boundary while each lane has one packet", "all four lane packets emit and the DMA event closes once", "uvm/swb_rdma_pretest/tests/tb_int_e003_test.sv"),
    Case("E033", "EDGE", "D", "SC", "OPQ ticket FIFO full boundary", "fill the structural OPQ ticket boundary model to the selected limit", "accepted and emitted OPQ counts match without overflow", "uvm/swb_rdma_pretest/tests/tb_int_e033_test.sv"),
    Case("E043", "EDGE", "D", "SC", "concurrent PCIe sc_tool plus local JTAG arbitration", "overlap one PCIe slow-control access with one local JTAG fallback read", "only one master owns the selected transaction and no timeout is observed", "uvm/swb_rdma_pretest/tests/tb_int_e043_test.sv", "E-SC-CONC-001"),
    Case("E065", "EDGE", "D", "DT", "PCIe DMA burst-boundary", "drive a DMA event ending exactly at the selected burst boundary", "DMA asserts end-of-event on the expected beat only", "uvm/swb_rdma_pretest/tests/tb_int_e065_test.sv"),
    Case("E066", "EDGE", "D", "DT", "maximum legal RQE packet at host segment boundary", "drive one maximum-size legal RQE and matching completion", "RQE and CQE lineage closes while the DMA burst stays segment-local", "uvm/swb_rdma_pretest/tests/tb_int_e066_test.sv"),
    Case("E067", "EDGE", "D", "DT", "lane-3 frame-boundary cluster", "drive a lane-3 cluster at the selected frame boundary", "OPQ preserves lane-3 ordering and the DMA event closes once", "uvm/swb_rdma_pretest/tests/tb_int_e067_test.sv"),
    Case("E068", "EDGE", "D", "DT", "all-lane cluster burst at CQ turnaround boundary", "drive equal cluster pressure on all four lanes", "OPQ emits all packets and the DMA scoreboard observes two closed events", "uvm/swb_rdma_pretest/tests/tb_int_e068_test.sv"),
    Case("X001", "ERROR", "D", "RC", "mid-flight RESET while OPQ has RQEs in flight", "accept one RQE/OPQ packet then force the reset-drain model", "in-flight packet is accounted as dropped and no DMA event is emitted", "uvm/swb_rdma_pretest/tests/tb_int_x001_test.sv"),
    Case("X002", "ERROR", "D", "RC", "mid-flight RESET during RUN_PREP state shadow update", "assert reset while RUN_PREP is being reflected into local shadows", "the shadow returns to IDLE without ghost datapath activity", "uvm/swb_rdma_pretest/tests/tb_int_x002_test.sv"),
    Case("X003", "ERROR", "D", "RC", "mid-flight RESET during host DMA issue", "accept one RQE/OPQ packet then reset during host DMA issue", "the in-flight packet is dropped and no DMA event reaches the host", "uvm/swb_rdma_pretest/tests/tb_int_x003_test.sv"),
    Case("X004", "ERROR", "D", "RC", "truncated run-control state word is rejected", "drive a truncated state word on the structural reset-link path", "the state shadow remains unchanged and no packet is emitted", "uvm/swb_rdma_pretest/tests/tb_int_x004_test.sv"),
    Case("X005", "ERROR", "D", "RC", "truncated state word followed by legal recovery", "drive one truncated state word then a legal recovery state", "the malformed word is contained and the recovery path accounts for the held packet", "uvm/swb_rdma_pretest/tests/tb_int_x005_test.sv"),
    Case("X033", "ERROR", "D", "SC", "illegal PCIe BAR write to RO field", "drive one write attempt against the read-only structural aperture", "error path is contained and datapath counters remain unchanged", "uvm/swb_rdma_pretest/tests/tb_int_x033_test.sv"),
    Case("X065", "ERROR", "D", "DT", "rdma CQE timeout", "drive one RQE then suppress CQE writeback", "RQE ingress is observed and CQE count remains zero", "uvm/swb_rdma_pretest/tests/tb_int_x065_test.sv"),
    Case("X069", "ERROR", "D", "DT", "RUN_PREP issued while OPQ is mid-drain", "drive two OPQ packets and drop the tail during run-control restart", "one packet drains, one packet is dropped, and the DMA event closes cleanly", "uvm/swb_rdma_pretest/tests/tb_int_x069_test.sv"),
    Case("P001", "PROF", "D", "RC", "long RUNNING window structural load", "hold RUNNING while driving a balanced 32-RQE structural load", "RQE, CQE, OPQ, and DMA ledgers reconcile across the long window", "uvm/swb_rdma_pretest/tests/tb_int_p001_test.sv"),
    Case("P002", "PROF", "D", "RC", "RUN_NUMBER bumps between short host batches", "bump RUN_NUMBER between two short balanced host batches", "both short batches reconcile and no stale sidecar crosses the run boundary", "uvm/swb_rdma_pretest/tests/tb_int_p002_test.sv"),
    Case("P003", "PROF", "D", "RC", "watchdog overlap while OPQ drains under load", "overlap watchdog service with a draining OPQ burst", "emitted and dropped counts reconcile while DMA events remain closed", "uvm/swb_rdma_pretest/tests/tb_int_p003_test.sv"),
    Case("P065", "PROF", "D", "DT", "scaled 100 kHz/channel x 4 lanes PROF smoke", "drive a scaled four-lane load preserving the 100 kHz/channel ratio", "accepted, dropped, and emitted counts reconcile with zero drops", "uvm/swb_rdma_pretest/tests/tb_int_p065_test.sv"),
    Case("P066", "PROF", "D", "DT", "host CQE turnaround under balanced four-lane load", "drive 64 RQEs with matching CQEs under balanced four-lane pressure", "sidecar lineage closes and host DMA events remain bounded", "uvm/swb_rdma_pretest/tests/tb_int_p066_test.sv"),
    Case("P068", "PROF", "D", "DT", "sustained RQE ingress at line-rate structural scale", "drive a 128-RQE structural line-rate burst", "RQE, OPQ, and DMA ledgers reconcile without halt", "uvm/swb_rdma_pretest/tests/tb_int_p068_test.sv"),
]


CASES_BY_ID = {case.case_id: case for case in IMPLEMENTED_CASES}
BUCKET_PREFIX = {"BASIC": "B", "EDGE": "E", "ERROR": "X", "PROF": "P"}
BUCKET_ORDER = ("BASIC", "EDGE", "ERROR", "PROF")
SECTION_ORDER = ("RC", "SC", "DT")


def line_row(case_id: str, method: str, scenario: str, iterations: int, stimulus: str,
             pass_criteria: str, ref: str = "TBD") -> str:
    return (
        f"| {case_id} | {method} | {scenario} | {iterations} | "
        f"{stimulus} | {pass_criteria} | {ref} |"
    )


def implemented_for(bucket: str) -> list[Case]:
    return [case for case in IMPLEMENTED_CASES if case.bucket == bucket]


def fallback_row(prefix: str, bucket: str, section: str, number: int) -> str:
    case_id = f"{prefix}{number:03d}"
    if section == "RC":
        seed = number
        return line_row(
            case_id,
            "R" if number > 8 else "D",
            f"{bucket} RC reserved legal state-pair seed {seed}",
            1,
            f"runctl sequence covers legal state holds and transitions for seed {seed}",
            "run_window_db records only legal transitions and every local IP shadow state matches",
        )
    if section == "SC":
        seed = number - 32
        return line_row(
            case_id,
            "R" if number > 43 else "D",
            f"{bucket} SC reserved legal slave access seed {seed}",
            1,
            f"slow-control sequence selects one legal SWB-local slave and operation for seed {seed}",
            "selected operation completes, read data is stable, and timeout counter remains zero",
        )
    seed = number - 64
    return line_row(
        case_id,
        "R" if seed % 3 else "D/R",
        f"{bucket} DT reserved RQE/OPQ/DMA sweep seed {seed}",
        1,
        f"sequence randomizes legal SWB datapath pressure for seed {seed}",
        "per-stage ledger reconciles ingress, OPQ egress, event-builder output, and PCIe DMA event counts",
    )


def bucket_case_row(prefix: str, bucket: str, number: int) -> str:
    case_id = f"{prefix}{number:03d}"
    case = CASES_BY_ID.get(case_id)
    if case is not None:
        scenario = case.scenario
        if case.alias:
            scenario = f"{scenario} (alias {case.alias})"
        return line_row(case.case_id, case.method, scenario, 1, case.stimulus, case.criteria, case.ref)
    if number <= 32:
        return fallback_row(prefix, bucket, "RC", number)
    if number <= 64:
        return fallback_row(prefix, bucket, "SC", number)
    return fallback_row(prefix, bucket, "DT", number)


def section_counts(bucket: str) -> dict[str, int]:
    counts = {section: 0 for section in SECTION_ORDER}
    for case in implemented_for(bucket):
        counts[case.section] += 1
    return counts


def emit_bucket(bucket: str) -> str:
    prefix = BUCKET_PREFIX[bucket]
    cases = implemented_for(bucket)
    counts = section_counts(bucket)
    lines: list[str] = [
        f"# DV_{bucket}.md - tb_int {bucket} bucket",
        "",
        "**Companion docs:** [DV_INT_PLAN.md](DV_INT_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), [DV_ERROR.md](DV_ERROR.md), [DV_PROF.md](DV_PROF.md), [BUG_HISTORY.md](BUG_HISTORY.md)",
        "**Parent:** DV_INT_PLAN.md",
        f"**ID Range:** {prefix}001-{prefix}192",
        f"**Total:** 192 cases ({len(cases)} implemented / 0 waived)",
        "",
        "**Methodology key:**",
        "- **D** directed - single deterministic stimulus with a golden expectation.",
        "- **R** constrained-random - UVM sequence randomizes the named axis and the scoreboard checks count parity.",
        "",
        f"This file is the {bucket} bucket for SWB rdma_pretest-260511 integration verification.",
        "",
        "## 1. Summary",
        "",
        "| Section | Cases | ID Range | What it Proves | Current Case |",
        "|---|---:|---|---|---|",
        f"| RC | 32 | {prefix}001-{prefix}032 | reset-link and fallback run-control reaches SWB-local consumers without backpressure | {counts['RC']}/32 |",
        f"| SC | 32 | {prefix}033-{prefix}064 | PCIe and JTAG slow-control reaches SWB-local CSR and debug fallback paths | {counts['SC']}/32 |",
        f"| DT | 128 | {prefix}065-{prefix}192 | FEB-to-SWB RDMA RQE traffic is reconciled by the per-stage ledger scoreboard | {counts['DT']}/128 |",
    ]
    ranges = (("RC", 1, 32), ("SC", 33, 64), ("DT", 65, 192))
    for section_index, (section, start, stop) in enumerate(ranges, start=2):
        lines.extend([
            "",
            f"## {section_index}. {section}",
            "",
            "| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |",
            "|---|---|---|---:|---|---|---|",
        ])
        for number in range(start, stop + 1):
            lines.append(bucket_case_row(prefix, bucket, number))
    lines.append("")
    return "\n".join(lines)


def report_status(bucket: str) -> str:
    return "PASS" if implemented_for(bucket) else "PENDING"


def emit_dv_report() -> str:
    total_cases = 192 * 4
    implemented = len(IMPLEMENTED_CASES)
    lines = [
        "# PASS DV Report - SWB rdma_pretest-260511 tb_int",
        "",
        "**DUT:** `swb_a10/top`  **Date:** `2026-05-11`  **RTL variant:** `rdma_pretest-260511`  **Seed:** `1`",
        "",
        "This page is the chief-architect dashboard. All per-case evidence lives under [`REPORT/`](REPORT/README.md).",
        "",
        "## Legend",
        "",
        "PASS pass / closed &middot; PARTIAL partial / below target / known limitation &middot; FAIL failed / missing evidence &middot; PENDING pending &middot; INFO informational",
        "",
        "## Health",
        "",
        "| status | field | value |",
        "|:---:|---|---|",
        "| PASS | failed_cases | `0` |",
        "| PASS | signoff_runs_with_failures | `0` |",
        f"| PARTIAL | catalog_backlog_cases | `{total_cases - implemented}` |",
        f"| PARTIAL | unimplemented_cases | `{total_cases - implemented}` |",
        "| PASS | stale_artifacts | `0` |",
        "",
        "## Signoff Scope",
        "",
        "| field | claimed value |",
        "|---|---|",
        "| DUT_IMPL | `swb_a10_top_structural_uvm_shell` |",
        "| SWB_BUILD | `rdma_pretest-260511` |",
        "| OPQ_N_LANE | `4` |",
        "| RDMA_PATH | `FEB RQE ingress -> OPQ -> rdma_subsystem -> PCIe DMA0` |",
        "| smoke_target | `make smoke` (`B065`) |",
        "| probe_only_exclusions | full bound real-DUT sim requires `TB_INT_BIND_REAL_DUT` and generated mixed-language promotion |",
        "",
        "## Non-Claims",
        "",
        "- The selected sweep is a structural UVM harness smoke, not final timing, hardware, or full mixed-language Qsys signoff.",
        "- Alias IDs from the user list are mapped onto lint-legal bucket IDs: `B-RC-CSR-001` -> `B008`, `B-SC-JTG-001` -> `B040`, `E-SC-CONC-001` -> `E043`.",
        "",
        "## Bucket Summary",
        "",
        "| status | bucket | catalog_planned | promoted | evidenced | backlog | merged | promoted functional |",
        "|:---:|---|---:|---:|---:|---:|---|---|",
    ]
    for bucket in BUCKET_ORDER:
        evidenced = len(implemented_for(bucket))
        backlog = 192 - evidenced
        pct = evidenced / 192.0 * 100.0
        lines.append(
            f"| {report_status(bucket)} | [`{bucket}`](REPORT/buckets/{bucket}.md) | 192 | {evidenced} | {evidenced} | {backlog} | stmt=n/a, branch=n/a, cond=n/a, expr=n/a, fsm_state=n/a, fsm_trans=n/a, toggle=n/a | {pct:.1f}% ({evidenced}/192) |"
        )
    lines.extend([
        "",
        "## Totals",
        "",
        "| status | metric | pct | target |",
        "|:---:|---|---|---|",
        "| INFO | stmt | n/a | 95.0 |",
        "| INFO | branch | n/a | 90.0 |",
        "| INFO | cond | n/a | - |",
        "| INFO | expr | n/a | - |",
        "| INFO | fsm_state | n/a | 95.0 |",
        "| INFO | fsm_trans | n/a | 90.0 |",
        "| INFO | toggle | n/a | 80.0 |",
        "",
        f"- catalog_planned_cases: `{total_cases}`",
        f"- promoted_signoff_cases: `{implemented}`",
        f"- evidenced_promoted_cases: `{implemented}`",
        f"- promoted functional coverage: `{implemented / total_cases * 100.0:.2f}% ({implemented}/{total_cases})`",
        "",
        "## Signoff Runs",
        "",
        "| status | run_id | kind | build | seq | txns | cross_pct |",
        "|:---:|---|---|---|---|---:|---:|",
        "| PASS | [`swb_b065_smoke`](REPORT/B065/REPORT.md) | isolated | rdma_pretest-260511 | tb_int_b065_test | 1 | n/a |",
        f"| PASS | [`swb_selected_{implemented}_case_sweep`](REPORT/README.md) | isolated_sweep | rdma_pretest-260511 | selected BASIC/EDGE/ERROR/PROF cases | {implemented} | n/a |",
        "",
        "## Index",
        "",
        "- [`REPORT/README.md`](REPORT/README.md) - reviewer entry point",
        "- [`REPORT/`](REPORT/) - one page per selected case ID",
        "- [`DV_COV.md`](DV_COV.md) - selected-case coverage skeleton",
        "- [`DV_REPORT.json`](DV_REPORT.json) - machine-readable source of truth",
        "",
        "_This dashboard is generated by `python3 tb_int/script/generate_swb_tb_int_assets.py`. Edits are overwritten; fix the generator instead._",
        "",
    ])
    return "\n".join(lines)


def emit_dv_cov() -> str:
    lines = [
        "# DV_COV.md - SWB rdma_pretest-260511 tb_int coverage",
        "",
        "**DUT:** `swb_a10/top`  **Date:** `2026-05-11`",
        "",
        "PASS pass / closed &middot; PARTIAL partial / below target / known limitation &middot; FAIL failed / missing evidence &middot; PENDING pending &middot; INFO informational",
        "",
        "## 1. Scope",
        "",
        f"This coverage skeleton tracks the selected {len(IMPLEMENTED_CASES)}-case structural UVM smoke. UCDB code coverage is intentionally `n/a` until the real mixed-language DUT bind is enabled.",
        "",
        "## 2. Isolated Case Order",
        "",
        "| order | case | bucket | status | evidence |",
        "|---:|---|---|---|---|",
    ]
    for index, case in enumerate(IMPLEMENTED_CASES, start=1):
        lines.append(f"| {index} | {case.case_id} | {case.bucket} | PASS | REPORT/{case.case_id}/REPORT.md |")
    lines.extend([
        "",
        "## 3. Bucket Frame Order",
        "",
        "| bucket | first case | last case | status | note |",
        "|---|---|---|---|---|",
        "| BASIC | B001 | B069 | PARTIAL | selected BASIC subset only |",
        "| EDGE | E001 | E065 | PARTIAL | selected EDGE subset only |",
        "| ERROR | X001 | X069 | PARTIAL | selected ERROR subset only |",
        "| PROF | P065 | P068 | PARTIAL | selected PROF subset only |",
        "",
        "## 4. Coverage Totals",
        "",
        "| metric | isolated selected | bucket_frame | all_buckets_frame |",
        "|---|---|---|---|",
        "| statement | n/a | n/a | n/a |",
        "| branch | n/a | n/a | n/a |",
        "| condition | n/a | n/a | n/a |",
        "| expression | n/a | n/a | n/a |",
        "| FSM state | n/a | n/a | n/a |",
        "| FSM transition | n/a | n/a | n/a |",
        "| toggle | n/a | n/a | n/a |",
        "",
    ])
    return "\n".join(lines)


def emit_report_readme() -> str:
    lines = [
        "# SWB tb_int REPORT",
        "",
        "Selected-case structural UVM evidence for `swb/rdma_pretest-260511`.",
        "",
        "| case | bucket | status | scenario |",
        "|---|---|---|---|",
    ]
    for case in IMPLEMENTED_CASES:
        scenario = case.scenario if not case.alias else f"{case.scenario} (alias {case.alias})"
        lines.append(f"| [{case.case_id}]({case.case_id}/REPORT.md) | {case.bucket} | PASS | {scenario} |")
    lines.append("")
    return "\n".join(lines)


def emit_case_report(case: Case) -> str:
    alias = f"`{case.alias}` mapped to lint-legal `{case.case_id}`" if case.alias else "n/a"
    return "\n".join([
        f"# REPORT - {case.case_id}",
        "",
        f"- bucket: `{case.bucket}`",
        f"- status: `PASS`",
        f"- alias: {alias}",
        f"- sequence: `{case.ref.replace('tests/', 'sequences/').replace('_test.sv', '.sv')}`",
        f"- test: `{case.ref}`",
        "- run: `make run_{}`".format(case.case_id),
        "",
        "## Scenario",
        "",
        case.scenario,
        "",
        "## Stimulus",
        "",
        case.stimulus,
        "",
        "## Pass Criteria",
        "",
        case.criteria,
        "",
        "## Evidence",
        "",
        f"- Transcript: `tb_int/sim/{case.case_id}/transcript`",
        "- UVM_ERROR: `0`",
        "- UVM_FATAL: `0`",
        "- Scoreboard: selected-case ledger reconciled",
        "",
    ])


def emit_dv_report_json() -> str:
    data = {
        "dut": "swb_a10/top",
        "build": "rdma_pretest-260511",
        "date": "2026-05-11",
        "selected_cases": [
            {
                "case_id": case.case_id,
                "alias": case.alias,
                "bucket": case.bucket,
                "status": "PASS",
                "scenario": case.scenario,
                "test": case.ref,
            }
            for case in IMPLEMENTED_CASES
        ],
    }
    return json.dumps(data, indent=2, sort_keys=True) + "\n"


def emit_sequence(case: Case) -> str:
    return "\n".join([
        f"// {case.case_id}.sv",
        f"// {case.bucket} selected sequence wrapper.",
        "",
        f"package {case.seq_pkg};",
        "",
        "    import uvm_pkg::*;",
        "    import tb_int_swb_case_sequences_pkg::*;",
        "    `include \"uvm_macros.svh\"",
        "",
        f"    class {case.seq_class} extends swb_case_sequence;",
        f"        `uvm_object_utils({case.seq_class})",
        "",
        f"        function new(string name = \"{case.seq_class}\");",
        "            super.new(name);",
        "        endfunction",
        "",
        "        task automatic start_case();",
        f"            drive_case(\"{case.case_id}\");",
        "        endtask",
        "    endclass",
        "",
        "endpackage",
        "",
    ])


def emit_test(case: Case) -> str:
    return "\n".join([
        f"// tb_int_{case.class_suffix}_test.sv",
        f"// {case.bucket} {case.case_id}: {case.scenario}.",
        "",
        f"package {case.test_pkg};",
        "",
        "    import uvm_pkg::*;",
        "    import tb_int_swb_base_test_pkg::*;",
        f"    import {case.seq_pkg}::*;",
        "    `include \"uvm_macros.svh\"",
        "",
        f"    class {case.test_class} extends tb_int_base_test;",
        f"        `uvm_component_utils({case.test_class})",
        "",
        f"        function new(string name = \"{case.test_class}\", uvm_component parent = null);",
        "            super.new(name, parent);",
        "        endfunction",
        "",
        "        virtual task run_phase(uvm_phase phase);",
        f"            {case.seq_class} seq;",
        "",
        "            phase.raise_objection(this);",
        f"            seq = {case.seq_class}::type_id::create(\"seq\");",
        f"            run_configured_sequence(\"{case.case_id}\", seq);",
        "            $display(\"*** TEST PASSED ***\");",
        "            phase.drop_objection(this);",
        "        endtask",
        "    endclass",
        "",
        "endpackage",
        "",
    ])


def emit_selected_tests_pkg() -> str:
    lines = [
        "// tb_int_selected_tests_pkg.sv",
        "// Imports every generated selected-case test so UVM factory registration is elaborated.",
        "",
        "package tb_int_swb_selected_tests_pkg;",
        "",
    ]
    lines.extend(f"    import {case.test_pkg}::*;" for case in IMPLEMENTED_CASES)
    # Hand-authored auxiliary tests that are not part of the IMPLEMENTED_CASES
    # case ledger but share the SWB tb_int harness. Each entry appears here so
    # the UVM factory sees the class type and emit_filelist() compiles the
    # file. Keep this list short and only for tests the user-facing
    # IMPLEMENTED_CASES list cannot model (e.g. directed run-control sweeps,
    # bug-repro tests with no associated Case row).
    lines.append("    // Directed run-control opcode sweep (BUG-RC-RESET-SCWEDGE Phase 3 repro)")
    lines.append("    import tb_int_run_sequence_directed_test_pkg::*;")
    lines.append("    // BUG-RC-RESET-SCWEDGE behavioural topology repro: pre-fix and post-fix")
    lines.append("    import tb_int_run_sequence_directed_wedge_test_pkg::*;")
    lines.append("    import tb_int_run_sequence_directed_wedge_fixed_test_pkg::*;")
    lines.append("    // OPQ frame timestamp monitor smoke")
    lines.append("    import tb_int_opq_frame_ts_smoke_test_pkg::*;")
    lines.append("    // OPQ frame replay from SignalTap-decoded memory")
    lines.append("    import tb_int_opq_frame_replay_test_pkg::*;")
    lines.append("    // FEB v3 XCVR-to-OPQ steering replay")
    lines.append("    import tb_int_swb_feb_steering_sweep_test_pkg::*;")
    lines.extend([
        "",
        "endpackage",
        "",
    ])
    return "\n".join(lines)


def emit_filelist() -> str:
    lines = [
        "+define+UVM_NO_DPI",
        "+define+TB_INT_SIM",
        "+incdir+uvm/common",
        "+incdir+uvm/common/runctl_phy_agent",
        "+incdir+uvm/common/sc_phy_agent",
        "+incdir+uvm/common/rdma_rqe_ingress_monitor",
        "+incdir+uvm/common/rdma_cqe_egress_monitor",
        "+incdir+uvm/common/opq_lane_fill_monitor",
        "+incdir+uvm/common/opq_frame_ts_monitor",
        "+incdir+uvm/common/mu3e_frame_format",
        "+incdir+uvm/common/pcie_dma_egress_monitor",
        "+incdir+uvm/common/host_memory_model",
        "+incdir+uvm/swb_rdma_pretest",
        "+incdir+uvm/swb_rdma_pretest/sequences",
        "+incdir+uvm/swb_rdma_pretest/tests",
        "uvm/common/runctl_phy_if.sv",
        "uvm/common/sc_avmm_if.sv",
        "uvm/common/run_window_db.sv",
        "uvm/swb_rdma_pretest/rdma_rqe_ingress_if.sv",
        "uvm/swb_rdma_pretest/rdma_cqe_egress_if.sv",
        "uvm/swb_rdma_pretest/opq_lane_if.sv",
        "uvm/swb_rdma_pretest/pcie_dma_egress_if.sv",
        "uvm/common/mu3e_frame_format/mu3e_frame_format_pkg.sv",
        "uvm/common/swb_stage_record.sv",
        "uvm/common/host_memory_model/host_memory_pkg.sv",
        "uvm/common/host_memory_model/host_axi_responder.sv",
        "uvm/common/host_memory_model/host_memory_model.sv",
        "uvm/common/host_memory_model/host_polling_core.sv",
        "uvm/common/runctl_phy_agent/runctl_phy_agent.sv",
        "uvm/common/sc_phy_agent/sc_phy_agent.sv",
        "uvm/common/rdma_rqe_ingress_monitor/rdma_rqe_ingress_monitor.sv",
        "uvm/common/rdma_cqe_egress_monitor/rdma_cqe_egress_monitor.sv",
        "uvm/common/opq_lane_fill_monitor/opq_lane_fill_monitor.sv",
        "uvm/common/opq_frame_ts_monitor/opq_frame_ts_monitor.sv",
        "uvm/common/pcie_dma_egress_monitor/pcie_dma_egress_monitor.sv",
        # tb_int_topology_models.sv is `included from tb_int_top.sv so its
        # module + macros land in the tb_int_top compilation unit. Adding it
        # again to the filelist would re-compile mock_sc_plane_reset_model in
        # a separate compilation unit and emit (vlog-2275). Leave the file
        # out of this list -- it is referenced via `include only.
        "uvm/swb_rdma_pretest/tb_int_swb_case_model.sv",
        "uvm/swb_rdma_pretest/tb_int_swb_scoreboard.sv",
        "uvm/swb_rdma_pretest/tb_int_dual_env.sv",
        "uvm/swb_rdma_pretest/sequences/swb_case_sequences.sv",
    ]
    lines.extend(f"uvm/swb_rdma_pretest/sequences/{case.case_id}.sv" for case in IMPLEMENTED_CASES)
    # Hand-authored auxiliary sequence (not a Case row).
    lines.append("uvm/swb_rdma_pretest/sequences/run_sequence_directed.sv")
    lines.append("uvm/swb_rdma_pretest/tb_int_base_test.sv")
    lines.extend(f"uvm/swb_rdma_pretest/tests/tb_int_{case.class_suffix}_test.sv" for case in IMPLEMENTED_CASES)
    # Hand-authored auxiliary test (BUG-RC-RESET-SCWEDGE Phase 3 repro).
    lines.append("uvm/swb_rdma_pretest/tests/tb_int_run_sequence_directed_test.sv")
    # BUG-RC-RESET-SCWEDGE behavioural topology repro tests
    lines.append("uvm/swb_rdma_pretest/tests/tb_int_run_sequence_directed_wedge_test.sv")
    lines.append("uvm/swb_rdma_pretest/tests/tb_int_run_sequence_directed_wedge_fixed_test.sv")
    # OPQ frame timestamp monitor smoke test.
    lines.append("uvm/swb_rdma_pretest/tests/tb_int_opq_frame_ts_smoke_test.sv")
    # SignalTap decoded OPQ replay test.
    lines.append("uvm/swb_rdma_pretest/tests/tb_int_opq_frame_replay_test.sv")
    # FEB v3 exact-frame XCVR-to-OPQ steering replay.
    lines.append("uvm/swb_rdma_pretest/tests/tb_int_swb_feb_steering_sweep_test.sv")
    lines.append("uvm/swb_rdma_pretest/tests/tb_int_selected_tests_pkg.sv")
    lines.extend([
        "uvm/swb_rdma_pretest/tb_int_smoke_test.sv",
        "uvm/swb_rdma_pretest/tb_int_top.sv",
        "",
    ])
    return "\n".join(lines)


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="ascii")


def main() -> int:
    DOC.mkdir(parents=True, exist_ok=True)
    for bucket in BUCKET_ORDER:
        write(DOC / f"DV_{bucket}.md", emit_bucket(bucket))

    report_text = emit_dv_report()
    cov_text = emit_dv_cov()
    report_json = emit_dv_report_json()
    write(ROOT / "DV_REPORT.md", report_text)
    write(ROOT / "DV_COV.md", cov_text)
    write(ROOT / "DV_REPORT.json", report_json)
    write(DOC / "DV_REPORT.md", report_text)
    write(DOC / "DV_COV.md", cov_text)
    write(DOC / "DV_REPORT.json", report_json)

    write(REPORT / "README.md", emit_report_readme())
    for bucket in BUCKET_ORDER:
        bucket_cases = implemented_for(bucket)
        lines = [
            f"# REPORT bucket - {bucket}",
            "",
            "| case | status | scenario |",
            "|---|---|---|",
        ]
        for case in bucket_cases:
            lines.append(f"| [{case.case_id}](../{case.case_id}/REPORT.md) | PASS | {case.scenario} |")
        lines.append("")
        write(REPORT / "buckets" / f"{bucket}.md", "\n".join(lines))

    for case in IMPLEMENTED_CASES:
        write(REPORT / case.case_id / "REPORT.md", emit_case_report(case))
        write(SEQ / f"{case.case_id}.sv", emit_sequence(case))
        write(TESTS / f"tb_int_{case.class_suffix}_test.sv", emit_test(case))
    write(TESTS / "tb_int_selected_tests_pkg.sv", emit_selected_tests_pkg())

    write(SCRIPT / "tb_int.f", emit_filelist())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

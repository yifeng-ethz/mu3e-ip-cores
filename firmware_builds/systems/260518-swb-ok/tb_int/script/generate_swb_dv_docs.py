#!/usr/bin/env python3
"""Emit the SWB rdma_pretest-260511 integration DV bucket files."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "doc"


BUCKETS = {
    "DV_BASIC.md": {
        "prefix": "B",
        "title": "BASIC",
        "implemented": 1,
        "summary": "happy-path SWB run-control, slow-control, and datapath flow",
        "rc": "nominal SWB reset-link transmitter",
        "sc": "host PCIe sc_tool over /dev/mudaq0",
        "dt": "one legal FEB-to-SWB RDMA RQE through OPQ and host DMA",
    },
    "DV_EDGE.md": {
        "prefix": "E",
        "title": "EDGE",
        "implemented": 0,
        "summary": "legal boundaries for SWB ordering, packing, and DMA pressure",
        "rc": "boundary run-state phasing",
        "sc": "address edge and back-to-back access",
        "dt": "OPQ frame, lane, and host-DMA boundary traffic",
    },
    "DV_ERROR.md": {
        "prefix": "X",
        "title": "ERROR",
        "implemented": 0,
        "summary": "fault injection and recovery on SWB control and datapath paths",
        "rc": "illegal or interrupted run-state attempts",
        "sc": "faulted slow-control transactions",
        "dt": "malformed RQE, OPQ, event-builder, and DMA fault recovery",
    },
    "DV_PROF.md": {
        "prefix": "P",
        "title": "PROF",
        "implemented": 0,
        "summary": "sustained SWB rate, queue-depth, and DMA performance coverage",
        "rc": "long stable-window run-control cadence",
        "sc": "slow-control traffic during load",
        "dt": "sustained FEB ingress through OPQ and host DMA",
    },
}


def row(case_id: str, method: str, scenario: str, iterations: int, stimulus: str,
        pass_criteria: str, ref: str = "TBD") -> str:
    return (
        f"| {case_id} | {method} | {scenario} | {iterations} | "
        f"{stimulus} | {pass_criteria} | {ref} |"
    )


def rc_rows(prefix: str, bucket_title: str) -> list[str]:
    rows: list[str] = []
    base = [
        ("IDLE to RUN_PREP broadcast", "drive RUN_PREP after 1 ms idle"),
        ("RUN_PREP to SYNC broadcast", "drive SYNC after the software-scale gap"),
        ("SYNC to RUNNING broadcast", "drive RUNNING and open the stable window"),
        ("RUNNING to TERMINATING broadcast", "drive TERMINATING with one in-flight packet"),
        ("TERMINATING to IDLE broadcast", "drive IDLE after bounded drain"),
        ("Full IDLE to IDLE cycle", "drive the five-state sequence with 1 ms gaps"),
        ("RUN_NUMBER increment", "increment RUN_NUMBER before RUN_PREP"),
        ("Local CSR-toggle fallback subset", "toggle SWB-local debug fallback once"),
    ]
    for index, (scenario, stim) in enumerate(base, start=1):
        case_id = f"{prefix}{index:03d}"
        criteria = "all SWB-local consumers observe one coherent state and no consumer backpressures the transition"
        rows.append(row(case_id, "D", f"{bucket_title} RC {scenario}", 1, stim, criteria))
    for index in range(9, 33):
        case_id = f"{prefix}{index:03d}"
        seed = index - 8
        scenario = f"{bucket_title} RC randomized legal state-pair seed {seed}"
        stim = f"runctl sequence randomizes legal state holds and transitions for seed {seed}"
        criteria = "run_window_db records only legal transitions and every local IP shadow state matches"
        rows.append(row(case_id, "R", scenario, 1, stim, criteria))
    return rows


def sc_rows(prefix: str, bucket_title: str) -> list[str]:
    rows: list[str] = []
    named = [
        ("SWB sc_hub_v2 identity read", "host PCIe sc_tool reads the SWB sc_hub identity word"),
        ("rdma_subsystem identity read", "host PCIe sc_tool reads rdma_subsystem identity"),
        ("rdma_dma_engine status read", "host PCIe sc_tool reads DMA engine live status"),
        ("OPQ CSR identity read", "host PCIe sc_tool reads OPQ identity through the JTAG master bridge"),
        ("musip_event_builder status read", "host PCIe sc_tool reads event-builder status"),
        ("swb_data_demerger status read", "host PCIe sc_tool reads demerger status"),
        ("hit_compactor status read", "host PCIe sc_tool reads compactor status"),
        ("SWB-local JTAG fallback read", "local JTAG master reads one debug-only identity word"),
        ("single-word RW round-trip", "write then read one scratch/debug word"),
        ("back-to-back two-slave access", "issue adjacent reads to two different SWB-local slaves"),
    ]
    for offset, (scenario, stim) in enumerate(named, start=33):
        case_id = f"{prefix}{offset:03d}"
        criteria = "transaction completes with expected data, no adjacent slave alias, and no bus error"
        rows.append(row(case_id, "D", f"{bucket_title} SC {scenario}", 1, stim, criteria))
    for offset in range(43, 65):
        case_id = f"{prefix}{offset:03d}"
        seed = offset - 42
        scenario = f"{bucket_title} SC randomized legal slave access seed {seed}"
        stim = f"sc sequence selects one legal SWB-local slave and operation for seed {seed}"
        criteria = "selected operation completes, read data is stable, and timeout counter remains zero"
        rows.append(row(case_id, "R", scenario, 1, stim, criteria))
    return rows


def dt_special(prefix: str, bucket_title: str) -> list[str]:
    if prefix == "B":
        return [
            row(
                "B065",
                "D",
                "SWB one-RQE ingress through OPQ to PCIe DMA egress",
                1,
                "inject one FEB-to-SWB RDMA RQE, one OPQ packet, and one host-DMA beat",
                "scoreboard reconciles one ingress, zero drops, and one PCIe egress event",
                "uvm/swb_rdma_pretest/tb_int_smoke_test.sv",
            ),
            row(
                "B066",
                "D",
                "rdma_subsystem RQ and CQ ring nominal accounting",
                1,
                "drive one legal RQE and observe one CQE completion",
                "RQ consumed count and CQ posted count both advance by one",
            ),
            row(
                "B067",
                "D",
                "OPQ four-lane native_sv single packet on lane 0",
                1,
                "drive one legal lane-0 packet into OPQ ingress",
                "OPQ egress emits the same packet with zero lane drops",
            ),
            row(
                "B068",
                "D",
                "event-builder one host packet pack",
                1,
                "drive one OPQ egress packet into musip_event_builder",
                "one host packet closes with expected byte count",
            ),
        ]
    if prefix == "E":
        return [
            row("E065", "D", "minimum legal RQE packet", 1, "drive smallest legal RQE payload", "egress closes one packet and all counters remain in range"),
            row("E066", "D", "maximum legal RQE packet", 1, "drive maximum legal RQE payload", "packet is split or packed only at legal boundaries"),
            row("E067", "D", "OPQ lane-boundary packet", 1, "drive lane 3 at the frame boundary", "OPQ preserves ordering and reports no late drop"),
            row("E068", "D", "PCIe DMA end-of-event boundary", 1, "drive event ending exactly on one 256-bit beat", "DMA asserts endofevent on the expected beat"),
        ]
    if prefix == "X":
        return [
            row("X065", "D", "malformed RQE is rejected", 1, "drive one RQE with illegal length", "error counter advances and no PCIe DMA beat is emitted"),
            row("X066", "D", "OPQ malformed packet recovery", 1, "drive a packet missing EOP then a legal packet", "legal packet after recovery reaches egress"),
            row("X067", "D", "event-builder timeout recovery", 1, "withhold the closing beat until timeout", "timeout is reported and the next legal packet closes"),
            row("X068", "D", "PCIe DMA backpressure timeout", 1, "hold DMA ready low beyond the programmed budget", "halt counter advances and no data corruption is observed"),
        ]
    return [
        row("P065", "D", "one-second nominal RQE stream", 1, "drive sustained legal RQEs for one stable window", "accepted, dropped, and emitted counts reconcile"),
        row("P066", "D", "OPQ four-lane balanced rate", 1, "drive equal rate on all four OPQ lanes", "egress service share remains balanced"),
        row("P067", "D", "event-builder packing efficiency", 1, "drive repeated medium packets", "host packet fill stays above the configured efficiency floor"),
        row("P068", "D", "PCIe DMA sustained push", 1, "drive continuous legal DMA beats", "DMA queue fill remains bounded and no halt is asserted"),
    ]


DT_AXES = [
    "RQE ingress rate",
    "OPQ lane mix",
    "event-builder packet fill",
    "rdma host DMA burst length",
    "PCIe endpoint ready pattern",
    "compactor occupancy",
    "demerger fanout",
    "mixed FEB source pattern",
]


def dt_rows(prefix: str, bucket_title: str) -> list[str]:
    rows = dt_special(prefix, bucket_title)
    start = 65 + len(rows)
    for offset in range(start, 193):
        case_id = f"{prefix}{offset:03d}"
        seed = offset - start + 1
        axis = DT_AXES[(seed - 1) % len(DT_AXES)]
        method = "R" if seed % 3 else "D/R"
        scenario = f"{bucket_title} DT {axis} sweep seed {seed}"
        stim = f"sequence randomizes {axis.lower()} within the {bucket_title.lower()} bucket legal envelope for seed {seed}"
        criteria = "per-stage ledger reconciles ingress, OPQ egress, event-builder output, and PCIe DMA event counts"
        rows.append(row(case_id, method, scenario, 1, stim, criteria))
    return rows


def emit_bucket(filename: str, cfg: dict[str, object]) -> str:
    prefix = str(cfg["prefix"])
    title = str(cfg["title"])
    implemented = int(cfg["implemented"])
    rc = rc_rows(prefix, title)
    sc = sc_rows(prefix, title)
    dt = dt_rows(prefix, title)
    assert len(rc) == 32
    assert len(sc) == 32
    assert len(dt) == 128
    lines: list[str] = [
        f"# {filename} - tb_int {title} bucket",
        "",
        "**Companion docs:** [DV_INT_PLAN.md](DV_INT_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), [DV_ERROR.md](DV_ERROR.md), [DV_PROF.md](DV_PROF.md), [BUG_HISTORY.md](BUG_HISTORY.md)",
        "**Parent:** DV_INT_PLAN.md",
        f"**ID Range:** {prefix}001-{prefix}192",
        f"**Total:** 192 cases ({implemented} implemented / 0 waived)",
        "",
        "**Methodology key:**",
        "- **D** directed - single deterministic stimulus with a golden expectation.",
        "- **R** constrained-random - UVM sequence randomizes the named axis and the scoreboard checks count parity.",
        "",
        f"This file is the {title} bucket for {cfg['summary']} in the SWB rdma_pretest-260511 integration build.",
        "",
        "## 1. Summary",
        "",
        "| Section | Cases | ID Range | What it Proves | Current Case |",
        "|---|---:|---|---|---|",
        f"| RC | 32 | {prefix}001-{prefix}032 | {cfg['rc']} reaches SWB-local consumers without backpressure | 0/32 |",
        f"| SC | 32 | {prefix}033-{prefix}064 | {cfg['sc']} reaches SWB-local CSR and debug fallback paths | 0/32 |",
        f"| DT | 128 | {prefix}065-{prefix}192 | {cfg['dt']} is reconciled by the per-stage ledger scoreboard | {implemented}/128 |",
        "",
        "## 2. RC",
        "",
        "| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |",
        "|---|---|---|---:|---|---|---|",
        *rc,
        "",
        "## 3. SC",
        "",
        "| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |",
        "|---|---|---|---:|---|---|---|",
        *sc,
        "",
        "## 4. DT",
        "",
        "| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |",
        "|---|---|---|---:|---|---|---|",
        *dt,
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    DOC.mkdir(parents=True, exist_ok=True)
    for filename, cfg in BUCKETS.items():
        (DOC / filename).write_text(emit_bucket(filename, cfg), encoding="ascii")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

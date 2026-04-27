#!/usr/bin/env python3
from __future__ import annotations

import csv
import math
import random
from collections import deque
from dataclasses import dataclass
from pathlib import Path


CLK_MHZ = 156.25
MUTRIG_MAX_MHIT = 25.0
N_MUTRIG = 8
HIST_PHYSICAL_CAP_MHIT = MUTRIG_MAX_MHIT * N_MUTRIG
HIST_DRAIN_CYCLES = 2
HIST_ELEMENT_SERVICE_MHZ = CLK_MHZ / HIST_DRAIN_CYCLES
N_BINS = 256
KICK_MAX = 255
SIM_CYCLES = 100_000

RATES_MHIT = [25.0, 50.0, 75.0, 100.0, 125.0, 150.0, 175.0, 200.0, 225.0]
DEPTHS = [1, 2, 4, 8, 16, 32, 64, 96, 128, 160, 192, 224, 240, 244, 248, 252, 254, 256]
THRESHOLDS = [5.0e-2, 1.0e-2, 1.0e-6]
MODES = [
    "iid_256",
    "cluster8_local",
    "cluster8_roaming",
    "mix50_iid_cluster8",
    "injection_all256",
]


@dataclass(frozen=True)
class QueueStats:
    mode: str
    rate_mhit: float
    depth: int
    offered_hits: int
    accepted_hits: int
    dropped_hits: int
    pending_hits: int
    drain_events: int
    occupancy_max: int
    occupancy_end: int

    @property
    def drop_probability(self) -> float:
        if self.offered_hits == 0:
            return 0.0
        return self.dropped_hits / self.offered_hits

    @property
    def coalesced_hits_per_element(self) -> float:
        elements = self.drain_events + self.occupancy_end
        if elements == 0:
            return 0.0
        return (self.accepted_hits + self.pending_hits) / elements


def fixed_seed(mode: str, rate_mhit: float) -> int:
    seed = 0x4D553345 ^ int(round(rate_mhit * 1000.0))
    for ch in mode.encode("ascii"):
        seed = ((seed << 5) ^ (seed >> 2) ^ ch) & 0xFFFFFFFF
    return seed or 1


def burst_tags(start: int, width: int) -> list[int]:
    return [(start + idx) % N_BINS for idx in range(width)]


def arrivals_for_cycle(
    mode: str,
    rate_mhit: float,
    rng: random.Random,
    acc: dict[str, float],
) -> list[int]:
    tags: list[int] = []
    if mode == "iid_256":
        acc["iid"] += rate_mhit / CLK_MHZ
        while acc["iid"] >= 1.0:
            tags.append(rng.randrange(N_BINS))
            acc["iid"] -= 1.0
    elif mode == "cluster8_local":
        acc["cluster"] += (rate_mhit / 8.0) / CLK_MHZ
        while acc["cluster"] >= 1.0:
            tags.extend(burst_tags(64, 8))
            acc["cluster"] -= 1.0
    elif mode == "cluster8_roaming":
        acc["cluster"] += (rate_mhit / 8.0) / CLK_MHZ
        while acc["cluster"] >= 1.0:
            tags.extend(burst_tags(rng.randrange(N_BINS), 8))
            acc["cluster"] -= 1.0
    elif mode == "mix50_iid_cluster8":
        acc["iid"] += (rate_mhit * 0.5) / CLK_MHZ
        while acc["iid"] >= 1.0:
            tags.append(rng.randrange(N_BINS))
            acc["iid"] -= 1.0
        acc["cluster"] += ((rate_mhit * 0.5) / 8.0) / CLK_MHZ
        while acc["cluster"] >= 1.0:
            tags.extend(burst_tags(rng.randrange(N_BINS), 8))
            acc["cluster"] -= 1.0
    elif mode == "injection_all256":
        acc["all"] += (rate_mhit / N_BINS) / CLK_MHZ
        while acc["all"] >= 1.0:
            tags.extend(range(N_BINS))
            acc["all"] -= 1.0
    else:
        raise ValueError(f"unknown mode {mode}")
    return tags


def simulate_queue(mode: str, rate_mhit: float, depth: int) -> QueueStats:
    rng = random.Random(fixed_seed(mode, rate_mhit))
    queue: deque[int] = deque()
    queued = [False] * N_BINS
    kicks = [0] * N_BINS
    acc = {"iid": 0.0, "cluster": 0.0, "all": 0.0}
    offered = 0
    accepted = 0
    dropped = 0
    drain_events = 0
    occupancy_max = 0

    for cycle in range(SIM_CYCLES):
        if cycle % HIST_DRAIN_CYCLES == 0 and queue:
            tag = queue.popleft()
            accepted += kicks[tag]
            drain_events += 1
            kicks[tag] = 0
            queued[tag] = False

        for tag in arrivals_for_cycle(mode, rate_mhit, rng, acc):
            offered += 1
            if queued[tag]:
                if kicks[tag] < KICK_MAX:
                    kicks[tag] += 1
                else:
                    dropped += 1
            elif len(queue) < depth:
                queue.append(tag)
                queued[tag] = True
                kicks[tag] = 1
            else:
                dropped += 1

        if len(queue) > occupancy_max:
            occupancy_max = len(queue)

    pending = sum(kicks)
    return QueueStats(
        mode=mode,
        rate_mhit=rate_mhit,
        depth=depth,
        offered_hits=offered,
        accepted_hits=accepted,
        dropped_hits=dropped,
        pending_hits=pending,
        drain_events=drain_events,
        occupancy_max=occupancy_max,
        occupancy_end=len(queue),
    )


def active_bins(mode: str) -> int:
    if mode == "cluster8_local":
        return 8
    return N_BINS


def burst_width(mode: str) -> int:
    if mode == "iid_256":
        return 1
    if mode in ("cluster8_local", "cluster8_roaming", "mix50_iid_cluster8"):
        return 8
    if mode == "injection_all256":
        return N_BINS
    raise ValueError(f"unknown mode {mode}")


def analytical_required_depth(mode: str, rate_mhit: float, threshold: float) -> int:
    if rate_mhit <= HIST_ELEMENT_SERVICE_MHZ:
        return burst_width(mode)
    support = active_bins(mode)
    depth = math.ceil(support * (1.0 - threshold))
    return max(burst_width(mode), min(N_BINS, depth))


def write_physical_limits(out_dir: Path) -> None:
    rows = [
        ("mutrig_wire_limit", MUTRIG_MAX_MHIT, "25 Mhit/s per MuTRiG physical wire-speed cap"),
        ("datapath_4_mutrig_limit", 4.0 * MUTRIG_MAX_MHIT, "25 Mhit/s * 4 MuTRiG per datapath"),
        ("histogram_8_mutrig_limit", HIST_PHYSICAL_CAP_MHIT, "25 Mhit/s * 8 MuTRiG feeding histogram"),
        ("hist_queue_element_service", HIST_ELEMENT_SERVICE_MHZ, "156.25 MHz / 2 cycles per bin update"),
        (
            "coalesce_factor_at_hist_cap",
            HIST_PHYSICAL_CAP_MHIT / HIST_ELEMENT_SERVICE_MHZ,
            "hit rate / queue-element service at 200 Mhit/s",
        ),
    ]
    with (out_dir / "phase4_physical_rate_limits.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(["quantity", "value", "definition"])
        writer.writerows(rows)


def write_queue_sweep(out_dir: Path) -> list[QueueStats]:
    stats: list[QueueStats] = []
    for mode in MODES:
        for rate_mhit in RATES_MHIT:
            for depth in DEPTHS:
                stats.append(simulate_queue(mode, rate_mhit, depth))

    with (out_dir / "phase4_queue_sweep.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "mode",
                "rate_mhit",
                "depth",
                "offered_hits",
                "accepted_hits",
                "pending_hits",
                "dropped_hits",
                "drop_probability",
                "drain_events",
                "occupancy_max",
                "occupancy_end",
                "coalesced_hits_per_element",
            ],
            lineterminator="\n",
        )
        writer.writeheader()
        for s in stats:
            writer.writerow(
                {
                    "mode": s.mode,
                    "rate_mhit": f"{s.rate_mhit:.3f}",
                    "depth": s.depth,
                    "offered_hits": s.offered_hits,
                    "accepted_hits": s.accepted_hits,
                    "pending_hits": s.pending_hits,
                    "dropped_hits": s.dropped_hits,
                    "drop_probability": f"{s.drop_probability:.9g}",
                    "drain_events": s.drain_events,
                    "occupancy_max": s.occupancy_max,
                    "occupancy_end": s.occupancy_end,
                    "coalesced_hits_per_element": f"{s.coalesced_hits_per_element:.6f}",
                }
            )
    return stats


def write_queue_regions(out_dir: Path, stats: list[QueueStats]) -> None:
    by_key = {(s.mode, s.rate_mhit, s.depth): s for s in stats}
    with (out_dir / "phase4_queue_depth_regions.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "mode",
                "rate_mhit",
                "threshold",
                "min_depth_sim",
                "analytical_depth",
                "required_depth",
                "drop_probability_at_required",
            ],
            lineterminator="\n",
        )
        writer.writeheader()
        for mode in MODES:
            for rate_mhit in RATES_MHIT:
                for threshold in THRESHOLDS:
                    min_sim: int | None = None
                    for depth in DEPTHS:
                        if by_key[(mode, rate_mhit, depth)].drop_probability <= threshold:
                            min_sim = depth
                            break
                    analytical = analytical_required_depth(mode, rate_mhit, threshold)
                    required = max(analytical, min_sim if min_sim is not None else analytical)
                    required = min(N_BINS, required)
                    sim_at_required = by_key.get((mode, rate_mhit, required))
                    drop_at_required = "" if sim_at_required is None else f"{sim_at_required.drop_probability:.9g}"
                    writer.writerow(
                        {
                            "mode": mode,
                            "rate_mhit": f"{rate_mhit:.3f}",
                            "threshold": f"{threshold:.6g}",
                            "min_depth_sim": "" if min_sim is None else min_sim,
                            "analytical_depth": analytical,
                            "required_depth": required,
                            "drop_probability_at_required": drop_at_required,
                        }
                    )


def write_mutrig_latency_model(out_dir: Path) -> None:
    frame_modes = [("short", 910), ("long", 1550)]
    rates = [1.0, 10.0, 20.0, 25.0, 30.0]
    fixed_pipe_cycles = 8.0
    with (out_dir / "phase4_mutrig_latency_model.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "frame_mode",
                "frame_cycles",
                "rate_mhit_per_mutrig",
                "clipped_to_physical_limit",
                "offset_cycles",
                "offset_frame",
                "wait_to_next_frame_cycles",
                "latency_min_cycles",
                "latency_p50_cycles",
                "latency_max_cycles",
                "latency_max_frames",
            ],
            lineterminator="\n",
        )
        writer.writeheader()
        for frame_mode, frame_cycles in frame_modes:
            for rate in rates:
                rho = min(rate, MUTRIG_MAX_MHIT) / MUTRIG_MAX_MHIT
                clipped = int(rate > MUTRIG_MAX_MHIT)
                for step in range(65):
                    offset = int(round(step * frame_cycles / 64.0))
                    if offset > frame_cycles:
                        offset = frame_cycles
                    wait = frame_cycles - offset
                    latency_min = fixed_pipe_cycles + wait
                    latency_p50 = fixed_pipe_cycles + wait * (1.0 + 0.5 * rho)
                    latency_max = fixed_pipe_cycles + wait * (1.0 + rho)
                    writer.writerow(
                        {
                            "frame_mode": frame_mode,
                            "frame_cycles": frame_cycles,
                            "rate_mhit_per_mutrig": f"{rate:.3f}",
                            "clipped_to_physical_limit": clipped,
                            "offset_cycles": offset,
                            "offset_frame": f"{offset / frame_cycles:.6f}",
                            "wait_to_next_frame_cycles": f"{wait:.3f}",
                            "latency_min_cycles": f"{latency_min:.3f}",
                            "latency_p50_cycles": f"{latency_p50:.3f}",
                            "latency_max_cycles": f"{latency_max:.3f}",
                            "latency_max_frames": f"{latency_max / frame_cycles:.6f}",
                        }
                    )


def main() -> int:
    out_dir = Path(__file__).resolve().parents[1] / "artifacts"
    out_dir.mkdir(parents=True, exist_ok=True)
    write_physical_limits(out_dir)
    stats = write_queue_sweep(out_dir)
    write_queue_regions(out_dir, stats)
    write_mutrig_latency_model(out_dir)
    print(f"Wrote {out_dir / 'phase4_physical_rate_limits.csv'}")
    print(f"Wrote {out_dir / 'phase4_queue_sweep.csv'}")
    print(f"Wrote {out_dir / 'phase4_queue_depth_regions.csv'}")
    print(f"Wrote {out_dir / 'phase4_mutrig_latency_model.csv'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

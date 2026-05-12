#!/usr/bin/env python3
"""Per-checkpoint RN.BASIC delay bounds.

The bounds are expressed in 8 ns cycles.  The fixed front-end values come from
the RN.BASIC per-checkpoint review:

* D_pre = wait_910(hit_ts) + s(q) + 18
* D_post = (GTS_post - ts_hit) mod 8192
* D_feb <= 2F - p + 20 + eps_clk
* D_ing = D_feb + adapter_sync
* D_opq = D_ing + W_n, W_n=max(0, W_{n-1}+S_n-A_n)
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping


CHECKPOINT_ORDER = (
    "pre_rbcam",
    "post_rbcam",
    "feb_egress",
    "opq_ingress",
    "opq_egress",
)

CHECKPOINT_LABELS = {
    "pre_rbcam": "pre-rbCAM",
    "post_rbcam": "post-rbCAM",
    "feb_egress": "FEB egress",
    "opq_ingress": "OPQ ingress",
    "opq_egress": "OPQ egress",
}

HEADER_SYNC_PHASE_8NS = 100
HEADER_SYNC_ASIC_STAGGER_8NS = 16
VIRTUAL_MUTRIG_SHORT_FRAME_CYCLES = 910
ACTIVE_ASICS_ALL_CHANNEL = 8
CHANNELS_PER_ASIC = 32


PER_CHECKPOINT_BOUNDS: dict[str, dict[str, tuple[float, float]]] = {
    "header_sync": {
        "pre_rbcam": (0.0, 2000.0),
        "post_rbcam": (2000.0, 2200.0),
        "feb_egress": (2049.0, 6143.0),
        "opq_ingress": (2049.0, 6159.0),
        "opq_egress": (4356.0, 99133.5),
    },
    # Periodic and emulator-only rows use the same FEB/rbCAM timing envelope as
    # header-sync.  Their OPQ bound is wider because row rate, lane mask, and
    # iid inter-arrival jitter control W_n rather than the fixed header phase.
    "periodic": {
        "pre_rbcam": (0.0, 2000.0),
        "post_rbcam": (2000.0, 2200.0),
        "feb_egress": (2049.0, 6143.0),
        "opq_ingress": (2049.0, 6159.0),
        "opq_egress": (0.0, 262144.0),
    },
    "emul_only": {
        "pre_rbcam": (0.0, 2000.0),
        "post_rbcam": (2000.0, 2200.0),
        "feb_egress": (2049.0, 6143.0),
        "opq_ingress": (2049.0, 6159.0),
        "opq_egress": (0.0, 262144.0),
    },
    "onclick": {
        "pre_rbcam": (0.0, 2000.0),
        "post_rbcam": (2000.0, 2200.0),
        "feb_egress": (2049.0, 6143.0),
        "opq_ingress": (2049.0, 6159.0),
        "opq_egress": (0.0, 32768.0 + 6159.0),
    },
}


MODE_ALIASES = {
    "headersync": "header_sync",
    "header-sync": "header_sync",
    "header_sync": "header_sync",
    "periodic": "periodic",
    "emul-only": "emul_only",
    "emul_only": "emul_only",
    "poisson": "emul_only",
    "poisson_iid": "emul_only",
    "onclick": "onclick",
}


@dataclass(frozen=True)
class BoundDecision:
    mode: str | None
    bounds: dict[str, tuple[float, float]]
    skip_reason: str = ""


def normalize_mode(mode: str | None) -> str | None:
    if mode is None:
        return None
    return MODE_ALIASES.get(mode.strip().lower().replace(" ", "_"))


def bounds_for_mode(mode: str | None) -> BoundDecision:
    normalized = normalize_mode(mode)
    if normalized is None:
        return BoundDecision(None, {}, f"unsupported injector mode {mode!r}")
    bounds = PER_CHECKPOINT_BOUNDS.get(normalized)
    if bounds is None:
        return BoundDecision(normalized, {}, f"no per-checkpoint bounds for {normalized}")
    return BoundDecision(normalized, dict(bounds))


def bounds_for_row(row: Mapping[str, object]) -> BoundDecision:
    name = row.get("injector_name")
    if name is None:
        mode_id = row.get("injector_mode")
        mode_by_id = {0: "emul_only", 1: "header_sync", 2: "periodic", 4: "onclick"}
        try:
            name = mode_by_id.get(int(mode_id))  # type: ignore[arg-type]
        except (TypeError, ValueError):
            name = None
    decision = bounds_for_mode(None if name is None else str(name))
    if decision.mode == "header_sync" and decision.bounds:
        return BoundDecision(decision.mode, header_sync_row_bounds(row, decision.bounds))
    return decision


def popcount_field(row: Mapping[str, object], count_key: str, mask_key: str, width: int) -> int:
    value = row.get(count_key)
    try:
        count = int(str(value), 0)
        if 0 < count <= width:
            return count
    except (TypeError, ValueError):
        pass
    try:
        mask = int(str(row.get(mask_key, 0)), 0)
    except (TypeError, ValueError):
        return width
    return max(1, min(width, mask.bit_count()))


def header_sync_row_bounds(
    row: Mapping[str, object],
    base: Mapping[str, tuple[float, float]],
) -> dict[str, tuple[float, float]]:
    bounds = dict(base)
    lower, upper = bounds["opq_egress"]
    lane_count = popcount_field(row, "lane_popcount", "lane_mask", ACTIVE_ASICS_ALL_CHANNEL)
    channel_count = popcount_field(row, "channel_popcount", "channel_mask", CHANNELS_PER_ASIC)

    # The published 4356-cycle OPQ lower edge is the all-ASIC/all-channel
    # header-sync anchor.  Sparse rows can select an earlier valid header slot,
    # so derive a conservative lower edge from the 16-cycle selected-slot
    # spacing and one ASIC-group guard instead of applying the dense-row edge.
    selected_slot_relief = HEADER_SYNC_ASIC_STAGGER_8NS * max(0, CHANNELS_PER_ASIC - channel_count)
    asic_group_relief = 64.0 if lane_count < ACTIVE_ASICS_ALL_CHANNEL else 0.0
    bounds["opq_egress"] = (max(0.0, lower - selected_slot_relief - asic_group_relief), upper)
    return bounds


def framing_formula(mode: str | None) -> str:
    normalized = normalize_mode(mode) or str(mode or "unknown")
    if normalized == "header_sync":
        return (
            "D_i=(T_i-GTS_hit)/8 ns; "
            f"alpha_h(t)=256*(floor(t/{VIRTUAL_MUTRIG_SHORT_FRAME_CYCLES})+1), "
            f"phase={HEADER_SYNC_PHASE_8NS}, stagger={HEADER_SYNC_ASIC_STAGGER_8NS}"
        )
    if normalized == "emul_only":
        return "D_i=(T_i-GTS_hit)/8 ns; alpha_iid(t) from Poisson emulator source"
    if normalized == "onclick":
        return "D_i=(T_i-GTS_hit)/8 ns; alpha_onclick(t) from commanded pulse count"
    return "D_i=(T_i-GTS_hit)/8 ns; alpha_periodic(t)=N*(floor(t/period)+1)"

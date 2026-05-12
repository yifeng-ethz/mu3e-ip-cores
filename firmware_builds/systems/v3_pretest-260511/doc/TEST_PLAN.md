# TEST_PLAN.md - FEB SciFi v3 on-board test plan (entry point)

**Revision:** 2026-05-12 / draft-4 (split into per-bucket files)
**Target:** `mu3e-ip-cores/firmware_builds/systems/v3_pretest-260511*`
**Host:** `yifeng@teferi`, `/dev/mudaq0` via SWB on link 2

This file is the **entry point** for FEB SciFi v3 on-board test plans. Each
bucket has its own file under `doc/`:

| Bucket | File | Cases | Methodology | Bucket Purpose |
|---|---|---:|---|---|
| **BU** Bring-up | [TEST_BU.md](TEST_BU.md) | 25 | B | cold read of every CSR / UID / META; no stimulus |
| **BASIC** | [TEST_BASIC.md](TEST_BASIC.md) | 159 | D + R | happy-path SC + RC + RN data flow at below-saturation rates |
| **PERF** | [TEST_PERF.md](TEST_PERF.md) | 15 | P + D | SC aggressive reads under RUNNING; RN saturation curve; long-soak |
| **ERROR** | [TEST_ERROR.md](TEST_ERROR.md) | 12 | E | illegal opcode sequences; invalid CSR values; reject-or-error |
| **EDGE** | [TEST_EDGE.md](TEST_EDGE.md) | 6 | D | corner masks; single-channel; SC + RUNNING concurrency |

**Total: 217 cases** across 5 bucket files.

**Companion docs:**
[SIM_CONVENTIONS.md](SIM_CONVENTIONS.md),
[tb_int/doc/DV_PLAN.md](../tb_int/doc/DV_PLAN.md),
[tb_int/doc/DV_BASIC.md](../tb_int/doc/DV_BASIC.md),
[tb_int/doc/DV_EDGE.md](../tb_int/doc/DV_EDGE.md),
[tb_int/doc/DV_ERROR.md](../tb_int/doc/DV_ERROR.md),
[tb_int/doc/DV_PROF.md](../tb_int/doc/DV_PROF.md),
[../tb_int/doc/BUG_HISTORY.md](../tb_int/doc/BUG_HISTORY.md)

---

## Case ID scheme

| Prefix | Meaning | Files |
|---|---|---|
| **BU** | Bring-up - cold read; no stimulus | TEST_BU.md |
| **SC** | Slow control - BIST writes / aggressive reads | TEST_BASIC.md (SC.BASIC) + TEST_PERF.md (SC.AG) |
| **RC** | Run control - opcode sequences | TEST_BASIC.md (RC.BASIC) + TEST_ERROR.md (RC.ERROR) |
| **RN** | Run datapath - emulator -> hist -> OPQ -> RDMA | TEST_BASIC.md (RN.BASIC) + TEST_PERF.md (RN.PROF) + TEST_ERROR.md (RN.ERROR) + TEST_EDGE.md (RN.EDGE) |
| **RN.COSIM** | End-to-end FEB+SWB cosim | TEST_BASIC.md (sanity) + TEST_PERF.md (long-soak) |

## Methodology key

- **B** (bring-up): non-destructive read or identity probe; no stimulus.
- **D** (directed): single deterministic stimulus with a golden expectation.
- **R** (constrained-random): UVM/Python sweep randomises a named axis;
  scoreboard checks count parity or shape.
- **P** (perf): performance / saturation; uses theoretical-delta accounting.
- **E** (error-injection): drive an illegal opcode order or out-of-bound CSR
  value; scoreboard asserts the IP rejects gracefully.

## Bucket key

- **BU**: read-only identity / metadata probe of every IP. Must pass before any
  later bucket is trusted.
- **BASIC**: aggregate hit rate < 50% of OPQ ingress ceiling. Theoretical-delta
  < 5% on both sim and board.
- **PERF**: aggregate rate at or above the ceiling. Saturation curve measured;
  loss expected to match clipped theoretical_hits. Also includes SC reads
  during RUNNING (aggressive) and long-soak (>= 10 s).
- **ERROR**: stimulus deliberately violates the IP contract. IP must reject
  gracefully without corrupting valid state.
- **EDGE**: corner cases of the legal contract (boundary masks, single-channel
  / single-lane, simultaneous SC + RUNNING).

## 3-evidence model

Every RN row PASSes only if all THREE evidence streams agree within tolerance:

| Evidence | Source | Window | Purpose |
|---|---|---|---|
| **E1** post-TERM CSR snapshot | SC reads of all counters AFTER `STATUS=IDLE` post-`0x13` | end-of-run, single point | authoritative final count |
| **E2** hist during-running readout | `hist_bin[0..255]` in BOTH `INTERVAL_CFG_NEVER_FIRE` mode AND `INTERVAL_CFG = 1 ms` mode | during RUNNING + at end | per-channel + per-interval shape |
| **E3** offline RDMA dump | SWB RDMA host-memory dump after END_RUN; per-FEB ring of hit-records | post-run, off-line replay | end-to-end transit confirmation |

For BASIC: E1, E2 sum-of-bins, and E3 record-count all agree with
`theoretical_hits` within `|delta| < 5%`.
For PERF: E1, E2, E3 agree with each other; collectively may sit below
`theoretical_hits` by the saturation delta.
For ERROR: E1 shows the rejection footprint; E2 and E3 may be empty.
For EDGE: same as BASIC unless row note declares otherwise.

## SIM time conventions

All UVM directed simulation sequences use a fixed RUNNING stage duration of
**1 ms** unless the sequence name and report explicitly declare a long-soak
exception. At `lvdspll_clk = 125 MHz` the timebase is 8 ns / tick, so
`RUN_WINDOW_8NS = 125000`. PREPARE, SYNC, and TERMINATE may take whatever
time the harness needs; they are not part of the comparison window. Long-soak
runs (10 s+) declare their nonstandard duration in sequence / test name and
in the row note. See `SIM_CONVENTIONS.md`.

## Theoretical-delta model

```
active_channels = popcount(channel_mask) * popcount(lane_mask)
per_channel_rate_hps = rate_88fp / 256 * (125e6 / 256)
requested_hits = per_channel_rate_hps * active_channels * run_window_s
theoretical_hits = min(requested_hits, opq_ceiling_hps * run_window_s)
sim_delta_pct   = (sim_total_hits   - theoretical_hits) / theoretical_hits * 100
board_delta_pct = (board_total_hits - theoretical_hits) / theoretical_hits * 100
```

`opq_ceiling_hps = 250e6` (user spec; codex confirmation in flight).

---

## Source of truth

| Board | SOF | Repo |
|---|---|---|
| SWB (A10 DE5, link 2) | `online_sc/online/switching_pc/a10_board/output_files/top.sof` | `online_sc` |
| FEB SciFi v3 | `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-arbfix-260512/syn/.../top.sof` | `mu3e-ip-cores` (latest arbfix build) |

`sc_hub v2` is **word-addressed** (`byte_addr / 4`).

## Pre-flight checklist

1. `jtagconfig -n` shows `DE5 [3-6.2]` + `USB-BlasterII [7-2]`.
2. Flash SWB with `online_sc` SOF (only if cold).
3. Flash FEB v3 with `tools/run_script/program_feb.sh <feb_sof>` (enforces 20 s settle).
4. `sudo -n /usr/local/sbin/mudaq_recover_pcie`.
5. `lsmod | grep mudaq && ls /dev/mudaq0`.
6. `tools/run_script/build_local_tools.py` refreshes local `sc_tool` / `rc_tool`.
7. `swb_ring_lock sc_tool 2 read 0x00000` returns valid 32-bit reply.
8. `tools/run_script/check_ip_metadata.py` clean.

---

## Summary across all buckets

| Bucket | Cases | Status | Headline metric |
|---|---:|---|---|
| BU | 25 | PASS | 24/24 verified UID + META cross-checks |
| SC.BASIC (in TEST_BASIC.md) | 12 | PASS | scratchpad BIST + per-IP SCRATCH RW |
| SC.AG (in TEST_PERF.md) | 8 | partial | BUG-006-S burst-read corruption documented |
| RC.BASIC (in TEST_BASIC.md) | 11 | PASS on-board | SC-WEDGE on-board verified post-`abb3e455` |
| RC.ERROR (in TEST_ERROR.md) | 6 | tb_int harness ready; selective board run pending | |
| RN.BASIC (in TEST_BASIC.md) | 128 | sim 32/32 PASS (10 ms); board pending arbfix retest | 8 x 4 x 4 matrix |
| RN.PROF (in TEST_PERF.md) | 6 | partial; saturation knee at `0x4000` observed | OPQ ingress ceiling probe |
| RN.ERROR (in TEST_ERROR.md) | 6 | pending | invalid configs during run |
| RN.EDGE (in TEST_EDGE.md) | 6 | RN.EDGE.002 sim-vs-board inversion pending arbfix retest | corner masks |
| RN.COSIM.001 (in TEST_BASIC.md) | 1 | infrastructure done; lossless at 1 ms below ceiling | 6 checkpoints |
| RN.COSIM.002 (in TEST_PERF.md) | 1 | pending | 10 s long-soak |

**Total: 217 cases.** PASS count is currently dominated by BU+SC.BASIC+RC.BASIC + sim RN.BASIC; the remaining gates close as the in-flight arbfix retest + cosim + BASIC/PERF codex dispatches return.

---

## Evidence trail (verdict references)

Key per-bucket evidence commits (see individual bucket files for per-row details):

| Bucket | Verdict | Key commits |
|---|---|---|
| BU | PASS | `5bd7e112`, `42222454` |
| SC.BASIC | PASS | legacy `run_atpg_v2_reference.sh` evidence |
| SC.AG | BUG-006-S documented (burst hist_bin reads corrupt SC bridge) | `a710b11a` (single-word workaround) |
| RC.BASIC | PASS on-board | `5bd7e112` (SC-WEDGE on-board), `abb3e455` (arb MODE-clear) |
| RC.ERROR | pending | tb_int |
| RN.BASIC | sim 32/32 PASS; board 25/32 on dualport pre-arbfix | `967845b5`, `47efa242`, arbfix retest in flight |
| RN.PROF | partial | `47efa242` |
| RN.ERROR | pending | tb_int |
| RN.EDGE | RN.EDGE.002 inversion pending arbfix | `47efa242`, arbfix retest |
| RN.COSIM | sanity done; long-soak pending | cosim 1 ms re-run in flight |

Per-row board evidence:
`firmware_builds/systems/v3_pretest-260511-emutype0-dualport*/sweep_evidence/<row_id>/`

Per-row sim evidence:
`firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/sim_evidence/<row_id>/`

HTML cross-validation report (rate-normalized + theoretical-delta):
`firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/doc/PHASE4_5_SWEEP_REPORT.html`

Bug ledger:
`firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/doc/BUG_HISTORY.md`

---

## Open items

- **OPQ aggregate ingress ceiling**: user-stated 250 MHz; exact RTL confirmation pending (codex1 BASIC/PERF dispatch in flight). Once confirmed, RN.BASIC threshold of < 50% ceiling and RN.PROF curve cross-check the value.
- **RN.BASIC matrix population**: 128-row enumeration lives in `scripts/cotest/phase4_5_sweep.py:rn_basic_plan()` (BASIC/PERF codex in flight expands today's 32 rows to 128).
- **RC.ERROR closure**: harness exists at `tb_int/feb_swb_corun`. Each ERROR row may leave the FSM in a non-IDLE state; sequencing requires explicit recovery between rows.
- **E3 offline RDMA dump**: not yet wired end-to-end. Current evidence covers E1 + E2. E3 requires a SWB host-memory dump tool.
- **Long-soak 10 s**: RN.COSIM.002 needs explicit `long_soak` flag and ~30-60 min sim wall time.

---

## Revision history

- **2026-05-12 draft-4** (this revision): split per-bucket; TEST_PLAN.md is the central entry point pointing at TEST_BU.md, TEST_BASIC.md, TEST_PERF.md, TEST_ERROR.md, TEST_EDGE.md.
- **2026-05-12 draft-3**: single-file BU/SC/RC/RN scheme with 3-evidence model; 232 cases; introduced bucket prefixes.
- **2026-05-12 draft-2**: first DV-plan uniform-row rewrite with TP001-TP299; 132 cases; 9 sections.
- **2026-05-12 draft-1**: long-form narrative with per-phase evidence sections 4.7..4.16; deprecated.

# TEST_PLAN.md - FEB SciFi v3 on-board test plan (entry point)

**Revision:** 2026-05-12 / draft-4 (split into per-bucket files)
**Target:** `mu3e-ip-cores/firmware_builds/systems/v3_pretest-260511*`
**Host:** `yifeng@teferi`, `/dev/mudaq0` via SWB on link 2

This file is the **entry point** for FEB SciFi v3 on-board test plans. Each
bucket has its own file under `doc/`:

| Bucket | File | Cases | Methodology | Bucket Purpose |
|---|---|---:|---|---|
| **BU** Bring-up | [TEST_BU.md](TEST_BU.md) | 25 | B | cold read of every CSR / UID / META; no stimulus |
| **BASIC** | [TEST_BASIC.md](TEST_BASIC.md) | 151 | D + R | happy-path SC + RC + RN data flow at below-saturation rates |
| **PERF** | [TEST_PERF.md](TEST_PERF.md) | 15 | P + D | SC aggressive reads under RUNNING; RN saturation curve; long-soak (waived from cosim) |
| **ERROR** | [TEST_ERROR.md](TEST_ERROR.md) | 12 | E | illegal opcode sequences; invalid CSR values; reject-or-error |
| **EDGE** | [TEST_EDGE.md](TEST_EDGE.md) | 8 | D | corner masks; single-channel; SC + RUNNING concurrency; headersync + periodic injector-mode coverage |

**Total: 211 cases** across 5 bucket files. Every row (except long-soak waivers)
runs in BOTH cosim AND on-board, with theory/sim/board cross-validation.

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

**Note:** there is no separate `RN.COSIM` bucket. The cosim is the **sim
evidence stream** for every RN row; see the 3-evidence model below.

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
- **BASIC**: aggregate hit rate < 50% of OPQ ingress ceiling. Sim and board
  both compare directly against `theoretical_hits` and should be lossless
  within tolerance.
- **PERF**: aggregate rate at or above 50% of the OPQ ceiling, including rows
  above the ceiling. Saturation curve rows are measured against clipped
  `theoretical_hits`; loss beyond that curve appears as a negative theory
  delta. Also includes SC reads during RUNNING (aggressive) and long-soak
  (>= 10 s).
- **ERROR**: stimulus deliberately violates the IP contract. IP must reject
  gracefully without corrupting valid state.
- **EDGE**: corner cases of the legal contract (boundary masks, single-channel
  / single-lane, simultaneous SC + RUNNING).

## 3-evidence model (theory / sim / board)

Every row in every bucket (BASIC, PERF, ERROR, EDGE) has THREE evidence
streams that MUST agree with each other:

| Evidence | Source | Notes |
|---|---|---|
| **theory** | mathematical reference from the math codex (`theoretical_hits` from the model above) | golden reference; lossless or saturation-clipped |
| **sim** | dual-UVM FEB <-> SWB cosim run for the same row | full DUT in `cosim/`; not a behavioural model |
| **board** | on-board sweep on the latest arbfix FEB SOF | `phase4_5_sweep.py --row <row_id>` |

**PASS criterion for every row** = all three measurements agree within
tolerance. There is no separate "cosim sanity" bucket - cosim IS the sim
evidence column for every row.

| Bucket | Tolerance |
|---|---|
| BASIC | `|theory - sim| < 5%` AND `|theory - board| < 5%` |
| PERF | both deltas measured against the clipped theoretical curve; the row PASSes if `(sim_delta, board_delta)` both fall on the saturation curve within ~10% noise |
| ERROR | sim and board both report the rejection footprint; theory is the contract assertion (error counter set / no corruption) |
| EDGE | same as BASIC unless noted |

**Waivers:** long-soak rows (RUNNING >= 10 s) are waived from the cosim
evidence requirement because the sim wall time would be prohibitive. These
rows declare `cosim_waived = true` in the row note and rely on theory + board
only.

### Per-row sub-evidence (collected from each stream)

Inside each of `sim` and `board`, three sub-measurements are recorded for
cross-validation:

| Sub-evidence | Source | Window |
|---|---|---|
| post-TERM CSR snapshot | counters read AFTER `STATUS=IDLE` post-`0x13` | end-of-run, single point |
| hist during-running readout | `hist_bin[0..255]` in `INTERVAL_CFG_NEVER_FIRE` mode + `INTERVAL_CFG = 1 ms` periodic mode | during RUNNING + at end |
| offline RDMA dump | SWB RDMA host-memory dump after END_RUN | post-run, off-line replay |

All three sub-measurements (within one stream) agree with each other within
+/- 8 hits (pipeline drain tolerance). Then the stream-level total is
compared against theory.

## Parallel cosim execution

The dual-UVM cosim at `cosim/` supports up to **30 parallel sim invocations**
on the same workstation (sized by the host's available cores; the harness
makes each row's `vsim` instance self-contained). The standard sweep runner
groups the 128 RN.BASIC rows into 5 batches of 30 (and one partial batch),
reducing wall-clock from ~6 hours sequential to ~15 minutes parallel.
Codex agents that dispatch a sweep should use `make run_BASIC PARALLEL=30`
or equivalent (TBD in cosim Makefile; see `cosim/doc/COSIM_USAGE.md`).

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
per_active_channel_hps = rate_88fp * (125e6 / 65536)
requested_hps = per_active_channel_hps * active_channels
requested_hits = requested_hps * run_window_s
theoretical_hits = min(requested_hits, opq_ceiling_hps * run_window_s)
sim_delta_pct   = (sim_total_hits   - theoretical_hits) / theoretical_hits * 100
board_delta_pct = (board_total_hits - theoretical_hits) / theoretical_hits * 100
```

`opq_ceiling_hps = 250e6` for the May 2026 retest. The standalone OPQ signoff
project closes at 275 MHz (1.1x margin), while the operational target remains
the user-specified 250 MHz aggregate delivery ceiling. The two theory deltas
are independent comparisons against theory; the normalized sim-vs-board rate
delta is retained only as a third comparison column in the HTML report.

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
| RN.PROF (in TEST_PERF.md) | 7 | partial; saturation knee at `0x4000` observed; long-soak (RN.PROF.007) on-board pending, cosim waived | OPQ ingress ceiling probe + 10 s soak |
| RN.ERROR (in TEST_ERROR.md) | 6 | pending | invalid configs during run |
| RN.EDGE (in TEST_EDGE.md) | 8 | RN.EDGE.002 sim-vs-board inversion pending arbfix retest; EDGE.007 + EDGE.008 injector-mode rows added | corner masks + injector-mode coverage |

**Total: 211 cases.** Each row (except long-soak waivers) carries three
agreeing evidence streams: theory, cosim sim, and board. PASS count is
currently dominated by BU+SC.BASIC+RC.BASIC + sim RN.BASIC; the remaining
gates close as the in-flight arbfix retest + cosim 1 ms rerun + BASIC/PERF
codex dispatches return.

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
| RN.PROF | partial | `47efa242`; RN.PROF.007 long-soak pending (cosim waived) |
| RN.ERROR | pending | tb_int |
| RN.EDGE | RN.EDGE.002 inversion pending arbfix | `47efa242`, arbfix retest |

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

- **OPQ aggregate ingress ceiling**: 250 MHz operational target confirmed
  against the OPQ signoff collateral; standalone signoff closes at 275 MHz
  margin. RN.BASIC threshold is therefore < 125 Mhit/s requested aggregate,
  and RN.PROF rows use clipped theoretical_hits at 250 Mhit/s.
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

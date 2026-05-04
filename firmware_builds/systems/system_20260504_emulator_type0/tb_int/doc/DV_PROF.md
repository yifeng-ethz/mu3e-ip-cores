# tb_int PROF — `system_20260504_emulator_type0`

**Parent:** [DV_PLAN.md](DV_PLAN.md) §3.

**Total: 192 cases.** `PROF-RC-001..032`, `PROF-SC-001..032`, `PROF-DT-001..128`.

PROF tests sustained throughput, soak, and peak conditions on every axis. Each case must run for ≥ 10⁵ cycles (≈ 800 µs at 125 MHz) where applicable.

---

## RC section (PROF-RC-001..PROF-RC-032)

| Sub-set | Count | Scope |
|---|---:|---|
| Long-`RUNNING` soak | 8 | Canonical run with `RUNNING` held for 10⁵ / 10⁶ / 10⁷ cycles; verify no run-state drift, frame counter advance correctly, no spurious watchdog. |
| Sustained `RUN_NUMBER` increment | 8 | 10² consecutive canonical runs; `RUN_NUMBER` increments exactly once per `RUN_PREP`; no double-increment, no off-by-one. |
| Watchdog overlap | 8 | `arb_hit_type0` watchdog fires during `RUNNING` while RC stays stable; egress lock + run-control RESET cleanup. |
| Re-sync stress | 8 | `SYNC` re-asserted 16 times in one `RUNNING`; counters' snapshot semantics under repeated re-sync. |

Each case must end with `RUN_NUMBER` matching expected and zero `UVM_ERROR`.

## SC section (PROF-SC-001..PROF-SC-032)

| Sub-set | Count | Scope |
|---|---:|---|
| Sustained back-to-back single-word | 8 | 10⁴ AVMM transactions with no idle gap; verify SC bridge never stalls beyond documented bound. |
| Sustained burst | 8 | 10³ full-aperture bursts back-to-back. |
| Mixed read/write soak | 8 | 10⁴ RW pairs randomised; latched-on-read pair-atomicity holds. |
| Concurrent SC + DT peak traffic | 8 | SC sustained while DT runs at 1 MHz × 32 channels; SC traffic does not slip. |

## DT section (PROF-DT-001..PROF-DT-128)

| Sub-set | Count | Scope |
|---|---:|---|
| Sustained Poisson per source × per rate × per cluster-size | 60 | Cartesian product of (`{REAL, EMU, MIX_RR, MIX_RR cross-source}`) × (`{100k, 500k, 1M, 2M, 5M Hz / channel}`) × (`{2, 4, 8}` mean cluster-size). 800 µs sim time each. |
| Raw `1 hit / 3.5 cycles` ceiling | 16 | Both real and emu sources at the documented saturation rate; verify no FIFO drops, no merge-FSM stalls, four-stage latency CDFs at the per-stage budget. |
| Long-soak with mid-run `RUN_NUMBER` bump | 16 | 10⁶-cycle soak with `RUN_NUMBER` incrementing every 10⁵ cycles; counters reset between runs but cumulative scoreboard tracks all hits across runs. |
| Watchdog stress | 16 | One source goes silent mid-frame at random offsets; watchdog synthesizes the missing EOP within the documented threshold. |
| Histogram saturation | 20 | Drive enough hits per bin to saturate `histogram_statistics_0`'s counter; verify saturating behaviour and no overflow corruption. |

Each PROF-DT case asserts: scoreboard PASS, latency CDFs at the four stages within budget, drops zero in non-saturation cases (in saturation cases, drops match the FIFO model prediction exactly), histogram cross-check matches.

---

## Plan drift notes

(none yet)

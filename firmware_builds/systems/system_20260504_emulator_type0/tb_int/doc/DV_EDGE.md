# tb_int EDGE — `system_20260504_emulator_type0`

**Parent:** [DV_PLAN.md](DV_PLAN.md) §3.

**Total: 192 cases.** `EDGE-RC-001..032`, `EDGE-SC-001..032`, `EDGE-DT-001..128`.

EDGE tests boundary conditions per axis. Each case is a corner — off-by-one, exact-cycle alignment, max-channel, max-cluster, sparse / dense extremes.

---

## RC section (EDGE-RC-001..EDGE-RC-032)

| Sub-set | Count | Scope |
|---|---:|---|
| Back-to-back state transitions with zero gap | 8 | `RUN_PREP → SYNC` on consecutive cycles (no idle between); IPs must observe both transitions; no merged transition. |
| Transition same cycle as CSR write | 8 | RC state change in cycle `t`, CSR write committed in cycle `t`; verify per-IP order is deterministic. |
| Truncated state words | 8 | Synclink delivers a state word with truncated payload; runctl_mgmt_host detects malformed and reports without state change. |
| Run-state vs watchdog timing | 8 | `RUNNING → TERMINATING` exactly at the cycle the watchdog fires; verify cleanup ordering. |

## SC section (EDGE-SC-001..EDGE-SC-032)

| Sub-set | Count | Scope |
|---|---:|---|
| Burst-length boundaries | 8 | Burst lengths 1, 2, 31, 32, 33, slave-aperture, slave-aperture−1, slave-aperture+1. |
| Aperture-edge addresses | 8 | Read/write at the very last legal address of every slave; verify no spillover. |
| Undefined address reads | 8 | Read addresses inside the slave window but outside the documented map; expected behaviour is "reads as zero". |
| Mixed read/write inside one burst | 8 | Test the SC bridge's intra-burst direction handling. |

## DT section (EDGE-DT-001..EDGE-DT-128)

| Sub-set | Count | Scope |
|---|---:|---|
| Cluster-size at maximum | 16 | All 32 channels active in one frame; cluster fills the entire MuTRiG frame; verify FIFO survives. |
| Single-channel saturation | 16 | One channel gets every possible hit (frame full of one channel); verify FIFO + arbiter handle the worst-case pattern. |
| Frame-boundary hit straddling | 16 | Hit's `T_coarse` exactly equals frame boundary; verify hit assigned to the correct frame in the deassembly. |
| FIFO-full induced drops at watchdog boundary | 16 | Drive enough traffic to fill the per-source FIFO exactly when the watchdog timer hits the threshold; verify drop accounting + watchdog synthesis interlock. |
| Channel ID at the convention boundary | 16 | Real channels at 7 (max real per convention), emu channels at 8 (min emu per convention); verify per-beat channel demultiplex by the scoreboard. |
| Frame phasing at the start / end | 16 | Hit at frame start cycle, hit at frame end cycle, hit at frame start +1, hit at frame end −1; verify deassembly-frame counter increments correctly. |
| Cross-source channel collision | 16 | Real and emu both emit channel = 8 in MIX_RR (violates the `[0..7]` / `[8..15]` convention); per the design, the arbiter forwards both, scoreboard logs the convention violation. |
| Empty frame | 16 | Virtual MuTRiG emits a frame containing zero hits; deassembly still produces the SOP/EOP boundary; counters update correctly. |

---

## Plan drift notes

(none yet)

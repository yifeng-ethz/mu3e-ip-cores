# tb_int ERROR — `system_20260504_emulator_type0`

**Parent:** [DV_PLAN.md](DV_PLAN.md) §3.

**Total: 192 cases.** `ERROR-RC-001..032`, `ERROR-SC-001..032`, `ERROR-DT-001..128`.

ERROR tests failure injection: bad-CRC frames, dropped frames, mid-flight RESET, watchdog firings, protocol violations, illegal SC traffic. Each case logs the system-level recovery path through error counters, syndromes, sticky flags, and run-control RESET cleanup.

---

## RC section (ERROR-RC-001..ERROR-RC-032)

| Sub-set | Count | Scope |
|---|---:|---|
| Mid-flight RESET while IP is mid-flush | 8 | RESET injected during the `arb_hit_type0` merge-packet close window; during `mutrig_frame_deassembly` mid-frame; during `histogram_statistics` mid-bin commit. |
| Back-to-back RESETs without intervening IDLE | 8 | RESET → RESET cycles; verify final state is consistent. |
| Truncated state words | 8 | Malformed RC payload; verify the host model + per-IP `STATUS.run_state` tracking detects and reports. |
| RC during SC | 8 | RESET issued mid-SC-burst; SC must complete or be aborted cleanly. |

## SC section (ERROR-SC-001..ERROR-SC-032)

| Sub-set | Count | Scope |
|---|---:|---|
| Burst overrun aperture | 8 | Burst length pushes past the 4 KB slave window; verify SC bridge rejects or trims. |
| Illegal address (outside any slave) | 8 | Verify "reads as zero" / "writes ignored" semantic. |
| Write to RO field | 8 | Verify field unchanged; no slave-error response unless documented. |
| Read of W1P field | 8 | W1P bits read as zero (not the last write). |

## DT section (ERROR-DT-001..ERROR-DT-128)

| Sub-set | Count | Scope |
|---|---:|---|
| Bad CRC injected | 16 | Virtual MuTRiG frame trailer carries wrong CRC; `mutrig_frame_deassembly` flags the frame; downstream stages drop. Scoreboard records the dropped uids in `drops.csv`. |
| Frame dropped mid-cluster | 16 | Drop a frame mid-cluster of a multi-frame cluster; verify the partial cluster's hits are accounted (drops `+= partial`, `INGRESS_*_FRAMES` reflects the missed frame). |
| `RUN_PREP` mid-frame | 16 | RC `RUN_PREP` injected while a frame is open at the deassembly; verify cleanup; verify counters preserved per the `RUN_PREP` contract. |
| Channel collision (cross-source) | 16 | Real and emu both emit channel = 8 in MIX_RR (violates the `[0..7]` / `[8..15]` convention); scoreboard logs the convention violation; arbiter forwards both. |
| SOP without EOP from one source | 16 | Virtual MuTRiG truncates a frame (drops the EOP-bearing word); `arb_hit_type0` records `STATUS.protocol_violation_sticky` + `ERROR_COUNT_PROTOCOL` + `SYNDROME_PROTOCOL`. |
| Double EOP without SOP | 16 | Virtual MuTRiG injects an extra EOP-marker beat without a matching SOP; protocol violation surface logs the event. |
| Watchdog firing under various conditions | 16 | One source goes silent at the start, the middle, the end of `RUNNING`; watchdog must / must not fire per the §2.3 spec; sticky flags + `STATUS.watchdog_synthesized_*` correct. |
| Combined error injections | 16 | Two error events in the same frame (e.g. bad CRC + SOP-without-EOP); verify both error counters fire; the scoreboard distinguishes them. |

Each ERROR-DT case records the syndrome registers (per-IP) at run-end into the test artifact directory and asserts the syndrome match the expected value for the injected error.

---

## Plan drift notes

(none yet)

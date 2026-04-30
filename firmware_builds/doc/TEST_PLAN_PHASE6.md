# TEST_PLAN_PHASE6.md - FEB to SWB to host end-to-end hit closure

**Revision**: 2026-04-30 / draft-0
**Target**: `firmware_builds/systems/system_20260427_testplanphase5/` plus the `online_sc` SWB image at `/home/yifeng/packages/online_sc/online/switching_pc/a10_board/output_files/top.sof`
**Host**: teferi (`/dev/mudaq0`, FEB SciFi on SWB SC link 2)
**Companions**: [`TEST_PLAN.md`](TEST_PLAN.md), [`TEST_PLAN_PHASE5.md`](TEST_PLAN_PHASE5.md), [`MUTRIG.md`](MUTRIG.md), [`RUNCTL_HITSTACK_SIGNALTAP_PLAN.md`](RUNCTL_HITSTACK_SIGNALTAP_PLAN.md)

---

## 0. Goal

Phase 6 is the first long-run closure plan for real MuTRiG hits across the full
chain:

```text
MuTRiG TDC injection
  -> FEB frame deassembly
  -> MTS timestamp processor
  -> ring-buffer CAM / hit processor
  -> FEB frame assembly output
  -> SWB input
  -> SWB time/stream merger output
  -> host PC DMA buffer
  -> disk file and offline decoder
```

The source signoff target is strict: 100 kHz injection per channel across 256
MuTRiG channels must create source bunches of 256 hits. The 256 source hits in
one bunch must have the same hit timestamp, and adjacent source-bunch
timestamps must be separated by the 100 kHz period. At the 125 MHz injector
clock, 100 kHz is `--pulse-intervals 1250`.

The current SWB/ER OPQ debug profile is deliberately not a no-loss profile:
Mu3e Demo uses `N_SHD=128` and `N_HIT=255`. A 256-hit source cluster must
therefore produce exactly 255 delivered host hits plus exactly one accounted
OPQ hit drop. The delivered 255 hits must share one timestamp, and the
bunch-to-bunch timestamp interval must still match the 100 kHz source cadence.
A future no-loss host-disk closure needs a different OPQ hit-limit profile; do
not silently count the Mu3e Demo diagnostic profile as 256-hit no-loss closure.

This phase is pessimistic by construction. Normal cases must pass before
performance cases count. Negative controls must fail in the expected way. If a
case that should fail does not fail, that is a bug or an observability gap, not
a lucky pass.

## 1. Current Entry State

Phase 6 starts from the 2026-04-30 Phase-5 state:

| Item | State | Evidence |
|---|---|---|
| FEB no-STP image | `PASS` timing-clean board image | `TEST_PLAN_PHASE5.md` v26.1.6 checkpoint |
| MuTRiG config mapping | `PASS` documented | `MUTRIG.md` ASIC/XML mapping, SMB3 lanes 0..3, SMB5 lanes 4..7 |
| Injector control path | `PASS` for current image | `mutrig_injector_0` at SC word base `0x0AC80`; no deprecated `MUTRIG_CNT_CTRL_REGISTER_W` control |
| LVDS controller observability | `PASS` for current blocker probe | active `lvds_rx_controller_pro_0.csr` at SC word base `0x08000`, 16-word aperture; [`../systems/system_20260427_testplanphase5/reports/phase6_lvds_blocker_probe_20260430.md`](../systems/system_20260427_testplanphase5/reports/phase6_lvds_blocker_probe_20260430.md) |
| Lower pair single-channel | `PASS` | lanes 5+6 pass one TDC-test channel after clean good-ribbon restore |
| Lower pair full 32-channel | `BLOCKED` | lanes 5+6 full-channel pulse-high 4 still produces MTS/ring timestamp errors |
| SWB OPQ profile | `PASS` source/synthesis checkpoint | Mu3e Demo OPQ uses `N_SHD=128`, `N_HIT=255`; packet_scheduler `ed249da` merge includes the `25e204c` one-drop UVM proof; online_sc `ada3aea38` |
| SWB image / PCIe | `PASS` image, `BLOCKED` SC return | online_sc `make flow` and `make pgm` passed; SOF checksum `0x31AA0589`; PCIe recovery restored `/dev/mudaq0`; FEB `sc_hub` latched a valid `0x0C000` read and `0x52434D48` data, but the SWB secondary ring returned zero host words; [`../systems/system_20260427_testplanphase5/reports/phase6_swb_opq_live_preflight_20260430.md`](../systems/system_20260427_testplanphase5/reports/phase6_swb_opq_live_preflight_20260430.md) |
| DMA disk closure | `not-run` | no valid host-disk Mu3e Demo OPQ evidence yet: expected 255 delivered hits plus 1 accounted OPQ hit drop per 256-hit source cluster; blocked until the SC reply path and SWB input gate pass |

The current first hard blocker is before SWB/DMA closure: the lower SMB5 pair
`lanes5+6` still fails the MTS/ring timestamp-delay gate when both ASICs run all
32 TDC-test channels. Enabling MTS `drop_delay_error` makes downstream ring
diagnostics clean, but that trims the offending hits before the ring and is not
latency closure.

The current SWB-side blocker is now localized to the SC reply/capture path:
after programming the OPQ-aligned online_sc image and recovering PCIe,
reset-link stop-reset/enable to FEB 7 echoed through
`RESET_LINK_STATUS_REGISTER_R` as `0x31000000` / `0x32000000`. Secondary SC
reads still timed out at the host and the SWB secondary ring stayed empty, but
FEB JTAG readback of `sc_hub` showed the request reached the FEB and completed a
valid external read: `LAST_RD_ADDR=0x0000C000`, `LAST_RD_DATA=0x52434D48`
(`RCMH`). Do not run OPQ/DMA/disk closure against this state except as
environment health diagnostics; first prove the reply leaves FEB and is captured
by the SWB secondary path.

## 2. Stage Gates

Each gate must name the exact stimulus, expected result, observed result, and
evidence path. A later gate cannot be credited if an earlier gate is failing
unless the run is explicitly marked diagnostic-only.

| Gate | Boundary | Required evidence | Closure rule |
|---|---|---|---|
| P6-FEB-IN | MuTRiG to FEB deassembly | per-ASIC frame counters advance; CRC/frame errors stay zero or are locally explained | all 8 ASICs active with correct SMB3/SMB5 XML mapping |
| P6-MTS-RING | MTS to ring-buffer CAM / hit processor | MTS discard and ring input-error counters stay zero without trimming; accepted latency in `0..2000` cycles | full 256-channel 100 kHz source passes |
| P6-FEB-OUT | FEB frame assembly output | FEB output frame counters and frame payload count match accepted hit count | FEB emits all accepted hits with stable run-control framing |
| P6-SWB-IN | SWB optical/link input | SWB SC read/reply loop returns a host-visible FEB `sc_hub` UID read; SWB SciFi link counters advance only on selected link mask; no link/CRC/reset errors | SWB sees FEB output for the same run window |
| P6-SWB-OUT | SWB merger output | time/stream merger counters match SWB input and chosen readout mode | no unexplained merger drops, reordering, or stale packets |
| P6-HOST-DMA | `/dev/mudaq0` DMA buffer | `swb_dmatest` or MIDAS readout writes a nonzero disk buffer for the same run | DMA words are recorded to host disk and linked to run metadata |
| P6-DISK-DECODE | offline decode | Mu3e Demo profile: decoded bunches contain 255 same-timestamp hits and OPQ `drop_hit` accounts exactly 1 lost hit from the 256-hit source cluster; bunch-to-bunch timestamp delta is 100 kHz | no stale, duplicate, timestamp-mismatched, or unaccounted missing hits |

## 3. Case Buckets

### 3.1 BASIC

| ID | Scenario | Expected result | Evidence |
|---|---|---|---|
| P6B001 | all 8 ASICs reload full 32-channel TDC-test XML | `PASS` config, no stale SMB file use | `configure_mutrig_from_xml.py` JSON |
| P6B010 | lower lanes 5+6, one channel per ASIC, pulse high 4, 100 kHz | `PASS` FEB MTS/ring | Phase-5 sanity JSON |
| P6B020 | lower lanes 5+6, full 32 channels, pulse high 4, 100 kHz | current expected `FAIL` at MTS/ring | Phase-5 sanity JSON, counters |
| P6B021 | same as P6B020 with LVDS SVD snapshots enabled | `PASS_DIAG`: ring fails while LVDS error/DPA deltas stay zero, so blocker is downstream of LVDS training | [`../systems/system_20260427_testplanphase5/reports/phase6_lvds_blocker_probe_20260430.md`](../systems/system_20260427_testplanphase5/reports/phase6_lvds_blocker_probe_20260430.md) |
| P6B030 | all 8 lanes, full 256 channels, pulse high 4, 100 kHz | `BLOCKED` until P6B020 passes | same |
| P6B040 | all 8 lanes, full 256 channels, diagnostic `drop_delay_error=on` | diagnostic-only downstream clean expected | proves downstream ring/SWB path only after labeling trimmed hits |
| P6B050 | SWB Mu3e Demo OPQ, 256-hit source cluster | `BLOCKED` until the SC reply path and SWB input gate pass; then `PASS` only if host/disk sees 255 delivered hits and OPQ drop ledger reports exactly 1 hit drop | OPQ CSR snapshot plus disk decode |

### 3.2 PROF

Only run these after P6B020 passes without trimming.

| ID | Scenario | Expected result | Evidence |
|---|---|---|---|
| P6P010 | rate sweep 1, 10, 50, 100 kHz per channel | monotonic hit counts, zero timestamp errors | FEB counters plus disk decode |
| P6P020 | mask sweep one ASIC, one SMB, both SMBs, all 8 ASICs | accepted hit count equals enabled-channel count per bunch | disk decode grouped by ASIC/channel |
| P6P030 | long 168-hour 256-channel soak | no timestamp drift, no DMA stale-data reuse, no unexplained drops | JSONL long-run log plus reduced report |
| P6P040 | SWB merger readout-mode comparison | time-merger and stream-merger expectations match their contracts | SWB counters and `memory_content.txt` decode |
| P6P050 | OPQ hit-limit A/B profile | Mu3e Demo `N_HIT=255` loses exactly one hit from a 256-hit cluster; later no-loss profile must deliver 256 | packet_scheduler UVM, SWB CSR drop ledger, disk decode |

### 3.3 EDGE

| ID | Scenario | Expected result | Evidence |
|---|---|---|---|
| P6E010 | pulse high 3 lower lanes 5+6 full 32 channels | likely clean but underfilled | must be classified underfilled, not PASS |
| P6E020 | latency window 1990, 2000, 2010 around accepted boundary | only hits inside the configured window accepted | MTS/ring counters and SignalTap |
| P6E030 | first bunch after SYNC, first bunch after START_RUN | no stale timestamp from prior run | disk decode bunch index |
| P6E040 | END_RUN during active injection | run terminates cleanly with bounded drain | FEB/SWB counters and DMA tail decode |
| P6E050 | lower lanes 5+6 full 32 channels with LVDS `dpa_hold` asserted after lock | only useful if P6B021 shows DPA unlocks; otherwise diagnostic-only | LVDS DPA counters plus MTS/ring counters |

### 3.4 ERROR

| ID | Scenario | Expected result | Evidence |
|---|---|---|---|
| P6X010 | deliberate MuTRiG PLL unlock on one ASIC | local timestamp-error path fires; disk closure blocked | MTS/ring counters, SignalTap |
| P6X020 | wrong SMB XML applied to down-side ASICs | config may ACK, data quality must fail | frame/MTS evidence |
| P6X030 | SWB readout link mask excludes FEB link | host DMA must not show the FEB hits | SWB counters and disk decode |
| P6X040 | injected rate above known safe point | controlled/asserted drops explain all missing hits | counters and decode |

## 4. Long-Run Harness

Use the restartable runner:

```bash
firmware_builds/systems/system_20260427_testplanphase5/script/run_phase6_long_soak.py \
  --duration-hours 168 \
  --sleep-seconds 60
```

The runner writes a timestamped directory under:

```text
firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_long_runs/
```

Raw long-run output is ignored by git. Promote only reduced reports or plots
that become durable evidence.

The runner classifies each case as one of:

| Result | Meaning |
|---|---|
| `expected_pass` | hardware result passed and the case was expected to pass |
| `expected_fail` | hardware result failed at the expected boundary |
| `unexpected_pass` | a negative-control or known-blocked case passed; debug as a missing observable or wrong stimulus |
| `unexpected_fail` | a nominal case failed |
| `underfilled` | counters are clean but accepted hit count is below the expected multiplicity |
| `diagnostic_only` | local trimming or bypass made later stages observable; not closure |

The long-run is allowed to continue after expected failures so later diagnostic
and health probes still collect evidence. It must stop on environment/preflight
failure, `/dev/mudaq0` loss, or a hardware command exception that prevents the
runner from forcing the injector off.

The Phase-6 runner now enables the live LVDS SVD snapshot path for real-source
cases. Each case JSON records `lvds_summary` from `lvds_rx_controller_pro_0.csr`:
capability, mode mask, DPA hold, lane-go, per-lane error-counter deltas, and
per-lane DPA-unlock deltas. The current Qsys aperture is 16 words
(`0x0..0x3f` internal bytes), so `lane_word_aligner_chosen` at word 16 is not
read by the live scripts. If P6B020 fails with zero LVDS error/DPA deltas, do
not spend a compile on an LVDS replacement first; move the next SignalTap scope
to MTS timestamp-delay and ring input-error causality. If LVDS deltas correlate
with the ring failure, follow the documented A/B path: control image, compatible
LVDS-controller candidate preserving the external PHY/CSR/clock contract, then
absorbed/full LVDS candidate only after the compatible candidate passes.

## 5. SignalTap and Simulation Loop

Use no more than four Quartus compiles in flight, and never run concurrent JTAG
transactions. JTAG programming, Node Finder, and SignalTap acquisition are
serialized even if compilation is parallel.

Debug loop:

1. Reproduce the failure in a short SC-only run and reduce it to a minimal
   lane/channel/rate/pulse condition.
2. Add or retarget SignalTap only for the first unexplained boundary.
3. Run the matching `tb_int/` or IP-level simulation with the same transaction
   identity: ASIC/lane, channel, timestamp, bunch index, accepted/dropped state,
   and cycle.
4. Classify loss as controlled, asserted, or inferred. Inferred-only loss is a
   debug symptom, not signoff.
5. Patch the source owner, regenerate, compile with high effort for timing, and
   rerun the same failing case before expanding the sweep.

SignalTap scope order for Phase 6:

| Scope | First trigger | Purpose |
|---|---|---|
| FEB MTS/ring | MTS timestamp-error sideband or ring input error | localize lower-pair full-channel blocker |
| FEB output | frame assembly valid/SOP/EOP and payload count | prove FEB output count before SWB |
| SWB input | SciFi link ingress valid/error/counter | prove optical/link receipt |
| SWB output | time/stream merger output valid and event builder status | prove merger output |
| Host DMA | DMA enable, end-of-event address, first buffer words | prove DMA capture is same run |

## 6. Host DMA and Disk Decode

The current host diagnostic tool is:

```text
/home/yifeng/packages/online_dpv2/online/build/farm_pc/tools/swb_dmatest
```

Relevant modes from `swb_dmatest.cpp`:

| Argument | Meaning |
|---|---|
| readout mode `4` | time merger reads links |
| readout mode `0` | stream merger reads links |
| detector/use-pixel `2` | SciFi |
| detector/use-pixel `4` | SWB readout SciFi/Pixel |

A DMA capture is not Phase-6 closure until the run directory contains:

- the exact `swb_dmatest` command and stdout/stderr;
- `memory_content.txt` copied from the command working directory;
- SWB counter snapshot before and after capture;
- FEB run metadata and injector/config JSON for the same run window;
- offline decode showing the Mu3e Demo result: 255 delivered hits per bunch,
  same timestamp per delivered bunch, OPQ `drop_hit=1` for each 256-hit source
  cluster, and 100 kHz bunch spacing.

Until the decode is implemented for the exact active packet format, the disk
stage remains `not-run` or `diagnostic_only`.

Current live checkpoint, 2026-04-30:

- SWB OPQ image compile/program: `PASS`, online_sc `ada3aea38`, SOF checksum
  `0x31AA0589`.
- PCIe endpoint recovery: `PASS`, `/dev/mudaq0` present after
  `mudaq_recover_pcie`.
- Reset-link command path: `PASS_DIAG`, FEB 7 stop-reset/enable echoed
  `0x31000000` / `0x32000000`.
- SWB SC return path: `BLOCKED`; valid SC requests reach FEB `sc_hub`
  (`LAST_RD_ADDR=0x0000C000`, `LAST_RD_DATA=0x52434D48`), but host-visible
  SWB secondary reads still return zero words.

## 7. Git and Evidence Hygiene

- Keep source changes committed at every stable checkpoint.
- Push checkpoints after verified commits when the remote is reachable.
- Keep raw generated run directories ignored.
- Promote evidence by reducing it into a curated Markdown/HTML/JSON report and
  adding a narrow `.gitignore` exception only for that artifact.
- Do not commit generated Qsys output or `functional/` RTL edits as source
  fixes. Patch the owning source script, Qsys/Tcl, RTL, or document instead.

# PHASE6_DEBUG_CHECKLIST.md - FEB/SWB end-to-end debug checklist

**Revision**: 2026-04-30 / draft-0
**Parent**: [`TEST_PLAN_PHASE6.md`](TEST_PLAN_PHASE6.md)
**Scope**: real MuTRiG good-ASIC capture, RBCAM/FEB frame-format proof, SWB/DMA disk integrity, and corner-case expansion.

---

## 1. Run Record Requirements

Every Phase-6 debug run must record enough identity to compare STP snapshots,
SC counters, simulation, and disk data without guessing.

| Item | Required value |
|---|---|
| Firmware image | FEB SOF path, checksum, STP/no-STP tag, SWB SOF path, SWB git hash |
| MuTRiG config | exact XML/TXT per SMB; ASIC mask; per-ASIC overrides; channel mask |
| Stimulus | source mode, lane mask, `pulse_intervals`, `pulse_high_cycles`, duration, settle time |
| Run-control | reset opcode history, SYNC/start timing, END_RUN/drain timing |
| FEB counters | deassembly, MTS discard, ring input error, RBCAM, frame assembly, histogram |
| SWB counters | selected link mask, input link counters, OPQ/merger counters, DMA status |
| Artifacts | STP file, VCD, decoder summary, raw command log, JSON manifest, disk buffer |

No rate or latency claim is valid if the run cannot be tied back to the exact
configuration and image that produced it.

## 2. Good-ASIC FEB Format Checklist

Use the current known-good isolated lower ASICs first:

| Step | Action | Pass criteria |
|---|---|---|
| G1 | Configure ASIC5/lane5 only from SMB5 XML, one enabled TDC-test channel, pulse high 4, `pulse_intervals=1250` | frame/deassembly and histogram counters advance; MTS discard, ring input error, LVDS error, and DPA-unlock deltas stay zero |
| G2 | Repeat G1 for ASIC6/lane6 only | same as G1 |
| G3 | Capture STP at MTS/RBCAM/FEB assembly boundaries for the same one-lane stimulus | all observed handshakes are legal; no `tserr` or `tsglitcherr`; decoded word grammar below matches RTL |
| G4 | Run matching authentic generated-system simulation or focused RTL replay with the same transaction identity | simulated boundary sequence matches STP packet grammar and count distributions |
| G5 | Re-run the same stimulus on the timing-clean no-STP image | SC counters remain clean; STP-only timing perturbation is not counted as closure |

Current 2026-04-30 status: the earlier ASIC6/lane6 `vco000` capture is
invalidated as PLL-lock evidence. With `vnvcodelay=0`, the MuTRiG should
generate no TDC-injection hits; a hit-producing zero-VCO run is a stale
configuration, bad override, or run-sequence artifact until the config manifest
proves otherwise. Treat G3 as `OPEN_STP_ALIGNMENT`: rerun with the ASIC-specific
nonzero XML/default setting, full `RUN_PREPARE` synchronization, and a deeper or
better-triggered capture that ties nonempty RBCAM `hit_type2` output to the
later FEB `hit_type3` frame drain.

### 2.1 RBCAM Input: `hit_type1`

Probe before RBCAM at `hit_stack_subsystem_N.hit_type_1_*` and, when needed,
the per-ring splitter outputs. Expected contract:

| Field | Expected |
|---|---|
| `valid && ready` | accepted hit_type1 beat |
| `data[38:0]` | MTS-forwarded MuTRiG hit payload |
| `channel[3:0]` | lane/stream tag used by the lower or upper hit stack |
| `error[0]` | timestamp-delay error (`tserr`); must stay zero for closure |
| packet flags | legal start/end boundaries only; no orphan EOP or missing SOP |

The accepted latency to the ring buffer CAM must be inside `0..2000` cycles.
Hits outside that window are expected to be rejected or flagged; accepting them
without an error is a bug.

### 2.2 RBCAM Output / FEB Assembly Input: `hit_type2`

Probe `ring_buffer_cam_0..3_hit_type2_*` inside the selected hit-stack
subsystem. Expected contract:

| Word kind | `data[35:32]` | Payload | Packet rule |
|---|---:|---|---|
| subheader | `0x1` | `data[31:24]=ts[11:4]`, `data[15:8]=hit_count`, `data[7:0]=0xF7` | SOP asserted; EOP asserted only when `hit_count=0` |
| hit | `0x0` | `data[31:28]=ts[3:0]`, ASIC/channel/time/energy fields from MuTRiG hit | follows its subheader; EOP asserted on the last hit in the subheader |

For a single enabled channel in deterministic header/TDC-test mode, the
subheader hit-count distribution should be a delta or a very narrow documented
pattern. A broad or multi-peak distribution is a timing/tuning bug unless a
controlled mask or backpressure case deliberately created it.

### 2.3 FEB Frame Assembly Output: `hit_type3`

Probe `hit_type3_*` from the selected hit-stack subsystem and the upper/lower
merged output when available. Expected frame grammar:

| Position | Expected word |
|---|---|
| preamble | K word with `data[35:32]=0x1`, `data[7:0]=0xBC` |
| header 1 | GTS upper slice |
| header 2 | GTS lower slice plus frame counter |
| header 3 | debug header: subheader count and hit count |
| header 4 | generation-time debug word |
| body | one or more `hit_type2` subheader/hit groups |
| trailer | K word with `data[35:32]=0x1`, `data[7:0]=0x9C`, EOP asserted |

For every captured frame, decode the body and compare:

- decoded subheader count equals header-3 subheader count;
- sum of decoded subheader hit counts equals header-3 hit count;
- number of hit words after each subheader equals that subheader's hit count;
- subheader timestamp buckets follow the expected `ts[11:4]` order;
- all hits in a source bunch share the expected timestamp where the stimulus
  promises one deterministic hit timestamp;
- adjacent source bunch timestamps are separated by the 100 kHz period.

## 3. Lane 6/7 TDC/VCO Tuning Checklist

Lane 6 and lane 7 tuning starts from an explicit no-hit reset point, then jumps
to the ASIC-specific known-good board range before fine tuning. A blind sweep
from zero is a bad MuTRiG tuning method.

| Step | Action | Pass criteria |
|---|---|---|
| V1 | Set lane ASIC TDC/VCO-related fields to zero (`vncnt=0`, `vnvcodelay=0`, `vnhitlogic=0` when exposed by the config tool) | configuration ACK/readback records the zero point and the ASIC produces no TDC-injection hits |
| V2 | Load the ASIC-specific SMB XML/default or recorded restore setting for `cnt/vcodelay/hitlogic`; run the full sequence through `RUN_PREPARE` before `RUNNING` | one enabled TDC-test channel produces a narrow head-sync delay peak at a legal offset |
| V3 | Capture a per-ASIC head-sync delay histogram plot and config manifest | dominant delta peak is in band; broad/random or roughly 50/50 in-band/out-of-band alias means PLL unlock |
| V4 | Fine-tune `vnvcodelay` first, then `vncnt`, and only modestly adjust `vnhitlogic`; do this during `RUNNING` only after lock is already established | stable delta peak with about 1000 ppm accounted out-of-band/lost hits on good ASICs, or documented waiver up to about 1% for a bad ASIC |
| V5 | Repeat after FEB reconfiguration and MuTRiG XML reload, then expand the channel mask | counts scale with enabled channels; no new timestamp-error class appears |

Reject a point if it has any of these symptoms: broad latency histogram,
multi-peak latency, low accepted count outside an underfill control, MTS
discard, ring input error, LVDS error delta, DPA-unlock delta, or an STP frame
grammar violation.

Reject any hit-producing `vco000` capture as a harness/configuration bug until
the config manifest proves `vnvcodelay` was actually nonzero or the run is
explicitly reclassified.

## 4. Corner-Case Matrix

Do not move to performance cases until all relevant normal cases pass.

| Case | Stimulus | Expected result |
|---|---|---|
| C1 | ASIC5/lane5 one channel, 1/10/100 kHz | clean counters; timestamp spacing scales with rate |
| C2 | ASIC6/lane6 one channel, 1/10/100 kHz | clean counters; timestamp spacing scales with rate |
| C3 | ASIC7/lane7 one channel after VCO sweep | clean only after a stable tuning point is found |
| C4 | ASIC5+ASIC6 one channel each | currently expected fail until the cross-ASIC timestamp/epoch blocker is fixed |
| C5 | pulse high 3 | expected underfill or no useful traffic; must not be called PASS |
| C6 | channel masks 1, 2, 4, 8, 16, 32 channels on one ASIC | counts scale; latency distribution stays narrow |
| C7 | END_RUN during active injection | bounded drain; no stale frame tail in the next run |
| C8 | wrong SMB XML or wrong ASIC mask | must fail at data quality or config evidence; a silent pass is a test bug |

If a negative control passes, stop and debug observability or stimulus before
using that capture as evidence.

## 5. SWB/DMA Disk Checklist

Run SWB/DMA only after the FEB one-ASIC path is clean at the FEB output
boundary. Use several short disk captures before any long soak.

Do not use `online_sc` `swb_dmatest`, `rw`, MIDAS, or libmudaq-backed Mu3e
online tools as Phase-6 closure evidence. They are reference-only because their
detector offsets, mask assumptions, and cleanup sequences can hide the first
bad boundary. Use repo-owned direct-MMIO tools under `tools/`, currently:
`tools/phase6_swb_dma_probe/phase6_swb_dma_probe.py` and
`tools/phase6_swb_dma_probe/analyze_phase6_dma_memory.py`.

| Step | Action | Pass criteria |
|---|---|---|
| D1 | Verify `/dev/mudaq0`, SWB SC link-2 readback, and selected FEB optical link mask | `/dev/mudaq0` present; SC `0x0C000` returns `0x52434D48`; only selected link counters move |
| D2 | Run SWB stream-datagen raw-DMA control | raw host DMA is nonzero; event-builder payload count advances; old-frame reducer may report `raw_payload_no_legacy_frames` |
| D3 | Run one 10 s DMA capture with ASIC5/lane5 one-channel clean FEB output | disk file is nonzero and tied to the exact injector window |
| D4 | Repeat D3 at least three times | no stale-buffer reuse; counters and disk word counts are monotonic |
| D5 | Expand to ASIC6/lane6, then tuned lane7, then selected multi-lane cases | SWB input/output counters and disk decoder agree with FEB output counts |
| D6 | Offline decode every disk file | legal frame grammar or explicitly decoded MuSiP payload, no unexplained gaps, no duplicate/stale run tail |

For Mu3e Demo OPQ with `N_SHD=128` and `N_HIT=255`, a 256-hit source cluster is
expected to deliver 255 hits plus exactly one accounted OPQ hit drop. A no-loss
256-hit disk result under that profile is itself suspicious unless OPQ settings
changed and the run manifest proves it.

## 6. Offline Analysis Requirements

The current reducer entry point is
`tools/phase6_swb_dma_probe/analyze_phase6_dma_memory.py`. It is called
automatically by `run_phase6_long_soak.py` for each SWB DMA capture and may
also be run directly against a saved `memory_content.txt` or the probe's
`dma_words.bin`.

`raw_payload_no_legacy_frames` is a partial SWB-DMA result, not a pass. It means
the host buffer contains nonpadding raw `musip_event_builder` payload but the
old FEB/SWB frame scanner found no legacy headers or trailers.

The offline disk reducer must report, at minimum:

- total words and nonpadding words;
- decoded frame count, malformed frame count, and first malformed word offset;
- per-frame subheader count and hit count;
- subheader hit-count distribution;
- per-bunch timestamp distribution and timestamp-delta distribution;
- duplicate/stale frame signatures across runs;
- SWB/OPQ controlled-drop counters, when available, matched against missing
  hits;
- first-loss boundary classified as controlled, asserted, or inferred.

STP is only a local snapshot. Disk analysis is the long-window integrity check;
both must agree before Phase-6 e2e closure is claimed.

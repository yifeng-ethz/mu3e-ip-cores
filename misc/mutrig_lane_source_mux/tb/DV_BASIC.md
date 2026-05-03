# mutrig_lane_source_mux DV — Basic Functional Cases

**Companion docs:** `README.md`, `DV_PLAN.md`, `DV_HARNESS.md`,
`DV_EDGE.md`, `DV_PROF.md`, `DV_ERROR.md`, `DV_CROSS.md`, `DV_COV.md`,
`BUG_HISTORY.md`

**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** B001-B064
**Total:** 64 cases (64 implemented / 0 waived)

**Methodology key:**
- **D** = Directed
- **R** = Constrained-random

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---:|---|---|---|
| Valid-Qualified Direct Modes | 16 | B001-B016 | Real-only and emulator-only forwarding with explicit real valid. | 16/16 |
| Valid-Qualified Mixed And Control | 16 | B017-B032 | Mixed RR FIFO ordering, CSR metadata, clear, and mode switch with explicit real valid. | 16/16 |
| Validless Direct Modes | 16 | B033-B048 | `REAL_ALWAYS_VALID=1` real forwarding and emulator isolation. | 16/16 |
| Validless Mixed And Control | 16 | B049-B064 | Mixed RR pressure, runtime switching, coherent selected-output accounting in validless mode. | 16/16 |

## 2. Valid-Qualified Direct Modes

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| B001 | D | Real mode one beat | 1 | `REAL_ALWAYS_VALID=0`, `CASE_ID=0`; one real byte. | Output byte/sidebands match; counters exact. | `mlsm_directed_test` |
| B002 | D | Real mode two beats with gaps | 1 | `CASE_ID=1`; two real bytes and periodic idle. | Output deasserts on idle; counters exact. | `mlsm_directed_test` |
| B003 | D | Real mode three beats | 1 | `CASE_ID=2`; three real bytes. | Real-selected count equals selected count. | `mlsm_directed_test` |
| B004 | D | Real mode four beats with sideband variation | 1 | `CASE_ID=3`; varied channel/error. | Sidebands preserved each cycle. | `mlsm_directed_test` |
| B005 | D | Real mode five beats | 1 | `CASE_ID=4`; longer direct burst. | No emulator-selected beats. | `mlsm_directed_test` |
| B006 | D | Real mode six beats with gaps | 1 | `CASE_ID=5`; burst plus idle gaps. | No stale output during idle gaps. | `mlsm_directed_test` |
| B007 | D | Real mode seven beats | 1 | `CASE_ID=6`; patterned payload. | Last-selected CSR matches final real beat. | `mlsm_directed_test` |
| B008 | D | Real mode eight beats | 1 | `CASE_ID=7`; longest direct real basic burst. | Exact input/selected counter match. | `mlsm_directed_test` |
| B009 | D | Emulator mode one beat | 1 | `CASE_ID=8`; one emulator byte. | Output follows emulator valid only. | `mlsm_directed_test` |
| B010 | D | Emulator mode two beats with gaps | 1 | `CASE_ID=9`; idle between emulator beats. | Real noise ignored; emu counters exact. | `mlsm_directed_test` |
| B011 | D | Emulator mode three beats | 1 | `CASE_ID=10`; three emulator bytes. | No real-selected beats. | `mlsm_directed_test` |
| B012 | D | Emulator mode four beats with sideband variation | 1 | `CASE_ID=11`; varied emulator sidebands. | Sidebands preserved. | `mlsm_directed_test` |
| B013 | D | Emulator mode five beats | 1 | `CASE_ID=12`; medium emulator burst. | Selected count equals emu-selected count. | `mlsm_directed_test` |
| B014 | D | Emulator mode six beats with gaps | 1 | `CASE_ID=13`; valid-qualified gaps. | Output invalid during gaps. | `mlsm_directed_test` |
| B015 | D | Emulator mode seven beats | 1 | `CASE_ID=14`; patterned payload. | Last-selected CSR matches final emulator beat. | `mlsm_directed_test` |
| B016 | D | Emulator mode eight beats | 1 | `CASE_ID=15`; longest direct emulator basic burst. | Exact input/selected counter match. | `mlsm_directed_test` |

## 3. Valid-Qualified Mixed And Control

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| B017 | D | Mixed RR both sources every cycle | 1 | `CASE_ID=16`; real and emulator valid together. | Output alternates source; counters exact after drain. | `mlsm_directed_test` |
| B018 | D | Mixed RR paired traffic, odd length | 1 | `CASE_ID=17`; paired burst with odd total. | Final drain completes without stale output. | `mlsm_directed_test` |
| B019 | D | Mixed RR emulator every second cycle | 1 | `CASE_ID=18`; sparse emulator. | Real gets extra grants; no unexpected drops. | `mlsm_directed_test` |
| B020 | D | Mixed RR emulator every third cycle | 1 | `CASE_ID=19`; sparser emulator. | FIFO level returns to zero. | `mlsm_directed_test` |
| B021 | D | Mixed RR longer paired pressure | 1 | `CASE_ID=20`; longer both-valid burst. | Drain guard empties both queues. | `mlsm_directed_test` |
| B022 | D | Mixed RR longer odd paired pressure | 1 | `CASE_ID=21`; odd paired burst. | Selected source accounting exact. | `mlsm_directed_test` |
| B023 | D | Mixed RR sparse emulator pressure | 1 | `CASE_ID=22`; emulator every second cycle. | Sparse source not starved. | `mlsm_directed_test` |
| B024 | D | Mixed RR sparse emulator long drain | 1 | `CASE_ID=23`; emulator every third cycle. | No residual FIFO occupancy. | `mlsm_directed_test` |
| B025 | D | CSR identity after traffic | 1 | `CASE_ID=24`; switching case reads UID/META. | UID `MLSM`, version/date/instance match. | `mlsm_directed_test` |
| B026 | D | CSR clear after real traffic | 1 | `CASE_ID=25`; clear during runtime sequence. | Selected counters restart from zero. | `mlsm_directed_test` |
| B027 | D | Real to emulator runtime switch | 1 | `CASE_ID=26`; real burst then emulator mode. | Output follows new source immediately. | `mlsm_directed_test` |
| B028 | D | Emulator to mixed runtime switch | 1 | `CASE_ID=27`; emulator burst then mixed. | Mode switch clears mixed FIFOs. | `mlsm_directed_test` |
| B029 | D | Mixed to direct runtime switch | 1 | `CASE_ID=28`; mixed queued traffic then direct. | Source switch count advances. | `mlsm_directed_test` |
| B030 | D | Last-selected update across modes | 1 | `CASE_ID=29`; all three modes. | Last-selected source tracks active output. | `mlsm_directed_test` |
| B031 | D | FIFO status after switch | 1 | `CASE_ID=30`; mode switch with queued mixed traffic. | FIFO status reports empty after switch clear. | `mlsm_directed_test` |
| B032 | D | Full control smoke | 1 | `CASE_ID=31`; identity, clear, real, emu, mixed. | No UVM errors; all accounting invariants hold. | `mlsm_directed_test` |

## 4. Validless Direct Modes

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| B033 | D | Validless real one beat | 1 | `REAL_ALWAYS_VALID=1`, `CASE_ID=32`; real valid held low. | Output valid follows real byte despite raw valid low. | `mlsm_directed_test` |
| B034 | D | Validless real two beats | 1 | `CASE_ID=33`; changing real byte. | Selected source is real only. | `mlsm_directed_test` |
| B035 | D | Validless real three beats | 1 | `CASE_ID=34`; sideband variation. | Channel/error preserved. | `mlsm_directed_test` |
| B036 | D | Validless real burst with gaps | 1 | `CASE_ID=35`; driver inserts idle raw-valid gaps. | Output remains valid on each clock. | `mlsm_directed_test` |
| B037 | D | Validless real medium burst | 1 | `CASE_ID=36`; five real updates. | Real input count is nonzero and monotonic. | `mlsm_directed_test` |
| B038 | D | Validless real longer burst | 1 | `CASE_ID=37`; six real updates. | Selected source sum is coherent. | `mlsm_directed_test` |
| B039 | D | Validless real payload pattern | 1 | `CASE_ID=38`; seven real updates. | Last output matches active real sidebands. | `mlsm_directed_test` |
| B040 | D | Validless real longest direct burst | 1 | `CASE_ID=39`; eight real updates. | No non-mixed drops. | `mlsm_directed_test` |
| B041 | D | Validless emulator one beat | 1 | `CASE_ID=40`; emulator selected. | Output follows emulator valid, not validless real. | `mlsm_directed_test` |
| B042 | D | Validless emulator two beats | 1 | `CASE_ID=41`; emulator gaps. | Output invalid during emulator gaps. | `mlsm_directed_test` |
| B043 | D | Validless emulator three beats | 1 | `CASE_ID=42`; emulator sideband variation. | Real-selected count remains zero after clear. | `mlsm_directed_test` |
| B044 | D | Validless emulator four beats | 1 | `CASE_ID=43`; medium burst. | Emu-selected equals selected. | `mlsm_directed_test` |
| B045 | D | Validless emulator five beats | 1 | `CASE_ID=44`; raw real changes in background. | Background real is ignored by selected output. | `mlsm_directed_test` |
| B046 | D | Validless emulator six beats | 1 | `CASE_ID=45`; gap pattern. | No stale emu output during gaps. | `mlsm_directed_test` |
| B047 | D | Validless emulator seven beats | 1 | `CASE_ID=46`; patterned payload. | Last-selected source is emulator. | `mlsm_directed_test` |
| B048 | D | Validless emulator eight beats | 1 | `CASE_ID=47`; longest direct emulator burst. | No non-mixed drops. | `mlsm_directed_test` |

## 5. Validless Mixed And Control

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| B049 | D | Validless mixed paired pressure | 1 | `CASE_ID=48`; emulator every cycle. | Mixed output coherent; drops observed under pressure. | `mlsm_directed_test` |
| B050 | D | Validless mixed odd paired pressure | 1 | `CASE_ID=49`; odd paired length. | Selected source sum equals selected after idle snapshot. | `mlsm_directed_test` |
| B051 | D | Validless mixed sparse emulator | 1 | `CASE_ID=50`; emulator every second cycle. | No required-drop false failure; output remains coherent. | `mlsm_directed_test` |
| B052 | D | Validless mixed sparse long interval | 1 | `CASE_ID=51`; emulator every third cycle. | Real pressure does not corrupt emulator beats. | `mlsm_directed_test` |
| B053 | D | Validless mixed longer paired pressure | 1 | `CASE_ID=52`; longer both-valid traffic. | Drop counter nonzero when expected. | `mlsm_directed_test` |
| B054 | D | Validless mixed longer odd paired pressure | 1 | `CASE_ID=53`; odd paired traffic. | Source accounting remains coherent. | `mlsm_directed_test` |
| B055 | D | Validless mixed sparse pressure | 1 | `CASE_ID=54`; sparse emulator. | No selected-output corruption. | `mlsm_directed_test` |
| B056 | D | Validless mixed sparse longest pressure | 1 | `CASE_ID=55`; longest sparse mixed burst. | CSR status remains readable. | `mlsm_directed_test` |
| B057 | D | Validless switch smoke 0 | 1 | `CASE_ID=56`; real, emulator, mixed sequence. | Both sources selected at least once. | `mlsm_directed_test` |
| B058 | D | Validless switch smoke 1 | 1 | `CASE_ID=57`; same sequence with new payload. | Source sum equals selected. | `mlsm_directed_test` |
| B059 | D | Validless switch smoke 2 | 1 | `CASE_ID=58`; same sequence with new payload. | Mode switch count advances. | `mlsm_directed_test` |
| B060 | D | Validless switch smoke 3 | 1 | `CASE_ID=59`; same sequence with new payload. | Mixed output drains or snapshots coherently. | `mlsm_directed_test` |
| B061 | D | Validless switch smoke 4 | 1 | `CASE_ID=60`; same sequence with new payload. | No selected-source accounting skew. | `mlsm_directed_test` |
| B062 | D | Validless switch smoke 5 | 1 | `CASE_ID=61`; same sequence with new payload. | CSR reads remain responsive. | `mlsm_directed_test` |
| B063 | D | Validless switch smoke 6 | 1 | `CASE_ID=62`; same sequence with new payload. | Both source counters are nonzero. | `mlsm_directed_test` |
| B064 | D | Validless switch smoke 7 | 1 | `CASE_ID=63`; final validless control case. | No UVM errors; selected-output invariant holds. | `mlsm_directed_test` |

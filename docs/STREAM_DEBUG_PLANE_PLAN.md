# Streaming Debug Plane — Datapath Re-architecture Plan

Status: draft for review (not started)
Owner: yifeng wang
Target repo: `mu3e-ip-cores`
Phases: A (MTS-Preprocessor side port), B (FEB-Frame-Assembly side port)

---

## 1. Motivation

The current path puts a 48-bit true-hit-timestamp sideband **inside** the main
datapath wires (`aso_hit_type1_data` widened from 39 → 87 b) and additionally
carries that sideband through a snoop fan-out into the histogram via
`histogram_ingress_bridge`. Consequences:

- Main-datapath widths (mts → splitter → rbCAM → frame_assembly) drift away
  from their original hit_type1 / hit_type2 contracts. Every Qsys-generated
  shim and adapter inherits the extra 48 b.
- Snoop-based observability fights the bridge's source-switch contract
  (BUG-005-R: `pre_packet_active` is a run-level marker, so RUN-time
  switches stall). The fix is in silicon (rev 26.0.6 on the bridge) but
  the snoop path is still the topological bottleneck for delay-mode
  observability.
- Anything Phase-B style (post-rbCAM / post-frame-assembly timing
  observability) needs another snoop tap, doubling the bridge-side
  combinational fan-out.

Re-architect: **observability becomes a streaming plane**. The main datapath
keeps its narrow contracts. Each interesting boundary exposes a dedicated
"_extended" Avalon-ST source (data + valid only) whose payload is
`{true_ts[47:0], <original hit word>}`. The histogram IP grows two
extended-input ports (upper bank `_0`, lower bank `_1`) and a CSR `in_port`
selector that picks which observability plane is in use.

Snoop ingress to the histogram (`asi_fill_in_[1..8]`) stays in service
exactly as today — this plan does not touch the rate-monitoring path.

---

## 2. Datapath topology — before vs after

### 2.1 Current (87-b widened main path + snoop sideband)

```
mts_processor
  └─ aso_hit_type1_data (87 b: ts48 | type1[38:0])
       │
       └─ splitter 1:4 (87 b)
             │
             └─ rbCAM × 4   (asi_hit_type1_data 39 b + asi_hit_type1_metadata 64 b conduit)
                   │
                   └─ aso_hit_type2_data 36 b + aso_hit_type2_metadata 64 b
                         │
                         └─ feb_frame_assembly (36 b inputs)
                         └─ histogram_ingress_bridge.asi_post_data (84 b: ts48 | type2[35:0])
                               │
                               └─ histogram_statistics_v2.asi_fill_in_[1..8] (rate)
                               └─ histogram_statistics_v2 mode-1 delay (via bridge ts48 sideband)
       └─ histogram_ingress_bridge.asi_pre_data (87 b: ts48 | type1[38:0])
```

Issues:
- mts → splitter → rbCAM main wire is 87 b but rbCAM internally takes 39 b +
  metadata 64 b. The 87-b widening is dead weight on every adapter in
  between.
- delay-mode observability goes through the bridge, contending with the
  source-switch contract.

### 2.2 Proposed (narrow main + streaming debug plane)

```
mts_processor
  ├─ aso_hit_type1            : 39 b + sop/eop/ch/empty/err  ← reverted to original contract
  └─ aso_hit_type1_extended_0 : { ts48 , type1[38:0] }   data+valid only       ── upper bank
  └─ aso_hit_type1_extended_1 : { ts48 , type1[38:0] }   data+valid only       ── lower bank
       │
       │ splitter 1:4  (39 b only)
       │       │
       │       └─ rbCAM × 4  (39 b in, 36 b out, metadata conduit unchanged)
       │             │
       │             └─ feb_frame_assembly (36 b in, unchanged)
       │
       └──────── streaming debug plane ────────►   histogram_statistics_v2
                                                     ├─ asi_fill_in_[1..8]   (unchanged)
                                                     ├─ asi_hit_type1_extended_0
                                                     └─ asi_hit_type1_extended_1

histogram_ingress_bridge
  ├─ asi_pre_data  : 39 b   ← reverted (no ts48 in band)
  ├─ asi_post_data : 36 b   ← reverted (no ts48 in band)
  ├─ switch_safe   : KEEPS rev 26.0.6 fix (ignore pre_packet_active during run)
  └─ debug counters: KEEPS rev 26.0.9 (pre_seen / post_seen / hist_emit / hist_drop)
```

Phase B adds, on `feb_frame_assembly`:

```
feb_frame_assembly
  ├─ asi_hit_type2_[0..N] : 36 b (unchanged)
  └─ aso_hit_type2_extended_0 : { ts48 , type2[35:0] }   data+valid only      ── upper bank
  └─ aso_hit_type2_extended_1 : { ts48 , type2[35:0] }   data+valid only      ── lower bank
        │
        └───────── streaming debug plane ────────► histogram_statistics_v2.asi_hit_type1_extended_[0/1]
                                                     (same physical sinks, rewired in Qsys)
```

Phase A wires the histogram's extended sinks from `mts_processor`; Phase B
rewires the same sinks from `feb_frame_assembly`. The hist IP does not need
new ports between the two phases.

---

## 3. Interface contracts

### 3.1 `aso_hit_type1_extended_<bank>` on `mts_processor` (Phase A)

| signal | width | direction | source | notes |
| --- | --- | --- | --- | --- |
| `aso_hit_type1_extended_<b>_data`  | 87 b | out | `{ts48, hit_type1[38:0]}` | literally wired from the internal hit_out + true-ts counter |
| `aso_hit_type1_extended_<b>_valid` | 1 b  | out | gated only by "this beat is a real hit" | NOT gated by ready / backpressure / sop / eop |

Rules:
- No ready. No sop/eop/channel/empty/error. The hist IP never backpressures
  this port; if it does drop, the drop is silently absorbed.
- `valid='0'` iff the beat is line-idle / sub-header / framing only — i.e.
  exactly the same gate as the existing `aso_hit_type1_valid` does today
  when the beat is a real hit.
- The two banks (`_0` upper, `_1` lower) follow the existing FEB v3 bank
  partition. They are not muxed inside `mts_processor`; they are two
  independent streaming sources for the two banks.

### 3.2 `aso_hit_type2_extended_<bank>` on `feb_frame_assembly` (Phase B)

Same interface shape as 3.1, payload swap:
- `aso_hit_type2_extended_<b>_data : { ts48 , hit_type2[35:0] }` = 84 b
- `aso_hit_type2_extended_<b>_valid` = 1 b, gated only by "real hit beat"

The hist IP's extended-sink data port is 87 b (Phase A native). Phase B
lower-bits are 36 b instead of 39 b, so the upper 3 b of the 39-b slot are
zero-padded at the Qsys edge or treated as don't-care by the hist IP. Will
be specified concretely when Phase B is started.

### 3.3 `mts_processor` main datapath revert

| port | now | after |
| --- | --- | --- |
| `aso_hit_type1_data` | 87 b (`{ts48, type1}`) | **39 b** (`type1` only) |
| `aso_hit_type1_sop/eop/ch/empty/err` | unchanged | unchanged |

Internal compute that derives the 48-bit non-overflowing true ts is **not**
removed. It is reused as the source for `aso_hit_type1_extended_<b>_data`.

### 3.4 `histogram_ingress_bridge` snoop revert

| port | now | after |
| --- | --- | --- |
| `asi_pre_data`  | 87 b (`{ts48, type1}`) | **39 b** (`type1` only) |
| `asi_post_data` | 84 b (`{ts48, type2}`) | **36 b** (`type2` only) |
| `aso_pre_data`  | unchanged trim back to 39 | unchanged |
| `aso_post_data` | unchanged trim back to 36 | unchanged |

Keep:
- rev 26.0.6 `switch_safe` fix (BUG-005-R): drops the `pre_packet_active`
  block so source switches can land mid-run.
- rev 26.0.9 bridge-local CSR counters (`pre_seen`, `post_seen`,
  `hist_emit`, `hist_drop`).

Revert / drop:
- 26.0.7 / 26.0.8 48-b ts sideband widening and the host-side
  `{ts48,data}` payload tap that fed hist mode 1.

### 3.5 `histogram_statistics_v2`

Keep:
- 8× `asi_fill_in_[1..8]` (hit_type0 ingress, unchanged contract)
- existing CSR `mode` semantics for `asi_fill_in_*` (mode 0 normal,
  mode 1 currently sourced from the bridge sideband — that source is
  retired)

Add:
- `asi_hit_type1_extended_0_data : 87 b`
  `asi_hit_type1_extended_0_valid : 1 b`
- `asi_hit_type1_extended_1_data : 87 b`
  `asi_hit_type1_extended_1_valid : 1 b`

CSR widen:
- new CSR `in_port` (2 b minimum):
  - `0` (default) → 8× `asi_fill_in_*` (current rate/snoop path)
  - `1` → `asi_hit_type1_extended_0` (upper bank streaming plane)
  - `2` → `asi_hit_type1_extended_1` (lower bank streaming plane)
- existing CSR `mode` (4 b) keeps its current numbering; the **source** of
  the 48-b ts that mode 1 consumes is now derived from `asi_hit_type1_extended_<b>_data[86:39]`
  when `in_port ∈ {1, 2}` instead of the bridge sideband.
- mode 0 + `in_port ∈ {1, 2}` → trim the lower bits the same way `in_port = 0`
  does today (configurable update / filter key range applies to the lower
  payload word slice).
- mode 1 + `in_port ∈ {1, 2}` → take `data[86:39]` as the 48-b true hit ts,
  subtract the internal run-control GTS counter, bin modulo `SAR_TICK_WIDTH`.

The existing `mode = -7` combined-MTS-delay path is left alone for this
phase — it does not interact with the new extended-input plane.

---

## 4. Phase plan

### Phase A — MTS-Preprocessor side port (this phase)

Touch list:

1. **`mutrig_timestamp_processor/mts_processor.vhd`**
   - Revert `aso_hit_type1_data` width to 39 b. Drop the `{ts48,…}`
     packing on the main output. Keep the internal ts48 compute.
   - Add ports `aso_hit_type1_extended_<b>_data : 87 b` and `_valid : 1 b`
     for `<b> ∈ {0, 1}`, wired from the same internal `{ts48, hit_out}`
     state.
   - Version bump (history-block + `VERSION_PATCH`).
2. **`mutrig_timestamp_processor/mts_processor_hw.tcl`**
   - Drop the 87-b declaration on the `hit_type1` AST source; restore 39 b.
   - Add two new AST sources `hit_type1_extended_0`, `hit_type1_extended_1`
     with only `data` and `valid`. `associatedClock` / `associatedReset` as
     existing `hit_type1`. `USE_PACKETS = 0`. No ready.
3. **`misc/avst_snoop_splitter/avst_snoop_splitter.sv`** and instances:
   - Confirm `DATA_WIDTH = 39` for all 1:4 splitter instances on the hit_type1
     plane. No RTL edit expected if generics are already 39; just verify and
     bump packaging build date if it was set for 87 b anywhere.
4. **`histogram_statistics/rtl/histogram_ingress_bridge.vhd`**
   - Revert `asi_pre_data` 87→39 and `asi_post_data` 84→36. Drop the
     ts48 sideband forward path (no more bridge-side delay-mode tap).
   - Keep rev 26.0.6 + rev 26.0.9 changes intact.
   - Version bump to 26.1.0 (major bump on contract change is fine since
     the rev 26.0.x stream was never tagged as a release in the parent repo).
5. **`histogram_statistics/histogram_ingress_bridge_hw.tcl`** and `.svd`,
   `*_cmsis_svd.tcl`: revert `asi_pre` / `asi_post` widths; drop sideband
   metadata fields from the SVD.
6. **`histogram_statistics/rtl/histogram_statistics_v2.vhd`**
   - Add `asi_hit_type1_extended_0/1_data` (87 b), `_valid` (1 b).
   - Add CSR `in_port` (2 b) — register, default 0, programmable via
     existing csr write process.
   - Route the ingress mux on `in_port`:
     - `0` → existing 8-way merge (unchanged)
     - `1`/`2` → the chosen extended source, with the lower 39 b feeding the
       same internal "hit word" lane the fill_in[*] ports feed.
   - mode-1 ts48 source: pick from `data[86:39]` of the selected extended
     port when `in_port ∈ {1,2}`; fall back to existing source when
     `in_port = 0` (or simply force `mode = 0` for `in_port = 0` if mode-1
     was always paired with the snoop sideband).
   - Version bump (history block + `VERSION_PATCH`).
7. **`histogram_statistics/histogram_statistics_v2_hw.tcl`** and `.svd`:
   - Add the two extended AST sinks. `USE_PACKETS = 0`, no ready.
   - Add the `in_port` CSR field to the SVD.
8. **`firmware_builds/systems/v3_pretest-260511/script/`**:
   - Edit the FEB v3 Qsys script (`generate_feb_system_v3.sh` and the
     nested `mutrig_datapath_system_v3.qsys`) to:
     - Rewire splitter / rbCAM / frame_assembly to the 39-b mts output.
     - Add `mts_processor.hit_type1_extended_0 → hist.asi_hit_type1_extended_0`
       and the matching bank-1 wiring.
   - Regenerate.

Verification gate (Phase A done):
- `mutrig_timestamp_processor` standalone tb passes, including any UVM
  randomized hit run; new extended outputs are checked beat-aligned
  with `aso_hit_type1`.
- `histogram_statistics` standalone tb passes for `in_port = 0` (regression),
  `in_port = 1`, `in_port = 2` × `mode ∈ {0, 1}`.
- `histogram_ingress_bridge` standalone tb passes the existing
  `tb_histogram_ingress_bridge_switch` contract test (regression on the
  rev 26.0.6 fix).
- FEB v3 `tb_int` regression passes the existing buckets that exercise
  histogram ingress (the buckets that today read non-zero hits into the
  histogram via the bridge should still read non-zero hits into the
  histogram via `in_port = 0`; new buckets exercise `in_port = 1/2`).
- Standalone Quartus sign-off (`1.1× F_target`) for each touched IP
  closes per the project rule.

### Phase B — FEB-Frame-Assembly side port (later)

Touch list:

1. **`feb_frame_assembly/feb_frame_assembly.vhd`**
   - Add `aso_hit_type2_extended_<b>_data : 84 b` (`{ts48, type2[35:0]}`),
     `_valid : 1 b`, for `<b> ∈ {0, 1}`.
   - Reuse the existing hit_type2 output and the existing per-hit ts48
     bookkeeping (sourced from rbCAM's metadata conduit through the FA's
     internal compute).
2. **`feb_frame_assembly/feb_frame_assembly_hw.tcl`**: add the two AST
   sources as in Phase A §2.
3. FEB v3 Qsys: rewire the histogram's extended sinks from `mts_processor`
   to `feb_frame_assembly` (same hist IP, different Qsys wiring).
4. **Histogram IP**: no port changes. The 84-b payload occupies the
   lower 36 b of the 39-b lower-bits slot (3 MSBs zero-padded). Document
   the slot allocation in the IP's SVD.

Verification gate: equivalent to Phase A — standalone tb on `feb_frame_assembly`
covering the new extended sources; FEB tb_int regression with `in_port = 1/2`
sourced from FA.

---

## 5. What this plan does **not** change

- `asi_fill_in_[1..8]` rate-monitoring ingress on the hist IP and the
  bridge logic that feeds it.
- `histogram_ingress_bridge` `switch_safe` BUG-005-R fix (rev 26.0.6).
- `histogram_ingress_bridge` debug counters (rev 26.0.9).
- rbCAM, `feb_frame_assembly` main hit_type1/hit_type2 widths.
- the existing `coe_hit_type1_sidecar_*` 64-b conduit on `mts_processor`
  and `coe_hit_type0_sidecar_*` on the parser. Both stay as debug-only
  metadata for downstream tap users; they are independent of the new
  AST streaming plane.

---

## 6. Migration risks

| risk | mitigation |
| --- | --- |
| Qsys auto-adapter on `_extended` sink because `USE_READY` not set to 0 on both ends | declare `set_interface_property … USE_READY 0` on both the source (`mts_processor`) and the sink (`histogram_statistics_v2`) hw.tcl; verify the generated `.vhd` shows no auto-inserted timing_adapter / clock_bridge on the new wires |
| `aso_hit_type1_data` width change breaks downstream that snapshotted 87 b | grep `mu3e-ip-cores` and `firmware_builds/` for `87` near `hit_type1` and update each occurrence in one sweep before regenerating Qsys |
| `mode = 1` semantics depended on bridge sideband; new path changes the upstream of `data[86:39]` | retain the same internal subtract-against-GTS arithmetic; the only change is the source of the 48-b ts |
| `in_port` change during run could mid-frame-swap the histogram input | apply the `in_port` change synchronously with the existing fill-in mux's idle-gate logic |

---

## 7. Open items for the review

- Is the extended port payload `{ts48, type1[38:0]}` or `{type1[38:0], ts48}`
  (i.e. ts48 in upper bits vs lower)? Plan picks ts48 in upper bits so the
  hist IP can slice `data[86:39]` for delay-mode and `data[38:0]` for normal
  trim — consistent with how `mode = 1` reads the 48-b ts today.
- Should `mts_processor` expose **one** extended port pair (`_0`/`_1`)
  per FEB or **one** port per ASIC channel? Plan defaults to one pair
  per bank (matches current FEB v3 bank topology and the user's two-input
  hist IP design).
- Phase B 84-b vs 87-b shape: pad in the FA's hw.tcl or in the hist IP?
  Plan suggests Qsys-side zero-pad at the FA edge so the hist IP keeps a
  single 87-b sink contract for both phases.

---

## 8. Deliverables (Phase A)

- Per IP, per repo:
  - RTL edit + version-history block + `VERSION_PATCH` bump
  - `_hw.tcl` edit + AUTHOR / DATE / GIT default bump
  - `.svd` and `*_cmsis_svd.tcl` edit
  - Standalone tb regression run (`make run` / `make run_after`)
  - Standalone qverify static screen (Lint/CDC/RDC) clean
  - Standalone Quartus signoff at 1.1× F_target clean
- FEB v3 Qsys regeneration produces an updated synthesis tree where:
  - mts → splitter → rbCAM → FA wires are 39 / 36 b on the main plane.
  - mts → hist extended_0/1 wires exist on the streaming debug plane.
- `tb_int` regression on `firmware_builds/systems/v3_pretest-260511/tb_int`
  passes (basic + at least one delay-mode bucket).
- BUG_HISTORY entry on each touched IP capturing the contract change.

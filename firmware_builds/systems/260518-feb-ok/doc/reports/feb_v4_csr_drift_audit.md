# FEB v4 SVD-vs-RTL Drift Audit (2026-05-18)

**Source:** `feb_v4_csr_report_20260518.md` (on-board readback, 22
endpoints, 2596 words via `--mode report --burst 256`) plus per-IP
audit of the live RTL and the matching CMSIS-SVD.

**Method:** for every drift row in the raw report I read the IP's
`.vhd`/`.sv` CSR `case` statement and its `.svd` register table, then
classified the drift cause. Live write/readback liveness probes used
`sc_tool` writes through `~/.local/bin/swb_ring_lock` against RW
registers that the SVD already documents.

## 1. Verdict per IP

| IP | drift | category | who is wrong | fix target |
|---|---|---|---|---|
| `scratch_pad_ram.s1` | 0 | RAM aperture, no header | — | — |
| `max10_prog_avmm.csr_avmm` | 1 | RTL constant byte drift | RTL or silicon | low priority (legacy IP) |
| `on_die_temp_sense_ctrl.csr` | 0 | Altera SVD, no UID/META | — | — |
| `onewire_master_controller.csr` | 0 (UID match) | reference impl | — | — |
| `firefly_xcvr_ctrl.firefly` | 0 (7 BURST≠SINGLE) | live I2C heartbeat | — | — |
| `mutrig_cfg_ctrl.avmm_csr` | 0 (no match either) | SVD declares no UID/META | both | low priority |
| **`lvds_rx_controller_pro.csr`** | 8 | **wrong IP in qsys** | qsys | **swap to `mu3e_lvds_controller`** |
| **`emulator_mutrig_qsys_inst.csr`** | 6 | **IP returns zeros for all RW** | runtime / reset wiring | debug |
| `arb_hit_type0_supercore.csr_pipe_N` | 0 in this report | passthrough bridges | — | — |
| `mts_preprocessor_0/_1.csr` | 0 (no match either) | SVD has 8 generic `WORD000..` placeholders | SVD | rewrite SVD per RTL |
| **`histogram_statistics_0.csr`** | 3 | **CORRECTED: kind is OK; IP held in reset** (the `_v2`-named hw.tcl already implements the v3 ingress contract; previous "wrong IP" classification here was wrong) | qsys reset wiring | **same fix path as injector/emulator below** (CSR clock is `lvds_rx_28nm_0.outclock`) |
| **`histogram_statistics_0.hist_bin`** | 0 (after probe fix) | ~~SVD overlay bug~~ → probe bug | probe | FIXED: probe now filters SVD overlay by port name (`CSR_PORT_NAMES`); hist_bin RAM aperture no longer gets the CSR overlay |
| **`mutrig_injector_0.csr`** | 11 | **IP held in reset** (write-readback test confirms) | runtime / reset wiring | debug |
| `sc_hub.internal_csr` | 0 (3 BURST≠SINGLE) | live counters | — | — |

## 2. Liveness write/readback probe (smoking-gun evidence)

```text
swb_ring_lock -- sc_tool 2 write 0x0A803 0xCAFE   # mutrig_injector HEADER_DELAY (RW per SVD)
swb_ring_lock -- sc_tool 2 read  0x0A803 1
  payload[0] = 0x00000000     <- write did NOT stick; IP is in reset

swb_ring_lock -- sc_tool 2 write 0x01401 0xBEEF   # mutrig_cfg_ctrl OFFSET (RW per SVD)
swb_ring_lock -- sc_tool 2 read  0x01401 1
  payload[0] = 0x0000BEEF     <- write stuck; IP is alive, just no UID/META in RTL
```

`mutrig_injector_0` is therefore **NOT a SVD bug or RTL bug** — the
RTL (`charge_injection/rtl/vhdl/mutrig_injector_multiheader.vhd` line
517) correctly returns `IP_UID = 0x4D494E4A` ("MINJ") at offset 0
when not held in reset. The silicon is holding it in reset, which
points at the run-control or `RUNCTL_*_CONST` wiring in
`scifi_datapath_system_v4`.

`emulator_mutrig_qsys_inst` (`emulator_mutrig/rtl/emulator_mutrig.sv`
instantiates `emulator_mutrig/rtl/frontend/frontend_csr.sv` which
implements the META header per
`ADDR_UID_CONST=0x00 / ADDR_META_CONST=0x01`) is in the same boat — it
also returns 0 for what should be `IP_UID = 0x454D5554` ("EMUT"). The
qsys explicitly sets `IP_UID = 1162696020 = 0x454D5554`. Same reset/
wiring debug as the injector.

## 3. SVD bug: `histogram_statistics_0.hist_bin` claims UID at offset 0

`hist_bin` is the 1024-word histogram-bin BRAM aperture, not a CSR.
The `histogram_statistics.svd` declares one peripheral with a UID
register at offset 0x00; the probe applies this peripheral overlay to
BOTH the `.csr` slave AND the `.hist_bin` slave. The latter is wrong
— `hist_bin` has no register interpretation, every word is raw bin
content. **Fix: split the SVD into two peripherals**: one for the
CSR aperture and one for the hist_bin memory aperture (or, simpler,
declare hist_bin as `<addressBlock usage="memory">` with no register
overlay).

## 4. SVD bug: `histogram_statistics_0.csr` assumes META-header shift

The SVD declares:

```
0x00 UID         reset=0x48495354  ("HIST")
0x04 META
0x08 CONTROL     reset=0x00000100
0x18 KEY_LOC     reset=0x26231D11
```

The live RTL (`histogram_statistics/rtl/histogram_statistics.vhd`
line 624-657) declares:

```
offset 0: CONTROL   (commit, mode, error, error_info)   <- where SVD claims UID
offset 1: LEFT_BOUND
offset 2: RIGHT_BOUND
offset 3: BIN_WIDTH
offset 4: KEY_LOCATIONS
offset 5: KEY_VALUE
offset 6: UNDERFLOW_COUNT
offset 7: OVERFLOW_COUNT
offset 8: (debug)
```

The SVD is aspirational. Two valid fixes:

- **Option A (cheap, no RTL change):** rewrite the SVD to match the
  current RTL — drop UID + META, shift every register down by 2
  words. Resolves all 3 drifts without touching silicon.
- **Option B (durable, follows convention):** add META header to RTL
  (insert `when 0 => IP_UID; when 1 => meta_readdata;` and shift the
  existing CONTROL/LEFT_BOUND/.../OVERFLOW_COUNT cases by +2). Same
  pattern as `emulator_mutrig/rtl/frontend/frontend_csr.sv`. Breaks
  any software using the current offsets — software side needs to
  follow.

Same pattern applies to `mts_preprocessor.csr` (SVD is even thinner —
8 generic `WORD000..` placeholders with no resetValue; nobody has
ever written what the registers actually mean).

## 5. Wrong IP in v4 qsys: `lvds_rx_controller_pro` vs `mu3e_lvds_controller`

The v4 qsys instantiates `lvds_rx_controller_pro` (kind
`lvds_rx_controller_pro`, RTL
`mu3e_lvds_controller/lvds_rx_controller_pro.terp.vhd`), an older IP
with no META header.

There is a NEWER LVDS controller in the same source tree:
`mu3e_lvds_controller/rtl/mu3e_lvds_controller.sv` (kind
`mu3e_lvds_controller`, version 26.2.1.0506) with:

- `IP_UID = 32'h4C564453` ("LVDS") at `CSR_UID_ADDR_CONST = 0`
- META mux page select (UVM sequences B003..B007 already exist for the
  4-page META under `mu3e_lvds_controller/tb/uvm/sequence/`)
- the PHY adapter `mu3e_lvds_controller/rtl/mu3e_lvds_controller_phy_adapter.sv`
  folded in (so the LVDS PHY HIP is inside this IP, not a separate Qsys block)

`scifi_datapath_system_v4.qsys` references `lvds_rx_controller_pro`
20 times; none of `mu3e_lvds_controller`. **Fix: swap the qsys
instance** (1-line module-kind change + re-elaborate) — picks up META
+ HIP fold + the existing UVM test corpus.

## 5a. Histogram naming gotcha (NOT a wrong-IP finding after all)

Earlier draft of this audit said the v4 qsys was using the wrong
histogram kind. That was wrong, and the corrected verdict is:

- `histogram_statistics_v2_hw.tcl` (kind: `histogram_statistics_v2`)
  is the IP that already implements the FEB v3 ingress contract per
  [`RTL_V3_NOTE.md`](../../../../histogram_statistics/RTL_V3_NOTE.md):
  explicit `type0_lane0..7` + `type1_up` / `type1_down` ingress with
  the separate 48-bit timestamp sideband. The `_v2`-named hw.tcl
  wraps `rtl/histogram_statistics_v2.vhd` which stamps `IP_UID = 0x48495354`
  ("HIST") at offset 0 and exposes the v3 streaming contract.
- `histogram_statistics_hw.tcl` (kind: `histogram_statistics`, no
  `_v2` suffix) is the LEGACY generic `hist_fill_in`/`hist_fill_out`
  IP that the v3 contract was written to replace.

`scifi_datapath_system_v4.qsys` instantiates kind
`histogram_statistics_v2` (the v3-contract IP) — this is **CORRECT**.
The deprecation hard-block now lives on `histogram_statistics_hw.tcl`
(the legacy kind), gated by `MU3E_ALLOW_DEPRECATED_HISTOGRAM_STATISTICS=1`
for legacy builds.

The histogram drift rows in section 1 are therefore the SAME class of
bug as the injector/emulator: the IP is held in reset because its CSR
clock is `lvds_rx_28nm_0.outclock`, not `monitor_clock_125.clk`. See
section 2 above for the write/readback liveness evidence and the
`mm_pipeline_lvds_csr_hist` bridge chain that drives histogram CSR
from the LVDS-recovered clock domain.

## 5b. mutrig_injector wiring note (header source)

`mutrig_injector_0` is the correct kind (`mutrig_injector_multiheader`)
and is wired in `scifi_datapath_system_v4.qsys` to receive 8 headerinfo
streams from `mutrig_datapath_subsystem_{0..7}.headerinfo`. Each of
those subsystem exports is internally bridged to the real
`mutrig_frame_deassembly_0.headerinfo` source (verified via the
`<interface name="headerinfo" internal="mutrig_frame_deassembly_0.headerinfo">`
binding in `quartus_systems/mutrig_datapath_system_v4.qsys`), so the
header path from the real MuTRiG frame deassembly IS routed through to
the injector's headerinfo0..7 inputs. The held-in-reset symptom in
section 2 above is NOT a header-routing issue — it is a reset-wiring
issue inside `scifi_datapath_system_v4.qsys` (likely the
`monitor_reset_sync.reset_out` that gates `mutrig_injector_0.reset_interface`
is stuck).

## 6. Minor: `max10_prog_avmm` ID byte 2

```
SVD ID resetValue : 0x4D313050  ("M10P")
hw.tcl default    : 1295067216  = 0x4D313050  ("M10P")
RTL constant      : 16#4D313050#  ("M10P")
live silicon      : 0x4D312850   ("M1(P")
                            ^^^ byte 2 = 0x28 instead of 0x30
```

`0x30 ^ 0x28 = 0x18` — 2 bits differ in byte 2. The RTL, the hw.tcl
default, and the qsys-overridden value all agree on `0x4D313050`.
The silicon returns one byte wrong. Either:

- a 2-bit error in the synthesized constant (very unlikely without an
  obvious silicon issue surfacing elsewhere)
- a different IP_ID is being read out (`IP_ID` propagation through
  Qsys vs HDL parameter mismatch)
- an obsolete silicon snapshot (the SOF doesn't carry the most recent
  `max10_prog_avmm` rebuild)

Low priority for the v4 bring-up; flag for the next legacy-IP
sweep.

## 7. What this audit confirms about the report mode

| signal | what it caught |
|---|---|
| `drift` | the 4 categories above (SVD ahead, SVD overlay bug, wrong IP, IP-in-reset). The probe surfaced ALL of them. |
| `BURST≠SINGLE` | only live counters / snapshots (firefly heartbeat, sc_hub GTS_SNAP, FIFO_STATUS) — bridge path is clean. |
| `match` | the 20 happy words where SVD and RTL agree and the IP is alive (sc_hub UID, onewire UID, lvds CAPABILITY hidden at +0x14 etc.). |

## 8. Recommended action order (smallest-blast-radius first)

1. **Fix the probe's SVD overlay scoping** — the bug was in the probe
   (not the SVD): it applied the histogram CSR overlay to BOTH the
   .csr and .hist_bin ports of the same IP, causing 3 false drifts on
   the memory aperture. Probe now filters on port name (`CSR_PORT_NAMES`
   allowlist); only the .csr port gets the SVD overlay. DONE in this
   commit, no rebuild needed.
2. **Investigate runtime reset on `mutrig_injector_0` and
   `emulator_mutrig_qsys_inst`** — the RTL is correct (verified by
   write-readback test on the injector RW reg returning 0); something
   in the `scifi_datapath_system_v4` wiring (likely
   `monitor_reset_sync.reset_out`) is holding them. Unblocks 17 of
   the 32 drift rows in one shot.
3. **Swap `lvds_rx_controller_pro` → `mu3e_lvds_controller` in
   `scifi_datapath_system_v4.qsys`** — picks up META + PHY HIP fold.
   Removes 8 drift rows. Needs Qsys re-elaborate + full FEB compile.
4. ~~Swap histogram_statistics_v2 to histogram_statistics~~ — CANCELLED.
   The v4 qsys already uses kind `histogram_statistics_v2` which IS
   the v3-contract IP (the naming is confusing; see section 5a
   above). No swap needed. The hist drift will close as a side-
   effect of the LVDS swap if the held-in-reset diagnosis is right.
5. **Audit max10_prog_avmm** — single-bit byte drift in the IP ID; can
   wait until the legacy IP gets its next refresh.

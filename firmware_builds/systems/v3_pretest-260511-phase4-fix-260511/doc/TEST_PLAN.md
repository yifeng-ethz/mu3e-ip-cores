# FEB SciFi v3 On-Board Test Plan

**Revision**: 2026-04-20 / draft-0
**Target**: `mu3e-ip-cores/firmware_builds/feb_system_v3` on FEB SciFi prototype
**Host**: teferi (`yifeng@teferi`, `/dev/mudaq0` via SWB on link 2)
**Authoring scope**: comprehensive on-board sign-off — not a liveness smoke test.
Each phase is designed to exercise enough of the datapath to surface asymmetries,
stale-data hazards, CDC glitches, protocol-regression, and address-map drift
that a simple `read UID → print` run would miss.

**2026-04-21 validation note**: the active software/tooling path in this repo
now targets QuestaOne 2026 (`/data1/questaone_sim/questasim`) and headless
local `sc_tool` / `rc_tool` builds from `systems/system_20260427_testplanphase5/script/`. Treat any older
references elsewhere to FE/FSE-era simulator assumptions as historical, not as
the current bring-up path.

---

## 0. Hardware, firmware, and source-of-truth

### 0.1 Board wiring and link map

| Board | Role | PCIe endpoint | JTAG cable tag | SC link index |
|---|---|---|---|---|
| SWB (A10 DE5) | SC master, reset-link master | `1172:0004` → `/dev/mudaq0` | `DE5 [3-6.2]` | — |
| FEB SciFi | DUT | — | `USB-BlasterII [7-2]` | **2** (per memory `feb_scifi_link_mapping`) |

The FEB SciFi is on **SWB SC link 2**. `LINK_LOCKED_HIGH_REGISTER_R = 0x00000F00`
(bits 8..11 set) is **other** boards and does not confirm the SciFi FEB is up —
the SciFi link bit is in the low link-lock register. The full test plan assumes
only link 2 is being driven; other links may be unplugged.

### 0.2 Firmware source of truth (do not confuse)

| Board | SOF | Repo | Rationale |
|---|---|---|---|
| SWB | `online_sc/online/switching_pc/a10_board/output_files/top.sof` | `online_sc` | `online_dpv2` SWB SOF leaves BAR decoding garbage; sc_tool then sees a fake flood of tens of thousands of SC preambles per second (root-caused 2026-04-13, recovery procedure below) |
| FEB | `firmware_builds/<feb_scifi_v3_project>/output_files/top.sof` (this repo) | `mu3e-ip-cores/firmware_builds` | v3 under test |

**Pre-flight checklist before any test below:**

1. `jtagconfig -n` — expect `DE5 [3-6.2]` and `USB-BlasterII [7-2]`.
2. Flash SWB with `online_sc` top.sof (if cold-booted or toggled since last SC probe).
3. Flash FEB SciFi with v3 top.sof.
4. `sudo -n /usr/local/sbin/mudaq_recover_pcie` — if `/dev/mudaq0` reads return
   all-ones, or after any SWB reflash. **Do not** use `pcie_uio_rescan`.
5. `lsmod | grep mudaq` then `ls /dev/mudaq0` — both must succeed.
6. `../systems/system_20260427_testplanphase5/script/build_local_tools.py` — refresh `systems/system_20260427_testplanphase5/bin/sc_tool` and
   `systems/system_20260427_testplanphase5/bin/rc_tool` from the local sources before relying on any stale
   installed copy.
7. `../systems/system_20260427_testplanphase5/script/sc_tool read 0x00000` (scratch_pad_ram @ word 0) — must return a
   well-formed 32-bit reply, not `0xffffffff`.
8. `../systems/system_20260427_testplanphase5/script/check_ip_metadata.py` — VERSION/GIT cross-check over SC and JTAG
   must pass for every reachable IP that exposes live metadata.
9. Kill any stale `system-console` holding JTAG (memory `kill_system_console`).

### 0.3 Tools used (in `../systems/system_20260427_testplanphase5/script/`)

| Tool | Purpose |
|---|---|
| `build_local_tools.py` | Build the local `sc_tool` / `rc_tool` copies into `systems/system_20260427_testplanphase5/bin/` using the checked-in sources in `../systems/system_20260427_testplanphase5/script/`. |
| `sc_tool` | 18-bit-word SC transactions. All register probing goes through this tool. **test_slowcontrol is deprecated (memory `sc_hub_word_addressed`) — do not use.** |
| `rc_tool` | Send reset-link command bytes from SWB, read `RESET_LINK_STATUS_REGISTER_R` for state echo. |
| `extract_svd_inventory.py` | Resolve every reachable Qsys slave to its SVD file, SC word base, JTAG byte base, and VERSION/GIT capability. |
| `check_ip_metadata.py` | Bring-up metadata audit. Reads VERSION and GIT via SC hub and JTAG, then compares the live values against SVD and Qsys metadata. |
| `check_sc_bridges.py` | Phase-1 bridge audit. Verifies SC reachability through `mm_bridge` into datapath leaves, plus SC/JTAG reachability through `upload_mm_bridge` into `runctl_mgmt_host_0.csr`. |
| `jtag_rw.tcl` | Generic headless JTAG AVMM read/write helper for direct fallback probing. |
| `inject_runcmd.tcl` | JTAG-master fallback for directly poking `runctl_mgmt_host_0.CSR_LOCAL_CMD`. Use only when the reset-link path is not trusted; the primary path in Phase 3 is `rc_tool`. |
| `run_atpg_v2_reference.sh` | Reference Phase-2 BIST runner, now path-hardened to the local board-test tool layout. |
| `run_rc_reg_v2_reference.sh` | Reference Phase-3 reset-domain runner, now path-hardened to the local board-test tool layout. |

libmudaq is from `online_dpv2`; v3 libmudaq is an open item (`../systems/system_20260427_testplanphase5/script/README.md` §Build).
For the tests below this is acceptable: the SWB-side SC register addresses are
part of the `online_sc` SOF, not the FEB v3, and libmudaq only wraps those.

### 0.4 Host-side address translation (critical)

`sc_hub v2` packets are **word-addressed** (`byte_addr / 4`). This is the only
address representation used in the tables below. Verified 2026-04-16; `sc_tool`
masks input to 18 bits via `sc_addr_mask = 0x0003ffff`. Do **not** send Qsys
byte addresses to `sc_tool` — they will land on the wrong word and the reply
will decode as random data (or a legitimate `ack=OK` but for the wrong
register).

---

## 1. Phase 1 — Bring-up: per-slave register audit

**Goal**: Every slave on the SC hub responds, UID matches SVD, VERSION/GIT
metadata matches the packaged SVD plus Qsys integration values where exposed,
and RO status registers return values consistent with the board being quiescent
(no injection enabled, no run armed, no FIFO back-pressure).

**Out of scope**: writes, resets, run-control commands. This phase is read-only
and must be safe to run after any cold boot.

### 1.0 Metadata gate before per-register audit

Run `../systems/system_20260427_testplanphase5/script/check_ip_metadata.py` first. This is the fast-fail guard against:

- stale SVD packaging,
- Qsys parameter drift relative to the packaged IP,
- wrong JTAG master selection,
- SC/JTAG path disagreement on the same live IP.

Any VERSION or GIT mismatch found here is a Phase-1 blocker. Do not continue to
the per-register audit until the metadata report is clean or the mismatch is
explained and recorded as an explicit exception.

Then run `../systems/system_20260427_testplanphase5/script/check_sc_bridges.py`. This is the focused bridge gate for the
two exported apertures added in v3: it proves that the SC path reaches the
bridged datapath leaves behind `mm_bridge`, and that the upload/run-control
window behind `upload_mm_bridge` is visible over both SC and JTAG before later
reset-link tests are trusted.

### 1.0.bis IP version/build cross-check (live-vs-source)

For every reachable IP on the FEB SC ring, read the standard 4-word metadata
page (UID at offset 0x00 + META at offset 0x04 + STATUS/INSTANCE at the
subsequent two words) and compare every live value against the local build
source of truth. The source-of-truth precedence for each IP is:

1. The IP's `_hw.tcl` and SVD under `mu3e-ip-cores/<ip>/`.
2. The IP's RTL `parameter`/`generic` defaults (`VERSION_MAJOR`,
   `VERSION_MINOR`, `VERSION_PATCH`, `BUILD`, `VERSION_DATE`,
   `VERSION_GIT`, `IP_UID`).
3. Any explicit Qsys parameter override in `firmware_builds/systems/<this-build>/script/*.tcl`
   or `firmware_builds/systems/<this-build>/syn/*.qsys` `<parameter ...>` lines.
4. The host-side header `a10_pcie_registers.h` (autogenerated for the FEB
   build) when it covers a register.

Procedure for every IP:

```bash
LOCK=/home/yifeng/.local/bin/swb_ring_lock
SCT=/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/tools/run_script/build/sc_tool
$LOCK $SCT 2 read <UID_word_addr>
$LOCK $SCT 2 read <META_word_addr>      # META page 0 = packed VERSION
# For IPs that expose VERSION_DATE on a META subpage, write meta_sel via the
# CSR write port and re-read META, OR observe the page-0 packed VERSION only.
```

`META` page 0 layout (Mu3e house style):

```
META[31:24] = VERSION_MAJOR (8 bits)
META[23:16] = VERSION_MINOR (8 bits)
META[15:12] = VERSION_PATCH (4 bits)
META[11:0]  = BUILD          (12 bits, integration-overridable; typically a
                              decimal MMDD or a small monotone counter)
```

Expected outcomes:

- Live UID **matches** the source-of-truth UID literal exactly.
- Live META `VERSION_MAJOR.VERSION_MINOR.VERSION_PATCH` **matches** the
  RTL/Qsys source.
- Live `VERSION_DATE` (when reachable) is greater than or equal to the
  source `VERSION_DATE` (forward-compat: the on-chip build may be newer
  than what the local source tree shows if the firmware was minted from
  a downstream commit).
- Live `VERSION_GIT` matches the source `VERSION_GIT` when exposed.

A live value that **regresses** below the source (e.g. live VERSION_DATE
older than the source-of-truth date) is a Phase-1 blocker — it means the
SOF on the board is older than the local source tree and every downstream
phase will be testing the wrong firmware.

A live value that is **newer** than the source is acceptable and must be
documented as a known forward-compat drift; record the live values verbatim
in the phase-1 evidence log so later phases can be re-interpreted if the
local source tree is updated.

### 1.1 SC-hub primary (`debug_sc_system_v3`) slave map

The following addresses are verified from `firmware_builds/systems/system_20260427_testplanphase5/syn/debug_sc_system_v3.qsys`
(byte addresses converted to `sc_tool` word addresses). Phase 1 now treats both
exported bridges as first-class audit targets: the datapath behind
`mm_bridge` and the upload/run-control CSR aperture behind `upload_mm_bridge`
must both be reachable before later phases are trusted.

| Slave | Qsys byte base | `sc_tool` word addr | UID expected | VERSION expected (META page 0) | Source path | Probes |
|---|---|---|---|---|---|---|
| `scratch_pad_ram` | `0x00000` | `0x00000` | n/a (RAM) | n/a | Qsys built-in RAM | §1.2 |
| `onewire_master_controller_0` | `0x11000` | `0x04400` | `0x4F574D43` ("OWMC") | `26.2.1.MMDD` packed | `onewire_temp_sense/rtl/vhdl/onewire_master_controller/onewire_master_controller.vhd` | §1.3 |
| `max10_prog_avmm_0` | `0x12000` | `0x04800` | `0x4D312850` ("M1(P") | `0.1.0.0` (RTL default, build still in flux) | `feb_max10_comm/legacy/max10_prog_avmm/rtl/max10_prog_avmm.vhd` | §1.4 |
| `charge_injection_pulser_0` | `0x13000` | `0x04C00` | **WO — skip read** | n/a | `charge_injection/legacy/charge_inj_pulser.vhd` | §1.5 |
| `firefly_xcvr_ctrl_0` | `0x14000` | `0x05000` | n/a (no UID exposed) | n/a | `firefly_xcvr_i2c_master/firefly_xcvr_ctrl.vhd` | §1.6 |
| `on_die_temp_sense_ctrl` | `0x15000` | `0x05400` | n/a (no UID exposed) | n/a | `alt_temp_sense_controller/altera_temp_sense_ctrl.vhd` | §1.7 |
| `legacy_firefly_bridge` | `0x16000` | `0x05800` | n/a (bridge) | n/a | Qsys bridge | §1.8 |
| `mm_bridge` (to datapath) | `0x20000` | `0x08000` | bridge span | n/a | Qsys bridge | §1.9 + Phase 4 |
| `→ emulator_mutrig_0..7.csr` (via mm_bridge) | `0x20|2000..|21C0` | `0x08800..0x08870` | `0x454D5554` ("EMUT") | `26.3.0.<BUILD>` (BUILD = decimal day, currently 506) | `emulator_mutrig/rtl/emulator_mutrig.sv` | §1.9 |
| `→ dbg_mm2runctrl_0.csr` (via mm_bridge) | `0x20|2200` | `0x08880` | `0x4D325243` ("M2RC") | non-META; reg[1]=`0x00000801` is HW-status | `misc/dbg_issp_fab/dbg_mm2runctrl.sv` | §1.9 |
| `→ histogram_statistics_0.csr` (via mm_bridge) | `0x20|A400` | `0x0A900` | `0x48495354` ("HIST") | `26.1.6.429` per Tcl override; RTL default is `26.1.6.<git>` | `histogram_statistics/rtl/histogram_statistics_v2.vhd` + `script/update_scifi_datapath_v3_histogram_stats.tcl` | §1.9 |
| `→ histogram_statistics_0.hist_bin` (via mm_bridge) | `0x20|A000` | `0x0A800` | n/a (RAM) | n/a | Qsys ping-pong RAM | §1.9 |
| `→ histogram_ingress_bridge_0.csr` (via mm_bridge) | `0x20|AC00` | `0x0AB00` | `0x48495342` ("HISB") | `26.0.2.<MMDD>` | `histogram_statistics/rtl/histogram_ingress_bridge.vhd` | §1.9 |
| `upload_mm_bridge` (to upload/runctl CSR) | `0x30000` | `0x0C000` | bridge span | n/a | Qsys bridge | §1.10 + Phase 3 |
| `→ runctl_mgmt_host_0.csr` (via upload_mm_bridge) | `0x30|0000` | `0x0C000..0x0C013` | `0x52434D48` ("RCMH") | `26.3.0.<BUILD>` (RTL says 12'h505; live shows 505 dec = May 5) | `run-control_mgmt/rtl/runctl_mgmt_host.sv` | §1.10 |
| `mutrig_cfg_ctrl_0.avmm_csr` | `0x3F010` | `0x0FC04` | n/a (cfg CSR, no UID exposed) | n/a | `mutrig_controller/mutrig_ctrl.vhd` | §1.11 |

The "VERSION expected" column is the META page-0 packed `{MAJOR,MINOR,PATCH,BUILD}`
word. The BUILD field is integration-overridable so the exact value floats with
each FEB recompile; treat the live readback as authoritative once the live
UID + MAJOR.MINOR.PATCH triple matches the source.

### 1.2 Scratchpad pre-flight — non-destructive

`scratch_pad_ram` is the canonical health check. In Phase 1 we do **reads only**
against a range we will then re-use destructively in Phase 2 BIST §2.1.

Procedure:

```bash
# Read first 16 words
for a in $(seq 0 15); do ./sc_tool read $(printf "0x%05x" $a); done
# Expect 16 lines, each ack=OK, each with a deterministic but undefined
# power-on value. Record the values for "restore" in BIST.
```

Failure modes to catch:

- **No reply / timeout** ⇒ SC preamble never reached scratchpad. Check SC
  link-lock bit, then the sc_hub primary ring on SignalTap (`sc_main` packet
  in-progress signal — §4.3 trigger `SC_TORN_PKT`).
- **`ack != OK` or `rsp != 2'b00`** ⇒ sc_hub is replying with SLVERR. Record
  the exact `(addr, ack, rsp)` triple; compare against the decoded `ack`/`rsp`
  fields per the `sc_hub v2` overlay (memory `sc_hub_word_addressed`).
- **All reads return `0xFFFFFFFF`** ⇒ `/dev/mudaq0` is in BAR-garbage state
  (the `online_dpv2` SWB SOF regression). Rerun §0.2 step 2 and §0.2 step 4.

### 1.3 onewire_master_controller_0 (word `0x04400`)

Per `onewire_master_controller_0` SVD, the UID register (offset 0) is a
32-bit magic. Read:

- `word_addr = 0x04400` → expect the documented UID literal.
- `word_addr = 0x04401` → version; must equal the `version=` attribute on the
  module instance in `debug_sc_system_v3.qsys`.
- `word_addr = 0x04402..0x0440F` → status / device address / last-byte-read.
  These are all RO or RW-scratch; the bring-up check is that every address in
  the declared aperture returns `ack=OK` and does **not** hang.

Failure-to-catch: silent aperture under-decode (hub replies OK on every address
up to slave span, but the slave itself ignored the read). Check: read two
out-of-range words (e.g. `0x0440F + 1`, `0x04500`); both must return either
a decoded slave register or a `SLVERR` from the hub — **not** the same value
as the in-range register. If they return the same value, the hub is reflecting
the last ring datum (stale preamble reuse) and the test stops.

### 1.4 max10_prog_avmm_0 (word `0x04800`)

Same audit pattern as §1.3. UID and version register per
`common/max10_prog_avmm/max10_prog_avmm.svd`. This slave is a programming
interface — `start`/`command` bits are RW but must be left at zero after
bring-up. Record the contents of the status register `[31:16]=rd_data`.

### 1.5 charge_injection_pulser_0 (word `0x04C00`)

**Write-only per SVD** (`charge_injection_pulser.svd`): reads are not
implemented. Phase 1 behavior: issue one read to confirm the hub replies (OK
or SLVERR — both are acceptable), then skip; the write paths are covered in
Phase 4 under `enable=0` guard.

### 1.6 firefly_xcvr_ctrl_0 (word `0x05000`)

14-word aperture, RW head (I²C command / data), RO tail (last-read data +
status). Per `firefly_xcvr_ctrl.svd`:

| Offset (byte) | Word addr | Field | Check |
|---|---|---|---|
| `0x00` | `0x05000` | FF1_TEMP_STATUS (RW, `[7:0]=temperature`) | Read, record. Temp in a sane board range (15–60 °C). |
| `0x04` | `0x05001` | ... | Iterate through SVD; check `ack=OK` on every word. |

Do **not** trigger an I²C transaction in Phase 1. Set `start=0` guard by
avoiding writes to the `COMMAND` register.

### 1.7 on_die_temp_sense_ctrl (word `0x05400`)

Per `on_die_temp_sense.svd`. Read temperature, record. Failure mode:
temperature reads `0x00` or `0xFF` — sensor not initialized. Not a Phase 1
blocker but a flag for follow-up.

### 1.8 legacy_firefly_bridge (word `0x05800`)

Bridge. Read one word to confirm it responds; no SVD-level check needed.

### 1.9 mm_bridge (word `0x08000`) — downstream datapath audit

`mm_bridge` (byte span `0x20000`) spans into the SciFi datapath exported AVMM
plane. Phase 1 must now address real datapath slaves through this bridge, not
just the bridge shell, to prove the SC decode is correct end-to-end.

Use the generated `.sopcinfo` address map as canonical. For the active pipe
image, this is `firmware_builds/systems/system_20260427_testplanphase5/syn/feb_system_v3_pipe.sopcinfo`. The current
internal byte offsets and external `sc_tool` word addresses are:

| Leaf slave | Internal byte base | External `sc_tool` word addr |
|---|---|---|
| `data_path_subsystem_emulator_mutrig_0.csr` | `0x2000` | `0x08800` |
| `data_path_subsystem_emulator_mutrig_1.csr` | `0x2040` | `0x08810` |
| `data_path_subsystem_emulator_mutrig_2.csr` | `0x2080` | `0x08820` |
| `data_path_subsystem_emulator_mutrig_3.csr` | `0x20C0` | `0x08830` |
| `data_path_subsystem_emulator_mutrig_4.csr` | `0x2100` | `0x08840` |
| `data_path_subsystem_emulator_mutrig_5.csr` | `0x2140` | `0x08850` |
| `data_path_subsystem_emulator_mutrig_6.csr` | `0x2180` | `0x08860` |
| `data_path_subsystem_emulator_mutrig_7.csr` | `0x21C0` | `0x08870` |
| `data_path_subsystem_dbg_mm2runctrl_0.csr` | `0x2200` | `0x08880` |
| `data_path_subsystem_histogram_statistics_0.hist_bin` | `0xA000` | `0x0A800` |
| `data_path_subsystem_histogram_statistics_0.csr` | `0xA400` | `0x0A900` |
| `data_path_subsystem_histogram_ingress_bridge_0.csr` | `0xAC00` | `0x0AB00` |

Minimum Phase-1 requirement through the bridge:

1. Read `histogram_statistics_0.csr` UID at `0x0A900`; expect `0x48495354`
   (`"HIST"`).
2. Read `histogram_ingress_bridge_0.csr` at `0x0AB00`; confirm `ack=OK`.
3. Read `emulator_mutrig_0.csr` UID/version at `0x08800/0x08801`.
4. Read `dbg_mm2runctrl_0.csr` base word `0x08880`; confirm `ack=OK`.

If any of these bridged accesses fail while the local control-plane slaves
still answer, treat that as a bridge integration failure and stop before
Phase 3 or Phase 4.

### 1.10 upload_mm_bridge (word `0x0C000`) — run-control CSR aperture

`upload_mm_bridge` exposes `upload_subsystem.csr`, which currently contains
`runctl_mgmt_host_0.csr` at internal byte base `0x0000`. The external
`sc_tool` word addresses are therefore:

| Register | Internal word | External `sc_tool` word |
|---|---|---|
| `UID` | `0x00` | `0x0C000` |
| `META` | `0x01` | `0x0C001` |
| `STATUS` | `0x03` | `0x0C003` |
| `LAST_CMD` | `0x04` | `0x0C004` |
| `RX_CMD_COUNT` | `0x0F` | `0x0C00F` |
| `LOCAL_CMD` | `0x13` | `0x0C013` |

Phase-1 requirement:

1. Read `UID` at `0x0C000`; expect `0x52434D48` (`"RCMH"`).
2. Read `META` page 0 at `0x0C001`; confirm the packed version is
   `26.2.5.0424`.
3. Read `STATUS`, `LAST_CMD`, and `RX_CMD_COUNT`; all must respond with
   `ack=OK` and must not hang even before any run-control command is sent.

This SC path is now the primary control-plane readback path for Phase 3. The
JTAG path remains a fallback and cross-check, not the default observability
mechanism.

### 1.11 mutrig_cfg_ctrl_0.avmm_csr (word `0x0FC04`)

`sc_tool` can read this word; Qsys byte base `0x3F010` is explicitly listed
in the SWB-side memory note `sc_hub_word_addressed`.

**Known limitation**: some historical probes of the cfg_ctrl CSR required
`test_slowcontrol` to reach subwords. Memory `sc_hub_word_addressed` now
pins `sc_tool` as the authoritative tool at 18-bit word span, so Phase 1
uses `sc_tool` exclusively. If `sc_tool` returns SLVERR here, record and
escalate — do **not** fall back to the deprecated tool.

### 1.12 Pass/Fail criterion for Phase 1

All local control-plane slaves, the required datapath leaves behind
`mm_bridge`, and the `runctl_mgmt_host_0.csr` aperture behind
`upload_mm_bridge` return `ack=OK` on the required UID/version (or first
in-aperture) reads, and the out-of-range reads either SLVERR or return
slave-specific data (not stale preamble data). No test below may run until
Phase 1 passes clean — a stale-ring or bridge decode failure in Phase 1 will
silently corrupt every later phase's write/readback comparison.

---

## 2. Phase 2 — BIST: write/readback/restore, ATPG, scratchpad randomized

**Goal**: Every **RW** register in the SC hub aperture survives a
write/readback/restore cycle without bit-flips; the scratchpad survives an
ATPG-style sweep (walking-1, walking-0, checkerboard, inverted checkerboard,
PRNG) and an alignment-corner burst; sc_hub v2 admission/back-pressure is
correct under the same patterns.

Reference: `../systems/system_20260427_testplanphase5/script/run_atpg_v2_reference.sh` (v2, 66-pattern driver). Re-pin
all slave base addresses to the v3 map in §1.1 before using.

### 2.1 Scratchpad BIST — destructive

The scratch_pad_ram has a declared span. Derive `N_WORDS` from the Qsys module
span (`components.ipx` → `scratch_pad_ram` span attribute).

Pattern matrix:

| Pattern | Words | Purpose |
|---|---|---|
| Walking-1 | 32 | Bit-line stuck-at-0 |
| Walking-0 | 32 | Bit-line stuck-at-1 |
| Checkerboard (`0x55555555`/`0xAAAAAAAA`) | all | Adjacent-bit short |
| Inverted checkerboard (per-word) | all | Column decode |
| Byte-inverting (`0xFF00FF00`/`0x00FF00FF`) | all | Byte-lane muxes inside SC hub |
| PRNG (LFSR, seed `0xDEADBEEF`) | all | Correlated-pattern failures |
| Address-is-data | all | Address decode (write `addr` to each word) |
| Alignment corners | first 4, last 4 | Edge of aperture |

For each pattern:

1. Save current scratchpad (Phase 1 already recorded first 16; extend to full
   span here before writing).
2. Write pattern to each word.
3. Read back and compare.
4. On mismatch, record `(addr, expected, got)`; **do not abort** — collect
   the full diff for the pattern so a bit-line failure shows up as a
   systematic mask.
5. Restore original values.

**Extra: re-read after restore**, compared against the pre-BIST snapshot. Any
word that differs means the SC-write path has an ack/retry bug (the write
landed after the comparison). This catches the v2 class of defects where the
response overtook the write because `sc_hub` let a read through while a write
was still in flight (memory `sc_hub_robustness_over_throughput` — "stall or
reject, never speculatively accept").

### 2.2 ATPG sweep — all SC-hub-visible RW registers

Using the SVD for each slave, enumerate RW registers. For each:

| Step | Action |
|---|---|
| 1 | Read current value, record. |
| 2 | Write `0x00000000`, read back. |
| 3 | Write `0xFFFFFFFF`, read back. |
| 4 | Write walking-1 (32 writes, one bit at a time), read back after each. |
| 5 | Write walking-0 (inverse), read back after each. |
| 6 | Write PRNG (16 values), read back after each. |
| 7 | Restore original. |

**Skip**: registers marked WO (e.g. `charge_injection_pulser_0`) — write-only
fields are exercised functionally in Phase 4. Handle registers with
side-effects per SVD: any register whose write triggers an I²C / one-wire
transaction must have `start`/`enable` fields masked to 0 during this sweep.

**Aperture-edge check**: after the sweep, read a word one past the last
valid offset of each slave; expect either SLVERR or a distinct value — not
the aperture's last-read data (same hazard as §1.3).

### 2.3 sc_hub admission / ordering regression

Per memory `sc_hub_robustness_over_throughput`, sc_hub v2 must **stall or
reject**, never speculatively accept. Two tests:

**2.3.a Burst-RW-interleave**: issue a 64-word write burst to scratchpad,
immediately followed by a single-word read at burst[0]. The read reply must
reflect the final written value (i.e. ordering held). If the reply is the
pre-burst value, the hub is reordering — record the `addr_word` in the read
reply (sc_tool prints `ack`/`rsp` separately per §0.3).

**2.3.b Reply-space exhaustion**: issue back-to-back bursts larger than the
reply FIFO depth without draining. Expected: hub back-pressures the writer
(host `sc_tool` sees writes slow down), and no reply is lost. Observe on
SignalTap the `sc_main_ring_valid` / `sc_main_ring_ready` pair (§4.3 trigger
table).

### 2.4 Pass/Fail criterion for Phase 2

Zero bit-flips across all RW registers and scratchpad after restore; every
address in-aperture replies `ack=OK` during the sweep; no reply lost under
burst pressure. Any write that **appears** to succeed but reads back
differently is a hard fail — it is almost always a sc_hub admission bug and
must be traced before Phase 3 runs.

---

## 3. Phase 3 — Run-control test

**Goal**: `runctl_mgmt_host_0` receives commands from SWB over the
**reset-link wire**, advances the 9-bit one-hot run-state correctly for every
opcode, fans out `dp_hard_reset` / `ct_hard_reset` / `ext_hard_reset` on
`lvdspll_clk` as specified, and logs the command correctly in its CSR
counters.

Reference: `../systems/system_20260427_testplanphase5/script/run_rc_reg_v2_reference.sh` (v2). v3 retains the same
`rc_op_table` opcode set; the runctl_mgmt_host IP version is 26.2.5.0424
(IP_UID `0x5243_4D48` = "RCMH") per the IP source.

Current pipe reset policy:

- `runctl_mgmt_host_0.lvdspll_clk` is the datapath LVDS outclock from
  `lvds_rx_28nm_0.outclock`; its reset comes from the board/monitor reset
  bridge, not from `ext_hard_reset`.
- The LVDS PHY/PLL is not wired to a run-control hard reset, and the LVDS
  controller resets are tied to the monitor 125 MHz reset. A reset-link
  command must therefore not hold the LVDS controller, PHY, or the host clock
  infrastructure in reset.
- In `feb_system_v3_pipe.qsys`, `ext_hard_reset` feeds only the cclk156/datapath
  reset merge and ultimately `data_path_subsystem.xcvr_reset`. It no longer
  resets the 125 MHz control reset tree.
- In `scifi_datapath_system_v3_pipe.qsys`, the top 16-way
  `run_control_splitter` is a readyless broadcast (`USE_READY=0`). Per-sink
  generated adapters absorb any ready-capable consumers; the host-side ready
  must not depend on all downstream run-control leaves acknowledging together.

### 3.1 Primary path: reset-link wire via rc_tool

Per memory `feb_swb_runctl_protocol_mismatch`, there is a known
**protocol-shape hazard**: SWB `a10_reset_link` sends 1-byte commands, FEB
`runctl_mgmt_host` v26.1 expected a 3-byte packet — `ext_hard_reset` never
fired from a SWB pulse. v26.2 is the fix; Phase 3 must **verify** the fix
rather than assume it.

Primary observability: the reset-link wire status. `rc_tool status` reads
`RESET_LINK_STATUS_REGISTER_R = 0x35` (memory `sc_hub_word_addressed` /
pin list in `rc_tool.cpp`). This echoes the last command sent and the state
echo from the FEB.

Secondary observability: `runctl_mgmt_host_0.csr` via the SC hub upload bridge.
In the current FEB v3 integration the host-visible base is fixed:
`upload_mm_bridge = 0x00030000` byte = `0x0C000` word, and
`runctl_mgmt_host_0.csr` sits at offset `0x0000` behind that bridge. The
Phase-3 primary CSR readback path is therefore:

- `UID` = `0x0C000`
- `META` = `0x0C001`
- `STATUS` = `0x0C003`
- `LAST_CMD` = `0x0C004`
- `RX_CMD_COUNT` = `0x0C00F`
- `LOCAL_CMD` = `0x0C013`

The JTAG path in §3.3 is now strictly a fallback and cross-check.

### 3.2 Command sweep

For each opcode in `rc_op_table` (see `tools/run_script/rc_tool.cpp::rc_op_table`,
authoritative for the v3_pretest-260511 build):

| name | opcode | run-number? | notes |
|---|---|---|---|
| `run-prepare` | `0x10` | yes | start-of-run handshake; emits 32-bit run number |
| `sync` | `0x11` | no | synchronize after run-prepare |
| `start-run` | `0x12` | no | |
| `end-run` | `0x13` | no | |
| `abort-run` | `0x14` | no | |
| `start-link-test` | `0x20` | no | |
| `stop-link-test` | `0x21` | no | |
| `start-sync-test` | `0x24` | no | |
| `stop-sync-test` | `0x25` | no | |
| `test-sync` | `0x26` | no | one-shot pulse |
| `reset` | `0x30` | no | assert soft reset (fires dp+ct+ext hard reset) |
| `stop-reset` | `0x31` | no | release reset |
| `enable` | `0x32` | no | enable run state |
| `disable` | `0x33` | no | disable run state |
| `address` | `0x40` | no | address assignment |

Per-opcode procedure:

| Step | Action | Expectation |
|---|---|---|
| 1 | Read `rc_tool status` — record `RESET_LINK_CTL_REGISTER_W`, `RESET_LINK_STATUS_REGISTER_R`, `RESET_LINK_RUN_NUMBER_REGISTER_W`, `last state byte`. | Baseline. |
| 2 | Read `runctl_mgmt_host_0.CSR_STATUS` (`0x0C003`) — decode bits {31:log_fifo_empty, 30:local_cmd_busy, 23:16:host_state, 15:8:recv_state, 5:ct_hreset, 4:dp_hreset, 1:host_idle, 0:recv_idle}. | Baseline = `0x80000003` if quiescent. |
| 3 | Read `CSR_RX_CMD_COUNT` (`0x0C00F`). | Baseline counter value N. |
| 4 | Read `CSR_LAST_CMD` (`0x0C004`) — `{shadow_fpga_addr[15:8], 8'd0, shadow_last_cmd[7:0]}`. | Baseline `0x00000000` if no command has ever run since reset. |
| 5 | `rc_tool send <cmd>` (optionally `--run <N>` for run-prepare). | sc_tool write returns ack=OK. Settle 5 ms (rc_tool default). |
| 6 | Re-read `rc_tool status`. | `last state byte` reflects the opcode just sent. |
| 7 | Re-read `runctl_mgmt_host_0.CSR_STATUS`. | `recv_state[15:8]` and `host_state[23:16]` reflect the opcode-driven FSM update (e.g. `start-run` -> RUNNING, `reset` -> momentary `dp_hreset`/`ct_hreset` window then back to idle, `enable` -> ENABLED). |
| 8 | Re-read `CSR_RX_CMD_COUNT`. | Value = **N+1 exactly**. Any other value is a dropped packet (N), a double-count (N+2), or the protocol-shape regression. **HARD FAIL CONDITION** |
| 9 | Re-read `CSR_LAST_CMD`. | Low byte = opcode just sent (e.g. `0x30` for reset). |
| 10 | Re-read `CSR_STATUS` and confirm hard-reset-window bits closed if applicable. | For `reset`: `ct_hreset` and `dp_hreset` are pulses bounded by `EXT_HARD_RESET_PULSE_CYCLES = 16384` LVDS-PLL cycles ≈ 130 µs — sc_tool readback ~ms later observes them deasserted. |

**Expected RESET_LINK_STATUS echo per opcode** (`rc_tool status` `last state byte`):
The reset-link echo byte is the opcode itself or the opcode-defined ack symbol;
record the actual values in the phase log so this column can be tightened
once the first clean sweep is recorded.

**Expected CSR_RX_CMD_COUNT delta**: +1 per command, exact. Per the Phase-2
caveat (sc_hub v2 transient ring drops ≈ 0.17%) any single-shot lag must be
distinguished from a real drop by repeating the command and observing whether
the counter advances on the retry. A persistent lag is a Phase-3 FAIL.

**Targeted regression test for the v26.1→v26.2 fix**: explicitly send
`reset` (opcode `0x30`) as a **single** 1-byte packet and verify the
`CSR_STATUS.dp_hreset` and `CSR_STATUS.ct_hreset` bits pulse high then
return to 0, AND that `CSR_RX_CMD_COUNT` increments by exactly 1. Pre-v26.2
this counter and the hard-reset pulse never fired from a SWB one-byte
packet. Run the sequence 16 times and confirm the counter advances by
exactly 16 (not 0, not 48 — 48 would be the 3-byte bug re-interpretation).

### 3.3 Fallback path: system-console JTAG inject

When the SC upload bridge is mistrusted, use the headless System Console
scripts `../systems/system_20260427_testplanphase5/script/jtag_rw.tcl` and `../systems/system_20260427_testplanphase5/script/inject_runcmd.tcl`.

Preferred JTAG cross-check path: the top-level debug JTAG master at byte base
`0x00030000`, i.e. the same aperture exported by `upload_mm_bridge`.

Addresses (relative to `0x00030000` on `control_path_subsystem.jtag_master.master`):

| Register | Offset | Check |
|---|---|---|
| UID | `0x00` | expect `0x5243_4D48` ("RCMH"). Any other value = wrong IP reached. |
| STATUS | `0x0C` | reflects current run-state one-hot. |
| LAST_CMD | `0x10` | echoes last accepted byte. |
| LOCAL_CMD | `0x4C` | write-port: pokes the command directly, bypassing the reset-link wire. |

The JTAG path **also** latches `CSR_RX_CMD_COUNT` (shared counter). The full
Phase 3 sweep §3.2 must reproduce across both paths — if counts diverge, one
path has a dropped transaction. Mandatory because memory
`feb_upload_jtag_master_stalled` documents the exact class of hang this
cross-check catches.

If the top-level JTAG aperture is unavailable, the dedicated
`upload_system_jtag_master` path may still be used as an emergency fallback,
but that is no longer the nominal Phase-3 debug route.

### 3.4 Reset-domain characterization

`runctl_mgmt_host_0` drives three reset-source conduits in the LVDS outclock
domain:
- `dp_hard_reset` and `ct_hard_reset` are live IP outputs/counters for
  characterization, but they are not the active top-level pipe reset path.
- `ext_hard_reset` is the reset source wired into the active pipe image; it
  feeds the cclk156/datapath reset merge and releases through the synchronizers
  in `feb_system_v3_pipe.qsys`.

Per SpecBook §4.6.2 the command-to-reset mapping is fixed. For each
reset-generating opcode, on SignalTap:

1. Trigger on `runctl_mgmt_host_0.ext_hard_reset` **rising edge** with 1-cycle
   condition `ext_hard_reset == 1'b1 && $past(ext_hard_reset) == 1'b0`.
2. Capture a window ±256 cycles around the edge in the LVDS outclock domain.
3. Confirm downstream reset propagation at
   `ext_reset_merge_cclk156.reset_out`, `ext_reset_pipe*_cclk156`, and
   `data_path_subsystem.xcvr_reset`. Separately record `dp_hard_reset` and
   `ct_hard_reset` as IP-local outputs/counters.
4. Confirm no spurious reset edges between commands (the counter §3.2 step 7
   already catches this aggregated; SignalTap confirms no phantom pulses
   below the counter's resolution).

**CDC probe**: `runctl_mgmt_host_0.mm_clock = cclk156`,
`lvdspll_clock = LVDS outclock`. The CSR-writable reset requests live on
`cclk156`; the reset-source conduits live on the LVDS outclock. The handshake
between them is the test target. SignalTap on both domains (split two
instances) and correlate via a free-running counter.

**Run-control broadcast probe**: do not probe the old
`run_control_splitter_outN_ready` leaves in the pipe image; they are absent by
construction after `USE_READY=0`. Probe host `valid/data/ready`,
`run_control_splitter_outN_valid/data`, and any inserted
`avalon_st_adapter_*_out_0_ready` signals only when a specific sink handshake
needs inspection.

### 3.5 Pass/Fail criterion for Phase 3

Every opcode advances counters by exactly 1 on both paths; the 9-bit run-
state one-hot takes the SpecBook-defined value after each opcode; the v26.1
protocol-shape hazard does not re-appear; no reset fires un-commanded; the
CDC handshake shows no hazard edges.

---

## 4. Phase 4 — Emulator + histogram datapath

**Goal**: the 8-lane `emulator_mutrig` LFSR produces statistically correct
hit streams that the SciFi data path consumes end-to-end, SWB receives
structurally well-formed hit records, SignalTap triggers sourced from
`DV_FORMAL.md` catch every class of datapath abnormality, and
`histogram_statistics` reflects the injector rate/channel-mask parameters
exactly — with channel-mask and rate-sweep **derived** patterns, not just
monotonicity.

### 4.1 Architecture under test (canonical references)

- `mu3e-ip-cores/emulator_mutrig/rtl/emulator_mutrig.sv` (v26.1.9.0418 per
  `scifi_datapath_system_v3.qsys`, 8 instances `emulator_mutrig_0..7`).
- `mu3e-ip-cores/histogram_statistics/histogram_statistics.svd` (v26.1.0.0411),
  one active instance `histogram_statistics_0`, fed by
  `histogram_ingress_bridge_0` so the same block can observe either the
  pre-hit-stack or post-hit-stack stream.
- `mu3e-ip-cores/charge_injection/{charge_injection_pulser,mutrig_injector}.svd`.
- `mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/DV_FORMAL.md`
  — source of all SignalTap trigger conditions in §4.3.

Key datapath wiring verified from `scifi_datapath_system_v3.qsys` (lines
noted for traceability):

- `run_control_splitter.out0 → histogram_statistics_0.ctrl`.
- `histogram_ingress_bridge_0.hist_out → histogram_statistics_0.hist_fill_in`.
- `histogram_ingress_bridge_0.pre_in` taps the pre-hit-stack stream and
  `histogram_ingress_bridge_0.post_in` taps the post-hit-stack stream.
- `histogram_ingress_bridge_0.pre_out → hit_stack_subsystem_0.hit_type_1`.
- 7 more `hist_rate_splitter_N.out1 → histogram_statistics_0.fill_in_N`
  giving per-lane fill taps.
- `emulator_mutrig_N.data_clock = lvds_rx_28nm_0.outclock`;
  `data_reset = master_datapath.master_reset`.

CSR bases (internal to the exported datapath AVMM plane, taken from the
generated `feb_system_v3.sopcinfo` address map):

| Module | Byte base (internal) | Comment |
|---|---|---|
| `emulator_mutrig_0..7.csr` | `0x2000..0x21C0` (Δ0x40) | 16-word aperture per instance |
| `dbg_mm2runctrl_0.csr` | `0x2200` | run-control debug observation |
| `histogram_statistics_0.csr` | `0xA400` | 17-word aperture |
| `histogram_statistics_0.hist_bin` | `0xA000` | 256-bin hist RAM |
| `histogram_ingress_bridge_0.csr` | `0xAC00` | ingress select / status aperture |

These are reached from the host via the sc_hub `mm_bridge` slave at
word `0x08000` (see §1.9); external SC word =
`0x08000 + internal_byte_offset / 4`. Verify on the board by reading the
`histogram_statistics_0` UID register and confirming it matches the SVD
literal `0x48495354` ("HIST") before running any Phase 4 sub-test below.

### 4.2 4a — Emulator not-stuck verification

**Claim**: with `enable=1`, `frame_count` in `emulator_mutrig_N.csr[0x05]`
increments monotonically and `event_count` advances by at least one per
frame during `run_generating` (run-state[3] = RUNNING).

**Prerequisite**: Phase 3 must have left the FEB in IDLE — NOT in any of
the reset states. If Phase 3 FAILed at the `reset` opcode, the FEB SC plane
is unrecoverable without a reflash and Phase 4 must be deferred until the
FEB is reflashed and §1 re-verified. See the Phase 3 hypothesis log for
the exact precondition recovery.

Procedure (CSR addresses are sc_tool word addresses behind `mm_bridge`):

| Step | Action | Word addr | Expected/value |
|---|---|---|---|
| 1 | Confirm state IDLE via rc_tool. | n/a | `rc_tool status` shows last byte 0x33 (disable) or freshly-reset 0x00 — NOT 0x12 (start-run) |
| 2.a | Write emulator 0 CSR[0]: `{enable=1, hit_mode=2'b00, short_mode=0}` | `0x08800` | write `0x00000001` |
| 2.b | Write emulator 0 CSR[1]: `{noise_rate=0, hit_rate=0x0800}` | `0x08801` | write `0x00000800` |
| 2.c | Write emulator 0 CSR[3]: PRNG seed | `0x08803` | write `0xDEADBEEF` |
| 2.d | Write emulator 0 CSR[6]: channel mask | `0x08806` | write `0xFFFFFFFF` |
| 3 | `rc_tool send run-prepare --run 0xAA`. Poll runctl `recv_state` = 0x10. | runctl `0x0C003[15:8]` | = 0x10 |
| 4 | `rc_tool send sync`. Poll runctl `recv_state` = 0x11. | runctl `0x0C003[15:8]` | = 0x11 |
| 5 | `rc_tool send start-run`. Poll runctl `recv_state` = 0x12. | runctl `0x0C003[15:8]` | = 0x12 |
| 6 | Wait 500 ms. | | |
| 7 | Read emulator 0 CSR[5] (frame/event counter pair). | `0x08805` | record `f0, e0` |
| 8 | Wait 500 ms. | | |
| 9 | Re-read CSR[5]. | `0x08805` | record `f1, e1` |

Pass: `f1 > f0` AND `e1 > e0`. For hit_rate=0x0800 ≈ 8.0 hits/frame at the
LVDS-PLL frame rate (~125 MHz / 256-cycle frames ≈ 500 kHz frames), 500 ms
yields ~250,000 frames so `f1 - f0` ≈ 2.5×10^5 and `e1 - e0` ≈ 2×10^6. The
exact ratio is implementation-defined but both must be **strictly** greater
than 0 across the half-second window.

10. Repeat steps 7–9 for emulators 1..7 (word base = `0x08800 + 16 * N`).
    Each lane must increment independently.

11. `rc_tool send end-run`, then `rc_tool send disable`. Confirm runctl
    `recv_state` returns to 0x33 and the emulator frame counters stop.

Failure modes caught:

- **Emulator 0 runs, others stuck** ⇒ `run_generating` fan-out is per-lane
  broken (emulator_ctrl_splitter).
- **`frame_count` increments but `event_count` doesn't** ⇒ LFSR enable bad,
  or inject_channel_mask cleared. Cross-check `csr[0x06]`.
- **Neither increments after CMD_START_RUN** ⇒ `run_generating` never
  asserted. Correlate against §3.4 state transitions.

### 4.3 4c — SignalTap triggers from DV_FORMAL.md (1-cycle combinational)

These are all 1-cycle conditions per user requirement (not temporal spread).
Source: `firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/DV_FORMAL.md`. Collected by
extracting every SVA that reduces to a single-cycle antecedent-implies-
consequent with the consequent on the same cycle.

Trigger is placed as SignalTap's `In` condition with the listed expression
in the target hierarchy. The capture window is set to 1k–8k samples
asymmetric (trigger position 20%) so the *preceding* cycles are recorded.

**Run Phase 4c triggers in the order below; one trigger at a time to avoid
Stp multiplexing delays.**

| ID | Trigger (1-cycle combinational) | Domain | Diagnoses |
|---|---|---|---|
| SOP | `aso_tx8b1k_valid && aso_tx8b1k_data == 9'h11C` | `lvds_rx_28nm_0.outclock` | emulator K28.0 SOP appears; sanity |
| EOP | `aso_tx8b1k_valid && aso_tx8b1k_data == 9'h19C` | same | emulator K28.4 EOP appears; frame closes |
| SOP_NO_EOP | `aso_tx8b1k_valid && aso_tx8b1k_data == 9'h11C && in_frame_q` | same | torn frame: new SOP before previous EOP |
| CRC_ERR | `hit_type0_valid && hit_type0_error[1] == 1'b1` | same | CRC flag on an aligned hit record |
| DROP_INC | `drop_count != $past(drop_count)` | hit_stack domain | any hit dropped this cycle (shallow FIFO); cross-ref PORT_STATUS |
| RR_VIOL | `out_valid && !$onehot(grant)` | arbiter (mux_mutrig2processor / decoded_lane_mux) | RR arbiter asserted grant on zero or multiple lanes |
| SC_TORN | `i_download_data[31:24] == 8'hBC && i_download_datak == 4'b1000 && o_pkt_in_progress` | sc_hub primary ring | SC preamble inside an in-progress packet (lost SC packet framing) |
| INJ_ARM | `mutrig_injector.csr_word0_we && csr_wdata[0] == 1'b1 && run_state != RUNNING` | cclk156 | injector armed outside RUNNING (should be gated) |
| UNDR_INC | `underflow_count != $past(underflow_count)` | histogram_statistics_0.clock | hit fell below LEFT_BOUND |
| OVRFL_INC | `overflow_count != $past(overflow_count)` | same | hit exceeded RIGHT_BOUND |

**Placement note**: the SignalTap .stp is to live in
`systems/system_20260427_testplanphase5/signaltap/phase4c_<id>.stp` (one per trigger). Use
`common/firmware/util/signaltap/…` templates if available in the project,
otherwise author them from scratch and check in after first-run capture.

### 4.4 4b — SWB hit-reception verification

**Claim**: with the emulator running (4a), the SWB sees a well-formed hit
stream on its front-end FIFO; `histogram_statistics_0.TOTAL_HITS` and the
SWB-side per-link hit counter advance together.

Procedure:

1. After §4.2 step 10 (8 emulators running), poll
   `histogram_statistics_0.TOTAL_HITS` (word offset `0x34/4 = 0x0D` from the
   histogram CSR base).
2. Simultaneously, read the SWB per-link hit counter via `sc_tool` on the
   SWB (register address from `online_sc` — **not** from this v3 tree).
3. Over a 10-second window, both must advance at approximately the same
   rate, within a tolerance set by the intermediate `decoded_lane_fifo_N`
   depth (≤ `fifo_level_max` from PORT_STATUS).
4. `histogram_statistics_0.DROPPED_HITS` (word offset `0x38/4 = 0x0E`) must
   remain 0 at the default rate of §4.2 step 2. If it advances, the
   downstream sink is back-pressuring — record the value and correlate with
   §4.3 `DROP_INC` trigger.

Failure modes:

- **Histogram advances, SWB doesn't** ⇒ the LVDS TX → SWB RX link dropped.
  Check SWB link-lock for link 2.
- **SWB advances, histogram doesn't** ⇒ histogram tap is disconnected.
  Unusual; cross-ref Qsys wiring lines 2353 and 2365–2395.

### 4.5 4d — Histogram channel-mask and rate-sweep

**Claim**: histogram bin population exactly reflects
`(rate × mask_bit_count)` per lane, scaled by the `fill_in_N` splitter ratio.
Derived patterns — not an equal check, but a parametric one.

Set-up: before each run below, write `LEFT_BOUND=0`, `RIGHT_BOUND=255`,
`BIN_WIDTH=1` so each bin covers one channel ID; this turns the histogram
into a direct per-channel hit distribution.

#### 4.5.1 Channel-mask sweep (8 lanes × mask)

For each lane N ∈ 0..7 in turn:

| Run | `inject_channel_mask` on lane N | Expected histogram (lane N slice) |
|---|---|---|
| 1 | `0xFFFFFFFF` | flat distribution across 32 channels (Poisson spread) |
| 2 | `0x0000FFFF` | only channels 0..15 populated; 16..31 bins = 0 |
| 3 | `0xFFFF0000` | inverse of run 2 |
| 4 | `0x55555555` | even channels only |
| 5 | `0xAAAAAAAA` | odd channels only |
| 6 | `0x00000001` | single channel; other 31 bins = 0 |

Every run: verify `UNDERFLOW_COUNT` and `OVERFLOW_COUNT` stay 0 (channel ID
always in bounds for the configured LEFT/RIGHT). A nonzero over/underflow
under this mask set is a hit-record encoding bug, not a histogram bug.

#### 4.5.2 Rate sweep (pattern derivation)

Keep `inject_channel_mask = 0xFFFFFFFF`. Sweep `hit_rate` in 8.8 fixed-point:
`0x0100, 0x0400, 0x0800, 0x1000, 0x2000, 0x4000, 0x8000`. For each point,
run for a fixed interval (set via `INTERVAL_CFG` to define the histogram
ping-pong period), then read `TOTAL_HITS`.

**Derived pattern (must hold)**: `TOTAL_HITS[i] / TOTAL_HITS[i-1] ≈ 2.0 ±
tolerance` across consecutive rate doublings, until the point where
`fifo_level_max` in `PORT_STATUS` clips. The clipping point identifies the
downstream saturation knee — record its rate in the test report. This is a
far more sensitive check than a single-rate sanity test because a
drop-on-back-pressure bug would flatten the ratio below 2.0 before any
absolute count looks wrong.

#### 4.5.3 Burst-mode and periodic-mode cross-check

Set `csr[0x00].hit_mode = 2'b01` (burst), run, record pattern. Then
`2'b11` (periodic), run, record pattern. Periodic mode produces a
delta-function histogram; burst mode produces a cluster centered at
`burst_center` (csr[0x02]). Any observed widening/smearing beyond what the
config predicts is the in-line ring_buffer_cam / hit_stack_subsystem
jittering timestamps — correlate with `histogram_statistics_1.debug_2..6`
debug-FIFO level readouts.

#### 4.5.4 Ping-pong sanity

`BANK_STATUS` (word offset `0x2C/4 = 0x0B`) must alternate between active-A
and active-B every `INTERVAL_CFG` interval. Read it 32 times across the run
and confirm the alternation is regular (stddev < 1 interval). If it's
not, the histogram ping-pong ISP missed an interval edge and one bank is
being written over an un-drained read.

### 4.6 Pass/Fail criterion for Phase 4

- §4.2 8-lane not-stuck: pass.
- §4.3 no unexpected trigger fires (SOP_NO_EOP, CRC_ERR, RR_VIOL, SC_TORN,
  INJ_ARM) during a 60-second clean run; if any fires, capture the window
  and attach to the report.
- §4.4 SWB and histogram advance together, DROPPED_HITS = 0 at default
  rate.
- §4.5.1 every mask produces exactly the predicted bin pattern.
- §4.5.2 rate-doubling ratio holds up to the knee; knee is documented.
- §4.5.4 ping-pong alternation is regular.

---

## 5. Report deliverables

Each phase produces a structured report written to `systems/system_20260427_testplanphase5/reports/`:

- `phase1_bringup_<date>.md` — one row per slave, showing UID, version,
  first-word read, out-of-range probe result.
- `phase2_bist_<date>.md` — pass/fail count per register; any bit-flip with
  `(addr, expected, got, pattern)`.
- `phase3_runctl_<date>.md` — counter deltas for every opcode on both paths,
  SignalTap capture file pointer for each hard-reset edge.
- `phase4_emulator_<date>.md` — not-stuck table, SignalTap captures for all
  triggers that fired (or explicit "no fire" with observation duration),
  mask-sweep and rate-sweep tables.

The reports are the sign-off artifact; the test plan is successful if and
only if these four reports are on disk, checked in, and review-approved.

---

## 6. Open items / known caveats

- **MuDAQ dependency closure**: `../systems/system_20260427_testplanphase5/script/build_local_tools.py` keeps
  `systems/system_20260427_testplanphase5/bin/sc_tool` and `systems/system_20260427_testplanphase5/bin/rc_tool` built from the local
  checked-in sources, but it still links against the dependency closure from
  `online_dpv2/online/build`. If that external build tree moves, refresh the
  build script inputs before trusting the local binaries.
- **Downstream SC-hub-reached datapath addresses** (Phase 4 CSR path): the
  external word offset via `mm_bridge` is derived from
  `scifi_datapath_system_v3.qsys` internal byte bases. Verify on-board with
  the histogram UID check before relying on the derived numbers for every
  register.
- **SignalTap .stp authoring**: no pre-built `.stp` files for v3 triggers
  in §4.3 yet; they are to be authored on first run and checked into
  `systems/system_20260427_testplanphase5/signaltap/`.
- **Ping-pong interval tuning**: §4.5.4 assumes `INTERVAL_CFG` yields an
  interval > the time needed for one full host-side read of hist_bin (256
  words). If it doesn't, raise `INTERVAL_CFG` until it does; a too-short
  interval aliases the alternation check.

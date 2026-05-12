# FEB SciFi v3 On-Board Test Plan

**Revision**: 2026-05-12 / draft-1
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

**Phase 3 verdict on `v3_pretest-260511` (pre-fix SOF, 2026-05-11 18:47 UTC)**:
**FAIL** at opcode `0x30` (`reset`). Post-CMD_RESET, every SC read returned
`rsp=RSP3 payload=0xEEEEEEEE`; SWB secondary ring filled with "invalid" packets;
SC plane stayed opaque until FEB reflash. Root cause: in `feb_system_v3.qsys`,
`ext_reset_pipe2_cclk156.out_reset` fanned into `control_path_subsystem.clk156_in_rst`,
so a `runctl_mgmt_host_0.ext_hard_reset` pulse held the SC-hub/upload bridge in
reset and wedged the control plane. See
`reports/phase3_20260511_184713.log` and BUG-RC-RESET-SCWEDGE in `BUG_HISTORY.md`.

**Phase 3 verdict on `v3_pretest-260511-fix-runctl-reset-260511` (post-fix SOF, 2026-05-11 19:58 UTC)**:
**PASS**. Qsys topology fix:
`ext_reset_pipe2_cclk156.out_reset -> control_path_subsystem.clk156_in_rst`
broken; replaced with direct
`cclk156_source.clk_reset -> control_path_subsystem.clk156_in_rst`. The control
plane no longer sees ext_hard_reset. Post-CMD_RESET, all three sentinel SC
reads (`scratch_pad_ram`, `sc_hub UID`, `onewire UID`) returned `rsp=OK` with
the expected payload; CSR_RX_CMD_COUNT advanced by exactly +1 across each
opcode (0x30 -> 0x31 -> 0x10). Evidence:
`reports/phase3_postfix_20260511_195758.log`. Detailed pre/post snapshots are
captured in §3.7.

### 3.6 Sim-side directed sequences (BUG-RC-RESET-SCWEDGE, BUG-RC-RUN-EMUL)

Two directed tb_int sequences exist as the sim-side mirror of the Phase 3
opcode sweep:

- SWB tb_int: `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/uvm/swb_rdma_pretest/sequences/run_sequence_directed.sv`
  + `tests/tb_int_run_sequence_directed_test.sv`. Drives the 10 PASS opcodes
  (0x10/0x11/0x12/0x13/0x14/0x20/0x21/0x24/0x25/0x26) plus CMD_RESET (0x30) on
  the SWB synclink 9-bit AVST, sampling runctl_mgmt_host CSR_STATUS,
  CSR_LAST_CMD, and CSR_RX_CMD_COUNT after each step. Make target:
  `make run_RC_DIRECTED`.
- FEB tb_int: `firmware_builds/systems/v3_pretest-260511/tb_int/uvm/v3_pretest-260511/sequences/run_emulator_directed.sv`
  + `tests/tb_int_run_emulator_directed_test.sv`. Drives `run-prepare` ->
  `sync` -> `start-run` and a 16-hit emulator-style burst, then polls the
  histogram_statistics / mts_preprocessor / feb_frame_assembly CSR addresses.
  Make target: `make run_RC_EMUL`.

Both sequences PASS today against the behavioural stub responder
(`tb_int_top.sv` returns a fixed `0x4849_5354` payload for every AVMM read).
The silicon-side signatures `RSP3+0xEEEEEEEE` (SC-WEDGE) and
`PORT_STATUS=0x000000FF, TOTAL_HITS=0` (splitter blockage) cannot be observed
in behavioural sim with the current stub responder. Each sequence emits a
labelled `uvm_info` marker on the silicon-vs-stub mismatch so the parent
regression can promote the marker to xfail when the
`TB_INT_BIND_REAL_DUT` Qsys-bound compile lands.

### 3.7 Postfix retest 2026-05-11 — BUG-RC-RESET-SCWEDGE on-board verification

**SOF**: `firmware_builds/systems/v3_pretest-260511-fix-runctl-reset-260511/syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`
(sha256 prefix `63d5d2fbe608bd88`).
**Qsys version**: `feb_system_v3.qsys = 3.0.1.0511` — description "runctl_mgmt_host
ext_hard_reset SC-plane wedge fix".
**Topology delta**: broke
`ext_reset_pipe2_cclk156.out_reset -> control_path_subsystem.clk156_in_rst`;
replaced with direct
`cclk156_source.clk_reset -> control_path_subsystem.clk156_in_rst`.

**Pre-test sanity** (after `program_feb.sh` 20 s settle + `mudaq_recover_pcie`):

| Probe | Address | Value | Verdict |
|---|---|---|---|
| `scratch_pad_ram` | `0x00000` | `0x00000000` | ack=OK, not 0xEEEEEEEE |
| `sc_hub` UID | `0x0FE80` | `0x53434842` ("SCHB") | ack=OK, magic matches |
| `runctl_mgmt_host_0.CSR_RX_CMD_COUNT` | `0x0C00F` | `0x00000000` | ack=OK, fresh boot |

**CMD sweep critical step (CMD_RESET 0x30 then CMD_STOP_RESET 0x31 then CMD_RUN_PREPARE 0x10)**:

| Probe | PRE (cold) | POST 0x30 | POST 0x31 | POST 0x10 (run 0x42) |
|---|---|---|---|---|
| `scratch_pad_ram@0x00000` | `0x00000000` | `0x00000000` | `0x00000000` | `0x00000000` |
| `sc_hub_UID@0x0FE80`      | `0x53434842` | `0x53434842` | `0x53434842` | `0x53434842` |
| `onewire@0x04400`         | `0x4F574D43` | `0x4F574D43` | `0x4F574D43` | `0x4F574D43` |
| `runctl CSR_RX_CMD_COUNT` | `0x00000000` | `0x00000001` | `0x00000002` | `0x00000003` |
| `runctl CSR_LAST_CMD`     | `0x00000000` | `0x00000030` | `0x00000031` | `0x00000010` |
| `runctl CSR_STATUS`       | `0x80000003` | `0x00000033` | `0x00000003` | `0x00000003` |
| `RESET_LINK_STATUS_R`     | `0x14000000` | `0x30000000` | `0x31000000` | `0x00000042` (run-number encoded) |

**Key observations**:

- **Post-0x30 SC reads were clean** — no `0xEEEEEEEE` / `RSP3` anywhere.
  Pre-fix SOF wedged every SC slave at this exact step
  (`reports/phase3_20260511_184713.log` lines 261-263). The fix verified.
- `CSR_RX_CMD_COUNT` advanced exactly +1 per opcode (0 -> 1 -> 2 -> 3),
  confirming no command drops and no double-count.
- `CSR_LAST_CMD` echoed the opcode byte in the low byte of each step
  (`0x30`, `0x31`, `0x10`).
- `CSR_STATUS` post-0x30 showed `0x00000033` (host_state and recv_state bits
  reflecting the active reset window inside the runctl FSM), then settled to
  `0x00000003` after `stop-reset` and again after `run-prepare`. The momentary
  hard-reset bits did not leak into the SC clock domain.

**Verdict**: **SC-WEDGE FIX: VERIFIED on board**. Log:
`reports/phase3_postfix_20260511_195758.log`.

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
generated `feb_system_v3.sopcinfo` address map). External SC word =
`0x08000 + internal_byte_offset / 4`:

| Module | Byte base (internal) | External `sc_tool` word | Span | Comment |
|---|---|---|---|---|
| `emulator_mutrig_0..7.csr` | `0x2000..0x21C0` (Δ0x40) | `0x08800..0x08870` (Δ0x10) | 16 words / inst | v3 CSR layout (different from legacy SVD) |
| `dbg_mm2runctrl_0.csr` | `0x2200` | `0x08880` | 16 words | run-control debug observation, UID="M2RC" |
| `mts_preprocessor_0.csr` | `0x4000` | `0x09000` | 8 words | first MTS preprocessor stage |
| `mts_preprocessor_1.csr` | `0x8000` | `0x0A000` | 8 words | second MTS preprocessor stage |
| `histogram_statistics_0.hist_bin` | `0xA000` | `0x0A800` | 256-bin (RAM) | 256-word ping-pong bin window |
| `histogram_statistics_0.csr` | `0xA400` | `0x0A900` | 32 words | UID="HIST" |
| `histogram_ingress_bridge_0.csr` | `0xAC00` | `0x0AB00` | 4 words | UID="HISB" |
| `ring_buffer_cam_HSS0_0..3.csr` | `0xB000..0xB180` (Δ0x80) | `0x0AC00..0x0AC60` (Δ0x20) | 32 words / inst | UID="RBCM" |
| `mutrig_injector_0.csr` | `0xB200` | `0x0AC80` | 16 words | UID="MINJ" |
| `ring_buffer_cam_HSS1_0..3.csr` | `0xB400..0xB580` (Δ0x80) | `0x0AD00..0x0AD60` (Δ0x20) | 32 words / inst | UID="RBCM" |
| `feb_frame_assembly_HSS0.csr` | `0xD000` | `0x0B400` | 16 words | no UID; word0=feb_type, word1=feb_id |
| `feb_frame_assembly_HSS1.csr` | `0xD040` | `0x0B410` | 16 words | no UID; word0=feb_type, word1=feb_id |

**v3 `emulator_mutrig` CSR map (in-aperture words 0..0x0F)** — from
`emulator_mutrig/rtl/frontend/frontend_csr.sv`, NOT the legacy SVD:

| Word | Name | Access | Description |
|---|---|---|---|
| `0x00` | `UID` | RO | `0x454D5554` ("EMUT") |
| `0x01` | `META` | RW | packed `{MAJOR,MINOR,PATCH,BUILD}` (page 0); writable selector at bits[1:0] |
| `0x02` | `SCRATCH` | RW | general-purpose scratch (RW probe target) |
| `0x07` | `CENTRAL` | RW | bit 0 = `cfg_central_global_enable` (defaults to 1 at reset) |
| `0x08` | `SIGNAL` | RW | hit-mode bits |
| `0x09` | `BACKGROUND` | RW | background hit mode |
| `0x0A` | `MUTRIG_FORMAT` | RW | tx_mode, short_mode, gen_idle, enable_type0_stream |
| `0x0B` | `RATES` | RW | `{noise_rate[31:16], hit_rate[15:0]}` (8.8 fixed-point); reset `0x01000800` |
| `0x0E` | `PRNG_SEED` | RW | reset `0xDEADBEEF` |
| `0x12` | `LANE_ENABLE` | RW | `{asic_id_base[15:8], lane_enable_mask[7:0]}` reset `{base, 0xFF}` |
| `0x13` | `FIRE` | WO | software-triggered inject pulse |
| `0x14` | `BANK_STATUS` | RO | `{busy_high_water, ticket_overflow_count}` per-instance |

The per-lane `frame_count` and `event_count` registers in the v3 RTL live at
word offsets `0x18..0x37`, which are **NOT reachable** through the Qsys 16-word
aperture per instance. They overflow into the neighbouring slave's span. The
correct host-observable proxy for "hits flowing" is the histogram
`TOTAL_HITS` plus `BANK_STATUS` bank-flip cadence and the `feb_frame_assembly`
declared/actual hit counts.

Verify on the board by reading the `histogram_statistics_0` UID at
`0x0A900` (expect `0x48495354`) and `emulator_mutrig_0` UID at `0x08800`
(expect `0x454D5554`) before running any Phase 4 sub-test below.

### 4.2 4a — Emulator not-stuck verification

**Claim**: with `cfg_central_global_enable=1` (default at reset) and the
runctl FSM in run-state `0x12` (start-run, AVST one-hot
`9'b000001000` reaching emulator `asi_ctrl`), `run_generating=ctrl_state_q[3]`
asserts inside every emulator and hits flow downstream through
`mts_preprocessor → ring_buffer_cam → feb_frame_assembly`, with
`histogram_statistics_0.TOTAL_HITS` and
`feb_frame_assembly_HSS0.actual_hit_cnt_all` advancing within a few hundred
ms.

**CRITICAL — runctl reset opcodes are forbidden in this build.** Do NOT send
`reset` (0x30) or `stop-reset` (0x31): they wedge the FEB SC plane on the
current v3_pretest SOF (every SC reply becomes `0xEEEEEEEE`, recovery
requires reflash). Only the 10 PASS opcodes from Phase 3 are safe here:
run-prepare (0x10), sync (0x11), start-run (0x12), end-run (0x13),
abort-run (0x14), start-link-test (0x20), stop-link-test (0x21),
start-sync-test (0x24), stop-sync-test (0x25), test-sync (0x26).

**Prerequisite**: Reflash FEB via `tools/run_script/program_feb.sh` and
verify SC plane alive with §1 pre-flight before starting Phase 4. The
runctl FSM must be at LAST_CMD=0 or any non-reset opcode (the SWB
`RESET_LINK_STATUS_REGISTER_R` echo byte may show stale state from prior
runs; what matters is FEB-side `runctl_mgmt_host_0.CSR_LAST_CMD` reads
non-`0xEEEEEEEE`).

**Note on observability**: the v3 emulator_mutrig per-lane frame and event
counters at RTL word offsets `0x18..0x37` are **NOT host-reachable** (the
Qsys exposes 16 words = bytes `0x00..0x3F` per instance only). Verify the
emulator chain via the downstream observable counters listed below.

**Hardware-first debug rule**: for this Phase 4 blocker, the board observation
chooses the debug boundary. The known-good side is the FEB run-control command
path through `runctl_mgmt_host_0.LOCAL_CMD` and `dbg_mm2runctrl_0.HOST_CMD`
to `run_control_splitter`; the unknown side is the splitter fan-out into the
emulator `asi_ctrl` leaves and the downstream histogram/FEB frame-assembly hit
flow. Simulation is used only to mirror or de-risk that boundary before a
rebuild. If the rebuilt hardware still shows zero hits, go directly to
SignalTap across the known-good/unknown gap instead of treating sim-only
evidence as a sufficient RTL-fix claim.

Procedure (CSR addresses are sc_tool word addresses behind `mm_bridge`):

| Step | Action | Word addr | Expected/value |
|---|---|---|---|
| 1 | Confirm FEB-side runctl quiescent. | `0x0C003`, `0x0C004` | STATUS=`0x80000003` (log_fifo_empty, host_idle, recv_idle) AND LAST_CMD=0 if freshly reflashed |
| 1.a | Confirm `cfg_central_global_enable=1` on every emulator. | `0x08807+i*16` for i=0..7 | each reads `0x00000001` (default at reset) |
| 1.b | Confirm histogram quiescent. | `0x0A900..0x0A912` | UID=`0x48495354`, TOTAL_HITS=0, LAST_INT_HITS=0, UNDERFLOW=0, OVERFLOW=0, BANK_STATUS=`0x00000001` (active_bank=A, no flushing), PORT_STATUS=`0x000000FF` (all 8 ingress FIFOs empty), INTERVAL_CFG=`0x07735940` (1.0 s at 125 MHz) |
| 1.c | Confirm feb_frame_assembly quiescent. | `0x0B400..0x0B407` and `0x0B410..0x0B417` | feb_type word0=`0x00000038`, feb_id word1=`0x00000002`, declared/actual/missing hit counters all 0 |
| 2.a | (Optional) Override `cfg_hit_rate` on emulator 0. | `0x0880B` | write `{noise_rate=0x0000, hit_rate=0x0800}` = `0x00000800` for ~8 hits/frame |
| 2.b | (Optional) Override `PRNG_SEED` on emulator 0. | `0x0880E` | write `0xDEADBEEF` |
| 2.c | (Optional) Force `LANE_ENABLE` to all 8 lanes on emulator 0. | `0x08812` | write `{asic_id_base=0, lane_enable_mask=0xFF}` = `0x000000FF` |
| 3 | `rc_tool send run-prepare --run 0x55`. | runctl `0x0C004` `0x0C00F` | LAST_CMD=`0x10`, RX_CMD_COUNT 0→1. SWB-side `RESET_LINK_STATUS_REGISTER_R`=`0x00000055` (run number echo). |
| 4 | `rc_tool send sync`. | runctl `0x0C004` `0x0C00F` | LAST_CMD=`0x11`, RX_CMD_COUNT 1→2. SWB-side state byte=`0x11`. |
| 5 | `rc_tool send start-run`. | runctl `0x0C004` `0x0C00F` | LAST_CMD=`0x12`, RX_CMD_COUNT 2→3. SWB-side state byte=`0x12`. |
| 6 | Wait 500 ms — 2 s. | | runctl FSM is now broadcasting AVST one-hot `9'b000001000` to the run_control_splitter fanout. |
| 7 | Read histogram TOTAL_HITS. | `0x0A90D` | **must be > 0** within 1–2 s. Expected ≥ ~10^4 hits/sec at default rate × 8 lanes × 8 emulators. |
| 7.b | Read histogram LAST_INT_HITS. | `0x0A911` | latched at every 1-second BANK interval; must be > 0 after the first interval edge. |
| 7.c | Read histogram BANK_STATUS. | `0x0A90B` | active_bank toggles each second (bit 0 flips), so over 2 s expect the value to change at least once. |
| 7.d | Read histogram PORT_STATUS. | `0x0A90C` | `fifo_empty_mask` should DROP below `0xFF` while hits are flowing; `fifo_level_max` should be non-zero. |
| 8 | Read feb_frame_assembly_HSS0 actual hit count. | `0x0B405` (low 32b), `0x0B404` (high 18b) | must be > 0; should track histogram TOTAL_HITS at the egress side modulo any frame_assembly drop counters. |
| 8.b | Read feb_frame_assembly_HSS1 actual hit count. | `0x0B415`, `0x0B414` | must also be > 0 (HSS1 takes emulators 4..7). |
| 9 | Wait additional 1 s and re-read TOTAL_HITS. | `0x0A90D` | new value > previous; **strictly monotonic** in RUNNING. |

**Run-control state observability note**: `runctl_mgmt_host_0.CSR_STATUS`
at `0x0C003` is observed to read `0x00000003` (host_idle | recv_idle) even
while the FEB-side reset-link FSM is in run-state 0x12 — the host_state[23:16]
and recv_state[15:8] sub-fields read as 0 due to a sampling skew between
the `host_state_sync_q1` flop and the SC clock. Treat the SWB-side
`RESET_LINK_STATUS_REGISTER_R` echo byte (top 8 bits of `rc_tool status`)
as the authoritative FSM-state indicator. CSR_STATUS's reliable fields
here are bit 31 (log_fifo_empty) and bit 30 (local_cmd_busy).

**Order constraint**: `end-run` (0x13) is **not accepted from every prior
state**. Observed 2026-05-11: after `enable` (0x32) the FEB FSM rejects
`end-run` (0x13); `abort-run` (0x14) is accepted from any state. The safe
end-of-run sequence in this build is `end-run` → (if rejected) `abort-run`.

10. If hits do not flow after the rc-readyless rebuild, repeat steps 7–9 with
    a SignalTap capture. This condition is active as of the 2026-05-12
    hardware retest (§4.10): run-control CSRs advance, but histogram and
    frame-assembly hit counters stay zero. Use
    `v3_pretest-260511-rc-readyless-260511/signaltap/phase4_rc_readyless_gap.stp`
    first. It probes the known-good/unknown gap: run-control mux output,
    splitter input, splitter `out0/out1/out12/out15`, emulator control
    splitter `out0/out1/out7`, emulator0 `asi_ctrl`, emulator0
    `frontend_run_ctl` state/run-generating, and emulator0 TX output.

11. `rc_tool send end-run` (if rejected by FSM, `rc_tool send abort-run`).
    Confirm `feb_frame_assembly_HSS0` actual hit count freezes (no further
    increment), `BANK_STATUS` interval timer stops (no further bank
    flips), and SC plane remains alive (re-read scratch_pad_ram at
    `0x00000` and emulator UID at `0x08800` — must NOT return
    `0xEEEEEEEE`).

Failure modes caught:

- **No hits in TOTAL_HITS, BANK_STATUS unchanged** ⇒ `run_generating` never
  asserted, OR run_control_splitter sink dangling. Verify the splitter
  outputs are all `ready=1`-terminated in
  `scifi_datapath_system_v3_pipe.qsys`. Cross-check via §3.4 SignalTap
  trigger `run_control_splitter_outN_valid` rising-edge.
- **TOTAL_HITS increments but feb_frame_assembly actual=0** ⇒ histogram tap
  works, but post-hit-stack egress is stuck. Suspect mts_preprocessor or
  ring_buffer_cam backpressure; inspect `PORT_STATUS.fifo_level_max` and
  `histogram_statistics_0.DROPPED_HITS`.
- **Histogram BANK_STATUS toggles, hits = 0 in feb_frame_assembly,
  but PORT_STATUS shows fifo_empty_mask < 0xFF** ⇒ hits are arriving at
  the histogram's ingress FIFOs but not being committed; check
  `apply_pending` bit in histogram CONTROL and any `error` flag in
  CONTROL[31:24].

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

### 4.7 Phase 4 postfix-1 retest 2026-05-11 (phase4-fix SOF)

**SOF**: `firmware_builds/systems/v3_pretest-260511-phase4-fix-260511/syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`
(sha256 prefix `d747954b36d1745c6`).
**SOF delta vs prior Phase 4 SOF** (`fix-runctl-reset-260511`):
- hist-debug-disconnect: removed 6 AVST debug connections feeding
  `histogram_statistics_0` (was the -1.376 ns LVDS Setup violator).
- SC-WEDGE fix already inherited.
- Worst Setup: -0.620 ns (improved from -1.376 ns). 2/4 corners pass.
- Does NOT include the full rc-readyless IP + Qsys closure
  (`17e0cec8` + `93ce227c` + `f3981273`).

**Pre-test sanity** (after `program_feb.sh` 20 s settle + `mudaq_recover_pcie`):

| Probe | Address | Value | Verdict |
|---|---|---|---|
| `scratch_pad_ram` | `0x00000` | `0x00000000` | ack=OK, not 0xEEEEEEEE |
| `sc_hub` UID | `0x0FE80` | `0x53434842` ("SCHB") | ack=OK, magic matches |
| `runctl_mgmt_host_0.CSR_RX_CMD_COUNT` | `0x0C00F` | `0x00000000` | ack=OK, fresh boot |

**SWB LVDS link status note**: `LINK_LOCKED_LOW_REGISTER_R = 0x00000F00`
(bits 8..11 locked = other boards). Bit 2 (SciFi FEB link 2) = 0 — LVDS
transceiver link NOT locked. `rc_tool send` commands do not echo back (STATUS
stuck at `0x00000042` from prior session). Run-control injected via SC write
to `LOCAL_CMD` at `0x0C013` (TEST_PLAN §3.3 fallback), which does reach the
`runctl_mgmt_host_0` FSM (RX_CMD_COUNT increments correctly).

**Run-control opcode sweep (LOCAL_CMD SC write)**:

| Opcode | Write to `0x0C013` | LAST_CMD (`0x0C004`) | RX_CMD_COUNT (`0x0C00F`) |
|---|---|---|---|
| `0x10` run-prepare | `0x00000010` | `0x00000010` | `0x00000001` |
| `0x11` sync | `0x00000011` | `0x00000011` | `0x00000002` |
| `0x12` start-run | `0x00000012` | `0x00000012` | `0x00000003` |
| `0x13` end-run | `0x00000013` | `0x00000013` | `0x00000004` |

RX_CMD_COUNT advanced exactly +1 per opcode. SC plane remained clean throughout.

**Pre/post CSR snapshot**:

| Metric | PRE (baseline) | POST start-run +4 s | POST end-run |
|---|---|---|---|
| `TOTAL_HITS` `0x0A90D` | `0x00000000` | `0x00000000` | `0x00000000` |
| `BANK_STATUS` `0x0A90B` | `0x00000001` | `0x00000001` | `0x00000001` |
| `PORT_STATUS` `0x0A90C` | `0x000000FF` | `0x000000FF` | `0x000000FF` |
| `RX_CMD_COUNT` `0x0C00F` | `0x00000000` | `0x00000003` | `0x00000004` |
| `LAST_CMD` `0x0C004` | `0x00000000` | `0x00000012` | `0x00000013` |
| `fa0 actual` `0x0B405` | `0x00000000` | `0x00000000` | `0x00000000` |
| `DROPPED_HITS` `0x0A90E` | `0x00000000` | `0x00000000` | `0x00000000` |

Additional probe: `dbg_mm2runctrl` HOST_CMD write of `0x12` (start-run) also
delivered RC_RUNNING to the run_control_splitter (`SENT_COUNT = 0 -> 1`,
`LAST_SENT = 0x00004A08` = RC_RUNNING state word). No change in TOTAL_HITS or
PORT_STATUS after this injection either.

**Verdict**: **PHASE 4 FAIL — rc-readyless rebuild needed**.

Root cause: the hist-debug-disconnect fix (timing improvement) did NOT resolve
the PORT_STATUS=0xFF symptom. The run_control_splitter RC_RUNNING broadcast
reaches the splitter (confirmed via both `runctl_mgmt_host_0.LOCAL_CMD` and
`dbg_mm2runctrl.HOST_CMD` injection paths), but the downstream sinks
(emulator_mutrig asi_ctrl inputs) do not receive it. The auto-inserted
`timing_adapter` components on the splitter outputs are the suspected carrier:
they can insert a ready handshake that blocks the AVST broadcast if a sink is
still ready-capable or if the Qsys instance pin is stale. The rc-readyless
rollout (`17e0cec8` for the first five sinks, `93ce227c` for
`mutrig_frame_deassembly`, and `f3981273` for the stale master Qsys instance
pin) is the intended closure path: the next build must prove that no
run-control fan-out adapter can deassert splitter ready.

Log: `reports/phase4_postfix1_20260511_213411.log`.

### 4.8 Phase 4 rc-readyless rebuild gate (handoff status, 2026-05-12)

The next Phase 4 retest should use the SOF from
`firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/`, which folds
in all three required fixes:

| Fix | Required source state | Status |
|---|---|---|
| SC-WEDGE | `feb_system_v3.qsys` keeps `control_path_subsystem.clk156_in_rst` on `cclk156_source.clk_reset`, not `ext_hard_reset` | master pre-flight complete |
| hist-debug-disconnect | `scifi_datapath_system_v3*.qsys` has the 6 debug AVST histogram connections removed | master pre-flight complete |
| rc-readyless | all 6 run-control sink IPs declare readyless AVST sinks, including `mutrig_frame_deassembly` 26.2.0.0511 | IP + master Qsys pre-flight complete |

Master Qsys pre-flight commit:
`f3981273` (`[FIX] Pre-flight master qsys bump for rc-readyless full rollout
(mutrig_frame_deassembly_0)`). It records:

- `quartus_systems/feb_system_v3.qsys` version `3.0.2.0511 -> 3.0.3.0511`.
- `quartus_systems/scifi_datapath_system_v3{,_pipe,_lat4}.qsys` version
  `3.0.2.0511 -> 3.0.3.0511`.
- `quartus_systems/mutrig_datapath_system_v3.qsys` system version
  `3.0.0.0511 -> 3.0.1.0511`.
- `mutrig_frame_deassembly_0` instance pin
  `26.1.0.0506 -> 26.2.0.0511`.
- `tb_int/doc/BUG_HISTORY.md` entry `BUG-002-R`, documenting the stale
  Qsys instance pin that allowed a run-control timing adapter to remain.

Current build-directory state at handoff:

| Item | Expected for retest | Current status |
|---|---|---|
| build dir | `v3_pretest-260511-rc-readyless-260511/` | exists |
| `syn/` tree | copied baseline plus regenerated master Qsys systems | generated |
| qsys-generate log | `syn/feb_system_v3_qsys_generate_<TS>_isolated.status` + console log | **pass**: `syn/feb_system_v3_qsys_generate_20260512_005752_isolated.status`, `exit_code=0`, `error_count=0` |
| run-control adapter proof | no `run_control_splitter` fan-out adapter can deassert ready | **pass**: ready-to-readyless wrappers drive `in_ready=1`; outputs 6/14/15 are direct ready consumers |
| Quartus compile | `quartus_compile_top_<TS>_rcreadyless.status` + console log | **flow pass**: `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_20260512_010600_rcreadyless.status`, `exit_code=0`, runtime `2445` s |
| SOF | `syn/board_projects/fe_scifi_feb_v3/output_files/top.sof` | **exists**: `12678639` bytes, SHA-256 `2171cd90643967aef85993ac384707807ffcf418b1b23652443277bd3f8d3f2e` |
| compile report | `doc/RC_READYLESS_COMPILE.md` | updated with Qsys, adapter, resources, timing violations, SOF/RBF hashes |
| SignalTap gap compile | `doc/RC_READYLESS_STP_COMPILE.md`, revision `top_stp_phase4_rc_readyless_gap` | **flow pass**: `99/99` probes found, SignalTap `35024` connected, full compile `rc=0`; debug-load candidate only |
| SignalTap gap capture | `doc/RC_READYLESS_STP_CAPTURE.md`, capture `phase4_rc_readyless_gap_20260512_042348` | **complete / Phase 4 still fail**: run-control reaches emulator lane 0 and `run_generating=1`; `aso_tx8b1k_valid` never asserts |

`v3_pretest-260511-rc-readyless-260511` now has a generated SOF/RBF, but it is
**not timing-clean**. `output_files/top.sta.rpt` reports timing not met at the
two slow corners and also reports unconstrained setup/hold requirements. Do not
use this as a production/signoff image. For the Phase 4 hardware-first debug
loop, it is only a debug-load candidate if the shared bench owner accepts the
FEB iterative-debug timing relaxation.

Compile/timing facts:

- Full Quartus flow: successful, `0 errors`, `1580 warnings`.
- SOF: `output_files/top.sof`, SHA-256
  `2171cd90643967aef85993ac384707807ffcf418b1b23652443277bd3f8d3f2e`.
- RBF: `output_files/top.rbf`, SHA-256
  `b3a7c4fa070228b0a0629f9170b7c23056436b7d65e2c43ee5caa1565e23d000`.
- Slow 1100 mV 85 C setup: LVDS RX `pll_sclk` divclk slack `-1.029`,
  TNS `-138.950`; `transceiver_pll_clock[0]` slack `-0.223`, TNS `-0.842`.
- Slow 1100 mV 85 C recovery: `lvds_firefly_clk` slack `-1.324`,
  TNS `-4110.829`.
- Slow 1100 mV 0 C setup: LVDS RX `pll_sclk` divclk slack `-0.707`,
  TNS `-60.808`.
- Slow 1100 mV 0 C recovery: `lvds_firefly_clk` slack `-1.225`,
  TNS `-3804.867`.
- Other critical warning: Nios RAM init depth mismatch (`16384` design depth vs
  `32768` init-file depth), with Quartus truncating the extra init content.

Dedicated SignalTap gap-compile facts:

- STP source:
  `v3_pretest-260511-rc-readyless-260511/signaltap/phase4_rc_readyless_gap.stp`.
- Node Finder report:
  `v3_pretest-260511-rc-readyless-260511/signaltap/phase4_rc_readyless_gap_nodes.md`,
  `99/99` probes found, `0` missing.
- Quartus revision: `top_stp_phase4_rc_readyless_gap`; output directory:
  `syn/board_projects/fe_scifi_feb_v3/output_files_stp_phase4_rc_readyless_gap_clkfix`.
- Acquisition clock fixed to the exported Qsys port `lvds_outclock_clk`.
  The previous internal-name attempt used `lvds_rx_28nm_0_outclock_clk` and
  produced an acquisition-clock disconnect warning; do not reuse it.
- SignalTap map evidence:
  `Info (35024): Successfully connected in-system debug instance
  "phase4_rc_readyless_gap_lvds" to all 231 required data inputs, trigger
  inputs, acquisition clocks, and dynamic pins`.
- Full STP compile:
  `quartus_compile_top_stp_phase4_rc_readyless_gap_clkfix_20260512_0328.console.log`,
  watcher result `rc=0`, `0 errors`, `1580 warnings`.
- STP SOF: `top_stp_phase4_rc_readyless_gap.sof`, SHA-256
  `7dd7f9303a7551d4b0074136a38f2b818ad37e1d20ec4a9decfd6dd21e7f03ad`.
- STP RBF: `top_stp_phase4_rc_readyless_gap.rbf`, SHA-256
  `70bd0ec7f67d48e500f14dc6232a616f90645eb278606ac25922760bd38e9a6c`.
- STP JDI: `top_stp_phase4_rc_readyless_gap.jdi`, SHA-256
  `362404a223d94d36e24fa0d5c3f4b4c3b061947ab7a68fc9029fc5a49bfa26d9`.
- STP timing status: slow 85 C setup/recovery fail (`-1.345` / `-1.335`);
  slow 0 C setup/recovery fail (`-1.177` / `-1.242`); both fast corners pass.
  This satisfies the FEB iterative-debug rule of at least 2 of 4 corners
  during the debug loop, but it is not production/signoff timing closure.

Dedicated SignalTap capture facts:

- Capture report:
  `v3_pretest-260511-rc-readyless-260511/doc/RC_READYLESS_STP_CAPTURE.md`.
- Capture directory:
  `v3_pretest-260511-rc-readyless-260511/signaltap/captures/phase4_rc_readyless_gap_20260512_042348`.
- Stimulus: preconditioned `LOCAL_CMD=0x10`, `0x11`, then armed STP and issued
  `LOCAL_CMD=0x12`.
- VCD:
  `local_start_run.vcd`; parsed summary:
  `local_start_run_vcd_summary.log`.
- Trigger result: `run_control_splitter.out15_valid` rose at `128500 ps` with
  `out15_data=0x008`; `emulator_ctrl_splitter.out0_valid` and
  `emulator_mutrig_0.asi_ctrl_valid` rose at the same timestamp with
  `0x008`.
- Emulator result: `run_generating` first high at `129500 ps`, final
  `frame_rst=0`, final `aso_tx8b1k_valid=0`, final
  `aso_tx8b1k_data=0x1bc`.
- Post-capture counters: histogram `TOTAL_HITS=0`, `PORT_STATUS=0xFF`, and
  HSS0/HSS1 actual-hit counters remain zero.
- Preliminary root-cause evidence:
  `syn/feb_system_v3.sopcinfo` wires all eight
  `data_path_subsystem_emulator_mutrig_N.tx8b1k` outputs to decoded-lane mux
  inputs while the emulator instances keep `BYTE_STREAM_ENABLE=false`; RTL then
  intentionally ties `aso_tx8b1k_valid` low and drives idle K28.5.

The required adapter proof after qsys-generate is:

```bash
cd firmware_builds/systems/v3_pretest-260511-rc-readyless-260511
rg -n "outUseReady|timing_adapter_0" \
  syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem_avalon_st_adapter_018.v
rg -n "ready\\[0\\] = 1|in_ready\\s*=\\s*ready\\[0\\]" \
  syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem_avalon_st_adapter_018_timing_adapter_0.sv
rg -n "run_control_splitter_out(6|14|15)_" \
  syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem.vhd
```

Expected result: any generated ready-to-readyless adapter on the splitter
fan-out must have `outUseReady=0` and must drive `in_ready=1`; direct outputs
6/14/15 must terminate at ordinary ready/valid consumers. A literal
`timing_adapter` filename match is not a failure in Quartus 18.1; a
ready-deasserting adapter is the failure.

The rc-readyless SOF was retested on hardware after bench-queue claim/release.
See §4.10 for the raw log pointers and counter table. Phase 4 remains failed:
`runctl_mgmt_host_0.LOCAL_CMD` and `dbg_mm2runctrl_0.HOST_CMD` both inject
start-run successfully, but `TOTAL_HITS`, `LAST_INT_HITS`, and
`feb_frame_assembly_HSS0/HSS1` actual-hit counters remain zero.

The follow-up SignalTap capture is now decisive enough for the next fix loop:
`LOCAL_CMD=0x12` propagates through `run_control_mux`,
`run_control_splitter.out15`, `emulator_ctrl_splitter.out0`, and
`emulator_mutrig_0.asi_ctrl`; lane 0 asserts `run_generating` and deasserts
`frame_rst`, but `aso_tx8b1k_valid` never asserts and `aso_tx8b1k_data` stays
at idle `0x1bc`.

Hardware-first debug status:

1. Qsys regeneration and the generated-wrapper adapter proof are complete.
2. Quartus compile and SOF/RBF generation are complete, but timing is not
   clean; the image is a debug-load candidate only under the FEB
   iterative-debug relaxation.
3. Shared-bench hardware retest was run on the exact SOF SHA-256
   `2171cd90643967aef85993ac384707807ffcf418b1b23652443277bd3f8d3f2e`.
4. The retest still shows zero hit flow after `run-prepare -> sync ->
   start-run` and after direct `dbg_mm2runctrl` start-run injection.
5. A focused SignalTap gap tap now exists and is Node-Finder clean:
   `v3_pretest-260511-rc-readyless-260511/signaltap/phase4_rc_readyless_gap.stp`,
   report
   `v3_pretest-260511-rc-readyless-260511/signaltap/phase4_rc_readyless_gap_nodes.md`
   (`99/99` probes found). Quartus import/map/full compile are complete for
   revision `top_stp_phase4_rc_readyless_gap`.
6. The shared-bench STP capture is complete:
   `v3_pretest-260511-rc-readyless-260511/signaltap/captures/phase4_rc_readyless_gap_20260512_042348/local_start_run.vcd`.
   It moves the known-good boundary through emulator run-control and identifies
   the first missing observable as the lane-0 `tx8b1k` byte-stream valid.

Confirmatory simulation evidence from 2026-05-12 is recorded in
`tb_int/REPORT/RC_EMUL/REPORT.md`. The run
`SIM_ROOT=sim/iter_20260512_rc_emul make run_RC_EMUL_BLOCKED run_RC_EMUL_FIXED`
shows the behavioural mirror in two modes:

- `RC_EMUL_BLOCKED`: `TOTAL_HITS=0x00000000`, showing the blocked splitter
  fan-out model reproduces the hardware-class symptom.
- `RC_EMUL_FIXED`: `TOTAL_HITS=0x00000010`, showing the ready-tied model lets
  the run-control broadcast propagate in the mirror.

Both runs have `UVM_ERROR=0`, `UVM_FATAL=0`, 16 pre/post/FEB closed records,
and zero drops. This is **not** a hardware closure artifact: the harness is a
behavioural mirror and hardware counters are unavailable in
`counter_agreement.csv`.

The 2026-05-12 STP capture supersedes the behavioural mirror as the decisive
hardware boundary. The quick support sim in
`v3_pretest-260511-rc-readyless-260511/signaltap/captures/phase4_rc_readyless_gap_20260512_042348/sim_byte_stream_disable.log`
elaborates `emulator_mutrig` with `BYTE_STREAM_ENABLE=0` and reports
`tx_valid=0`, `tx_data=1bc`, matching the captured idle byte-stream output.

### 4.9 Phase 4 plot and RDMA closure status (math review, 2026-05-12)

Independent math/DV review found no current end-to-end hit-loss closure. Treat
the current blocker as hardware-first until a positive-hit board run exists.

Current non-closure facts:

- Latest Phase 4 hardware evidence is the pre-HSS STP capture in
  `v3_pretest-260511-rc-readyless-260511/signaltap/captures/phase4_pre_hss_gap_20260512_050729/`
  and report `v3_pretest-260511-rc-readyless-260511/doc/PRE_HSS_STP_CAPTURE.md`.
  Reset-link `start-run` reaches the emulator and `run_generating` asserts, but
  `aso_tx8b1k_valid`, `avalon_st_adapter_032.in_0_valid`,
  `decoded_lane_mux_0.in1_valid`, MTS valid outputs, histogram pre/post valids,
  and HSS counters remain zero.
- The rc-readyless gate, disabled-byte-stream contract fix, and pre-HSS STP
  compile have all advanced the hardware boundary, but there is still no
  positive legal hit-flow capture. The exact hardware-stimulus sim now
  reproduces the zero-byte-stream result when `emu_signal=1` and shows that
  changing only `SIGNAL` to `0` restores byte-stream valid. The next required
  artifact is therefore a corrected-stimulus hardware capture that shows
  `tx8b1k_valid` and downstream pre-HSS valid movement before any
  rate/latency/RDMA closure can be accepted.
- The RDMA/SWB checklist is explicitly non-passing as of
  `2026-05-11T02:39:05Z`: `pass_rows=0`, `fail_rows=631`, `pending_rows=320`
  in `rdma_subsystem/test_plan/CHECKLIST.md`.

Existing Phase 4 plots under
`systems/system_20260427_testplanphase5/model/phase4/artifacts/` are useful
historical calibration, not current-build closure:

- `phase4_rate_sweep.{csv,png,svg}` shows the model/HDL physical cap at
  200 Mhit/s, but the historical board curve knees near 135 Mhit/s. Rate
  sign-off remains open.
- `phase4_latency_tlm_vs_rtl.{csv,png,svg}` shows the old RTL latency histogram
  extending to about 1.6k cycles while the TLM short-frame model support is
  around one 910-cycle frame. That RTL data is stale for short-frame latency
  sign-off.
- `phase4_queue_depth_regions.{csv,png,svg}` and
  `phase4_mutrig_latency_model.{csv,png,svg}` are model/truth artifacts. They
  define expectations and debug hypotheses, but they do not prove the current
  FEB/SWB/RDMA chain.

The next accepted plot packet must be generated after the current build has
positive hardware hit flow. It must include raw CSV bins, rendered PNG/SVG,
script provenance, firmware/SOF/build identifiers, CP or run ID, seed/run
duration, and machine-readable pass/fail JSON.

### 4.10 Phase 4 rc-readyless hardware retest 2026-05-12

The rc-readyless debug SOF was flashed and retested on hardware under a shared
bench-queue claim. The programmed image was
`v3_pretest-260511-rc-readyless-260511/syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`,
SHA-256 `2171cd90643967aef85993ac384707807ffcf418b1b23652443277bd3f8d3f2e`.

Raw artifacts:

- `reports/phase4_rc_readyless_20260511_235457.log` — program/recovery
  preflight. FEB program succeeded and basic SC reads passed, but emulator2
  UID read hit `SC secondary did not report ready after reset`.
- `reports/phase4_rc_readyless_sc_recovery_20260511_235558.log` — post-PCIe
  recovery sanity pass. Scratch, sc_hub UID, emulator2 UID, histogram UID,
  total hits, and runctl status all read correctly.
- `reports/phase4_rc_readyless_runctl_20260511_235638.log` — decisive
  run-control/counter pass; aggregate exit code 0.
- `v3_pretest-260511-rc-readyless-260511/signaltap/phase4_rc_readyless_gap.stp`
  and `phase4_rc_readyless_gap_nodes.md` — first SignalTap gap tap, Node Finder
  `99/99` probes found. The fixed STP revision now imports and compiles through
  Quartus as `top_stp_phase4_rc_readyless_gap`.
- `v3_pretest-260511-rc-readyless-260511/doc/RC_READYLESS_STP_COMPILE.md` —
  SignalTap compile report for the gap tap. The compile log is
  `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_stp_phase4_rc_readyless_gap_clkfix_20260512_0328.console.log`;
  output files live in
  `syn/board_projects/fe_scifi_feb_v3/output_files_stp_phase4_rc_readyless_gap_clkfix`.
  Map connected the SignalTap instance to all 231 required inputs, and the STP
  SOF hash is
  `7dd7f9303a7551d4b0074136a38f2b818ad37e1d20ec4a9decfd6dd21e7f03ad`.
- `v3_pretest-260511-rc-readyless-260511/doc/RC_READYLESS_STP_CAPTURE.md` —
  on-board SignalTap capture report. Capture files live under
  `signaltap/captures/phase4_rc_readyless_gap_20260512_042348/`; the primary
  files are `local_start_run.vcd`, `local_start_run_vcd_summary.log`,
  `local_start_run_stp.log`, `local_start_run_stim.log`,
  `post_capture_counters.log`, and `sim_byte_stream_disable.log`.

Decisive counter results from the run-control pass:

| Checkpoint | Evidence |
|---|---|
| SWB link lock | `LINK_LOCKED_LOW` majority `0x00000F00`; stable bits b11..b8 only, link bit 2 stable 0 |
| Run-control LOCAL_CMD | writes `0x10`, `0x11`, `0x12` produce `LAST_CMD=0x12`, `RX_CMD_COUNT=3`, `STATUS=0x00000003` |
| Histogram after start-run | `BANK_STATUS` toggles 0/1/0 across samples, but `PORT_STATUS=0x000000FF`, `TOTAL_HITS=0`, `LAST_INT_HITS=0`, drop/under/overflow 0 |
| Frame assembly after start-run | HSS0/HSS1 type words `0x38`, actual-hit high/low counters all 0 |
| Direct `dbg_mm2runctrl` injection | `SENT_COUNT 0 -> 1`, `LAST_SENT=0x00004A08`, `STATUS=0x00000821` |
| After direct injection | `TOTAL_HITS=0`, `PORT_STATUS=0xFF`, HSS0/HSS1 actual counters 0 |
| Cleanup | end-run sets `LAST_CMD=0x13`, `RX_CMD_COUNT=4`, scratch re-read remains 0 |

Decisive SignalTap gap-capture results:

| Checkpoint | Evidence |
|---|---|
| STP trigger | `run_control_splitter.out15_valid` rising edge captured after `LOCAL_CMD=0x12` |
| Run-control payload | `run_control_mux.out_data=0x008`, `run_control_splitter.out15_data=0x008` |
| Emulator-control fan-out | `emulator_ctrl_splitter.out0_valid` and `emulator_mutrig_0.asi_ctrl_valid` first high at `128500 ps`, payload `0x008` |
| Emulator run state | `run_generating` first high at `129500 ps`, final `run_generating=1`, final `frame_rst=0` |
| First byte-stream source | `aso_tx8b1k_valid` never high; final `aso_tx8b1k_data=0x1bc` |
| Counter aftermath | Histogram `TOTAL_HITS=0`, `PORT_STATUS=0xFF`; HSS0/HSS1 actual counters remain 0 |
| Source/sim confirmation | generated `.sopcinfo` has `BYTE_STREAM_ENABLE=false` while wiring `emulator_mutrig_N.tx8b1k` to decoded-lane muxes; minimal Questa log reports `tx_valid=0`, `tx_data=1bc` for `BYTE_STREAM_ENABLE=0` |

Verdict: **PHASE 4 FAIL — rc-readyless did not clear the zero-hit blocker**.
Known-good now extends through run-control CSR reception, direct
`dbg_mm2runctrl` command injection, `run_control_splitter.out15`,
`emulator_ctrl_splitter.out0`, `emulator_mutrig_0.asi_ctrl`, and lane-0
`run_generating`. The first failed observable is the byte-stream source:
`aso_tx8b1k_valid` is tied low while downstream Qsys consumes `tx8b1k`.
The next fix loop must either set `BYTE_STREAM_ENABLE=true` for all eight
emulator instances on the current `tx8b1k` path, or rewire the integration to
consume the emulator's direct `hit_type0` source instead. That
`BYTE_STREAM_ENABLE=true` path was built and smoked in §4.11; the later
pre-HSS STP capture in §4.13 shows the byte-stream valid is still dark under
the exact board stimulus, so §4.10 is no longer the latest active boundary.

### 4.11 Phase 4 byte-stream contract fix candidate 2026-05-12

The follow-up fix keeps the existing decoded-lane mux wiring and enables the
emulator byte-stream output. The 2026-05-12 hardware smoke retires the captured
`aso_tx8b1k_valid=0` / disabled-byte-stream blocker as a build-contract issue,
but it is still not Phase 4 closure. The first smoke produced post-selected
histogram counter activity, and the follow-up pre-HSS probe showed that activity
is not yet legal hit-flow evidence: `histogram_ingress_bridge_0.pre_in`,
`mts_preprocessor_0.hit_type1_out`, rbCAM, and
`feb_frame_assembly_HSS0/HSS1` remain dark.

The later pre-HSS STP capture in §4.13 supersedes the broad interpretation of
this smoke: enabling `BYTE_STREAM_ENABLE` was necessary for the wired
`tx8b1k` path, but it was not sufficient under the actual board
JTAG/reset-link stimulus. `aso_tx8b1k_valid` is still the first failed
observable in the latest hardware capture. The §4.13 directed sim then
reproduces that failure with `emu_signal=1` and restores byte-stream output
when only `SIGNAL` is changed to `0`.

Source/Qsys state:

- Tcl recipe:
  `firmware_builds/systems/v3_pretest-260511/script/update_v3_byte_stream_contract.tcl`.
- Wrapper:
  `firmware_builds/systems/v3_pretest-260511/script/apply_v3_byte_stream_contract.sh`.
- Applied to
  `quartus_systems/scifi_datapath_system_v3{,_pipe,_lat4}.qsys`; each file now
  has eight `BYTE_STREAM_ENABLE=true` emulator instance parameters.
- `quartus_systems/feb_system_v3.qsys` was also validated through the same
  recipe to keep the wrapper system in the reproducible Qsys path.

Generated-system evidence:

- Regeneration status:
  `v3_pretest-260511-rc-readyless-260511/syn/feb_system_v3_qsys_generate_20260512_044214_byte_stream_fix_isolated.status`,
  `exit_code=0`, `error_count=0`.
- Regenerated `.sopcinfo` has eight `BYTE_STREAM_ENABLE` parameters at
  emulator instances and still wires
  `data_path_subsystem_emulator_mutrig_N.tx8b1k` to
  `data_path_subsystem_decoded_lane_mux_N.in1` for lanes `0..7`.

Directed simulation evidence:

- Run directory:
  `v3_pretest-260511-rc-readyless-260511/tb_int/sim_byte_stream_axis_20260512_0443/`.
- `BYTE_STREAM_ENABLE=0`: `valid_high_count=0`, `first_valid_ps=None`,
  first data stays idle `110111100` (`0x1bc` with control bit).
- `BYTE_STREAM_ENABLE=1`: `valid_high_count=16`, first valid at
  `12708000 ps`.

Compile result:

- Compile log:
  `v3_pretest-260511-rc-readyless-260511/syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_20260512_0445_byte_stream_fix.console.log`.
- Flow result: `Quartus Prime Full Compilation was successful. 0 errors,
  1587 warnings`; elapsed `00:37:42`, CPU `02:02:51`.
- Fresh SOF:
  `syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`,
  SHA-256 `c8239ef1ab2f0bc21da91e0de41ca4c452531cb363677c43c9fb3f7930712dcd`,
  size `12678659`.
- Fresh RBF:
  `syn/board_projects/fe_scifi_feb_v3/output_files/top.rbf`,
  SHA-256 `5dc37ae000a5e37a677f8dcae0a62e769416675342a8409a88f86807e4951bd1`,
  size `7079716`.
- Fitter resources: `65,358 / 91,680` ALMs (`71%`), `101241` registers,
  `4,130,506 / 13,987,840` block-memory bits (`30%`), `556 / 1,366` RAM
  blocks (`41%`), HSSI TX `8 / 9` (`89%`).
- Timing status: debug-load only, not production signoff. Slow 85C setup worst
  slack is `-2.226 ns`, slow 85C recovery worst slack is `-1.339 ns`; the
  image is acceptable only under the iterative-debug FEB rule.

Hardware smoke evidence:

- Artifact directory:
  `v3_pretest-260511-rc-readyless-260511/hw_smoke/phase4_byte_stream_fix_20260512_0526/`.
- Bench queue: claimed as `codex_v3_byte_stream_fix_smoke`, prolonged once,
  and released after teardown.
- Programming: `program_feb.log` shows `quartus_pgm` success on
  `USB-BlasterII [7-2]` and the mandatory 20 s FEB settle.
- PCIe recovery: `mudaq_recover_pcie.log` unloads and reloads `mudaq`.
- JTAG run-control setup: `jtag_setup_start.log` writes
  `{0x00FFFF30, 0x00000240, 0x00FFFF31, 0x01023510, 0x00000011, 0x00000012}`;
  `runctl_status=0x00000003`, `runctl_last_cmd=0x00020012`.
- SC run-control readback before end-run:
  `sc_runctl_last_cmd.log` returns `0x00020012` and
  `sc_runctl_rx_cmd_count.log` returns `0x00000006`. After JTAG teardown,
  `sc_runctl_last_cmd_after_end.log` returns `0x00020013` and
  `sc_runctl_rx_cmd_count_after_end.log` returns `0x00000007`.
- Rate-configured post-selected histogram dump:
  `jtag_setup_start.log` uses `hist_snoop_source=post`; the corresponding
  `hist_rate_dump.log` reports `live_select_post 1` and
  `post_hit_filter_enabled 0`.
  `hist_rate_dump.log` reports `stats_after_wait={underflow_count 0
  overflow_count 0 total_hits 836042 dropped_hits 0 ... last_interval_total_hits
  7995716 last_interval_dropped_hits 0}`. The CSV
  `hist_rate_bins.csv` sums to `7995716` counts, all in bin `0`.
- Independent SC histogram read after the rate dump:
  `sc_hist_after_rate_0x0A908_len11.log` returns `UNDERFLOW=0`,
  `OVERFLOW=0`, `PORT_STATUS=0x000200FF`, `TOTAL_HITS=0x001C9282`,
  `DROPPED_HITS=0`, `COAL_STATUS=0x00000100`,
  `LAST_INT_HITS=0x007A0144`.
- HSS frame-assembly counters are still zero:
  `sc_hss0_after_hist_rate.log` and `sc_hss1_after_hist_rate.log` both show
  declared/actual/missing hit high/low words all `0`.
- Interpretation: because the post path was selected with the post-hit filter
  disabled, this is word-counter evidence, not a hit-conservation proof.

Pre-HSS boundary probe:

- Artifact directory:
  `v3_pretest-260511-rc-readyless-260511/hw_smoke/phase4_pre_hss_probe_20260512_0541/`.
- Bench queue: claimed as `codex_v3_pre_hss_probe` and released after teardown.
- Programming and recovery:
  `program_feb.log` reloads the same byte-stream-fix SOF
  (`c8239ef1ab2f0bc21da91e0de41ca4c452531cb363677c43c9fb3f7930712dcd`) and
  waits the mandatory 20 s; `mudaq_recover_pcie.log` reloads `mudaq`.
- JTAG setup:
  `jtag_setup_pre_start.log` uses `hist_snoop_source=pre`,
  `selector={source pre ...}`, `runctl_last_cmd=0x00020012`, and one active
  emulator lane (`active_lane=0`, `emu_hit_rate=0x00000800`).
- Pre-HSS histogram dump:
  `hist_pre_rate_dump.log` reports `live_select_post 0`,
  `pre_packet_active 0`, `post_packet_active 0`, and all histogram statistics
  zero after the 1.1 s wait. `hist_pre_rate_bins.csv` has
  `sum(count)=0`.
- Independent SC histogram read:
  `sc_hist_pre_after_rate_0x0A908_len11.log` returns `TOTAL_HITS=0`,
  `DROPPED_HITS=0`, `LAST_INT_HITS=0`, `UNDERFLOW=0`, `OVERFLOW=0`, and
  `PORT_STATUS=0x000000FF`.
- Stage counters:
  `sc_mts0_after_pre_rate_0x09000_len5.log` and
  `sc_mts1_after_pre_rate_0x0A000_len5.log` keep their visible totals at zero;
  all eight rbCAM snapshots under `0x0AC00..0x0AD60` return the `RBCM` UID with
  push/pop/error-style payload words still zero; HSS0/HSS1 declared/actual/
  missing counters remain zero.
- Teardown:
  `jtag_teardown_pre_stop.log` reaches `runctl_last_cmd=0x00020013`.

Debug gate after this smoke, superseded by §4.13:

1. Treat the Qsys `BYTE_STREAM_ENABLE=true` change as the fix for the captured
   disabled-byte-stream contract, but keep the hardware claim limited to
   post-selected histogram word-counter activity.
2. The active hardware gap is now upstream of the pre-HSS hit stream:
   post-selected histogram counts are nonzero, while
   `histogram_ingress_bridge_0.pre_in` / `mts_preprocessor_0.hit_type1_out`,
   MTS visible totals, rbCAM push/pop-style counters, and HSS counters are zero.
3. Use the next hardware-first loop to probe `decoded_lane_mux_0.out`,
   decoded-lane FIFO output, mutrig-datapath type0 output,
   `mts_preprocessor_0.hit_type0_in`, `mts_preprocessor_0.hit_type1_out`, and
   `histogram_ingress_bridge_0.pre_in/pre_out`. The focused SignalTap source
   for that gap is now imported and compiled as
   `top_stp_phase4_pre_hss_gap`; use the compiled image for the next
   hardware-first capture. Caveat: Node Finder resolves `76/76` probes, but
   map connects only `129/185` SignalTap inputs because wide payload, channel,
   and error aliases are not preserved. Treat it as a loadable handshake/stage
   localization image, not a payload-complete capture image. This capture has
   now been run; see §4.13 for the current blocker.

### 4.12 Phase 4 pre-HSS SignalTap compile 2026-05-12

Purpose: narrow the active hardware gap left by §4.11. Post-selected histogram
word counters advance, but legal pre-HSS hit flow is still dark at
`histogram_ingress_bridge_0.pre_in/pre_out`,
`mts_preprocessor_0.hit_type1_out`, MTS visible totals, rbCAM payload counters,
and HSS frame-assembly counters.

Supporting sim:

- Testbench:
  `v3_pretest-260511-rc-readyless-260511/tb_int/tb_pre_hss_axis.sv`.
- Run directory:
  `v3_pretest-260511-rc-readyless-260511/tb_int/sim_pre_hss_axis_20260512/`.
- Result:
  ```text
  PRE_HSS_AXIS_COUNTS tx_valid=11659 emu_type0=1919 parser_headers=19 parser_hits=1918
  *** PRE_HSS_AXIS PASSED ***
  Errors: 0, Warnings: 11
  ```
- Interpretation: the reduced source/parser path is decodable in sim, but this
  does not explain the on-board dark pre-HSS boundary and is not an RTL-fix
  proof.

SignalTap compile:

- Report:
  `v3_pretest-260511-rc-readyless-260511/doc/PRE_HSS_STP_COMPILE.md`.
- STP file:
  `v3_pretest-260511-rc-readyless-260511/signaltap/phase4_pre_hss_gap.stp`.
- Dedicated revision:
  `top_stp_phase4_pre_hss_gap`.
- Node Finder:
  `phase4_pre_hss_gap_nodes_top_stp_phase4_pre_hss_gap.md`, `76/76` probes
  found, `0` missing.
- Full compile:
  `Quartus Prime Full Compilation was successful. 0 errors, 1580 warnings`;
  watcher `rc=0`, elapsed `00:38:35`, CPU `02:06:57`.
- Programming files:
  `output_files_stp_phase4_pre_hss_gap/top_stp_phase4_pre_hss_gap.sof`
  SHA-256 `bbb2b17af1a65c63394acfae40606968565dd562f54d5606ca6ce2aa77dd939c`,
  size `12684913`; `.rbf` SHA-256
  `f472dbbae6a1b64ef57aaa0d150c0f57e1aefd8393f791a302da58c60cdd7d46`,
  size `7117568`.
- Fitter resources: `65,557 / 91,680` ALMs (`72%`), `102648` registers,
  `4,209,354 / 13,987,840` block-memory bits (`30%`), `564 / 1,366` RAM
  blocks (`41%`), HSSI TX `8 / 9` (`89%`).
- Timing status: debug-load only, not production signoff. Slow 85C setup
  slack `-1.097 ns`, slow 85C recovery slack `-1.330 ns`; slow 0C setup
  `-0.728 ns`, slow 0C recovery `-1.236 ns`. Both fast corners pass, so it
  meets the FEB iterative-debug rule of `2/4` corners passing.

SignalTap caveat:

- Quartus map reports `Critical Warning (35025)`: instance
  `phase4_pre_hss_gap_lvds` is partially connected to `129` of `185` required
  inputs, with `56` missing sources/connections.
- The missing unique aliases are payload/channel/error style probes such as
  `decoded_lane_mux_0_out_{channel,data,error}`,
  `decoded_lane_fifo_0_out_{channel,data,error}`,
  `mutrig_datapath_subsystem_0_hit_type0_out_{channel,data,error}`,
  `mts_preprocessor_0_hit_type1_out_{channel,data}`, and
  `histogram_ingress_bridge_0_{pre_out_data,hist_out_data}`.
- Use this image to localize the first dark handshake/stage on hardware. If
  the next capture needs actual payload words, regenerate with preserved/source
  pre-synthesis payload taps or retarget payload probes to post-synthesis nets.

Compile-time next hardware action was to claim the bench queue, program
`top_stp_phase4_pre_hss_gap.sof`, arm `phase4_pre_hss_gap.stp`, and capture the
first missing transition between decoded-lane mux/FIFO, mutrig-datapath type0,
MTS ingress/egress, and the histogram pre tap. Do not treat the sim-only
pre-HSS smoke as closure. The resulting capture is recorded in §4.13.

### 4.13 Phase 4 pre-HSS SignalTap capture 2026-05-12

The §4.12 hardware action has now been run. This capture is the current Phase 4
source of truth and keeps Phase 4 failed.

Report and artifacts:

- Capture report:
  `v3_pretest-260511-rc-readyless-260511/doc/PRE_HSS_STP_CAPTURE.md`.
- Capture directory:
  `v3_pretest-260511-rc-readyless-260511/signaltap/captures/phase4_pre_hss_gap_20260512_050729/`.
- Programmed STP SOF:
  `v3_pretest-260511-rc-readyless-260511/syn/board_projects/fe_scifi_feb_v3/output_files_stp_phase4_pre_hss_gap/top_stp_phase4_pre_hss_gap.sof`,
  SHA-256
  `bbb2b17af1a65c63394acfae40606968565dd562f54d5606ca6ce2aa77dd939c`.
- Successful VCD:
  `run_generating_start_run.vcd`; parsed summary:
  `run_generating_vcd_summary.log`.

Bench and setup facts:

- Bench queue was claimed before programming and released after teardown.
- FEB programming succeeded with Quartus checksum `0x147FE76A`, `0` errors,
  `0` warnings, followed by the mandatory 20 s settle.
- PCIe was recovered with `mudaq_recover_pcie` and the `mudaq` module reloaded.
- JTAG setup required explicit data/upload master patterns under the FEB
  `USB-BlasterII [7-2]` path.
- Stimulus used lane 0 in emulator mode:
  `hist_snoop_source=pre`, `emu_hit_rate=0x00000800`,
  `emu_control=0x00000001`, `emu_signal=0x00000001`,
  `MUTRIG_FORMAT=0x00000020`, and `cluster_fix=0x00004000`.

Trigger sequence:

- First attempt used the original `decoded_mux_valid_rise` trigger. `rc_tool`
  `start-run` advanced reset-link status from `0x11000003` to `0x12000004`,
  but SignalTap timed out after 120 s with no trigger and no VCD export.
- The run state was cleaned with `end-run -> reset -> stop-reset`, then setup
  was repeated.
- A copied STP retargeted only the trigger expression to lane-0
  `run_generating` rising edge. The STP trigger name stayed
  `decoded_mux_valid_rise`.
- The retargeted capture reached SignalTap `DONE`, exported
  `run_generating_start_run.vcd`, and Quartus SignalTap ended with `0` errors,
  `0` warnings.

Decisive VCD facts:

| Checkpoint | Evidence |
|---|---|
| Emulator control input | `emulator_mutrig_0.asi_ctrl_valid` first high at `127500 ps`; `asi_ctrl_ready` stays ready |
| Emulator run state | `run_generating` first high at `128500 ps`, final `1`; `frame_rst` final `0` |
| Byte-stream source | `emulator_mutrig_0.aso_tx8b1k_valid` never high, `0` rises, final `0` |
| Byte-stream adapter | `avalon_st_adapter_032.in_0_valid` and `out_0_valid` never high |
| Decoded-lane mux input | `decoded_lane_mux_0.in1_valid` never high |
| Mutrig/MTS path | `hit_type0_out_valid`, `mux_mutrig2processor.out_valid`, and `mts_preprocessor_0.aso_hit_type1_valid` never high |
| Histogram path | `histogram_ingress_bridge_0.asi_pre_valid`, `aso_pre_valid`, `aso_hist_valid`, and `hist_post_cdc_0.out_valid` never high |

Some downstream valids, including `decoded_lane_mux_0.out_valid` and
`decoded_lane_fifo_0.*_valid`, are already high or toggling from the first
captured sample while the upstream byte-stream valid and mux input are dark.
They are not legal hit-flow proof and must not be used as closure evidence.

Post-capture counters:

- Histogram read `0x0A908`, 11 words: `PORT_STATUS=0x000000FF`,
  `TOTAL_HITS=0`, `DROPPED_HITS=0`, underflow `0`, overflow `0`.
- MTS0/MTS1 reads at `0x09000` and `0x0A000`: visible totals remain zero.
- HSS0/HSS1 reads at `0x0B400` and `0x0B410`: type/id words are present
  (`0x38`, `0x2`), but declared/actual/missing hit counters are all zero.
- Run-control readback after capture: `LAST_CMD=0x00020012`,
  `RX_CMD_COUNT=0x00000010`.
- Teardown sent `end-run` and reported `runctl_last_cmd=0x00020013`,
  `runctl_status=0x00000003`.

Directed sim confirmation:

- Testbench:
  `v3_pretest-260511-rc-readyless-260511/tb_int/tb_pre_hss_axis_hwstim.sv`.
- Run directory:
  `v3_pretest-260511-rc-readyless-260511/tb_int/sim_pre_hss_hwstim_20260512/`.
- Compile: `compile_emulator.log` and `compile_tb.log` report `Errors: 0`.
- Exact board tuple:
  `SIGNAL=0x1`, `MUTRIG_FORMAT=0x20`, `cluster_fix=0x4000` gives
  `tx_valid=0`, `type0=0`, first tx time `0`, final `tx_data=0x1bc`.
- One-bit control:
  changing only `SIGNAL` to `0x0` gives `tx_valid=3038`, `type0=481`,
  first tx at `253324000 ps`, with `Errors: 0`, `Warnings: 6`.

RTL interpretation: `frontend_trigger_engine.sv` launches internal random hits
only when `!cfg_hit_mode_sig`. The board setup's `emu_signal=1` writes
`SIGNAL[0]=1`, selecting signal/external mode. Because this setup did not
provide a matching external inject pulse, no tickets reach the lane emitter and
`aso_tx8b1k_valid` correctly remains zero.

Interim verdict for this capture: **PHASE 4 FAIL — this specific
`SIGNAL=1` setup is a stimulus/CSR mode mismatch, not an apparent downstream
rbCAM/HSS/RDMA datapath bug**. The hardware known-good boundary reaches
lane-0 emulator run-control and `run_generating`; sim confirms that
`emu_signal=1` explains the zero byte-stream source. The corrected-stimulus
hardware rerun is recorded in §4.14 and supersedes this as the current active
blocker boundary.

### 4.14 Phase 4 corrected-stimulus pre-HSS SignalTap capture 2026-05-12

Purpose: run the next hardware-first pass from §4.13 with internal random-hit
generation (`SIGNAL=0`) and determine whether the first missing legal-hit
boundary stays at the byte-stream source or moves downstream.

Report and artifacts:

- Capture report:
  `v3_pretest-260511-rc-readyless-260511/doc/PRE_HSS_STP_CAPTURE.md`.
- Capture directory:
  `v3_pretest-260511-rc-readyless-260511/signaltap/captures/phase4_pre_hss_signal0_20260512_053323/`.
- Trigger STP:
  `phase4_pre_hss_gap_trigger_txvalid.stp`; copied from
  `phase4_pre_hss_gap.stp` with only the trigger condition changed to
  `emulator_mutrig_0.aso_tx8b1k_valid` rising edge.
- VCD:
  `txvalid_start_run_default_signal0.vcd`; parsed summary:
  `txvalid_vcd_summary.log`.

Setup caveats:

- The explicit System Console setup with `--emu-signal 0` failed twice before
  run start with a Java `ThreadPoolExecutor` rejection.
- The partial SC readback after that failure did show lane 0
  `SIGNAL=0`, but also showed default-ish `MUTRIG_FORMAT=0x22` and default
  rate/cluster fields, not the exact sim tuple `format=0x20/cluster_fix=0x4000`.
- A reset attempt wedged the SC leaf path (`RSP3`, `0xEEEEEEEE`). The board was
  reprogrammed and PCIe recovered; the capture then used the fresh image's
  default internal-random `SIGNAL=0` state and avoided reset during teardown.

Run-control and capture facts:

- `run-prepare`: reset-link status `0x31000000 -> 0x00010299`.
- `sync`: `0x00010299 -> 0x11000003`.
- SignalTap capture with `start-run`: `0x11000003 -> 0x12000004`.
- SignalTap reached `DONE`, exported the VCD, and Quartus reported
  `0` errors, `0` warnings.
- Teardown used `end-run` only: `0x12000004 -> 0x13000000`.

Decisive VCD facts:

| Checkpoint | Evidence |
|---|---|
| Run state | `run_generating` high for all captured samples |
| Byte-stream source | `emulator_mutrig_0.aso_tx8b1k_valid` first high at `128500 ps`, `1408` one-samples |
| Adapter | `avalon_st_adapter_032.in_0_valid` and `out_0_valid` first high at `128500 ps`, `1408` one-samples |
| Decoded-lane mux input | `decoded_lane_mux_0.in1_valid` first high at `128500 ps`, `1408` one-samples |
| Decoded-lane FIFO | `decoded_lane_fifo_0.out_valid` toggles (`512` rises, `1024` one-samples); payload probes are not trusted in this STP image |
| Mutrig parser/header | `mutrig_datapath_subsystem_0.headerinfo_valid` and `hit_type0_out_valid` never high |
| MTS path | `mux_mutrig2processor.out_valid`, `mts_preprocessor_0.asi_hit_type0_valid`, and `aso_hit_type1_valid` never high |
| Histogram/HSS path | `histogram_ingress_bridge_0.asi_pre_valid`, `aso_pre_valid`, `aso_hist_valid`, and `hist_post_cdc_0.out_valid` never high |

Post-capture counters:

- Histogram read `0x0A908`, 11 words: `PORT_STATUS=0x000000FF`,
  `TOTAL_HITS=0`, drops/underflow/overflow all `0`.
- MTS0/MTS1 reads at `0x09000` and `0x0A000`: visible totals remain zero.
- HSS0/HSS1 reads at `0x0B400` and `0x0B410`: type/id words are present
  (`0x38`, `0x2`), but declared/actual/missing hit counters are all zero.
- Run-control readback: `LAST_CMD=0x00000012`, `RX_CMD_COUNT=0x00000003`.

Verdict: **PHASE 4 FAIL — corrected/default internal stimulus restores
byte-stream valid, but legal pre-HSS hit flow is still dark at the
mutrig-datapath parser/header boundary**. The current hardware known-good side
is now lane-0 `tx8b1k` valid through the adapter/mux/FIFO handshake boundary.
The unknown side starts at `mutrig_datapath_subsystem_0.headerinfo_valid` /
`hit_type0_out_valid` and remains dark through MTS, histogram, HSS, rbCAM, and
RDMA/offline proof. The next STP pass should probe emitted byte values, decoded
FIFO output payload/control, frame receiver parser state, and the parser CSR
and reset mode. A reliable SC/JTAG config path is also required before claiming
the exact `SIGNAL=0`, `MUTRIG_FORMAT=0x20`, `cluster_fix=0x4000` sim tuple on
hardware.

### 4.15 Parser-gap STP capture 2026-05-12

Purpose: run the next parser-gap capture from the §4.14 boundary with the
compiled parser-gap STP image and the supported SC `LOCAL_CMD` fallback path.
This attempt stopped at the SignalTap stop condition below and is not a valid
Phase 4 §4.2-§4.3 stimulus-qualified capture.

Image and setup:

- SOF:
  `v3_pretest-260511-rc-readyless-260511/syn/board_projects/fe_scifi_feb_v3/output_files_stp_phase4_parser_gap/top_stp_phase4_parser_gap.sof`.
- SOF SHA-256:
  `507c3b7ed78a39d08519595aedf1895d57199d9647f387eb5489955ea54545b7`.
- STP:
  `v3_pretest-260511-rc-readyless-260511/signaltap/phase4_parser_gap.stp`.
- Node Finder:
  `phase4_parser_gap_nodes_top_stp_phase4_parser_gap_postcompile.md`,
  `122/122` probes found.
- Bench ticket:
  `ticket_20260512T064723Z_codex_phase4_parser_gap_stp.txt`.
- Programming and recovery:
  `program_feb.sh` returned `0`, Quartus programmer checksum `0x14D4C4A6`;
  `mudaq_recover_pcie` returned `0`; `/dev/mudaq0` was present.

Phase-1 mini-sanity:

| Probe | Address | Value | Verdict |
|---|---:|---:|---|
| `scratch_pad_ram` | `0x00000` | `0x00000000` | `rsp=OK`, not `0xEEEEEEEE` |
| `sc_hub` UID | `0x0FE80` | `0x53434842` | `rsp=OK`, `"SCHB"` |
| `runctl_mgmt_host_0.CSR_RX_CMD_COUNT` | `0x0C00F` | `0x00000000` | `rsp=OK`, fresh boot |

Pre-arm counter snapshot:

| Metric | Address | Value |
|---|---:|---:|
| `BANK_STATUS` | `0x0A90B` | `0x00000001` |
| `PORT_STATUS` | `0x0A90C` | `0x000000FF` |
| `TOTAL_HITS` | `0x0A90D` | `0x00000000` |

SignalTap action:

- Command opened instance `phase4_parser_gap_lvds`, signal set
  `phase4_parser_gap`, trigger `parser_input_valid_rise`, data log
  `capture_[clock clicks]`, timeout `120 s`.
- SignalTap reported `IDLE -> FILL -> DONE`, exported
  `v3_pretest-260511-rc-readyless-260511/captures/phase4_parser_gap_20260512_084719.vcd`,
  and returned `0` errors / `0` warnings.
- Stop condition: acquisition reached `DONE` before any SC write to
  `LOCAL_CMD` could be issued. The intended `0x10 -> 0x11 -> 0x12`, 4 s
  wait, counter snapshot, and `0x13` sequence was therefore not run. No
  `0x30` or `0x31` reset opcode was sent.

Pre-stimulus VCD summary:

| Signal group | Observation |
|---|---|
| Known failing outputs | `mutrig_datapath_subsystem_0.headerinfo_valid` and `hit_type0_out_valid` never asserted |
| Parser input path | `avalon_st_adapter_009.out_0_valid`, `decoded_lane_fifo_0.out_valid`, `decoded_din_valid`, and `mutrig_frame_deassembly_0.asi_rx8b1k_valid` toggled before run start |
| Run/emulator controls | `run_generating`, `emulator_mutrig_0.aso_tx8b1k_valid`, `run_ctrl_valid`, `receiver_go`, and `enable` stayed low |
| Parser progress | `p_new_word`, `n_new_word`, `aso_headerinfo_valid`, and `aso_hit_type0_valid` stayed low |
| Payload note | observed buses sit mostly at idle/control values `0x1bc` / `0xbc`; this is not legal hit-flow evidence |

Artifacts:

- Log:
  `v3_pretest-260511/reports/phase4_parser_gap_20260512_084719.log`.
- VCD:
  `v3_pretest-260511-rc-readyless-260511/captures/phase4_parser_gap_20260512_084719.vcd`.
- Summary:
  `v3_pretest-260511-rc-readyless-260511/captures/phase4_parser_gap_20260512_084719.summary.md`.
- CSV sidecars:
  `v3_pretest-260511-rc-readyless-260511/captures/phase4_parser_gap_20260512_084719_csv/`.

Verdict: **STOPPED - premature parser-input trigger**. This capture does not
advance the Phase 4 hardware boundary beyond §4.14. It does show that
`parser_input_valid_rise` is not selective enough for the requested board
sequence because the adapter/FIFO/parser-input valid path can toggle while
run-control and emulator source valid are still low. The next investigation
step needs user direction: use a run-qualified parser trigger, a staged arm
after `0x10/0x11`, or another precondition that prevents this idle/control
traffic from consuming the capture.

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

For the current `v3_pretest-260511` closure, the reviewed minimum deliverables
are stricter:

- **Current-build pre-gate proof**: SWB SciFi link 2 locked, SC plane alive,
  run-control reaches FEB emulators, histogram `TOTAL_HITS > 0`,
  `feb_frame_assembly_HSS0/HSS1` actual-hit counters advance,
  `DROPPED_HITS/UNDERFLOW/OVERFLOW == 0`, and any armed SignalTap error
  triggers either do not fire or have a captured explanation.
- **Counter-conservation ledger**: common hit-equivalent stages
  `H1..H6` covering emulator, frame assembly, rbCAM ingress, rbCAM egress,
  histogram, and FEB TX; then byte/job stages `B7 = 4 * CNT_OPQ_INPUT_W`,
  `B8 = CNT_BYTES_WRITTEN`, and `Q9 = CNT_CQE_POSTED` for SWB/RDMA.
  Modes A/B require exact adjacent equality; Mode C uses the documented
  Poisson 5-sigma tolerance, and masked channels must be exactly zero.
- **Rate plot packet**: raw per-channel ingress/egress bins, stage deltas,
  expected counts, tolerances, CSV, PNG/SVG, and script provenance for every
  mode/mask/rate point.
- **Latency plot packet**: five normalized lifetime panels for `pre_rbcam`,
  `post_rbcam`, FEB egress, OPQ ingress, and OPQ egress/offline, with raw bins,
  quantiles, expected sample count, and sim/board comparison.
- **Offline-disk proof**: fresh `dma.bin`, decoded hit records, total decoded
  hits equal to first-stage generated hits, per-channel active/masked count
  comparison, timestamp/inter-arrival distribution check, and frame-boundary
  checks.
- **Provenance**: firmware/SOF/build ID, CP ID, seed, run duration,
  start/stop timestamps, raw counter snapshots, raw dumps, rendered plots, and
  pass/fail JSON.

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
- **SignalTap .stp authoring**: the rc-readyless Phase 4 gap tap is authored
  at
  `v3_pretest-260511-rc-readyless-260511/signaltap/phase4_rc_readyless_gap.stp`
  with Node Finder report `phase4_rc_readyless_gap_nodes.md` (`99/99` found).
  Quartus import, map, and full compile are complete for
  `top_stp_phase4_rc_readyless_gap`; programming, arming, and on-board capture
  are complete in
  `signaltap/captures/phase4_rc_readyless_gap_20260512_042348/`. Broader §4.3
  trigger taps remain to be authored as needed after the next fix candidate.
  The follow-up pre-HSS gap tap is authored at
  `v3_pretest-260511-rc-readyless-260511/signaltap/phase4_pre_hss_gap.stp`.
  Quartus import and full compile are complete for
  `top_stp_phase4_pre_hss_gap`; the dedicated Node Finder report
  `phase4_pre_hss_gap_nodes_top_stp_phase4_pre_hss_gap.md` shows `76/76`
  found. Caveat: map connects only `129/185` SignalTap inputs because
  payload/channel/error aliases are not preserved, so the image is loadable for
  handshake/stage localization but not payload-complete capture. The pre-HSS
  hardware capture is complete in
  `signaltap/captures/phase4_pre_hss_gap_20260512_050729/`; the
  corrected-stimulus/default `SIGNAL=0` capture is complete in
  `signaltap/captures/phase4_pre_hss_signal0_20260512_053323/`. See
  `v3_pretest-260511-rc-readyless-260511/doc/PRE_HSS_STP_CAPTURE.md`.
- **Ping-pong interval tuning**: §4.5.4 assumes `INTERVAL_CFG` yields an
  interval > the time needed for one full host-side read of hist_bin (256
  words). If it doesn't, raise `INTERVAL_CFG` until it does; a too-short
  interval aliases the alternation check.
- **rc-readyless hardware gate**: `v3_pretest-260511-rc-readyless-260511`
  has Qsys, adapter proof, Quartus flow exit 0, SOF/RBF artifacts, the
  SignalTap gap capture, a byte-stream fix smoke, and two follow-up pre-HSS
  STP captures. The byte-stream fix image restores post-selected histogram
  word-counter activity with zero drops/underflow/overflow in that profile. The
  first pre-HSS STP capture showed `aso_tx8b1k_valid=0` because the setup used
  `emu_signal=1` without an external inject source; the exact-stimulus sim
  reproduced that and restored byte-stream output when only `SIGNAL` changed to
  `0`. The corrected/default `SIGNAL=0` hardware capture then restored
  `aso_tx8b1k_valid` through the adapter/mux/FIFO handshake boundary, but
  `headerinfo_valid`, `hit_type0_out_valid`, MTS valids, pre-HSS histogram
  valids, rbCAM payload counters, and HSS frame-assembly counters remain zero.
  This is a debug-load candidate, not production signoff.
- **next active blocker**: under the latest hardware source of truth in
  §4.14, reset-link `start-run` reaches lane-0 emulator run-control,
  `run_generating`, `emulator_mutrig_0.aso_tx8b1k_valid`, the adapter, the
  decoded-lane mux input, and the decoded-lane FIFO handshake boundary. The
  first still-dark legal-hit signals are
  `mutrig_datapath_subsystem_0.headerinfo_valid` and `hit_type0_out_valid`.
  The next pass should use STP to probe emitted byte values, decoded FIFO
  payload/control, frame receiver parser state, and parser CSR/reset mode, and
  should also repair the SC/JTAG setup path so the exact `SIGNAL=0`,
  `MUTRIG_FORMAT=0x20`, `cluster_fix=0x4000` tuple can be replayed on board.

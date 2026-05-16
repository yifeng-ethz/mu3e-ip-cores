# tools/run_script - FEB+SWB on-board debug + bring-up tools

Canonical home for the SWB-host debug + bring-up tools. Previously these
lived under `online_dpv2/online/switching_pc/tools/` and
`online_sc/online/switching_pc/tools/`; both old locations are deprecated.

The tools target the **SWB (Arria 10 DE5)** card programmed from
`firmware_builds/systems/swb/rdma_pretest-260511/` (the canonical SWB
build location going forward), reaching the FEB SciFi at SWB link 2 over
`/dev/mudaq0`.

## Inventory

| File | Purpose |
|---|---|
| `sc_tool.cpp` | Slow-control CLI. Default mode is word-addressed (18-bit) into `sc_hub_v2`; `--swb` mode bypasses the SC ring and reads/writes SWB PCIe BAR registers by firmware-true names. Supersedes the legacy `test_slowcontrol.cpp`. |
| `rc_tool.cpp` | Run-control CLI. Drives the SWB reset-link transmitter to broadcast `IDLE / RUN_PREP / SYNC / RUNNING / TERMINATING` to FEB consumers. |
| `dma_tool.cpp` | DMA test CLI. Configures the rdma_subsystem SQ/CQ rings on SWB and exercises host-side DMA capture. |
| `run_tool` | Python orchestrator that calls `rc_tool` / `dma_tool` / `sc_tool` in the right order for an end-to-end run. Required pattern when more than one of {SC, RC, DMA} is touched in the same run. |
| `test_slowcontrol.cpp` | Legacy SC CLI (16-bit address). Deprecated, kept for archival comparison only. Use `sc_tool` instead. |
| `test_scifi_sc_hub.cpp` | SWB-side sc_hub_v2 unit test (loop a known pattern through the hub). |
| `test_scifi_scratchpad_random.cpp` | FEB scratch_pad_ram random-pattern soak via SC. |
| `sc_scratchpad_sweep.py` | Scratchpad sweep harness (python). |
| `sc_speed_sweep.py` | SC bridge speed sweep (python). |
| `stp_datalog_extract.py` | SignalTap datalog post-processing (python). |
| `decode_mu3e_stp_vcd.py` | Strict Mu3e frame decode for FEB/SWB SignalTap VCD exports; checks header/subheader/hit contracts and can emit `tb_int` replay memory. |
| `gen_swb_pcie_registers.py` | Build-time parser for the SWB firmware `a10_pcie_registers.vhd`; emits the generated C++ register table into the CMake build directory. |
| `feb_scifi_sc_quickref.md` | One-page SC address quickref (FEB SciFi slave map). |
| `feb_scifi_datapath_test_report.md` | Historical bring-up report (Apr 16 2026); kept for context. |
| `CMakeLists.txt` | Native C++ build (sc_tool / rc_tool / dma_tool / test_slowcontrol). |

## Build

The C++ tools build via the SWB host-side CMake toolchain. The minimum
out-of-tree build is:

```
cd <build-dir>
cmake -S /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/tools/run_script -B .
cmake --build . -j
```

The host link depends on the SWB `mudaq` library; that lib is built
inside `online_sc` or `online_dpv2` and exported into
`/home/yifeng/packages/online_sc/online/install/lib/` (or the equivalent
in online_dpv2). Set `CMAKE_PREFIX_PATH` accordingly.

## Run (with the SWB ring lock)

SWB ring access MUST be serialised across SC / RC / DMA calls. Always
launch via the ring-lock orchestrator:

```
~/.local/bin/swb_ring_lock python3 <tools/run_script>/run_tool ...
~/.local/bin/swb_ring_lock <tools/run_script>/build/sc_tool ...
~/.local/bin/swb_ring_lock <tools/run_script>/build/rc_tool ...
```

This is documented in the auto-memory under
`memory/feedback_swb_ring_lock.md`.

`run_tool` also self-reexecs under `~/.local/bin/swb_ring_lock` when it
is launched directly. Wrapping it explicitly is still the preferred board
smoke pattern because the full SC/RC/DMA run then holds one serialized
hardware-access lease.

## SignalTap Packet Contract Decode

Use `decode_mu3e_stp_vcd.py` after exporting a SignalTap capture to VCD.
Final packet-contract captures must include data and datak at the tapped
boundary; SOP/EOP-only captures are valid for visual lifetime review but are
not sufficient for Mu3e header/subheader/hit signoff.

```
tools/run_script/decode_mu3e_stp_vcd.py --profile feb <capture.vcd> \
  --json-out feb_contract.json --words-csv-out feb_words.csv \
  --fail-on-contract-error

tools/run_script/decode_mu3e_stp_vcd.py --profile swb --active-lane-mask 0x3 <capture.vcd> \
  --json-out swb_contract.json --words-csv-out swb_words.csv \
  --replay-stream opq_ingress_lane0 --replay-mem-out opq_ingress_lane0.mem \
  --fail-on-contract-error --fail-on-boundary-drop
```

## run_tool debug flags

`run_tool` defaults to the local build output in
`tools/run_script/build/` for `sc_tool`, `rc_tool`, and `dma_tool`.
It then checks `tools/run_script/install/bin/` and finally `PATH`.
Use these flags when the binaries live somewhere else:

```
--tool-bin-dir <dir>       Override the primary tool directory.
--tool-install-dir <dir>   Override the secondary tool directory.
--refresh-tool-paths       Force fresh local/PATH discovery.
```

Board-smoke and inspection flags:

```
--empty-frame          Configure FEB emulator sources for empty/header frames:
                       no MuTRiG XML/JTAG configure and zero emulator hits.
--skip-mutrig-config   Skip real-MuTRiG XML/JTAG configuration while still
                       allowing emulator traffic.
--no-data-ingress      Force SWB_LINK_MASK_SCIFI=0 so FEB payload is rejected
                       at the SWB ingress, and route the SWB generated generic
                       lane through OPQ/RDMA for host-path smoke traffic.
--dump-csrs            Write run_tool_csr_dump_<timestamp>.md with the full
                       `sc_tool --swb dump-all` BAR0 table and 9 FEB SC CSR
                       ranges.
--no-program           Skip SOF programming; assumes SWB/FEB images are loaded.
```

Example empty-frame smoke after programming both boards:

```
~/.local/bin/swb_ring_lock python3 \
  /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/tools/run_script/run_tool \
  --empty-frame --no-data-ingress --dump-csrs \
  --duration-s 5 \
  --no-program
```

## sc_tool address rules

### SWB BAR mode

Use `--swb` for SWB-local PCIe BAR registers. This path opens
`/dev/mudaq0` directly and does not touch the FEB slow-control ring. Register
names are generated at build time from:

```
firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10/registers/a10_pcie_registers.vhd
```

Every `--swb` command prints the truth-source path and sha256 before the
readback. Long firmware names and short aliases are both accepted:

```
./sc_tool --swb read VERSION_REGISTER_R
./sc_tool --swb read LINK_LOCKED_LOW
./sc_tool --swb read RESET_LINK_STATUS
./sc_tool --swb read LINK_LOCKED_LOW --samples 1000 --bit-stats
./sc_tool --swb stat RESET_LINK_STATUS --samples 1000
./sc_tool --swb write DMA_REGISTER 0x00000001
./sc_tool --swb burst RESET_LINK_STATUS_REGISTER_R 3
./sc_tool --swb dump-all
./sc_tool --swb dump-stats --samples 1000
./sc_tool --swb-list-regs
```

`--swb` register offsets are BAR word indices, matching the firmware package
constants. For example, `LINK_LOCKED_LOW_REGISTER_R` is offset `0x36`, which
maps to BAR0 byte address `0xD8`.

### SWB BAR CDC-drift hazard

The SWB status registers are not CDC-clean in the current firmware. Status bits
such as `LINK_LOCKED_LOW_REGISTER_R`, `LINK_LOCKED_HIGH_REGISTER_R`, and
`RESET_LINK_STATUS_REGISTER_R` cross from the xcvr clock domain into the PCIe
`coreclkout` domain without a synchronizer chain. Single-shot host reads of
these registers are NOT TRUSTWORTHY for status interpretation because they can
return metastable or bit-torn values.

For status decisions, always use repeated bit-stability sampling:

```
~/.local/bin/swb_ring_lock ./sc_tool --swb read <reg> --samples 1000 --bit-stats
```

`sc_tool --swb stat <reg> --samples 1000` is an alias for the same sampled
status read. Use the per-bit majority vote and the stable/unstable bit lists;
do not make link/reset decisions from a single `sc_tool --swb read` or `rw rr`
of these status offsets.

Count-style registers (`CNT_*`) accumulate in their source domain and can be
read single-shot only when no events are in flight. For sanity, read counters
with `--samples 2` and compare both values before treating the snapshot as
static.

### FEB SC-ring mode

The SWB `sc_hub` is **word-addressed** (NOT byte-addressed). To read a
Qsys byte address `0xN`, pass `0xN / 4` to `sc_tool`. See
`feb_scifi_sc_quickref.md` for the FEB SciFi slave map.

## Hardware reach map

| Board | Programmed from | Reachable from these tools |
|---|---|---|
| SWB Arria 10 DE5 (`1172:0004`) | `firmware_builds/systems/swb/rdma_pretest-260511/` | sc_tool / rc_tool / dma_tool all target the SWB directly via `/dev/mudaq0`. |
| FEB SciFi (USB-BlasterII [7-2]) | `firmware_builds/systems/v3_pretest-260511/` | sc_tool reaches FEB CSR slaves through the SWB sc_hub (link 2). rc_tool reaches FEB consumers through the SWB reset-link transmitter (firefly downlink). |

## Cross-references

- `firmware_builds/systems/v3_pretest-260511/doc/TEST_PLAN.md` - the
  on-board test plan that USES these tools (Phase 1..4).
- `firmware_builds/systems/swb/rdma_pretest-260511/` - the SWB build.
- `firmware_builds/systems/v3_pretest-260511/` - the FEB SciFi build.
- `~/.local/bin/swb_ring_lock` - ring-lock orchestrator (auto-memory
  `feedback_swb_ring_lock.md`).
- `~/.local/sbin/mudaq_recover_pcie` - PCIe recovery helper (auto-memory
  `feedback_swb_pll_diag.md`).

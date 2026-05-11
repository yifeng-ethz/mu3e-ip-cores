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
| `sc_tool.cpp` | Slow-control CLI. Word-addressed (18-bit) into `sc_hub_v2`. Reads/writes any CSR slave reachable via the SWB sc_hub. Supersedes the legacy `test_slowcontrol.cpp`. |
| `rc_tool.cpp` | Run-control CLI. Drives the SWB reset-link transmitter to broadcast `IDLE / RUN_PREP / SYNC / RUNNING / TERMINATING` to FEB consumers. |
| `dma_tool.cpp` | DMA test CLI. Configures the rdma_subsystem SQ/CQ rings on SWB and exercises host-side DMA capture. |
| `run_tool` | Python orchestrator that calls `rc_tool` / `dma_tool` / `sc_tool` in the right order for an end-to-end run. Required pattern when more than one of {SC, RC, DMA} is touched in the same run. |
| `test_slowcontrol.cpp` | Legacy SC CLI (16-bit address). Deprecated, kept for archival comparison only. Use `sc_tool` instead. |
| `test_scifi_sc_hub.cpp` | SWB-side sc_hub_v2 unit test (loop a known pattern through the hub). |
| `test_scifi_scratchpad_random.cpp` | FEB scratch_pad_ram random-pattern soak via SC. |
| `sc_scratchpad_sweep.py` | Scratchpad sweep harness (python). |
| `sc_speed_sweep.py` | SC bridge speed sweep (python). |
| `stp_datalog_extract.py` | SignalTap datalog post-processing (python). |
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
--dump-csrs            Write run_tool_csr_dump_<timestamp>.md with 9 SWB BAR0
                       registers and 9 FEB SC CSR ranges.
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

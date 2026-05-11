Switching Board Firmware
======================


Installation
----------------------
1. Build from the project root (`a10_board/`), not from `quartus-build/SEED_1`.
2. Run app generation before full flow so Nios meminit is baked into the compile.
3. This prep image is SC-focused: the current generic detector-data path is disabled entirely so the board image only keeps the FEB slow-control, Nios flash access, and Link02 debug needed for MAX10 flash-programming bring-up.

```bash
cd switching_pc/a10_board
make clean
make
make app
make flow
```

Quick checks:

- the generated `top.qsf` points at `scripts/settings.tcl`, which sources the shared baseline and tightens the compile to `AGGRESSIVE PERFORMANCE` with `PLACEMENT_EFFORT_MULTIPLIER 4.0`.
- `top.qsf` contains `ENABLE_SIGNALTAP ON` and `USE_SIGNALTAP_FILE "top_sc_link2_packets_example1_format.stp"`.
- outputs exist in `output_files/` (`top.sof`, `top.sld`, `top.sta.summary`).
- JTAG UART is reachable (`timeout 10s make terminal`).
- Engineering note and validation evidence live under `doc/sc_path_fix/`.

SignalTap
----------------------
- The default build enables SignalTap using `top_sc_link2_packets_example1_format.stp`.
- This tap captures slow-control TX words from SWB to FEB (`swb_sc_main|o_mem_data[2]`) and RX/reply-side words in SWB (`swb_sc_secondary` path, including Link02 FIFO output).
- Open the resulting SOF in SignalTap and arm `tap_swb_sc_link2` to inspect SC packet flow.
- Repo-local bring-up wrapper:

```bash
./scripts/run_sc_hw_bringup.sh --phase all
```

- The wrapper does not program hardware. It assumes SWB and FEB are already programmed, validates the active `.stp`, auto-detects the current STP instance/signal-set/trigger names, runs one direct smoke write/read, then runs one strict SignalTap-backed SC transaction on Link02.

SC Scratchpad Smoke / Stress
----------------------
- Build the host-side helper once if needed:

```bash
cmake --build ../../build-codex --target test_slowcontrol
```

- Single smoke read/write on FEB link 2:

```bash
../../build-codex/switching_pc/tools/test_slowcontrol 2 --write 0x0 0xA5A55A5A --once
../../build-codex/switching_pc/tools/test_slowcontrol 2 --read 0x0 1 --once
```

- Random scratchpad sweep through the FEB `sc_hub` scratchpad RAM:

```bash
python3 ../tools/sc_scratchpad_sweep.py \
  --mode random \
  --full-scope-profile mixed-random \
  --link 2 \
  --random-ops 1000
```

- Pair one selected transaction with strict TX/RX SignalTap verification:

```bash
python3 ../tools/sc_scratchpad_sweep.py \
  --mode scan \
  --iterations 1 \
  --link 2 \
  --use-signaltap \
  --stp-strict
```

- `test_slowcontrol` forces a readback of the staged SWB write-memory packet before toggling `SC_MAIN_ENABLE_REGISTER_W`; keep that behavior when debugging suspected posted-write / CPU-ordering issues.

SC Speed Sweep
----------------------
- Packet-size read/write software sweep on the scratchpad path:

```bash
python3 ../tools/sc_speed_sweep.py \
  --link 2 \
  --iterations 10 \
  --out-csv ../a10_board/output_files/sc_speed_sweep_link2.csv
```

- Add a guard, or switch the helper to tight busy-polling instead of the default `100 us` / `1000 us` poll sleeps:

```bash
python3 ../tools/sc_speed_sweep.py \
  --link 2 \
  --words 1,4,8,16,32,64,96,128 \
  --iterations 10 \
  --guard-us 0 \
  --busy-poll \
  --out-csv ../a10_board/output_files/sc_speed_sweep_link2_busy.csv
```

- Reproduce the older drain-all timing path:

```bash
python3 ../tools/sc_speed_sweep.py \
  --link 2 \
  --words 1,4,8,16,32,64,96,128 \
  --iterations 20 \
  --legacy-drain-all \
  --guard-us 1000 \
  --out-csv ../a10_board/output_files/sc_speed_sweep_link2_legacy_guard1ms.csv
```

- Measure raw BAR MMIO access cost separately from the SC protocol:

```bash
cmake --build ../../build-codex --target mmio_rtt
../../build-codex/farm_pc/tools/mmio_rtt --blocks 4000 --inner 1000
```

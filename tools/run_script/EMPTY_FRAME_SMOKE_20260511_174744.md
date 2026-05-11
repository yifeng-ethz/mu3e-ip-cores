# EMPTY_FRAME_SMOKE_20260511_174744

## Result

- Status: FAIL for the requested DMA-frame acceptance criterion. The run completed without tool errors, but the host DMA reader captured 0 words / 0 bytes.
- Hardware: SWB Arria 10 DE5 `rdma_pretest-260511` plus Apr 27 FEB SciFi `system_20260427_testplanphase5`.
- Programming: SWB Quartus Programmer exit 0, checksum `0x31A9E107`; FEB Quartus Programmer exit 0, checksum `0x13449048`; PCIe recovery exit 0.
- Command: `~/.local/bin/swb_ring_lock python3 tools/run_script/run_tool --empty-frame --no-data-ingress --dump-csrs --duration-s 5 --no-program --output-dir tools/run_script/empty_frame_smoke_20260511_174744`
- Tools: local `tools/run_script/build/{sc_tool,rc_tool,dma_tool}`.
- PCIe: `/dev/mudaq0` accessible after `sudo -n /usr/local/sbin/mudaq_recover_pcie`; SWB `VERSION_REGISTER_R=0xE774D90D`.
- Link status: `LINK_LOCKED_LOW_REGISTER_R=0x13000000`, `LINK_LOCKED_HIGH_REGISTER_R=0x00000F00`. Link 2 slow-control access was live (`SC_HUB_UID=0x53434842`), but the high register shows only the 8..11 loopback-style pattern.
- No-data ingress state at start: `SWB_LINK_MASK_SCIFI=0x00000000`, `SWB_GENERIC_MASK=0x00000001`, `SWB_READOUT_STATE=0x00040005` (generic + generated link + OPQ).
- FEB empty-frame setup: MuTRiG XML/JTAG configure skipped; legacy emulator lanes enabled with zero rates and short-idle tx modes `0x0C..0x7C`.
- Histogram counters: `hist_0_total_hits=0`, `hist_0_dropped_hits=0`.
- RDMA/OPQ observability: `CNT_OPQ_INPUT_W=0`, `CNT_BYTES_WRITTEN=0`, `CNT_RQE_CONSUMED=0`, `CNT_CQE_POSTED=0`, `CNT_EOE_OBSERVED=0`.
- DMA capture: `capture.bin` is 0 bytes; `dma_tool` summary reports `read_words=0`, `written_words=0`, `bytes_written=0`.
- CSR dump: `tools/run_script/empty_frame_smoke_20260511_174744/run_tool_csr_dump_20260511_174759.md`.
- Notes: no 64k+ secondary-ring SC preamble noise was observed in this run. The failing boundary is before host DMA production; the generated-data counter is alive, but the rdma-pretest OPQ/RDMA counters did not advance.

## Raw Transcript

Script started on 2026-05-11 17:47:50+02:00 [<not executed on terminal>]
run_tool: FEB SC ring up
run_tool: MuTRiG XML/JTAG configure step skipped
run_tool: --no-data-ingress active; forcing SWB_LINK_MASK_SCIFI=0x00000000 and enabling the SWB generated generic lane through OPQ/RDMA
0x1740000e
0x0
0x1
0x10
0x40005
0x40005
0x80000
0x0
0x8
0x2
0x8
0x1
0x1
run_tool: SWB state {'RESET_REGISTER_W': 0, 'DATAGENERATOR_DIVIDER_REGISTER_W': 16, 'SWB_GENERIC_MASK_REGISTER_W': 1, 'SWB_LINK_MASK_SCIFI': 0, 'SWB_READOUT_STATE': 262149, 'FARM_READOUT_STATE': 262149, 'RDMA': {'STATUS': 0, 'CNT_OPQ_INPUT_W': 0, 'CNT_BYTES_WRITTEN': 0, 'CNT_RQE_CONSUMED': 0, 'CNT_CQE_POSTED': 0, 'CNT_HALT': 0, 'CNT_EOE_OBSERVED': 0}, 'GET_N_DMA_WORDS_REGISTER_W': 524288, 'DMA_REGISTER': 0}
run_tool: configuring empty-frame FEB source mode (no MuTRiG config, no emulator hits)
run_tool: launching dma_tool -> /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/tools/run_script/empty_frame_smoke_20260511_174744/capture.bin
run_tool: rc_tool sequence run=129577
info: cmd=0x30 (reset) feb=7 -> RESET_LINK_CTL_REGISTER_W=0xE0000030
info: before: CTL=0x00000000 STATUS=0x13000000
info: after : CTL=0x00000000 STATUS=0x30000000
info: ok: o_state_out echoes 0x30
info: cmd=0x31 (stop-reset) feb=7 -> RESET_LINK_CTL_REGISTER_W=0xE0000031
info: before: CTL=0x00000000 STATUS=0x30000000
info: after : CTL=0x00000000 STATUS=0x31000000
info: ok: o_state_out echoes 0x31
info: cmd=0x10 (run-prepare) feb=7 -> RESET_LINK_CTL_REGISTER_W=0xE0000010
info: before: CTL=0x00000000 STATUS=0x31000000
info: writing RESET_LINK_RUN_NUMBER_REGISTER_W = 0x0001FA29
info: after : CTL=0x00000000 STATUS=0x0001FA29
info: ok: run-prepare FSM advanced (state encodes run number)
info: cmd=0x11 (sync) feb=7 -> RESET_LINK_CTL_REGISTER_W=0xE0000011
info: before: CTL=0x00000000 STATUS=0x0001FA29
info: after : CTL=0x00000000 STATUS=0x11000003
info: ok: o_state_out echoes 0x11
info: cmd=0x12 (start-run) feb=7 -> RESET_LINK_CTL_REGISTER_W=0xE0000012
info: before: CTL=0x00000000 STATUS=0x11000003
info: after : CTL=0x00000000 STATUS=0x12000004
info: ok: o_state_out echoes 0x12
run_tool: running for 5 s
info: cmd=0x13 (end-run) feb=7 -> RESET_LINK_CTL_REGISTER_W=0xE0000013
info: before: CTL=0x00000000 STATUS=0x12000004
info: after : CTL=0x00000000 STATUS=0x13000000
info: ok: o_state_out echoes 0x13
run_tool: CSR dump at /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/tools/run_script/empty_frame_smoke_20260511_174744/run_tool_csr_dump_20260511_174759.md
run_tool: summary at /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/tools/run_script/empty_frame_smoke_20260511_174744/debug_daq_summary.json
  capture file:    /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/tools/run_script/empty_frame_smoke_20260511_174744/capture.bin (0 bytes)
  dma counters:    {'read_words': 0, 'written_words': 0, 'bytes_written': 0, 'dma_cnt_words_register': 0, 'output': '/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/tools/run_script/empty_frame_smoke_20260511_174744/capture.bin'}
  hist_0 total:    0
  hist_0 drops:    0

Script done on 2026-05-11 17:48:00+02:00 [COMMAND_EXIT_CODE="0"]

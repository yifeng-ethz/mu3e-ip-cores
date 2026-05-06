# Virtual MuTRiG integration notes for tb_int

Scope: planning notes only. No RTL, IP packaging, Qsys, or UVM source files are changed by this document.

Golden source inspected:

- Repo: `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb`
- Tag: `mutrig-smoke-stable-20260506`
- Tag commit: `ae55cee1c04aaa0b695b23f10edbac6bc78513c5`

The tag pins the smoke harness, `digital_all.vhdl`, and several hdlcore dependencies. The checkout also contains unit sources referenced by `tb/smoke/run_smoke.do` that are not all tracked by the tag. A CI implementation should either consume a complete vendor archive/submodule at this commit or record file hashes for the local checkout dependencies.

## Recommendation

Add the tagged virtual MuTRiG as a second tb_int source mode beside the existing direct emulator path. For the first integration, use the decoded 9-bit raw MuTRiG frame source from the existing A/B bridge:

`emulator_mutrig/tb/mutrig_true_ab/raw_mutrig_frame_top.vhd`

This wrapper accepts golden MuTRiG 48-bit L2 words and emits decoded MuTRiG frame bytes as `{isk, byte}` on a 9-bit stream. It is the minimal useful boundary for tb_int because it feeds the real `mutrig_frame_deassembly_0.rx8b1k` input while avoiding Altera LVDS bit-serial/DPA lock behavior in a system integration test.

Keep both source paths:

- Existing emulator path: `emulator_mutrig_qsys_lane` with `BYTE_STREAM_ENABLE=0`, direct `aso_hit_type0` into `arb_hit_type0_0`.
- New virtual raw path: `raw_mutrig_frame_top` emits decoded frame bytes into `mutrig_frame_deassembly_0.rx8b1k`; `mutrig_frame_deassembly_0.aso_hit_type0` then feeds `arb_hit_type0_0`.

Use a later plusarg or test parameter such as `+TB_INT_SOURCE=emu_direct|virtual_mutrig_raw|mixed`. The virtual raw mode should configure `arb_hit_type0_0` to accept the real/deassembly path. The existing emulator smoke path should keep the current emulator selection. Add `mixed` only after both source streams have independent monitors and deterministic source IDs.

## Source files to reuse

Minimal decoded-9b source path:

1. Golden/local MuTRiG datapath packages:
   - `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/datapath_defs/source/rtl/vhdl/datapath_helpers.vhd`
   - `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/datapath_defs/source/rtl/vhdl/datapath_types.vhd`
   - `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/datapath_defs/source/rtl/vhdl/serial_comm_defs.vhd`
   - `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/datapath_defs/source/rtl/vhdl/txt_util.vhd`
2. FIFO dependency:
   - Prefer tagged golden file: `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/hdlcore_lib/generic_memory/generic_dp_fifo/source/rtl/vhdl/generic_dp_fifo.vhd`
   - Existing A/B bridge fallback: `emulator_mutrig/tlm/raw_support/hdlcore_lib/generic_memory/generic_dp_fifo/source/rtl/vhdl/generic_dp_fifo.vhd`
3. Golden MuTRiG frame generator:
   - `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/frame_generator/source/rtl/vhdl/crc16_8.vhd`
   - `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/frame_generator/source/rtl/vhdl/frame_generator.vhd`
4. Local bridge wrapper:
   - `emulator_mutrig/tb/mutrig_true_ab/raw_mutrig_frame_top.vhd`

Use these A/B bridge files as references for handshake, payload mapping, and evidence, not as mandatory tb_int dependencies:

- `emulator_mutrig/tb/mutrig_true_ab/Makefile`
- `emulator_mutrig/tb/mutrig_true_ab/tb_mutrig_true_ab.sv`
- `emulator_mutrig/tb/mutrig_true_ab/emut_frame_top_direct.sv`
- `emulator_mutrig/tb/mutrig_true_ab/dpi/emut_ab_dpi.c`
- `emulator_mutrig/tb/mutrig_true_ab/results/TRUE_AB_REPORT.md`

Optional full digital virtual MuTRiG path:

- `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/digital_all/source/rtl/vhdl/digital_all.vhdl`
- `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/tb/smoke/src/mutrig_smoke_analysis_pkg.vhd`
- `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/tb/smoke/src/mutrig_tdc_pulse_injector_model.vhd`
- `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/tb/smoke/src/mutrig_tdc_injection_model.vhd`
- `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/tb/smoke/src/mutrig_smoke_scoreboard.vhd`
- `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/tb/smoke/src/mutrig_digital_smoke_tb.vhd` as a reference only; do not copy it wholesale into tb_int.

## Compile order

Decoded-9b virtual MuTRiG source:

1. `vlib work` and map the same work library used by the DUT simulation.
2. `vcom -2008 /home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/datapath_defs/source/rtl/vhdl/datapath_helpers.vhd`
3. `vcom -2008 /home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/datapath_defs/source/rtl/vhdl/datapath_types.vhd`
4. `vcom -2008 /home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/datapath_defs/source/rtl/vhdl/serial_comm_defs.vhd`
5. `vcom -2008 /home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/datapath_defs/source/rtl/vhdl/txt_util.vhd`
6. `vcom -2008 /home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/hdlcore_lib/generic_memory/generic_dp_fifo/source/rtl/vhdl/generic_dp_fifo.vhd`
7. `vcom -2008 /home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/frame_generator/source/rtl/vhdl/crc16_8.vhd`
8. `vcom -2008 /home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/frame_generator/source/rtl/vhdl/frame_generator.vhd`
9. `vcom -2008 emulator_mutrig/tb/mutrig_true_ab/raw_mutrig_frame_top.vhd`
10. Compile generated `focus_emulator_type0_system` DUT sources using the existing tb_int DUT compile hook.
11. Compile UVM and tb_int SV sources with `firmware_builds/systems/system_20260504_emulator_type0/tb_int/script/tb_int.f`.
12. Compile the later tb_int virtual-source wrapper/top after the DUT and before `vsim`.

Do not add the standalone SV emulator A/B model to the tb_int source list unless the test intentionally performs an A/B comparison inside tb_int. The system DUT already contains the emulator source path.

Full `digital_all` path compile order should follow `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/tb/smoke/run_smoke.do`:

1. Datapath packages: `datapath_helpers.vhd`, `datapath_types.vhd`, `serial_comm_defs.vhd`
2. Generated `mutrig_smoke_config_pkg.vhd`
3. Hdlcore arbitration/FIFO files: `arb_selection_alter.vhd`, `arb_selection.vhd`, `generic_mux.vhd`, `fifo_wtrig_entity.vhd`, `fifo_wtrig_arch_generic_ram.vhd`, `generic_dp_fifo.vhd`
4. LVDS macro emulation: `LVDS_RX_top.vhd`, `LVDS_TX_top.vhd`
5. Utility RTL: `clock_divider_sreg_counter_longedge.vhd`, `reset_generator.vhdl`, `synchronizer.vhd`, `pll_lol_detector.vhd`
6. Datapath RTL: `ch_event_counter.vhd`, `therm_decode.vhd`, `ch_hit_receiver.vhdl`, `L1_arbitration.vhd`, `group_buffer.vhd`
7. Selection RTL: `MS_select.vhd`, `group_select.vhd`, `GroupMasterSelect.vhd`
8. Frame TX: `crc16_8.vhd`, `frame_generator.vhd`, `8b10_enc.vhd`, `encoder_module.vhd`, `dual_edge_flipflop.vhd`, `dual_edge_serializer.vhd`, `init_transmission.vhd`, `prbs_gen48.vhd`, `block_frame_gen_ser.vhd`
9. SPI/coincidence/top: `spi_slave.vhdl`, `coincidence_crossbar.vhd`, `coincidence_matrix.vhd`, `digital_all.vhdl`
10. RX monitor/reference: `bclock_gen.vhd`, `dec_8b10b.vhd`, `deserializer.vhd`, `crc16_calc.vhd`, `frame_rcv.vhd`, `block_deser_frame_rcv.vhd`
11. Smoke analysis harness: `mutrig_smoke_analysis_pkg.vhd`, `mutrig_tdc_pulse_injector_model.vhd`, `mutrig_tdc_injection_model.vhd`, `mutrig_smoke_scoreboard.vhd`, `mutrig_digital_smoke_tb.vhd`

Use the full path only when tb_int needs to exercise bit-serial LVDS, SPI configuration, TDC pulse generation, or `digital_all` debug metadata.

## Ports and mapping

`raw_mutrig_frame_top` entity:

- Inputs: `i_clk`, `i_rst`, `i_start_trans`, `i_short_mode`, `i_gen_idle`, `i_offer_valid`, `i_offer_word(47 downto 0)`
- Outputs: `o_offer_ready`, `o_accept_pulse`, `o_fifo_rd_en`, `o_event_count(9 downto 0)`, `o_fifo_empty`, `o_fifo_full`, `o_fifo_almost_full`, `o_tx_data(8 downto 0)`, `o_tx_valid`

The input `i_offer_word(47 downto 0)` uses the MuTRiG L2 raw layout exercised by `tb_mutrig_true_ab.sv`:

- `[47:43]`: channel
- `[41:27]`: T coarse
- `[26:22]`: T fine
- `[20:6]`: E coarse
- `[5:1]`: E fine
- `[0]`: energy flag

Convert raw L2 to tb_int hit_type0 with the same mapping already present in `prof_int_002_full_pipeline_top.sv`:

```systemverilog
function automatic logic [44:0] raw48_to_hit0(logic [47:0] raw_word, logic [3:0] asic);
  raw48_to_hit0 = {
    asic,
    raw_word[47:43],
    raw_word[41:27],
    raw_word[26:22],
    raw_word[19:5],
    raw_word[20]
  };
endfunction
```

The generated focus system connects LVDS decode to frame deassembly through:

- `lvds_rx_controller_pro_0_decoded_data[8:0]`
- `lvds_rx_controller_pro_0_decoded_error[2:0]`
- `avalon_st_adapter_out_0_data[8:0]`
- `avalon_st_adapter_out_0_valid`
- `avalon_st_adapter_out_0_channel[3:0]`
- `avalon_st_adapter_out_0_error[2:0]`
- `mutrig_frame_deassembly_0.asi_rx8b1k_*`

For virtual raw mode, drive the deassembly-side adapter output in simulation:

- `avalon_st_adapter_out_0_data <= o_tx_data`
- `avalon_st_adapter_out_0_valid <= o_tx_valid`
- `avalon_st_adapter_out_0_channel <= lane_id[3:0]`
- `avalon_st_adapter_out_0_error <= 3'b000`

Implement this later as a testbench-only hierarchical force, bind helper, or simulation wrapper. Do not change the Qsys system or IP RTL for this source mode.

## tb_int analysis fields

Current tb_int scoreboard records hits as `hit_record` objects. The virtual MuTRiG source monitor should publish source-stage hits using the same payload convention as the current emulator taps:

- `payload[44:41]`: ASIC/lane id
- `payload[40:36]`: channel
- `payload[35:21]`: T coarse
- `payload[20:16]`: T fine
- `payload[15:1]`: E coarse
- `payload[0]`: energy flag
- `key`: `{channel[4:0], t_fine[4:0]}` through `hit_key_pkg.sv`
- `lane_id`: virtual MuTRiG lane/ASIC index
- `t_coarse`: `payload[35:21]`
- `observation_point`: `stage_a` for accepted source words, then existing pre-rbCAM/post-rbCAM/FEB monitor names downstream
- `root_hit_id`: set by the first source-stage monitor and propagated by the existing per-bucket ledger scoreboard

Publish the source-stage record on `o_accept_pulse`, not on `o_tx_valid`. `o_accept_pulse` marks that a raw L2 word entered the virtual MuTRiG frame source. `o_tx_valid` marks byte-stream serialization and may span many cycles per accepted hit.

For the downstream real path, `mutrig_frame_deassembly_0.aso_hit_type0_*` produces the 45-bit hit_type0 payload expected by the existing adapters and monitors. Existing pre-rbCAM and post-rbCAM monitors should remain the sink-side truth for ordering and loss checks.

If the later full `digital_all` path is used, useful debug/analysis fields are:

- `mutrig_smoke_driver_hit_t.global_hit_id`
- `mutrig_smoke_driver_hit_t.channel`
- `mutrig_smoke_driver_hit_t.time_ccm`
- `mutrig_smoke_driver_hit_t.time_fine`
- `mutrig_smoke_driver_hit_t.energy_ccm`
- `mutrig_smoke_driver_hit_t.energy_fine`
- `mutrig_smoke_driver_hit_t.energy_flag`
- `digital_all.o_debug_l2_valid`
- `digital_all.o_debug_l2_data[47:0]`
- `digital_all.o_debug_meta_valid`
- `digital_all.o_debug_meta_channel[4:0]`
- `digital_all.o_debug_meta_global_hit_id[31:0]`
- `digital_all.o_debug_meta_timestamp_ps[63:0]`
- `digital_all.o_debug_frame_mark`
- `digital_all.o_debug_l1_fifo_fill`
- `digital_all.o_debug_l2_fifo_fill`

Those fields are useful for CSV/debug, but tb_int should continue to key scoreboard identity on the canonical hit_type0 payload fields unless the scoreboard is deliberately extended.

## Minimal copy/reference policy

Do not copy the MuTRiG unit source tree into tb_int for the first integration.

Reference these paths from a tb_int virtual-source make fragment or filelist:

- `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb` as `MUTRIG_GOLDEN_ROOT`
- `mutrig-smoke-stable-20260506` / `ae55cee1c04aaa0b695b23f10edbac6bc78513c5` as the expected provenance
- `emulator_mutrig/tb/mutrig_true_ab/raw_mutrig_frame_top.vhd` as the local bridge wrapper

Only copy a file if it must be adapted for tb_int. The expected minimum later copy, if any, is a tb_int-local simulation wrapper or bind helper under `tb_int/`. The raw MuTRiG RTL, `digital_all`, and smoke harness files should remain external references until the repository has a chosen vendor policy.

## Later implementation steps

1. Add a tb_int make target, for example `comp_virtual_mutrig_raw`, that compiles the decoded-9b source files before the existing tb_int SV filelist.
2. Add a tb_int source-mode plusarg and UVM config field: `emu_direct`, `virtual_mutrig_raw`, and later `mixed`.
3. Instantiate or bind a testbench-only `raw_mutrig_frame_top` source in virtual raw mode.
4. Use the existing deterministic hit scheduler to produce `i_offer_word[47:0]` streams.
5. On `o_accept_pulse`, publish a source-stage hit record after `raw48_to_hit0`.
6. Hierarchically drive the generated deassembly input adapter wires listed above, or use an equivalent test-only wrapper around `focus_emulator_type0_system`.
7. Configure `arb_hit_type0_0` source selection for the real/deassembly path in virtual raw mode and keep the existing emulator selection for `emu_direct`.
8. Reuse existing pre-rbCAM, post-rbCAM, FEB egress, histogram, and per-bucket ledger monitors.
9. Add one smoke test that compares accepted source hits to downstream post-rbCAM/FEB observations at low occupancy before enabling mixed-source arbitration stress.

## Open risks

- The decoded-9b path does not exercise Altera LVDS RX, 8b10b alignment, DPA lock, or serial timing. That is intentional for the first tb_int source-model integration.
- The full `digital_all` path is the correct choice only when the objective includes TDC pulse timing, SPI configuration, or bit-serial LVDS behavior.
- The golden tag does not by itself list every unit dependency referenced by `run_smoke.do`; a reproducible CI implementation needs a stronger vendoring decision.
- The current `tb_int/script/tb_int.f` is still a small UVM harness filelist. It does not yet compile the generated DUT or virtual MuTRiG source. Add make/filelist structure later without changing RTL/IP.

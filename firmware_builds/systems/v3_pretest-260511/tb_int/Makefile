QUESTA_HOME      ?= /data1/questaone_sim-2026.1_1/questasim
ETH_LIC_SERVER   := 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE      := $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE    := $(LM_LICENSE_FILE)
export SALT_LICENSE_SERVER  := $(LM_LICENSE_FILE)
export QSIM_INI             := modelsim.ini

VLOG := $(QUESTA_HOME)/linux_x86_64/vlog
VCOM := $(QUESTA_HOME)/linux_x86_64/vcom
VSIM := $(QUESTA_HOME)/linux_x86_64/vsim
VLIB := $(QUESTA_HOME)/linux_x86_64/vlib
VMAP := $(QUESTA_HOME)/linux_x86_64/vmap

WORK              ?= work_tb_int
TB_TOP             := tb_int_top
SEED              ?= 1
SIM_ROOT          ?= sim
TB_INT_ROOT        := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SYSTEM_ROOT        := $(abspath ..)
REPO_ROOT          := $(abspath ../../../..)
QSYS_DUT_VARIANT   ?= synthesis_debug
ifeq ($(QSYS_DUT_VARIANT),debug)
QSYS_DUT_VARIANT   := synthesis_debug
endif
ifeq ($(QSYS_DUT_VARIANT),sim)
QSYS_DUT_VARIANT   := synthesis_debug
endif
ifeq ($(QSYS_DUT_VARIANT),normal)
QSYS_DUT_VARIANT   := synthesis
endif
ifeq ($(QSYS_DUT_VARIANT),compile)
QSYS_DUT_VARIANT   := synthesis
endif
QSYS_SYNTH_DIR     := $(SYSTEM_ROOT)/syn/feb_system_v3/$(QSYS_DUT_VARIANT)
QSYS_QIP           := $(QSYS_SYNTH_DIR)/feb_system_v3.qip
QSYS_SPLITTER_SV   := $(QSYS_SYNTH_DIR)/submodules/altera_avalon_st_splitter.sv
QSYS_FILELIST_DIR  := $(SIM_ROOT)/filelists
QSYS_DUT_MANIFEST_CHECK := $(SYSTEM_ROOT)/script/feb_generated_dut_manifest.py
BOARD_UTIL_SLV_PKG := $(firstword $(wildcard $(SYSTEM_ROOT)/syn/board_projects/*/src/common/util/util_slv.vhd))
BOARD_MUDAQ_PKG    := $(firstword $(wildcard $(SYSTEM_ROOT)/syn/board_projects/*/src/common/registers/mudaq.vhd))
EMU_RTL_DIR        := $(REPO_ROOT)/emulator_mutrig/rtl
RUNCTL_MGMT_RTL_DIR := $(REPO_ROOT)/run-control_mgmt
FRCV_RTL_DIR       := $(REPO_ROOT)/mutrig_frame_deassembly/rtl
ARB_TYPE0_RTL_DIR  := $(REPO_ROOT)/misc/arb_hit_type0/rtl
HIT_TYPE0_MUX4_RTL := $(REPO_ROOT)/misc/hit_type0_readyless_mux4/rtl/hit_type0_readyless_mux4.sv
MTS_RTL_DIR        := $(REPO_ROOT)/mutrig_timestamp_processor
HIST_RTL_DIR       := $(REPO_ROOT)/histogram_statistics/rtl
VCD2FST            ?= vcd2fst
INTEL_18_SIM_LIB   ?= /data1/intelFPGA/18.1/quartus/eda/sim_lib
INTEL_VERILOG_LIB  ?= intel_verilog
INTEL_ALTERA_MF_LIB ?= altera_mf
UVM_HOME           := $(QUESTA_HOME)/verilog_src/uvm-1.2/src
QUESTA_UVM_HOME    := $(QUESTA_HOME)/verilog_src/questa_uvm_pkg-1.2/src
UVM_SRC            := $(UVM_HOME)/uvm_pkg.sv
UVM_INCDIR         := +incdir+$(UVM_HOME) +incdir+$(QUESTA_UVM_HOME)
VLOG_OPTS          := -sv -work $(WORK) -timescale 1ps/1ps +define+UVM_NO_DPI +define+TB_INT_SIM
BIND_REAL_DUT      ?= 0
VSIM_LIB_OPTS      := -L lpm -L $(INTEL_ALTERA_MF_LIB)
VSIM_DO            := run -all; quit -f
COMP_UVM_DEPS      := lib comp_tb_int_hist_ip
ifeq ($(BIND_REAL_DUT),1)
VLOG_OPTS          += +define+TB_INT_BIND_REAL_DUT
VSIM_LIB_OPTS      := -L lpm -L $(INTEL_VERILOG_LIB) -L $(INTEL_ALTERA_MF_LIB)
VSIM_DO            := assertion enable -off -r /$(TB_TOP)/u_dut/*; run -all; quit -f
COMP_UVM_DEPS      := lib comp_dut
endif
VSIM_OPTS          := -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -suppress 8822 -nodpiexports -work $(WORK) $(VSIM_LIB_OPTS)
TYPE0_ARB_WORK ?= work_type0_arb_hist
TYPE0_ARB_TOP  := tb_type0_arb_mts_hist_cosim
TYPE0_ARB_FIFO_DEPTH ?= 2
TYPE0_ARB_COUNTER_PROFILE ?= 1
TYPE0_ARB_DEBUG_LEVEL ?= 0
TYPE0_MUX_FIFO_DEPTH ?= 16
TYPE0_MUX_DEBUG_LEVEL ?= 0
TYPE0_EMU_DEBUG_LEVEL ?= 0
TYPE0_MTS_DEBUG ?= 0
TYPE0_ARB_RUN_CYCLES ?= 200000
TYPE0_ARB_Q16_RATE   ?= 52
TYPE0_ARB_DRAIN_CYCLES ?= 4096
TYPE0_ARB_HIST_MODE ?= 1
TYPE0_ARB_LANE_SCALE ?= 1
TYPE0_ARB_CHECK_THEORY ?= 0
TYPE0_ARB_DO_SWITCH_TEST ?= 1
TYPE0_ARB_REAL_PERIOD_CYCLES ?= 256
TYPE0_ARB_REAL_HITS_PER_FRAME ?= 8
TYPE0_ARB_RATE_TOLERANCE_PCT ?= 5.0
TYPE0_ARB_SIM_SUBDIR ?= TYPE0_ARB_HIST
TYPE0_ARB_WAVE_VCD ?= $(SIM_ROOT)/$(TYPE0_ARB_SIM_SUBDIR)/type0_arb_mts_hist.vcd
TYPE0_ARB_WAVE_FST ?= $(SIM_ROOT)/$(TYPE0_ARB_SIM_SUBDIR)/type0_arb_mts_hist.fst
TYPE0_ARB_GTKW ?= waves/gtkw/type0_arb_mts_hist.gtkw
RC_EMUL_REALISTIC_WAVE_VCD ?= $(SIM_ROOT)/RC_EMUL_REALISTIC_WAVE/feb_rc_emul_realistic_packet_contract.vcd
RC_EMUL_REALISTIC_WAVE_FST ?= $(SIM_ROOT)/RC_EMUL_REALISTIC_WAVE/feb_rc_emul_realistic_packet_contract.fst
RC_EMUL_REALISTIC_GTKW ?= waves/gtkw/feb_rc_emul_realistic_packet_contract.gtkw
RC_EMUL_REALISTIC_LONG_HIT_COUNT ?= 128
RC_EMUL_REALISTIC_LONG_PERIOD_CYCLES ?= 1250
RC_EMUL_REALISTIC_LONG_FRAMES_PER_LANE ?= 64
RC_EMUL_REALISTIC_LONG_FRAME_PERIOD_CYCLES ?= 2048
RC_EMUL_REALISTIC_LONG_WAVE_VCD ?= $(SIM_ROOT)/RC_EMUL_REALISTIC_LONG_WAVE/feb_rc_emul_realistic_long_packet_contract.vcd
RC_EMUL_REALISTIC_LONG_WAVE_FST ?= $(SIM_ROOT)/RC_EMUL_REALISTIC_LONG_WAVE/feb_rc_emul_realistic_long_packet_contract.fst
RC_EMUL_REALISTIC_LONG_GTKW ?= waves/gtkw/feb_rc_emul_realistic_long_packet_contract.gtkw
UPLOAD_MUX_CONTRACT_WORK ?= work_upload_mux_contract
UPLOAD_MUX_CONTRACT_TOP ?= tb_upload_pkt_mux_contract
UPLOAD_MUX_CONTRACT_TB ?= uvm/common/upload_pkt_mux_contract/tb_upload_pkt_mux_contract.sv
UPLOAD_MUX_CONTRACT_TRANSCRIPT ?= $(SIM_ROOT)/upload_pkt_mux_contract/transcript

SOURCE_MUX_FRAME_RUN_CYCLES ?= $(TYPE0_ARB_RUN_CYCLES)
SOURCE_MUX_FRAME_Q16_RATE ?= $(TYPE0_ARB_Q16_RATE)
SOURCE_MUX_FRAME_DRAIN_CYCLES ?= $(TYPE0_ARB_DRAIN_CYCLES)
SOURCE_MUX_FRAME_HIST_MODE ?= $(TYPE0_ARB_HIST_MODE)
SOURCE_MUX_FRAME_LANE_SCALE ?= $(TYPE0_ARB_LANE_SCALE)
SOURCE_MUX_FRAME_CHECK_THEORY ?= $(TYPE0_ARB_CHECK_THEORY)
SOURCE_MUX_FRAME_RATE_TOLERANCE_PCT ?= $(TYPE0_ARB_RATE_TOLERANCE_PCT)

HIST_VHDL_SRC = \
	$(HIST_RTL_DIR)/histogram_statistics_v2_pkg.vhd \
	$(HIST_RTL_DIR)/true_dual_port_ram_single_clock.vhd \
	$(HIST_RTL_DIR)/alt_dpram/alt_dpram_true.vhd \
	$(HIST_RTL_DIR)/hit_fifo.vhd \
	$(HIST_RTL_DIR)/rr_arbiter.vhd \
	$(HIST_RTL_DIR)/bin_divider.vhd \
	$(HIST_RTL_DIR)/coalescing_queue.vhd \
	$(HIST_RTL_DIR)/pingpong_sram.vhd \
	$(HIST_RTL_DIR)/histogram_statistics_v2.vhd

RUNCTL_MGMT_VHDL_SRC = \
	$(RUNCTL_MGMT_RTL_DIR)/altera_ip/logging_fifo.vhd

QSYS_RUNCTL_SPLITTER_VHDL_SRC = \
	$(QSYS_SYNTH_DIR)/submodules/feb_system_v3_data_path_subsystem_run_control_splitter.vhd \
	$(QSYS_SYNTH_DIR)/submodules/feb_system_v3_data_path_subsystem_emulator_ctrl_splitter.vhd

EMU_COSIM_SV_SRC = \
	$(EMU_RTL_DIR)/common/frontend_ticket_bus_pkg.sv \
	$(EMU_RTL_DIR)/backend_mutrig/be_mutrig_pkg.sv \
	$(EMU_RTL_DIR)/common/prbs15_lfsr.sv \
	$(EMU_RTL_DIR)/common/crc16_8.sv \
	$(EMU_RTL_DIR)/frontend/frontend_csr.sv \
	$(EMU_RTL_DIR)/frontend/frontend_run_ctl.sv \
	$(EMU_RTL_DIR)/frontend/frontend_trigger_engine.sv \
	$(EMU_RTL_DIR)/frontend/frontend_bkg_generator.sv \
	$(EMU_RTL_DIR)/frontend/frontend_ticket_distributor.sv \
	$(EMU_RTL_DIR)/backend_mutrig/be_mutrig_l2_fifo.sv \
	$(EMU_RTL_DIR)/backend_mutrig/be_mutrig_lane_emitter.sv \
	$(EMU_RTL_DIR)/backend_mutrig/be_mutrig_lane_type0_emit.sv \
	$(EMU_RTL_DIR)/backend_mutrig/be_mutrig_frame_assembler.sv \
	$(EMU_RTL_DIR)/emulator_mutrig.sv \
	$(EMU_RTL_DIR)/emulator_mutrig_qsys_lane.sv \
	$(ARB_TYPE0_RTL_DIR)/arb_hit_type0_fifo.sv \
	$(ARB_TYPE0_RTL_DIR)/arb_hit_type0_watchdog.sv \
	$(ARB_TYPE0_RTL_DIR)/arb_hit_type0_runctl.sv \
	$(ARB_TYPE0_RTL_DIR)/arb_hit_type0_arbiter.sv \
	$(ARB_TYPE0_RTL_DIR)/arb_hit_type0_csr.sv \
	$(ARB_TYPE0_RTL_DIR)/arb_hit_type0_csr_trim3.sv \
	$(ARB_TYPE0_RTL_DIR)/arb_hit_type0_csr_profiled.sv \
	$(ARB_TYPE0_RTL_DIR)/arb_hit_type0.sv \
	$(HIT_TYPE0_MUX4_RTL) \
	uvm/v3_pretest-260511/tb_source_mux_frame_parser_cosim.sv

TYPE0_ARB_VLOG_DEFS = \
	+define+TYPE0_ARB_FIFO_DEPTH=$(TYPE0_ARB_FIFO_DEPTH) \
	+define+TYPE0_ARB_COUNTER_PROFILE=$(TYPE0_ARB_COUNTER_PROFILE) \
	+define+TYPE0_ARB_DEBUG_LEVEL=$(TYPE0_ARB_DEBUG_LEVEL) \
	+define+TYPE0_MUX_FIFO_DEPTH=$(TYPE0_MUX_FIFO_DEPTH) \
	+define+TYPE0_MUX_DEBUG_LEVEL=$(TYPE0_MUX_DEBUG_LEVEL) \
	+define+TYPE0_EMU_DEBUG_LEVEL=$(TYPE0_EMU_DEBUG_LEVEL) \
	+define+TYPE0_MTS_DEBUG=$(TYPE0_MTS_DEBUG)

.PHONY: lib intel_lpm altera_mf_vhdl intel_verilog_libs comp_board_deps comp_tb_int_hist_ip check_qsys_dut_manifest comp_uvm comp_uvm_emul_fixed qsys_filelists comp_dut check_dut_contract comp_type0_arb_mts_hist_cosim run_type0_arb_mts_hist_cosim run_type0_arb_mts_hist_cosim_wave run_type0_arb_mts_hist_cosim_rate run_type0_arb_mts_hist_cosim_latency comp_source_mux_frame_parser_cosim run_source_mux_frame_parser_cosim smoke run_B065 run_B066 run_B067 run_B068 run_B069 run_b065 run_b066 run_b067 run_b068 run_b069 run_RC_EMUL run_RC_EMUL_BLOCKED run_RC_EMUL_FIXED run_RC_EMUL_REALISTIC run_RC_EMUL_REALISTIC_WAVE run_RC_EMUL_REALISTIC_LONG_WAVE run_UPLOAD_MUX_CONTRACT regress_basic all_buckets_frame static_screen clean

modelsim.ini:
	cp $(QUESTA_HOME)/modelsim.ini modelsim.ini

lib: modelsim.ini
	mkdir -p $(WORK) $(SIM_ROOT)
	$(VLIB) $(WORK)
	$(VMAP) -modelsimini modelsim.ini work $(WORK)

intel_lpm: modelsim.ini
	$(VLIB) lpm
	$(VMAP) -modelsimini modelsim.ini lpm lpm
	$(VCOM) -modelsimini modelsim.ini -2008 -work lpm $(INTEL_18_SIM_LIB)/220pack.vhd
	$(VCOM) -modelsimini modelsim.ini -2008 -work lpm $(INTEL_18_SIM_LIB)/220model.vhd

altera_mf_vhdl: modelsim.ini
	$(VLIB) $(INTEL_ALTERA_MF_LIB)
	$(VMAP) -modelsimini modelsim.ini $(INTEL_ALTERA_MF_LIB) $(INTEL_ALTERA_MF_LIB)
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(INTEL_ALTERA_MF_LIB) $(INTEL_18_SIM_LIB)/altera_mf_components.vhd
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(INTEL_ALTERA_MF_LIB) $(INTEL_18_SIM_LIB)/altera_mf.vhd

intel_verilog_libs: modelsim.ini
	$(VLIB) $(INTEL_VERILOG_LIB)
	$(VMAP) -modelsimini modelsim.ini $(INTEL_VERILOG_LIB) $(INTEL_VERILOG_LIB)
	$(VLOG) -modelsimini modelsim.ini -work $(INTEL_VERILOG_LIB) $(INTEL_18_SIM_LIB)/220model.v
	$(VLOG) -modelsimini modelsim.ini -work $(INTEL_VERILOG_LIB) $(INTEL_18_SIM_LIB)/altera_mf.v
	$(VLOG) -modelsimini modelsim.ini -sv -work $(INTEL_VERILOG_LIB) $(INTEL_18_SIM_LIB)/altera_lnsim.sv
	$(VLOG) -modelsimini modelsim.ini -work $(INTEL_VERILOG_LIB) $(INTEL_18_SIM_LIB)/arriav_atoms.v
	$(VLOG) -modelsimini modelsim.ini -work $(INTEL_VERILOG_LIB) $(INTEL_18_SIM_LIB)/mentor/arriav_atoms_ncrypt.v

comp_board_deps: lib
	@if [ -n "$(BOARD_UTIL_SLV_PKG)" ]; then \
		$(VCOM) -modelsimini modelsim.ini -2008 -work $(WORK) $(BOARD_UTIL_SLV_PKG); \
	else \
		echo "WARN: no local board-project util_slv.vhd found; mudaq.vhd may fail to compile."; \
	fi
	@if [ -n "$(BOARD_MUDAQ_PKG)" ]; then \
		$(VCOM) -modelsimini modelsim.ini -2008 -work $(WORK) $(BOARD_MUDAQ_PKG); \
	else \
		echo "WARN: no local board-project mudaq.vhd found; generated max10_prog_avmm.vhd may fail to compile."; \
	fi

check_qsys_dut_manifest:
	python3 $(QSYS_DUT_MANIFEST_CHECK) check --variant $(QSYS_DUT_VARIANT) --dut-dir $(QSYS_SYNTH_DIR)

comp_uvm: check_qsys_dut_manifest $(COMP_UVM_DEPS)
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(UVM_INCDIR) $(UVM_SRC)
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(QSYS_SPLITTER_SV)
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(UVM_INCDIR) -f script/tb_int.f

comp_tb_int_hist_ip: lib intel_lpm altera_mf_vhdl
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(WORK) $(HIST_VHDL_SRC)
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(WORK) $(RUNCTL_MGMT_VHDL_SRC)
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(WORK) $(QSYS_RUNCTL_SPLITTER_VHDL_SRC)

qsys_filelists:
	python3 script/qip_to_filelists.py $(QSYS_QIP) $(QSYS_FILELIST_DIR)

comp_dut: qsys_filelists lib intel_lpm altera_mf_vhdl intel_verilog_libs comp_board_deps
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(WORK) -f $(QSYS_FILELIST_DIR)/qsys_vhdl.f
	@if [ -s "$(QSYS_FILELIST_DIR)/qsys_verilog.f" ]; then $(VLOG) -modelsimini modelsim.ini -work $(WORK) -f $(QSYS_FILELIST_DIR)/qsys_verilog.f; fi
	@if [ -s "$(QSYS_FILELIST_DIR)/qsys_sv.f" ]; then $(VLOG) -modelsimini modelsim.ini -sv -work $(WORK) -f $(QSYS_FILELIST_DIR)/qsys_sv.f; fi

comp_type0_arb_mts_hist_cosim: lib intel_lpm altera_mf_vhdl
	test -d $(TYPE0_ARB_WORK) || $(VLIB) $(TYPE0_ARB_WORK)
	$(VMAP) -modelsimini modelsim.ini $(TYPE0_ARB_WORK) $(TYPE0_ARB_WORK)
	cp $(MTS_RTL_DIR)/dual_port_rom_init.txt .
	$(VLOG) -modelsimini modelsim.ini -work $(TYPE0_ARB_WORK) $(MTS_RTL_DIR)/dual_port_rom.v
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(TYPE0_ARB_WORK) $(MTS_RTL_DIR)/mts_processor.vhd
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(TYPE0_ARB_WORK) $(HIST_VHDL_SRC)
	$(VLOG) -modelsimini modelsim.ini -sv -work $(TYPE0_ARB_WORK) -timescale 1ps/1ps -mfcu +define+TB_INT_SIM $(TYPE0_ARB_VLOG_DEFS) $(EMU_COSIM_SV_SRC)

run_type0_arb_mts_hist_cosim: comp_type0_arb_mts_hist_cosim
	mkdir -p $(SIM_ROOT)/$(TYPE0_ARB_SIM_SUBDIR)
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -nodpiexports -work $(TYPE0_ARB_WORK) -L lpm -L $(INTEL_ALTERA_MF_LIB) $(TYPE0_ARB_TOP) +RUN_CYCLES=$(TYPE0_ARB_RUN_CYCLES) +Q16_RATE=$(TYPE0_ARB_Q16_RATE) +DRAIN_CYCLES=$(TYPE0_ARB_DRAIN_CYCLES) +HIST_MODE=$(TYPE0_ARB_HIST_MODE) +LANE_SCALE=$(TYPE0_ARB_LANE_SCALE) +CHECK_THEORY=$(TYPE0_ARB_CHECK_THEORY) +DO_SWITCH_TEST=$(TYPE0_ARB_DO_SWITCH_TEST) +REAL_PERIOD_CYCLES=$(TYPE0_ARB_REAL_PERIOD_CYCLES) +REAL_HITS_PER_FRAME=$(TYPE0_ARB_REAL_HITS_PER_FRAME) +RATE_TOLERANCE_PCT=$(TYPE0_ARB_RATE_TOLERANCE_PCT) -l $(SIM_ROOT)/$(TYPE0_ARB_SIM_SUBDIR)/transcript -do "set NumericStdNoWarnings 1; set StdArithNoWarnings 1; run -all; quit -f"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/$(TYPE0_ARB_SIM_SUBDIR)/transcript

run_type0_arb_mts_hist_cosim_wave: comp_type0_arb_mts_hist_cosim
	mkdir -p $(SIM_ROOT)/$(TYPE0_ARB_SIM_SUBDIR) waves/gtkw
	$(VSIM) -modelsimini modelsim.ini -c -voptargs=+acc -suppress 19 -suppress 3009 -nodpiexports -work $(TYPE0_ARB_WORK) -L lpm -L $(INTEL_ALTERA_MF_LIB) $(TYPE0_ARB_TOP) +RUN_CYCLES=$(TYPE0_ARB_RUN_CYCLES) +Q16_RATE=$(TYPE0_ARB_Q16_RATE) +DRAIN_CYCLES=$(TYPE0_ARB_DRAIN_CYCLES) +HIST_MODE=$(TYPE0_ARB_HIST_MODE) +LANE_SCALE=$(TYPE0_ARB_LANE_SCALE) +CHECK_THEORY=$(TYPE0_ARB_CHECK_THEORY) +DO_SWITCH_TEST=$(TYPE0_ARB_DO_SWITCH_TEST) +REAL_PERIOD_CYCLES=$(TYPE0_ARB_REAL_PERIOD_CYCLES) +REAL_HITS_PER_FRAME=$(TYPE0_ARB_REAL_HITS_PER_FRAME) +RATE_TOLERANCE_PCT=$(TYPE0_ARB_RATE_TOLERANCE_PCT) -l $(SIM_ROOT)/$(TYPE0_ARB_SIM_SUBDIR)/transcript -do "set NumericStdNoWarnings 1; set StdArithNoWarnings 1; vcd file $(TYPE0_ARB_WAVE_VCD); vcd add -r /$(TYPE0_ARB_TOP)/clk /$(TYPE0_ARB_TOP)/rst /$(TYPE0_ARB_TOP)/cycle_count /$(TYPE0_ARB_TOP)/emu_hit_valid /$(TYPE0_ARB_TOP)/emu_hit_data /$(TYPE0_ARB_TOP)/emu_tx_valid /$(TYPE0_ARB_TOP)/real_source_enable /$(TYPE0_ARB_TOP)/real_hit_valid /$(TYPE0_ARB_TOP)/real_hit_data /$(TYPE0_ARB_TOP)/arb_ctrl_valid /$(TYPE0_ARB_TOP)/arb_ctrl_data /$(TYPE0_ARB_TOP)/arb_hit_valid /$(TYPE0_ARB_TOP)/arb_hit_data /$(TYPE0_ARB_TOP)/arb_debug_selected_metadata_valid /$(TYPE0_ARB_TOP)/arb_debug_selected_metadata /$(TYPE0_ARB_TOP)/mux_out_valid /$(TYPE0_ARB_TOP)/mux_out_data /$(TYPE0_ARB_TOP)/mts_type1_valid /$(TYPE0_ARB_TOP)/mts_type1_data /$(TYPE0_ARB_TOP)/mts_ext0_valid /$(TYPE0_ARB_TOP)/mts_ext0_data /$(TYPE0_ARB_TOP)/mts_type1_sidecar_valid /$(TYPE0_ARB_TOP)/mts_type1_sidecar_data /$(TYPE0_ARB_TOP)/hist_ext0_count /$(TYPE0_ARB_TOP)/hist_total_hits_csr /$(TYPE0_ARB_TOP)/hist_bank_status_csr /$(TYPE0_ARB_TOP)/hist_port_status_csr /$(TYPE0_ARB_TOP)/hist_dropped_hits_csr /$(TYPE0_ARB_TOP)/hist_csr_read /$(TYPE0_ARB_TOP)/hist_csr_address /$(TYPE0_ARB_TOP)/hist_csr_readdata; run -all; vcd flush; quit -f"
	$(VCD2FST) $(TYPE0_ARB_WAVE_VCD) $(TYPE0_ARB_WAVE_FST)
	@{ \
		printf '%s\n' '[*] GTKWave Analyzer save file'; \
		printf '[dumpfile] %s\n' '$(abspath $(TYPE0_ARB_WAVE_FST))'; \
		printf '[savefile] %s\n' '$(abspath $(TYPE0_ARB_GTKW))'; \
		printf '%s\n' '[timestart] 0' '[size] 1600 900' '[pos] -1 -1' '*-1 0' '[treeopen] $(TYPE0_ARB_TOP).'; \
		printf '%s\n' '@200' '- 00 clock reset cycle' '@28' '$(TYPE0_ARB_TOP).clk' '$(TYPE0_ARB_TOP).rst' '@24' '$(TYPE0_ARB_TOP).cycle_count[63:0]'; \
		printf '%s\n' '@200' '- 01 post-deassembly Type-0 sources' '@28' '$(TYPE0_ARB_TOP).emu_hit_valid' '$(TYPE0_ARB_TOP).emu_tx_valid' '$(TYPE0_ARB_TOP).real_source_enable' '$(TYPE0_ARB_TOP).real_hit_valid' '@22' '$(TYPE0_ARB_TOP).emu_hit_data[44:0]' '$(TYPE0_ARB_TOP).real_hit_data[44:0]'; \
		printf '%s\n' '@200' '- 02 arb_hit_type0 selected stream and metadata' '@28' '$(TYPE0_ARB_TOP).arb_ctrl_valid' '$(TYPE0_ARB_TOP).arb_hit_valid' '$(TYPE0_ARB_TOP).arb_debug_selected_metadata_valid' '@22' '$(TYPE0_ARB_TOP).arb_ctrl_data[8:0]' '$(TYPE0_ARB_TOP).arb_hit_data[44:0]' '$(TYPE0_ARB_TOP).arb_debug_selected_metadata[63:0]'; \
		printf '%s\n' '@200' '- 03 readyless mux and MTS' '@28' '$(TYPE0_ARB_TOP).mux_out_valid' '$(TYPE0_ARB_TOP).mts_type1_valid' '$(TYPE0_ARB_TOP).mts_ext0_valid' '$(TYPE0_ARB_TOP).mts_type1_sidecar_valid' '@22' '$(TYPE0_ARB_TOP).mux_out_data[44:0]' '$(TYPE0_ARB_TOP).mts_type1_data[38:0]' '$(TYPE0_ARB_TOP).mts_ext0_data[86:0]' '$(TYPE0_ARB_TOP).mts_type1_sidecar_data[63:0]'; \
		printf '%s\n' '@200' '- 04 histogram fill and CSR evidence' '@24' '$(TYPE0_ARB_TOP).hist_ext0_count' '@28' '$(TYPE0_ARB_TOP).hist_csr_read' '@22' '$(TYPE0_ARB_TOP).hist_csr_address[4:0]' '$(TYPE0_ARB_TOP).hist_csr_readdata[31:0]' '$(TYPE0_ARB_TOP).hist_total_hits_csr[31:0]' '$(TYPE0_ARB_TOP).hist_bank_status_csr[31:0]' '$(TYPE0_ARB_TOP).hist_port_status_csr[31:0]' '$(TYPE0_ARB_TOP).hist_dropped_hits_csr[31:0]'; \
	} > $(TYPE0_ARB_GTKW)
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/$(TYPE0_ARB_SIM_SUBDIR)/transcript

run_type0_arb_mts_hist_cosim_rate:
	$(MAKE) run_type0_arb_mts_hist_cosim TYPE0_ARB_SIM_SUBDIR=TYPE0_ARB_HIST_RATE TYPE0_ARB_HIST_MODE=0 TYPE0_ARB_DO_SWITCH_TEST=0 TYPE0_ARB_RUN_CYCLES=125000 TYPE0_ARB_DRAIN_CYCLES=8192 TYPE0_ARB_LANE_SCALE=8 TYPE0_ARB_CHECK_THEORY=1

run_type0_arb_mts_hist_cosim_latency:
	$(MAKE) run_type0_arb_mts_hist_cosim TYPE0_ARB_SIM_SUBDIR=TYPE0_ARB_HIST_LATENCY TYPE0_ARB_HIST_MODE=1 TYPE0_ARB_DO_SWITCH_TEST=0 TYPE0_ARB_RUN_CYCLES=125000 TYPE0_ARB_DRAIN_CYCLES=8192 TYPE0_ARB_LANE_SCALE=8 TYPE0_ARB_CHECK_THEORY=1

comp_source_mux_frame_parser_cosim: comp_type0_arb_mts_hist_cosim

run_source_mux_frame_parser_cosim:
	$(MAKE) run_type0_arb_mts_hist_cosim TYPE0_ARB_RUN_CYCLES=$(SOURCE_MUX_FRAME_RUN_CYCLES) TYPE0_ARB_Q16_RATE=$(SOURCE_MUX_FRAME_Q16_RATE) TYPE0_ARB_DRAIN_CYCLES=$(SOURCE_MUX_FRAME_DRAIN_CYCLES) TYPE0_ARB_HIST_MODE=$(SOURCE_MUX_FRAME_HIST_MODE) TYPE0_ARB_LANE_SCALE=$(SOURCE_MUX_FRAME_LANE_SCALE) TYPE0_ARB_CHECK_THEORY=$(SOURCE_MUX_FRAME_CHECK_THEORY) TYPE0_ARB_RATE_TOLERANCE_PCT=$(SOURCE_MUX_FRAME_RATE_TOLERANCE_PCT)

check_dut_contract:
	mkdir -p $(SIM_ROOT)/logs
	@echo "Checking generated DUT FEB upload contract in $(QSYS_SYNTH_DIR)" > $(SIM_ROOT)/logs/dut_structural_check.log
	@if rg -n "upload_pkt_mux|feb_frame_assembly" $(QSYS_SYNTH_DIR) >> $(SIM_ROOT)/logs/dut_structural_check.log; then \
		echo "PASS: legacy FEB upload_pkt_mux/feb_frame_assembly path found" >> $(SIM_ROOT)/logs/dut_structural_check.log; \
	else \
		echo "BLOCKED: generated feb_system_v3 synthesis tree has no bindable upload_pkt_mux/feb_frame_assembly path." >> $(SIM_ROOT)/logs/dut_structural_check.log; \
		exit 2; \
	fi

smoke: run_B065

run_B065: comp_uvm
	mkdir -p $(SIM_ROOT)/B065
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_b065_test +ARB_SEED=$(SEED) +TB_INT_EXPECTED_HITS=16 +TB_INT_SIM_DIR=$(SIM_ROOT)/B065 -l $(SIM_ROOT)/B065/transcript -do "$(VSIM_DO)"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/B065/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/B065/transcript; then exit 1; fi

run_B066: comp_uvm
	mkdir -p $(SIM_ROOT)/B066
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_b066_test +ARB_SEED=$(SEED) +TB_INT_EXPECTED_HITS=16 +TB_INT_SIM_DIR=$(SIM_ROOT)/B066 -l $(SIM_ROOT)/B066/transcript -do "$(VSIM_DO)"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/B066/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/B066/transcript; then exit 1; fi

run_B067: comp_uvm
	mkdir -p $(SIM_ROOT)/B067
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_b067_test +ARB_SEED=$(SEED) +TB_INT_EXPECTED_HITS=100 +TB_INT_SIM_DIR=$(SIM_ROOT)/B067 -l $(SIM_ROOT)/B067/transcript -do "$(VSIM_DO)"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/B067/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/B067/transcript; then exit 1; fi

run_B068: comp_uvm
	mkdir -p $(SIM_ROOT)/B068
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_b068_test +ARB_SEED=$(SEED) +TB_INT_EXPECTED_HITS=1024 +TB_INT_SIM_DIR=$(SIM_ROOT)/B068 -l $(SIM_ROOT)/B068/transcript -do "$(VSIM_DO)"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/B068/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/B068/transcript; then exit 1; fi

run_B069: comp_uvm
	mkdir -p $(SIM_ROOT)/B069
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_b069_test +ARB_SEED=$(SEED) +TB_INT_EXPECTED_HITS=1 +TB_INT_SIM_DIR=$(SIM_ROOT)/B069 -l $(SIM_ROOT)/B069/transcript -do "$(VSIM_DO)"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/B069/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/B069/transcript; then exit 1; fi

run_b065: run_B065
run_b066: run_B066
run_b067: run_B067
run_b068: run_B068
run_b069: run_B069

# Legacy BUG-RC-RUN-EMUL target name retained for regression scripts. The
# current tb_int shell uses the real runctl_mgmt_host synclink protocol plus
# generated Qsys splitters, so this now expects the path to pass hits.
run_RC_EMUL_BLOCKED: comp_uvm
	mkdir -p $(SIM_ROOT)/RC_EMUL_BLOCKED
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_run_emul_blocked_test +ARB_SEED=$(SEED) +TB_INT_RC_EMUL_HIT_COUNT=16 +TB_INT_SIM_DIR=$(SIM_ROOT)/RC_EMUL_BLOCKED -l $(SIM_ROOT)/RC_EMUL_BLOCKED/transcript -do "$(VSIM_DO)"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/RC_EMUL_BLOCKED/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/RC_EMUL_BLOCKED/transcript; then exit 1; fi

# Directed runctl_mgmt_host + emulator hit-path regression in a separate WORK
# dir for waveform/debug isolation. This build intentionally uses the same
# generated Qsys splitter path as the main tb_int compile and no legacy shortcut
# define.
comp_uvm_emul_fixed: check_qsys_dut_manifest lib intel_lpm altera_mf_vhdl
	test -d work_tb_int_emul_fixed || $(VLIB) work_tb_int_emul_fixed
	$(VMAP) -modelsimini modelsim.ini work_emul_fixed work_tb_int_emul_fixed
	$(VCOM) -modelsimini modelsim.ini -2008 -work work_tb_int_emul_fixed $(HIST_VHDL_SRC)
	$(VCOM) -modelsimini modelsim.ini -2008 -work work_tb_int_emul_fixed $(RUNCTL_MGMT_VHDL_SRC)
	$(VCOM) -modelsimini modelsim.ini -2008 -work work_tb_int_emul_fixed $(QSYS_RUNCTL_SPLITTER_VHDL_SRC)
	$(VLOG) -modelsimini modelsim.ini -sv -work work_tb_int_emul_fixed -timescale 1ps/1ps +define+UVM_NO_DPI +define+TB_INT_SIM $(UVM_INCDIR) $(UVM_SRC)
	$(VLOG) -modelsimini modelsim.ini -sv -work work_tb_int_emul_fixed -timescale 1ps/1ps +define+UVM_NO_DPI +define+TB_INT_SIM $(QSYS_SPLITTER_SV)
	$(VLOG) -modelsimini modelsim.ini -sv -work work_tb_int_emul_fixed -timescale 1ps/1ps +define+UVM_NO_DPI +define+TB_INT_SIM $(UVM_INCDIR) -f script/tb_int.f

run_RC_EMUL_FIXED: comp_uvm_emul_fixed
	mkdir -p $(SIM_ROOT)/RC_EMUL_FIXED
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -nodpiexports -work work_tb_int_emul_fixed -L lpm -L $(INTEL_ALTERA_MF_LIB) $(TB_TOP) +UVM_TESTNAME=tb_int_run_emul_fixed_test +ARB_SEED=$(SEED) +TB_INT_RC_EMUL_HIT_COUNT=16 +TB_INT_SIM_DIR=$(SIM_ROOT)/RC_EMUL_FIXED -l $(SIM_ROOT)/RC_EMUL_FIXED/transcript -do "run -all; quit -f"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/RC_EMUL_FIXED/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/RC_EMUL_FIXED/transcript; then exit 1; fi

run_RC_EMUL_REALISTIC: comp_uvm
	mkdir -p $(SIM_ROOT)/RC_EMUL_REALISTIC
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_run_emul_fixed_test +ARB_SEED=$(SEED) +TB_INT_RC_EMUL_HIT_COUNT=16 +TB_INT_REALISTIC_LATENCY +TB_INT_PERIODIC_CHANNEL=0 +TB_INT_PERIODIC_HIT_PERIOD_CYCLES=1250 +TB_INT_RUN_PREP_FLUSH_CYCLES=5000 +TB_INT_REQUIRE_FEB_UPLOAD_FRAMES +TB_INT_MIN_FEB_UPLOAD_HITS=1 +TB_INT_SIM_DIR=$(SIM_ROOT)/RC_EMUL_REALISTIC -l $(SIM_ROOT)/RC_EMUL_REALISTIC/transcript -do "$(VSIM_DO)"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/RC_EMUL_REALISTIC/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/RC_EMUL_REALISTIC/transcript; then exit 1; fi

run_RC_EMUL_REALISTIC_WAVE: comp_uvm
	mkdir -p $(SIM_ROOT)/RC_EMUL_REALISTIC_WAVE waves/gtkw
	$(VSIM) $(VSIM_OPTS) -voptargs=+acc $(TB_TOP) +UVM_TESTNAME=tb_int_run_emul_fixed_test +ARB_SEED=$(SEED) +TB_INT_RC_EMUL_HIT_COUNT=16 +TB_INT_REALISTIC_LATENCY +TB_INT_PERIODIC_CHANNEL=0 +TB_INT_PERIODIC_HIT_PERIOD_CYCLES=1250 +TB_INT_RUN_PREP_FLUSH_CYCLES=5000 +TB_INT_REQUIRE_FEB_UPLOAD_FRAMES +TB_INT_MIN_FEB_UPLOAD_HITS=1 +TB_INT_SIM_DIR=$(SIM_ROOT)/RC_EMUL_REALISTIC_WAVE -l $(SIM_ROOT)/RC_EMUL_REALISTIC_WAVE/transcript -do "vcd file $(RC_EMUL_REALISTIC_WAVE_VCD); vcd add -r /$(TB_TOP)/clk_125 /$(TB_TOP)/rst /$(TB_TOP)/runctl_phy_vif/* /$(TB_TOP)/stage_a_vif/* /$(TB_TOP)/debug_l2_vif/* /$(TB_TOP)/emulator_egress_vif/* /$(TB_TOP)/pre_rbcam_vif/* /$(TB_TOP)/post_rbcam_vif/* /$(TB_TOP)/feb_egress_vif/* /$(TB_TOP)/upload_data0_frame_vif/* /$(TB_TOP)/upload_data1_frame_vif/*; run -all; vcd flush; quit -f"
	-$(VCD2FST) $(RC_EMUL_REALISTIC_WAVE_VCD) $(RC_EMUL_REALISTIC_WAVE_FST)
	@{ \
		printf '%s\n' '[*] GTKWave Analyzer save file'; \
		printf '[dumpfile] %s\n' '$(abspath $(RC_EMUL_REALISTIC_WAVE_FST))'; \
		printf '[savefile] %s\n' '$(abspath $(RC_EMUL_REALISTIC_GTKW))'; \
		printf '%s\n' '[timestart] 0' '[size] 1800 1000' '[pos] -1 -1' '*-1 0' '[treeopen] $(TB_TOP).'; \
		printf '%s\n' '@200' '- 00 clocks reset and run-control command stream' '@28' '$(TB_TOP).clk_125' '$(TB_TOP).rst' '$(TB_TOP).runctl_phy_vif.valid' '@22' '$(TB_TOP).runctl_phy_vif.data[8:0]' '$(TB_TOP).runctl_phy_vif.error[2:0]'; \
		printf '%s\n' '@200' '- 01 generated-DUT emulator commit and debug sidecar' '@28' '$(TB_TOP).stage_a_vif.valid' '$(TB_TOP).debug_l2_vif.valid' '@22' '$(TB_TOP).stage_a_vif.payload[44:0]' '$(TB_TOP).debug_l2_vif.hit_id[63:0]'; \
		printf '%s\n' '@200' '- 02 expected hit checkpoints' '@28' '$(TB_TOP).emulator_egress_vif.valid' '$(TB_TOP).pre_rbcam_vif.valid' '$(TB_TOP).post_rbcam_vif.valid' '$(TB_TOP).feb_egress_vif.valid' '@22' '$(TB_TOP).emulator_egress_vif.payload[44:0]' '$(TB_TOP).pre_rbcam_vif.payload[44:0]' '$(TB_TOP).post_rbcam_vif.payload[44:0]' '$(TB_TOP).feb_egress_vif.payload[44:0]'; \
		printf '%s\n' '@200' '- 03 FEB upload frame contract upper bank' '@28' '$(TB_TOP).upload_data0_frame_vif.valid' '$(TB_TOP).upload_data0_frame_vif.ready' '$(TB_TOP).upload_data0_frame_vif.sop' '$(TB_TOP).upload_data0_frame_vif.eop' '@22' '$(TB_TOP).upload_data0_frame_vif.data[35:0]' '@24' '$(TB_TOP).upload_data0_frame_vif.frame_seq'; \
		printf '%s\n' '@200' '- 04 FEB upload frame contract lower bank' '@28' '$(TB_TOP).upload_data1_frame_vif.valid' '$(TB_TOP).upload_data1_frame_vif.ready' '$(TB_TOP).upload_data1_frame_vif.sop' '$(TB_TOP).upload_data1_frame_vif.eop' '@22' '$(TB_TOP).upload_data1_frame_vif.data[35:0]' '@24' '$(TB_TOP).upload_data1_frame_vif.frame_seq'; \
	} > $(RC_EMUL_REALISTIC_GTKW)
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/RC_EMUL_REALISTIC_WAVE/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/RC_EMUL_REALISTIC_WAVE/transcript; then exit 1; fi

run_RC_EMUL_REALISTIC_LONG_WAVE: comp_uvm
	mkdir -p $(SIM_ROOT)/RC_EMUL_REALISTIC_LONG_WAVE waves/gtkw
	$(VSIM) $(VSIM_OPTS) -voptargs=+acc $(TB_TOP) +UVM_TESTNAME=tb_int_run_emul_fixed_test +ARB_SEED=$(SEED) +TB_INT_RC_EMUL_HIT_COUNT=$(RC_EMUL_REALISTIC_LONG_HIT_COUNT) +TB_INT_REALISTIC_LATENCY +TB_INT_PERIODIC_CHANNEL=0 +TB_INT_PERIODIC_HIT_PERIOD_CYCLES=$(RC_EMUL_REALISTIC_LONG_PERIOD_CYCLES) +TB_INT_RUN_PREP_FLUSH_CYCLES=5000 +TB_INT_FEB_UPLOAD_FRAMES_PER_LANE=$(RC_EMUL_REALISTIC_LONG_FRAMES_PER_LANE) +TB_INT_FEB_UPLOAD_FRAME_PERIOD_CYCLES=$(RC_EMUL_REALISTIC_LONG_FRAME_PERIOD_CYCLES) +TB_INT_REQUIRE_FEB_UPLOAD_FRAMES +TB_INT_MIN_FEB_UPLOAD_HITS=1 +TB_INT_MIN_FEB_UPLOAD_FRAMES=$(RC_EMUL_REALISTIC_LONG_FRAMES_PER_LANE) +TB_INT_RC_EMUL_SNAPSHOT_ONLY +TB_INT_SIM_DIR=$(SIM_ROOT)/RC_EMUL_REALISTIC_LONG_WAVE -l $(SIM_ROOT)/RC_EMUL_REALISTIC_LONG_WAVE/transcript -do "vcd file $(RC_EMUL_REALISTIC_LONG_WAVE_VCD); vcd add -r /$(TB_TOP)/clk_125 /$(TB_TOP)/rst /$(TB_TOP)/runctl_phy_vif/* /$(TB_TOP)/stage_a_vif/* /$(TB_TOP)/debug_l2_vif/* /$(TB_TOP)/emulator_egress_vif/* /$(TB_TOP)/pre_rbcam_vif/* /$(TB_TOP)/post_rbcam_vif/* /$(TB_TOP)/feb_egress_vif/* /$(TB_TOP)/upload_data0_frame_vif/* /$(TB_TOP)/upload_data1_frame_vif/*; run -all; vcd flush; quit -f"
	-$(VCD2FST) $(RC_EMUL_REALISTIC_LONG_WAVE_VCD) $(RC_EMUL_REALISTIC_LONG_WAVE_FST)
	@{ \
		printf '%s\n' '[*] GTKWave Analyzer save file'; \
		printf '[dumpfile] %s\n' '$(abspath $(RC_EMUL_REALISTIC_LONG_WAVE_FST))'; \
		printf '[savefile] %s\n' '$(abspath $(RC_EMUL_REALISTIC_LONG_GTKW))'; \
		printf '%s\n' '[timestart] 0' '[size] 1800 1000' '[pos] -1 -1' '*-1 0' '[treeopen] $(TB_TOP).'; \
		printf '%s\n' '@200' '- 00 clocks reset and run-control command stream' '@28' '$(TB_TOP).clk_125' '$(TB_TOP).rst' '$(TB_TOP).runctl_phy_vif.valid' '@22' '$(TB_TOP).runctl_phy_vif.data[8:0]' '$(TB_TOP).runctl_phy_vif.error[2:0]'; \
		printf '%s\n' '@200' '- 01 long-run hit checkpoints' '@28' '$(TB_TOP).stage_a_vif.valid' '$(TB_TOP).debug_l2_vif.valid' '$(TB_TOP).emulator_egress_vif.valid' '$(TB_TOP).pre_rbcam_vif.valid' '$(TB_TOP).post_rbcam_vif.valid' '$(TB_TOP).feb_egress_vif.valid' '@22' '$(TB_TOP).debug_l2_vif.hit_id[63:0]' '$(TB_TOP).feb_egress_vif.payload[44:0]'; \
		printf '%s\n' '@200' '- 02 FEB upload frame contract upper bank' '@28' '$(TB_TOP).upload_data0_frame_vif.valid' '$(TB_TOP).upload_data0_frame_vif.ready' '$(TB_TOP).upload_data0_frame_vif.sop' '$(TB_TOP).upload_data0_frame_vif.eop' '@22' '$(TB_TOP).upload_data0_frame_vif.data[35:0]' '@24' '$(TB_TOP).upload_data0_frame_vif.frame_seq'; \
		printf '%s\n' '@200' '- 03 FEB upload frame contract lower bank' '@28' '$(TB_TOP).upload_data1_frame_vif.valid' '$(TB_TOP).upload_data1_frame_vif.ready' '$(TB_TOP).upload_data1_frame_vif.sop' '$(TB_TOP).upload_data1_frame_vif.eop' '@22' '$(TB_TOP).upload_data1_frame_vif.data[35:0]' '@24' '$(TB_TOP).upload_data1_frame_vif.frame_seq'; \
	} > $(RC_EMUL_REALISTIC_LONG_GTKW)
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/RC_EMUL_REALISTIC_LONG_WAVE/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/RC_EMUL_REALISTIC_LONG_WAVE/transcript; then exit 1; fi

run_UPLOAD_MUX_CONTRACT: modelsim.ini
	mkdir -p $(dir $(UPLOAD_MUX_CONTRACT_TRANSCRIPT))
	test -d $(UPLOAD_MUX_CONTRACT_WORK) || $(VLIB) $(UPLOAD_MUX_CONTRACT_WORK)
	$(VLOG) -modelsimini modelsim.ini -sv -work $(UPLOAD_MUX_CONTRACT_WORK) $(QSYS_SYNTH_DIR)/submodules/feb_system_v3_upload_subsystem_upload_pkt_mux.sv $(UPLOAD_MUX_CONTRACT_TB)
	$(VSIM) -modelsimini modelsim.ini -c -work $(UPLOAD_MUX_CONTRACT_WORK) $(UPLOAD_MUX_CONTRACT_TOP) -l $(UPLOAD_MUX_CONTRACT_TRANSCRIPT) -do "run -all; quit -f"
	rg "UPLOAD_MUX_CONTRACT_PASS" $(UPLOAD_MUX_CONTRACT_TRANSCRIPT)

run_RC_EMUL: comp_uvm
	mkdir -p $(SIM_ROOT)/RC_EMUL
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_run_emulator_directed_test +ARB_SEED=$(SEED) +TB_INT_RC_EMUL_HIT_COUNT=16 +TB_INT_SIM_DIR=$(SIM_ROOT)/RC_EMUL -l $(SIM_ROOT)/RC_EMUL/transcript -do "$(VSIM_DO)"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/RC_EMUL/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/RC_EMUL/transcript; then exit 1; fi

regress_basic: run_B065 run_B066 run_B067 run_B068 run_B069

all_buckets_frame:
	@echo "all_buckets_frame: hook present; full continuous-frame run waits for the complete bucket implementation."

static_screen:
	python3 ~/.codex/skills/rtl-linter-and-checker/scripts/questa_static_screen.py --top tb_int_top --filelist script/tb_int.f --modes lint,cdc,rdc uvm/v3_pretest-260511/*.sv

clean:
	@echo "clean: non-destructive by policy. Remove work/ and sim/ manually if a clean tree is required."

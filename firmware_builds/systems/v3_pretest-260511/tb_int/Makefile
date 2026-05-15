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
QSYS_SYNTH_DIR     := $(SYSTEM_ROOT)/syn/feb_system_v3/synthesis
QSYS_QIP           := $(QSYS_SYNTH_DIR)/feb_system_v3.qip
QSYS_FILELIST_DIR  := $(SIM_ROOT)/filelists
BOARD_UTIL_SLV_PKG := $(firstword $(wildcard $(SYSTEM_ROOT)/syn/board_projects/*/src/common/util/util_slv.vhd))
BOARD_MUDAQ_PKG    := $(firstword $(wildcard $(SYSTEM_ROOT)/syn/board_projects/*/src/common/registers/mudaq.vhd))
EMU_RTL_DIR        := $(REPO_ROOT)/emulator_mutrig/rtl
FRCV_RTL_DIR       := $(REPO_ROOT)/mutrig_frame_deassembly/rtl
SOURCE_MUX_RTL     := $(REPO_ROOT)/misc/mutrig_lane_source_mux/rtl/mutrig_lane_source_mux.sv
MTS_RTL_DIR        := $(REPO_ROOT)/mutrig_timestamp_processor
HIST_RTL_DIR       := $(REPO_ROOT)/histogram_statistics/rtl
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
VSIM_LIB_OPTS      += -L $(INTEL_VERILOG_LIB)
VSIM_DO            := assertion enable -off -r /$(TB_TOP)/u_dut/*; run -all; quit -f
COMP_UVM_DEPS      := lib comp_dut
endif
VSIM_OPTS          := -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -nodpiexports -work $(WORK) $(VSIM_LIB_OPTS)
SOURCE_MUX_FRAME_WORK ?= work_source_mux_frame
SOURCE_MUX_FRAME_TOP  := tb_source_mux_frame_parser_cosim
SOURCE_MUX_FRAME_RUN_CYCLES ?= 200000
SOURCE_MUX_FRAME_Q16_RATE   ?= 52

QSYS_LANE_CHAIN_SV_SRC = \
	$(QSYS_SYNTH_DIR)/submodules/feb_system_v3_data_path_subsystem_avalon_st_adapter_024_channel_adapter_0.sv \
	$(QSYS_SYNTH_DIR)/submodules/feb_system_v3_data_path_subsystem_avalon_st_adapter_024_timing_adapter_0.sv \
	$(QSYS_SYNTH_DIR)/submodules/feb_system_v3_data_path_subsystem_avalon_st_adapter_024.v \
	$(QSYS_SYNTH_DIR)/submodules/altera_avalon_sc_fifo.v \
	$(QSYS_SYNTH_DIR)/submodules/feb_system_v3_data_path_subsystem_avalon_st_adapter_009_channel_adapter_0.sv \
	$(QSYS_SYNTH_DIR)/submodules/feb_system_v3_data_path_subsystem_avalon_st_adapter_009_timing_adapter_0.sv \
	$(QSYS_SYNTH_DIR)/submodules/feb_system_v3_data_path_subsystem_avalon_st_adapter_009.v

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
	$(SOURCE_MUX_RTL) \
	$(FRCV_RTL_DIR)/sv_ver/frame_rcv_ip/frame_rcv_ip_dut_sv.sv \
	$(QSYS_LANE_CHAIN_SV_SRC) \
	uvm/v3_pretest-260511/tb_source_mux_frame_parser_cosim.sv

.PHONY: lib intel_lpm altera_mf_vhdl intel_verilog_libs comp_board_deps comp_tb_int_hist_ip comp_uvm comp_uvm_emul_fixed qsys_filelists comp_dut check_dut_contract comp_source_mux_frame_parser_cosim run_source_mux_frame_parser_cosim smoke run_B065 run_B066 run_B067 run_B068 run_B069 run_b065 run_b066 run_b067 run_b068 run_b069 run_RC_EMUL run_RC_EMUL_BLOCKED run_RC_EMUL_FIXED regress_basic all_buckets_frame static_screen clean

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

comp_uvm: $(COMP_UVM_DEPS)
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(UVM_INCDIR) $(UVM_SRC)
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(UVM_INCDIR) -f script/tb_int.f

comp_tb_int_hist_ip: lib intel_lpm altera_mf_vhdl
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(WORK) $(HIST_VHDL_SRC)

qsys_filelists:
	python3 script/qip_to_filelists.py $(QSYS_QIP) $(QSYS_FILELIST_DIR)

comp_dut: qsys_filelists lib intel_lpm altera_mf_vhdl intel_verilog_libs comp_board_deps
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(WORK) -f $(QSYS_FILELIST_DIR)/qsys_vhdl.f
	@if [ -s "$(QSYS_FILELIST_DIR)/qsys_verilog.f" ]; then $(VLOG) -modelsimini modelsim.ini -work $(WORK) -f $(QSYS_FILELIST_DIR)/qsys_verilog.f; fi
	@if [ -s "$(QSYS_FILELIST_DIR)/qsys_sv.f" ]; then $(VLOG) -modelsimini modelsim.ini -sv -work $(WORK) -f $(QSYS_FILELIST_DIR)/qsys_sv.f; fi

comp_source_mux_frame_parser_cosim: lib intel_lpm altera_mf_vhdl
	test -d $(SOURCE_MUX_FRAME_WORK) || $(VLIB) $(SOURCE_MUX_FRAME_WORK)
	$(VMAP) -modelsimini modelsim.ini $(SOURCE_MUX_FRAME_WORK) $(SOURCE_MUX_FRAME_WORK)
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(SOURCE_MUX_FRAME_WORK) $(FRCV_RTL_DIR)/crc16_calc.vhd
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(SOURCE_MUX_FRAME_WORK) $(FRCV_RTL_DIR)/frame_rcv_ip.vhd
	cp $(MTS_RTL_DIR)/dual_port_rom_init.txt .
	$(VLOG) -modelsimini modelsim.ini -work $(SOURCE_MUX_FRAME_WORK) $(MTS_RTL_DIR)/dual_port_rom.v
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(SOURCE_MUX_FRAME_WORK) $(MTS_RTL_DIR)/mts_processor.vhd
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(SOURCE_MUX_FRAME_WORK) $(HIST_VHDL_SRC)
	$(VLOG) -modelsimini modelsim.ini -sv -work $(SOURCE_MUX_FRAME_WORK) -timescale 1ps/1ps -mfcu +define+TB_INT_SIM $(EMU_COSIM_SV_SRC)

run_source_mux_frame_parser_cosim: comp_source_mux_frame_parser_cosim
	mkdir -p $(SIM_ROOT)/SOURCE_MUX_FRAME
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -nodpiexports -work $(SOURCE_MUX_FRAME_WORK) -L lpm -L $(INTEL_ALTERA_MF_LIB) $(SOURCE_MUX_FRAME_TOP) +RUN_CYCLES=$(SOURCE_MUX_FRAME_RUN_CYCLES) +Q16_RATE=$(SOURCE_MUX_FRAME_Q16_RATE) -l $(SIM_ROOT)/SOURCE_MUX_FRAME/transcript -do "run -all; quit -f"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/SOURCE_MUX_FRAME/transcript

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

# BUG-RC-RUN-EMUL behavioural topology repro (PRE-FIX). Uses the default
# WORK dir (no BUG_RC_RUN_EMUL_FIXED define), so the splitter's
# dangling-ready collapse blocks the RUNNING broadcast. Expects
# TOTAL_HITS=0 after 16 emulator hits.
run_RC_EMUL_BLOCKED: comp_uvm
	mkdir -p $(SIM_ROOT)/RC_EMUL_BLOCKED
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_run_emul_blocked_test +ARB_SEED=$(SEED) +TB_INT_RC_EMUL_HIT_COUNT=16 +TB_INT_SIM_DIR=$(SIM_ROOT)/RC_EMUL_BLOCKED -l $(SIM_ROOT)/RC_EMUL_BLOCKED/transcript -do "$(VSIM_DO)"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/RC_EMUL_BLOCKED/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/RC_EMUL_BLOCKED/transcript; then exit 1; fi

# BUG-RC-RUN-EMUL behavioural topology repro (POST-FIX). Compiles into a
# separate WORK dir (work_tb_int_emul_fixed) with
# +define+BUG_RC_RUN_EMUL_FIXED so the splitter ignores out_ready and the
# broadcast propagates. Expects TOTAL_HITS=16 after 16 emulator hits.
comp_uvm_emul_fixed: lib intel_lpm altera_mf_vhdl
	test -d work_tb_int_emul_fixed || $(VLIB) work_tb_int_emul_fixed
	$(VMAP) -modelsimini modelsim.ini work_emul_fixed work_tb_int_emul_fixed
	$(VCOM) -modelsimini modelsim.ini -2008 -work work_tb_int_emul_fixed $(HIST_VHDL_SRC)
	$(VLOG) -modelsimini modelsim.ini -sv -work work_tb_int_emul_fixed -timescale 1ps/1ps +define+UVM_NO_DPI +define+TB_INT_SIM +define+BUG_RC_RUN_EMUL_FIXED $(UVM_INCDIR) $(UVM_SRC)
	$(VLOG) -modelsimini modelsim.ini -sv -work work_tb_int_emul_fixed -timescale 1ps/1ps +define+UVM_NO_DPI +define+TB_INT_SIM +define+BUG_RC_RUN_EMUL_FIXED $(UVM_INCDIR) -f script/tb_int.f

run_RC_EMUL_FIXED: comp_uvm_emul_fixed
	mkdir -p $(SIM_ROOT)/RC_EMUL_FIXED
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -nodpiexports -work work_tb_int_emul_fixed -L lpm -L $(INTEL_ALTERA_MF_LIB) $(TB_TOP) +UVM_TESTNAME=tb_int_run_emul_fixed_test +ARB_SEED=$(SEED) +TB_INT_RC_EMUL_HIT_COUNT=16 +TB_INT_SIM_DIR=$(SIM_ROOT)/RC_EMUL_FIXED -l $(SIM_ROOT)/RC_EMUL_FIXED/transcript -do "run -all; quit -f"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/RC_EMUL_FIXED/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/RC_EMUL_FIXED/transcript; then exit 1; fi

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

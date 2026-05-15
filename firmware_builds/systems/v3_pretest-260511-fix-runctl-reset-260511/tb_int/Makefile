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
QSYS_SYNTH_DIR     := $(SYSTEM_ROOT)/syn/feb_system_v3/synthesis
QSYS_QIP           := $(QSYS_SYNTH_DIR)/feb_system_v3.qip
QSYS_FILELIST_DIR  := $(SIM_ROOT)/filelists
BOARD_UTIL_SLV_PKG := $(firstword $(wildcard $(SYSTEM_ROOT)/syn/board_projects/*/src/common/util/util_slv.vhd))
BOARD_MUDAQ_PKG    := $(firstword $(wildcard $(SYSTEM_ROOT)/syn/board_projects/*/src/common/registers/mudaq.vhd))
INTEL_18_SIM_LIB   ?= /data1/intelFPGA/18.1/quartus/eda/sim_lib
UVM_HOME           := $(QUESTA_HOME)/verilog_src/uvm-1.2/src
QUESTA_UVM_HOME    := $(QUESTA_HOME)/verilog_src/questa_uvm_pkg-1.2/src
UVM_SRC            := $(UVM_HOME)/uvm_pkg.sv
UVM_INCDIR         := +incdir+$(UVM_HOME) +incdir+$(QUESTA_UVM_HOME)
VLOG_OPTS          := -sv -work $(WORK) -timescale 1ps/1ps +define+UVM_NO_DPI +define+TB_INT_SIM
VSIM_OPTS          := -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -nodpiexports -work $(WORK)

.PHONY: lib intel_lpm comp_board_deps comp_uvm qsys_filelists comp_dut check_dut_contract smoke run_B065 run_B066 run_B067 run_B068 run_B069 run_b065 run_b066 run_b067 run_b068 run_b069 regress_basic all_buckets_frame static_screen clean

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

comp_uvm: lib
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(UVM_INCDIR) $(UVM_SRC)
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(UVM_INCDIR) -f script/tb_int.f

qsys_filelists:
	python3 script/qip_to_filelists.py $(QSYS_QIP) $(QSYS_FILELIST_DIR)

comp_dut: qsys_filelists lib intel_lpm comp_board_deps
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(WORK) -f $(QSYS_FILELIST_DIR)/qsys_vhdl.f
	@if [ -s "$(QSYS_FILELIST_DIR)/qsys_verilog.f" ]; then $(VLOG) -modelsimini modelsim.ini -work $(WORK) -f $(QSYS_FILELIST_DIR)/qsys_verilog.f; fi
	@if [ -s "$(QSYS_FILELIST_DIR)/qsys_sv.f" ]; then $(VLOG) -modelsimini modelsim.ini -sv -work $(WORK) -f $(QSYS_FILELIST_DIR)/qsys_sv.f; fi

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
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_b065_test +ARB_SEED=$(SEED) +TB_INT_EXPECTED_HITS=16 +TB_INT_SIM_DIR=$(SIM_ROOT)/B065 -l $(SIM_ROOT)/B065/transcript -do "run -all; quit -f"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/B065/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/B065/transcript; then exit 1; fi

run_B066: comp_uvm
	mkdir -p $(SIM_ROOT)/B066
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_b066_test +ARB_SEED=$(SEED) +TB_INT_EXPECTED_HITS=16 +TB_INT_SIM_DIR=$(SIM_ROOT)/B066 -l $(SIM_ROOT)/B066/transcript -do "run -all; quit -f"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/B066/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/B066/transcript; then exit 1; fi

run_B067: comp_uvm
	mkdir -p $(SIM_ROOT)/B067
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_b067_test +ARB_SEED=$(SEED) +TB_INT_EXPECTED_HITS=100 +TB_INT_SIM_DIR=$(SIM_ROOT)/B067 -l $(SIM_ROOT)/B067/transcript -do "run -all; quit -f"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/B067/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/B067/transcript; then exit 1; fi

run_B068: comp_uvm
	mkdir -p $(SIM_ROOT)/B068
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_b068_test +ARB_SEED=$(SEED) +TB_INT_EXPECTED_HITS=1024 +TB_INT_SIM_DIR=$(SIM_ROOT)/B068 -l $(SIM_ROOT)/B068/transcript -do "run -all; quit -f"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/B068/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/B068/transcript; then exit 1; fi

run_B069: comp_uvm
	mkdir -p $(SIM_ROOT)/B069
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_b069_test +ARB_SEED=$(SEED) +TB_INT_EXPECTED_HITS=1 +TB_INT_SIM_DIR=$(SIM_ROOT)/B069 -l $(SIM_ROOT)/B069/transcript -do "run -all; quit -f"
	rg "\\*\\*\\* TEST PASSED \\*\\*\\*" $(SIM_ROOT)/B069/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/B069/transcript; then exit 1; fi

run_b065: run_B065
run_b066: run_B066
run_b067: run_B067
run_b068: run_B068
run_b069: run_B069

regress_basic: run_B065 run_B066 run_B067 run_B068 run_B069

all_buckets_frame:
	@echo "all_buckets_frame: hook present; full continuous-frame run waits for the complete bucket implementation."

static_screen:
	python3 ~/.codex/skills/rtl-linter-and-checker/scripts/questa_static_screen.py --top tb_int_top --filelist script/tb_int.f --modes lint,cdc,rdc uvm/v3_pretest-260511/*.sv

clean:
	@echo "clean: non-destructive by policy. Remove work/ and sim/ manually if a clean tree is required."

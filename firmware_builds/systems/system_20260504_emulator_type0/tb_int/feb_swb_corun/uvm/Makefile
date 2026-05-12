QUESTA_HOME ?= /data1/questaone_sim-2026.1_1/questasim
ETH_LIC_SERVER ?= 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE := $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE := $(LM_LICENSE_FILE)
export SALT_LICENSE_SERVER := $(LM_LICENSE_FILE)

VLIB ?= $(QUESTA_HOME)/linux_x86_64/vlib
VMAP ?= $(QUESTA_HOME)/linux_x86_64/vmap
VLOG ?= $(QUESTA_HOME)/linux_x86_64/vlog
VSIM ?= $(QUESTA_HOME)/linux_x86_64/vsim

WORK ?= work_feb_swb_uvm
PHASE45_WORK ?= work_phase45_fail_modes
MODELSIM_INI ?= questa.ini
UVM_HOME ?= $(QUESTA_HOME)/verilog_src/uvm-1.2
UVM_SRC := $(UVM_HOME)/src/uvm_pkg.sv
UVM_INCDIR := +incdir+$(UVM_HOME)/src
INI_OPT := -ini $(MODELSIM_INI)
VLOG_OPTS := -sv -work $(WORK) -timescale 1ns/1ps +define+UVM_NO_DPI
PHASE45_VLOG_OPTS := -sv -work $(PHASE45_WORK) -timescale 1ns/1ps
PHASE45_TB_VLOG_OPTS := $(PHASE45_VLOG_OPTS) -mfcu
VSIM_OPTS := $(INI_OPT) -c -suppress 19 -suppress 3009 -nodpiexports -work $(WORK)
PHASE45_VSIM_OPTS := $(INI_OPT) -c -suppress 19 -suppress 3009 -work $(PHASE45_WORK)
REPO_ROOT := $(abspath ../../../../../..)
P45_REPORT_ROOT ?= ../REPORT
P45_LOG_ROOT ?= ../REPORT

SV_SOURCES := \
	feb_swb_corun_if.sv \
	feb_swb_corun_uvm_pkg.sv \
	tb_top.sv

PHASE45_EMULATOR_SOURCES := \
	$(REPO_ROOT)/emulator_mutrig/rtl/common/frontend_ticket_bus_pkg.sv \
	$(REPO_ROOT)/emulator_mutrig/rtl/backend_mutrig/be_mutrig_pkg.sv \
	$(REPO_ROOT)/emulator_mutrig/rtl/common/prbs15_lfsr.sv \
	$(REPO_ROOT)/emulator_mutrig/rtl/common/crc16_8.sv \
	$(REPO_ROOT)/emulator_mutrig/rtl/frontend/frontend_csr.sv \
	$(REPO_ROOT)/emulator_mutrig/rtl/frontend/frontend_run_ctl.sv \
	$(REPO_ROOT)/emulator_mutrig/rtl/frontend/frontend_trigger_engine.sv \
	$(REPO_ROOT)/emulator_mutrig/rtl/frontend/frontend_bkg_generator.sv \
	$(REPO_ROOT)/emulator_mutrig/rtl/frontend/frontend_ticket_distributor.sv \
	$(REPO_ROOT)/emulator_mutrig/rtl/backend_mutrig/be_mutrig_l2_fifo.sv \
	$(REPO_ROOT)/emulator_mutrig/rtl/backend_mutrig/be_mutrig_lane_emitter.sv \
	$(REPO_ROOT)/emulator_mutrig/rtl/backend_mutrig/be_mutrig_lane_type0_emit.sv \
	$(REPO_ROOT)/emulator_mutrig/rtl/backend_mutrig/be_mutrig_frame_assembler.sv \
	$(REPO_ROOT)/emulator_mutrig/rtl/emulator_mutrig.sv \
	$(REPO_ROOT)/emulator_mutrig/rtl/emulator_mutrig_qsys_lane.sv

PHASE45_ARB_SOURCES := \
	$(REPO_ROOT)/misc/arb_hit_type0/rtl/arb_hit_type0_fifo.sv \
	$(REPO_ROOT)/misc/arb_hit_type0/rtl/arb_hit_type0_arbiter.sv \
	$(REPO_ROOT)/misc/arb_hit_type0/rtl/arb_hit_type0_watchdog.sv \
	$(REPO_ROOT)/misc/arb_hit_type0/rtl/arb_hit_type0_runctl.sv \
	$(REPO_ROOT)/misc/arb_hit_type0/rtl/arb_hit_type0_csr.sv \
	$(REPO_ROOT)/misc/arb_hit_type0/rtl/arb_hit_type0.sv

PHASE45_TB_SOURCES := \
	phase4_5_fail_mode_if.sv \
	sequences/lane_admit_asymmetry_seq.sv \
	sequences/mode_dispatch_seq.sv \
	phase4_5_fail_mode_tb.sv

.PHONY: compile smoke comp_phase45_fail_modes run_LANE_ASYM run_MODE_DISPATCH clean

compile:
	test -f $(MODELSIM_INI) || $(VMAP) -c
	mkdir -p $(WORK)
	test -f $(WORK)/_info || $(VLIB) $(WORK)
	$(VMAP) $(INI_OPT) work $(WORK)
	$(VLOG) $(INI_OPT) $(VLOG_OPTS) $(UVM_INCDIR) $(UVM_SRC)
	$(VLOG) $(INI_OPT) $(VLOG_OPTS) $(UVM_INCDIR) $(SV_SOURCES)

smoke: compile
	$(VSIM) $(VSIM_OPTS) tb_top \
	    +UVM_TESTNAME=feb_swb_corun_base_test \
	    +FEB_SWB_SELF_SMOKE \
	    -do "run -all; quit -f"

comp_phase45_fail_modes:
	test -f $(MODELSIM_INI) || $(VMAP) -c
	mkdir -p $(PHASE45_WORK) $(P45_REPORT_ROOT)/lane_admit_asymmetry $(P45_REPORT_ROOT)/mode_dispatch
	test -f $(PHASE45_WORK)/_info || $(VLIB) $(PHASE45_WORK)
	$(VMAP) $(INI_OPT) phase45_work $(PHASE45_WORK)
	$(VLOG) $(INI_OPT) $(PHASE45_VLOG_OPTS) $(PHASE45_EMULATOR_SOURCES)
	$(VLOG) $(INI_OPT) $(PHASE45_VLOG_OPTS) $(PHASE45_ARB_SOURCES)
	$(VLOG) $(INI_OPT) $(PHASE45_TB_VLOG_OPTS) $(PHASE45_TB_SOURCES)

run_LANE_ASYM: comp_phase45_fail_modes
	mkdir -p $(P45_REPORT_ROOT)/lane_admit_asymmetry
	$(VSIM) $(PHASE45_VSIM_OPTS) phase4_5_fail_mode_tb \
	    +P45_TEST=lane \
	    +P45_REPORT_ROOT=$(P45_REPORT_ROOT) \
	    -l $(P45_LOG_ROOT)/lane_admit_asymmetry/transcript.log \
	    -do "run -all; quit -f"
	rg "P45_LANE_ASYM_PASS" $(P45_LOG_ROOT)/lane_admit_asymmetry/transcript.log
	@if rg "P45_LANE_ASYM_FAIL|Fatal:|Error:" $(P45_LOG_ROOT)/lane_admit_asymmetry/transcript.log; then exit 1; fi

run_MODE_DISPATCH: comp_phase45_fail_modes
	mkdir -p $(P45_REPORT_ROOT)/mode_dispatch
	$(VSIM) $(PHASE45_VSIM_OPTS) phase4_5_fail_mode_tb \
	    +P45_TEST=mode \
	    +P45_REPORT_ROOT=$(P45_REPORT_ROOT) \
	    -l $(P45_LOG_ROOT)/mode_dispatch/transcript.log \
	    -do "run -all; quit -f"
	rg "P45_MODE_DISPATCH_PASS" $(P45_LOG_ROOT)/mode_dispatch/transcript.log
	@if rg "P45_MODE_DISPATCH_FAIL|Fatal:|Error:" $(P45_LOG_ROOT)/mode_dispatch/transcript.log; then exit 1; fi

clean:
	@echo "clean: non-destructive by policy. Move or archive work dirs manually if a clean tree is required."

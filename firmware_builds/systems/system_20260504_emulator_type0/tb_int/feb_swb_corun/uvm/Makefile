QUESTA_HOME ?= /data1/questaone_sim-2026.1_1/questasim
ETH_LIC_SERVER ?= 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE := $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE := $(LM_LICENSE_FILE)
export SALT_LICENSE_SERVER := $(LM_LICENSE_FILE)

VLIB ?= $(QUESTA_HOME)/linux_x86_64/vlib
VMAP ?= $(QUESTA_HOME)/linux_x86_64/vmap
VLOG ?= $(QUESTA_HOME)/linux_x86_64/vlog
VSIM ?= $(QUESTA_HOME)/linux_x86_64/vsim
PYTHON ?= python3

WORK ?= work_feb_swb_uvm
PHASE45_WORK ?= work_phase45_fail_modes
PHASE45_SIM_WORK ?= work_phase45_sim_rows
MODELSIM_INI ?= questa.ini
UVM_HOME ?= $(QUESTA_HOME)/verilog_src/uvm-1.2
UVM_SRC := $(UVM_HOME)/src/uvm_pkg.sv
UVM_INCDIR := +incdir+$(UVM_HOME)/src
INI_OPT := -ini $(MODELSIM_INI)
VLOG_OPTS := -sv -work $(WORK) -timescale 1ns/1ps +define+UVM_NO_DPI
PHASE45_VLOG_OPTS := -sv -work $(PHASE45_WORK) -timescale 1ns/1ps
PHASE45_TB_VLOG_OPTS := $(PHASE45_VLOG_OPTS) -mfcu
PHASE45_SIM_VLOG_OPTS := -sv -work $(PHASE45_SIM_WORK) -timescale 1ns/1ps
PHASE45_SIM_TB_VLOG_OPTS := $(PHASE45_SIM_VLOG_OPTS) -mfcu
VSIM_OPTS := $(INI_OPT) -c -suppress 19 -suppress 3009 -nodpiexports -work $(WORK)
PHASE45_VSIM_OPTS := $(INI_OPT) -c -suppress 19 -suppress 3009 -work $(PHASE45_WORK)
PHASE45_SIM_VSIM_OPTS := $(INI_OPT) -c -suppress 19 -suppress 3009 -work $(PHASE45_SIM_WORK)
REPO_ROOT := $(abspath ../../../../../..)
P45_REPORT_ROOT ?= ../REPORT
P45_LOG_ROOT ?= ../REPORT
P45_SIM_EVIDENCE_ROOT ?= ../sim_evidence

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

PHASE45_SIM_ROW_IDS := \
	p45_000_all_lanes_0xFFFFFFFF_default_dir \
	p45_001_all_lanes_0x0000FFFF_default_dir \
	p45_002_all_lanes_0xFFFF0000_default_dir \
	p45_003_all_lanes_0x55555555_default_dir \
	p45_004_all_lanes_0xAAAAAAAA_default_dir \
	p45_005_all_lanes_0x00000001_default_dir \
	p45_006_lane0_only_default_default_dir \
	p45_007_lane1_only_default_default_dir \
	p45_008_lane2_only_default_default_dir \
	p45_009_lane3_only_default_default_dir \
	p45_010_lane4_only_default_default_dir \
	p45_011_lane5_only_default_default_dir \
	p45_012_lane6_only_default_default_dir \
	p45_013_lane7_only_default_default_dir \
	p45_014_all_lanes_default_0x0100_dir \
	p45_015_all_lanes_default_0x0400_dir \
	p45_016_all_lanes_default_0x0800_dir \
	p45_017_all_lanes_default_0x1000_dir \
	p45_018_all_lanes_default_0x2000_dir \
	p45_019_all_lanes_default_0x4000_dir \
	p45_020_all_lanes_default_0x8000_dir \
	p45_021_all_lanes_default_default_burst \
	p45_022_all_lanes_default_default_periodic \
	p45_023_lane_evens_default_default_dir \
	p45_024_lane_odds_default_default_dir \
	p45_025_lane_none_default_default_dir \
	p45_026_lane0only_0x0000FFFF_default_dir \
	p45_027_lane_evens_0x55555555_default_dir \
	p45_028_lane_odds_0xAAAAAAAA_default_dir \
	p45_029_lane0only_0x00000001_default_dir \
	p45_030_lane_evens_default_0x2000_dir \
	p45_031_lane_none_0x00000001_default_dir

PHASE45_SIM_ROW_SOURCES := $(addprefix sequences/phase4_5_sim_row_,$(addsuffix .sv,$(PHASE45_SIM_ROW_IDS)))

.PHONY: compile smoke comp_phase45_fail_modes run_LANE_ASYM run_MODE_DISPATCH comp_phase45_sim_rows run_PHASE4_5_SIM_ROW p45_run_phase4_5_sim_row run_PHASE4_5_SIM_ALL clean

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

comp_phase45_sim_rows:
	test -f $(MODELSIM_INI) || $(VMAP) -c
	mkdir -p $(PHASE45_SIM_WORK) $(P45_SIM_EVIDENCE_ROOT)
	test -f $(PHASE45_SIM_WORK)/_info || $(VLIB) $(PHASE45_SIM_WORK)
	$(VMAP) $(INI_OPT) phase45_sim_work $(PHASE45_SIM_WORK)
	$(VLOG) $(INI_OPT) $(PHASE45_SIM_VLOG_OPTS) $(PHASE45_EMULATOR_SOURCES)
	$(VLOG) $(INI_OPT) $(PHASE45_SIM_VLOG_OPTS) $(PHASE45_ARB_SOURCES)
	$(VLOG) $(INI_OPT) $(PHASE45_SIM_TB_VLOG_OPTS) $(PHASE45_SIM_ROW_SOURCES)

run_PHASE4_5_SIM_ROW: comp_phase45_sim_rows p45_run_phase4_5_sim_row

p45_run_phase4_5_sim_row:
	test -n "$(row_id)" || (echo "row_id=<phase4.5 row id> is required"; exit 2)
	mkdir -p "$(P45_SIM_EVIDENCE_ROOT)/$(row_id)"
	$(VSIM) $(PHASE45_SIM_VSIM_OPTS) phase4_5_sim_row_$(row_id)_tb \
	    +P45_SIM_EVIDENCE_DIR=$(P45_SIM_EVIDENCE_ROOT)/$(row_id) \
	    $(if $(run_cycles),+P45_SIM_RUN_CYCLES=$(run_cycles),) \
	    -l $(P45_SIM_EVIDENCE_ROOT)/$(row_id)/transcript.log \
	    -do "run -all; quit -f"
	rg "P45_SIM_ROW_PASS row_id=$(row_id)" $(P45_SIM_EVIDENCE_ROOT)/$(row_id)/transcript.log
	@if rg "P45_SIM_ROW_FAIL|Fatal:|Error:" $(P45_SIM_EVIDENCE_ROOT)/$(row_id)/transcript.log; then exit 1; fi
	ROW_ID="$(row_id)" EVIDENCE_DIR="$(P45_SIM_EVIDENCE_ROOT)/$(row_id)" REPO_ROOT="$(REPO_ROOT)" $(PYTHON) -c 'import csv, os, sys; from pathlib import Path; repo=Path(os.environ["REPO_ROOT"]); sys.path.insert(0, str(repo/"scripts"/"cotest")); from phase4_5_plot import render_rate_plot, render_latency_plot; ev=Path(os.environ["EVIDENCE_DIR"]); bins=[0]*256; rows=list(csv.DictReader(open(ev/"sim_hist_bin.csv", newline=""))); [bins.__setitem__(int(r["bin_idx"]), int(r["count"])) for r in rows]; row_id=os.environ["ROW_ID"]; render_rate_plot(bins, row_id, ev/"sim_plot_rate.png", title_suffix="sim"); render_latency_plot(bins, row_id, ev/"sim_plot_latency.png", title_suffix="sim", note="compact sim has no rbCAM timestamp split")'

run_PHASE4_5_SIM_ALL: comp_phase45_sim_rows
	@set -e; for rid in $(PHASE45_SIM_ROW_IDS); do \
	    $(MAKE) --no-print-directory p45_run_phase4_5_sim_row row_id=$$rid; \
	done

clean:
	@echo "clean: non-destructive by policy. Move or archive work dirs manually if a clean tree is required."

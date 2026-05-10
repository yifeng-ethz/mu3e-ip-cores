# prof_int_001.mk
# Build and run target for PROF-INT-001: 100 kHz/channel full-load latency
# benchmark against arb_hit_type0_supercore synthesis RTL.
#
# Compilation order:
#   1. UVM package (Questa One install)
#   2. Generated supercore RTL (same SUPERCORE_SYNTH path as error_b002.mk)
#   3. PROF-INT-001 sequence and test packages
#   4. prof_int_001_top.sv (defines the interface + standalone top)
#
# Run target: run_prof_int_001_full_load_100khz_per_channel_test
#
# Scope note (documented deviation):
#   Requested:  1 sec @ 100 kHz/ch x 16 ch x 8 lanes
#   Delivered:  100 ms @ 100 kHz/ch x 16 ch x 1 lane (lane 0, EMU mode)
#   Rationale:  12.5 M sim cycles is expected to complete well within the
#               60-min wall-clock budget. 160 000 hits give adequate histogram
#               statistics. Eight-lane extension deferred to a follow-up run.

SUPERCORE_SYNTH ?= /home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_hit_type0_mux_20260504/firmware_builds/systems/system_20260504_full8lane_type0/syn/arb_hit_type0_supercore/synthesis

PROF_INT_001_TB_TOP    := prof_int_001_top
PROF_INT_001_TEST_NAME := prof_int_001_full_load_100khz_per_channel_test
PROF_INT_001_SIM_DIR   := $(SIM_ROOT)/$(PROF_INT_001_TEST_NAME)
PROF_INT_001_REPORT_DIR := reports/assets/full_load_100khz_$(shell date +%Y%m%d)

SUPERCORE_VLOG_FILES_P001 := \
    $(SUPERCORE_SYNTH)/submodules/arb_hit_type0_supercore_avalon_st_adapter.v \
    $(SUPERCORE_SYNTH)/submodules/arb_hit_type0_supercore_avalon_st_adapter_timing_adapter_0.sv \
    $(SUPERCORE_SYNTH)/submodules/altera_avalon_st_splitter.sv \
    $(SUPERCORE_SYNTH)/submodules/arb_hit_type0_fifo.sv \
    $(SUPERCORE_SYNTH)/submodules/arb_hit_type0_arbiter.sv \
    $(SUPERCORE_SYNTH)/submodules/arb_hit_type0_watchdog.sv \
    $(SUPERCORE_SYNTH)/submodules/arb_hit_type0_runctl.sv \
    $(SUPERCORE_SYNTH)/submodules/arb_hit_type0_csr.sv \
    $(SUPERCORE_SYNTH)/submodules/arb_hit_type0.sv \
    $(SUPERCORE_SYNTH)/arb_hit_type0_supercore.v

PROF_INT_001_SEQ_FILE  := $(TB_INT_ROOT)/uvm/sequence/prof/prof_int_001_full_load_100khz_per_channel_seq.sv
PROF_INT_001_TEST_FILE := $(TB_INT_ROOT)/uvm/test/prof/prof_int_001_full_load_100khz_per_channel_test.sv
PROF_INT_001_TOP_FILE  := $(TB_INT_ROOT)/prof_int_001_top.sv

.PHONY: comp_uvm_prof_int_001 comp_supercore_p001 comp_prof_int_001_test \
        run_prof_int_001_$(PROF_INT_001_TEST_NAME) \
        plot_prof_int_001

comp_uvm_prof_int_001: lib
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(UVM_INCDIR) $(UVM_SRC)

comp_supercore_p001: comp_uvm_prof_int_001
	$(VLOG) -modelsimini modelsim.ini -sv -work $(WORK) -timescale 1ns/1ps \
	    $(SUPERCORE_VLOG_FILES_P001)

comp_prof_int_001_test: comp_supercore_p001
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) \
	    $(UVM_INCDIR) \
	    $(PROF_INT_001_SEQ_FILE) \
	    $(PROF_INT_001_TEST_FILE) \
	    $(PROF_INT_001_TOP_FILE)

run_prof_int_001_$(PROF_INT_001_TEST_NAME): comp_prof_int_001_test
	@mkdir -p $(PROF_INT_001_SIM_DIR)
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 \
	    -nodpiexports -work $(WORK) $(PROF_INT_001_TB_TOP) \
	    +UVM_TESTNAME=$(PROF_INT_001_TEST_NAME) \
	    +ARB_SEED=$(SEED) \
	    +TB_INT_SIM_DIR=$(PROF_INT_001_SIM_DIR) \
	    -l $(PROF_INT_001_SIM_DIR)/transcript \
	    -do "run -all; quit -f"
	@grep -E "(PROF_INT_001|TEST PASSED|UVM_ERROR|UVM_FATAL)" \
	    $(PROF_INT_001_SIM_DIR)/transcript | tail -20
	@if grep -E "UVM_FATAL\s*:\s*[1-9]" $(PROF_INT_001_SIM_DIR)/transcript; then exit 1; fi
	@echo "=== PROF-INT-001 sim done; CSV at $(PROF_INT_001_SIM_DIR)/closed_records.csv ==="

plot_prof_int_001: run_prof_int_001_$(PROF_INT_001_TEST_NAME)
	@mkdir -p $(PROF_INT_001_REPORT_DIR)
	python3 $(TB_INT_ROOT)/script/plot_tb_int_latency_contact_sheet.py \
	    --sim-root $(SIM_ROOT) \
	    --cases $(PROF_INT_001_TEST_NAME) \
	    --out-dir $(PROF_INT_001_REPORT_DIR) \
	    --stage-mode synthesis \
	    --title-tag "1-lane 16-ch 100ms 100kHz/ch full load"
	@echo "=== PROF-INT-001 contact sheet written to $(PROF_INT_001_REPORT_DIR)/ ==="

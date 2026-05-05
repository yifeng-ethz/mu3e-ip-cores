# error_b002.mk
# Filelist and Make targets for B002 integration repro bucket.
# Included by tb_int/Makefile when building the error_b002 case.
#
# Compilation order:
#   1. UVM package (from Questa One install — done by comp_uvm_b002)
#   2. Generated supercore RTL (Verilog + SV submodules)
#   3. B002 sequence and test packages (SV)
#   4. Top module (error_int_b002_top.sv — defines the interface and module)
#
# Run target: run_b002_error_int_b002_supercore_runctl_propagation_test

SUPERCORE_SYNTH := /home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_hit_type0_mux_20260504/firmware_builds/systems/system_20260504_full8lane_type0/syn/arb_hit_type0_supercore/synthesis

B002_TB_TOP    := error_int_b002_top
B002_TEST_NAME := error_int_b002_supercore_runctl_propagation_test
B002_SIM_DIR   := $(SIM_ROOT)/b002_$(B002_TEST_NAME)

# -----------------------------------------------------------------------
# Supercore RTL filelist (order matches qip: top wrapper first, then subs)
# -----------------------------------------------------------------------
SUPERCORE_VLOG_FILES := \
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

# B002 test source files
B002_SEQ_FILE  := $(TB_INT_ROOT)/uvm/sequence/error/error_int_b002_supercore_runctl_propagation_seq.sv
B002_TEST_FILE := $(TB_INT_ROOT)/uvm/test/error/error_int_b002_supercore_runctl_propagation_test.sv
B002_TOP_FILE  := $(TB_INT_ROOT)/error_int_b002_top.sv

.PHONY: comp_uvm_b002 comp_supercore comp_b002_test run_b002_$(B002_TEST_NAME)

comp_uvm_b002: lib
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(UVM_INCDIR) $(UVM_SRC)

comp_supercore: comp_uvm_b002
	$(VLOG) -modelsimini modelsim.ini -sv -work $(WORK) -timescale 1ns/1ps \
	    $(SUPERCORE_VLOG_FILES)

comp_b002_test: comp_supercore
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) \
	    $(UVM_INCDIR) \
	    $(B002_SEQ_FILE) \
	    $(B002_TEST_FILE) \
	    $(B002_TOP_FILE)

run_b002_$(B002_TEST_NAME): comp_b002_test
	@mkdir -p $(B002_SIM_DIR)
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 \
	    -nodpiexports -work $(WORK) $(B002_TB_TOP) \
	    +UVM_TESTNAME=$(B002_TEST_NAME) \
	    +ARB_SEED=$(SEED) \
	    -l $(B002_SIM_DIR)/transcript \
	    -do "run -all; quit -f"
	@grep -E "(REPRO_HIT_INTEGRATION|NO_REPRO_INTEGRATION|UVM_ERROR|UVM_FATAL|TEST)" \
	    $(B002_SIM_DIR)/transcript | tail -40
	@if grep -E "UVM_FATAL\s*:\s*[1-9]" $(B002_SIM_DIR)/transcript; then exit 1; fi
	@echo "=== B002 run complete — check transcript for REPRO_HIT_INTEGRATION / NO_REPRO_INTEGRATION ==="

QUESTA_HOME     ?= /data1/questaone_sim-2026.1_1/questasim
ETH_LIC_SERVER  := 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE     := $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE   := $(LM_LICENSE_FILE)
export SALT_LICENSE_SERVER := $(LM_LICENSE_FILE)
export QSIM_INI            := modelsim.ini

VLOG := $(QUESTA_HOME)/linux_x86_64/vlog
VCOM := $(QUESTA_HOME)/linux_x86_64/vcom
VSIM := $(QUESTA_HOME)/linux_x86_64/vsim
VLIB := $(QUESTA_HOME)/linux_x86_64/vlib
VMAP := $(QUESTA_HOME)/linux_x86_64/vmap

WORK      ?= work_tb_int
TB_TOP    := tb_int_top
SEED      ?= 1
SIM_ROOT  ?= sim
TB_INT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SMOKE_DIR := $(SIM_ROOT)/tb_int_smoke_test
UVM_SRC   := $(QUESTA_HOME)/verilog_src/uvm-1.2/src/uvm_pkg.sv
UVM_INCDIR := +incdir+$(QUESTA_HOME)/verilog_src/uvm-1.2/src
VLOG_OPTS := -sv -work $(WORK) -timescale 1ps/1ps +define+UVM_NO_DPI +define+TB_INT_SIM

.PHONY: lib comp_uvm comp_dut run_tb_int_smoke_test regress_basic regress_edge regress_prof regress_error all_buckets_frame static_screen clean

lib:
	@mkdir -p $(WORK) $(SIM_ROOT)
	$(VLIB) $(WORK)
	$(VMAP) -modelsimini modelsim.ini work $(WORK)

comp_uvm: lib
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(UVM_INCDIR) $(UVM_SRC)
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) -f script/tb_int.f

comp_dut: comp_uvm
	@echo "comp_dut: focus-build DUT hook is compiled in tb_int_top; full Qsys sim source promotion is deferred."

run_tb_int_smoke_test: comp_uvm comp_dut
	@mkdir -p $(SMOKE_DIR)
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -nodpiexports -work $(WORK) $(TB_TOP) \
	    +UVM_TESTNAME=tb_int_smoke_test \
	    +ARB_SEED=$(SEED) \
	    +TB_INT_EXPECTED_HITS=16 \
	    +TB_INT_SIM_DIR=$(SMOKE_DIR) \
	    -l $(SMOKE_DIR)/transcript \
	    -do "run -all; quit -f"
	@grep -q "\*\*\* TEST PASSED \*\*\*" $(SMOKE_DIR)/transcript
	@if grep -E "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SMOKE_DIR)/transcript; then exit 1; fi

regress_basic: comp_uvm comp_dut
	@echo "regress_basic: no directed bucket cases implemented yet."

regress_edge: comp_uvm comp_dut
	@echo "regress_edge: no directed bucket cases implemented yet."

regress_prof: comp_uvm comp_dut
	@echo "regress_prof: no directed bucket cases implemented yet."

regress_error: comp_uvm comp_dut
	@echo "regress_error: no directed bucket cases implemented yet."

all_buckets_frame: comp_uvm comp_dut
	@echo "all_buckets_frame: continuous no-restart hook present; no directed cases implemented yet."

static_screen:
	python3 ~/.codex/skills/rtl-writing/scripts/rtl_style_check.py uvm/**/*.sv
	python3 ~/.codex/skills/rtl-linter-and-checker/scripts/questa_static_screen.py --top tb_int_top --filelist script/tb_int.f --modes lint,cdc,rdc uvm/**/*.sv

clean:
	@echo "clean: non-destructive by policy. Remove work/ and sim/ manually if a clean tree is required."

# ---------------------------------------------------------------------------
# B002 integration repro bucket (error bucket — add run target only; existing
# smoke / regress targets are not modified)
# ---------------------------------------------------------------------------
include script/buckets/error_b002.mk

# ---------------------------------------------------------------------------
# PROF-INT-001 full-load latency benchmark (standalone top, not tb_int_top)
# ---------------------------------------------------------------------------
include script/buckets/prof_int_001.mk

# ---------------------------------------------------------------------------
# PROF-INT-002 full-pipeline real-RTL latency benchmark
# ---------------------------------------------------------------------------
include script/buckets/prof_int_002.mk

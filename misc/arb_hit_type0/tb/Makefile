SHELL := /bin/bash

QUESTA_HOME     ?= /data1/questaone_sim-2026.1_1/questasim
ETH_LIC_SERVER  := 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE     := $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE   := $(LM_LICENSE_FILE)
export SALT_LICENSE_SERVER := $(LM_LICENSE_FILE)
export QSIM_INI            := $(QUESTA_HOME)/modelsim.ini

VLIB   := $(QUESTA_HOME)/linux_x86_64/vlib
VMAP   := $(QUESTA_HOME)/linux_x86_64/vmap
VLOG   := $(QUESTA_HOME)/linux_x86_64/vlog
VSIM   := $(QUESTA_HOME)/linux_x86_64/vsim
VCOVER := $(QUESTA_HOME)/linux_x86_64/vcover

IP_ROOT      := $(abspath ..)
TB_ROOT      := $(abspath .)
UVM_DIR      := $(TB_ROOT)/uvm
SIM_DIR      := $(TB_ROOT)/sim
WORK_LIB     := $(SIM_DIR)/work
MODELSIM_INI := $(SIM_DIR)/modelsim.ini
HW_TCL       := $(IP_ROOT)/script/arb_hit_type0_hw.tcl
STATIC_FILELIST := $(SIM_DIR)/arb_hit_type0_static.f
STATIC_PRE_DO   := $(SIM_DIR)/questa_static_pre.do

UVM_HOME     ?= $(QUESTA_HOME)/verilog_src/uvm-1.2
UVM_SRC      := $(UVM_HOME)/src
UVM_PKG      := $(UVM_SRC)/uvm_pkg.sv
UVM_DPI_LIB  := $(QUESTA_HOME)/uvm-1.2/linux_x86_64/uvm_dpi
DPI_CPP      ?= /usr/bin/gcc

SEED         ?= 1
PLUSARGS     ?=
TB_TOP       := tb_top

DUT_SRCS := $(shell awk '/add_fileset_file/ { for (idx = 1; idx < NF; idx++) if ($$idx == "PATH") print "$(IP_ROOT)/"$$(idx + 1) }' $(HW_TCL) | awk '!seen[$$0]++')
TB_SRCS  := $(shell find $(UVM_DIR) -name '*.sv' -print | sort)

LIB_STAMP := $(SIM_DIR)/.lib.stamp
UVM_STAMP := $(SIM_DIR)/.uvm.stamp
DUT_STAMP := $(SIM_DIR)/.dut.stamp

BASIC_TESTS ?=
EDGE_TESTS  ?=
PROF_TESTS  ?=
ERROR_TESTS ?=
CROSS_TESTS ?=

# Per-bucket test lists are appended by fragments under script/buckets/<bucket>.mk
# (one fragment per parallel codex2 session; each is `<BUCKET>_TESTS += ...`).
-include $(IP_ROOT)/script/buckets/*.mk

.PHONY: lib comp_uvm comp_dut static_screen run_% regress_basic regress_edge regress_prof regress_error regress_cross all_buckets_frame clean

lib: $(LIB_STAMP)

$(LIB_STAMP):
	@mkdir -p $(SIM_DIR)
	@if [ ! -f "$(MODELSIM_INI)" ]; then cp "$(QSIM_INI)" "$(MODELSIM_INI)"; chmod u+w "$(MODELSIM_INI)"; fi
	@if [ ! -d "$(WORK_LIB)" ]; then $(VLIB) "$(WORK_LIB)" >/dev/null; fi
	@$(VMAP) -modelsimini "$(MODELSIM_INI)" work "$(WORK_LIB)" >/dev/null
	@touch "$@"

comp_uvm: $(UVM_STAMP)

$(UVM_STAMP): $(UVM_PKG) | $(LIB_STAMP)
	@echo "=== Compiling UVM 1.2 ==="
	@$(VLOG) -modelsimini "$(MODELSIM_INI)" -sv -work work +incdir+"$(UVM_SRC)" "$(UVM_PKG)"
	@touch "$@"

comp_dut: $(DUT_STAMP)

$(DUT_STAMP): $(DUT_SRCS) $(TB_SRCS) | $(UVM_STAMP)
	@echo "=== Compiling arb_hit_type0 DUT from $(HW_TCL) ==="
	@for src in $(DUT_SRCS); do \
	  echo "vlog $$src"; \
	  $(VLOG) -modelsimini "$(MODELSIM_INI)" -sv -work work "$$src" || exit $$?; \
	done
	@echo "=== Compiling arb_hit_type0 UVM scaffold ==="
	@$(VLOG) -modelsimini "$(MODELSIM_INI)" -sv -work work +incdir+"$(UVM_SRC)" +incdir+"$(UVM_DIR)" "$(UVM_DIR)/lcg_prng.sv"
	@$(VLOG) -modelsimini "$(MODELSIM_INI)" -sv -work work +incdir+"$(UVM_SRC)" +incdir+"$(UVM_DIR)" "$(UVM_DIR)/reg_pkg.sv"
	@$(VLOG) -modelsimini "$(MODELSIM_INI)" -sv -work work +incdir+"$(UVM_SRC)" +incdir+"$(UVM_DIR)" "$(UVM_DIR)/arb_hit_type0_pkg.sv"
	@$(VLOG) -modelsimini "$(MODELSIM_INI)" -sv -mfcu -cuname arb_hit_type0_assertions_cu -work work "$(UVM_DIR)/arb_hit_type0_assertions.sv"
	@$(VLOG) -modelsimini "$(MODELSIM_INI)" -sv -work work +incdir+"$(UVM_SRC)" +incdir+"$(UVM_DIR)" "$(UVM_DIR)/tb_top.sv"
	@echo "=== Compiling per-bucket sequences (tb/uvm/sequence/*/*.sv) ==="
	@for src in $$(find $(UVM_DIR)/sequence -mindepth 2 -maxdepth 2 -name '*.sv' 2>/dev/null | sort); do \
	  echo "vlog $$src"; \
	  $(VLOG) -modelsimini "$(MODELSIM_INI)" -sv -work work +incdir+"$(UVM_SRC)" +incdir+"$(UVM_DIR)" "$$src" || exit $$?; \
	done
	@echo "=== Compiling per-bucket tests (tb/uvm/test/*/*.sv) ==="
	@for src in $$(find $(UVM_DIR)/test -mindepth 2 -maxdepth 2 -name '*.sv' 2>/dev/null | sort); do \
	  echo "vlog $$src"; \
	  $(VLOG) -modelsimini "$(MODELSIM_INI)" -sv -work work +incdir+"$(UVM_SRC)" +incdir+"$(UVM_DIR)" "$$src" || exit $$?; \
	done
	@touch "$@"

run_%: comp_dut
	@echo "=== Running UVM_TESTNAME=$* SEED=$(SEED) ==="
	@set -o pipefail; cd "$(SIM_DIR)" && \
	  "$(VSIM)" -modelsimini "$(MODELSIM_INI)" -c -work work -t ps \
	    -dpicpppath "$(DPI_CPP)" -sv_lib "$(UVM_DPI_LIB)" \
	    -suppress 19 -suppress 3009 \
	    -voptargs=+acc \
	    +UVM_TESTNAME=$* +ARB_SEED=$(SEED) $(PLUSARGS) \
	    "$(TB_TOP)" \
	    -do "quietly set NumericStdNoWarnings 1; quietly set StdArithNoWarnings 1; run -all; quit -f" \
	    | tee "$*.log"
	@if grep -qE '(^# )?UVM_(ERROR|FATAL) [^:]|\\*\\* (Fatal|Error):' "$(SIM_DIR)/$*.log"; then \
	  echo "FAIL: $*"; exit 1; \
	elif ! grep -q '\*\*\* TEST PASSED \*\*\*' "$(SIM_DIR)/$*.log"; then \
	  echo "FAIL: $* did not report TEST PASSED"; exit 1; \
	else \
	  echo "PASS: $*"; \
	fi

regress_basic: comp_dut
	@tests="$(BASIC_TESTS)"; if [ -z "$$tests" ]; then echo "No BASIC_TESTS defined yet"; else for test in $$tests; do $(MAKE) run_$$test SEED=$(SEED); done; fi

regress_edge: comp_dut
	@tests="$(EDGE_TESTS)"; if [ -z "$$tests" ]; then echo "No EDGE_TESTS defined yet"; else for test in $$tests; do $(MAKE) run_$$test SEED=$(SEED); done; fi

regress_prof: comp_dut
	@tests="$(PROF_TESTS)"; if [ -z "$$tests" ]; then echo "No PROF_TESTS defined yet"; else for test in $$tests; do $(MAKE) run_$$test SEED=$(SEED); done; fi

regress_error: comp_dut
	@tests="$(ERROR_TESTS)"; if [ -z "$$tests" ]; then echo "No ERROR_TESTS defined yet"; else for test in $$tests; do $(MAKE) run_$$test SEED=$(SEED); done; fi

regress_cross: comp_dut
	@tests="$(CROSS_TESTS)"; if [ -z "$$tests" ]; then echo "No CROSS_TESTS defined yet"; else for test in $$tests; do $(MAKE) run_$$test SEED=$(SEED); done; fi

all_buckets_frame: comp_dut
	@tests="$(BASIC_TESTS) $(EDGE_TESTS) $(PROF_TESTS) $(ERROR_TESTS) $(CROSS_TESTS)"; \
	if [ -z "$$(echo $$tests)" ]; then \
	  echo "No bucket-frame tests defined yet"; \
	else \
	  for test in $$tests; do $(MAKE) run_$$test SEED=$(SEED) PLUSARGS="$(PLUSARGS) +ARB_FRAME_MODE=all_buckets_frame"; done; \
	fi

$(STATIC_FILELIST): $(HW_TCL)
	@mkdir -p "$(SIM_DIR)"
	@awk '/add_fileset_file/ { for (idx = 1; idx < NF; idx++) if ($$idx == "PATH") print "$(IP_ROOT)/"$$(idx + 1) }' "$(HW_TCL)" | awk '!seen[$$0]++' > "$@"
	@printf '%s\n' "$(UVM_DIR)/arb_hit_type0_assertions.sv" >> "$@"

$(STATIC_PRE_DO):
	@mkdir -p "$(SIM_DIR)"
	@printf '%s\n' \
	  'vmap std /data3/siemens/questa_OneSpin_StaticFormal-2024.1_2/questa_static_formal/linux_x86_64/share/modeltech/std' \
	  'vmap sv_std /data3/siemens/questa_OneSpin_StaticFormal-2024.1_2/questa_static_formal/linux_x86_64/share/modeltech/sv_std' \
	  > "$@"

static_screen: $(STATIC_FILELIST) $(STATIC_PRE_DO)
	@python3 /home/yifeng/.codex/skills/rtl-linter-and-checker/scripts/questa_static_screen.py \
	  --top arb_hit_type0 \
	  --filelist "$(STATIC_FILELIST)" \
	  --pre-do "$(STATIC_PRE_DO)" \
	  $(DUT_SRCS) "$(UVM_DIR)/arb_hit_type0_assertions.sv"

clean:
	@python3 -c 'import os, shutil; p = os.path.abspath("sim"); shutil.rmtree(p) if os.path.isdir(p) else None'

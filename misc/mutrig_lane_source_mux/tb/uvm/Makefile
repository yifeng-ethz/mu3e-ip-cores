include ../../../../scripts/questa_one.mk

UVM_DIR     := $(abspath .)
IP_DIR      := $(abspath ../..)
LOG_DIR     := $(UVM_DIR)/logs
UVM_HOME    ?= $(QUESTA_UVM_HOME)
UVM_SRC     := $(UVM_HOME)/src
UVM_DPI_LIB := $(QUESTA_UVM_DPI_LIB)
DPI_CPP     ?= /usr/bin/gcc

REAL_ALWAYS_VALID ?= 1
FIFO_DEPTH        ?= 16
CASE_ID           ?= 32
TEST              ?= mlsm_directed_test
SEED              ?= 1
VERBOSITY         ?= UVM_MEDIUM
SOAK_ITERS        ?= 150000

COV_DIR     := $(UVM_DIR)/cov_rav$(REAL_ALWAYS_VALID)
WORK_DIR    := $(UVM_DIR)/work_rav$(REAL_ALWAYS_VALID)_fd$(FIFO_DEPTH)
TB_TOP := tb_top

RTL_SRC = $(IP_DIR)/rtl/mutrig_lane_source_mux.sv
TB_SRC  = \
	$(UVM_DIR)/mlsm_if.sv \
	$(UVM_DIR)/mlsm_env_pkg.sv \
	$(UVM_DIR)/tb_top.sv

.PHONY: license_check compile run run_case directed32_rav0 directed32_rav1 directed64 bucket_frame soak clean

license_check:
	@$(LMUTIL) lmstat -f mtiverification -c $(QUESTA_LICENSE_SERVER) >/dev/null 2>&1 || \
	  { echo "ERROR: mtiverification feature not visible via $(QUESTA_LICENSE_SERVER)"; exit 1; }

compile: license_check $(WORK_DIR)/.compiled

$(WORK_DIR)/.compiled: $(RTL_SRC) $(TB_SRC)
	@rm -rf $(WORK_DIR)
	@mkdir -p $(WORK_DIR) $(LOG_DIR) $(COV_DIR)
	@cp $(QSIM_INI) $(WORK_DIR)/modelsim.ini
	@chmod u+w $(WORK_DIR)/modelsim.ini
	@cd $(WORK_DIR) && $(VLIB) work
	@cd $(WORK_DIR) && $(VMAP) -modelsimini modelsim.ini work work > /dev/null
	@cd $(WORK_DIR) && $(VLOG) -modelsimini modelsim.ini -work work +cover=bcesft -sv $(UVM_DIR)/mlsm_if.sv
	@cd $(WORK_DIR) && $(VLOG) -modelsimini modelsim.ini -work work -mfcu +cover=bcesft \
	  +define+MLSM_REAL_ALWAYS_VALID=$(REAL_ALWAYS_VALID) \
	  +define+MLSM_FIFO_DEPTH=$(FIFO_DEPTH) \
	  +incdir+$(UVM_SRC) +incdir+$(UVM_DIR) -sv \
	  $(UVM_SRC)/uvm_pkg.sv \
	  $(RTL_SRC) \
	  $(UVM_DIR)/mlsm_env_pkg.sv \
	  $(UVM_DIR)/tb_top.sv
	@touch $@

run: compile
	@mkdir -p $(LOG_DIR) $(COV_DIR)
	@cd $(WORK_DIR) && $(VSIM) -modelsimini modelsim.ini -c -coverage \
	  -dpicpppath $(DPI_CPP) -sv_lib $(UVM_DPI_LIB) \
	  -sv_seed $(SEED) \
	  +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(VERBOSITY) \
	  +MLSM_CASE_ID=$(CASE_ID) +MLSM_SOAK_ITERS=$(SOAK_ITERS) +MLSM_SOAK_ID=$(SEED) \
	  -suppress 3009 -suppress 3473 -voptargs="+acc" \
	  work.$(TB_TOP) \
	  -do "coverage save -onexit $(COV_DIR)/$(TEST)_case$(CASE_ID)_s$(SEED).ucdb; run -all; quit -f" \
	  | tee $(LOG_DIR)/$(TEST)_rav$(REAL_ALWAYS_VALID)_case$(CASE_ID)_s$(SEED).log
	@if grep -qE '^# UVM_(FATAL|ERROR) .* @|^# \\*\\* Fatal:|^# \\*\\* Error:' $(LOG_DIR)/$(TEST)_rav$(REAL_ALWAYS_VALID)_case$(CASE_ID)_s$(SEED).log; then \
	  echo "FAIL: $(TEST) rav=$(REAL_ALWAYS_VALID) case=$(CASE_ID) seed=$(SEED)"; exit 1; \
	elif ! grep -q '\*\*\* TEST PASSED \*\*\*' $(LOG_DIR)/$(TEST)_rav$(REAL_ALWAYS_VALID)_case$(CASE_ID)_s$(SEED).log; then \
	  echo "FAIL: missing pass banner for $(TEST) rav=$(REAL_ALWAYS_VALID) case=$(CASE_ID) seed=$(SEED)"; exit 1; \
	else \
	  echo "PASS: $(TEST) rav=$(REAL_ALWAYS_VALID) case=$(CASE_ID) seed=$(SEED)"; \
	fi

run_case:
	@$(MAKE) -s run REAL_ALWAYS_VALID=$(REAL_ALWAYS_VALID) CASE_ID=$(CASE_ID) TEST=mlsm_directed_test SEED=$(SEED)

directed32_rav0:
	@set -e; for case_id in $$(seq 0 31); do \
	  $(MAKE) -s run_case REAL_ALWAYS_VALID=0 CASE_ID=$$case_id SEED=1; \
	done

directed32_rav1:
	@set -e; for case_id in $$(seq 32 63); do \
	  $(MAKE) -s run_case REAL_ALWAYS_VALID=1 CASE_ID=$$case_id SEED=1; \
	done

directed64: directed32_rav0 directed32_rav1

bucket_frame:
	@$(MAKE) -s run REAL_ALWAYS_VALID=0 CASE_ID=0 TEST=mlsm_bucket_frame_test SEED=11
	@$(MAKE) -s run REAL_ALWAYS_VALID=1 CASE_ID=32 TEST=mlsm_bucket_frame_test SEED=12

soak:
	@$(MAKE) -s run REAL_ALWAYS_VALID=0 CASE_ID=0 TEST=mlsm_soak_test SEED=101 SOAK_ITERS=$(SOAK_ITERS)
	@$(MAKE) -s run REAL_ALWAYS_VALID=1 CASE_ID=32 TEST=mlsm_soak_test SEED=102 SOAK_ITERS=$(SOAK_ITERS)
	@$(MAKE) -s run REAL_ALWAYS_VALID=1 CASE_ID=32 TEST=mlsm_soak_test SEED=103 SOAK_ITERS=$(SOAK_ITERS)

clean:
	rm -rf $(UVM_DIR)/work_* $(LOG_DIR) $(UVM_DIR)/cov_* transcript vsim.wlf

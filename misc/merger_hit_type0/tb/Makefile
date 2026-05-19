# Simplified directed Questa One sim for merger_hit_type0.
# Bypasses the global make compile rm-rf rule; uses a fresh work dir.

QUESTA_HOME ?= /data1/questaone_sim-2026.1_1/questasim
ETH_LIC_SERVER := 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE     := $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE   := $(LM_LICENSE_FILE)
export SALT_LICENSE_SERVER := $(LM_LICENSE_FILE)
export QSIM_INI            := $(QUESTA_HOME)/modelsim.ini

VLIB := $(QUESTA_HOME)/linux_x86_64/vlib
VMAP := $(QUESTA_HOME)/linux_x86_64/vmap
VLOG := $(QUESTA_HOME)/linux_x86_64/vlog
VSIM := $(QUESTA_HOME)/linux_x86_64/vsim

WORK_BASE   ?= work_merger_$(shell date +%Y%m%d_%H%M%S)
WORK        := $(WORK_BASE)/work
LOG         := $(WORK_BASE)/sim.log

SV_SRCS := \
  ../rtl/merger_hit_type0.sv \
  merger_hit_type0_tb.sv

.PHONY: all run clean-trash

all: run

run:
	@mkdir -p $(WORK_BASE)
	@$(VLIB) $(WORK)
	@$(VMAP) -modelsimini $(WORK_BASE)/modelsim.ini work $(WORK) 2>/dev/null || true
	$(VLOG) -sv -work $(WORK) $(SV_SRCS) | tee -a $(LOG)
	$(VSIM) -c -work $(WORK) -t ps -voptargs=+acc \
	  -do "run -all; quit -f" merger_hit_type0_tb \
	  2>&1 | tee -a $(LOG)
	@grep -E "TEST (PASSED|FAILED)|\[FAIL\]" $(LOG) | tail -10
	@if grep -q "TEST PASSED" $(LOG); then echo "OK: $(LOG)"; else echo "FAIL: $(LOG)"; exit 1; fi

# Per CLAUDE.md, never rm. Move stale work dirs into trash_bin/.
clean-trash:
	@mkdir -p trash_bin
	@find . -maxdepth 1 -type d -name 'work_merger_*' -exec mv {} trash_bin/ \;

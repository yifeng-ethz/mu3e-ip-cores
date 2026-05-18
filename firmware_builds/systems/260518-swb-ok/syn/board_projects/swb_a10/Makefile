# 260518-swb-ok SWB A10 board build driver.
#
# Same target shape as 260518-feb-ok/syn/board_projects/fe_scifi_feb_v3/Makefile
# (see firmware_builds/systems/README.md "Make-targets contract").
# This system delegates qsys generation to the existing pair under
# qsys_tcl/script/ (regenerate_swb_qsys.sh + regenerate_opq_upstream_4lane.tcl)
# because the OPQ native-SV path is rooted deep inside syn/board_projects/.
# The pre-restructure Makefile is preserved at <system>/trash_bin/Makefile.original.

# --- Paths -------------------------------------------------------------------
PROJ_DIR        := $(abspath .)
SYSTEM_DIR      := $(abspath $(PROJ_DIR)/../../..)
REPO_ROOT       := $(abspath $(SYSTEM_DIR)/../../..)
QSYS_TCL_DIR    := $(SYSTEM_DIR)/qsys_tcl
QSYS_TCL_SCRIPT := $(QSYS_TCL_DIR)/script
GENERATED_DIR   := $(SYSTEM_DIR)/generated
GEN_QSYS_DIR    := $(GENERATED_DIR)/qsys
GEN_SYN_DIR     := $(GENERATED_DIR)/synthesis
GEN_SIM_DIR     := $(GENERATED_DIR)/simulation
SOFTWARE_DIR    := $(PROJ_DIR)/software
TRASH_DIR       := $(SYSTEM_DIR)/trash_bin
BOARD_SCRIPT_DIR:= $(PROJ_DIR)/script/board

# OPQ source comes from the packet_scheduler submodule
OPQ_SOURCE_ROOT ?= $(REPO_ROOT)/packet_scheduler
OPQ_SYNTH_DEBUG_LEVEL ?= 0
OPQ_SIM_DEBUG_LEVEL   ?= $(if $(DEBUG_LEVEL),$(DEBUG_LEVEL),2)

# Quartus tools
QUARTUS_ROOTDIR ?= /data1/intelFPGA/18.1/quartus
QSYS_SCRIPT     := $(QUARTUS_ROOTDIR)/sopc_builder/bin/qsys-script
QSYS_GENERATE   := $(QUARTUS_ROOTDIR)/sopc_builder/bin/qsys-generate
QUARTUS_SH      := $(QUARTUS_ROOTDIR)/bin/quartus_sh
NIOS2_BSP       := $(QUARTUS_ROOTDIR)/nios2eds/sdk2/bin/nios2-bsp

# Environment for all recipes
export MU3E_IP_CORES_ROOT := $(REPO_ROOT)
export SYSTEM_DIR
export OPQ_SOURCE_ROOT
export OPQ_SYNTH_DEBUG_LEVEL
export OPQ_SIM_DEBUG_LEVEL
export QUARTUS_ROOTDIR
export PATH := $(QUARTUS_ROOTDIR)/bin:$(QUARTUS_ROOTDIR)/sopc_builder/bin:$(PATH)

# Pattern target case-list discovery
TB_INT_DIR  := $(SYSTEM_DIR)/tb_int
SIM_CASES   := $(notdir $(patsubst %/,%,$(filter-out %/trash_bin/, $(sort $(dir $(wildcard $(TB_INT_DIR)/*/Makefile))))))
TEST_CASES  := $(patsubst test_%.py,%,$(notdir $(wildcard $(BOARD_SCRIPT_DIR)/test_*.py))) \
               $(patsubst test_%.tcl,%,$(notdir $(wildcard $(BOARD_SCRIPT_DIR)/test_*.tcl)))

.PHONY: all help qsys qsys-from-tcl qsys-patch qsys-syn qsys-gen app flow flow_map clean-trash sim-% test-%
all: flow

help:
	@echo 'SWB A10 board project build (system: $(notdir $(SYSTEM_DIR)))'
	@echo
	@echo 'Common targets:'
	@echo '  make qsys-from-tcl    step 1: regenerate_swb_qsys.sh -> generated/qsys/'
	@echo '  make qsys-syn         step 2a: qsys-generate --synthesis (DEBUG_LEVEL=0)'
	@echo '  make qsys-gen         step 2b: qsys-generate --simulation (DEBUG_LEVEL=2)'
	@echo '  make qsys             step 1 + step 2a + step 2b'
	@echo '  make app              Nios SW (BSP + main.cpp)'
	@echo '  make flow_map         Quartus analysis_and_synthesis only'
	@echo '  make flow             Quartus full compile -> output_files/top.sof'
	@echo '  make clean-trash      move build outputs to trash_bin/build_<stamp>/  (NO rm)'
	@echo
	@echo 'Simulation / on-board test targets:'
	@echo '  make sim-<case>       run tb_int scenario <case>  (e.g. sim-feb_swb_corun)'
	@echo '  make test-<case>      run on-board driver <case>  (e.g. test-sc_smoke)'
	@echo
	@echo 'Wired sim cases:  $(SIM_CASES)'
	@echo 'Wired test cases: $(TEST_CASES)'
	@echo
	@echo 'Paths:'
	@echo '  PROJ_DIR       = $(PROJ_DIR)'
	@echo '  SYSTEM_DIR     = $(SYSTEM_DIR)'
	@echo '  REPO_ROOT      = $(REPO_ROOT)'
	@echo '  OPQ_SOURCE_ROOT= $(OPQ_SOURCE_ROOT)'
	@echo '  GEN_QSYS_DIR   = $(GEN_QSYS_DIR)'

# --- Step 1: qsys-from-tcl (delegates to existing regenerate_swb_qsys.sh) ----
qsys-from-tcl:
	@bash $(QSYS_TCL_SCRIPT)/regenerate_swb_qsys.sh

# --- Optional patcher step (no-op for SWB; OPQ is rebuilt fully each time) ---
qsys-patch:
	@echo "[qsys-patch] no-op for SWB (regenerate_swb_qsys.sh rebuilds the OPQ system in-place)"

# --- Step 2a: qsys-syn (handled inside regenerate_swb_qsys.sh today) ---------
qsys-syn:
	@echo "[qsys-syn] handled inside regenerate_swb_qsys.sh; nothing to do here"

# --- Step 2b: qsys-gen (rerun the regenerate wrapper in simulation mode) -----
qsys-gen:
	@bash -c 'GENERATE_SIMULATION=1 OPQ_SIM_DEBUG_LEVEL=$(OPQ_SIM_DEBUG_LEVEL) bash $(QSYS_TCL_SCRIPT)/regenerate_swb_qsys.sh'

# --- Full Qsys: tcl + sim ----------------------------------------------------
qsys: qsys-from-tcl qsys-patch qsys-syn qsys-gen

# --- Nios software -----------------------------------------------------------
app:
	@if [ ! -d $(SOFTWARE_DIR) ]; then \
	    echo "[app] no software/ directory" >&2; exit 1; \
	fi
	@echo "[app] BSP via $(SOFTWARE_DIR)/hal_bsp.tcl"
	@cd $(SOFTWARE_DIR) && \
	    $(NIOS2_BSP) hal build/hal_bsp hal_bsp.tcl
	@$(MAKE) -C $(SOFTWARE_DIR)/build/hal_bsp
	@cd $(SOFTWARE_DIR) && \
	    nios2-app-generate-makefile \
	        --bsp-dir=build/hal_bsp \
	        --src-files=main.cpp \
	        --elf-name=app.elf \
	        --app-dir=build/app
	@$(MAKE) -C $(SOFTWARE_DIR)/build/app

# --- Quartus flow ------------------------------------------------------------
flow_map:
	$(QUARTUS_SH) --flow analysis_and_synthesis top -c top

flow: qsys
	$(QUARTUS_SH) --flow compile top -c top

# --- Simulation scenarios (sim-<case>) ---------------------------------------
sim-%:
	@case_dir=$(TB_INT_DIR)/$*; \
	if [ -f $$case_dir/Makefile ]; then \
	    echo "[sim-$*] -> $$case_dir"; \
	    $(MAKE) -C $$case_dir QUESTA_HOME=$${QUESTA_HOME:-/data1/questaone_sim-2026.1_1/questasim}; \
	else \
	    echo "[sim-$*] PLACEHOLDER -- wire $$case_dir/Makefile per firmware_builds/systems/README.md \"Make-targets contract\"" >&2; \
	    exit 1; \
	fi

# --- On-board test drivers (test-<case>) -------------------------------------
# HARD RULES for the driver itself live in firmware_builds/systems/README.md
# "Make-targets contract" - sopcinfo at runtime, .svd as field guide,
# VERSION readback on startup, swb_ring_lock serialization, 20 s FEB settle.
test-%:
	@py=$(BOARD_SCRIPT_DIR)/test_$*.py; \
	tcl=$(BOARD_SCRIPT_DIR)/test_$*.tcl; \
	sopc=$$(ls $(GEN_QSYS_DIR)/*.sopcinfo 2>/dev/null | head -1); \
	if [ -z "$$sopc" ]; then \
	    echo "[test-$*] WARN: no .sopcinfo under $(GEN_QSYS_DIR); run \`make qsys-from-tcl qsys-syn\` first." >&2; \
	fi; \
	if [ -f $$py ]; then \
	    echo "[test-$*] python3 $$py --sopcinfo $$sopc"; \
	    python3 $$py --sopcinfo $$sopc; \
	elif [ -f $$tcl ]; then \
	    echo "[test-$*] tclsh $$tcl $$sopc"; \
	    tclsh $$tcl $$sopc; \
	else \
	    echo "[test-$*] PLACEHOLDER -- wire $(BOARD_SCRIPT_DIR)/test_$*.{py,tcl} per firmware_builds/systems/README.md \"Make-targets contract\"" >&2; \
	    exit 1; \
	fi

# --- Clean to trash (no rm per CLAUDE.md) ------------------------------------
clean-trash:
	@STAMP=$$(date +%Y%m%d_%H%M%S); \
	DEST=$(TRASH_DIR)/build_$$STAMP; \
	mkdir -p $$DEST; \
	moved=0; \
	for d in db qdb incremental_db output_files sta_debug greybox_tmp; do \
	    if [ -e $$d ]; then mv $$d $$DEST/$$d; moved=$$((moved+1)); fi; \
	done; \
	for d in $$(ls -d sta_debug_* 2>/dev/null); do \
	    mv $$d $$DEST/$$d; moved=$$((moved+1)); \
	done; \
	echo "[clean-trash] $$moved items -> $$DEST"

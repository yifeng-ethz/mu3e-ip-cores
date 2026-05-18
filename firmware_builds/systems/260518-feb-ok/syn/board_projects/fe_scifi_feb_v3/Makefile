# 260518-feb-ok FEB SciFi v3 board build driver.
#
# Layout (per rtl-file-structure system folder contract):
#   <system>/qsys_tcl/         pure connection-inferring Tcl
#   <system>/qsys_tcl/script/  paired Sh wrappers + parameter-only Tcl
#   <system>/generated/qsys/   generated .qsys + .sopcinfo (read-only)
#   <system>/generated/synthesis/<name>/  qsys-generate --synthesis output
#   <system>/generated/simulation/<name>/ qsys-generate --simulation output
#   <system>/syn/board_projects/fe_scifi_feb_v3/  this Makefile + top.{vhd,qpf,qip,sdc}
#                                                 + rtl/{adapters,wrappers} + settings/ + revisions/
#
# Targets (high level):
#   make help          show this help
#   make qsys          full Qsys: qsys-from-tcl, then qsys-syn and qsys-gen
#   make qsys-from-tcl step 1: run qsys_tcl/*.tcl + paired script/ to emit generated/qsys/*.qsys
#   make qsys-syn      step 2a: qsys-generate --synthesis (DEBUG_LEVEL=0) -> generated/synthesis/
#   make qsys-gen      step 2b: qsys-generate --simulation (DEBUG_LEVEL=2) -> generated/simulation/
#   make app           Nios SW BSP + main.cpp build
#   make flow_map      Quartus analysis_and_synthesis (no fit)
#   make flow          Quartus full compile (map + fit + sta + asm) -> output_files/top.sof
#   make clean-trash   mv build artifacts to <system>/trash_bin/build_<stamp>/ (no rm)
#
# Per CLAUDE.md hard rules, no `rm` is invoked. clean-trash uses mv only.

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
SEED_QSYS       := $(SYSTEM_DIR)/syn/feb_system_v3.qsys

# --- Quartus tools -----------------------------------------------------------
QUARTUS_ROOTDIR ?= /data1/intelFPGA/18.1/quartus
QSYS_SCRIPT     := $(QUARTUS_ROOTDIR)/sopc_builder/bin/qsys-script
QSYS_GENERATE   := $(QUARTUS_ROOTDIR)/sopc_builder/bin/qsys-generate
QUARTUS_SH      := $(QUARTUS_ROOTDIR)/bin/quartus_sh
NIOS2_BSP       := $(QUARTUS_ROOTDIR)/nios2eds/sdk2/bin/nios2-bsp

# --- Qsys systems we build/generate ------------------------------------------
QSYS_NAMES      := arb_hit_type0_supercore scifi_datapath_system_v3 scifi_datapath_system_v3_pipe feb_system_v3

# --- Family / part for FEB v3 (Arria 10 SoC on the FEB SciFi board) ----------
FPGA_FAMILY     := Arria 10
FPGA_PART       := 10AS066N3F40E2SG

# --- Environment exported to all recipes -------------------------------------
export MU3E_IP_CORES_ROOT := $(REPO_ROOT)
export SYSTEM_DIR
export QUARTUS_ROOTDIR
export PATH := $(QUARTUS_ROOTDIR)/bin:$(QUARTUS_ROOTDIR)/sopc_builder/bin:$(PATH)

# --- Search-path helper sourced by every qsys recipe -------------------------
# Produces SEARCH_PATHS (comma list) + isolates the user IP catalog so
# qsys-script / qsys-generate find every active *_hw.tcl in the worktree.
define SEARCH_PATH_BOOTSTRAP
	source $(QSYS_TCL_SCRIPT)/qsys_search_path.sh; \
	SEARCH_PATHS=""; USER_COMPONENT_PATHS=""; \
	QSYS_SEARCH_PATH_COUNT=0; QSYS_SEARCH_PATH_SEEN=":"; \
	qsys_collect_active_search_paths "$(REPO_ROOT)"; \
	qsys_create_isolated_user_catalog
endef

# --- Phony list --------------------------------------------------------------
.PHONY: all help qsys qsys-from-tcl qsys-patch qsys-syn qsys-gen app flow flow_map clean-trash
all: flow

help:
	@echo 'FEB SciFi v3 board project build (system: $(notdir $(SYSTEM_DIR)))'
	@echo
	@echo 'Common targets:'
	@echo '  make qsys-from-tcl    step 1: run qsys_tcl/ to produce generated/qsys/*.qsys'
	@echo '  make qsys-syn         step 2a: qsys-generate --synthesis  -> generated/synthesis/'
	@echo '  make qsys-gen         step 2b: qsys-generate --simulation -> generated/simulation/'
	@echo '  make qsys             step 1 + step 2a + step 2b'
	@echo '  make app              Nios SW (BSP + main.cpp)'
	@echo '  make flow_map         Quartus analysis_and_synthesis only'
	@echo '  make flow             Quartus full compile (map + fit + sta + asm)'
	@echo '  make clean-trash      move build outputs to trash_bin/build_<stamp>/  (NO rm)'
	@echo
	@echo 'Paths:'
	@echo '  PROJ_DIR      = $(PROJ_DIR)'
	@echo '  SYSTEM_DIR    = $(SYSTEM_DIR)'
	@echo '  REPO_ROOT     = $(REPO_ROOT)'
	@echo '  GEN_QSYS_DIR  = $(GEN_QSYS_DIR)'
	@echo '  GEN_SYN_DIR   = $(GEN_SYN_DIR)'
	@echo '  GEN_SIM_DIR   = $(GEN_SIM_DIR)'

# --- Step 1: qsys-from-tcl ---------------------------------------------------
# Build the .qsys files that have a true "create_system" recipe in qsys_tcl/.
#   - arb_hit_type0_supercore.qsys     BUILT from scratch by build_arb_*.tcl
#                                       (writes to generated/qsys/<name>.qsys)
#
# The patcher Tcls (refactor_v3_emulator_type0_qsys.tcl,
# update_dualport_histogram_topology.tcl, add_mclk125_reset_bridge_v3.tcl,
# update_feb_system_v3_dualport_version.tcl, update_emulator_type0_descriptions.tcl,
# update_scifi_datapath_v3_histogram_stats.tcl, set_readyless_ctrl_splitters.tcl)
# are NOT standalone — they expect a caller to have already `load_system`'d a
# target .qsys before invoking add_connection / set_instance_parameter_value /
# save_system. Wiring them through `make qsys-patch` requires per-Tcl context
# (which .qsys to load, which to save) that the legacy `apply_*_qsys.sh`
# wrappers encoded. See `qsys-patch` below for the staging-only placeholder.
qsys-from-tcl:
	@mkdir -p $(GEN_QSYS_DIR)
	@chmod u+w $(GEN_QSYS_DIR)
	@find $(GEN_QSYS_DIR) -maxdepth 1 -type f \( -name '*.qsys' -o -name '*.sopcinfo' \) \
	    -exec chmod u+w {} + 2>/dev/null || true
	@bash -c ' \
	set -euo pipefail; \
	$(SEARCH_PATH_BOOTSTRAP); \
	cd $(GEN_QSYS_DIR); \
	echo "[qsys-from-tcl 1.a] build arb_hit_type0_supercore.qsys"; \
	$(QSYS_SCRIPT) --search-path="$$SEARCH_PATHS,\$$" \
	    --cmd="set ::env(SYSTEM_DIR) {$(SYSTEM_DIR)}" \
	    --cmd="set ::env(MU3E_IP_CORES_ROOT) {$(REPO_ROOT)}" \
	    --script=$(QSYS_TCL_DIR)/build_arb_hit_type0_supercore_qsys.tcl; \
	if [ ! -f feb_system_v3.qsys ] && [ -f $(SEED_QSYS) ]; then \
	    echo "[qsys-from-tcl 1.b] seed feb_system_v3.qsys from $(SEED_QSYS)"; \
	    cp $(SEED_QSYS) feb_system_v3.qsys; \
	fi; \
	echo "[qsys-from-tcl] done"; \
	'
	@find $(GEN_QSYS_DIR) -maxdepth 1 -type f \( -name '*.qsys' -o -name '*.sopcinfo' \) \
	    -exec chmod a-w {} + 2>/dev/null || true
	@chmod u+w $(GEN_QSYS_DIR)

# --- Optional: qsys-patch ----------------------------------------------------
# Apply the in-place patchers to the seeded .qsys files. Currently a NO-OP
# because the patcher Tcls need a small wrapper per file (load_system <q.qsys>
# then source <patcher.tcl> then save_system <q.qsys>) which is TODO.
# When wired, this should run BETWEEN qsys-from-tcl and qsys-syn / qsys-gen.
qsys-patch:
	@echo "[qsys-patch] TODO: wire per-target load_system wrappers for:"
	@echo "  - scifi_datapath_system_v3{,_pipe}.qsys: refactor_v3_emulator_type0_qsys.tcl + update_dualport_histogram_topology.tcl"
	@echo "  - feb_system_v3.qsys: add_mclk125_reset_bridge_v3.tcl + script/{update_feb_system_v3_dualport_version,update_emulator_type0_descriptions,update_scifi_datapath_v3_histogram_stats,set_readyless_ctrl_splitters}.tcl"
	@echo "[qsys-patch] (no-op for now; the seeded .qsys files are used as-is)"

# --- Step 2a: qsys-syn (synthesis HDL, DEBUG_LEVEL=0) ------------------------
qsys-syn:
	@mkdir -p $(GEN_SYN_DIR)
	@chmod u+w $(GEN_SYN_DIR)
	@bash -c ' \
	set -euo pipefail; \
	$(SEARCH_PATH_BOOTSTRAP); \
	for q in $(QSYS_NAMES); do \
	    in=$(GEN_QSYS_DIR)/$$q.qsys; \
	    out=$(GEN_SYN_DIR)/$$q; \
	    if [ ! -f $$in ]; then \
	        echo "[qsys-syn] SKIP $$q (missing $$in; run make qsys-from-tcl first)" >&2; continue; \
	    fi; \
	    echo "[qsys-syn] $$q  ->  $$out"; \
	    [ -d $$out ] && chmod -R u+w $$out || true; \
	    QSYS_DEBUG_LEVEL=0 $(QSYS_GENERATE) $$in \
	        --synthesis=VHDL \
	        --output-directory=$$out \
	        --clear-output-directory \
	        --family="$(FPGA_FAMILY)" --part=$(FPGA_PART) \
	        --search-path="$$SEARCH_PATHS,\$$"; \
	done; \
	'
	@find $(GEN_SYN_DIR) -mindepth 1 -type f -exec chmod a-w {} + 2>/dev/null || true

# --- Step 2b: qsys-gen (simulation HDL, DEBUG_LEVEL=2) -----------------------
qsys-gen:
	@mkdir -p $(GEN_SIM_DIR)
	@chmod u+w $(GEN_SIM_DIR)
	@bash -c ' \
	set -euo pipefail; \
	$(SEARCH_PATH_BOOTSTRAP); \
	for q in $(QSYS_NAMES); do \
	    in=$(GEN_QSYS_DIR)/$$q.qsys; \
	    out=$(GEN_SIM_DIR)/$$q; \
	    if [ ! -f $$in ]; then \
	        echo "[qsys-gen] SKIP $$q (missing $$in; run make qsys-from-tcl first)" >&2; continue; \
	    fi; \
	    echo "[qsys-gen] $$q  ->  $$out"; \
	    [ -d $$out ] && chmod -R u+w $$out || true; \
	    QSYS_DEBUG_LEVEL=2 $(QSYS_GENERATE) $$in \
	        --simulation=VERILOG \
	        --allow-mixed-language-simulation \
	        --output-directory=$$out \
	        --clear-output-directory \
	        --family="$(FPGA_FAMILY)" --part=$(FPGA_PART) \
	        --search-path="$$SEARCH_PATHS,\$$"; \
	done; \
	'
	@find $(GEN_SIM_DIR) -mindepth 1 -type f -exec chmod a-w {} + 2>/dev/null || true

# --- Full Qsys: tcl (+ optional patch) + synth + sim -------------------------
qsys: qsys-from-tcl qsys-patch qsys-syn qsys-gen

# --- Nios software -----------------------------------------------------------
# Builds a HAL BSP from software/hal_bsp.tcl then compiles main.cpp into ELF.
# Output lives under software/build/ (gitignored).
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

QUESTA_HOME ?= /data1/questaone_sim-2026.1_1/questasim
ETH_LIC_SERVER := 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE := $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE := $(LM_LICENSE_FILE)
export SALT_LICENSE_SERVER := $(LM_LICENSE_FILE)
export QSIM_INI := modelsim.ini

VLOG := $(QUESTA_HOME)/linux_x86_64/vlog
VCOM := $(QUESTA_HOME)/linux_x86_64/vcom
VSIM := $(QUESTA_HOME)/linux_x86_64/vsim
VLIB := $(QUESTA_HOME)/linux_x86_64/vlib
VMAP := $(QUESTA_HOME)/linux_x86_64/vmap

WORK ?= work_tb_int
SWB_VHDL_WORK ?= work_swb_demux
SWB_BLOCK_WORK ?= work_swb_block_mask
OPQ_NATIVE_WORK ?= work_opq_native_replay
OPQ_NATIVE_PLUSARGS ?=
TB_TOP := tb_int_top
SEED ?= 1
SIM_ROOT ?= sim
STP_REPLAY_MEM ?=
STP_REPLAY_LANE ?= 0
STP_REPLAY_SIDE ?= ingress
OPQ_NATIVE_SRC_ROOT ?= /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/packet_scheduler
UVM_HOME := $(QUESTA_HOME)/verilog_src/uvm-1.2/src
QUESTA_UVM_HOME := $(QUESTA_HOME)/verilog_src/questa_uvm_pkg-1.2/src
UVM_SRC := $(UVM_HOME)/uvm_pkg.sv
UVM_INCDIR := +incdir+$(UVM_HOME) +incdir+$(QUESTA_UVM_HOME)
VLOG_OPTS := -sv -work $(WORK) -timescale 1ps/1ps +define+UVM_NO_DPI +define+TB_INT_SIM
VSIM_OPTS := -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -nodpiexports -work $(WORK)
OPQ_NATIVE_VLOG_OPTS := -sv -work $(OPQ_NATIVE_WORK) -timescale 1ns/1ps \
	+define+OPQ_USE_NATIVE_SV +define+OPQ_N_LANE=4 +define+OPQ_N_SHD=128 \
	+define+OPQ_N_HIT=255 +define+OPQ_TICKET_FIFO_DEPTH=1024 \
	+define+OPQ_PAGE_RAM_DEPTH=65536 +define+OPQ_DEBUG_LEVEL=1

OPQ_NATIVE_RAM_SRCS := \
	$(OPQ_NATIVE_SRC_ROOT)/rtl/sv_ver/vendor/alt_ram/frame_table.v \
	$(OPQ_NATIVE_SRC_ROOT)/rtl/sv_ver/vendor/alt_ram/handle_fifo.v \
	$(OPQ_NATIVE_SRC_ROOT)/rtl/sv_ver/vendor/alt_ram/lane_fifo.v \
	$(OPQ_NATIVE_SRC_ROOT)/rtl/sv_ver/vendor/alt_ram/page_ram.v \
	$(OPQ_NATIVE_SRC_ROOT)/rtl/sv_ver/vendor/alt_ram/ticket_fifo.v \
	$(OPQ_NATIVE_SRC_ROOT)/rtl/sv_ver/vendor/alt_ram/tile_fifo.v

OPQ_NATIVE_SV_SRCS := \
	$(OPQ_NATIVE_SRC_ROOT)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_ingress_parser.sv \
	$(OPQ_NATIVE_SRC_ROOT)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_page_allocator.sv \
	$(OPQ_NATIVE_SRC_ROOT)/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic_block_path.sv \
	$(OPQ_NATIVE_SRC_ROOT)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_frame_table_tracker.sv \
	$(OPQ_NATIVE_SRC_ROOT)/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic_frame_table_presenter.sv \
	$(OPQ_NATIVE_SRC_ROOT)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_basic_presenter.sv \
	$(OPQ_NATIVE_SRC_ROOT)/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic.sv \
	$(OPQ_NATIVE_SRC_ROOT)/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_dut_sv.sv

BASIC_CASES := B001 B002 B003 B004 B005 B006 B007 B008 B033 B034 B040 B043 B065 B066 B067 B068 B069
EDGE_CASES := E001 E002 E003 E033 E043 E065 E066 E067 E068
ERROR_CASES := X001 X002 X003 X004 X005 X033 X065 X069
PROF_CASES := P001 P002 P003 P065 P066 P068
SELECTED_CASES := $(BASIC_CASES) $(EDGE_CASES) $(ERROR_CASES) $(PROF_CASES)

.PHONY: docs check modelsim_ini lib comp_uvm comp_swb_demux_replay comp_swb_block_mask_replay comp_opq_native_replay comp_uvm_wedge_fixed smoke basic edge error prof regress_selected structural_preflight static_screen clean $(addprefix run_,$(SELECTED_CASES)) run_B-RC-CSR-001 run_B-SC-JTG-001 run_E-SC-CONC-001 run_RC_DIRECTED run_RC_DIRECTED_WEDGE run_RC_DIRECTED_WEDGE_FIXED run_OPQ_FRAME_TS_SMOKE run_OPQ_FRAME_STP_REPLAY run_OPQ_NATIVE_LANE2_REPLAY run_SWB_FEB_XCVR_DEMERGER_REPLAY run_SWB_FEB_XCVR_STEERING_REPLAY run_SWB_FEB_SCIFI_MASK_REPLAY

docs:
	python3 script/generate_swb_tb_int_assets.py

check: docs
	python3 ~/.codex/skills/dv-workflow/scripts/dv_bucket_format_check.py doc
	python3 ~/.codex/skills/dv-workflow/scripts/bug_history_format_check.py doc/BUG_HISTORY.md
	python3 ~/.codex/skills/dv-workflow/scripts/dv_report_format_check.py doc/DV_REPORT.md

modelsim.ini:
	cp $(QUESTA_HOME)/modelsim.ini modelsim.ini

lib: modelsim.ini
	mkdir -p $(SIM_ROOT)
	test -d $(WORK) || $(VLIB) $(WORK)
	$(VMAP) -modelsimini modelsim.ini work $(WORK)

comp_uvm: docs lib
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(UVM_INCDIR) $(UVM_SRC)
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(UVM_INCDIR) -f script/tb_int.f

comp_swb_demux_replay: modelsim.ini
	mkdir -p $(SIM_ROOT)
	test -d $(SWB_VHDL_WORK) || $(VLIB) $(SWB_VHDL_WORK)
	$(VMAP) -modelsimini modelsim.ini work $(SWB_VHDL_WORK)
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(SWB_VHDL_WORK) \
		../syn/board_projects/swb_a10/util/util_slv.vhd \
		../syn/board_projects/swb_a10/util/util_pkg.vhd \
		../syn/board_projects/swb_a10/registers/mudaq.vhd \
		../syn/board_projects/swb_a10/a10/link/mu3e_pkg.vhd \
		../syn/board_projects/swb_a10/a10/swb/swb_data_demerger.vhd \
		hdl/tb_swb_data_demerger_feb_v3.vhd

comp_swb_block_mask_replay: modelsim.ini
	mkdir -p $(SIM_ROOT)
	test -d $(SWB_BLOCK_WORK) || $(VLIB) $(SWB_BLOCK_WORK)
	$(VMAP) -modelsimini modelsim.ini work $(SWB_BLOCK_WORK)
	$(VCOM) -modelsimini modelsim.ini -2008 -work $(SWB_BLOCK_WORK) \
		../syn/board_projects/swb_a10/util/util_slv.vhd \
		../syn/board_projects/swb_a10/util/util_pkg.vhd \
		../syn/board_projects/swb_a10/registers/mudaq.vhd \
		../syn/board_projects/swb_a10/registers/a10_pcie_registers.vhd \
		../syn/board_projects/swb_a10/registers/a10_counters.vhd \
		../syn/board_projects/swb_a10/a10/link/mu3e_pkg.vhd \
		../syn/board_projects/swb_a10/a10/swb/swb_data_demerger.vhd \
		hdl/swb_block_mask_stubs.vhd \
		../syn/board_projects/swb_a10/a10/swb/swb_block.vhd \
		hdl/tb_swb_block_feb_v3_scifi_mask.vhd

comp_opq_native_replay: modelsim.ini
	mkdir -p $(SIM_ROOT)
	test -d $(OPQ_NATIVE_WORK) || $(VLIB) $(OPQ_NATIVE_WORK)
	$(VMAP) -modelsimini modelsim.ini work $(OPQ_NATIVE_WORK)
	$(VLOG) -modelsimini modelsim.ini $(OPQ_NATIVE_VLOG_OPTS) \
		$(OPQ_NATIVE_RAM_SRCS) \
		$(OPQ_NATIVE_SV_SRCS) \
		hdl/tb_opq_native_lane2_replay.sv

define RUN_CASE_template
run_$(1): comp_uvm
	mkdir -p $(SIM_ROOT)/$(1)
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_$(2)_test +ARB_SEED=$(SEED) +TB_INT_CASE=$(1) +TB_INT_SIM_DIR=$(SIM_ROOT)/$(1) -l $(SIM_ROOT)/$(1)/transcript -do "run -all; quit -f"
	rg "\*\*\* TEST PASSED \*\*\*" $(SIM_ROOT)/$(1)/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/$(1)/transcript; then exit 1; fi
endef

$(eval $(call RUN_CASE_template,B001,b001))
$(eval $(call RUN_CASE_template,B002,b002))
$(eval $(call RUN_CASE_template,B003,b003))
$(eval $(call RUN_CASE_template,B004,b004))
$(eval $(call RUN_CASE_template,B005,b005))
$(eval $(call RUN_CASE_template,B006,b006))
$(eval $(call RUN_CASE_template,B007,b007))
$(eval $(call RUN_CASE_template,B008,b008))
$(eval $(call RUN_CASE_template,B033,b033))
$(eval $(call RUN_CASE_template,B034,b034))
$(eval $(call RUN_CASE_template,B040,b040))
$(eval $(call RUN_CASE_template,B043,b043))
$(eval $(call RUN_CASE_template,B065,b065))
$(eval $(call RUN_CASE_template,B066,b066))
$(eval $(call RUN_CASE_template,B067,b067))
$(eval $(call RUN_CASE_template,B068,b068))
$(eval $(call RUN_CASE_template,B069,b069))
$(eval $(call RUN_CASE_template,E001,e001))
$(eval $(call RUN_CASE_template,E002,e002))
$(eval $(call RUN_CASE_template,E003,e003))
$(eval $(call RUN_CASE_template,E033,e033))
$(eval $(call RUN_CASE_template,E043,e043))
$(eval $(call RUN_CASE_template,E065,e065))
$(eval $(call RUN_CASE_template,E066,e066))
$(eval $(call RUN_CASE_template,E067,e067))
$(eval $(call RUN_CASE_template,E068,e068))
$(eval $(call RUN_CASE_template,X001,x001))
$(eval $(call RUN_CASE_template,X002,x002))
$(eval $(call RUN_CASE_template,X003,x003))
$(eval $(call RUN_CASE_template,X004,x004))
$(eval $(call RUN_CASE_template,X005,x005))
$(eval $(call RUN_CASE_template,X033,x033))
$(eval $(call RUN_CASE_template,X065,x065))
$(eval $(call RUN_CASE_template,X069,x069))
$(eval $(call RUN_CASE_template,P001,p001))
$(eval $(call RUN_CASE_template,P002,p002))
$(eval $(call RUN_CASE_template,P003,p003))
$(eval $(call RUN_CASE_template,P065,p065))
$(eval $(call RUN_CASE_template,P066,p066))
$(eval $(call RUN_CASE_template,P068,p068))

smoke: run_B065

basic: $(addprefix run_,$(BASIC_CASES))

edge: $(addprefix run_,$(EDGE_CASES))

error: $(addprefix run_,$(ERROR_CASES))

prof: $(addprefix run_,$(PROF_CASES))

regress_selected: basic edge error prof

run_B-RC-CSR-001: run_B008

run_B-SC-JTG-001: run_B040

run_E-SC-CONC-001: run_E043

run_RC_DIRECTED: comp_uvm
	mkdir -p $(SIM_ROOT)/RC_DIRECTED
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_run_sequence_directed_test +ARB_SEED=$(SEED) +TB_INT_SIM_DIR=$(SIM_ROOT)/RC_DIRECTED -l $(SIM_ROOT)/RC_DIRECTED/transcript -do "run -all; quit -f"
	rg "\*\*\* TEST PASSED \*\*\*" $(SIM_ROOT)/RC_DIRECTED/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/RC_DIRECTED/transcript; then exit 1; fi

# BUG-RC-RESET-SCWEDGE behavioural topology repro (PRE-FIX). Uses the
# default WORK dir (no BUG_RC_RESET_SCWEDGE_FIXED define), so the
# mock_sc_plane_reset cascade is active. Expects post-CMD_RESET STATUS
# read == 0xEEEE_EEEE.
run_RC_DIRECTED_WEDGE: comp_uvm
	mkdir -p $(SIM_ROOT)/RC_DIRECTED_WEDGE
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_run_sequence_directed_wedge_test +ARB_SEED=$(SEED) +TB_INT_SIM_DIR=$(SIM_ROOT)/RC_DIRECTED_WEDGE -l $(SIM_ROOT)/RC_DIRECTED_WEDGE/transcript -do "run -all; quit -f"
	rg "\*\*\* TEST PASSED \*\*\*" $(SIM_ROOT)/RC_DIRECTED_WEDGE/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/RC_DIRECTED_WEDGE/transcript; then exit 1; fi

# BUG-RC-RESET-SCWEDGE behavioural topology repro (POST-FIX). Compiles
# into a separate WORK dir (work_tb_int_wedge_fixed) with
# +define+BUG_RC_RESET_SCWEDGE_FIXED so the mock_ext_hard_reset ->
# mock_sc_plane_reset pipeline is BROKEN. Expects post-CMD_RESET STATUS
# read == 0x4849_5354 ("HIST" stub pattern).
comp_uvm_wedge_fixed: docs lib
	test -d work_tb_int_wedge_fixed || $(VLIB) work_tb_int_wedge_fixed
	$(VMAP) -modelsimini modelsim.ini work_wedge_fixed work_tb_int_wedge_fixed
	$(VLOG) -modelsimini modelsim.ini -sv -work work_tb_int_wedge_fixed -timescale 1ps/1ps +define+UVM_NO_DPI +define+TB_INT_SIM +define+BUG_RC_RESET_SCWEDGE_FIXED $(UVM_INCDIR) $(UVM_SRC)
	$(VLOG) -modelsimini modelsim.ini -sv -work work_tb_int_wedge_fixed -timescale 1ps/1ps +define+UVM_NO_DPI +define+TB_INT_SIM +define+BUG_RC_RESET_SCWEDGE_FIXED $(UVM_INCDIR) -f script/tb_int.f

run_RC_DIRECTED_WEDGE_FIXED: comp_uvm_wedge_fixed
	mkdir -p $(SIM_ROOT)/RC_DIRECTED_WEDGE_FIXED
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -nodpiexports -work work_tb_int_wedge_fixed $(TB_TOP) +UVM_TESTNAME=tb_int_run_sequence_directed_wedge_fixed_test +ARB_SEED=$(SEED) +TB_INT_SIM_DIR=$(SIM_ROOT)/RC_DIRECTED_WEDGE_FIXED -l $(SIM_ROOT)/RC_DIRECTED_WEDGE_FIXED/transcript -do "run -all; quit -f"
	rg "\*\*\* TEST PASSED \*\*\*" $(SIM_ROOT)/RC_DIRECTED_WEDGE_FIXED/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/RC_DIRECTED_WEDGE_FIXED/transcript; then exit 1; fi

run_OPQ_FRAME_TS_SMOKE: comp_uvm
	mkdir -p $(SIM_ROOT)/OPQ_FRAME_TS_SMOKE
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_opq_frame_ts_smoke_test +ARB_SEED=$(SEED) +TB_INT_SIM_DIR=$(SIM_ROOT)/OPQ_FRAME_TS_SMOKE -l $(SIM_ROOT)/OPQ_FRAME_TS_SMOKE/transcript -do "run -all; quit -f"
	rg "\*\*\* TEST PASSED \*\*\*" $(SIM_ROOT)/OPQ_FRAME_TS_SMOKE/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/OPQ_FRAME_TS_SMOKE/transcript; then exit 1; fi

run_OPQ_FRAME_STP_REPLAY: comp_uvm
	@test -n "$(STP_REPLAY_MEM)" || { echo "STP_REPLAY_MEM=<decoded.mem> is required"; exit 2; }
	mkdir -p $(SIM_ROOT)/OPQ_FRAME_STP_REPLAY
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_opq_frame_replay_test +ARB_SEED=$(SEED) +TB_INT_STP_REPLAY_MEM=$(STP_REPLAY_MEM) +TB_INT_STP_REPLAY_LANE=$(STP_REPLAY_LANE) +TB_INT_STP_REPLAY_SIDE=$(STP_REPLAY_SIDE) +TB_INT_REPLAY_EXPECT_INGRESS_HITS +TB_INT_SIM_DIR=$(SIM_ROOT)/OPQ_FRAME_STP_REPLAY -l $(SIM_ROOT)/OPQ_FRAME_STP_REPLAY/transcript -do "run -all; quit -f"
	rg "\*\*\* TEST PASSED \*\*\*" $(SIM_ROOT)/OPQ_FRAME_STP_REPLAY/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/OPQ_FRAME_STP_REPLAY/transcript; then exit 1; fi

run_OPQ_NATIVE_LANE2_REPLAY: comp_opq_native_replay
	mkdir -p $(SIM_ROOT)/OPQ_NATIVE_LANE2_REPLAY
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -work $(OPQ_NATIVE_WORK) tb_opq_native_lane2_replay $(OPQ_NATIVE_PLUSARGS) -l $(SIM_ROOT)/OPQ_NATIVE_LANE2_REPLAY/transcript -do "run -all; quit -f"
	rg "\*\*\* TEST PASSED \*\*\*" $(SIM_ROOT)/OPQ_NATIVE_LANE2_REPLAY/transcript

run_SWB_FEB_XCVR_DEMERGER_REPLAY: comp_swb_demux_replay
	mkdir -p $(SIM_ROOT)/SWB_FEB_XCVR_DEMERGER_REPLAY
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -work $(SWB_VHDL_WORK) tb_swb_data_demerger_feb_v3 -l $(SIM_ROOT)/SWB_FEB_XCVR_DEMERGER_REPLAY/transcript -do "run -all; quit -f"
	rg "\*\*\* TEST PASSED \*\*\*" $(SIM_ROOT)/SWB_FEB_XCVR_DEMERGER_REPLAY/transcript

run_SWB_FEB_XCVR_STEERING_REPLAY: comp_uvm
	mkdir -p $(SIM_ROOT)/SWB_FEB_XCVR_STEERING_REPLAY
	$(VSIM) $(VSIM_OPTS) $(TB_TOP) +UVM_TESTNAME=tb_int_swb_feb_steering_sweep_test +ARB_SEED=$(SEED) +TB_INT_SIM_DIR=$(SIM_ROOT)/SWB_FEB_XCVR_STEERING_REPLAY -l $(SIM_ROOT)/SWB_FEB_XCVR_STEERING_REPLAY/transcript -do "run -all; quit -f"
	rg "\*\*\* TEST PASSED \*\*\*" $(SIM_ROOT)/SWB_FEB_XCVR_STEERING_REPLAY/transcript
	@if rg "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(SIM_ROOT)/SWB_FEB_XCVR_STEERING_REPLAY/transcript; then exit 1; fi

run_SWB_FEB_SCIFI_MASK_REPLAY: comp_swb_block_mask_replay
	mkdir -p $(SIM_ROOT)/SWB_FEB_SCIFI_MASK_REPLAY
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -work $(SWB_BLOCK_WORK) tb_swb_block_feb_v3_scifi_mask -l $(SIM_ROOT)/SWB_FEB_SCIFI_MASK_REPLAY/transcript -do "run -all; quit -f"
	rg "\*\*\* TEST PASSED \*\*\*" $(SIM_ROOT)/SWB_FEB_SCIFI_MASK_REPLAY/transcript

structural_preflight: docs
	python3 script/run_basic_bucket_sweep.py

static_screen:
	@echo "static_screen: deferred to full TB_INT_BIND_REAL_DUT mixed-language promotion."

clean:
	@echo "clean: non-destructive by policy. Remove work/ and sim/ manually if a clean tree is required."

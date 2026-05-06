# PROF-INT-002 full-pipeline real-RTL integration benchmark.
#
# Author: Yifeng Wang <yifenwan@phys.ethz.ch>

PROF_INT_002_TEST := prof_int_002_full_pipeline_100khz_per_channel_test
PROF_INT_002_TOP  := prof_int_002_full_pipeline_top
PROF_INT_002_DIR  := $(SIM_ROOT)/$(PROF_INT_002_TEST)
PROF_INT_002_DIR_1L_5S := $(SIM_ROOT)/prof_int_002_full_pipeline_100khz_per_channel_1lane_5s
PROF_INT_002_DIR_8L_5S := $(SIM_ROOT)/prof_int_002_full_pipeline_100khz_per_channel_8lane_5s
PROF_INT_002_DIR_EMU_5S := $(SIM_ROOT)/prof_int_002_full_pipeline_100khz_per_channel_emulator_full8lane_5s
PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE ?= periodic
PROF_INT_002_PRE_RBCAM_INJECT_PHASE_CYCLES ?= 100
PROF_INT_002_PRE_RBCAM_INJECT_PULSE_COUNT ?= 128
PROF_INT_002_PRE_RBCAM_RUN_CYCLES ?= 200000
PROF_INT_002_PRE_RBCAM_DRAIN_CYCLES ?= 4096
PROF_INT_002_PRE_RBCAM_CHANNEL_LOW ?= 0
PROF_INT_002_PRE_RBCAM_CHANNEL_HIGH ?= 1
PROF_INT_002_PRE_RBCAM_PHASE_SWEEP ?= 100 200 300 400 500 600 700 800 900
PROF_INT_002_PRE_RBCAM_CASE ?= prof_int_002_pre_rbcam_$(PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE)_phase$(PROF_INT_002_PRE_RBCAM_INJECT_PHASE_CYCLES)
PROF_INT_002_PRE_RBCAM_DIR := $(SIM_ROOT)/$(PROF_INT_002_PRE_RBCAM_CASE)
PROF_INT_002_PRE_RBCAM_HIST_DIR := $(PROF_INT_002_PRE_RBCAM_DIR)/pre_rbcam_hist
PROF_INT_002_PRE_RBCAM_SWEEP_HIST_DIR := $(SIM_ROOT)/prof_int_002_pre_rbcam_header_sync_phase_sweep/pre_rbcam_hist
PROF_INT_002_REPORT_DIR := $(TB_INT_ROOT)/reports
PROF_INT_002_REPORT_DIR_1L_5S := $(PROF_INT_002_REPORT_DIR)/prof_int_002_full_pipeline_100khz_per_channel_1lane_5s
PROF_INT_002_REPORT_DIR_8L_5S := $(PROF_INT_002_REPORT_DIR)/prof_int_002_full_pipeline_100khz_per_channel_8lane_5s
PROF_INT_002_REPORT_DIR_EMU_5S := $(PROF_INT_002_REPORT_DIR)/prof_int_002_full_pipeline_100khz_per_channel_emulator_full8lane_5s
PROF_INT_002_RUN_CYCLES_5S := 625000000
PROF_INT_002_STABLE_WINDOW_CYCLES := 125000000
PROF_INT_002_DRAIN_CYCLES_5S := 16384
PROF_INT_002_SYN  := $(abspath $(TB_INT_ROOT)/../../system_20260504_full8lane_type0/syn/full8lane_type0_system/synthesis)
PROF_INT_002_COMMON := $(abspath $(TB_INT_ROOT)/../../system_20260504_full8lane_type0/syn/board_projects/fe_scifi_full8lane/src/common)
PROF_INT_002_MTS_ROM_INIT := $(PROF_INT_002_SYN)/submodules/dual_port_rom_init.txt
PROF_INT_002_QUARTUS_SIMLIB ?= /data1/intelFPGA/18.1/quartus/eda/sim_lib
PROF_INT_002_INCDIR := +incdir+$(PROF_INT_002_SYN) +incdir+$(PROF_INT_002_SYN)/submodules
PROF_INT_002_RUN_CYCLES ?= 12500000
PROF_INT_002_DRAIN_CYCLES ?= 16384
PROF_INT_002_HIT_RATE_Q16 ?= 52
PROF_INT_002_RUNCTL_CPP_GAP_CYCLES ?= 125000
PROF_INT_002_RUNCTL_SETTLE_TIMEOUT_CYCLES ?= 1250000
PROF_INT_002_STABLE_ONLY_EXPORT ?= 1
PROF_INT_002_VLOG_V_OPTS := -sv -ignoresvkeywords=do -mixedansiports -mixedsvvh s -work $(WORK) -timescale 1ps/1ps +define+UVM_NO_DPI +define+TB_INT_SIM

.PHONY: comp_prof_int_002_dut comp_prof_int_002 prepare_prof_int_002_mem_init \
\trun_prof_int_002_full_pipeline_100khz_per_channel_test \
\trun_prof_int_002_full_pipeline_100khz_per_channel_1lane_5s \
\trun_prof_int_002_full_pipeline_100khz_per_channel_8lane_5s \
\trun_prof_int_002_full_pipeline_100khz_per_channel_emulator_full8lane_5s \
\trun_prof_int_002_pre_rbcam_latency \
\trun_prof_int_002_pre_rbcam_header_sync_phase_100 \
\trun_prof_int_002_pre_rbcam_header_sync_phase_500 \
\trun_prof_int_002_pre_rbcam_header_sync_phase_900 \
\trun_prof_int_002_pre_rbcam_header_sync_phase_sweep_100_900 \
\trun_prof_int_002_pre_rbcam_periodic_2ch \
\tplot_prof_int_002_full_pipeline_100khz_per_channel_1lane_5s \
\tplot_prof_int_002_full_pipeline_100khz_per_channel_8lane_5s \
\tplot_prof_int_002_full_pipeline_100khz_per_channel_emulator_full8lane_5s \
\tplot_prof_int_002_full_pipeline_100khz_per_channel_5s \
\trun_prof_int_002_full_pipeline_100khz_per_channel_5s

comp_prof_int_002_dut: lib
	$(VMAP) -modelsimini modelsim.ini std $(QUESTA_HOME)/std
	$(VMAP) -modelsimini modelsim.ini ieee $(QUESTA_HOME)/ieee
	$(VMAP) -modelsimini modelsim.ini synopsys $(QUESTA_HOME)/synopsys
	$(VMAP) -modelsimini modelsim.ini verilog $(QUESTA_HOME)/verilog
	$(VMAP) -modelsimini modelsim.ini std_developerskit $(QUESTA_HOME)/std_developerskit
	$(VMAP) -modelsimini modelsim.ini altera_mf $(QUESTA_HOME)/intel_2026/vhdl/altera_mf
	$(VMAP) -modelsimini modelsim.ini altera $(QUESTA_HOME)/intel_2026/vhdl/altera
	$(VMAP) -modelsimini modelsim.ini lpm $(QUESTA_HOME)/intel_2026/vhdl/220model
	$(VMAP) -modelsimini modelsim.ini sgate $(QUESTA_HOME)/intel_2026/vhdl/sgate
	$(VLOG) -modelsimini modelsim.ini -work $(WORK) -timescale 1ps/1ps $(QUESTA_HOME)/intel/verilog/src/altera_mf.v
	$(VLOG) -modelsimini modelsim.ini -sv -work $(WORK) -timescale 1ps/1ps $(QUESTA_HOME)/intel/verilog/src/altera_lnsim.sv
	$(VLOG) -modelsimini modelsim.ini -work $(WORK) -timescale 1ps/1ps \
	    $(PROF_INT_002_QUARTUS_SIMLIB)/arriav_atoms.v \
	    $(PROF_INT_002_QUARTUS_SIMLIB)/mentor/arriav_atoms_ncrypt.v
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/firefly_constants.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/cam_helper_pkg.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/histogram_statistics_v2_pkg.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/addr_enc_logic_partitioned.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/bin_divider.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/alt_simple_dpram.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/true_dual_port_ram_single_clock.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/cam_mem_blk_a5.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/cam_mem_a5.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/hit_fifo.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rr_arbiter.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/coalescing_queue.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/pingpong_sram.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/histogram_statistics_v2_bool_core.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/histogram_statistics_v2.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/ring_buffer_cam_v2_core.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/search_for_extreme3.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/i2c_master.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/pseudo_clock_down_convertor.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/onewire_master.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/simple_dual_port_ram_single_clock.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/write_mask_gen.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/alt_dcfifo_w40d256.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/alt_dcfifo_w40d256_patched.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/sc_hub_pkg.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/fifo/sc_hub_fifo_sc.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/fifo/sc_hub_fifo_sf.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/fifo/sc_hub_fifo_bp.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/sc_hub_payload_ram.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/sc_hub_pkt_rx.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/sc_hub_pkt_tx.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/sc_hub_avmm_handler.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/sc_hub_axi4_handler.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/sc_hub_axi4_ooo_handler.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/sc_hub_core.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/sc_hub_axi4_core.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/sc_hub_top.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/sc_hub_top_axi4.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/max10_spi_split.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_COMMON)/util/util_slv.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_COMMON)/registers/mudaq.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/max10_prog_avmm.vhd
	$(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008 $(PROF_INT_002_SYN)/submodules/rtl/histogram_ingress_bridge.vhd
	@find $(PROF_INT_002_SYN) -type f -name '*.vhd' \
	    ! -name firefly_constants.vhd \
	    ! -name cam_helper_pkg.vhd \
	    ! -name histogram_statistics_v2_pkg.vhd \
	    ! -name addr_enc_logic_partitioned.vhd \
	    ! -name bin_divider.vhd \
	    ! -name alt_simple_dpram.vhd \
	    ! -name true_dual_port_ram_single_clock.vhd \
	    ! -name cam_mem_blk_a5.vhd \
	    ! -name cam_mem_a5.vhd \
	    ! -name hit_fifo.vhd \
	    ! -name rr_arbiter.vhd \
	    ! -name coalescing_queue.vhd \
	    ! -name pingpong_sram.vhd \
	    ! -name histogram_statistics_v2_bool_core.vhd \
	    ! -name histogram_statistics_v2.vhd \
	    ! -name ring_buffer_cam_v2_core.vhd \
	    ! -name search_for_extreme3.vhd \
	    ! -name i2c_master.vhd \
	    ! -name pseudo_clock_down_convertor.vhd \
	    ! -name onewire_master.vhd \
	    ! -name simple_dual_port_ram_single_clock.vhd \
	    ! -name write_mask_gen.vhd \
	    ! -name alt_dcfifo_w40d256.vhd \
	    ! -name alt_dcfifo_w40d256_patched.vhd \
	    ! -name sc_hub_pkg.vhd \
	    ! -name sc_hub_fifo_sc.vhd \
	    ! -name sc_hub_fifo_sf.vhd \
	    ! -name sc_hub_fifo_bp.vhd \
	    ! -name sc_hub_payload_ram.vhd \
	    ! -name sc_hub_pkt_rx.vhd \
	    ! -name sc_hub_pkt_tx.vhd \
	    ! -name sc_hub_avmm_handler.vhd \
	    ! -name sc_hub_axi4_handler.vhd \
	    ! -name sc_hub_axi4_ooo_handler.vhd \
	    ! -name sc_hub_core.vhd \
	    ! -name sc_hub_axi4_core.vhd \
	    ! -name sc_hub_top.vhd \
	    ! -name sc_hub_top_axi4.vhd \
	    ! -name max10_spi_split.vhd \
	    ! -name max10_prog_avmm.vhd \
	    ! -name histogram_ingress_bridge.vhd \
	    -print0 | sort -z | xargs -0 $(VCOM) -modelsimini modelsim.ini -work $(WORK) -2008
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(PROF_INT_002_INCDIR) $(PROF_INT_002_SYN)/submodules/frontend_ticket_bus_pkg.sv
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(PROF_INT_002_INCDIR) $(PROF_INT_002_SYN)/submodules/be_mutrig_pkg.sv
	@find $(PROF_INT_002_SYN) -type f -name '*.sv' \
	    ! -name frontend_ticket_bus_pkg.sv \
	    ! -name be_mutrig_pkg.sv \
	    -print0 | sort -z | xargs -0 $(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(PROF_INT_002_INCDIR)
	@find $(PROF_INT_002_SYN) -type f -name '*.v' \
	    -print0 | sort -z | xargs -0 $(VLOG) -modelsimini modelsim.ini $(PROF_INT_002_VLOG_V_OPTS) $(PROF_INT_002_INCDIR)

comp_prof_int_002: comp_uvm comp_prof_int_002_dut
	$(VLOG) -modelsimini modelsim.ini $(VLOG_OPTS) $(UVM_INCDIR) $(PROF_INT_002_INCDIR) \
	    uvm/sequence/prof/prof_int_002_full_pipeline_100khz_per_channel_seq.sv \
	    uvm/test/prof/prof_int_002_full_pipeline_100khz_per_channel_test.sv \
	    prof_int_002_full_pipeline_top.sv

prepare_prof_int_002_mem_init:
	@test -f $(PROF_INT_002_MTS_ROM_INIT)
	@ln -sf $(PROF_INT_002_MTS_ROM_INIT) dual_port_rom_init.txt

run_prof_int_002_full_pipeline_100khz_per_channel_test: comp_prof_int_002 prepare_prof_int_002_mem_init
	@mkdir -p $(PROF_INT_002_DIR)
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -nodpiexports -work $(WORK) $(PROF_INT_002_TOP) \
	    +UVM_TESTNAME=$(PROF_INT_002_TEST) \
	    +ARB_SEED=$(SEED) \
	    +TB_INT_SIM_DIR=$(PROF_INT_002_DIR) \
	    +TB_INT_REQUIRE_ZERO_RESIDUAL=0 \
	    +TB_INT_MIN_CLOSED_PCT=95 \
		    +TB_INT_RUN_CYCLES=$(PROF_INT_002_RUN_CYCLES) \
		    +TB_INT_DRAIN_CYCLES=$(PROF_INT_002_DRAIN_CYCLES) \
		    +TB_INT_STABLE_WINDOW_CYCLES=0 \
		    +TB_INT_RUNCTL_CPP_GAP_CYCLES=$(PROF_INT_002_RUNCTL_CPP_GAP_CYCLES) \
		    +TB_INT_RUNCTL_SETTLE_TIMEOUT_CYCLES=$(PROF_INT_002_RUNCTL_SETTLE_TIMEOUT_CYCLES) \
		    +PROF_INT_002_HIT_RATE_Q16=$(PROF_INT_002_HIT_RATE_Q16) \
	    +TB_INT_ACTIVE_LANE_COUNT=1 \
	    +TB_INT_ACTIVE_LANE_MASK=1 \
	    -l $(PROF_INT_002_DIR)/transcript \
	    -do "run -all; quit -f"
	@tail -n 80 $(PROF_INT_002_DIR)/transcript
	@grep -q "\*\*\* TEST PASSED \*\*\*" $(PROF_INT_002_DIR)/transcript
	@if grep -E "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(PROF_INT_002_DIR)/transcript; then exit 1; fi

run_prof_int_002_pre_rbcam_latency: comp_prof_int_002 prepare_prof_int_002_mem_init
	@mkdir -p $(PROF_INT_002_PRE_RBCAM_DIR)
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -nodpiexports -work $(WORK) $(PROF_INT_002_TOP) \
	    +UVM_TESTNAME=$(PROF_INT_002_TEST) \
	    +ARB_SEED=$(SEED) \
	    +TB_INT_SIM_DIR=$(PROF_INT_002_PRE_RBCAM_DIR) \
	    +TB_INT_REQUIRE_ZERO_RESIDUAL=0 \
	    +TB_INT_MIN_CLOSED_PCT=0 \
		    +TB_INT_RUN_CYCLES=$(PROF_INT_002_PRE_RBCAM_RUN_CYCLES) \
		    +TB_INT_DRAIN_CYCLES=$(PROF_INT_002_PRE_RBCAM_DRAIN_CYCLES) \
		    +TB_INT_STABLE_WINDOW_CYCLES=0 \
		    +TB_INT_RUNCTL_CPP_GAP_CYCLES=$(PROF_INT_002_RUNCTL_CPP_GAP_CYCLES) \
		    +TB_INT_RUNCTL_SETTLE_TIMEOUT_CYCLES=$(PROF_INT_002_RUNCTL_SETTLE_TIMEOUT_CYCLES) \
		    +PROF_INT_002_HIT_RATE_Q16=$(PROF_INT_002_HIT_RATE_Q16) \
		    +TB_INT_TRAFFIC_MODE=$(PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE) \
		    +TB_INT_MUTRIG_SHORT_MODE=1 \
		    +TB_INT_HIT_CHANNEL_LOW=$(PROF_INT_002_PRE_RBCAM_CHANNEL_LOW) \
		    +TB_INT_HIT_CHANNEL_HIGH=$(PROF_INT_002_PRE_RBCAM_CHANNEL_HIGH) \
		    +TB_INT_INJECT_PHASE_CYCLES=$(PROF_INT_002_PRE_RBCAM_INJECT_PHASE_CYCLES) \
		    +TB_INT_INJECT_PULSE_COUNT=$(PROF_INT_002_PRE_RBCAM_INJECT_PULSE_COUNT) \
	    +TB_INT_STABLE_ONLY_EXPORT=0 \
	    +TB_INT_ACTIVE_LANE_COUNT=1 \
	    +TB_INT_ACTIVE_LANE_MASK=1 \
	    -l $(PROF_INT_002_PRE_RBCAM_DIR)/transcript \
	    -do "run -all; quit -f"
	python3 $(TB_INT_ROOT)/script/analyze_pre_rbcam_latency.py \
	    --sim-root $(SIM_ROOT) \
	    --cases $(PROF_INT_002_PRE_RBCAM_CASE) \
	    --hist-dir $(PROF_INT_002_PRE_RBCAM_HIST_DIR) \
	    --hist-formats csv,png
	@tail -n 80 $(PROF_INT_002_PRE_RBCAM_DIR)/transcript
	@grep -q "\*\*\* TEST PASSED \*\*\*" $(PROF_INT_002_PRE_RBCAM_DIR)/transcript
	@if grep -E "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(PROF_INT_002_PRE_RBCAM_DIR)/transcript; then exit 1; fi

run_prof_int_002_pre_rbcam_header_sync_phase_100:
	$(MAKE) run_prof_int_002_pre_rbcam_latency \
	    PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE=header_sync \
	    PROF_INT_002_PRE_RBCAM_INJECT_PHASE_CYCLES=100

run_prof_int_002_pre_rbcam_header_sync_phase_500:
	$(MAKE) run_prof_int_002_pre_rbcam_latency \
	    PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE=header_sync \
	    PROF_INT_002_PRE_RBCAM_INJECT_PHASE_CYCLES=500

run_prof_int_002_pre_rbcam_header_sync_phase_900:
	$(MAKE) run_prof_int_002_pre_rbcam_latency \
	    PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE=header_sync \
	    PROF_INT_002_PRE_RBCAM_INJECT_PHASE_CYCLES=900

run_prof_int_002_pre_rbcam_header_sync_phase_sweep_100_900:
	@set -e; for phase in $(PROF_INT_002_PRE_RBCAM_PHASE_SWEEP); do \
	    $(MAKE) run_prof_int_002_pre_rbcam_latency \
	        PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE=header_sync \
	        PROF_INT_002_PRE_RBCAM_INJECT_PHASE_CYCLES=$$phase \
	        PROF_INT_002_PRE_RBCAM_CASE=prof_int_002_pre_rbcam_header_sync_phase$${phase}; \
	done
	python3 $(TB_INT_ROOT)/script/analyze_pre_rbcam_latency.py \
	    --sim-root $(SIM_ROOT) \
	    --cases 'prof_int_002_pre_rbcam_header_sync_phase[1-9]00' \
	    --hist-dir $(PROF_INT_002_PRE_RBCAM_SWEEP_HIST_DIR) \
	    --hist-formats csv,png \
	    --aggregate

run_prof_int_002_pre_rbcam_periodic_2ch:
	$(MAKE) run_prof_int_002_pre_rbcam_latency \
	    PROF_INT_002_PRE_RBCAM_TRAFFIC_MODE=periodic \
	    PROF_INT_002_PRE_RBCAM_INJECT_PULSE_COUNT=0 \
	    PROF_INT_002_PRE_RBCAM_INJECT_PHASE_CYCLES=0

run_prof_int_002_full_pipeline_100khz_per_channel_1lane_5s: comp_prof_int_002 prepare_prof_int_002_mem_init
	@mkdir -p $(PROF_INT_002_DIR_1L_5S)
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -nodpiexports -work $(WORK) $(PROF_INT_002_TOP) \
	    +UVM_TESTNAME=$(PROF_INT_002_TEST) \
	    +ARB_SEED=$(SEED) \
	    +TB_INT_SIM_DIR=$(PROF_INT_002_DIR_1L_5S) \
	    +TB_INT_REQUIRE_ZERO_RESIDUAL=0 \
	    +TB_INT_MIN_CLOSED_PCT=95 \
		    +TB_INT_RUN_CYCLES=$(PROF_INT_002_RUN_CYCLES_5S) \
		    +TB_INT_DRAIN_CYCLES=$(PROF_INT_002_DRAIN_CYCLES_5S) \
		    +TB_INT_STABLE_WINDOW_CYCLES=$(PROF_INT_002_STABLE_WINDOW_CYCLES) \
		    +TB_INT_RUNCTL_CPP_GAP_CYCLES=$(PROF_INT_002_RUNCTL_CPP_GAP_CYCLES) \
		    +TB_INT_RUNCTL_SETTLE_TIMEOUT_CYCLES=$(PROF_INT_002_RUNCTL_SETTLE_TIMEOUT_CYCLES) \
		    +PROF_INT_002_HIT_RATE_Q16=$(PROF_INT_002_HIT_RATE_Q16) \
	    +TB_INT_STABLE_ONLY_EXPORT=$(PROF_INT_002_STABLE_ONLY_EXPORT) \
	    +TB_INT_ACTIVE_LANE_COUNT=1 \
	    +TB_INT_ACTIVE_LANE_MASK=1 \
	    -l $(PROF_INT_002_DIR_1L_5S)/transcript \
	    -do "run -all; quit -f"
	@echo "=== PROF-INT-002 1-lane 5s sim done; CSV at $(PROF_INT_002_DIR_1L_5S)/closed_records.csv ==="
	@echo "=== PROF-INT-002 1-lane 5s transcript: $(PROF_INT_002_DIR_1L_5S)/transcript ==="
	@tail -n 60 $(PROF_INT_002_DIR_1L_5S)/transcript
	@grep -q "\*\*\* TEST PASSED \*\*\*" $(PROF_INT_002_DIR_1L_5S)/transcript
	@if grep -E "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(PROF_INT_002_DIR_1L_5S)/transcript; then exit 1; fi

run_prof_int_002_full_pipeline_100khz_per_channel_8lane_5s: comp_prof_int_002 prepare_prof_int_002_mem_init
	@mkdir -p $(PROF_INT_002_DIR_8L_5S)
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -nodpiexports -work $(WORK) $(PROF_INT_002_TOP) \
	    +UVM_TESTNAME=$(PROF_INT_002_TEST) \
	    +ARB_SEED=$(SEED) \
	    +TB_INT_SIM_DIR=$(PROF_INT_002_DIR_8L_5S) \
	    +TB_INT_REQUIRE_ZERO_RESIDUAL=0 \
	    +TB_INT_MIN_CLOSED_PCT=0 \
		    +TB_INT_RUN_CYCLES=$(PROF_INT_002_RUN_CYCLES_5S) \
		    +TB_INT_DRAIN_CYCLES=$(PROF_INT_002_DRAIN_CYCLES_5S) \
		    +TB_INT_STABLE_WINDOW_CYCLES=$(PROF_INT_002_STABLE_WINDOW_CYCLES) \
		    +TB_INT_RUNCTL_CPP_GAP_CYCLES=$(PROF_INT_002_RUNCTL_CPP_GAP_CYCLES) \
		    +TB_INT_RUNCTL_SETTLE_TIMEOUT_CYCLES=$(PROF_INT_002_RUNCTL_SETTLE_TIMEOUT_CYCLES) \
		    +PROF_INT_002_HIT_RATE_Q16=$(PROF_INT_002_HIT_RATE_Q16) \
	    +TB_INT_STABLE_ONLY_EXPORT=$(PROF_INT_002_STABLE_ONLY_EXPORT) \
	    +TB_INT_ACTIVE_LANE_COUNT=8 \
	    +TB_INT_ACTIVE_LANE_MASK=ff \
	    -l $(PROF_INT_002_DIR_8L_5S)/transcript \
	    -do "run -all; quit -f"
	@echo "=== PROF-INT-002 8-lane 5s sim done; CSV at $(PROF_INT_002_DIR_8L_5S)/closed_records.csv ==="
	@echo "=== PROF-INT-002 8-lane 5s transcript: $(PROF_INT_002_DIR_8L_5S)/transcript ==="
	@tail -n 60 $(PROF_INT_002_DIR_8L_5S)/transcript
	@grep -q "\*\*\* TEST PASSED \*\*\*" $(PROF_INT_002_DIR_8L_5S)/transcript
	@if grep -E "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(PROF_INT_002_DIR_8L_5S)/transcript; then exit 1; fi

run_prof_int_002_full_pipeline_100khz_per_channel_emulator_full8lane_5s: comp_prof_int_002 prepare_prof_int_002_mem_init
	@mkdir -p $(PROF_INT_002_DIR_EMU_5S)
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -nodpiexports -work $(WORK) $(PROF_INT_002_TOP) \
	    +UVM_TESTNAME=$(PROF_INT_002_TEST) \
	    +ARB_SEED=$(SEED) \
	    +TB_INT_SIM_DIR=$(PROF_INT_002_DIR_EMU_5S) \
	    +TB_INT_REQUIRE_ZERO_RESIDUAL=0 \
	    +TB_INT_MIN_CLOSED_PCT=0 \
		    +TB_INT_RUN_CYCLES=$(PROF_INT_002_RUN_CYCLES_5S) \
		    +TB_INT_DRAIN_CYCLES=$(PROF_INT_002_DRAIN_CYCLES_5S) \
		    +TB_INT_STABLE_WINDOW_CYCLES=$(PROF_INT_002_STABLE_WINDOW_CYCLES) \
		    +TB_INT_RUNCTL_CPP_GAP_CYCLES=$(PROF_INT_002_RUNCTL_CPP_GAP_CYCLES) \
		    +TB_INT_RUNCTL_SETTLE_TIMEOUT_CYCLES=$(PROF_INT_002_RUNCTL_SETTLE_TIMEOUT_CYCLES) \
		    +PROF_INT_002_HIT_RATE_Q16=$(PROF_INT_002_HIT_RATE_Q16) \
	    +TB_INT_STABLE_ONLY_EXPORT=$(PROF_INT_002_STABLE_ONLY_EXPORT) \
	    +TB_INT_ACTIVE_LANE_COUNT=8 \
	    +TB_INT_ACTIVE_LANE_MASK=ff \
	    -l $(PROF_INT_002_DIR_EMU_5S)/transcript \
	    -do "run -all; quit -f"
	@echo "=== PROF-INT-002 emulator/full 5s sim done; CSV at $(PROF_INT_002_DIR_EMU_5S)/closed_records.csv ==="
	@echo "=== PROF-INT-002 emulator/full 5s transcript: $(PROF_INT_002_DIR_EMU_5S)/transcript ==="
	@tail -n 60 $(PROF_INT_002_DIR_EMU_5S)/transcript
	@grep -q "\*\*\* TEST PASSED \*\*\*" $(PROF_INT_002_DIR_EMU_5S)/transcript
	@if grep -E "UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]" $(PROF_INT_002_DIR_EMU_5S)/transcript; then exit 1; fi

plot_prof_int_002_full_pipeline_100khz_per_channel_1lane_5s: run_prof_int_002_full_pipeline_100khz_per_channel_1lane_5s
	@mkdir -p $(PROF_INT_002_REPORT_DIR_1L_5S)
	python3 $(TB_INT_ROOT)/script/plot_tb_int_latency_dislin.py \
	    --sim-root $(SIM_ROOT) \
	    --cases prof_int_002_full_pipeline_100khz_per_channel_1lane_5s \
	    --out-dir $(PROF_INT_002_REPORT_DIR_1L_5S) \
	    --rows-per-page 1 \
	    --title-tag "1-lane virtual MuTRiG 100kHz/ch, 5 s run, 1 s stable window" \
	    --stable-only
	@echo "=== PROF-INT-002 1-lane 5s contact-sheet: $(PROF_INT_002_REPORT_DIR_1L_5S)/contact_sheet_dislin.png ==="

plot_prof_int_002_full_pipeline_100khz_per_channel_8lane_5s: run_prof_int_002_full_pipeline_100khz_per_channel_8lane_5s
	@mkdir -p $(PROF_INT_002_REPORT_DIR_8L_5S)
	python3 $(TB_INT_ROOT)/script/plot_tb_int_latency_dislin.py \
	    --sim-root $(SIM_ROOT) \
	    --cases prof_int_002_full_pipeline_100khz_per_channel_8lane_5s \
	    --out-dir $(PROF_INT_002_REPORT_DIR_8L_5S) \
	    --rows-per-page 1 \
	    --title-tag "8-lane virtual MuTRiG 100kHz/ch, 5 s run, 1 s stable window" \
	    --stable-only
	@echo "=== PROF-INT-002 8-lane 5s contact-sheet: $(PROF_INT_002_REPORT_DIR_8L_5S)/contact_sheet_dislin.png ==="

plot_prof_int_002_full_pipeline_100khz_per_channel_emulator_full8lane_5s: run_prof_int_002_full_pipeline_100khz_per_channel_emulator_full8lane_5s
	@mkdir -p $(PROF_INT_002_REPORT_DIR_EMU_5S)
	python3 $(TB_INT_ROOT)/script/plot_tb_int_latency_dislin.py \
	    --sim-root $(SIM_ROOT) \
	    --cases prof_int_002_full_pipeline_100khz_per_channel_emulator_full8lane_5s \
	    --out-dir $(PROF_INT_002_REPORT_DIR_EMU_5S) \
	    --rows-per-page 1 \
	    --title-tag "emulator/full 8-lane 100kHz/ch, 5 s run, 1 s stable window" \
	    --stable-only
	@echo "=== PROF-INT-002 emulator/full 5s contact-sheet: $(PROF_INT_002_REPORT_DIR_EMU_5S)/contact_sheet_dislin.png ==="

plot_prof_int_002_full_pipeline_100khz_per_channel_5s: \
	plot_prof_int_002_full_pipeline_100khz_per_channel_1lane_5s \
	plot_prof_int_002_full_pipeline_100khz_per_channel_8lane_5s \
	plot_prof_int_002_full_pipeline_100khz_per_channel_emulator_full8lane_5s

run_prof_int_002_full_pipeline_100khz_per_channel_5s: \
	run_prof_int_002_full_pipeline_100khz_per_channel_1lane_5s \
	run_prof_int_002_full_pipeline_100khz_per_channel_8lane_5s \
	run_prof_int_002_full_pipeline_100khz_per_channel_emulator_full8lane_5s

run_prof_int_002_full_pipeline: run_prof_int_002_full_pipeline_100khz_per_channel_5s

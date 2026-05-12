QUESTA_HOME ?= /data1/questaone_sim-2026.1_1/questasim
ETH_LIC_SERVER ?= 8161@lic-mentor.ethz.ch
PYTHON ?= python3

export LM_LICENSE_FILE := $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE := $(LM_LICENSE_FILE)
export SALT_LICENSE_SERVER := $(LM_LICENSE_FILE)

VLIB ?= $(QUESTA_HOME)/linux_x86_64/vlib
VLOG ?= $(QUESTA_HOME)/linux_x86_64/vlog
UVM_SRC ?= $(QUESTA_HOME)/verilog_src/uvm-1.2/src

COSIM_ROOT := $(CURDIR)
COSIM_BUILD_DIR ?= $(COSIM_ROOT)/build
COSIM_WORK ?= cosim_work
FEB_CORUN_DIR ?= $(COSIM_ROOT)/../tb_int/feb_swb_corun
REPORT_DIR ?= $(COSIM_ROOT)/REPORT/sanity_1ms
EXPECTED_HITS ?= 6400

RUN_WINDOW_8NS ?= 125000
HIT_PERIOD_8NS ?= 5000
ASIC_COUNT ?= 8
DRAIN_SWB_CYCLES ?= 800000

COSIM_SV_SOURCES := \
	$(COSIM_ROOT)/sv/feb_egress_meta_pkg.sv \
	$(COSIM_ROOT)/sv/feb_egress_monitor_pkg.sv \
	$(COSIM_ROOT)/sv/swb_ingress_driver_pkg.sv \
	$(COSIM_ROOT)/sv/swb_ingress_meta_consumer_pkg.sv \
	$(COSIM_ROOT)/sv/cosim_phy_fifo.sv \
	$(COSIM_ROOT)/sv/cosim_packet_steering_monitor.sv \
	$(COSIM_ROOT)/uvm/cosim_scoreboard_pkg.sv \
	$(COSIM_ROOT)/uvm/feb_cosim_env_pkg.sv \
	$(COSIM_ROOT)/uvm/swb_cosim_env_pkg.sv \
	$(COSIM_ROOT)/uvm/sequences/sanity_1ms_periodic_all_channel_seq.sv \
	$(COSIM_ROOT)/uvm/cosim_top_pkg.sv

.PHONY: compile_cosim run_COSIM_SANITY summarize_COSIM_SANITY

compile_cosim:
	mkdir -p $(COSIM_BUILD_DIR)
	cd $(COSIM_BUILD_DIR) && $(VLIB) $(COSIM_WORK)
	cd $(COSIM_BUILD_DIR) && $(VLOG) -sv -mfcu -work $(COSIM_WORK) \
		+define+UVM_NO_DPI +incdir+$(UVM_SRC) \
		$(UVM_SRC)/uvm_pkg.sv $(COSIM_SV_SOURCES)

run_COSIM_SANITY: compile_cosim
	mkdir -p $(REPORT_DIR)
	$(MAKE) -C $(FEB_CORUN_DIR) SHELL=/bin/bash run_swb_corun \
		REPORT_DIR=$(REPORT_DIR) \
		RUN_LOG=$(REPORT_DIR)/run_swb_corun.log \
		SOURCE_MODE=periodic \
		HIT_PERIOD_8NS=$(HIT_PERIOD_8NS) \
		RUN_WINDOW_8NS=$(RUN_WINDOW_8NS) \
		ASIC_COUNT=$(ASIC_COUNT) \
		DRAIN_SWB_CYCLES=$(DRAIN_SWB_CYCLES) \
		ALLOW_DROPS=0 \
		SCAN_ONLY=0
	$(MAKE) summarize_COSIM_SANITY REPORT_DIR=$(REPORT_DIR)

summarize_COSIM_SANITY:
	$(PYTHON) $(COSIM_ROOT)/scripts/summarize_cosim_sanity.py \
		--report-dir $(REPORT_DIR) \
		--output $(REPORT_DIR)/sanity_1ms_summary.md \
		--expected-hits $(EXPECTED_HITS) \
		--hit-period-8ns $(HIT_PERIOD_8NS) \
		--run-window-8ns $(RUN_WINDOW_8NS) \
		--asic-count $(ASIC_COUNT)

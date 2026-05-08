QUESTA_HOME ?= /data1/questaone_sim-2026.1_1/questasim
ETH_LIC_SERVER ?= 8161@lic-mentor.ethz.ch
MUSIP_ROOT ?= /home/yifeng/packages/musip_2604
ROOT := $(MUSIP_ROOT)
include $(ROOT)/tb_int/cases/basic/opq_sources.mk

export LM_LICENSE_FILE := $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE := $(LM_LICENSE_FILE)
export SALT_LICENSE_SERVER := $(LM_LICENSE_FILE)

VLIB ?= $(QUESTA_HOME)/linux_x86_64/vlib
VMAP ?= $(QUESTA_HOME)/linux_x86_64/vmap
VCOM ?= $(QUESTA_HOME)/linux_x86_64/vcom
VLOG ?= $(QUESTA_HOME)/linux_x86_64/vlog
VSIM ?= $(QUESTA_HOME)/linux_x86_64/vsim
QUESTA_INI_PREP := $(ROOT)/tools/ip/prepare_questa_ini.sh
QUESTA_RUNNER := $(ROOT)/tools/ip/run_questa.sh
PYTHON ?= python3

WORK ?= work
MUSIP_UVM_ROOT ?= /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm
BUILD_ROOT ?= $(CURDIR)/build
REPORT_DIR ?= $(CURDIR)/report
TRACE_ANALYZER := $(CURDIR)/scripts/analyze_feb_swb_trace.py
CORUN_BUILD_DIR := $(BUILD_ROOT)/swb_corun
QUESTA_INI := $(CORUN_BUILD_DIR)/modelsim.ini
RUN_LOG ?= $(REPORT_DIR)/run_swb_corun.log
RUN_DO ?= run -all; quit -f
VCOM_FLAGS := -2008
VLOG_FLAGS := -sv
VSIM_FLAGS := -c -t ps -voptargs=+acc

export QSIM_INI ?= $(QUESTA_INI)

SV_SOURCES := \
	sv/feb_swb_corun_pkg.sv \
	sv/feb_swb_async_fifo.sv \
	sv/feb_swb_parallel_cdc_adapter.sv \
	sv/feb_swb_serial_line_adapter_stub.sv \
	sv/feb_swb_parallel_cdc_adapter_smoke_tb.sv

CORUN_VHDL_SOURCES := \
	$(ROOT)/firmware/util/util_pkg.vhd \
	$(ROOT)/firmware/util/util_slv.vhd \
	$(ROOT)/firmware/util/fifo_reg.vhd \
	$(ROOT)/firmware/util/quartus/ip_ram_2rw.vhd \
	$(ROOT)/firmware/util/quartus/ip_scfifo_v2.vhd \
	$(ROOT)/firmware/util/histogram_generic_half_rate.vhd \
	$(ROOT)/firmware/registers/mudaq.vhd \
	$(ROOT)/firmware/registers/a10_pcie_registers.vhd \
	$(ROOT)/firmware/registers/a10_counters.vhd \
	$(ROOT)/firmware/a10_board/a10/link/mu3e_pkg.vhd \
	$(ROOT)/firmware/a10_board/a10/link/link32_scfifo.vhd \
	$(ROOT)/firmware/a10_board/a10/chip_lookup.vhd \
	$(ROOT)/firmware/a10_board/a10/data_generator_a10.vhd \
	$(ROOT)/firmware/a10_board/a10/run_control_link_listener.vhd \
	$(ROOT)/firmware/a10_board/a10/run_control.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/hit_compactor.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/word_rate.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/mux_4_1_256.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/subtime_merger.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/musip_event_builder.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/swb_data_demerger.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/swb_sc_main.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/swb_sc_secondary.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/qc_histos.vhd \
	$(OPQ_VHDL_DUT_SOURCES) \
	$(OPQ_ADAPTOR_VHDL_SOURCE) \
	$(ROOT)/firmware/a10_board/a10/swb/musip_mux_4_1.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/swb_block.vhd \
	$(ROOT)/tb_int/cases/basic/uvm/dut/swb_block_uvm_wrapper.vhd

CORUN_SV_SOURCES := \
	$(CURDIR)/sv/feb_swb_corun_pkg.sv \
	$(CURDIR)/sv/feb_swb_async_fifo.sv \
	$(CURDIR)/sv/feb_swb_parallel_cdc_adapter.sv \
	$(CURDIR)/sv/feb_swb_corun_plain_tb.sv

CORUN_COMPILE_STAMP := $(CORUN_BUILD_DIR)/.compile-stamp.$(OPQ_SOURCE_MODE).$(OPQ_N_SHD).$(OPQ_LANE_FIFO_DEPTH).$(OPQ_TICKET_FIFO_DEPTH).$(OPQ_HANDLE_FIFO_DEPTH).$(OPQ_PAGE_RAM_DEPTH)

.PHONY: compile compile_musip_driver smoke compile_swb_corun run_swb_corun clean

compile: clean
	$(VLIB) $(WORK)
	$(VLOG) -sv -work $(WORK) $(SV_SOURCES)

compile_musip_driver: clean
	$(VLIB) $(WORK)
	$(VLOG) -sv -work $(WORK) \
	    $(MUSIP_UVM_ROOT)/sv/interfaces.sv \
	    sv/feb_swb_musip_uvm_driver.sv

smoke: compile
	$(VSIM) -c -lib $(WORK) feb_swb_parallel_cdc_adapter_smoke_tb -do "run -all; quit -f"

compile_swb_corun: $(CORUN_COMPILE_STAMP)

$(CORUN_COMPILE_STAMP): $(CORUN_VHDL_SOURCES) $(OPQ_SIM_QSYS_TOP_VHDL_SOURCES) $(OPQ_SIM_QSYS_VHDL_SOURCES) $(OPQ_SIM_QSYS_VERILOG_SOURCES) $(CORUN_SV_SOURCES) $(QUESTA_INI_PREP)
	rm -rf $(CORUN_BUILD_DIR)
	mkdir -p $(CORUN_BUILD_DIR)
	$(QUESTA_INI_PREP) $(QUESTA_HOME) $(QUESTA_INI)
	cd $(CORUN_BUILD_DIR) && QSIM_INI=$(QUESTA_INI) $(VLIB) work
	cd $(CORUN_BUILD_DIR) && set -e; for lib in $(OPQ_SIM_EXTRA_LIBS); do QSIM_INI=$(QUESTA_INI) $(VLIB) $$lib; QSIM_INI=$(QUESTA_INI) $(VMAP) $$lib $$lib; done
	cd $(CORUN_BUILD_DIR) && if [ -n "$(strip $(OPQ_SIM_QSYS_COMPONENT_SYNTH_DIRS))" ]; then \
	    set -e; \
	    for dir in $(OPQ_SIM_QSYS_COMPONENT_SYNTH_DIRS); do \
	        lib="$(OPQ_QSYS_TOP_LIB)_$$(basename "$$(dirname "$$dir")")"; \
	        vhd_files=$$(find "$$dir" -type f -name '*.vhd' | sort); \
	        if [ -n "$$vhd_files" ]; then \
	            QSIM_INI=$(QUESTA_INI) $(VCOM) $(VCOM_FLAGS) -work $$lib $$vhd_files; \
	        fi; \
	    done; \
	    for dir in $(OPQ_SIM_QSYS_COMPONENT_SYNTH_DIRS); do \
	        lib="$(OPQ_QSYS_TOP_LIB)_$$(basename "$$(dirname "$$dir")")"; \
	        vlog_files=$$(find "$$dir" -type f \( -name '*.v' -o -name '*.sv' \) ! -name '*_cfg.v' | sort); \
	        if [ -n "$$vlog_files" ]; then \
	            QSIM_INI=$(QUESTA_INI) $(VLOG) $(VLOG_FLAGS) -work $$lib $(OPQ_DUT_DEFINES) $$vlog_files; \
	        fi; \
	    done; \
	    for dir in $(OPQ_SIM_QSYS_COMPONENT_SYNTH_DIRS); do \
	        lib="$(OPQ_QSYS_TOP_LIB)_$$(basename "$$(dirname "$$dir")")"; \
	        cfg_files=$$(find "$$dir" -type f -name '*_cfg.v' | sort); \
	        if [ -n "$$cfg_files" ]; then \
	            QSIM_INI=$(QUESTA_INI) $(VLOG) $(VLOG_FLAGS) -work $$lib $(OPQ_DUT_DEFINES) $$cfg_files; \
	        fi; \
	    done; \
	else \
	    set -e; \
	    for file in $(OPQ_SIM_QSYS_VHDL_SOURCES); do QSIM_INI=$(QUESTA_INI) $(VCOM) $(VCOM_FLAGS) -work $(OPQ_SIM_QSYS_LIB) $$file; done; \
	    if [ -n "$(strip $(OPQ_SIM_QSYS_VERILOG_SOURCES))" ]; then QSIM_INI=$(QUESTA_INI) $(VLOG) $(VLOG_FLAGS) -work $(OPQ_SIM_QSYS_LIB) $(OPQ_DUT_DEFINES) $(OPQ_SIM_QSYS_VERILOG_SOURCES); fi; \
	fi
	cd $(CORUN_BUILD_DIR) && if [ -n "$(strip $(OPQ_SIM_QSYS_TOP_VHDL_SOURCES))" ]; then set -e; for file in $(OPQ_SIM_QSYS_TOP_VHDL_SOURCES); do QSIM_INI=$(QUESTA_INI) $(VCOM) $(VCOM_FLAGS) -work $(OPQ_SIM_QSYS_TOP_LIB) $$file; done; fi
	cd $(CORUN_BUILD_DIR) && set -e; for file in $(CORUN_VHDL_SOURCES); do QSIM_INI=$(QUESTA_INI) $(VCOM) $(VCOM_FLAGS) $$file; done
	cd $(CORUN_BUILD_DIR) && QSIM_INI=$(QUESTA_INI) $(VLOG) $(VLOG_FLAGS) $(OPQ_DUT_DEFINES) $(CORUN_SV_SOURCES)
	touch $@

run_swb_corun: compile_swb_corun
	mkdir -p $(REPORT_DIR)
	cd $(CORUN_BUILD_DIR) && set -o pipefail; \
	QSIM_INI=$(QUESTA_INI) $(QUESTA_RUNNER) $(VSIM) $(VSIM_FLAGS) $(OPQ_VSIM_LIB_FLAGS) feb_swb_corun_plain_tb -do "$(RUN_DO)" +FEB_SWB_TRACE_DIR=$(abspath $(REPORT_DIR)) | tee "$(RUN_LOG)"
	grep -q "FEB_SWB_CORUN_PLAIN_PASS" "$(RUN_LOG)"
	$(PYTHON) $(TRACE_ANALYZER) --trace-dir "$(REPORT_DIR)"

clean:
	rm -rf $(WORK) $(BUILD_ROOT) transcript vsim.wlf

QUESTA_HOME ?= /data1/questaone_sim/questasim
ETH_LIC_SERVER := 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE := $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE := $(LM_LICENSE_FILE)
export SALT_LICENSE_SERVER := $(LM_LICENSE_FILE)

PATH := $(QUESTA_HOME)/linux_x86_64:$(PATH)

VLIB ?= vlib
VLOG ?= vlog
VSIM ?= vsim
RG ?= rg

MODE ?= broken
WORK ?= work_upload_backpressure_$(MODE)
SIM_ROOT ?= sim_upload_backpressure
TRANSCRIPT ?= $(SIM_ROOT)/$(MODE)/transcript

TB_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SYSTEM_ROOT := $(abspath $(TB_DIR)/../..)
GEN_DIR := $(SYSTEM_ROOT)/syn/feb_system_v3/synthesis/submodules

COMMON_GEN_SRC := \
	$(GEN_DIR)/feb_system_v3_upload_subsystem_upload_pkt_mux.sv

BROKEN_GEN_SRC := \
	$(GEN_DIR)/feb_system_v3_avalon_st_adapter_timing_adapter_0.sv \
	$(GEN_DIR)/feb_system_v3_avalon_st_adapter_data_format_adapter_0.sv \
	$(GEN_DIR)/feb_system_v3_avalon_st_adapter.v

TB_SRC := $(TB_DIR)/tb_feb_upload_backpressure.sv

ifeq ($(MODE),broken)
VLOG_DEFS := +define+FEB_UPLOAD_BROKEN_ADAPTER
VSIM_ARGS := +EXPECT_BROKEN=1
GEN_SRC := $(BROKEN_GEN_SRC) $(COMMON_GEN_SRC)
else ifeq ($(MODE),direct)
VLOG_DEFS := +define+FEB_UPLOAD_DIRECT_READY
VSIM_ARGS := +EXPECT_FIXED=1
GEN_SRC := $(COMMON_GEN_SRC)
else
$(error MODE must be broken or direct)
endif

.PHONY: run compile

modelsim.ini:
	cp $(QUESTA_HOME)/modelsim.ini modelsim.ini

$(WORK): modelsim.ini
	test -d $(WORK) || $(VLIB) $(WORK)

compile: $(WORK)
	$(VLOG) -modelsimini modelsim.ini -sv -work $(WORK) $(VLOG_DEFS) $(GEN_SRC) $(TB_SRC)

run: compile
	mkdir -p $(dir $(TRANSCRIPT))
	$(VSIM) -modelsimini modelsim.ini -c -suppress 19 -suppress 3009 -work $(WORK) tb_feb_upload_backpressure $(VSIM_ARGS) -l $(TRANSCRIPT) -do "run -all; quit -f"
	$(RG) "UPLOAD_BACKPRESSURE_(BROKEN_REPRO|FIXED_PASS)" $(TRANSCRIPT)

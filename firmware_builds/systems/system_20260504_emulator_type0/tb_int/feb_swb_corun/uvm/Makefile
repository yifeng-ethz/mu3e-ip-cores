QUESTA_HOME ?= /data1/questaone_sim-2026.1_1/questasim
ETH_LIC_SERVER ?= 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE := $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE := $(LM_LICENSE_FILE)
export SALT_LICENSE_SERVER := $(LM_LICENSE_FILE)

VLIB ?= $(QUESTA_HOME)/linux_x86_64/vlib
VMAP ?= $(QUESTA_HOME)/linux_x86_64/vmap
VLOG ?= $(QUESTA_HOME)/linux_x86_64/vlog
VSIM ?= $(QUESTA_HOME)/linux_x86_64/vsim

WORK ?= work_feb_swb_uvm
MODELSIM_INI ?= questa.ini
UVM_HOME ?= $(QUESTA_HOME)/verilog_src/uvm-1.2
UVM_SRC := $(UVM_HOME)/src/uvm_pkg.sv
UVM_INCDIR := +incdir+$(UVM_HOME)/src
INI_OPT := -ini $(MODELSIM_INI)
VLOG_OPTS := -sv -work $(WORK) -timescale 1ns/1ps +define+UVM_NO_DPI
VSIM_OPTS := $(INI_OPT) -c -suppress 19 -suppress 3009 -nodpiexports -work $(WORK)

SV_SOURCES := \
	feb_swb_corun_if.sv \
	feb_swb_corun_uvm_pkg.sv \
	tb_top.sv

.PHONY: compile smoke clean

compile:
	test -f $(MODELSIM_INI) || $(VMAP) -c
	rm -rf $(WORK)
	$(VLIB) $(WORK)
	$(VMAP) $(INI_OPT) work $(WORK)
	$(VLOG) $(INI_OPT) $(VLOG_OPTS) $(UVM_INCDIR) $(UVM_SRC)
	$(VLOG) $(INI_OPT) $(VLOG_OPTS) $(UVM_INCDIR) $(SV_SOURCES)

smoke: compile
	$(VSIM) $(VSIM_OPTS) tb_top \
	    +UVM_TESTNAME=feb_swb_corun_base_test \
	    +FEB_SWB_SELF_SMOKE \
	    -do "run -all; quit -f"

clean:
	rm -rf $(WORK) $(MODELSIM_INI) transcript vsim.wlf

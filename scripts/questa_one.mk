QUESTA_HOME_ALLOWED := /data1/questaone_sim/questasim
QUESTA_HOME ?= $(QUESTA_HOME_ALLOWED)
QUESTA_LICENSE_SERVER ?= 8161@lic-mentor.ethz.ch
ETH_LIC_SERVER ?= $(QUESTA_LICENSE_SERVER)
ETH_MENTOR_SERVER ?= $(QUESTA_LICENSE_SERVER)

ifneq ($(QUESTA_HOME),$(QUESTA_HOME_ALLOWED))
$(error Unsupported QUESTA_HOME=$(QUESTA_HOME). Use $(QUESTA_HOME_ALLOWED) only)
endif

VLIB := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlib $(QUESTA_HOME)/linux_x86_64/vlib))
VMAP := $(firstword $(wildcard $(QUESTA_HOME)/bin/vmap $(QUESTA_HOME)/linux_x86_64/vmap))
VCOM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vcom $(QUESTA_HOME)/linux_x86_64/vcom))
VLOG := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlog $(QUESTA_HOME)/linux_x86_64/vlog))
VSIM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vsim $(QUESTA_HOME)/linux_x86_64/vsim))
VOPT := $(firstword $(wildcard $(QUESTA_HOME)/bin/vopt $(QUESTA_HOME)/linux_x86_64/vopt))
VCOVER := $(firstword $(wildcard $(QUESTA_HOME)/bin/vcover $(QUESTA_HOME)/linux_x86_64/vcover))
LMUTIL := $(firstword $(wildcard $(QUESTA_HOME)/bin/lmutil $(QUESTA_HOME)/linux_x86_64/lmutil))
QRUN := $(firstword $(wildcard $(QUESTA_HOME)/bin/qrun $(QUESTA_HOME)/linux_x86_64/qrun))
QUESTA_FLAVOR := $(notdir $(QUESTA_HOME))
QSIM_INI := $(QUESTA_HOME)/modelsim.ini
QUESTA_MODELSIM_INI := $(QSIM_INI)

QUESTA_INTEL_VHDL_LIBS := $(firstword $(wildcard $(QUESTA_HOME)/intel_2026/vhdl $(QUESTA_HOME)/intel/vhdl))
QUARTUS_SIM_LIB ?= /data1/intelFPGA_pro/23.1/quartus/eda/sim_lib
QUESTA_UVM_HOME := $(patsubst %/src/uvm_pkg.sv,%,$(firstword $(wildcard $(QUESTA_HOME)/verilog_src/uvm-1.2/src/uvm_pkg.sv $(QUESTA_HOME)/uvm-1.2/src/uvm_pkg.sv)))
QUESTA_UVM_SRC := $(QUESTA_UVM_HOME)/src
QUESTA_UVM_DPI_SO := $(firstword $(wildcard $(QUESTA_UVM_HOME)/linux_x86_64/uvm_dpi.so $(QUESTA_HOME)/uvm-1.2/linux_x86_64/uvm_dpi.so $(QUESTA_HOME)/verilog_src/uvm-1.2/linux_x86_64/uvm_dpi.so))
QUESTA_UVM_DPI_LIB := $(basename $(QUESTA_UVM_DPI_SO))

export QUESTA_HOME
export QSIM_INI
export SALT_LICENSE_SERVER := $(QUESTA_LICENSE_SERVER)
export MGLS_LICENSE_FILE := $(QUESTA_LICENSE_SERVER)
export LM_LICENSE_FILE := $(QUESTA_LICENSE_SERVER)

ifeq ($(strip $(VLIB)),)
$(error Questa One 2026 vlib not found under $(QUESTA_HOME))
endif

ifeq ($(strip $(QUESTA_UVM_HOME)),)
$(error UVM 1.2 installation not found under $(QUESTA_HOME))
endif

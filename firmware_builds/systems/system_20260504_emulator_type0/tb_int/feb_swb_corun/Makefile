QUESTA_HOME ?= /data1/questaone_sim-2026.1_1/questasim
ETH_LIC_SERVER ?= 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE := $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE := $(LM_LICENSE_FILE)
export SALT_LICENSE_SERVER := $(LM_LICENSE_FILE)

VLIB ?= $(QUESTA_HOME)/linux_x86_64/vlib
VLOG ?= $(QUESTA_HOME)/linux_x86_64/vlog
VSIM ?= $(QUESTA_HOME)/linux_x86_64/vsim

WORK ?= work
MUSIP_UVM_ROOT ?= /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm

SV_SOURCES := \
	sv/feb_swb_corun_pkg.sv \
	sv/feb_swb_async_fifo.sv \
	sv/feb_swb_parallel_cdc_adapter.sv \
	sv/feb_swb_serial_line_adapter_stub.sv \
	sv/feb_swb_parallel_cdc_adapter_smoke_tb.sv

.PHONY: compile compile_musip_driver smoke clean

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

clean:
	rm -rf $(WORK) transcript vsim.wlf

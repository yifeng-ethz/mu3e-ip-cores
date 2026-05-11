#

CABLE:=DE5
CABLE_DEVICE:=^10A
# Keep this project rooted at a10_board/ to avoid BUILD_DIR path confusion.
BUILD_DIR ?= .
PREFIX ?= generated

VERILOG_MACROS += \
    SYNTHESIS=1 \
    OPQ_USE_NATIVE_SV \
    OPQ_N_LANE=4 \
    OPQ_N_SHD=128 \
    OPQ_N_HIT=255 \
    OPQ_TICKET_FIFO_DEPTH=1024 \
    OPQ_PAGE_RAM_DEPTH=65536

OPQ_SOURCE_ROOT ?= /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/packet_scheduler
OPQ_QSYS_DIR := a10/merger/qsys/opq_upstream_4lane_native_sv
OPQ_QSYS_HW_TCL := $(OPQ_QSYS_DIR)/ordered_priority_queue_native_sv_fixed4_hw.tcl
OPQ_QSYS_TCL := $(OPQ_QSYS_DIR)/opq_upstream_4lane.tcl
OPQ_QSYS_FILE := $(OPQ_QSYS_DIR)/opq_upstream_4lane.qsys
OPQ_QSYS_QIP := $(OPQ_QSYS_DIR)/generated/opq_upstream_4lane.qip
OPQ_PACKAGED_SOURCES := \
    $(OPQ_SOURCE_ROOT)/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_dut_sv.sv \
    $(OPQ_SOURCE_ROOT)/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic.sv \
    $(OPQ_SOURCE_ROOT)/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic_block_path.sv \
    $(OPQ_SOURCE_ROOT)/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic_frame_table_presenter.sv \
    $(OPQ_SOURCE_ROOT)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_basic_presenter.sv \
    $(OPQ_SOURCE_ROOT)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_frame_table_tracker.sv \
    $(OPQ_SOURCE_ROOT)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_ingress_parser.sv \
    $(OPQ_SOURCE_ROOT)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_page_allocator.sv \
    $(OPQ_SOURCE_ROOT)/syn/quartus/opq_native_sv_4lane_signoff/src_compat/handle_fifo.v \
    $(OPQ_SOURCE_ROOT)/syn/quartus/opq_native_sv_4lane_signoff/src_compat/lane_fifo.v \
    $(OPQ_SOURCE_ROOT)/syn/quartus/opq_native_sv_4lane_signoff/src_compat/page_ram.v \
    $(OPQ_SOURCE_ROOT)/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ticket_fifo.v \
    $(OPQ_SOURCE_ROOT)/rtl/sv_ver/vendor/alt_ram/frame_table.v \
    $(OPQ_SOURCE_ROOT)/rtl/sv_ver/vendor/alt_ram/tile_fifo.v
QSYS_SCRIPT ?= $(QUARTUS_ROOTDIR)/sopc_builder/bin/qsys-script
QSYS_GENERATE ?= $(QUARTUS_ROOTDIR)/sopc_builder/bin/qsys-generate

IPs = \
    $(wildcard a10/ip/*.tcl) \
    $(wildcard a10/pcieapp/*.tcl) \
    $(wildcard a10/*.vhd.envsubst) \
    nios.tcl

include util/quartus/makefile.mk
include scripts/local_overrides.mk

.PHONY : opq_qsys_unpack opq_qsys_regen
opq_qsys_unpack : $(OPQ_QSYS_QIP)

$(OPQ_QSYS_FILE) : $(OPQ_QSYS_TCL) $(OPQ_QSYS_HW_TCL)
	test -f "$(OPQ_SOURCE_ROOT)/VERSION"
	( cd "$(OPQ_QSYS_DIR)" && OPQ_SOURCE_ROOT="$(OPQ_SOURCE_ROOT)" "$(QSYS_SCRIPT)" --search-path=".,$$" --script="$(notdir $(OPQ_QSYS_TCL))" )

$(OPQ_QSYS_QIP) : $(OPQ_QSYS_FILE) $(OPQ_QSYS_HW_TCL) $(OPQ_PACKAGED_SOURCES)
	test -f "$(OPQ_SOURCE_ROOT)/VERSION"
	OPQ_SOURCE_ROOT="$(OPQ_SOURCE_ROOT)" "$(QSYS_GENERATE)" --synthesis=VHDL --output-directory="$(OPQ_QSYS_DIR)/generated" --search-path="$(abspath $(OPQ_QSYS_DIR)),$$" "$(OPQ_QSYS_FILE)"

opq_qsys_regen :
	rm -rf -- "$(OPQ_QSYS_DIR)/generated"
	rm -f -- "$(OPQ_QSYS_FILE)" "$(OPQ_QSYS_DIR)/opq_upstream_4lane.sopcinfo"
	$(MAKE) opq_qsys_unpack

all app flow_map : opq_qsys_unpack
flow :: opq_qsys_unpack

flash :
	../../common/firmware/a10_tcl/program.sh

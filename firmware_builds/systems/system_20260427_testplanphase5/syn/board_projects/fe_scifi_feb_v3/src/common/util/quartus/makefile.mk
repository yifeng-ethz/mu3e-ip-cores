#
# author : Alexandr Kozlinskiy
#

.DEFAULT_GOAL := all

.DELETE_ON_ERROR :
.ONESHELL :

ifndef QUARTUS_ROOTDIR
    $(error QUARTUS_ROOTDIR is undefined)
endif

ifeq ($(QUARTUS_OUTPUT_FILES),)
    override QUARTUS_OUTPUT_FILES := output_files
endif

# directory for generated files (*.qsys, *.sopcinfo, etc.)
# TODO: rename PREFIX -> QP_TMP_DIR
ifeq ($(PREFIX),)
    override PREFIX := generated
endif

# location of compiled firmware (SOF file)
ifeq ($(SOF),)
    SOF := $(QUARTUS_OUTPUT_FILES)/top.sof
endif

# location of generated nios.sopcinfo
ifeq ($(NIOS_SOPCINFO),)
    NIOS_SOPCINFO := $(PREFIX)/nios.sopcinfo
endif

# tcl script to generate BSP
# TODO: rename BSP_SCRIPT to NIOS_BSP_SCRIPT
ifeq ($(BSP_SCRIPT),)
    BSP_SCRIPT := software/hal_bsp.tcl
endif

# location (directory) of main.cpp
# TODO: rename SRC_DIR to NIOS_SRC_DIR
ifeq ($(SRC_DIR),)
    SRC_DIR := software
endif

# destination for generated BSP
# TODO: rename BSP_DIR to NIOS_BSP_DIR
ifeq ($(BSP_DIR),)
    BSP_DIR := $(PREFIX)/software/hal_bsp
endif

# destination for compiled software (nios)
# TODO: rename APP_DIR to NIOS_APP_DIR
ifeq ($(APP_DIR),)
    APP_DIR := $(PREFIX)/software/app
endif

# list all .tcl files
# (use absolute path for files outside project directory)
QSYS_TCL_FILES := $(patsubst $(abspath .)/%,%,$(abspath $(filter %.tcl,$(IPs))))
# convert all .tcl files into .qsys files
# (place generated files into $(PREFIX) directory)
QSYS_FILES := $(addprefix $(PREFIX)/,$(patsubst %.tcl,%.qsys,$(QSYS_TCL_FILES)))
# convert all .qsys files into .sopcinfo files
SOPC_FILES := $(patsubst %.qsys,%.sopcinfo,$(QSYS_FILES))
# make list of .vhd.qmegawiz and .vhd.envsubst files
VHD_QMEGAWIZ_FILES := $(patsubst $(abspath .)/%,%,$(abspath $(filter %.vhd.qmegawiz,$(IPs))))
VHD_ENVSUBST_FILES := $(patsubst $(abspath .)/%,%,$(abspath $(filter %.vhd.envsubst,$(IPs))))
# generate list of .vhd files
VHD_FILES := $(addprefix $(PREFIX)/, \
    $(patsubst %.vhd.qmegawiz,%.vhd,$(VHD_QMEGAWIZ_FILES)) \
    $(patsubst %.vhd.envsubst,%.vhd,$(VHD_ENVSUBST_FILES)) \
)

define find_file
$(lastword $(wildcard $(addsuffix $(1),$(dir $(MAKEFILE_LIST)))))
endef

.PHONY : clean
clean :
	rm -rf -- \
	    ./.qsys_edit ./top.qws \
	    ./db ./incremental_db ./$(QUARTUS_OUTPUT_FILES) \
	    ./top.qsf ./top.qpf "./$(PREFIX)"

# default qpf file
top.qpf : top.qsf
	cat << EOF > "$@"
	PROJECT_REVISION = "top"
	EOF

# default qsf file - load top.qip, and generated include.qip
top.qsf : $(MAKEFILE_LIST) $(PREFIX)/include.qip
	cat << EOF > "$@"
	set_global_assignment -name QIP_FILE "top.qip"
	set_global_assignment -name TOP_LEVEL_ENTITY top
	set_global_assignment -name PROJECT_OUTPUT_DIRECTORY "$(QUARTUS_OUTPUT_FILES)"
	set_global_assignment -name SOURCE_TCL_SCRIPT_FILE "$(call find_file,settings.tcl)"
	set_global_assignment -name QIP_FILE "$(PREFIX)/include.qip"
	set_global_assignment -name PRE_FLOW_SCRIPT_FILE "quartus_sh:util/quartus/pre_flow.tcl"
	EOF
	# Optional SignalTap (board projects can set SIGNALTAP_STP=<file.stp>)
	if [ -n "$(SIGNALTAP_STP)" ] ; then
	    [ -e "$(SIGNALTAP_STP)" ] || { echo "ERROR: SIGNALTAP_STP not found: $(SIGNALTAP_STP)" ; exit 1 ; }
	    {
	        echo ""
	        echo "set_global_assignment -name ENABLE_SIGNALTAP ON"
	        echo "set_global_assignment -name USE_SIGNALTAP_FILE $(SIGNALTAP_STP)"
	        echo "set_global_assignment -name SIGNALTAP_FILE $(SIGNALTAP_STP)"
	    } >> "$@"
	fi

all : top.qpf top.qsf
	[ -e "top.srf" ] || ln -sv -- "util/quartus/top.srf"

.PHONY : $(PREFIX)/components_pkg.vhd
$(PREFIX)/components_pkg.vhd : $(SOPC_FILES) $(VHD_FILES)
	mkdir -pv -- "$(PREFIX)"
	# find and exec components_pkg.sh
	$(call find_file,components_pkg.sh) "$(PREFIX)" > "$@"
	[ -x /usr/bin/awk ] && awk -f $(call find_file,components_pkg.awk) "$@"
	# patch generated "altera_pci_express.sdc" files
	$(call find_file,altera_pci_express.sh) "$(PREFIX)"

# include.qip - include all generated files
$(PREFIX)/include.qip : $(PREFIX)/components_pkg.vhd $(QSYS_FILES)
	# components package
	echo "set_global_assignment -name VHDL_FILE [ file join $$::quartus(qip_path) \"components_pkg.vhd\" ]" > "$@"
	# add qsys *.qsys files
	for file in $(patsubst %.qsys,%,$(QSYS_FILES)) ; do
	    QIP="$$file/synthesis/$$(basename -- $$file).qip"
	    if [ -e "$$QIP" ] ; then
	        echo "set_global_assignment -name QIP_FILE [ file join $$::quartus(qip_path) \"$$(realpath -m --relative-to=$(PREFIX) -- $$QIP)\" ]" >> "$@"
	    else
	        echo "set_global_assignment -name QSYS_FILE [ file join $$::quartus(qip_path) \"$$(realpath -m --relative-to=$(PREFIX) -- $$file.qsys)\" ]" >> "$@"
	    fi
	done
	# add *.vhd (*.qip) files
	for file in $(patsubst %.vhd,%,$(VHD_FILES)) ; do
	    [ -e "$$file.qip" ] && echo "set_global_assignment -name QIP_FILE [ file join $$::quartus(qip_path) \"$$(realpath -m --relative-to=$(PREFIX) -- $$file.qip)\" ]" >> "$@"
	    [ -e "$$file.qip" ] || echo "set_global_assignment -name VHDL_FILE [ file join $$::quartus(qip_path) \"$$(realpath -m --relative-to=$(PREFIX) -- $$file.vhd)\" ]" >> "$@"
	done
	# add $(APP_DIR)/mem_init/meminit.qip
	echo "set_global_assignment -name QIP_FILE [ file join $$::quartus(qip_path) \"$$(realpath -m --relative-to=$(PREFIX) -- $(APP_DIR)/mem_init/meminit.qip)\" ]" >> "$@"

# default device.tcl file
device.tcl :
	touch -- "$@"

$(PREFIX)/%.vhd : %.vhd.envsubst
	NAME="$(basename $(notdir $@))" envsubst '$$NAME' < "$<" > "$@"

$(PREFIX)/%.vhd : %.vhd.qmegawiz
	# find and exec qmegawiz.sh
	$(call find_file,qmegawiz.sh) "$<" "$@"

$(PREFIX)/%.qsys : %.tcl device.tcl
	mkdir -pv -- "$(PREFIX)"
	# util link is used by qsys to find _hw.tcl modules
	[ -e $(PREFIX)/util ] || ln -snv --relative -T util $(PREFIX)/util
	# find and exec tcl2qsys.sh (use `awk` to remove timestamp prefix)
	$(call find_file,tcl2qsys.sh) "$<" "$@" 2>&1 | awk '{ sub(/^([0-9]+[.:]?)+ /, "") ; print $0 }'

$(PREFIX)/%.sopcinfo : $(PREFIX)/%.qsys
	# find and exec qsys-generate.sh
	$(call find_file,qsys-generate.sh) "$<" 2>&1 | awk '{ sub(/^([0-9]+[.:]?)+ /, "") ; print $0 }'

.PHONY : pre_flow
pre_flow :
	# generate components_pkg.vhd
	$(call find_file,components_pkg.sh) "$(PREFIX)" > "$(PREFIX)/components_pkg.vhd"

.PHONY : flow
flow : all
	# If SignalTap is configured, let quartus_stp generate the required QSF/HDL
	if [ -n "$(SIGNALTAP_STP)" ] ; then
	    quartus_stp top --enable --signaltap --stp_file="$(SIGNALTAP_STP)" -c top
	fi
	# find and exec flow.sh
	$(call find_file,flow.sh)

.PHONY : flow_map
flow_map : all
	quartus_map top

.PHONY : post_flow
post_flow :

update_mif :
	quartus_cdb top --update_mif
	quartus_asm top

.PRECIOUS : $(BSP_DIR)/settings.bsp
$(BSP_DIR)/settings.bsp : $(BSP_SCRIPT) $(NIOS_SOPCINFO) $(MAKEFILE_LIST)
	mkdir -pv -- "$(BSP_DIR)"
	LD_LIBRARY_PATH="$(QUARTUS_ROOTDIR)/linux64:$(LD_LIBRARY_PATH)" \
	nios2-bsp-create-settings \
	    --type hal --script "$(SOPC_KIT_NIOS2)/sdk2/bin/bsp-set-defaults.tcl" \
	    --sopc $(NIOS_SOPCINFO) --cpu-name cpu \
	    --bsp-dir "$(BSP_DIR)" --settings "$(BSP_DIR)/settings.bsp" --script "$(BSP_SCRIPT)"
	$(MAKE) -C "$(BSP_DIR)" clean

.PRECIOUS : $(APP_DIR)/Makefile
$(APP_DIR)/Makefile : $(BSP_DIR)/settings.bsp $(SRC_DIR)/*
	QUARTUS_VERSION=$(shell quartus_sh -v | awk '/^Version/{print $$2}')
	if [[ "$$QUARTUS_VERSION" < 20.0 ]] ; then
	    NIOS2_CFLAGS_STD="-std=c++14"
	fi
	nios2-app-generate-makefile \
	    --set ALT_CFLAGS "$$NIOS2_CFLAGS_STD -Wall -Wextra -Wformat=0 -Os" \
	    --bsp-dir "$(BSP_DIR)" --src-dir "$(SRC_DIR)" \
	    --app-dir "$(APP_DIR)" --elf-name main.elf
	$(MAKE) -C "$(APP_DIR)" clean

.PRECIOUS : $(APP_DIR)/main.elf
.PHONY : $(APP_DIR)/main.elf
$(APP_DIR)/main.elf : $(APP_DIR)/Makefile
	$(MAKE) -C "$(BSP_DIR)"
	$(MAKE) -C "$(APP_DIR)"

$(APP_DIR)/main.srec : $(APP_DIR)/main.elf
	nios2-elf-objcopy "$(APP_DIR)/main.elf" -O srec "$(APP_DIR)/main.srec"

.PHONY : app
app : $(APP_DIR)/main.elf
	# generate mem_init/*.hex files (see AN730 / HEX File Generation)
	$(MAKE) -C "$(APP_DIR)" mem_init_generate
	mkdir -pv -- "$(QUARTUS_OUTPUT_FILES)"
	cp -av -- "$(APP_DIR)/mem_init/nios_ram.hex" "$(QUARTUS_OUTPUT_FILES)/"




.PHONY : pgm
pgm : $(SOF)
	CABLE="$(CABLE)"
	[ -n "$(CABLE_DEVICE)" ] && CABLE=$$($(call find_file,jtagconfig_match.sh) "$(CABLE)" "$(CABLE_DEVICE)")
	[ -n "$${CABLE:+x}" ] || exit 1
	quartus_pgm -m jtag -c "$$CABLE" --operation="p;$(SOF)"

.PHONY : app_upload
app_upload : $(APP_DIR)/main.srec
	CABLE="$(CABLE)"
	[ -n "$(CABLE_DEVICE)" ] && CABLE=$$($(call find_file,jtagconfig_match.sh) "$(CABLE)" "$(CABLE_DEVICE)")
	[ -n "$${CABLE:+x}" ] || exit 1
	nios2-gdb-server -c "$$CABLE" -r -w 1 -g "$(APP_DIR)/main.srec"

app_gdb :
	CABLE="$(CABLE)"
	[ -n "$(CABLE_DEVICE)" ] && CABLE=$$($(call find_file,jtagconfig_match.sh) "$(CABLE)" "$(CABLE_DEVICE)")
	[ -n "$${CABLE:+x}" ] || exit 1
	PORT=$$(hexdump -n 2 -e '/2 "%u"' /dev/urandom)
	nios2-gdb-server --cable "$$CABLE" --tcpport "$$PORT" --tcptimeout 2 &
	nios2-elf-gdb \
	    --eval-command="target remote :$$PORT" \
	    --eval-command="set confirm off" \
	    --eval-command="set pagination off" \
	    "$(APP_DIR)/main.elf"

.PHONY : terminal
terminal :
	CABLE="$(CABLE)"
	[ -n "$(CABLE_DEVICE)" ] && CABLE=$$($(call find_file,jtagconfig_match.sh) "$(CABLE)" "$(CABLE_DEVICE)")
	[ -n "$${CABLE:+x}" ] || exit 1
	nios2-terminal -c "$$CABLE"

quartus : top.qpf
	quartus top.qpf &> /dev/null &

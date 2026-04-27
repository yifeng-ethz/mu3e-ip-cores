#
# tdomConfig.sh --
# 
# This shell script (for Bourne sh and alike) is generated 
# automatically by tDOM configure script. It will create 
# shell variables for some of the configuration options 
# discovered by the configure. This script is intended to be
# sourced by the configure scripts for tDOM extensions so 
# that they don't have to figure this all out for themselves.
# This file does not duplicate information already provided
# by tclConfig.sh, so you may need to use that file in addition
# to this one. To be able to locate this file easily, extensions
# might want to include the tdom.m4 file in their configure
# scripts and use the TDOM_PATH_CONFIG and TDOM_LOAD_CONFIG.
#
# The information in this file is specific to a single platform.
#

#
# tDOM version number
#
TDOM_VERSION='0.9.4'

# The name of the TDOM library (may be either a .a file or a shared library):
TDOM_LIB_FILE=libtdom0.9.4.so

#
# The name of the tDOM stub library file
#
TDOM_STUB_LIB_FILE=libtdomstub0.9.4.a

#
# String to pass to linker to pick up the tDOM library from
# its build directory.
#
TDOM_BUILD_STUB_LIB_SPEC='-L/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/system_console/lib/tdom-0.9.4-src -ltdomstub0.9.4'

#
# String to pass to linker to pick up the tDOM library from
# its installed directory.
#
TDOM_STUB_LIB_SPEC='-L/usr/lib64/tdom0.9.4 -ltdomstub0.9.4'

# String to pass to linker to pick up the TDOM stub library from its
# build directory.
#
TDOM_BUILD_STUB_LIB_PATH='/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/system_console/lib/tdom-0.9.4-src/libtdomstub0.9.4.a'

# String to pass to linker to pick up the TDOM stub library from its
# installed directory.
#
TDOM_STUB_LIB_PATH='/usr/lib64/tdom0.9.4/libtdomstub0.9.4.a'

#
# Location of the top-level source directories from which tDOM
# was built.  This is the directory that contains generic, unix,
# win etc. If tDOM was compiled in a different place than the 
# directory containing the source files, this points to the 
# location of the sources, not the location where tDOM was compiled.
#
TDOM_SRC_DIR='.'

# EOF

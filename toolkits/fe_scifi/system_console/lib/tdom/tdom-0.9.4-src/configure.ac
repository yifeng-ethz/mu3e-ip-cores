#!/bin/bash -norc
dnl	This file is an input file used by the GNU "autoconf" program to
dnl	generate the file "configure", which is run during Tcl installation
dnl	to configure the system for the local environment.

#-----------------------------------------------------------------------
# Sample configure.ac for Tcl Extensions.  The only places you should
# need to modify this file are marked by the string __CHANGE__
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# __CHANGE__
# Set your package name and version numbers here.
#
# This initializes the environment with PACKAGE_NAME and PACKAGE_VERSION
# set as provided.  These will also be added as -D defs in your Makefile
# so you can encode the package version directly into the source files.
# This will also define a special symbol for Windows (BUILD_<PACKAGE_NAME>
# so that we create the export library with the dll.
#-----------------------------------------------------------------------

AC_INIT([tdom],[0.9.4])

#--------------------------------------------------------------------
# Call TEA_INIT as the first TEA_ macro to set up initial vars.
# This will define a ${TEA_PLATFORM} variable == "unix" or "windows"
# as well as PKG_LIB_FILE and PKG_STUB_LIB_FILE.
#--------------------------------------------------------------------

TEA_INIT()

AC_CONFIG_AUX_DIR(tclconfig)

#--------------------------------------------------------------------
# Load the tclConfig.sh file
#--------------------------------------------------------------------

TEA_PATH_TCLCONFIG
TEA_LOAD_TCLCONFIG

#--------------------------------------------------------------------
# Load the tkConfig.sh file if necessary (Tk extension)
#--------------------------------------------------------------------

#TEA_PATH_TKCONFIG
#TEA_LOAD_TKCONFIG

#-----------------------------------------------------------------------
# Handle the --prefix=... option by defaulting to what Tcl gave.
# Must be called after TEA_LOAD_TCLCONFIG and before TEA_SETUP_COMPILER.
#-----------------------------------------------------------------------

TEA_PREFIX

#-----------------------------------------------------------------------
# Standard compiler checks.
# This sets up CC by using the CC env var, or looks for gcc otherwise.
# This also calls AC_PROG_CC and a few others to create the basic setup
# necessary to compile executables.
#-----------------------------------------------------------------------

TEA_SETUP_COMPILER

#-----------------------------------------------------------------------
# Those two are needed for compiling expat.
#-----------------------------------------------------------------------

AC_CHECK_FUNCS(memmove bcopy)

#--------------------------------------------------------------------
# Add optional AOLserver includes
#--------------------------------------------------------------------

TDOM_PATH_AOLSERVER

#--------------------------------------------------------------------
# Add shared expat includes and expat entropy
#--------------------------------------------------------------------

TDOM_PATH_EXPAT
TDOM_EXPAT_ENTROPY

#--------------------------------------------------------------------
# We need the UINT2PTR and PTR2UINT macros, so make sure that intptr_t
# is defined.
#--------------------------------------------------------------------

AC_CHECK_TYPE([uintptr_t], [
    AC_DEFINE([HAVE_UINTPTR_T], 1, [Do we have the uintptr_t type?])], [
    AC_CACHE_CHECK([for pointer-size unsigned integer type], tcl_cv_uintptr_t, [
    for tcl_cv_uintptr_t in "unsigned int" "unsigned long" "unsigned long long" \
	    none; do
	if test "$tcl_cv_uintptr_t" != none; then
	    AC_COMPILE_IFELSE([AC_LANG_BOOL_COMPILE_TRY([AC_INCLUDES_DEFAULT],
		    [[sizeof (void *) <= sizeof ($tcl_cv_uintptr_t)]])],
		[tcl_ok=yes], [tcl_ok=no])
	    test "$tcl_ok" = yes && break; fi
    done])
    if test "$tcl_cv_uintptr_t" != none; then
	AC_DEFINE_UNQUOTED([uintptr_t], [$tcl_cv_uintptr_t], [Unsigned integer
	   type wide enough to hold a pointer.])
    fi
])

#--------------------------------------------------------------------
# Add HTML5 parsing support.
#--------------------------------------------------------------------

TDOM_ENABLE_HTML5

#-----------------------------------------------------------------------
# __CHANGE__
# Specify the C source files to compile in TEA_ADD_SOURCES,
# public headers that need to be installed in TEA_ADD_HEADERS,
# stub library C source files to compile in TEA_ADD_STUB_SOURCES,
# and runtime Tcl library files in TEA_ADD_TCL_SOURCES.
# This defines PKG(_STUB)_SOURCES, PKG(_STUB)_OBJECTS, PKG_HEADERS
# and PKG_TCL_SOURCES.
#-----------------------------------------------------------------------

TEA_ADD_SOURCES([generic/xmlsimple.c \
                 generic/dom.c       \
                 generic/domhtml.c   \
                 generic/domhtml5.c  \
                 generic/domjson.c   \
                 generic/domxpath.c  \
                 generic/domxslt.c   \
                 generic/domlock.c   \
                 generic/tcldom.c    \
                 generic/nodecmd.c   \
                 generic/tdominit.c  \
                 generic/tclexpat.c  \
                 generic/tclpull.c   \
                 generic/schema.c    \
                 generic/datatypes.c \
                 generic/tdomStubInit.c])
TEA_ADD_HEADERS([generic/tdom.h])
TEA_ADD_INCLUDES([-I${srcdir}/generic ${AOL_INCLUDES} ${HTML5_INCLUDES}])
TEA_ADD_LIBS([${AOL_LIBS} ${HTML5_LIBS}])
TEA_ADD_CFLAGS([])
TEA_ADD_STUB_SOURCES([generic/tdomStubLib.c])
TEA_ADD_TCL_SOURCES([lib/tdom.tcl])

#--------------------------------------------------------------------
# __CHANGE__
#
# You can add more files to clean if your extension creates any extra
# files by extending CLEANFILES.
# Add pkgIndex.tcl if it is generated in the Makefile instead of ./configure
# and change Makefile.in to move it from CONFIG_CLEAN_FILES to BINARIES var.
#
# A few miscellaneous platform-specific items:
# TEA_ADD_* any platform specific compiler/build info here.
#--------------------------------------------------------------------

#CLEANFILES="$CLEANFILES pkgIndex.tcl"
if test "${TEA_PLATFORM}" = "windows" ; then
    # Ensure no empty if clauses
    :
    #TEA_ADD_SOURCES([win/winFile.c])
    #TEA_ADD_INCLUDES([-I\"$(${CYGPATH} ${srcdir}/win)\"])
    CLEANFILES="$CLEANFILES *.ilk vc*.pch"
else
    # Ensure no empty else clauses
    :
    #TEA_ADD_SOURCES([unix/unixFile.c])
    #TEA_ADD_LIBS([-lsuperfly])
    CLEANFILES="$CLEANFILES tdom.tcl tcldomsh"
fi

#--------------------------------------------------------------------
# __CHANGE__
# Choose which headers you need.  Extension authors should try very
# hard to only rely on the Tcl public header files.  Internal headers
# contain private data structures and are subject to change without
# notice.
# This MUST be called after TEA_LOAD_TCLCONFIG / TEA_LOAD_TKCONFIG
#--------------------------------------------------------------------

TEA_PUBLIC_TCL_HEADERS
#TEA_PRIVATE_TCL_HEADERS

#TEA_PUBLIC_TK_HEADERS
#TEA_PRIVATE_TK_HEADERS
#TEA_PATH_X

#--------------------------------------------------------------------
# Check whether --enable-threads or --disable-threads was given.
# This auto-enables if Tcl was compiled threaded.
#--------------------------------------------------------------------

TEA_ENABLE_THREADS

#--------------------------------------------------------------------
# The statement below defines a collection of symbols related to
# building as a shared library instead of a static library.
#--------------------------------------------------------------------

TEA_ENABLE_SHARED

#--------------------------------------------------------------------
# This macro figures out what flags to use with the compiler/linker
# when building shared/static debug/optimized objects.  This information
# can be taken from the tclConfig.sh file, but this figures it all out.
#--------------------------------------------------------------------

TEA_CONFIG_CFLAGS

TDOM_LD_SEARCH_FLAGS=${LD_SEARCH_FLAGS}
AC_SUBST(TDOM_LD_SEARCH_FLAGS)

#--------------------------------------------------------------------
# Set the default compiler switches based on the --enable-symbols option.
#--------------------------------------------------------------------

TEA_ENABLE_SYMBOLS

#--------------------------------------------------------------------
# This macro generates a line to use when building a library.  It
# depends on values set by the TEA_ENABLE_SHARED, TEA_ENABLE_SYMBOLS,
# and TEA_LOAD_TCLCONFIG macros above.
#--------------------------------------------------------------------

TEA_MAKE_LIB

#--------------------------------------------------------------------
# Determine the name of the tclsh and/or wish executables in the
# Tcl and Tk build directories or the location they were installed
# into. These paths are used to support running test cases only,
# the Makefile should not be making use of these paths to generate
# a pkgIndex.tcl file or anything else at extension build time.
#--------------------------------------------------------------------

TEA_PROG_TCLSH
#TEA_PROG_WISH

#--------------------------------------------------------------------
# Add some private preprocessor options
#--------------------------------------------------------------------

TDOM_ENABLE_DTD
# If we expose XML_GetInputContext() at script level
#TDOM_CONTEXT_BYTES
AC_DEFINE(XML_CONTEXT_BYTES, 0)
AC_DEFINE(XML_GE, 1)
TDOM_ENABLE_NS
TDOM_ENABLE_UNKNOWN
TDOM_ENABLE_TDOMALLOC
TDOM_ENABLE_LESS_NS
TDOM_ENABLE_SCHEMA

TDOMSHELL=tcldomsh
AC_SUBST(TDOMSHELL)

TDOM_EXPORT_CONFIG

#--------------------------------------------------------------------
# Finally, substitute all of the various values into the Makefile.
# You may alternatively have a special pkgIndex.tcl.in or other files
# which require substituting the AC variables in. Include these here.
#--------------------------------------------------------------------

AC_CONFIG_FILES([Makefile pkgIndex.tcl tdomConfig.sh])
AC_OUTPUT

# all.tcl --
#
# This file contains a top-level script to run all of the Tcl
# tests.  Execute it by invoking "tclsh all.test".
#
# Copyright (c) 1998-1999 by Scriptics Corporation.
# All rights reserved.
#
# RCS: @(#) $Id$
# 

source [file join [file dir [info script]] loadschemadtx.tcl]

singleProcess 1
configure {*}$argv -testdir [file dirname [info script]]
runAllTests
# See http://mini.net/tcl/3248 for an explanation.
proc exit args {}

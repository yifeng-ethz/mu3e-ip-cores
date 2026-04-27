catch {load ../../../unix/libtdom0.9.2.so}
catch {load ../libschemadtx1.0.so}
catch {load ../../unix/libtdom0.9.2.so}
catch {load libschemadtx1.0.so}
# loadschemadtx.tcl --
#
# This file is [source]d by all.tcl and all test files, to ensure, that
# the tcltest package and the lastest schemadtx build is present.

if {[lsearch [namespace children] ::tcltest] == -1} {
    package require tcltest
    namespace import ::tcltest::*
}

if {[catch {package present tdom}]} {
    package require tdom 0.9.2
}

if {[catch {package require tnc}]} {
    package require schemadtx
}


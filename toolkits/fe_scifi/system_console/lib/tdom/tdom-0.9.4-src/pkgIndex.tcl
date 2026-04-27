#
# Tcl package index file
#
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded tdom 0.9.4 \
        "[list load [file join $dir libtcl9tdom0.9.4.so]];
         [list source [file join $dir tdom.tcl]]"
} else {
    package ifneeded tdom 0.9.4 \
        "[list load [file join $dir libtdom0.9.4.so]];
         [list source [file join $dir tdom.tcl]]"
}

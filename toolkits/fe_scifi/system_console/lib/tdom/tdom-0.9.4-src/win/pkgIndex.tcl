#
# Tcl package index file
#
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded tdom 0.9.4 \
        "[list load [file join $dir tcl9tdom094.dll]];
         [list source [file join $dir tdom.tcl]]"
} else {
    package ifneeded tdom 0.9.4 \
        "[list load [file join $dir tdom094.dll]];
         [list source [file join $dir tdom.tcl]]"
}

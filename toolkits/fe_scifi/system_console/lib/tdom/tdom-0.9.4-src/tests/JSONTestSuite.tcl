# The code in this file refers to the work done by:
#
# Parsing JSON is a Minefield
# http://seriot.ch/parsing_json.php
# https://github.com/nst/JSONTestSuite
#
# The dir argument should point to the test_parsing directory of that
# repository

package require tdom

if {$argc > 1} {
    error "usage: $argv0 ?testdir?"
}

if {$argc} {
    set path [lindex $argv 0]
    if {[file isdirectory $path]} {
        set dir $path
    } else {
        set file $path
    }
} else {
    set path ""
    set dir [pwd]
}

set skipfile [list]
# Not all chars allowed in JSON strings are allowed as element names
# or in XML char data.
foreach file {
    y_string_escaped_control_character.json
    y_string_null_escape.json
    y_string_allowed_escapes.json
    y_object_empty_key.json
    y_object_escaped_null_in_key.json
} {
    lappend skipfile $file
}
# UTF-8 edge cases and outside of BMP chars, for which tcl IO already
# did the wrong thing. Or misuse of tcl internal string rep as if it
# would be canonical UTF-8 (which it is not).
foreach file {
    y_string_nonCharacterInUTF-8_U+FFFF.json
    y_string_nonCharacterInUTF-8_U+1FFFF.json
    n_string_unescaped_crtl_char.json    
} {
    lappend skipfile $file
}

foreach test [glob -directory $path "n_*"] {
    if {[file tail $test] in $skipfile} continue
    set fd [open $test]
    set input [read $fd]
    close $fd
    set result [catch {dom parse -json -jsonroot json -- $input}]
    if {!$result} {
        puts $test
    }
}

foreach test [glob -directory $path "y_*"] {
    if {[file tail $test] in $skipfile} continue
    set fd [open $test]
    set input [read $fd]
    close $fd
    set result [catch {dom parse -json -jsonroot json -- $input} errMsg]
    if {$result} {
        puts "$test $errMsg"
    }
}

# The 'some say so, some so' cases. Ignore result, just ensure no seg
# fault */
foreach test [glob -directory $path "i_*"] {
    set fd [open $test]
    set input [read $fd]
    close $fd
    catch {dom parse -json -jsonroot json -- $input}
}

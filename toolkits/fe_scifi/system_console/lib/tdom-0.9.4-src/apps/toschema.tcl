# This is a (too) simple DTD to tDOM schema converter.
#
# It should work for not namespaced document types and namespaced
# document types with the elements in a default namespace. In case of
# namespaced document types with prefixed elements the generated
# schema file will not be usable, but may be a starting point.

package require tdom
package require uri

variable dtdStart ""
variable dtdFinished 0
variable indent 4

proc indent {} {
    variable indent
    upvar level level
    return [string repeat " " [expr {$indent * $level}]]
}

proc fromDTD_serialize {level type quant name content} {
    variable nslookup
    
    switch $type {
        "NAME" {
            set parts [split $name :]
            if {[llength $parts] == 2 && [info exists nslookup([lindex $parts 0])]} {
                puts "[indent]namespace $nslookup([lindex $parts 0]) {"
                incr level
                puts "[indent]element [lindex $parts 1] $quant"
                incr level -1
                puts "[indent]}"
            } else {
                puts "[indent]element $name $quant"
            }
            return
        }
        "MIXED" {
            if {[llength $content] == 0} {
                puts "[indent]text"
                return
            }
            puts "[indent]mixed \{"
        }
        "EMPTY" {
            return
        }
        "ANY" {
            puts "[indent]ANY\}"
            return
        }
        "SEQ" {
            if {$level == 1 && $quant eq ""} {
                # At least directly below defelement there isn't any
                # need to wrap a ! SEQ into a group container -
                # defelement children are already processed as sequence
                # while validating.
                foreach cp $content {
                    fromDTD_serialize $level {*}$cp
                }
                return
            } else {
                puts "[indent]group $quant \{"
            }
        }
        "CHOICE" {
            puts "[indent]choice $quant \{"
        }
    }
    foreach cp $content {
        fromDTD_serialize [expr {$level +1}] {*}$cp
    }
    puts "[indent]\}"
}
    
proc fromDTD_generate {} {
    variable dtdStart
    variable dtdElements
    variable dtdAttributes
    variable nslookup
    
    if {$dtdStart ne ""} {
        if {![info exists dtdElements($dtdStart)]} {
            puts "Document element not defined."
            exit 1
        }
        set ns ""
        foreach {attkey attDef} [array get dtdAttributes $dtdStart,*] {
            lassign $attDef attname type default isRequired
            if {$attname eq "xmlns"} {
                set ns $default
            }
        }
        if {$ns eq ""} {
            puts "start $dtdStart"
        } else {
            puts "start $dtdStart $ns"
        }
    }
    set elements [lsort [array names dtdElements]]
    set startInd [lsearch -exact $elements $dtdStart]
    set elements [lreplace $elements $startInd $startInd]
    set elements [linsert $elements 0 $dtdStart]
    set level 1
    foreach name $elements {
        # First round over attributes to get possible namespace
        # declarations
        foreach {attkey attDef} [array get dtdAttributes $name,*] {
            lassign $attDef attname type default isRequired
            if {$attname eq "xmlns"} {
                if {$default ne ""} {
                    set nslookup(:default) $default
                }
            } else {
                set parts [split $attname ":"]
                if {[llength $parts] == 2} {
                    switch [lindex $parts 0] {
                        "xml" {
                            set nslookup(xml) "http://www.w3.org/XML/1998/namespace"
                        }
                        "xmlns" {
                            if {$default ne ""} {
                                set nslookup([lindex $parts 1]) $default
                            }
                        }
                    }
                }
            }
        }
        # Heuristic to get namespace right
        set namespace ""
        if {[info exists nslookup(:default)] && $nslookup(:default) ne ""} {
            set namespace $nslookup(:default)
        }
        set parts [split $name ":"]
        set schemaName $name
        if {[llength $parts] == 2} {
            set prefix [lindex $parts 0]
            if {[info exists nslookup($prefix)]} {
                set namespace $nslookup($prefix)
                set schemaName [lindex $parts 1]
            } else {
                # Hmmm. Either dtd error or the namespace is
                # defined somewhere on the ancestors. To be
                # handled. TODO
            }
        }
        if {$namespace ne ""} {
            puts "defelement $schemaName $namespace \{"
        } else {
            puts "defelement $schemaName \{"
        }
        # Second round over attributes for the actualy attribute
        # declarations.
        foreach {attkey attDef} [array get dtdAttributes $name,*] {
            lassign $attDef attname type default isRequired
            set parts [split $attname ":"]
            if {[llength $parts] == 2} {
                set prefix [lindex $parts 0]
                if {$prefix eq "xmlns"} continue
                if {![info exists nslookup($prefix)]} {
                    # Hmmm. Either dtd error or the namespace is
                    # defined somewhere on the ancestors. To be
                    # handled. TODO
                    set cmd "attribute $attname"
                } else {
                    set cmd "nsattribute [lindex $parts 1] $nslookup($prefix)"
                }
            } else {
                if {$attname eq "xmlns"} continue
                set cmd "attribute $attname"
            }
            if {$isRequired && $default != ""} {
                puts "[indent]$cmd ? {[list "fixed" $default]}"
                continue
            }
            switch $type {
                "ENTITY" -
                "ENTITIES" -
                "NOTATION" {
                    # All above to be done
                    puts "[indent]$cmd [expr {$isRequired ? "" : "?"}]"
                }
                "NMTOKEN" {
                    puts "[indent]$cmd [expr {$isRequired ? "" : "?"}] \{nmtoken\}"
                }
                "ID" {
                    puts "[indent]$cmd [expr {$isRequired ? "" : "?"}] \{nmtoken;id\}"
                }
                "IDREF" {
                    puts "[indent]$cmd [expr {$isRequired ? "" : "?"}] \{idref\}"
                }
                "IDREFS" {
                    puts "[indent]$cmd [expr {$isRequired ? "" : "?"}] \{split \{idref\}\}"
                }
                "NMTOKENS" {
                    puts "[indent]$cmd [expr {$isRequired ? "" : "?"}] \{nmtokens\}"
                }
                "CDATA" {
                    puts "[indent]$cmd [expr {$isRequired ? "" : "?"}]"
                }
                default {
                    if {[string index $type 0] ne "("} {
                        # Ups. Should not happen.
                        error "Unexpeced (invalid) attribute type '$type'"
                    } 
                    puts "[indent]$cmd [expr {$isRequired ? "" : "?"}] {enumeration {[split [string trim $type "()"] "|"]}}"
                }
            }
        }
        fromDTD_serialize 1 {*}$dtdElements($name)
        puts "\}"
    }
}

proc fromDTD_startDoctypeDecl {name systemID publicID hasInternalSubset} {
    variable dtdStart $name
    variable dtdFinished 0
}

proc fromDTD_endDoctypeDecl {args} {
    variable dtdFinished 1

    fromDTD_generate
}

proc fromDTD_elementDecl {name content} {
    variable dtdElements

    set dtdElements($name) $content
}

proc fromDTD_attlistDecl {elname name type default isRequired} {
    variable dtdAttributes

    set dtdAttributes($elname,$name) [list $name $type $default $isRequired]
}

proc fromDTD {file} {

    ::xml::parser p \
        -baseurl [tdom::baseURL $file] \
        -paramentityparsing always \
        -externalentitycommand tdom::extRefHandler \
        -startdoctypedeclcommand fromDTD_startDoctypeDecl \
        -enddoctypedeclcommand fromDTD_endDoctypeDecl \
        -elementdeclcommand fromDTD_elementDecl \
        -attlistdeclcommand fromDTD_attlistDecl
        
    p parse [tdom::xmlReadFile $file]
}

proc usage {} {
    puts "$argv0 <XML-with-DTD>"
}

proc run {args} {
    if {[llength $args] == 1} {
        set file [lindex $args 0]
        if {![file readable $file] || ![file isfile $file]} {
            puts stderr "Can't open '$file'"
            exit 1
        }
        set needToGuess 0
        switch [file extension $file] {
            ".xml" {
                fromDTD $file
            }
            default {
                set needToGuess 1
            }
        }
        if {$needToGuess} {
            # Just probe everything we have in no specific order
            foreach reader {
                fromDTD
            } {
                if {![catch {$reader $file}]} {
                    return
                }
            }
        }
        return
    }
    usage
}

run {*}$argv


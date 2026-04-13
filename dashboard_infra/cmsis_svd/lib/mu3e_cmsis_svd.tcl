package require Tcl 8.5

namespace eval ::mu3e::cmsis::svd {}

proc ::mu3e::cmsis::svd::xml_escape {value} {
    return [string map {
        & &amp;
        < &lt;
        > &gt;
        \" &quot;
        ' &apos;
    } $value]
}

proc ::mu3e::cmsis::svd::parse_kv_args {defaults args} {
    set out $defaults

    if {[expr {[llength $args] % 2}] != 0} {
        error "expected -key value pairs"
    }

    foreach {key value} $args {
        if {![string match "-*" $key]} {
            error "argument $key must start with '-'"
        }
        dict set out [string range $key 1 end] $value
    }

    return $out
}

proc ::mu3e::cmsis::svd::normalize_access {value} {
    set key [string tolower [string trim $value]]
    set out [dict create access $value]

    switch -- $key {
        "" {
            dict set out access ""
        }
        "ro" -
        "read-only" {
            dict set out access "read-only"
        }
        "wo" -
        "write-only" {
            dict set out access "write-only"
        }
        "rw" -
        "read-write" -
        "rw/ro" {
            dict set out access "read-write"
        }
        "rw1c" -
        "w1c" {
            dict set out access "read-write"
            dict set out modifiedWriteValues "oneToClear"
        }
        "rw1s" -
        "w1s" {
            dict set out access "read-write"
            dict set out modifiedWriteValues "oneToSet"
        }
        "rw1t" -
        "w1t" {
            dict set out access "read-write"
            dict set out modifiedWriteValues "oneToToggle"
        }
        default {
            dict set out access $value
        }
    }

    return $out
}

proc ::mu3e::cmsis::svd::field {name bit_offset bit_width args} {
    set spec [::mu3e::cmsis::svd::parse_kv_args [dict create \
        description "" \
        access "" \
        modifiedWriteValues "" \
        readAction ""] {*}$args]
    set access_map [::mu3e::cmsis::svd::normalize_access [dict get $spec access]]

    dict set spec name $name
    dict set spec bitOffset $bit_offset
    dict set spec bitWidth $bit_width
    dict set spec access [dict get $access_map access]

    if {[dict get $spec modifiedWriteValues] eq "" &&
        [dict exists $access_map modifiedWriteValues]} {
        dict set spec modifiedWriteValues \
            [dict get $access_map modifiedWriteValues]
    }

    return $spec
}

proc ::mu3e::cmsis::svd::register {name address_offset args} {
    set spec [::mu3e::cmsis::svd::parse_kv_args [dict create \
        description "" \
        size "" \
        access "" \
        resetValue "" \
        resetMask "" \
        modifiedWriteValues "" \
        readAction "" \
        fields {}] {*}$args]
    set access_map [::mu3e::cmsis::svd::normalize_access [dict get $spec access]]

    dict set spec name $name
    dict set spec addressOffset $address_offset
    dict set spec access [dict get $access_map access]

    if {[dict get $spec modifiedWriteValues] eq "" &&
        [dict exists $access_map modifiedWriteValues]} {
        dict set spec modifiedWriteValues \
            [dict get $access_map modifiedWriteValues]
    }

    return $spec
}

proc ::mu3e::cmsis::svd::peripheral {name base_address args} {
    set spec [::mu3e::cmsis::svd::parse_kv_args [dict create \
        description "" \
        groupName "" \
        addressBlockOffset 0x0 \
        addressBlockSize "" \
        addressBlockUsage "registers" \
        registers {}] {*}$args]

    dict set spec name $name
    dict set spec baseAddress $base_address
    return $spec
}

proc ::mu3e::cmsis::svd::device {name args} {
    set spec [::mu3e::cmsis::svd::parse_kv_args [dict create \
        schemaVersion "1.3" \
        vendor "Mu3e" \
        vendorID "MU3E" \
        series "MU3E_FPGA_IP" \
        version "0.0.0" \
        description "" \
        addressUnitBits 8 \
        width 32 \
        size 32 \
        access "read-write" \
        resetValue 0x00000000 \
        resetMask 0xFFFFFFFF \
        peripherals {}] {*}$args]
    set access_map [::mu3e::cmsis::svd::normalize_access [dict get $spec access]]

    dict set spec name $name
    dict set spec access [dict get $access_map access]
    return $spec
}

proc ::mu3e::cmsis::svd::word_window_registers {count args} {
    set spec [::mu3e::cmsis::svd::parse_kv_args [dict create \
        prefix "WORD" \
        startIndex 0 \
        startOffset 0x0 \
        stride 4 \
        descriptionPrefix "Window word" \
        fieldDescriptionPrefix "Raw window word" \
        access "read-only"] {*}$args]
    set regs {}
    set count_int [expr {int($count)}]
    set start_index [expr {int([dict get $spec startIndex])}]
    set start_offset [expr {int([dict get $spec startOffset])}]
    set stride [expr {int([dict get $spec stride])}]

    for {set idx 0} {$idx < $count_int} {incr idx} {
        set reg_index [expr {$start_index + $idx}]
        set name [format "%s%03d" [dict get $spec prefix] $reg_index]
        set offs [format "0x%X" [expr {$start_offset + ($idx * $stride)}]]
        lappend regs [::mu3e::cmsis::svd::register $name $offs \
            -description [format {%s %d.} [dict get $spec descriptionPrefix] $reg_index] \
            -access [dict get $spec access] \
            -fields [list \
                [::mu3e::cmsis::svd::field value 0 32 \
                    -description [format {%s %d.} [dict get $spec fieldDescriptionPrefix] $reg_index] \
                    -access [dict get $spec access]]]]
    }

    return $regs
}

proc ::mu3e::cmsis::svd::emit_scalar {chan indent tag value} {
    if {$value eq ""} {
        return
    }
    puts $chan "${indent}<${tag}>[::mu3e::cmsis::svd::xml_escape $value]</${tag}>"
}

proc ::mu3e::cmsis::svd::emit_field {chan field indent} {
    puts $chan "${indent}<field>"
    set child_indent "${indent}  "

    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent name [dict get $field name]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent description [dict get $field description]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent bitOffset [dict get $field bitOffset]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent bitWidth [dict get $field bitWidth]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent access [dict get $field access]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent modifiedWriteValues \
        [dict get $field modifiedWriteValues]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent readAction \
        [dict get $field readAction]
    puts $chan "${indent}</field>"
}

proc ::mu3e::cmsis::svd::emit_register {chan reg indent} {
    puts $chan "${indent}<register>"
    set child_indent "${indent}  "

    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent name [dict get $reg name]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent description [dict get $reg description]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent addressOffset \
        [dict get $reg addressOffset]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent size [dict get $reg size]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent access [dict get $reg access]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent resetValue \
        [dict get $reg resetValue]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent resetMask \
        [dict get $reg resetMask]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent modifiedWriteValues \
        [dict get $reg modifiedWriteValues]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent readAction \
        [dict get $reg readAction]

    if {[llength [dict get $reg fields]] != 0} {
        puts $chan "${child_indent}<fields>"
        foreach field [dict get $reg fields] {
            ::mu3e::cmsis::svd::emit_field $chan $field "${child_indent}  "
        }
        puts $chan "${child_indent}</fields>"
    }

    puts $chan "${indent}</register>"
}

proc ::mu3e::cmsis::svd::emit_peripheral {chan periph indent} {
    puts $chan "${indent}<peripheral>"
    set child_indent "${indent}  "

    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent name [dict get $periph name]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent description \
        [dict get $periph description]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent groupName \
        [dict get $periph groupName]
    ::mu3e::cmsis::svd::emit_scalar $chan $child_indent baseAddress \
        [dict get $periph baseAddress]

    if {[dict get $periph addressBlockSize] ne ""} {
        puts $chan "${child_indent}<addressBlock>"
        ::mu3e::cmsis::svd::emit_scalar $chan "${child_indent}  " offset \
            [dict get $periph addressBlockOffset]
        ::mu3e::cmsis::svd::emit_scalar $chan "${child_indent}  " size \
            [dict get $periph addressBlockSize]
        ::mu3e::cmsis::svd::emit_scalar $chan "${child_indent}  " usage \
            [dict get $periph addressBlockUsage]
        puts $chan "${child_indent}</addressBlock>"
    }

    puts $chan "${child_indent}<registers>"
    foreach reg [dict get $periph registers] {
        ::mu3e::cmsis::svd::emit_register $chan $reg "${child_indent}  "
    }
    puts $chan "${child_indent}</registers>"
    puts $chan "${indent}</peripheral>"
}

proc ::mu3e::cmsis::svd::to_xml {device} {
    set chan [file tempfile tmpfile]

    puts $chan "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    puts $chan "<device schemaVersion=\"[dict get $device schemaVersion]\" xmlns:xs=\"http://www.w3.org/2001/XMLSchema-instance\" xs:noNamespaceSchemaLocation=\"CMSIS-SVD.xsd\">"
    ::mu3e::cmsis::svd::emit_scalar $chan "  " vendor [dict get $device vendor]
    ::mu3e::cmsis::svd::emit_scalar $chan "  " vendorID [dict get $device vendorID]
    ::mu3e::cmsis::svd::emit_scalar $chan "  " name [dict get $device name]
    ::mu3e::cmsis::svd::emit_scalar $chan "  " series [dict get $device series]
    ::mu3e::cmsis::svd::emit_scalar $chan "  " version [dict get $device version]
    ::mu3e::cmsis::svd::emit_scalar $chan "  " description [dict get $device description]
    ::mu3e::cmsis::svd::emit_scalar $chan "  " addressUnitBits \
        [dict get $device addressUnitBits]
    ::mu3e::cmsis::svd::emit_scalar $chan "  " width [dict get $device width]
    ::mu3e::cmsis::svd::emit_scalar $chan "  " size [dict get $device size]
    ::mu3e::cmsis::svd::emit_scalar $chan "  " access [dict get $device access]
    ::mu3e::cmsis::svd::emit_scalar $chan "  " resetValue [dict get $device resetValue]
    ::mu3e::cmsis::svd::emit_scalar $chan "  " resetMask [dict get $device resetMask]
    puts $chan "  <peripherals>"
    foreach periph [dict get $device peripherals] {
        ::mu3e::cmsis::svd::emit_peripheral $chan $periph "    "
    }
    puts $chan "  </peripherals>"
    puts $chan "</device>"

    seek $chan 0 start
    set xml [read $chan]
    close $chan
    file delete -force $tmpfile
    return $xml
}

proc ::mu3e::cmsis::svd::write_device_file {device path} {
    set chan [open $path w]
    fconfigure $chan -translation lf
    puts -nonewline $chan [::mu3e::cmsis::svd::to_xml $device]
    close $chan
}

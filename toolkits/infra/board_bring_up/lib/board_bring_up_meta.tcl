package require Tcl 8.5

namespace eval ::board_bring_up::meta {}

proc ::board_bring_up::meta::field {name description bit_range access} {
        return [dict create \
                name $name \
                description $description \
                bit_range $bit_range \
                access $access]
}

proc ::board_bring_up::meta::register {name description address_offset fields args} {
        set reg [dict create \
                name $name \
                description $description \
                address_offset $address_offset \
                fields $fields]
        foreach {key value} $args {
                dict set reg $key $value
        }
        return $reg
}

proc ::board_bring_up::meta::contract {registers} {
        return [dict create registers $registers]
}

proc ::board_bring_up::meta::runtime_version_check {args} {
        if {[expr {[llength $args] % 2}] != 0} {
                error "runtime_version_check expects key/value pairs"
        }

        set spec [dict create encoding common_csr_header_v1]
        foreach {key value} $args {
                dict set spec $key $value
        }
        return $spec
}

proc ::board_bring_up::meta::metadata {metadata_version rtl_version hw_tcl_version contract {runtime_version_check ""}} {
        set metadata [dict create \
                metadata_version $metadata_version \
                rtl_version $rtl_version \
                hw_tcl_version $hw_tcl_version \
                contract $contract]

        if {$runtime_version_check ne ""} {
                dict set metadata runtime_version_check $runtime_version_check
        }
        return $metadata
}

package require Tcl 8.5

namespace eval ::fe_scifi::board_bring_up::csr_meta {}

proc ::fe_scifi::board_bring_up::csr_meta::field {name description bit_range access} {
    return [dict create \
        name $name \
        description $description \
        bit_range $bit_range \
        access $access]
}

proc ::fe_scifi::board_bring_up::csr_meta::register {name description address_offset fields args} {
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

proc ::fe_scifi::board_bring_up::csr_meta::contract {registers} {
    return [dict create registers $registers]
}

proc ::fe_scifi::board_bring_up::csr_meta::runtime_version_check {args} {
    if {[expr {[llength $args] % 2}] != 0} {
        error "runtime_version_check expects key/value pairs"
    }

    set spec [dict create encoding common_csr_header_v1]
    foreach {key value} $args {
        dict set spec $key $value
    }

    return $spec
}

proc ::fe_scifi::board_bring_up::csr_meta::metadata {metadata_version rtl_version hw_tcl_version contract {runtime_version_check ""}} {
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

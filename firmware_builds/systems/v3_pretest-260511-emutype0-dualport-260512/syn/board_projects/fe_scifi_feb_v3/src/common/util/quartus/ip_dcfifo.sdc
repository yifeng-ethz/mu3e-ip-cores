#

# from <https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/ug/ug_fifo.pdf>
# section "Recovery and Removal Timing Violation Warnings when Compiling a DCFIFO"

proc dcfifo_apply_false_path_to {pattern} {
    set nodes [get_keepers -nowarn $pattern]
    if { [get_collection_size $nodes] > 0 } {
        set_false_path -to $nodes
    }
}

dcfifo_apply_false_path_to *dcfifo:dcfifo_component|dcfifo_*:auto_generated|dffpipe_*:wraclr|dffe*a[0]
dcfifo_apply_false_path_to *dcfifo:dcfifo_component|dcfifo_*:auto_generated|dffpipe_*:rdaclr|dffe*a[0]
dcfifo_apply_false_path_to *dcfifo_mixed_widths:dcfifo_component|dcfifo_*:auto_generated|dffpipe_*:wraclr|dffe*a[0]
dcfifo_apply_false_path_to *dcfifo_mixed_widths:dcfifo_component|dcfifo_*:auto_generated|dffpipe_*:rdaclr|dffe*a[0]

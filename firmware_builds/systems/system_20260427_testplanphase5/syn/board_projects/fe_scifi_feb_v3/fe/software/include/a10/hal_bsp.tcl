#

source "software/include/hal_bsp.tcl"

set_driver none flash

# regions
foreach { name slave offset span } [ get_memory_region ram ] {
    set span [ expr $span - 0x100 - 0x40000 ]
    update_memory_region $name $slave $offset $span
    add_memory_region ctrl $slave [ expr $offset + $span         ] [ expr 0x100   ]
    add_memory_region data $slave [ expr $offset + $span + 0x100 ] [ expr 0x40000 ]
    break
}

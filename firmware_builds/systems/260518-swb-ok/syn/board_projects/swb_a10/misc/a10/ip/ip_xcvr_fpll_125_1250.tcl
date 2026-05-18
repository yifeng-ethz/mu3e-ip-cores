#

source "device.tcl"
source "util/altera_ip.tcl"

add_altera_xcvr_fpll_a10 125.0 [ expr 1250 / 2 ]

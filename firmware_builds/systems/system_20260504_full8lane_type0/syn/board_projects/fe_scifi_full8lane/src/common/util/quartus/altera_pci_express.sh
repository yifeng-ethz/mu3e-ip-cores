#!/bin/bash
set -euf

#
# patch generated `altera_pcie_express.sdc` files
#
# `query_collection` returns string (space separated list of objects)
# which must not be treated as tcl list,
# otherwise list access procedures (`lindex`, `foreach`, etc.) may corrupt objects
# (e.g. by stripping `\` symbol)
#

for f in $(find "$1" -name "altera_pci_express.sdc") ; do
    test -w "$f" || continue
    sed -e 's/foreach clk $clk_prefix/foreach clk [split $clk_prefix " "]/' -i -- "$f"
    sed -e 's/lindex \[query_collection $byte_ser_clk_pins\]/lindex [split [query_collection $byte_ser_clk_pins] " "]/' -i -- "$f"
    sed -e 's/foreach clk $byte_ser_clk_pin0/foreach clk [split $byte_ser_clk_pin0 " "]/' -i -- "$f"
done

#!/bin/bash
set -euf

DIR=$(dirname -- "$(readlink -f -- "$0")")

PROJECT_NAME=top

# run Analysis & Synthesis
#quartus_map top
# run Fitter
#quartus_fit top --write_settings_files=off
# run Assembler
#quartus_asm top --write_settings_files=off

quartus_sh -t "$DIR/flow.tcl" "$PROJECT_NAME"

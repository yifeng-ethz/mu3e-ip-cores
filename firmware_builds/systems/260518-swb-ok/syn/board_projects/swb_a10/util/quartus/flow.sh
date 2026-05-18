#!/bin/bash
set -euf
set -o pipefail

DIR=$(dirname -- "$(readlink -f -- "$0")")

PROJECT_NAME="${1:-top}"

# run Analysis & Synthesis
#quartus_map top
# run Fitter
#quartus_fit top --write_settings_files=off
# run Assembler
#quartus_asm top --write_settings_files=off

GREP_PATTERNS=(
    -e "altera_xcvr_functions\.sv"
    -e "alt_xcvr_csr_selector\.sv"
)

quartus_sh -t "$DIR/flow.tcl" "$PROJECT_NAME" 2>&1 \
| grep --line-buffered -v "${GREP_PATTERNS[@]}" \
| awk -f "$DIR/flow.awk"

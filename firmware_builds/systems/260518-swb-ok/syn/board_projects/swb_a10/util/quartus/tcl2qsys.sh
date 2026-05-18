#!/bin/bash
set -euf
export LC_ALL=C

TCL=$1
QSYS=$2

QSYS_DIR=$(dirname -- "$QSYS")
mkdir -p -- "$QSYS_DIR"

# use tcl file basename as system name
NAME=$(basename -- "$TCL")
NAME=${NAME%.*}

CMD=(
    "package require qsys;"
    "create_system {$NAME};"
    "source {$TCL};"
    "save_system {$QSYS};"
)

QSYS_SEARCH_PATH="${QSYS_SEARCH_PATH:-.}"',$'

exec \
qsys-script \
    --search-path="$QSYS_SEARCH_PATH" \
    --cmd="${CMD[*]}" \
    --script="./util/quartus/tcl2qsys.tcl"

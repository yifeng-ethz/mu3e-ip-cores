#!/bin/sh
set -euf
export LC_ALL=C

QSYS=$1

QSYS_DIR=$(dirname -- "$QSYS")

QSYS_SEARCH_PATH="${QSYS_SEARCH_PATH:-.}"',$'

exec \
qsys-generate \
    --synthesis=VHDL \
    --output-directory="$QSYS_DIR/" \
    --search-path="$QSYS_SEARCH_PATH" \
    "$QSYS"

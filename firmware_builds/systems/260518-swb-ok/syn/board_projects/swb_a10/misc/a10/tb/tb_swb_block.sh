#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH
cd "$(dirname -- "$(readlink -e -- "$0")")" || exit 1

export STOPTIME=50ns

entity=$(basename "$0" .sh)

../../util/sim.sh "$entity" "$entity.vhd" \
    *.vhd ../*.vhd ../../util/*.vhd ../../util/quartus/*.vhd \
    ../../registers/*.vhd ../link/*.vhd ../swb/*.vhd ../../../../fe_board/firmware/FEB_common/*.vhd \
    ../../../../fe_board/fe/sc_rx.vhd ../pcieapp/*.vhd

#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH
cd "$(dirname -- "$(readlink -e -- "$0")")" || exit 1

export STOPTIME=10us

entity=$(basename "$0" .sh)

../../util/sim.sh "$entity.vhd" \
    ./*.vhd ../*.vhd ../../util/*.vhd \
    ../../../../fe_board/fe/sc_rx.vhd ../../../../fe_board/firmware/FEB_common/*.vhd ../../registers/*.vhd ../../util/quartus/*.vhd

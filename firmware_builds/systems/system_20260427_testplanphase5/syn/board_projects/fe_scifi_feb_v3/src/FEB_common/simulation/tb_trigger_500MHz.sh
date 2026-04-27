#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH
cd "$(dirname -- "$(readlink -e -- "$0")")" || exit 1

export STOPTIME=80us

entity=$(basename "$0" .sh)

../../../../common/firmware/util/sim.sh "$entity.vhd" \
    ../*.vhd ../../../fe/registers/mudaq.vhd \
    ../../../../common/firmware/util/*.vhd \
    ../../../../common/firmware/util/quartus/*.vhd
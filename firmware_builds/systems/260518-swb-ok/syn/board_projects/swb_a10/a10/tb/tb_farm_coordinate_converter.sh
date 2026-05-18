#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH
cd "$(dirname -- "$(readlink -e -- "$0")")" || exit 1

export STOPTIME=80ns

entity=$(basename "$0" .sh)

../../util/sim.sh "$entity.vhd" \
    ./*.vhd ../*.vhd ../../util/*.vhd ../../util/quartus/*.vhd \
    ../../registers/*.vhd ../ddr/*.vhd \
    ../swb/*.vhd ../farm/*.vhd ../ddr/tb/*.vhd \
    ../../../../farm_pc/farm_ddr4/generated/a10/ip/ip_madd/altera_fpdsp_block_180/synth/*.sv \
    ../../../../farm_pc/farm_ddr4/generated/a10/ip/ip_madd/altera_fpdsp_block_180/synth/*.vhd

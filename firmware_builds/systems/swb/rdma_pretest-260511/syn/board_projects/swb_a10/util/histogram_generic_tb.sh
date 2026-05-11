#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH
cd "$(dirname -- "$(readlink -e -- "$0")")" || exit 1

export STOPTIME=20us

./sim.sh histogram_generic_tb.vhd ./*.vhd ./quartus/*.vhd

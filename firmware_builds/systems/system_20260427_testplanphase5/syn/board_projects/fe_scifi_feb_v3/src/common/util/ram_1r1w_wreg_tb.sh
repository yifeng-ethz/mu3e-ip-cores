#!/bin/sh
set -eu

STOP_TIME_US=1 \
./sim.sh "$0" ./*.vhd

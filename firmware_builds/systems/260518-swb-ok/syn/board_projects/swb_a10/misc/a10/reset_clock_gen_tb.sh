#!/bin/bash

STOP_TIME_US=1 \
../util/sim.sh "$0" \
    ./*.vhd ../util/*.vhd

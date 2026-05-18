#!/bin/bash

STOP_TIME_US=2 \
../sim.sh "$0" ./*.vhd ../*.vhd \
    ../quartus/*.vhd

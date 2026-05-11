#!/bin/bash
set -eu

export STOPTIME=400us

../sim.sh --no-gtkwave "$0" ./*.vhd ../*.vhd

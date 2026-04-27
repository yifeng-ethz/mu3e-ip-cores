#!/bin/sh

export STOPTIME=8us

../sim.sh "$0" ./*.vhd ../*.vhd

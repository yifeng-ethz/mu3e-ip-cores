#!/bin/sh

export STOPTIME=1us

../sim.sh "$0" ./*.vhd ../*.vhd

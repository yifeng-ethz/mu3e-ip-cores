#!/bin/sh
set -euf
export LC_ALL=C

# generate Altera IP using qmegawiz

# qmegawiz takes IP parameters from XML embedded into VHDL
VHD_QMEGAWIZ=$1
VHD=$2

# copy source VHDL (XML) file to new location
VHD_DIR=$(dirname -- "$VHD")
mkdir -p -- "$VHD_DIR"
cp -- "$VHD_QMEGAWIZ" "$VHD"

# run qmegawiz from destination directory
cd -- "$VHD_DIR" || exit 1
VHD=$(basename -- "$VHD")
exec \
qmegawiz -silent "$VHD"

#!/bin/sh

SOF="output_files/top.sof"

# convert sof file into flash file
sof2flash --pfl --programmingmode=PS \
    --optionbit=0x00030000 \
    --input="$(SOF)" \
    --output="$(SOF).flash" --offset=0x02B40000
objcopy -Isrec -Obinary "$(SOF).flash" "$(SOF).bin"

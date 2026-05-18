#

vlib work
vmap work work

vcom -work work ../quartus/ip_ram_2rw.vhd
vcom -work work histogram_generic_half_rate.vhd
vcom -work work histogram_generic.vhd
vcom -work work histogram_generic_tb.vhd

set TOP_LEVEL_NAME histogram_generic_tb

vsim -L altera_mf histogram_generic_tb
do wave_histogram_generic.do
run 20 us

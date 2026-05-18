# M.Mueller, Feb 2023, script for sc_tb

vlib work
quit -sim
vcom -2008 ../../../../common/firmware/util/util_slv.vhd
vcom -2008 ../../../../common/firmware/registers/mudaq.vhd
vcom -2008 ../../../../common/firmware/util/util_pkg.vhd
vcom -2008 ../../../../common/firmware/util/clkdiv.vhd
vcom -2008 ../../../../common/firmware/registers/mupix.vhd
vcom -2008 ../../../../common/firmware/registers/mupix_registers.vhd
vcom -2008 ../../../../fe_board/fe/util/fifo_reg.vhd
vcom -2008 ../../../../common/firmware/util/quartus/ip_scfifo_v2.vhd
vcom -2008 ../../../../common/firmware/util/ram_1r1w.vhd
vcom -2008 ../../../../common/firmware/util/quartus/ip_ram_2rw.vhd
vcom -2008 ../../../../common/firmware/a10/link/mu3e_pkg.vhd
vcom -2008 ../../../../common/firmware/a10/swb/swb_sc_main.vhd
vcom -2008 ../../../../common/firmware/registers/feb_sc_registers.vhd
vcom -2008 ../../../../fe_board/fe/sc_rx.vhd
vcom -2008 ../../../../fe_board/fe/sc_ram.vhd
vcom -2008 ../../../../fe_board/fe/sc_node.vhd
vcom -2008 ../../../../fe_board/firmware/FEB_common/overflow_check.vhd
vcom -2008 ../../../../fe_board/firmware/FEB_common/data_merger_single.vhd
vcom -2008 ../../../../fe_board/firmware/FEB_common/data_merger.vhd
vcom -2008 ../../../../common/firmware/a10/link/link32_scfifo.vhd
vcom -2008 ../../../../common/firmware/a10/swb/swb_sc_secondary.vhd
vcom -2008 ../../../../common/firmware/a10/tb/tb_sc.vhd
vcom -2008 ../../../../common/firmware/a10/tb/tb_sc.vhd

vsim work.tb_sc(rtl)
onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -group tb_sc /tb_sc/*
add wave -noupdate -group sc_main /tb_sc/sc_main/*
add wave -noupdate -group sc_rx /tb_sc/sc_rx/*
add wave -noupdate -group merger /tb_sc/e_merger/*
add wave -noupdate -group sc_secondary /tb_sc/sc_secondary/*
add wave -noupdate -group sc_ram /tb_sc/e_sc_ram/*
add wave -noupdate -group sc_node /tb_sc/sc_node_inst/*


TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 367
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
radix -hexadecimal

run 800 ns
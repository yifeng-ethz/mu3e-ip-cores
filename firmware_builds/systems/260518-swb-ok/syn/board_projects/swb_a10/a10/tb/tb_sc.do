# M.Mueller, Feb 2023, script for sc_tb

vlib work
quit -sim
onerror {[exit -force -code 1]}
onbreak {[exit -force -code 1]}
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

vsim work.tb_sc(rtl)

run 800 ns
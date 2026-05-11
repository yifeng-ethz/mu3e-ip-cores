quit -sim
vlib work
project compileall
vsim work.tb_zero_suppression(rtl)

onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group tb_top /tb_zero_suppression/*
add wave -noupdate -group zero_sup /tb_zero_suppression/zero_suppression_inst/*

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4127596 ps} 0}
quietly wave cursor active 1
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

run 200ns
force -freeze sim:/tb_zero_suppression/data_in.data E80000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 20ns
-- ts1
force -freeze sim:/tb_zero_suppression/data_in.data ABCD0123
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
-- ts2
force -freeze sim:/tb_zero_suppression/data_in.data 45678901
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 00000110
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 01100000
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 000000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 200ns
-- subh
force -freeze sim:/tb_zero_suppression/data_in.data FC000000
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 000000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 60ns
-- subh
force -freeze sim:/tb_zero_suppression/data_in.data FC010000
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 000000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 100ns
-- subh
force -freeze sim:/tb_zero_suppression/data_in.data FC020000
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 000000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 100ns
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 000000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
-- subh
force -freeze sim:/tb_zero_suppression/data_in.data FC030000
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 000000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 40ns
-- trailer
force -freeze sim:/tb_zero_suppression/data_in.data CAFE009C
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 20ns






force -freeze sim:/tb_zero_suppression/data_in.data E80000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 20ns
-- ts1
force -freeze sim:/tb_zero_suppression/data_in.data ABCD0123
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
-- ts2
force -freeze sim:/tb_zero_suppression/data_in.data 45678901
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 00000110
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 01100000
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 000000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 200ns
-- subh
force -freeze sim:/tb_zero_suppression/data_in.data FC000000
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 000000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 60ns
-- subh
force -freeze sim:/tb_zero_suppression/data_in.data FC010000
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 000000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 100ns
-- subh
force -freeze sim:/tb_zero_suppression/data_in.data FC020000
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 000000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 100ns
--hit
force -freeze sim:/tb_zero_suppression/data_in.data 0601AFFE
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 000000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 40ns
--hit
force -freeze sim:/tb_zero_suppression/data_in.data 0801CAFE
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 000000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
-- subh
force -freeze sim:/tb_zero_suppression/data_in.data FC030000
force -freeze sim:/tb_zero_suppression/data_in.datak 0000
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 000000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 40ns
-- trailer
force -freeze sim:/tb_zero_suppression/data_in.data CAFE009C
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 20ns
force -freeze sim:/tb_zero_suppression/data_in.data 000000BC
force -freeze sim:/tb_zero_suppression/data_in.datak 0001
run 2000 ns
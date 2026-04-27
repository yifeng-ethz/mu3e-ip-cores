onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /mp_sorter_datagen_tb/clk
add wave -noupdate /mp_sorter_datagen_tb/reset_n
add wave -noupdate /mp_sorter_datagen_tb/fifo_wdata
add wave -noupdate /mp_sorter_datagen_tb/fifo_write
add wave -noupdate /mp_sorter_datagen_tb/e_mp_sorter_datagen/genstate
add wave -noupdate /mp_sorter_datagen_tb/e_mp_sorter_datagen/i_global_ts
add wave -noupdate /mp_sorter_datagen_tb/e_mp_sorter_datagen/col
add wave -noupdate /mp_sorter_datagen_tb/e_mp_sorter_datagen/row
add wave -noupdate /mp_sorter_datagen_tb/e_mp_sorter_datagen/tot
add wave -noupdate /mp_sorter_datagen_tb/e_mp_sorter_datagen/ts
add wave -noupdate /mp_sorter_datagen_tb/e_mp_sorter_datagen/chipID
add wave -noupdate /mp_sorter_datagen_tb/e_mp_sorter_datagen/chipID_index
add wave -noupdate /mp_sorter_datagen_tb/e_mp_sorter_datagen/shift0/o_lfsr
add wave -noupdate /mp_sorter_datagen_tb/e_mp_sorter_datagen/o_hit_counter
add wave -noupdate /mp_sorter_datagen_tb/e_mp_sorter_datagen/produce_next_hit
add wave -noupdate /mp_sorter_datagen_tb/e_mp_sorter_datagen/i_control_reg
add wave -noupdate /mp_sorter_datagen_tb/e_mp_sorter_datagen/next_hit_p_range
add wave -noupdate /mp_sorter_datagen_tb/e_mp_sorter_datagen/ts_pull_ahead
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
WaveRestoreZoom {7582471 ps} {7813990 ps}
run 800ns
force -freeze /mp_sorter_datagen_tb/e_mp_sorter_datagen/i_control_reg 10000000000000000000000000010000 0
run 400ns
force -freeze /mp_sorter_datagen_tb/e_mp_sorter_datagen/i_control_reg 10000000000000000000000000010001 0
run 400ns

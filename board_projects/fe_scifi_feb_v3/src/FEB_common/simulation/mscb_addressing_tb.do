onerror {resume}
quietly WaveActivateNextPane {} 0 
add wave -noupdate \
sim:/mscb_addressing_tb/clk \
sim:/mscb_addressing_tb/reset \
sim:/mscb_addressing_tb/addressing_data_in \
sim:/mscb_addressing_tb/addressing_data_out \
sim:/mscb_addressing_tb/addressing_wrreq \
sim:/mscb_addressing_tb/addressing_rdreq \
sim:/mscb_addressing_tb/rec_fifo_empty \
sim:/mscb_addressing_tb/i_mscb_address \
sim:/mscb_addressing_tb/e_mscb_addressing/state \
sim:/mscb_addressing_tb/e_mscb_addressing/proc_state \
sim:/mscb_addressing_tb/e_mscb_addressing/data \
sim:/mscb_addressing_tb/e_mscb_addressing/cmd_buffer \
sim:/mscb_addressing_tb/e_mscb_addressing/send_buffer \
sim:/mscb_addressing_tb/e_mscb_addressing/timeout
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {225425 ps} 0}
quietly wave cursor active 1

configure wave -namecolwidth 332
configure wave -valuecolwidth 277
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
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {289673 ps}
run 
property wave -radix decimal /mscb_addressing_tb/e_mscb_addressing/timeout

force -freeze sim:/mscb_addressing_tb/i_mscb_address x\"ACA0\" 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 1 0
force -freeze sim:/mscb_addressing_tb/addressing_data_in 111111111 0
force -freeze sim:/mscb_addressing_tb/reset 1 0
run 8 ns
force -freeze sim:/mscb_addressing_tb/reset 0 0
run 80 ns

# A0 address command 
force -freeze sim:/mscb_addressing_tb/addressing_data_in 110100000 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 0 0
run 8 ns
force -freeze sim:/mscb_addressing_tb/addressing_data_in 111111111 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 1 0
run 80 ns

# AC part 1 of address
force -freeze sim:/mscb_addressing_tb/addressing_data_in 110101100 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 0 0
run 8 ns
force -freeze sim:/mscb_addressing_tb/addressing_data_in 111111111 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 1 0
run 80 ns

# A0 part 2 of address
force -freeze sim:/mscb_addressing_tb/addressing_data_in 110100000 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 0 0
run 8 ns
force -freeze sim:/mscb_addressing_tb/addressing_data_in 111111111 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 1 0
run 80 ns

# CRC
force -freeze sim:/mscb_addressing_tb/addressing_data_in 101010101 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 0 0
run 8 ns
force -freeze sim:/mscb_addressing_tb/addressing_data_in 111111111 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 1 0
run 160 ns

# other commands, 
force -freeze sim:/mscb_addressing_tb/addressing_data_in 101011111 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 0 0
run 8 ns
force -freeze sim:/mscb_addressing_tb/addressing_data_in 111111111 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 1 0
run 80 ns

force -freeze sim:/mscb_addressing_tb/addressing_data_in 111110101 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 0 0
run 8 ns
force -freeze sim:/mscb_addressing_tb/addressing_data_in 111111111 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 1 0
run 80 ns

force -freeze sim:/mscb_addressing_tb/addressing_data_in 101010000 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 0 0
run 8 ns
force -freeze sim:/mscb_addressing_tb/addressing_data_in 111111111 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 1 0
run 80 ns

# command to other node:
force -freeze sim:/mscb_addressing_tb/reset 1 0
run 8 ns
force -freeze sim:/mscb_addressing_tb/reset 0 0
run 80 ns

# A0 address command 
force -freeze sim:/mscb_addressing_tb/addressing_data_in 110100000 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 0 0
run 8 ns
force -freeze sim:/mscb_addressing_tb/addressing_data_in 111111111 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 1 0
run 80 ns

# part 1 of address
force -freeze sim:/mscb_addressing_tb/addressing_data_in 110101111 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 0 0
run 8 ns
force -freeze sim:/mscb_addressing_tb/addressing_data_in 111111111 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 1 0
run 80 ns

# part 2 of address
force -freeze sim:/mscb_addressing_tb/addressing_data_in 110101111 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 0 0
run 8 ns
force -freeze sim:/mscb_addressing_tb/addressing_data_in 111111111 0
force -freeze sim:/mscb_addressing_tb/rec_fifo_empty 1 0
run 80 ns

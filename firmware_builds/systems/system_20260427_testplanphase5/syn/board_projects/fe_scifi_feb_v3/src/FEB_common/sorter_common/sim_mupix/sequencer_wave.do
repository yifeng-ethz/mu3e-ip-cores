onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /sequencer_tb/reset_n
add wave -noupdate -radix hexadecimal /sequencer_tb/reset
add wave -noupdate -radix hexadecimal /sequencer_tb/writeclk
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/running
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/running_last
add wave -noupdate /sequencer_tb/runend
add wave -noupdate -divider {FIFO Write}
add wave -noupdate -radix hexadecimal /sequencer_tb/tofifo_counters
add wave -noupdate -radix hexadecimal /sequencer_tb/write_counterfifo
add wave -noupdate -radix hexadecimal /sequencer_tb/counterfifo_almostfull
add wave -noupdate -divider {FIFO read}
add wave -noupdate -radix hexadecimal /sequencer_tb/fromfifo_counters
add wave -noupdate -radix hexadecimal /sequencer_tb/read_counterfifo
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/read_fifo_int
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/fifo_new
add wave -noupdate -radix hexadecimal /sequencer_tb/counterfifo_empty
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/fifo_empty_last
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/no_copy_next
add wave -noupdate -divider Sequencing
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/output
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/ts_to_out
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/hasmem
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/hasoverflow
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/current_block
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/blockchange
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/current_ts
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/counters_reg
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/subaddr
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/overflowts
add wave -noupdate -radix hexadecimal /sequencer_tb/dut/overflow_to_out
add wave -noupdate -divider Output
add wave -noupdate -radix hexadecimal /sequencer_tb/outcommand
add wave -noupdate -radix hexadecimal /sequencer_tb/command_enable
add wave -noupdate -radix hexadecimal /sequencer_tb/outoverflow
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {73269 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 505
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
WaveRestoreZoom {845510 ps} {1008132 ps}

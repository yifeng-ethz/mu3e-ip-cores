onerror {resume}
quietly virtual signal -install /hitsorter_scint_tb/dut { /hitsorter_scint_tb/dut/fromfifo_counters(108 downto 102)} FromFifoBlock
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/tofifo_counters
add wave -noupdate -radix hexadecimal -childformat {{/hitsorter_scint_tb/dut/fromfifo_counters(108) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(107) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(106) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(105) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(104) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(103) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(102) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(101) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(100) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(99) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(98) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(97) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(96) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(95) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(94) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(93) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(92) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(91) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(90) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(89) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(88) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(87) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(86) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(85) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(84) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(83) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(82) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(81) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(80) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(79) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(78) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(77) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(76) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(75) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(74) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(73) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(72) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(71) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(70) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(69) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(68) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(67) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(66) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(65) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(64) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(63) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(62) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(61) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(60) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(59) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(58) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(57) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(56) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(55) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(54) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(53) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(52) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(51) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(50) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(49) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(48) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(47) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(46) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(45) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(44) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(43) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(42) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(41) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(40) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(39) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(38) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(37) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(36) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(35) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(34) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(33) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(32) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(31) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(30) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(29) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(28) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(27) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(26) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(25) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(24) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(23) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(22) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(21) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(20) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(19) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(18) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(17) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(16) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(15) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(14) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(13) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(12) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(11) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(10) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(9) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(8) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(7) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(6) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(5) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(4) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(3) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(2) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(1) -radix hexadecimal} {/hitsorter_scint_tb/dut/fromfifo_counters(0) -radix hexadecimal}} -subitemconfig {/hitsorter_scint_tb/dut/fromfifo_counters(108) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(107) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(106) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(105) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(104) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(103) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(102) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(101) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(100) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(99) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(98) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(97) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(96) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(95) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(94) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(93) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(92) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(91) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(90) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(89) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(88) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(87) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(86) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(85) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(84) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(83) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(82) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(81) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(80) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(79) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(78) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(77) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(76) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(75) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(74) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(73) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(72) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(71) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(70) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(69) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(68) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(67) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(66) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(65) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(64) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(63) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(62) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(61) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(60) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(59) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(58) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(57) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(56) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(55) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(54) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(53) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(52) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(51) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(50) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(49) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(48) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(47) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(46) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(45) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(44) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(43) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(42) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(41) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(40) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(39) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(38) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(37) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(36) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(35) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(34) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(33) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(32) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(31) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(30) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(29) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(28) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(27) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(26) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(25) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(24) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(23) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(22) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(21) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(20) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(19) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(18) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(17) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(16) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(15) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(14) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(13) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(12) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(11) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(10) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(9) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(8) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(7) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(6) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(5) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(4) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(3) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(2) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(1) {-radix hexadecimal} /hitsorter_scint_tb/dut/fromfifo_counters(0) {-radix hexadecimal}} /hitsorter_scint_tb/dut/fromfifo_counters
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/read_counterfifo
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/write_counterfifo
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/counterfifo_empty
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/FromFifoBlock
add wave -noupdate /hitsorter_scint_tb/dut/fromfifo_counters(108)
add wave -noupdate /hitsorter_scint_tb/dut/fromfifo_counters(107)
add wave -noupdate /hitsorter_scint_tb/dut/fromfifo_counters(106)
add wave -noupdate /hitsorter_scint_tb/dut/fromfifo_counters(105)
add wave -noupdate /hitsorter_scint_tb/dut/fromfifo_counters(104)
add wave -noupdate /hitsorter_scint_tb/dut/fromfifo_counters(103)
add wave -noupdate /hitsorter_scint_tb/dut/fromfifo_counters(102)
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/running
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/running_last
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/stopped
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/output
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/current_block
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/current_ts
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/ts_to_out
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/counters_reg
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/subaddr
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/subaddr_to_out
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/chip_to_out
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/hasmem
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/hasoverflow
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/fifo_empty_last
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/fifo_new
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/line__95/copy_fifo
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/read_fifo_int
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/make_header
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/blockchange
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/no_copy_next
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/overflowts
add wave -noupdate -expand -group Sequencer -radix hexadecimal /hitsorter_scint_tb/dut/seq/overflow_to_out
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/reset_n
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/writeclk
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/tsclk
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/running
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/currentts
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/hit_in
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/hit_ena_in
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/readclk
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/data_out
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/out_ena
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/out_type
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/diagnostic_out
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/counter
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/localts
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/clk156
add wave -noupdate -group {Run Control} -radix hexadecimal /hitsorter_scint_tb/dut/running_last
add wave -noupdate -group {Run Control} -radix hexadecimal /hitsorter_scint_tb/dut/running_read
add wave -noupdate -group {Run Control} -radix hexadecimal /hitsorter_scint_tb/dut/running_read_last
add wave -noupdate -group {Run Control} -radix hexadecimal /hitsorter_scint_tb/dut/running_seq
add wave -noupdate -group {Run Control} -radix hexadecimal /hitsorter_scint_tb/dut/tslow
add wave -noupdate -group {Run Control} -radix hexadecimal /hitsorter_scint_tb/dut/tshi
add wave -noupdate -group {Run Control} -radix hexadecimal /hitsorter_scint_tb/dut/tsread
add wave -noupdate -group {Run Control} -radix hexadecimal /hitsorter_scint_tb/dut/tsreadmemdelay
add wave -noupdate -group {Run Control} -radix hexadecimal /hitsorter_scint_tb/dut/runstartup
add wave -noupdate -group {Run Control} -radix hexadecimal /hitsorter_scint_tb/dut/runshutdown
add wave -noupdate -group {Run Control} -radix hexadecimal /hitsorter_scint_tb/dut/runend
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/hit_last1
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/hit_last2
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/hit_last3
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/hit_ena_last1
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/hit_ena_last2
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/hit_ena_last3
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/tshit
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/sametsafternext
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/sametsnext
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/dcountertemp
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/dcountertemp2
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/tomem
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/waddr
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/memwren
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/tocmem
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/tocmem_hitwriter
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/cmemwren_hitwriter
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/cmemwren
add wave -noupdate -group Writing -radix hexadecimal /hitsorter_scint_tb/dut/cmemwriteaddr
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/frommem
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/raddr
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/fromcmem
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/fromcmem_hitreader
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/cmemreadaddr
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/cmemreadaddr_hitwriter
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/cmemwriteaddr_hitwriter
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/cmemreadaddr_hitreader
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/addrcounterreset
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/reset
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/counterfifo_almostfull
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/block_nonempty_accumulate
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/block_empty
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/block_empty_del1
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/block_empty_del2
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/stopwrite
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/stopwrite_del1
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/stopwrite_del2
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/blockchange
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/blockchange_del1
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/blockchange_del2
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/mem_nnonempty
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/mem_nechips
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/mem_nechips2
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/mem_countchips
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/mem_countchips_m1
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/mem_countchips_m2
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/hashits
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/mem_overflow
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/mem_overflow_del1
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/mem_overflow_del2
add wave -noupdate -radix decimal /hitsorter_scint_tb/dut/credits
add wave -noupdate /hitsorter_scint_tb/dut/creditchange_reg
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/credits32
add wave -noupdate -radix decimal /hitsorter_scint_tb/dut/credittemp
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/hitcounter_sum_m3_mem
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/hitcounter_sum_mem
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/hitcounter_sum
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/readcommand
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/readcommand_last1
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/readcommand_last2
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/readcommand_last3
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/readcommand_last4
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/readcommand_ena
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/readcommand_ena_last1
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/readcommand_ena_last2
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/readcommand_ena_last3
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/readcommand_ena_last4
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/outoverflow
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/overflow_last1
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/overflow_last2
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/overflow_last3
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/overflow_last4
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/memmultiplex
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/tscounter
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/terminate_output
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/terminated_output
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/noutoftime
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/noverflow
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/nintime
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/nout
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/delay
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/noutoftime2
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/noverflow2
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/nintime2
add wave -noupdate -radix hexadecimal /hitsorter_scint_tb/dut/nout2
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {22801227 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 583
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
WaveRestoreZoom {22800250 ps} {23010716 ps}

//alttemp_sense CBX_AUTO_BLACKBOX="ALL" CBX_SINGLE_OUTPUT_FILE="ON" CLK_FREQUENCY="40.0" CLOCK_DIVIDER_ENABLE="on" CLOCK_DIVIDER_VALUE=80 DEVICE_FAMILY="Arria V" NUMBER_OF_SAMPLES=128 POI_CAL_TEMPERATURE=85 SIM_TSDCALO=0 USE_WYS="on" USER_OFFSET_ENABLE="off" ce clk clr tsdcaldone tsdcalo ALTERA_INTERNAL_OPTIONS=SUPPRESS_DA_RULE_INTERNAL=C106
//VERSION_BEGIN 18.1 cbx_alttemp_sense 2018:09:12:13:04:09:SJ cbx_cycloneii 2018:09:12:13:04:09:SJ cbx_lpm_add_sub 2018:09:12:13:04:09:SJ cbx_lpm_compare 2018:09:12:13:04:09:SJ cbx_lpm_counter 2018:09:12:13:04:09:SJ cbx_lpm_decode 2018:09:12:13:04:09:SJ cbx_mgl 2018:09:12:14:15:07:SJ cbx_nadder 2018:09:12:13:04:09:SJ cbx_nightfury 2018:09:12:13:04:09:SJ cbx_stratix 2018:09:12:13:04:09:SJ cbx_stratixii 2018:09:12:13:04:09:SJ cbx_stratixiii 2018:09:12:13:04:09:SJ cbx_stratixv 2018:09:12:13:04:09:SJ  VERSION_END
// synthesis VERILOG_INPUT_VERSION VERILOG_2001
// altera message_off 10463



// Copyright (C) 2018  Intel Corporation. All rights reserved.
//  Your use of Intel Corporation's design tools, logic functions 
//  and other software and tools, and its AMPP partner logic 
//  functions, and any output files from any of the foregoing 
//  (including device programming or simulation files), and any 
//  associated documentation or information are expressly subject 
//  to the terms and conditions of the Intel Program License 
//  Subscription Agreement, the Intel Quartus Prime License Agreement,
//  the Intel FPGA IP License Agreement, or other applicable license
//  agreement, including, without limitation, that your use is for
//  the sole purpose of programming logic devices manufactured by
//  Intel and sold by Intel or its authorized distributors.  Please
//  refer to the applicable agreement for further details.



//synthesis_resources = arriav_tsdblock 1 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"SUPPRESS_DA_RULE_INTERNAL=C106"} *)
module  debug_sc_system_v3_on_die_temp_sense
	( 
	ce,
	clk,
	clr,
	tsdcaldone,
	tsdcalo) /* synthesis synthesis_clearbox=1 */;
	input   ce;
	input   clk;
	input   clr;
	output   tsdcaldone;
	output   [7:0]  tsdcalo;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri1   ce;
	tri0   clr;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire  wire_sd1_tsdcaldone;
	wire  [7:0]   wire_sd1_tsdcalo;

	arriav_tsdblock   sd1
	( 
	.ce(ce),
	.clk(clk),
	.clr(clr),
	.tsdcaldone(wire_sd1_tsdcaldone),
	.tsdcalo(wire_sd1_tsdcalo));
	defparam
		sd1.clock_divider_enable = "true",
		sd1.clock_divider_value = 80,
		sd1.sim_tsdcalo = 0,
		sd1.lpm_type = "arriav_tsdblock";
	assign
		tsdcaldone = wire_sd1_tsdcaldone,
		tsdcalo = wire_sd1_tsdcalo;
endmodule //debug_sc_system_v3_on_die_temp_sense
//VALID FILE

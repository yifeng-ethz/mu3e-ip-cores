`ifndef FE_SCIFI_V3_DEBUG_SC_MAP_SVH
`define FE_SCIFI_V3_DEBUG_SC_MAP_SVH

localparam int unsigned FE_SC_MAP_COUNT = 17;

localparam int unsigned FE_SC_IDX_JTAG_MASTER_MASTER_SCRATCH_PAD_RAM_S1 = 0;
localparam logic [31:0] FE_SC_BASE_JTAG_MASTER_MASTER_SCRATCH_PAD_RAM_S1 = 32'h00000000;
localparam logic [31:0] FE_SC_SPAN_JTAG_MASTER_MASTER_SCRATCH_PAD_RAM_S1 = 32'h00000400;
localparam logic [31:0] FE_SC_END_JTAG_MASTER_MASTER_SCRATCH_PAD_RAM_S1 = 32'h000003FF;
// 0: master=jtag_master.master slave=scratch_pad_ram.s1
//     base=0x00000000 span=0x00000400 end=0x000003FF
localparam int unsigned FE_SC_IDX_JTAG_MASTER_MASTER_SC_HUB_CSR = 1;
localparam logic [31:0] FE_SC_BASE_JTAG_MASTER_MASTER_SC_HUB_CSR = 32'h00000400;
localparam logic [31:0] FE_SC_SPAN_JTAG_MASTER_MASTER_SC_HUB_CSR = 32'h00000080;
localparam logic [31:0] FE_SC_END_JTAG_MASTER_MASTER_SC_HUB_CSR = 32'h0000047F;
// 1: master=jtag_master.master slave=sc_hub.csr
//     base=0x00000400 span=0x00000080 end=0x0000047F
localparam int unsigned FE_SC_IDX_JTAG_MASTER_MASTER_CHARGE_INJECTION_PULSER_0_CSR_AVMM = 2;
localparam logic [31:0] FE_SC_BASE_JTAG_MASTER_MASTER_CHARGE_INJECTION_PULSER_0_CSR_AVMM = 32'h000004C4;
localparam logic [31:0] FE_SC_SPAN_JTAG_MASTER_MASTER_CHARGE_INJECTION_PULSER_0_CSR_AVMM = 32'h00000004;
localparam logic [31:0] FE_SC_END_JTAG_MASTER_MASTER_CHARGE_INJECTION_PULSER_0_CSR_AVMM = 32'h000004C7;
// 2: master=jtag_master.master slave=charge_injection_pulser_0.csr_avmm
//     base=0x000004C4 span=0x00000004 end=0x000004C7
localparam int unsigned FE_SC_IDX_JTAG_MASTER_MASTER_FIREFLY_XCVR_CTRL_0_FIREFLY = 3;
localparam logic [31:0] FE_SC_BASE_JTAG_MASTER_MASTER_FIREFLY_XCVR_CTRL_0_FIREFLY = 32'h00000500;
localparam logic [31:0] FE_SC_SPAN_JTAG_MASTER_MASTER_FIREFLY_XCVR_CTRL_0_FIREFLY = 32'h00000080;
localparam logic [31:0] FE_SC_END_JTAG_MASTER_MASTER_FIREFLY_XCVR_CTRL_0_FIREFLY = 32'h0000057F;
// 3: master=jtag_master.master slave=firefly_xcvr_ctrl_0.firefly
//     base=0x00000500 span=0x00000080 end=0x0000057F
localparam int unsigned FE_SC_IDX_JTAG_MASTER_MASTER_ON_DIE_TEMP_SENSE_CTRL_CSR = 4;
localparam logic [31:0] FE_SC_BASE_JTAG_MASTER_MASTER_ON_DIE_TEMP_SENSE_CTRL_CSR = 32'h00010818;
localparam logic [31:0] FE_SC_SPAN_JTAG_MASTER_MASTER_ON_DIE_TEMP_SENSE_CTRL_CSR = 32'h00000004;
localparam logic [31:0] FE_SC_END_JTAG_MASTER_MASTER_ON_DIE_TEMP_SENSE_CTRL_CSR = 32'h0001081B;
// 4: master=jtag_master.master slave=on_die_temp_sense_ctrl.csr
//     base=0x00010818 span=0x00000004 end=0x0001081B
localparam int unsigned FE_SC_IDX_JTAG_MASTER_MASTER_ONEWIRE_MASTER_CONTROLLER_0_CSR = 5;
localparam logic [31:0] FE_SC_BASE_JTAG_MASTER_MASTER_ONEWIRE_MASTER_CONTROLLER_0_CSR = 32'h00011000;
localparam logic [31:0] FE_SC_SPAN_JTAG_MASTER_MASTER_ONEWIRE_MASTER_CONTROLLER_0_CSR = 32'h00000040;
localparam logic [31:0] FE_SC_END_JTAG_MASTER_MASTER_ONEWIRE_MASTER_CONTROLLER_0_CSR = 32'h0001103F;
// 5: master=jtag_master.master slave=onewire_master_controller_0.csr
//     base=0x00011000 span=0x00000040 end=0x0001103F
localparam int unsigned FE_SC_IDX_JTAG_MASTER_MASTER_MAX10_PROG_AVMM_0_CSR_AVMM = 6;
localparam logic [31:0] FE_SC_BASE_JTAG_MASTER_MASTER_MAX10_PROG_AVMM_0_CSR_AVMM = 32'h00012000;
localparam logic [31:0] FE_SC_SPAN_JTAG_MASTER_MASTER_MAX10_PROG_AVMM_0_CSR_AVMM = 32'h00001000;
localparam logic [31:0] FE_SC_END_JTAG_MASTER_MASTER_MAX10_PROG_AVMM_0_CSR_AVMM = 32'h00012FFF;
// 6: master=jtag_master.master slave=max10_prog_avmm_0.csr_avmm
//     base=0x00012000 span=0x00001000 end=0x00012FFF
localparam int unsigned FE_SC_IDX_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_CSR = 7;
localparam logic [31:0] FE_SC_BASE_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_CSR = 32'h0003F010;
localparam logic [31:0] FE_SC_SPAN_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_CSR = 32'h00000010;
localparam logic [31:0] FE_SC_END_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_CSR = 32'h0003F01F;
// 7: master=jtag_master.master slave=mutrig_cfg_ctrl_0.avmm_csr
//     base=0x0003F010 span=0x00000010 end=0x0003F01F
localparam int unsigned FE_SC_IDX_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_SCANRESULT = 8;
localparam logic [31:0] FE_SC_BASE_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_SCANRESULT = 32'h00040000;
localparam logic [31:0] FE_SC_SPAN_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_SCANRESULT = 32'h00010000;
localparam logic [31:0] FE_SC_END_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_SCANRESULT = 32'h0004FFFF;
// 8: master=jtag_master.master slave=mutrig_cfg_ctrl_0.avmm_scanresult
//     base=0x00040000 span=0x00010000 end=0x0004FFFF
localparam int unsigned FE_SC_IDX_SC_HUB_CMD_PIPE_M0_SCRATCH_PAD_RAM_S1 = 9;
localparam logic [31:0] FE_SC_BASE_SC_HUB_CMD_PIPE_M0_SCRATCH_PAD_RAM_S1 = 32'h00000000;
localparam logic [31:0] FE_SC_SPAN_SC_HUB_CMD_PIPE_M0_SCRATCH_PAD_RAM_S1 = 32'h00000400;
localparam logic [31:0] FE_SC_END_SC_HUB_CMD_PIPE_M0_SCRATCH_PAD_RAM_S1 = 32'h000003FF;
// 9: master=sc_hub_cmd_pipe.m0 slave=scratch_pad_ram.s1
//     base=0x00000000 span=0x00000400 end=0x000003FF
localparam int unsigned FE_SC_IDX_SC_HUB_CMD_PIPE_M0_ONEWIRE_MASTER_CONTROLLER_0_CSR = 10;
localparam logic [31:0] FE_SC_BASE_SC_HUB_CMD_PIPE_M0_ONEWIRE_MASTER_CONTROLLER_0_CSR = 32'h00011000;
localparam logic [31:0] FE_SC_SPAN_SC_HUB_CMD_PIPE_M0_ONEWIRE_MASTER_CONTROLLER_0_CSR = 32'h00000040;
localparam logic [31:0] FE_SC_END_SC_HUB_CMD_PIPE_M0_ONEWIRE_MASTER_CONTROLLER_0_CSR = 32'h0001103F;
// 10: master=sc_hub_cmd_pipe.m0 slave=onewire_master_controller_0.csr
//     base=0x00011000 span=0x00000040 end=0x0001103F
localparam int unsigned FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MAX10_PROG_AVMM_0_CSR_AVMM = 11;
localparam logic [31:0] FE_SC_BASE_SC_HUB_CMD_PIPE_M0_MAX10_PROG_AVMM_0_CSR_AVMM = 32'h00012000;
localparam logic [31:0] FE_SC_SPAN_SC_HUB_CMD_PIPE_M0_MAX10_PROG_AVMM_0_CSR_AVMM = 32'h00001000;
localparam logic [31:0] FE_SC_END_SC_HUB_CMD_PIPE_M0_MAX10_PROG_AVMM_0_CSR_AVMM = 32'h00012FFF;
// 11: master=sc_hub_cmd_pipe.m0 slave=max10_prog_avmm_0.csr_avmm
//     base=0x00012000 span=0x00001000 end=0x00012FFF
localparam int unsigned FE_SC_IDX_SC_HUB_CMD_PIPE_M0_CHARGE_INJECTION_PULSER_0_CSR_AVMM = 12;
localparam logic [31:0] FE_SC_BASE_SC_HUB_CMD_PIPE_M0_CHARGE_INJECTION_PULSER_0_CSR_AVMM = 32'h00013000;
localparam logic [31:0] FE_SC_SPAN_SC_HUB_CMD_PIPE_M0_CHARGE_INJECTION_PULSER_0_CSR_AVMM = 32'h00000004;
localparam logic [31:0] FE_SC_END_SC_HUB_CMD_PIPE_M0_CHARGE_INJECTION_PULSER_0_CSR_AVMM = 32'h00013003;
// 12: master=sc_hub_cmd_pipe.m0 slave=charge_injection_pulser_0.csr_avmm
//     base=0x00013000 span=0x00000004 end=0x00013003
localparam int unsigned FE_SC_IDX_SC_HUB_CMD_PIPE_M0_FIREFLY_XCVR_CTRL_0_FIREFLY = 13;
localparam logic [31:0] FE_SC_BASE_SC_HUB_CMD_PIPE_M0_FIREFLY_XCVR_CTRL_0_FIREFLY = 32'h00014000;
localparam logic [31:0] FE_SC_SPAN_SC_HUB_CMD_PIPE_M0_FIREFLY_XCVR_CTRL_0_FIREFLY = 32'h00000080;
localparam logic [31:0] FE_SC_END_SC_HUB_CMD_PIPE_M0_FIREFLY_XCVR_CTRL_0_FIREFLY = 32'h0001407F;
// 13: master=sc_hub_cmd_pipe.m0 slave=firefly_xcvr_ctrl_0.firefly
//     base=0x00014000 span=0x00000080 end=0x0001407F
localparam int unsigned FE_SC_IDX_SC_HUB_CMD_PIPE_M0_ON_DIE_TEMP_SENSE_CTRL_CSR = 14;
localparam logic [31:0] FE_SC_BASE_SC_HUB_CMD_PIPE_M0_ON_DIE_TEMP_SENSE_CTRL_CSR = 32'h00015000;
localparam logic [31:0] FE_SC_SPAN_SC_HUB_CMD_PIPE_M0_ON_DIE_TEMP_SENSE_CTRL_CSR = 32'h00000004;
localparam logic [31:0] FE_SC_END_SC_HUB_CMD_PIPE_M0_ON_DIE_TEMP_SENSE_CTRL_CSR = 32'h00015003;
// 14: master=sc_hub_cmd_pipe.m0 slave=on_die_temp_sense_ctrl.csr
//     base=0x00015000 span=0x00000004 end=0x00015003
localparam int unsigned FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MM_BRIDGE_S0 = 15;
localparam logic [31:0] FE_SC_BASE_SC_HUB_CMD_PIPE_M0_MM_BRIDGE_S0 = 32'h00020000;
localparam logic [31:0] FE_SC_SPAN_SC_HUB_CMD_PIPE_M0_MM_BRIDGE_S0 = 32'h00010000;
localparam logic [31:0] FE_SC_END_SC_HUB_CMD_PIPE_M0_MM_BRIDGE_S0 = 32'h0002FFFF;
// 15: master=sc_hub_cmd_pipe.m0 slave=mm_bridge.s0
//     base=0x00020000 span=0x00010000 end=0x0002FFFF
localparam int unsigned FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MUTRIG_CFG_CTRL_0_AVMM_CSR = 16;
localparam logic [31:0] FE_SC_BASE_SC_HUB_CMD_PIPE_M0_MUTRIG_CFG_CTRL_0_AVMM_CSR = 32'h0003F010;
localparam logic [31:0] FE_SC_SPAN_SC_HUB_CMD_PIPE_M0_MUTRIG_CFG_CTRL_0_AVMM_CSR = 32'h00000010;
localparam logic [31:0] FE_SC_END_SC_HUB_CMD_PIPE_M0_MUTRIG_CFG_CTRL_0_AVMM_CSR = 32'h0003F01F;
// 16: master=sc_hub_cmd_pipe.m0 slave=mutrig_cfg_ctrl_0.avmm_csr
//     base=0x0003F010 span=0x00000010 end=0x0003F01F

`endif

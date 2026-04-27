library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mu3e.all;

entity tb_feb_system_v3_soak is
    generic (
        G_CLK156_PERIOD          : time := 6.4 ns;
        G_CLK125_PERIOD          : time := 8 ns;
        G_CLK50_PERIOD           : time := 20 ns;
        G_RESET_ASSERT_TIME      : time := 200 ns;
        G_POST_RESET_SETTLE      : time := 5 us;
        G_SOAK_ACTIVE_TIME        : time := 2 ms;
        G_SOAK_STATUS_INTERVAL    : time := 1 ms;
        G_SOAK_SC_HEALTH_INTERVAL : time := 10 ms;
        G_SOAK_START_SETTLE       : time := 20 us;
        G_SOAK_DRAIN_TIME         : time := 40 us;
        G_ENABLE_SC_HEALTH        : boolean := true;
        G_EMU_ACTIVE_MASK         : natural := 16#FF#;
        G_EMU_HIT_RATE            : natural := 16#0800#;
        G_EMU_NOISE_RATE          : natural := 16#0000#;
        G_EMU_TIMING_WORD         : natural := 16#00020004#;
        G_EMU_CFG_LOCAL           : boolean := false;
        G_EMU_CFG_FAST_FORCE      : boolean := false;
        G_PROGRESS_HEARTBEAT_CYCLES : natural := 0
    );
end entity tb_feb_system_v3_soak;

architecture sim of tb_feb_system_v3_soak is
    constant NLINKS_CONST        : positive := 1;
    constant CMD_DEPTH_CONST     : natural  := 256;
    constant RSP_DEPTH_CONST     : natural  := 4096;

    constant READ_PREAMBLE_CONST  : std_logic_vector(31 downto 0) := x"1E0000BC";
    constant WRITE_PREAMBLE_CONST : std_logic_vector(31 downto 0) := x"1D0000BC";
    constant READ_ACK_CONST       : std_logic_vector(31 downto 0) := x"00000001";
    constant TRAILER_CONST        : std_logic_vector(31 downto 0) := x"0000009C";
    constant ZERO_WORD_CONST      : std_logic_vector(31 downto 0) := (others => '0');

    constant SCRATCH_ADDR_CONST               : natural := 16#000000#;
    constant DATA_PATH_EXPORT_BASE_ADDR_CONST : natural := 16#008000#;
    -- SC packet addresses are word-addressed; the generated Qsys maps are byte-addressed.
    constant EMU0_BASE_ADDR_CONST             : natural := DATA_PATH_EXPORT_BASE_ADDR_CONST + 16#000800#;
    constant EMU_ADDR_STRIDE_CONST            : natural := 16#000010#;
    constant DBG_MM2RUNCTRL_ADDR_CONST        : natural := DATA_PATH_EXPORT_BASE_ADDR_CONST + 16#000880#;
    constant HIST0_CSR_BASE_ADDR_CONST        : natural := DATA_PATH_EXPORT_BASE_ADDR_CONST + 16#002900#;
    constant HIST1_CSR_BASE_ADDR_CONST        : natural := DATA_PATH_EXPORT_BASE_ADDR_CONST + 16#002B00#;
    constant HIST_CSR_CONTROL_OFF_CONST  : natural := 2;
    constant HIST_CSR_LEFT_OFF_CONST     : natural := 3;
    constant HIST_CSR_BIN_WIDTH_OFF_CONST : natural := 5;
    constant HIST_CSR_KEY_LOC_OFF_CONST  : natural := 6;
    constant HIST_CSR_KEY_VALUE_OFF_CONST : natural := 7;
    constant HIST_CSR_UNDERFLOW_OFF_CONST : natural := 8;
    constant HIST_CSR_OVERFLOW_OFF_CONST : natural := 9;
    constant HIST_CSR_INTERVAL_OFF_CONST : natural := 10;
    constant HIST_CSR_BANK_OFF_CONST     : natural := 11;
    constant HIST_CSR_TOTAL_OFF_CONST    : natural := 13;
    constant HIST_CSR_DROPPED_OFF_CONST  : natural := 14;

    constant HIST0_KEY_LOC_CONST     : std_logic_vector(31 downto 0) := x"251E251E";
    constant HIST1_KEY_LOC_CONST     : std_logic_vector(31 downto 0) := x"0F000F00";
    constant HIST_CONTROL_RUN_CONST  : std_logic_vector(31 downto 0) := x"00000101";
    constant HIST_CONTROL_STOP_CONST : std_logic_vector(31 downto 0) := x"00000000";
    constant HIST_INTERVAL_CONST     : std_logic_vector(31 downto 0) := x"00002000";
    constant SCRATCH_HEARTBEAT_CONST : std_logic_vector(31 downto 0) := x"5A5AA5A5";

    constant EMU_CONTROL_CONST       : std_logic_vector(31 downto 0) := x"00000001";
    constant EMU_DEFAULT_RATE_CONST  : std_logic_vector(31 downto 0) := x"01000800";
    constant EMU_TX_GEN_IDLE_CONST   : std_logic_vector(31 downto 0) := x"00000008";

    constant RC_RUNNING_CONST        : std_logic_vector(8 downto 0) := "000001000";
    constant RC_ALL_SEEN_CONST       : std_logic_vector(15 downto 0) := (others => '1');
    constant EMU_RC_ALL_SEEN_CONST   : std_logic_vector(7 downto 0) := (others => '1');
    constant UPLOAD_CH_UPPER_DATA_CONST : std_logic_vector(1 downto 0) := "00";
    constant UPLOAD_CH_SC_CONST         : std_logic_vector(1 downto 0) := "01";
    constant UPLOAD_CH_RC_CONST         : std_logic_vector(1 downto 0) := "10";

    constant RESPONSE_TIMEOUT_CYCLES_CONST : natural := 2048;
    constant RESPONSE_QUIET_CYCLES_CONST   : natural := 32;

    type word_mem_t is array (0 to CMD_DEPTH_CONST - 1) of std_logic_vector(31 downto 0);
    type rsp_word_mem_t is array (0 to RSP_DEPTH_CONST - 1) of std_logic_vector(31 downto 0);

    function read_reply_header_ok (
        constant word_value   : std_logic_vector(31 downto 0);
        constant length_value : natural
    ) return boolean is
    begin
        return (
            word_value(31 downto 17) = (word_value(31 downto 17)'range => '0') and
            unsigned(word_value(15 downto 0)) = to_unsigned(length_value, 16)
        );
    end function read_reply_header_ok;

    function reply_response_code (
        constant word_value : std_logic_vector(31 downto 0)
    ) return std_logic_vector is
    begin
        return word_value(19 downto 18);
    end function reply_response_code;

    function has_unknown (
        constant value : std_logic_vector
    ) return boolean is
    begin
        for i in value'range loop
            if not (value(i) = '0' or value(i) = '1') then
                return true;
            end if;
        end loop;
        return false;
    end function has_unknown;

    function sl_to_nat (
        constant value : std_logic
    ) return natural is
    begin
        if value = '1' then
            return 1;
        end if;
        return 0;
    end function sl_to_nat;

    function bool_to_nat (
        constant value : boolean
    ) return natural is
    begin
        if value then
            return 1;
        end if;
        return 0;
    end function bool_to_nat;

    signal clk156  : std_logic := '0';
    signal clk125  : std_logic := '0';
    signal clk50   : std_logic := '0';
    signal reset_n : std_logic := '0';

    signal cmd_mem         : word_mem_t := (others => (others => '0'));
    signal rsp_mem         : rsp_word_mem_t := (others => (others => '0'));
    signal rsp_write_count : natural range 0 to RSP_DEPTH_CONST := 0;

    signal sc_length_we      : std_logic := '0';
    signal sc_length         : std_logic_vector(15 downto 0) := (others => '0');
    signal sc_main_mem_addr  : std_logic_vector(15 downto 0);
    signal sc_main_mem_data  : std_logic_vector(31 downto 0);
    signal sc_main_links     : link_array_t(NLINKS_CONST - 1 downto 0);
    signal sc_main_injection : link_array_t(3 downto 0);
    signal sc_main_done      : std_logic;
    signal sc_main_state     : std_logic_vector(27 downto 0);

    signal secondary_links        : link_array_t(NLINKS_CONST - 1 downto 0) := (others => LINK_IDLE);
    signal secondary_enable       : std_logic_vector(NLINKS_CONST - 1 downto 0) := (others => '1');
    signal sc_secondary_mem_addr  : std_logic_vector(15 downto 0);
    signal sc_secondary_addr_done : std_logic_vector(15 downto 0);
    signal sc_secondary_mem_data  : std_logic_vector(31 downto 0);
    signal sc_secondary_mem_we    : std_logic;
    signal sc_secondary_state     : std_logic_vector(3 downto 0);

    signal sc_down_data  : std_logic_vector(31 downto 0);
    signal sc_down_datak : std_logic_vector(3 downto 0);
    signal sc_down_ready : std_logic;
    signal sc_up_data    : std_logic_vector(35 downto 0);
    signal sc_up_valid   : std_logic;
    signal sc_up_ready   : std_logic;
    signal sc_up_sop     : std_logic;
    signal sc_up_eop     : std_logic;
    signal sc_up_channel : std_logic_vector(1 downto 0);

    signal inject_pulse        : std_logic;
    signal max10_link_csn      : std_logic;
    signal max10_link_clk      : std_logic;
    signal max10_link_mosi_in  : std_logic := '0';
    signal max10_link_mosi_out : std_logic;
    signal max10_link_mosi_oe  : std_logic;
    signal max10_link_miso_in  : std_logic := '0';
    signal max10_link_miso_out : std_logic;
    signal max10_link_miso_oe  : std_logic;
    signal max10_link_d1_in    : std_logic := '0';
    signal max10_link_d1_out   : std_logic;
    signal max10_link_d1_oe    : std_logic;
    signal max10_link_d2_in    : std_logic := '0';
    signal max10_link_d2_out   : std_logic;
    signal max10_link_d2_oe    : std_logic;
    signal max10_link_d3_in    : std_logic := '0';
    signal max10_link_d3_out   : std_logic;
    signal max10_link_d3_oe    : std_logic;
    signal spi_miso            : std_logic := '0';
    signal spi_mosi            : std_logic;
    signal spi_sclk            : std_logic;
    signal spi_ssn             : std_logic_vector(7 downto 0);
    signal mutrig_reset        : std_logic_vector(1 downto 0);
    signal pulse_out_conduit   : std_logic;
    signal redriver_losn       : std_logic_vector(8 downto 0) := (others => '1');
    signal serial_data         : std_logic_vector(8 downto 0) := (others => '0');
    signal sense_dq_pad        : std_logic_vector(5 downto 0) := (others => 'H');
    signal sense_dq_in         : std_logic_vector(5 downto 0);
    signal sense_dq_out        : std_logic_vector(5 downto 0);
    signal sense_dq_oe         : std_logic_vector(5 downto 0);
    signal firefly_scl         : std_logic := 'H';
    signal firefly_present_n   : std_logic_vector(1 downto 0) := (others => '1');
    signal firefly_sda         : std_logic := 'H';
    signal firefly_reset_n     : std_logic_vector(1 downto 0);
    signal firefly_select_n    : std_logic_vector(1 downto 0);
    signal firefly_int_n       : std_logic_vector(1 downto 0) := (others => '1');
    signal upload_data1_data   : std_logic_vector(35 downto 0);
    signal upload_data1_valid  : std_logic;
    signal upload_data1_ready  : std_logic;
    signal upload_data1_sop    : std_logic;
    signal upload_data1_eop    : std_logic;

    signal swb_link0_words     : natural range 0 to 65535 := 0;
    signal swb_link0_frames    : natural range 0 to 65535 := 0;
    signal swb_link1_words     : natural range 0 to 65535 := 0;
    signal swb_link1_frames    : natural range 0 to 65535 := 0;
    signal external_rc_active  : std_logic := '0';

    signal upper_words_accepted  : natural range 0 to 65535 := 0;
    signal upper_frames_accepted : natural range 0 to 65535 := 0;
    signal lower_words_accepted  : natural range 0 to 65535 := 0;
    signal lower_frames_accepted : natural range 0 to 65535 := 0;
    signal runctrl_seen_mask     : std_logic_vector(15 downto 0) := (others => '0');
    signal emulator_rc_seen_mask : std_logic_vector(7 downto 0) := (others => '0');
    signal hitstack_input_rc_seen_mask : std_logic_vector(1 downto 0) := (others => '0');
    signal frame_dp_rc_seen_mask  : std_logic_vector(1 downto 0) := (others => '0');
    signal frame_xcvr_rc_seen_mask : std_logic_vector(1 downto 0) := (others => '0');
    signal ext_emu_word_count         : natural := 0;
    signal dp_hit0_word_count         : natural := 0;
    signal mts_type1_word_count       : natural := 0;
    signal hit_stack_ingress_word_count : natural := 0;
    signal hit_stack0_type2_word_count : natural := 0;
    signal hit_stack1_type2_word_count : natural := 0;
    signal hit_stack0_type2_valid_cycles : natural := 0;
    signal hit_stack1_type2_valid_cycles : natural := 0;
    signal hit_stack0_type3_word_count : natural := 0;
    signal hit_stack1_type3_word_count : natural := 0;
    signal hs0_popcmd_wrreq_count : natural := 0;
    signal hs0_popcmd_rdack_count : natural := 0;
    signal hs0_pop_pipeline_start_count : natural := 0;
    signal hs1_popcmd_wrreq_count : natural := 0;
    signal hs1_popcmd_rdack_count : natural := 0;
    signal hs1_pop_pipeline_start_count : natural := 0;
    signal hs0_frame_loss8fill_count : natural := 0;
    signal hs0_frame_delay8loss_count : natural := 0;
    signal hs1_frame_loss8fill_count : natural := 0;
    signal hs1_frame_delay8loss_count : natural := 0;
    signal progress_heartbeat_count : natural := 0;

    alias upper_hit_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem_hit_type3_upper_valid : std_logic >>;
    alias upper_hit_ready is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem_hit_type3_upper_ready : std_logic >>;
    alias upper_hit_sop is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem_hit_type3_upper_startofpacket : std_logic >>;
    alias upper_hit_eop is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem_hit_type3_upper_endofpacket : std_logic >>;
    alias host_runctl_ready is << signal .tb_feb_system_v3_soak.dut.upload_subsystem_runctl_mgmt_host_ready : std_logic >>;

    alias rc_out0_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out0_valid : std_logic >>;
    alias rc_out0_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out0_data : std_logic_vector(8 downto 0) >>;
    alias rc_out1_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out1_valid : std_logic >>;
    alias rc_out1_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out1_data : std_logic_vector(8 downto 0) >>;
    alias rc_out2_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out2_valid : std_logic >>;
    alias rc_out2_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out2_data : std_logic_vector(8 downto 0) >>;
    alias rc_out3_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out3_valid : std_logic >>;
    alias rc_out3_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out3_data : std_logic_vector(8 downto 0) >>;
    alias rc_out4_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out4_valid : std_logic >>;
    alias rc_out4_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out4_data : std_logic_vector(8 downto 0) >>;
    alias rc_out5_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out5_valid : std_logic >>;
    alias rc_out5_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out5_data : std_logic_vector(8 downto 0) >>;
    alias rc_out6_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out6_valid : std_logic >>;
    alias rc_out6_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out6_data : std_logic_vector(8 downto 0) >>;
    alias rc_out7_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out7_valid : std_logic >>;
    alias rc_out7_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out7_data : std_logic_vector(8 downto 0) >>;
    alias rc_out8_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out8_valid : std_logic >>;
    alias rc_out8_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out8_data : std_logic_vector(8 downto 0) >>;
    alias rc_out9_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out9_valid : std_logic >>;
    alias rc_out9_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out9_data : std_logic_vector(8 downto 0) >>;
    alias rc_out10_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out10_valid : std_logic >>;
    alias rc_out10_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out10_data : std_logic_vector(8 downto 0) >>;
    alias rc_out11_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out11_valid : std_logic >>;
    alias rc_out11_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out11_data : std_logic_vector(8 downto 0) >>;
    alias rc_out12_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out12_valid : std_logic >>;
    alias rc_out12_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out12_data : std_logic_vector(8 downto 0) >>;
    alias rc_out13_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out13_valid : std_logic >>;
    alias rc_out13_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out13_data : std_logic_vector(8 downto 0) >>;
    alias rc_out14_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out14_valid : std_logic >>;
    alias rc_out14_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out14_data : std_logic_vector(8 downto 0) >>;
    alias rc_out15_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out15_valid : std_logic >>;
    alias rc_out15_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out15_data : std_logic_vector(8 downto 0) >>;

    alias emu_rc_out1_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out1_valid : std_logic >>;
    alias emu_rc_out1_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out1_data : std_logic_vector(8 downto 0) >>;
    alias emu_rc_out2_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out2_valid : std_logic >>;
    alias emu_rc_out2_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out2_data : std_logic_vector(8 downto 0) >>;
    alias emu_rc_out3_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out3_valid : std_logic >>;
    alias emu_rc_out3_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out3_data : std_logic_vector(8 downto 0) >>;
    alias emu_rc_out4_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out4_valid : std_logic >>;
    alias emu_rc_out4_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out4_data : std_logic_vector(8 downto 0) >>;
    alias emu_rc_out5_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out5_valid : std_logic >>;
    alias emu_rc_out5_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out5_data : std_logic_vector(8 downto 0) >>;
    alias emu_rc_out6_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out6_valid : std_logic >>;
    alias emu_rc_out6_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out6_data : std_logic_vector(8 downto 0) >>;
    alias emu_rc_out7_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out7_valid : std_logic >>;
    alias emu_rc_out7_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out7_data : std_logic_vector(8 downto 0) >>;
    alias emu_rc_out8_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out8_valid : std_logic >>;
    alias emu_rc_out8_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out8_data : std_logic_vector(8 downto 0) >>;
    alias rc_hist0_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.histogram_statistics_0.asi_ctrl_valid : std_logic >>;
    alias rc_hist0_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.histogram_statistics_0.asi_ctrl_data : std_logic_vector(8 downto 0) >>;
    alias rc_mts0_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_0.asi_ctrl_valid : std_logic >>;
    alias rc_mts0_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_0.asi_ctrl_data : std_logic_vector(8 downto 0) >>;
    alias rc_dp0_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_0.run_ctrl_valid : std_logic >>;
    alias rc_dp0_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_0.run_ctrl_data : std_logic_vector(8 downto 0) >>;
    alias rc_dp1_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_1.run_ctrl_valid : std_logic >>;
    alias rc_dp1_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_1.run_ctrl_data : std_logic_vector(8 downto 0) >>;
    alias rc_dp2_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_2.run_ctrl_valid : std_logic >>;
    alias rc_dp2_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_2.run_ctrl_data : std_logic_vector(8 downto 0) >>;
    alias rc_dp3_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_3.run_ctrl_valid : std_logic >>;
    alias rc_dp3_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_3.run_ctrl_data : std_logic_vector(8 downto 0) >>;
    alias rc_hitstack0_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_signal_valid : std_logic >>;
    alias rc_hitstack0_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_signal_data : std_logic_vector(8 downto 0) >>;
    alias rc_reset_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_reset_controller_0.asi_runcontrol_valid : std_logic >>;
    alias rc_reset_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_reset_controller_0.asi_runcontrol_data : std_logic_vector(8 downto 0) >>;
    alias rc_dp4_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_4.run_ctrl_valid : std_logic >>;
    alias rc_dp4_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_4.run_ctrl_data : std_logic_vector(8 downto 0) >>;
    alias rc_dp5_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_5.run_ctrl_valid : std_logic >>;
    alias rc_dp5_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_5.run_ctrl_data : std_logic_vector(8 downto 0) >>;
    alias rc_dp6_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_6.run_ctrl_valid : std_logic >>;
    alias rc_dp6_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_6.run_ctrl_data : std_logic_vector(8 downto 0) >>;
    alias rc_dp7_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_7.run_ctrl_valid : std_logic >>;
    alias rc_dp7_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_7.run_ctrl_data : std_logic_vector(8 downto 0) >>;
    alias rc_mts1_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_1.asi_ctrl_valid : std_logic >>;
    alias rc_mts1_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_1.asi_ctrl_data : std_logic_vector(8 downto 0) >>;
    alias rc_injector_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_injector_0.asi_runctl_valid : std_logic >>;
    alias rc_injector_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_injector_0.asi_runctl_data : std_logic_vector(8 downto 0) >>;
    alias rc_hitstack1_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_signal_valid : std_logic >>;
    alias rc_hitstack1_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_signal_data : std_logic_vector(8 downto 0) >>;
    alias rc_hist1_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.histogram_statistics_1.asi_ctrl_valid : std_logic >>;
    alias rc_hist1_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.histogram_statistics_1.asi_ctrl_data : std_logic_vector(8 downto 0) >>;
    alias emu0_tx_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_0_tx8b1k_valid : std_logic >>;
    alias emu1_tx_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_1_tx8b1k_valid : std_logic >>;
    alias emu2_tx_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_2_tx8b1k_valid : std_logic >>;
    alias emu3_tx_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_3_tx8b1k_valid : std_logic >>;
    alias emu4_tx_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_4_tx8b1k_valid : std_logic >>;
    alias emu5_tx_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_5_tx8b1k_valid : std_logic >>;
    alias emu6_tx_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_6_tx8b1k_valid : std_logic >>;
    alias emu7_tx_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_7_tx8b1k_valid : std_logic >>;
    alias dp0_hit0_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_0_hit_type0_out_valid : std_logic >>;
    alias dp1_hit0_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_1_hit_type0_out_valid : std_logic >>;
    alias dp2_hit0_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_2_hit_type0_out_valid : std_logic >>;
    alias dp3_hit0_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_3_hit_type0_out_valid : std_logic >>;
    alias dp4_hit0_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_4_hit_type0_out_valid : std_logic >>;
    alias dp5_hit0_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_5_hit_type0_out_valid : std_logic >>;
    alias dp6_hit0_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_6_hit_type0_out_valid : std_logic >>;
    alias dp7_hit0_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_7_hit_type0_out_valid : std_logic >>;
    alias mts0_type1_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_valid : std_logic >>;
    alias mts0_type1_ready is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_ready : std_logic >>;
    alias mts1_type1_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_valid : std_logic >>;
    alias mts1_type1_ready is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_ready : std_logic >>;
    alias hs0_rbcam0_type2_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_valid : std_logic >>;
    alias hs0_rbcam0_type2_ready is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_ready : std_logic >>;
    alias hs0_rbcam0_popcmd_wrreq is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0.v2_core.pop_cmd_fifo_wrreq : std_logic >>;
    alias hs0_rbcam0_popcmd_rdack is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0.v2_core.pop_cmd_fifo_rdack : std_logic >>;
    alias hs0_rbcam0_pop_pipeline_start is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0.v2_core.pop_pipeline_start : std_logic >>;
    alias hs0_rbcam1_type2_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_valid : std_logic >>;
    alias hs0_rbcam1_type2_ready is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_ready : std_logic >>;
    alias hs0_rbcam2_type2_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_valid : std_logic >>;
    alias hs0_rbcam2_type2_ready is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_ready : std_logic >>;
    alias hs0_rbcam3_type2_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_valid : std_logic >>;
    alias hs0_rbcam3_type2_ready is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_ready : std_logic >>;
    alias hs1_rbcam0_type2_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_valid : std_logic >>;
    alias hs1_rbcam0_type2_ready is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_ready : std_logic >>;
    alias hs1_rbcam0_popcmd_wrreq is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0.v2_core.pop_cmd_fifo_wrreq : std_logic >>;
    alias hs1_rbcam0_popcmd_rdack is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0.v2_core.pop_cmd_fifo_rdack : std_logic >>;
    alias hs1_rbcam0_pop_pipeline_start is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0.v2_core.pop_pipeline_start : std_logic >>;
    alias hs1_rbcam1_type2_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_valid : std_logic >>;
    alias hs1_rbcam1_type2_ready is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_ready : std_logic >>;
    alias hs1_rbcam2_type2_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_valid : std_logic >>;
    alias hs1_rbcam2_type2_ready is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_ready : std_logic >>;
    alias hs1_rbcam3_type2_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_valid : std_logic >>;
    alias hs1_rbcam3_type2_ready is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_ready : std_logic >>;
    alias hs0_type3_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.hit_type3_valid : std_logic >>;
    alias hs0_type3_ready is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.hit_type3_ready : std_logic >>;
    alias hs1_type3_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.hit_type3_valid : std_logic >>;
    alias hs1_type3_ready is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.hit_type3_ready : std_logic >>;
    alias hs0_frame_dp_rc_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out4_valid : std_logic >>;
    alias hs0_frame_dp_rc_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out4_data : std_logic_vector(8 downto 0) >>;
    alias hs1_frame_dp_rc_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out4_valid : std_logic >>;
    alias hs1_frame_dp_rc_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out4_data : std_logic_vector(8 downto 0) >>;
    alias hs0_frame_xcvr_rc_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_ctrl_cdc_d2x_out_valid : std_logic >>;
    alias hs0_frame_xcvr_rc_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_ctrl_cdc_d2x_out_data : std_logic_vector(8 downto 0) >>;
    alias hs1_frame_xcvr_rc_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_ctrl_cdc_d2x_out_valid : std_logic >>;
    alias hs1_frame_xcvr_rc_data is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_ctrl_cdc_d2x_out_data : std_logic_vector(8 downto 0) >>;
    alias hs0_frame_loss8fill_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.frame_debug_loss8fill_valid : std_logic >>;
    alias hs0_frame_delay8loss_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.frame_debug_delay8loss_valid : std_logic >>;
    alias hs1_frame_loss8fill_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.frame_debug_loss8fill_valid : std_logic >>;
    alias hs1_frame_delay8loss_valid is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.frame_debug_delay8loss_valid : std_logic >>;
    alias datapath_lvds_outclock_clk is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem_lvds_outclock_clk : std_logic >>;
    alias hist0_csr_address is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_histogram_statistics_0_csr_address : std_logic_vector(4 downto 0) >>;
    alias hist0_csr_read is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_histogram_statistics_0_csr_read : std_logic >>;
    alias hist0_csr_write is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_histogram_statistics_0_csr_write : std_logic >>;
    alias hist0_csr_writedata is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_histogram_statistics_0_csr_writedata : std_logic_vector(31 downto 0) >>;
    alias hist0_csr_readdata is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_histogram_statistics_0_csr_readdata : std_logic_vector(31 downto 0) >>;
    alias hist0_csr_waitrequest is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_histogram_statistics_0_csr_waitrequest : std_logic >>;
    alias hist1_csr_address is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_histogram_statistics_1_csr_address : std_logic_vector(4 downto 0) >>;
    alias hist1_csr_read is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_histogram_statistics_1_csr_read : std_logic >>;
    alias hist1_csr_write is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_histogram_statistics_1_csr_write : std_logic >>;
    alias hist1_csr_writedata is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_histogram_statistics_1_csr_writedata : std_logic_vector(31 downto 0) >>;
    alias hist1_csr_readdata is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_histogram_statistics_1_csr_readdata : std_logic_vector(31 downto 0) >>;
    alias hist1_csr_waitrequest is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_histogram_statistics_1_csr_waitrequest : std_logic >>;
    alias emu0_csr_address is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_0_csr_address : std_logic_vector(3 downto 0) >>;
    alias emu0_csr_read is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_0_csr_read : std_logic >>;
    alias emu0_csr_write is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_0_csr_write : std_logic >>;
    alias emu0_csr_writedata is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_0_csr_writedata : std_logic_vector(31 downto 0) >>;
    alias emu0_csr_waitrequest is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_0_csr_waitrequest : std_logic >>;
    alias emu1_csr_address is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_1_csr_address : std_logic_vector(3 downto 0) >>;
    alias emu1_csr_read is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_1_csr_read : std_logic >>;
    alias emu1_csr_write is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_1_csr_write : std_logic >>;
    alias emu1_csr_writedata is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_1_csr_writedata : std_logic_vector(31 downto 0) >>;
    alias emu1_csr_waitrequest is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_1_csr_waitrequest : std_logic >>;
    alias emu2_csr_address is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_2_csr_address : std_logic_vector(3 downto 0) >>;
    alias emu2_csr_read is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_2_csr_read : std_logic >>;
    alias emu2_csr_write is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_2_csr_write : std_logic >>;
    alias emu2_csr_writedata is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_2_csr_writedata : std_logic_vector(31 downto 0) >>;
    alias emu2_csr_waitrequest is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_2_csr_waitrequest : std_logic >>;
    alias emu3_csr_address is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_3_csr_address : std_logic_vector(3 downto 0) >>;
    alias emu3_csr_read is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_3_csr_read : std_logic >>;
    alias emu3_csr_write is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_3_csr_write : std_logic >>;
    alias emu3_csr_writedata is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_3_csr_writedata : std_logic_vector(31 downto 0) >>;
    alias emu3_csr_waitrequest is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_3_csr_waitrequest : std_logic >>;
    alias emu4_csr_address is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_4_csr_address : std_logic_vector(3 downto 0) >>;
    alias emu4_csr_read is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_4_csr_read : std_logic >>;
    alias emu4_csr_write is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_4_csr_write : std_logic >>;
    alias emu4_csr_writedata is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_4_csr_writedata : std_logic_vector(31 downto 0) >>;
    alias emu4_csr_waitrequest is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_4_csr_waitrequest : std_logic >>;
    alias emu5_csr_address is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_5_csr_address : std_logic_vector(3 downto 0) >>;
    alias emu5_csr_read is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_5_csr_read : std_logic >>;
    alias emu5_csr_write is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_5_csr_write : std_logic >>;
    alias emu5_csr_writedata is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_5_csr_writedata : std_logic_vector(31 downto 0) >>;
    alias emu5_csr_waitrequest is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_5_csr_waitrequest : std_logic >>;
    alias emu6_csr_address is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_6_csr_address : std_logic_vector(3 downto 0) >>;
    alias emu6_csr_read is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_6_csr_read : std_logic >>;
    alias emu6_csr_write is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_6_csr_write : std_logic >>;
    alias emu6_csr_writedata is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_6_csr_writedata : std_logic_vector(31 downto 0) >>;
    alias emu6_csr_waitrequest is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_6_csr_waitrequest : std_logic >>;
    alias emu7_csr_address is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_7_csr_address : std_logic_vector(3 downto 0) >>;
    alias emu7_csr_read is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_7_csr_read : std_logic >>;
    alias emu7_csr_write is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_7_csr_write : std_logic >>;
    alias emu7_csr_writedata is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_7_csr_writedata : std_logic_vector(31 downto 0) >>;
    alias emu7_csr_waitrequest is << signal .tb_feb_system_v3_soak.dut.data_path_subsystem.mm_interconnect_1_emulator_mutrig_7_csr_waitrequest : std_logic >>;
begin
    clk156 <= not clk156 after G_CLK156_PERIOD / 2;
    clk125 <= not clk125 after G_CLK125_PERIOD / 2;
    clk50  <= not clk50 after G_CLK50_PERIOD / 2;

    sc_main_mem_data <= cmd_mem(to_integer(unsigned(sc_main_mem_addr(7 downto 0))));
    sense_dq_in      <= sense_dq_pad;

    sc_down_data  <= sc_main_links(0).data;
    sc_down_datak <= sc_main_links(0).datak;

    gen_sense_dq_iobuf : for i in sense_dq_pad'range generate
    begin
        sense_dq_pad(i) <= sense_dq_out(i) when sense_dq_oe(i) = '1' else 'H';
    end generate gen_sense_dq_iobuf;

    proc_reply_bridge : process (all)
        variable link_v : link_t;
    begin
        if sc_up_valid = '1' and sc_up_channel = UPLOAD_CH_SC_CONST then
            link_v      := to_link(sc_up_data(31 downto 0), sc_up_data(35 downto 32));
            link_v.idle := '0';
            link_v.sop  := sc_up_sop;
            link_v.eop  := sc_up_eop;
            secondary_links(0) <= link_v;
        else
            secondary_links(0) <= LINK_IDLE;
        end if;
    end process proc_reply_bridge;

    proc_rsp_capture : process (clk156)
    begin
        if rising_edge(clk156) then
            if reset_n = '0' then
                rsp_mem         <= (others => (others => '0'));
                rsp_write_count <= 0;
            elsif sc_secondary_mem_we = '1' then
                assert rsp_write_count < RSP_DEPTH_CONST
                    report "SC response capture overflow"
                    severity failure;
                rsp_mem(rsp_write_count) <= sc_secondary_mem_data;
                rsp_write_count          <= rsp_write_count + 1;
            end if;
        end if;
    end process proc_rsp_capture;

    proc_upper_frame_count : process (clk156)
    begin
        if rising_edge(clk156) then
            if reset_n = '0' then
                upper_words_accepted  <= 0;
                upper_frames_accepted <= 0;
            elsif upper_hit_valid = '1' and upper_hit_ready = '1' then
                upper_words_accepted <= upper_words_accepted + 1;
                if upper_hit_sop = '1' then
                    upper_frames_accepted <= upper_frames_accepted + 1;
                end if;
            end if;
        end if;
    end process proc_upper_frame_count;

    proc_lower_frame_count : process (clk156)
    begin
        if rising_edge(clk156) then
            if reset_n = '0' then
                lower_words_accepted  <= 0;
                lower_frames_accepted <= 0;
            elsif upload_data1_valid = '1' and upload_data1_ready = '1' then
                lower_words_accepted <= lower_words_accepted + 1;
                if upload_data1_sop = '1' then
                    lower_frames_accepted <= lower_frames_accepted + 1;
                end if;
            end if;
        end if;
    end process proc_lower_frame_count;

    proc_run_control_monitor : process (clk125)
    begin
        if rising_edge(clk125) then
            if reset_n = '0' then
                runctrl_seen_mask     <= (others => '0');
                emulator_rc_seen_mask <= (others => '0');
                frame_xcvr_rc_seen_mask <= (others => '0');
            else
                if rc_hist0_valid = '1' and rc_hist0_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(0) <= '1';
                end if;
                if rc_mts0_valid = '1' and rc_mts0_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(1) <= '1';
                end if;
                if rc_dp0_valid = '1' and rc_dp0_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(2) <= '1';
                end if;
                if rc_dp1_valid = '1' and rc_dp1_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(3) <= '1';
                end if;
                if rc_dp2_valid = '1' and rc_dp2_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(4) <= '1';
                end if;
                if rc_dp3_valid = '1' and rc_dp3_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(5) <= '1';
                end if;
                if rc_hitstack0_valid = '1' and rc_hitstack0_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(6) <= '1';
                end if;
                if rc_reset_valid = '1' and rc_reset_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(7) <= '1';
                end if;
                if rc_dp4_valid = '1' and rc_dp4_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(8) <= '1';
                end if;
                if rc_dp5_valid = '1' and rc_dp5_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(9) <= '1';
                end if;
                if rc_dp6_valid = '1' and rc_dp6_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(10) <= '1';
                end if;
                if rc_dp7_valid = '1' and rc_dp7_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(11) <= '1';
                end if;
                if rc_mts1_valid = '1' and rc_mts1_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(12) <= '1';
                end if;
                if rc_injector_valid = '1' and rc_injector_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(13) <= '1';
                end if;
                if rc_hitstack1_valid = '1' and rc_hitstack1_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(14) <= '1';
                end if;
                if rc_hist1_valid = '1' and rc_hist1_data = RC_RUNNING_CONST then
                    runctrl_seen_mask(15) <= '1';
                end if;

                if emu_rc_out1_valid = '1' and emu_rc_out1_data = RC_RUNNING_CONST then
                    emulator_rc_seen_mask(0) <= '1';
                end if;
                if emu_rc_out2_valid = '1' and emu_rc_out2_data = RC_RUNNING_CONST then
                    emulator_rc_seen_mask(1) <= '1';
                end if;
                if emu_rc_out3_valid = '1' and emu_rc_out3_data = RC_RUNNING_CONST then
                    emulator_rc_seen_mask(2) <= '1';
                end if;
                if emu_rc_out4_valid = '1' and emu_rc_out4_data = RC_RUNNING_CONST then
                    emulator_rc_seen_mask(3) <= '1';
                end if;
                if emu_rc_out5_valid = '1' and emu_rc_out5_data = RC_RUNNING_CONST then
                    emulator_rc_seen_mask(4) <= '1';
                end if;
                if emu_rc_out6_valid = '1' and emu_rc_out6_data = RC_RUNNING_CONST then
                    emulator_rc_seen_mask(5) <= '1';
                end if;
                if emu_rc_out7_valid = '1' and emu_rc_out7_data = RC_RUNNING_CONST then
                    emulator_rc_seen_mask(6) <= '1';
                end if;
                if emu_rc_out8_valid = '1' and emu_rc_out8_data = RC_RUNNING_CONST then
                    emulator_rc_seen_mask(7) <= '1';
                end if;

                if hs0_frame_xcvr_rc_valid = '1' and hs0_frame_xcvr_rc_data = RC_RUNNING_CONST then
                    frame_xcvr_rc_seen_mask(0) <= '1';
                end if;
                if hs1_frame_xcvr_rc_valid = '1' and hs1_frame_xcvr_rc_data = RC_RUNNING_CONST then
                    frame_xcvr_rc_seen_mask(1) <= '1';
                end if;
            end if;
        end if;
    end process proc_run_control_monitor;

    proc_datapath_progress_monitor : process (clk125)
    begin
        if rising_edge(clk125) then
            if reset_n = '0' then
                ext_emu_word_count          <= 0;
                dp_hit0_word_count          <= 0;
                mts_type1_word_count        <= 0;
                hit_stack_ingress_word_count <= 0;
                hitstack_input_rc_seen_mask <= (others => '0');
                frame_dp_rc_seen_mask       <= (others => '0');
                hit_stack0_type2_word_count <= 0;
                hit_stack1_type2_word_count <= 0;
            else
                ext_emu_word_count <= ext_emu_word_count
                    + sl_to_nat(emu0_tx_valid)
                    + sl_to_nat(emu1_tx_valid)
                    + sl_to_nat(emu2_tx_valid)
                    + sl_to_nat(emu3_tx_valid)
                    + sl_to_nat(emu4_tx_valid)
                    + sl_to_nat(emu5_tx_valid)
                    + sl_to_nat(emu6_tx_valid)
                    + sl_to_nat(emu7_tx_valid);

                dp_hit0_word_count <= dp_hit0_word_count
                    + sl_to_nat(dp0_hit0_valid)
                    + sl_to_nat(dp1_hit0_valid)
                    + sl_to_nat(dp2_hit0_valid)
                    + sl_to_nat(dp3_hit0_valid)
                    + sl_to_nat(dp4_hit0_valid)
                    + sl_to_nat(dp5_hit0_valid)
                    + sl_to_nat(dp6_hit0_valid)
                    + sl_to_nat(dp7_hit0_valid);

                mts_type1_word_count <= mts_type1_word_count
                    + sl_to_nat(mts0_type1_valid)
                    + sl_to_nat(mts1_type1_valid);

                hit_stack_ingress_word_count <= hit_stack_ingress_word_count
                    + bool_to_nat(mts0_type1_valid = '1' and mts0_type1_ready = '1')
                    + bool_to_nat(mts1_type1_valid = '1' and mts1_type1_ready = '1');

                if rc_hitstack0_valid = '1' and rc_hitstack0_data = RC_RUNNING_CONST then
                    hitstack_input_rc_seen_mask(0) <= '1';
                end if;
                if rc_hitstack1_valid = '1' and rc_hitstack1_data = RC_RUNNING_CONST then
                    hitstack_input_rc_seen_mask(1) <= '1';
                end if;

                if hs0_frame_dp_rc_valid = '1' and hs0_frame_dp_rc_data = RC_RUNNING_CONST then
                    frame_dp_rc_seen_mask(0) <= '1';
                end if;
                if hs1_frame_dp_rc_valid = '1' and hs1_frame_dp_rc_data = RC_RUNNING_CONST then
                    frame_dp_rc_seen_mask(1) <= '1';
                end if;

                hit_stack0_type2_word_count <= hit_stack0_type2_word_count
                    + bool_to_nat(hs0_rbcam0_type2_valid = '1' and hs0_rbcam0_type2_ready = '1')
                    + bool_to_nat(hs0_rbcam1_type2_valid = '1' and hs0_rbcam1_type2_ready = '1')
                    + bool_to_nat(hs0_rbcam2_type2_valid = '1' and hs0_rbcam2_type2_ready = '1')
                    + bool_to_nat(hs0_rbcam3_type2_valid = '1' and hs0_rbcam3_type2_ready = '1');

                hit_stack1_type2_word_count <= hit_stack1_type2_word_count
                    + bool_to_nat(hs1_rbcam0_type2_valid = '1' and hs1_rbcam0_type2_ready = '1')
                    + bool_to_nat(hs1_rbcam1_type2_valid = '1' and hs1_rbcam1_type2_ready = '1')
                    + bool_to_nat(hs1_rbcam2_type2_valid = '1' and hs1_rbcam2_type2_ready = '1')
                    + bool_to_nat(hs1_rbcam3_type2_valid = '1' and hs1_rbcam3_type2_ready = '1');
            end if;
        end if;
    end process proc_datapath_progress_monitor;

    proc_frame_loss_monitor : process (clk125)
    begin
        if rising_edge(clk125) then
            if reset_n = '0' then
                hs0_frame_loss8fill_count <= 0;
                hs0_frame_delay8loss_count <= 0;
                hs1_frame_loss8fill_count <= 0;
                hs1_frame_delay8loss_count <= 0;
            else
                hs0_frame_loss8fill_count <= hs0_frame_loss8fill_count + sl_to_nat(hs0_frame_loss8fill_valid);
                hs0_frame_delay8loss_count <= hs0_frame_delay8loss_count + sl_to_nat(hs0_frame_delay8loss_valid);
                hs1_frame_loss8fill_count <= hs1_frame_loss8fill_count + sl_to_nat(hs1_frame_loss8fill_valid);
                hs1_frame_delay8loss_count <= hs1_frame_delay8loss_count + sl_to_nat(hs1_frame_delay8loss_valid);
            end if;
        end if;
    end process proc_frame_loss_monitor;

    proc_hit_stack_pop_monitor : process (clk125)
    begin
        if rising_edge(clk125) then
            if reset_n = '0' then
                hit_stack0_type2_valid_cycles <= 0;
                hit_stack1_type2_valid_cycles <= 0;
                hs0_popcmd_wrreq_count <= 0;
                hs0_popcmd_rdack_count <= 0;
                hs0_pop_pipeline_start_count <= 0;
                hs1_popcmd_wrreq_count <= 0;
                hs1_popcmd_rdack_count <= 0;
                hs1_pop_pipeline_start_count <= 0;
            else
                hit_stack0_type2_valid_cycles <= hit_stack0_type2_valid_cycles
                    + sl_to_nat(hs0_rbcam0_type2_valid)
                    + sl_to_nat(hs0_rbcam1_type2_valid)
                    + sl_to_nat(hs0_rbcam2_type2_valid)
                    + sl_to_nat(hs0_rbcam3_type2_valid);
                hit_stack1_type2_valid_cycles <= hit_stack1_type2_valid_cycles
                    + sl_to_nat(hs1_rbcam0_type2_valid)
                    + sl_to_nat(hs1_rbcam1_type2_valid)
                    + sl_to_nat(hs1_rbcam2_type2_valid)
                    + sl_to_nat(hs1_rbcam3_type2_valid);
                hs0_popcmd_wrreq_count <= hs0_popcmd_wrreq_count + sl_to_nat(hs0_rbcam0_popcmd_wrreq);
                hs0_popcmd_rdack_count <= hs0_popcmd_rdack_count + sl_to_nat(hs0_rbcam0_popcmd_rdack);
                hs0_pop_pipeline_start_count <= hs0_pop_pipeline_start_count + sl_to_nat(hs0_rbcam0_pop_pipeline_start);
                hs1_popcmd_wrreq_count <= hs1_popcmd_wrreq_count + sl_to_nat(hs1_rbcam0_popcmd_wrreq);
                hs1_popcmd_rdack_count <= hs1_popcmd_rdack_count + sl_to_nat(hs1_rbcam0_popcmd_rdack);
                hs1_pop_pipeline_start_count <= hs1_pop_pipeline_start_count + sl_to_nat(hs1_rbcam0_pop_pipeline_start);
            end if;
        end if;
    end process proc_hit_stack_pop_monitor;

    proc_hit_type3_monitor : process (clk156)
    begin
        if rising_edge(clk156) then
            if reset_n = '0' then
                hit_stack0_type3_word_count <= 0;
                hit_stack1_type3_word_count <= 0;
            else
                hit_stack0_type3_word_count <= hit_stack0_type3_word_count
                    + bool_to_nat(hs0_type3_valid = '1' and hs0_type3_ready = '1');
                hit_stack1_type3_word_count <= hit_stack1_type3_word_count
                    + bool_to_nat(hs1_type3_valid = '1' and hs1_type3_ready = '1');
            end if;
        end if;
    end process proc_hit_type3_monitor;

    proc_progress_heartbeat : process (clk156)
    begin
        if rising_edge(clk156) then
            if reset_n = '0' or external_rc_active = '0' then
                progress_heartbeat_count <= 0;
            elsif G_PROGRESS_HEARTBEAT_CYCLES /= 0 then
                if progress_heartbeat_count + 1 >= G_PROGRESS_HEARTBEAT_CYCLES then
                    progress_heartbeat_count <= 0;
                    report "SOAK heartbeat @" & time'image(now)
                        & ": runctrl_mask=0x" & to_hstring(runctrl_seen_mask)
                        & ", emu_rc_mask=0x" & to_hstring(emulator_rc_seen_mask)
                        & ", ext_emu_words=" & integer'image(ext_emu_word_count)
                        & ", dp_hit0_words=" & integer'image(dp_hit0_word_count)
                        & ", upper_frames=" & integer'image(upper_frames_accepted)
                        & ", lower_frames=" & integer'image(lower_frames_accepted)
                        severity note;
                else
                    progress_heartbeat_count <= progress_heartbeat_count + 1;
                end if;
            end if;
        end if;
    end process proc_progress_heartbeat;

    sc_main_inst : entity work.swb_sc_main
        generic map (
            NLINKS => NLINKS_CONST
        )
        port map (
            i_length_we => sc_length_we,
            i_length    => sc_length,
            i_mem_data  => sc_main_mem_data,
            o_mem_addr  => sc_main_mem_addr,
            o_mem_data  => sc_main_links,
            o_injection => sc_main_injection,
            o_done      => sc_main_done,
            o_state     => sc_main_state,
            i_reset_n   => reset_n,
            i_clk       => clk156
        );

    dut : entity work.feb_system_v3
        port map (
            cclk156_clk                           => clk156,
            download_sc_data                      => sc_down_data,
            download_sc_datak                     => sc_down_datak,
            download_sc_ready                     => sc_down_ready,
            inject_pulse                          => inject_pulse,
            lvds_pll_inclock_clk                  => clk125,
            max10_link_csn                        => max10_link_csn,
            max10_link_clk                        => max10_link_clk,
            max10_link_mosi_in                    => max10_link_mosi_in,
            max10_link_mosi_out                   => max10_link_mosi_out,
            max10_link_mosi_oe                    => max10_link_mosi_oe,
            max10_link_miso_in                    => max10_link_miso_in,
            max10_link_miso_out                   => max10_link_miso_out,
            max10_link_miso_oe                    => max10_link_miso_oe,
            max10_link_d1_in                      => max10_link_d1_in,
            max10_link_d1_out                     => max10_link_d1_out,
            max10_link_d1_oe                      => max10_link_d1_oe,
            max10_link_d2_in                      => max10_link_d2_in,
            max10_link_d2_out                     => max10_link_d2_out,
            max10_link_d2_oe                      => max10_link_d2_oe,
            max10_link_d3_in                      => max10_link_d3_in,
            max10_link_d3_out                     => max10_link_d3_out,
            max10_link_d3_oe                      => max10_link_d3_oe,
            max10_link_clock_clk                  => clk50,
            mclk125_clk                           => clk125,
            mutrig_cfg_ctrl_0_spi_export2top_miso => spi_miso,
            mutrig_cfg_ctrl_0_spi_export2top_mosi => spi_mosi,
            mutrig_cfg_ctrl_0_spi_export2top_sclk => spi_sclk,
            mutrig_cfg_ctrl_0_spi_export2top_ssn  => spi_ssn,
            mutrig_reset_reset                    => mutrig_reset,
            osc_clock_50_in_clk                   => clk50,
            pulse_out_conduit_pulse               => pulse_out_conduit,
            redriver_losn                         => redriver_losn,
            reset_3_reset_n                       => reset_n,
            sense_dq_in                           => sense_dq_in,
            sense_dq_out                          => sense_dq_out,
            sense_dq_oe                           => sense_dq_oe,
            serial_data                           => serial_data,
            to_firefly_ucc8_scl                   => firefly_scl,
            to_firefly_ucc8_present_n             => firefly_present_n,
            to_firefly_ucc8_sda                   => firefly_sda,
            to_firefly_ucc8_reset_n               => firefly_reset_n,
            to_firefly_ucc8_select_n              => firefly_select_n,
            to_firefly_ucc8_int_n                 => firefly_int_n,
            upload_data0_sc_rc_data               => sc_up_data,
            upload_data0_sc_rc_valid              => sc_up_valid,
            upload_data0_sc_rc_ready              => sc_up_ready,
            upload_data0_sc_rc_startofpacket      => sc_up_sop,
            upload_data0_sc_rc_endofpacket        => sc_up_eop,
            upload_data0_sc_rc_channel            => sc_up_channel,
            upload_data1_data                     => upload_data1_data,
            upload_data1_valid                    => upload_data1_valid,
            upload_data1_ready                    => upload_data1_ready,
            upload_data1_startofpacket            => upload_data1_sop,
            upload_data1_endofpacket              => upload_data1_eop
        );

    sc_secondary_inst : entity work.swb_sc_secondary
        generic map (
            NLINKS    => NLINKS_CONST,
            skip_init => '1'
        )
        port map (
            i_link_enable       => secondary_enable,
            i_link_data         => secondary_links,
            o_mem_addr          => sc_secondary_mem_addr,
            o_mem_addr_finished => sc_secondary_addr_done,
            o_mem_data          => sc_secondary_mem_data,
            o_mem_we            => sc_secondary_mem_we,
            o_state             => sc_secondary_state,
            i_reset_n           => reset_n,
            i_clk               => clk156
        );

    swb_phy_ingress_inst : entity work.swb_phy_ingress_stub
        generic map (
            ENABLE_BACKPRESSURE_G => false
        )
        port map (
            clk     => clk156,
            reset_n => reset_n,
            link0_data  => sc_up_data,
            link0_valid => sc_up_valid,
            link0_sop   => sc_up_sop,
            link0_eop   => sc_up_eop,
            link0_ready => sc_up_ready,
            link1_data  => upload_data1_data,
            link1_valid => upload_data1_valid,
            link1_sop   => upload_data1_sop,
            link1_eop   => upload_data1_eop,
            link1_ready => upload_data1_ready,
            link0_words_accepted  => swb_link0_words,
            link0_frames_accepted => swb_link0_frames,
            link1_words_accepted  => swb_link1_words,
            link1_frames_accepted => swb_link1_frames
        );

    proc_stimulus : process
        procedure clear_command_mem is
        begin
            for i in cmd_mem'range loop
                cmd_mem(i) <= (others => '0');
            end loop;
            sc_length    <= (others => '0');
            sc_length_we <= '0';
        end procedure clear_command_mem;

        procedure pulse_reset is
        begin
            clear_command_mem;
            external_rc_active <= '0';
            reset_n            <= '0';
            wait for G_RESET_ASSERT_TIME;
            wait until rising_edge(clk156);
            reset_n <= '1';
            wait for G_POST_RESET_SETTLE;
        end procedure pulse_reset;

        procedure wait_for_main_idle is
        begin
            for i in 0 to 2047 loop
                wait until rising_edge(clk156);
                exit when sc_main_done = '1';
            end loop;
            assert sc_main_done = '1'
                report "swb_sc_main did not return to idle"
                severity failure;
        end procedure wait_for_main_idle;

        procedure load_single_read_command (
            constant address_value : in natural
        ) is
        begin
            clear_command_mem;
            cmd_mem(0) <= READ_PREAMBLE_CONST;
            cmd_mem(1) <= x"00" & std_logic_vector(to_unsigned(address_value, 24));
            cmd_mem(2) <= x"00000001";
            cmd_mem(3) <= TRAILER_CONST;
            sc_length  <= x"0002";
            wait until rising_edge(clk156);
        end procedure load_single_read_command;

        procedure load_single_write_command (
            constant address_value  : in natural;
            constant data_value     : in std_logic_vector(31 downto 0);
            constant suppress_reply : in boolean := true
        ) is
            variable addr_word_v : std_logic_vector(31 downto 0);
        begin
            addr_word_v := x"00" & std_logic_vector(to_unsigned(address_value, 24));
            if suppress_reply then
                addr_word_v(24) := '1';
            end if;

            clear_command_mem;
            cmd_mem(0) <= WRITE_PREAMBLE_CONST;
            cmd_mem(1) <= addr_word_v;
            cmd_mem(2) <= x"00000001";
            cmd_mem(3) <= data_value;
            cmd_mem(4) <= TRAILER_CONST;
            sc_length  <= x"0003";
            wait until rising_edge(clk156);
        end procedure load_single_write_command;

        procedure start_command is
        begin
            wait_for_main_idle;
            sc_length_we <= '1';
            wait until rising_edge(clk156);
            sc_length_we <= '0';
        end procedure start_command;

        procedure wait_for_response (
            constant start_index   : in natural;
            constant expected_words : in natural;
            constant timeout_cycles : in natural;
            constant case_name      : in string
        ) is
            variable quiet_count_v      : natural := 0;
            variable previous_count_v   : natural := 0;
        begin
            for i in 0 to timeout_cycles loop
                wait until rising_edge(clk156);
                exit when rsp_write_count >= start_index + expected_words;
            end loop;
            assert rsp_write_count >= start_index + expected_words
                report case_name & ": timeout waiting for reply, rsp_write_count="
                    & integer'image(rsp_write_count)
                    & ", start_index=" & integer'image(start_index)
                    & ", expected_words=" & integer'image(expected_words)
                severity failure;

            previous_count_v := rsp_write_count;
            while quiet_count_v < RESPONSE_QUIET_CYCLES_CONST loop
                wait until rising_edge(clk156);
                if rsp_write_count = previous_count_v then
                    quiet_count_v := quiet_count_v + 1;
                else
                    previous_count_v := rsp_write_count;
                    quiet_count_v := 0;
                end if;
            end loop;
        end procedure wait_for_response;

        procedure read32 (
            constant case_name     : in string;
            constant address_value : in natural;
            variable data_value    : out std_logic_vector(31 downto 0)
        ) is
            variable start_index_v : natural;
            variable expected_addr_word_v : std_logic_vector(31 downto 0);
        begin
            start_index_v := rsp_write_count;
            load_single_read_command(address_value);
            start_command;
            wait_for_response(start_index_v, 5, RESPONSE_TIMEOUT_CYCLES_CONST, case_name);

            expected_addr_word_v := x"00" & std_logic_vector(to_unsigned(address_value, 24));
            assert rsp_mem(start_index_v + 0) = READ_PREAMBLE_CONST
                report case_name & ": bad reply preamble, got 0x" & to_hstring(rsp_mem(start_index_v + 0))
                severity failure;
            assert rsp_mem(start_index_v + 1) = expected_addr_word_v
                report case_name & ": bad reply address, got 0x" & to_hstring(rsp_mem(start_index_v + 1))
                severity failure;
            assert read_reply_header_ok(rsp_mem(start_index_v + 2), 1)
                report case_name & ": bad reply header, got 0x" & to_hstring(rsp_mem(start_index_v + 2))
                severity failure;
            assert reply_response_code(rsp_mem(start_index_v + 2)) = "00"
                report case_name & ": bad reply response code, got 0b" & to_string(reply_response_code(rsp_mem(start_index_v + 2)))
                severity failure;
            assert rsp_mem(start_index_v + 4) = TRAILER_CONST
                report case_name & ": bad reply trailer, got 0x" & to_hstring(rsp_mem(start_index_v + 4))
                severity failure;
            data_value := rsp_mem(start_index_v + 3);
        end procedure read32;

        procedure read32_expect (
            constant case_name      : in string;
            constant address_value  : in natural;
            constant expected_value : in std_logic_vector(31 downto 0)
        ) is
            variable data_value_v : std_logic_vector(31 downto 0);
        begin
            read32(case_name, address_value, data_value_v);
            assert data_value_v = expected_value
                report case_name & ": bad read data, got 0x" & to_hstring(data_value_v)
                    & ", expected 0x" & to_hstring(expected_value)
                severity failure;
        end procedure read32_expect;

        procedure write32_quiet (
            constant case_name     : in string;
            constant address_value : in natural;
            constant data_value    : in std_logic_vector(31 downto 0)
        ) is
            variable start_index_v : natural;
            variable expected_addr_word_v : std_logic_vector(31 downto 0);
        begin
            start_index_v := rsp_write_count;
            load_single_write_command(address_value, data_value, false);
            start_command;
            wait_for_response(start_index_v, 4, RESPONSE_TIMEOUT_CYCLES_CONST, case_name);
            expected_addr_word_v := x"00" & std_logic_vector(to_unsigned(address_value, 24));

            assert rsp_mem(start_index_v + 0) = WRITE_PREAMBLE_CONST
                report case_name & ": bad write reply preamble, got 0x" & to_hstring(rsp_mem(start_index_v + 0))
                severity failure;
            assert rsp_mem(start_index_v + 1) = expected_addr_word_v
                report case_name & ": bad write reply address, got 0x" & to_hstring(rsp_mem(start_index_v + 1))
                severity failure;
            assert read_reply_header_ok(rsp_mem(start_index_v + 2), 1)
                report case_name & ": bad write reply header, got 0x" & to_hstring(rsp_mem(start_index_v + 2))
                severity failure;
            assert reply_response_code(rsp_mem(start_index_v + 2)) = "00"
                report case_name & ": bad write reply response code, got 0b" & to_string(reply_response_code(rsp_mem(start_index_v + 2)))
                severity failure;
            assert rsp_mem(start_index_v + 3) = TRAILER_CONST
                report case_name & ": bad write reply trailer, got 0x" & to_hstring(rsp_mem(start_index_v + 3))
                severity failure;
            report case_name & ": wrote 0x" & to_hstring(data_value)
                & " to 0x" & to_hstring(std_logic_vector(to_unsigned(address_value, 24)))
                severity note;
        end procedure write32_quiet;

        procedure wait_cycles (
            constant cycles_value : in natural
        ) is
        begin
            for i in 0 to cycles_value - 1 loop
                wait until rising_edge(clk156);
            end loop;
        end procedure wait_cycles;

        procedure wait_hist_cfg_applied (
            constant case_name : in string;
            constant base_addr : in natural
        ) is
            variable ctrl_word_v : std_logic_vector(31 downto 0);
        begin
            for i in 0 to 255 loop
                read32(case_name & " ctrl poll", base_addr + HIST_CSR_CONTROL_OFF_CONST, ctrl_word_v);
                exit when ctrl_word_v(1) = '0';
            end loop;
            assert ctrl_word_v(1) = '0'
                report case_name & ": histogram control busy bit did not clear, ctrl=0x" & to_hstring(ctrl_word_v)
                severity failure;
            assert ctrl_word_v(24) = '0'
                report case_name & ": histogram control error bit set, ctrl=0x" & to_hstring(ctrl_word_v)
                severity failure;
        end procedure wait_hist_cfg_applied;

        procedure local_hist_idle is
        begin
            hist0_csr_address   <= (others => '0');
            hist0_csr_read      <= '0';
            hist0_csr_write     <= '0';
            hist0_csr_writedata <= (others => '0');
            hist1_csr_address   <= (others => '0');
            hist1_csr_read      <= '0';
            hist1_csr_write     <= '0';
            hist1_csr_writedata <= (others => '0');
        end procedure local_hist_idle;

        procedure local_hist_csr_write (
            constant case_name  : in string;
            constant hist_index : in natural;
            constant addr_value : in natural;
            constant data_value : in std_logic_vector(31 downto 0)
        ) is
            variable cycles_v : natural := 0;
        begin
            wait until rising_edge(datapath_lvds_outclock_clk);
            if hist_index = 0 then
                hist0_csr_address   <= std_logic_vector(to_unsigned(addr_value, hist0_csr_address'length));
                hist0_csr_writedata <= data_value;
                hist0_csr_write     <= '1';
                hist0_csr_read      <= '0';
            else
                hist1_csr_address   <= std_logic_vector(to_unsigned(addr_value, hist1_csr_address'length));
                hist1_csr_writedata <= data_value;
                hist1_csr_write     <= '1';
                hist1_csr_read      <= '0';
            end if;

            loop
                wait until rising_edge(datapath_lvds_outclock_clk);
                exit when ((hist_index = 0) and (hist0_csr_waitrequest = '0'))
                       or ((hist_index = 1) and (hist1_csr_waitrequest = '0'));
                cycles_v := cycles_v + 1;
                assert cycles_v < RESPONSE_TIMEOUT_CYCLES_CONST
                    report case_name & ": local histogram write accept timeout"
                    severity failure;
            end loop;

            local_hist_idle;
            wait until rising_edge(datapath_lvds_outclock_clk);
        end procedure local_hist_csr_write;

        procedure local_hist_csr_read (
            constant case_name  : in string;
            constant hist_index : in natural;
            constant addr_value : in natural;
            variable data_value : out std_logic_vector(31 downto 0)
        ) is
            variable cycles_v : natural := 0;
        begin
            wait until rising_edge(datapath_lvds_outclock_clk);
            if hist_index = 0 then
                hist0_csr_address <= std_logic_vector(to_unsigned(addr_value, hist0_csr_address'length));
                hist0_csr_read    <= '1';
                hist0_csr_write   <= '0';
            else
                hist1_csr_address <= std_logic_vector(to_unsigned(addr_value, hist1_csr_address'length));
                hist1_csr_read    <= '1';
                hist1_csr_write   <= '0';
            end if;

            loop
                wait until rising_edge(datapath_lvds_outclock_clk);
                exit when ((hist_index = 0) and (hist0_csr_waitrequest = '0'))
                       or ((hist_index = 1) and (hist1_csr_waitrequest = '0'));
                cycles_v := cycles_v + 1;
                assert cycles_v < RESPONSE_TIMEOUT_CYCLES_CONST
                    report case_name & ": local histogram read accept timeout"
                    severity failure;
            end loop;

            if hist_index = 0 then
                data_value := hist0_csr_readdata;
            else
                data_value := hist1_csr_readdata;
            end if;
            local_hist_idle;
            wait until rising_edge(datapath_lvds_outclock_clk);
        end procedure local_hist_csr_read;

        procedure local_emu_idle is
        begin
            emu0_csr_address <= (others => '0');
            emu0_csr_read <= '0';
            emu0_csr_write <= '0';
            emu0_csr_writedata <= (others => '0');
            emu1_csr_address <= (others => '0');
            emu1_csr_read <= '0';
            emu1_csr_write <= '0';
            emu1_csr_writedata <= (others => '0');
            emu2_csr_address <= (others => '0');
            emu2_csr_read <= '0';
            emu2_csr_write <= '0';
            emu2_csr_writedata <= (others => '0');
            emu3_csr_address <= (others => '0');
            emu3_csr_read <= '0';
            emu3_csr_write <= '0';
            emu3_csr_writedata <= (others => '0');
            emu4_csr_address <= (others => '0');
            emu4_csr_read <= '0';
            emu4_csr_write <= '0';
            emu4_csr_writedata <= (others => '0');
            emu5_csr_address <= (others => '0');
            emu5_csr_read <= '0';
            emu5_csr_write <= '0';
            emu5_csr_writedata <= (others => '0');
            emu6_csr_address <= (others => '0');
            emu6_csr_read <= '0';
            emu6_csr_write <= '0';
            emu6_csr_writedata <= (others => '0');
            emu7_csr_address <= (others => '0');
            emu7_csr_read <= '0';
            emu7_csr_write <= '0';
            emu7_csr_writedata <= (others => '0');
        end procedure local_emu_idle;

        procedure local_emu_csr_write (
            constant case_name  : in string;
            constant lane_index : in natural;
            constant addr_value : in natural;
            constant data_value : in std_logic_vector(31 downto 0)
        ) is
            variable cycles_v : natural := 0;
        begin
            wait until rising_edge(datapath_lvds_outclock_clk);
            local_emu_idle;
            case lane_index is
                when 0 =>
                    emu0_csr_address <= std_logic_vector(to_unsigned(addr_value, emu0_csr_address'length));
                    emu0_csr_writedata <= data_value;
                    emu0_csr_write <= '1';
                when 1 =>
                    emu1_csr_address <= std_logic_vector(to_unsigned(addr_value, emu1_csr_address'length));
                    emu1_csr_writedata <= data_value;
                    emu1_csr_write <= '1';
                when 2 =>
                    emu2_csr_address <= std_logic_vector(to_unsigned(addr_value, emu2_csr_address'length));
                    emu2_csr_writedata <= data_value;
                    emu2_csr_write <= '1';
                when 3 =>
                    emu3_csr_address <= std_logic_vector(to_unsigned(addr_value, emu3_csr_address'length));
                    emu3_csr_writedata <= data_value;
                    emu3_csr_write <= '1';
                when 4 =>
                    emu4_csr_address <= std_logic_vector(to_unsigned(addr_value, emu4_csr_address'length));
                    emu4_csr_writedata <= data_value;
                    emu4_csr_write <= '1';
                when 5 =>
                    emu5_csr_address <= std_logic_vector(to_unsigned(addr_value, emu5_csr_address'length));
                    emu5_csr_writedata <= data_value;
                    emu5_csr_write <= '1';
                when 6 =>
                    emu6_csr_address <= std_logic_vector(to_unsigned(addr_value, emu6_csr_address'length));
                    emu6_csr_writedata <= data_value;
                    emu6_csr_write <= '1';
                when 7 =>
                    emu7_csr_address <= std_logic_vector(to_unsigned(addr_value, emu7_csr_address'length));
                    emu7_csr_writedata <= data_value;
                    emu7_csr_write <= '1';
                when others =>
                    assert false report case_name & ": bad emulator lane index" severity failure;
            end case;

            loop
                wait until rising_edge(datapath_lvds_outclock_clk);
                case lane_index is
                    when 0 => exit when emu0_csr_waitrequest = '0';
                    when 1 => exit when emu1_csr_waitrequest = '0';
                    when 2 => exit when emu2_csr_waitrequest = '0';
                    when 3 => exit when emu3_csr_waitrequest = '0';
                    when 4 => exit when emu4_csr_waitrequest = '0';
                    when 5 => exit when emu5_csr_waitrequest = '0';
                    when 6 => exit when emu6_csr_waitrequest = '0';
                    when 7 => exit when emu7_csr_waitrequest = '0';
                    when others => null;
                end case;
                cycles_v := cycles_v + 1;
                assert cycles_v < RESPONSE_TIMEOUT_CYCLES_CONST
                    report case_name & ": local emulator write accept timeout"
                    severity failure;
            end loop;

            local_emu_idle;
            wait until rising_edge(datapath_lvds_outclock_clk);
        end procedure local_emu_csr_write;

        procedure local_wait_hist_cfg_applied (
            constant case_name  : in string;
            constant hist_index : in natural
        ) is
            variable ctrl_word_v : std_logic_vector(31 downto 0);
            variable cycles_v    : natural := 0;
        begin
            loop
                local_hist_csr_read(case_name & " ctrl poll", hist_index, HIST_CSR_CONTROL_OFF_CONST, ctrl_word_v);
                exit when ctrl_word_v(1) = '0';
                cycles_v := cycles_v + 1;
                assert cycles_v < RESPONSE_TIMEOUT_CYCLES_CONST
                    report case_name & ": local histogram cfg_apply_pending stuck high, ctrl=0x" & to_hstring(ctrl_word_v)
                    severity failure;
            end loop;

            assert ctrl_word_v(24) = '0'
                report case_name & ": local histogram control error bit set, ctrl=0x" & to_hstring(ctrl_word_v)
                severity failure;
        end procedure local_wait_hist_cfg_applied;

        procedure configure_histogram_local (
            constant case_name  : in string;
            constant hist_index : in natural
        ) is
            variable key_loc_v : std_logic_vector(31 downto 0);
        begin
            if hist_index = 0 then
                key_loc_v := HIST0_KEY_LOC_CONST;
            else
                key_loc_v := HIST1_KEY_LOC_CONST;
            end if;

            local_hist_csr_write(case_name & " left",      hist_index, HIST_CSR_LEFT_OFF_CONST,      x"00000000");
            local_hist_csr_write(case_name & " bin_width", hist_index, HIST_CSR_BIN_WIDTH_OFF_CONST, x"00000001");
            local_hist_csr_write(case_name & " key_loc",   hist_index, HIST_CSR_KEY_LOC_OFF_CONST,   key_loc_v);
            local_hist_csr_write(case_name & " interval",  hist_index, HIST_CSR_INTERVAL_OFF_CONST,  HIST_INTERVAL_CONST);
            local_hist_csr_write(case_name & " control",   hist_index, HIST_CSR_CONTROL_OFF_CONST,   HIST_CONTROL_RUN_CONST);
            local_wait_hist_cfg_applied(case_name, hist_index);
        end procedure configure_histogram_local;

        procedure freeze_histogram_local (
            constant case_name  : in string;
            constant hist_index : in natural
        ) is
            variable ctrl_word_v : std_logic_vector(31 downto 0);
        begin
            local_hist_csr_write(case_name & " control stop", hist_index, HIST_CSR_CONTROL_OFF_CONST, HIST_CONTROL_STOP_CONST);
            local_hist_csr_read(case_name & " control readback", hist_index, HIST_CSR_CONTROL_OFF_CONST, ctrl_word_v);
            assert ctrl_word_v(1) = '0'
                report case_name & ": local histogram freeze left cfg_apply_pending set, ctrl=0x" & to_hstring(ctrl_word_v)
                severity failure;
            assert ctrl_word_v(24) = '0'
                report case_name & ": local histogram freeze raised error bit, ctrl=0x" & to_hstring(ctrl_word_v)
                severity failure;
        end procedure freeze_histogram_local;

        procedure read_hist_status_local (
            constant case_name      : in string;
            constant hist_index     : in natural;
            variable ctrl_word      : out std_logic_vector(31 downto 0);
            variable bank_status    : out std_logic_vector(31 downto 0);
            variable total_hits     : out std_logic_vector(31 downto 0);
            variable dropped_hits   : out std_logic_vector(31 downto 0);
            variable underflow_hits : out std_logic_vector(31 downto 0);
            variable overflow_hits  : out std_logic_vector(31 downto 0)
        ) is
        begin
            local_hist_csr_read(case_name & " ctrl",      hist_index, HIST_CSR_CONTROL_OFF_CONST,   ctrl_word);
            local_hist_csr_read(case_name & " bank",      hist_index, HIST_CSR_BANK_OFF_CONST,      bank_status);
            local_hist_csr_read(case_name & " total",     hist_index, HIST_CSR_TOTAL_OFF_CONST,     total_hits);
            local_hist_csr_read(case_name & " dropped",   hist_index, HIST_CSR_DROPPED_OFF_CONST,   dropped_hits);
            local_hist_csr_read(case_name & " underflow", hist_index, HIST_CSR_UNDERFLOW_OFF_CONST, underflow_hits);
            local_hist_csr_read(case_name & " overflow",  hist_index, HIST_CSR_OVERFLOW_OFF_CONST,  overflow_hits);
        end procedure read_hist_status_local;

        procedure configure_histogram (
            constant case_name : in string;
            constant hist_index : in natural
        ) is
            variable base_addr_v : natural;
            variable key_loc_v : std_logic_vector(31 downto 0);
        begin
            if hist_index = 0 then
                base_addr_v := HIST0_CSR_BASE_ADDR_CONST;
                key_loc_v := HIST0_KEY_LOC_CONST;
            else
                base_addr_v := HIST1_CSR_BASE_ADDR_CONST;
                key_loc_v := HIST1_KEY_LOC_CONST;
            end if;

            write32_quiet(case_name & " left",      base_addr_v + HIST_CSR_LEFT_OFF_CONST,      x"00000000");
            write32_quiet(case_name & " bin_width", base_addr_v + HIST_CSR_BIN_WIDTH_OFF_CONST, x"00000001");
            write32_quiet(case_name & " key_loc",   base_addr_v + HIST_CSR_KEY_LOC_OFF_CONST,   key_loc_v);
            write32_quiet(case_name & " interval",  base_addr_v + HIST_CSR_INTERVAL_OFF_CONST,  HIST_INTERVAL_CONST);
            write32_quiet(case_name & " control",   base_addr_v + HIST_CSR_CONTROL_OFF_CONST,   HIST_CONTROL_RUN_CONST);
            wait_hist_cfg_applied(case_name, base_addr_v);
        end procedure configure_histogram;

        procedure freeze_histogram (
            constant case_name : in string;
            constant hist_index : in natural
        ) is
            variable base_addr_v : natural;
            variable ctrl_word_v : std_logic_vector(31 downto 0);
        begin
            if hist_index = 0 then
                base_addr_v := HIST0_CSR_BASE_ADDR_CONST;
            else
                base_addr_v := HIST1_CSR_BASE_ADDR_CONST;
            end if;

            write32_quiet(case_name & " control stop", base_addr_v + HIST_CSR_CONTROL_OFF_CONST, HIST_CONTROL_STOP_CONST);
            read32(case_name & " control readback", base_addr_v + HIST_CSR_CONTROL_OFF_CONST, ctrl_word_v);
            assert ctrl_word_v(1) = '0'
                report case_name & ": histogram freeze left cfg_apply_pending set, ctrl=0x" & to_hstring(ctrl_word_v)
                severity failure;
            assert ctrl_word_v(24) = '0'
                report case_name & ": histogram freeze raised error bit, ctrl=0x" & to_hstring(ctrl_word_v)
                severity failure;
        end procedure freeze_histogram;

        procedure read_hist_status (
            constant case_name      : in string;
            constant hist_index     : in natural;
            variable ctrl_word      : out std_logic_vector(31 downto 0);
            variable bank_status    : out std_logic_vector(31 downto 0);
            variable total_hits     : out std_logic_vector(31 downto 0);
            variable dropped_hits   : out std_logic_vector(31 downto 0);
            variable underflow_hits : out std_logic_vector(31 downto 0);
            variable overflow_hits  : out std_logic_vector(31 downto 0)
        ) is
            variable base_addr_v : natural;
        begin
            if hist_index = 0 then
                base_addr_v := HIST0_CSR_BASE_ADDR_CONST;
            else
                base_addr_v := HIST1_CSR_BASE_ADDR_CONST;
            end if;
            read32(case_name & " ctrl",      base_addr_v + HIST_CSR_CONTROL_OFF_CONST,   ctrl_word);
            read32(case_name & " bank",      base_addr_v + HIST_CSR_BANK_OFF_CONST,      bank_status);
            read32(case_name & " total",     base_addr_v + HIST_CSR_TOTAL_OFF_CONST,     total_hits);
            read32(case_name & " dropped",   base_addr_v + HIST_CSR_DROPPED_OFF_CONST,   dropped_hits);
            read32(case_name & " underflow", base_addr_v + HIST_CSR_UNDERFLOW_OFF_CONST, underflow_hits);
            read32(case_name & " overflow",  base_addr_v + HIST_CSR_OVERFLOW_OFF_CONST,  overflow_hits);
        end procedure read_hist_status;

        procedure configure_emulator_lane (
            constant lane_index : in natural
        ) is
            constant LANE_BASE_CONST : natural := EMU0_BASE_ADDR_CONST + (lane_index * EMU_ADDR_STRIDE_CONST);
            variable tx_word_v       : std_logic_vector(31 downto 0);
            variable rate_word_v     : std_logic_vector(31 downto 0);
            variable control_word_v  : std_logic_vector(31 downto 0);
            variable lane_active_v   : boolean;
        begin
            tx_word_v := EMU_TX_GEN_IDLE_CONST;
            tx_word_v(7 downto 4) := std_logic_vector(to_unsigned(lane_index, 4));
            rate_word_v := std_logic_vector(to_unsigned(G_EMU_NOISE_RATE, 16))
                & std_logic_vector(to_unsigned(G_EMU_HIT_RATE, 16));
            lane_active_v := ((G_EMU_ACTIVE_MASK / (2 ** lane_index)) mod 2) = 1;
            if lane_active_v then
                control_word_v := EMU_CONTROL_CONST;
            else
                control_word_v := ZERO_WORD_CONST;
            end if;

            if G_EMU_CFG_LOCAL then
                if not lane_active_v then
                    local_emu_csr_write("EMU lane" & integer'image(lane_index) & " control", lane_index, 0, control_word_v);
                end if;
                if rate_word_v /= EMU_DEFAULT_RATE_CONST then
                    local_emu_csr_write("EMU lane" & integer'image(lane_index) & " rate", lane_index, 1, rate_word_v);
                end if;
                local_emu_csr_write("EMU lane" & integer'image(lane_index) & " seed", lane_index, 3, std_logic_vector(to_unsigned(16#1BADF00D#, 32)) xor std_logic_vector(to_unsigned(lane_index, 32)));
                local_emu_csr_write("EMU lane" & integer'image(lane_index) & " tx", lane_index, 4, tx_word_v);
            else
                if not lane_active_v then
                    write32_quiet("EMU lane" & integer'image(lane_index) & " control", LANE_BASE_CONST + 0, control_word_v);
                end if;
                if rate_word_v /= EMU_DEFAULT_RATE_CONST then
                    write32_quiet("EMU lane" & integer'image(lane_index) & " rate", LANE_BASE_CONST + 1, rate_word_v);
                end if;
                write32_quiet("EMU lane" & integer'image(lane_index) & " seed", LANE_BASE_CONST + 3, std_logic_vector(to_unsigned(16#1BADF00D#, 32)) xor std_logic_vector(to_unsigned(lane_index, 32)));
                write32_quiet("EMU lane" & integer'image(lane_index) & " tx", LANE_BASE_CONST + 4, tx_word_v);
            end if;
        end procedure configure_emulator_lane;

        procedure configure_all_emulators is
        begin
            for lane in 0 to 7 loop
                configure_emulator_lane(lane);
            end loop;
        end procedure configure_all_emulators;

        procedure sample_runtime_status (
            constant case_name : in string;
            constant check_sc  : in boolean
        ) is
            variable scratch_v : std_logic_vector(31 downto 0);
        begin
            if check_sc then
                write32_quiet(case_name & " scratch write", SCRATCH_ADDR_CONST, SCRATCH_HEARTBEAT_CONST);
                read32(case_name & " scratch readback", SCRATCH_ADDR_CONST, scratch_v);
                assert scratch_v = SCRATCH_HEARTBEAT_CONST
                    report case_name & ": scratch heartbeat readback mismatch, got 0x" & to_hstring(scratch_v)
                    severity failure;
                write32_quiet(case_name & " scratch clear", SCRATCH_ADDR_CONST, ZERO_WORD_CONST);
                read32(case_name & " scratch zero", SCRATCH_ADDR_CONST, scratch_v);
                assert scratch_v = ZERO_WORD_CONST
                    report case_name & ": scratch clear mismatch, got 0x" & to_hstring(scratch_v)
                    severity failure;
            end if;

            report case_name
                & ": emu0_tx_valid=" & std_logic'image(emu0_tx_valid)
                & ", runctrl_mask=0x" & to_hstring(runctrl_seen_mask)
                & ", emu_rc_mask=0x" & to_hstring(emulator_rc_seen_mask)
                & ", hitstack_rc_mask=0x" & to_hstring(hitstack_input_rc_seen_mask)
                & ", frame_dp_rc_mask=0x" & to_hstring(frame_dp_rc_seen_mask)
                & ", frame_xcvr_rc_mask=0x" & to_hstring(frame_xcvr_rc_seen_mask)
                & ", ext_emu_words=" & integer'image(ext_emu_word_count)
                & ", dp_hit0_words=" & integer'image(dp_hit0_word_count)
                & ", mts_type1_words=" & integer'image(mts_type1_word_count)
                & ", hit_stack_ingress_words=" & integer'image(hit_stack_ingress_word_count)
                & ", hs0_type2_words=" & integer'image(hit_stack0_type2_word_count)
                & ", hs1_type2_words=" & integer'image(hit_stack1_type2_word_count)
                & ", hs0_type2_valid_cycles=" & integer'image(hit_stack0_type2_valid_cycles)
                & ", hs1_type2_valid_cycles=" & integer'image(hit_stack1_type2_valid_cycles)
                & ", hs0_type3_words=" & integer'image(hit_stack0_type3_word_count)
                & ", hs1_type3_words=" & integer'image(hit_stack1_type3_word_count)
                & ", hs0_pop_wrreq=" & integer'image(hs0_popcmd_wrreq_count)
                & ", hs0_pop_rdack=" & integer'image(hs0_popcmd_rdack_count)
                & ", hs0_pop_start=" & integer'image(hs0_pop_pipeline_start_count)
                & ", hs1_pop_wrreq=" & integer'image(hs1_popcmd_wrreq_count)
                & ", hs1_pop_rdack=" & integer'image(hs1_popcmd_rdack_count)
                & ", hs1_pop_start=" & integer'image(hs1_pop_pipeline_start_count)
                & ", hs0_loss8fill=" & integer'image(hs0_frame_loss8fill_count)
                & ", hs0_delay8loss=" & integer'image(hs0_frame_delay8loss_count)
                & ", hs1_loss8fill=" & integer'image(hs1_frame_loss8fill_count)
                & ", hs1_delay8loss=" & integer'image(hs1_frame_delay8loss_count)
                & ", upper_frames=" & integer'image(upper_frames_accepted)
                & ", lower_frames=" & integer'image(lower_frames_accepted)
                & ", swb_link0_frames=" & integer'image(swb_link0_frames)
                & ", swb_link1_frames=" & integer'image(swb_link1_frames)
                severity note;
        end procedure sample_runtime_status;

        variable soak_deadline_v  : time;
        variable last_status_v    : time;
        variable last_sc_health_v : time;
        variable do_sc_health_v   : boolean;
        variable hist0_ctrl_v      : std_logic_vector(31 downto 0);
        variable hist0_bank_v      : std_logic_vector(31 downto 0);
        variable hist0_total_v     : std_logic_vector(31 downto 0);
        variable hist0_dropped_v   : std_logic_vector(31 downto 0);
        variable hist0_underflow_v : std_logic_vector(31 downto 0);
        variable hist0_overflow_v  : std_logic_vector(31 downto 0);
        variable hist1_ctrl_v      : std_logic_vector(31 downto 0);
        variable hist1_bank_v      : std_logic_vector(31 downto 0);
        variable hist1_total_v     : std_logic_vector(31 downto 0);
        variable hist1_dropped_v   : std_logic_vector(31 downto 0);
        variable hist1_underflow_v : std_logic_vector(31 downto 0);
        variable hist1_overflow_v  : std_logic_vector(31 downto 0);
    begin
        pulse_reset;
        local_hist_idle;
        local_emu_idle;

        report "SOAK: timing clk156=" & time'image(G_CLK156_PERIOD)
            & ", clk125=" & time'image(G_CLK125_PERIOD)
            & ", clk50=" & time'image(G_CLK50_PERIOD)
            & ", reset_assert=" & time'image(G_RESET_ASSERT_TIME)
            & ", post_reset_settle=" & time'image(G_POST_RESET_SETTLE)
            & ", active=" & time'image(G_SOAK_ACTIVE_TIME)
            & ", status=" & time'image(G_SOAK_STATUS_INTERVAL)
            & ", sc_health=" & time'image(G_SOAK_SC_HEALTH_INTERVAL)
            & ", start_settle=" & time'image(G_SOAK_START_SETTLE)
            & ", drain=" & time'image(G_SOAK_DRAIN_TIME)
            severity note;
        if G_EMU_CFG_FAST_FORCE then
            report "SOAK: emulator configuration path=sidecar fast-force" severity note;
        elsif G_EMU_CFG_LOCAL then
            report "SOAK: emulator configuration path=local datapath csr seam" severity note;
        else
            report "SOAK: emulator configuration path=slow-control transport" severity note;
        end if;
        report "SOAK: emulator profile mask=0x" & to_hstring(std_logic_vector(to_unsigned(G_EMU_ACTIVE_MASK, 8)))
            & ", hit_rate=0x" & to_hstring(std_logic_vector(to_unsigned(G_EMU_HIT_RATE, 16)))
            & ", noise_rate=0x" & to_hstring(std_logic_vector(to_unsigned(G_EMU_NOISE_RATE, 16)))
            & ", timing=0x" & to_hstring(std_logic_vector(to_unsigned(G_EMU_TIMING_WORD, 32)))
            severity note;
        if G_EMU_CFG_FAST_FORCE then
            report "SOAK: emulator configuration delegated to sidecar fast-force" severity note;
        else
            configure_all_emulators;
        end if;
        report "SOAK: emulator configuration done" severity note;
        if G_ENABLE_SC_HEALTH then
            report "SOAK: checking scratch over SC" severity note;
            read32_expect("SOAK init scratch", SCRATCH_ADDR_CONST, ZERO_WORD_CONST);
        else
            report "SOAK: SC scratch transport precheck disabled for this soak run" severity note;
        end if;

        report "SOAK: opening external RC injection window" severity note;
        external_rc_active <= '1';
        wait for G_SOAK_START_SETTLE;

        soak_deadline_v  := now + G_SOAK_ACTIVE_TIME;
        last_status_v    := now;
        last_sc_health_v := now;

        while now < soak_deadline_v loop
            if G_SOAK_STATUS_INTERVAL > 0 ns and now - last_status_v >= G_SOAK_STATUS_INTERVAL then
                do_sc_health_v := G_SOAK_SC_HEALTH_INTERVAL > 0 ns and
                    now - last_sc_health_v >= G_SOAK_SC_HEALTH_INTERVAL;
                sample_runtime_status("SOAK active @" & time'image(now), do_sc_health_v);
                last_status_v := now;
                if do_sc_health_v then
                    last_sc_health_v := now;
                end if;
            end if;
            wait_cycles(64);
        end loop;

        external_rc_active <= '0';
        report "SOAK: external RC injection window closed" severity note;
        wait for G_SOAK_DRAIN_TIME;

        sample_runtime_status("SOAK final", G_ENABLE_SC_HEALTH);
        assert ext_emu_word_count > 0
            report "SOAK: emulator traffic never became active"
            severity failure;
        if dp_hit0_word_count = 0 or mts_type1_word_count = 0 or hit_stack_ingress_word_count = 0 then
            report "SOAK: early datapath seam counters stayed zero in the mixed-language image; "
                & "final signoff uses hit-stack type2/type3 and upload-frame observability"
                severity note;
        end if;
        assert upper_frames_accepted > 0
            report "SOAK: no upper datapath frames accepted"
            severity failure;
        assert lower_frames_accepted > 0
            report "SOAK: no lower datapath frames accepted"
            severity failure;
        assert swb_link0_frames >= upper_frames_accepted
            report "SOAK: upside SWB frame count underran datapath frames, swb_link0_frames="
                & integer'image(swb_link0_frames)
                & ", upper_frames=" & integer'image(upper_frames_accepted)
            severity failure;
        assert swb_link1_frames = lower_frames_accepted
            report "SOAK: lower upload frame mismatch, swb_link1_frames=" & integer'image(swb_link1_frames)
                & ", lower_frames=" & integer'image(lower_frames_accepted)
            severity failure;
        assert runctrl_seen_mask = RC_ALL_SEEN_CONST
            report "SOAK: RC datapath fanout incomplete, mask=0x" & to_hstring(runctrl_seen_mask)
            severity failure;
        assert emulator_rc_seen_mask = EMU_RC_ALL_SEEN_CONST
            report "SOAK: RC emulator fanout incomplete, mask=0x" & to_hstring(emulator_rc_seen_mask)
            severity failure;
        assert hitstack_input_rc_seen_mask = "11"
            report "SOAK: RC hit-stack ingress fanout incomplete, mask=0x" & to_hstring(hitstack_input_rc_seen_mask)
            severity failure;
        assert frame_dp_rc_seen_mask = "11"
            report "SOAK: RC frame datapath fanout incomplete, mask=0x" & to_hstring(frame_dp_rc_seen_mask)
            severity failure;
        assert frame_xcvr_rc_seen_mask = "11"
            report "SOAK: RC frame xcvr fanout incomplete, mask=0x" & to_hstring(frame_xcvr_rc_seen_mask)
            severity failure;
        assert hit_stack0_type2_word_count > 0 and hit_stack1_type2_word_count > 0
            report "SOAK: hit-stack type2 traffic did not emerge on both halves"
            severity failure;
        assert hit_stack0_type3_word_count > 0 and hit_stack1_type3_word_count > 0
            report "SOAK: hit-stack type3 traffic did not emerge on both halves"
            severity failure;
        assert hit_stack0_type2_word_count = hit_stack0_type2_valid_cycles
            report "SOAK: hit-stack0 type2 valid/ready mismatch, words=" & integer'image(hit_stack0_type2_word_count)
                & ", valid_cycles=" & integer'image(hit_stack0_type2_valid_cycles)
            severity failure;
        assert hit_stack1_type2_word_count = hit_stack1_type2_valid_cycles
            report "SOAK: hit-stack1 type2 valid/ready mismatch, words=" & integer'image(hit_stack1_type2_word_count)
                & ", valid_cycles=" & integer'image(hit_stack1_type2_valid_cycles)
            severity failure;
        assert hs0_popcmd_wrreq_count >= hs0_popcmd_rdack_count
            report "SOAK: hit-stack0 pop rdack exceeded wrreq, wrreq=" & integer'image(hs0_popcmd_wrreq_count)
                & ", rdack=" & integer'image(hs0_popcmd_rdack_count)
            severity failure;
        assert hs0_popcmd_wrreq_count <= hs0_popcmd_rdack_count + 1
            report "SOAK: hit-stack0 pop queue did not drain, wrreq=" & integer'image(hs0_popcmd_wrreq_count)
                & ", rdack=" & integer'image(hs0_popcmd_rdack_count)
            severity failure;
        assert hs1_popcmd_wrreq_count >= hs1_popcmd_rdack_count
            report "SOAK: hit-stack1 pop rdack exceeded wrreq, wrreq=" & integer'image(hs1_popcmd_wrreq_count)
                & ", rdack=" & integer'image(hs1_popcmd_rdack_count)
            severity failure;
        assert hs1_popcmd_wrreq_count <= hs1_popcmd_rdack_count + 1
            report "SOAK: hit-stack1 pop queue did not drain, wrreq=" & integer'image(hs1_popcmd_wrreq_count)
                & ", rdack=" & integer'image(hs1_popcmd_rdack_count)
            severity failure;
        assert hs0_frame_loss8fill_count = 0
            report "SOAK: upper frame assembly reported fill-loss events, count=" & integer'image(hs0_frame_loss8fill_count)
            severity failure;
        assert hs0_frame_delay8loss_count = 0
            report "SOAK: upper frame assembly reported delay-loss events, count=" & integer'image(hs0_frame_delay8loss_count)
            severity failure;
        assert hs1_frame_loss8fill_count = 0
            report "SOAK: lower frame assembly reported fill-loss events, count=" & integer'image(hs1_frame_loss8fill_count)
            severity failure;
        assert hs1_frame_delay8loss_count = 0
            report "SOAK: lower frame assembly reported delay-loss events, count=" & integer'image(hs1_frame_delay8loss_count)
            severity failure;

        report "PASS: tb_feb_system_v3_soak upper_frames="
            & integer'image(upper_frames_accepted)
            & ", lower_frames=" & integer'image(lower_frames_accepted)
            & ", hs0_pop_wrreq=" & integer'image(hs0_popcmd_wrreq_count)
            & ", hs0_pop_rdack=" & integer'image(hs0_popcmd_rdack_count)
            & ", hs1_pop_wrreq=" & integer'image(hs1_popcmd_wrreq_count)
            & ", hs1_pop_rdack=" & integer'image(hs1_popcmd_rdack_count)
            & ", swb_link0_frames=" & integer'image(swb_link0_frames)
            & ", swb_link1_frames=" & integer'image(swb_link1_frames)
            severity note;
        stop;
        wait;
    end process proc_stimulus;
end architecture sim;

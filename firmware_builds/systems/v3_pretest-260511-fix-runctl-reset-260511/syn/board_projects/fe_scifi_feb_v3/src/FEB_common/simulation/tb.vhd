-- testbench for FEB common

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity feb_common_tb is
end entity;

architecture rtl of feb_common_tb is

    signal clk   : std_logic := '1';
    signal reset : std_logic;
    signal state_idle               : std_logic; -- "reset" states from state controller
    signal state_run_prepare        : std_logic;
    signal state_sync               : std_logic;
    signal state_running            : std_logic;
    signal state_terminating        : std_logic;
    signal state_link_test          : std_logic;
    signal state_sync_test          : std_logic;
    signal state_reset              : std_logic;
    signal state_out_of_DAQ         : std_logic;
    signal data_out                 : std_logic_vector(31 downto 0);
    signal data_is_k                : std_logic_vector(3 downto 0);
    signal data_in                  : std_logic_vector(35 downto 0);
    signal data_in_slowcontrol      : std_logic_vector(35 downto 0);
    signal slowcontrol_fifo_empty   : std_logic;
    signal data_fifo_empty          : std_logic;
    signal slowcontrol_read_req     : std_logic;
    signal data_read_req            : std_logic;
    signal terminated               : std_logic;
    signal reset_link               : std_logic_vector(7 downto 0);
    signal runnumber                : std_logic_vector(31 downto 0);
    signal override_granted         : std_logic;

    -- on switch side:
    signal data_out_switch          : std_logic_vector(31 downto 0);
    signal data_ready_switch        : std_logic;
    signal sc_out_switch            : std_logic_vector(31 downto 0);
    signal sc_ready_switch          : std_logic;
    signal fpga_id                  : std_logic_vector(15 downto 0);

    -- test inputs on FEB side
    signal data_test_input          : std_logic_vector(35 downto 0);
    signal sc_test_input            : std_logic_vector(35 downto 0);
    signal wrreq_sc                 : std_logic;
    signal wrreq_data               : std_logic;
    signal override_req             : std_logic;
    signal override_data_in         : std_logic_vector(31 downto 0);
    signal override_data_is_k_in    : std_logic_vector(3  downto 0);


begin
  clk   <= not clk  after 4 ns;
  reset <= '1', '0' after 24 ns;

    merger : entity work.data_merger
    port map (
        clk       => clk,
        reset     => reset,
        fpga_ID_in              => (5=>'1',others => '0'), -- will be set by 15 jumpers in the end, set this to something random for now
        FEB_type_in             => "111010", -- Type of the frontendboard (111010: mupix, 111000: mutrig, DO NOT USE 000111 or 000000 HERE !!!!)
        state_idle              => state_idle, -- "reset" states from state controller
        state_run_prepare       => state_run_prepare,
        state_sync              => state_sync,
        state_running           => state_running,
        state_terminating       => state_terminating,
        state_link_test         => state_link_test,
        state_sync_test         => state_sync_test,
        state_reset             => state_reset,
        state_out_of_DAQ        => state_out_of_DAQ,
        data_out                => data_out, -- to optical transm.
        data_is_k               => data_is_k, -- to optical trasm.
        data_in                 => data_in, -- data input from FIFO (32 bit data, 4 bit ID (0010 Header, 0011 Trail, 0000 Data))
        data_in_slowcontrol     => data_in_slowcontrol, -- data input slowcontrol from SCFIFO (32 bit data, 4 bit ID (0010 Header, 0011 Trail, 0000 SCData))
        slowcontrol_fifo_empty  => slowcontrol_fifo_empty,
        data_fifo_empty         => data_fifo_empty,
        slowcontrol_read_req    => slowcontrol_read_req,
        data_read_req           => data_read_req,
        terminated              => terminated, -- to state controller (when stop run acknowledge was transmitted the state controller can go from terminating into idle, this is the signal to tell him that)
        override_data_in        => override_data_in, -- data input for states link_test and sync_test;
        override_data_is_k_in   => override_data_is_k_in,
        override_req            => override_req,
        override_granted        => override_granted,
        data_priority           => '0',
        leds                    => open -- debug

    );

    ustate_controller : entity work.state_controller
    port map (
        clk => clk,
        reset => reset,
        reset_link_8bData => reset_link,
        state_idle => state_idle,
        state_run_prepare => state_run_prepare,
        state_sync => state_sync,
        state_running => state_running,
        state_terminating => state_terminating,
        state_link_test => state_link_test,
        state_sync_test => state_sync_test,
        state_reset => state_reset,
        state_out_of_DAQ => state_out_of_DAQ,
        fpga_addr => (others => '0'),
        runnumber => runnumber,
        reset_mask => open,
        link_test_payload => open,
        sync_test_payload => open,
        terminated => terminated

    );

    udata_demerge : entity work.data_demerge
    port map (
        clk             => clk,
        reset           => reset,
        aligned         => '1',
        data_in         => data_out,
        datak_in        => data_is_k,
        data_out        => data_out_switch,
        data_ready      => data_ready_switch,
        sc_out          => sc_out_switch,
        sc_out_ready    => sc_ready_switch,
        fpga_id         => fpga_id
    );

    fifo_sc : entity work.mergerfifo
    port map (
        data    => sc_test_input,
        rdclk   => clk,
        rdreq   => slowcontrol_read_req,
        wrclk   => clk,
        wrreq   => wrreq_sc,
        q       => data_in_slowcontrol,
        rdempty => slowcontrol_fifo_empty,
        wrfull  => open
    );

    fifo_data : entity work.mergerfifo
    port map (
        data    => data_test_input,
        rdclk   => clk,
        rdreq   => data_read_req,
        wrclk   => clk,
        wrreq   => wrreq_data,
        q       => data_in,
        rdempty => data_fifo_empty,
        wrfull  => open
    );

end architecture;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity scifi_dp_emu_live_wrapper_v3 is
    port (
        avmm_clk_clk                   : in  std_logic;
        avmm_port_waitrequest          : out std_logic;
        avmm_port_readdata             : out std_logic_vector(31 downto 0);
        avmm_port_readdatavalid        : out std_logic;
        avmm_port_burstcount           : in  std_logic_vector(8 downto 0);
        avmm_port_writedata            : in  std_logic_vector(31 downto 0);
        avmm_port_address              : in  std_logic_vector(13 downto 0);
        avmm_port_write                : in  std_logic;
        avmm_port_read                 : in  std_logic;
        avmm_port_byteenable           : in  std_logic_vector(3 downto 0);
        avmm_port_debugaccess          : in  std_logic;
        avmm_rst_reset                 : in  std_logic;
        counter_sclr_reset             : in  std_logic;
        hit_type3_lower_data           : out std_logic_vector(35 downto 0);
        hit_type3_lower_valid          : out std_logic;
        hit_type3_lower_ready          : in  std_logic;
        hit_type3_lower_startofpacket  : out std_logic;
        hit_type3_lower_endofpacket    : out std_logic;
        hit_type3_upper_data           : out std_logic_vector(35 downto 0);
        hit_type3_upper_valid          : out std_logic;
        hit_type3_upper_ready          : in  std_logic;
        hit_type3_upper_startofpacket  : out std_logic;
        hit_type3_upper_endofpacket    : out std_logic;
        inject_pulse                   : out std_logic;
        inject_aux_pulse               : in  std_logic;
        lvds_outclock_clk              : out std_logic;
        lvds_pll_inclock_clk           : in  std_logic;
        monitor_clock_125_in_clk       : in  std_logic;
        osc_clock_50_in_clk            : in  std_logic;
        monitor_reset_in_reset_reset_n : in  std_logic;
        mutrig_reset_reset             : out std_logic_vector(1 downto 0);
        redriver_losn                  : in  std_logic_vector(8 downto 0);
        rstlink_data                   : out std_logic_vector(8 downto 0);
        rstlink_channel                : out std_logic_vector(3 downto 0);
        rstlink_error                  : out std_logic_vector(2 downto 0);
        runctl_mgmt_host_valid         : in  std_logic;
        runctl_mgmt_host_data          : in  std_logic_vector(8 downto 0);
        serial_data                    : in  std_logic_vector(8 downto 0);
        xcvr_clock_clk                 : in  std_logic;
        xcvr_reset_reset_n             : in  std_logic
    );
end entity scifi_dp_emu_live_wrapper_v3;

architecture sim of scifi_dp_emu_live_wrapper_v3 is
begin

    dut : entity work.scifi_datapath_system_v3
        port map (
            avmm_clk_clk                   => avmm_clk_clk,
            avmm_port_waitrequest          => avmm_port_waitrequest,
            avmm_port_readdata             => avmm_port_readdata,
            avmm_port_readdatavalid        => avmm_port_readdatavalid,
            avmm_port_burstcount           => avmm_port_burstcount,
            avmm_port_writedata            => avmm_port_writedata,
            avmm_port_address              => avmm_port_address,
            avmm_port_write                => avmm_port_write,
            avmm_port_read                 => avmm_port_read,
            avmm_port_byteenable           => avmm_port_byteenable,
            avmm_port_debugaccess          => avmm_port_debugaccess,
            avmm_rst_reset                 => avmm_rst_reset,
            counter_sclr_reset             => counter_sclr_reset,
            hit_type3_lower_data           => hit_type3_lower_data,
            hit_type3_lower_valid          => hit_type3_lower_valid,
            hit_type3_lower_ready          => hit_type3_lower_ready,
            hit_type3_lower_startofpacket  => hit_type3_lower_startofpacket,
            hit_type3_lower_endofpacket    => hit_type3_lower_endofpacket,
            hit_type3_upper_data           => hit_type3_upper_data,
            hit_type3_upper_valid          => hit_type3_upper_valid,
            hit_type3_upper_ready          => hit_type3_upper_ready,
            hit_type3_upper_startofpacket  => hit_type3_upper_startofpacket,
            hit_type3_upper_endofpacket    => hit_type3_upper_endofpacket,
            inject_pulse                   => inject_pulse,
            inject_aux_pulse               => inject_aux_pulse,
            lvds_outclock_clk              => lvds_outclock_clk,
            lvds_pll_inclock_clk           => lvds_pll_inclock_clk,
            monitor_clock_125_in_clk       => monitor_clock_125_in_clk,
            osc_clock_50_in_clk            => osc_clock_50_in_clk,
            monitor_reset_in_reset_reset_n => monitor_reset_in_reset_reset_n,
            mutrig_reset_reset             => mutrig_reset_reset,
            redriver_losn                  => redriver_losn,
            rstlink_data                   => rstlink_data,
            rstlink_channel                => rstlink_channel,
            rstlink_error                  => rstlink_error,
            runctl_mgmt_host_valid         => runctl_mgmt_host_valid,
            runctl_mgmt_host_data          => runctl_mgmt_host_data,
            serial_data                    => serial_data,
            xcvr_clock_clk                 => xcvr_clock_clk,
            xcvr_reset_reset_n             => xcvr_reset_reset_n
        );

end architecture sim;

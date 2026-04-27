library ieee;
library feb_system_v3_pipe;

use ieee.std_logic_1164.all;

entity feb_system is
    port (
        i_xcvr_clk                 : in    std_logic;
        i_lvds_pll_refclk          : in    std_logic;
        i_monitor_clk_125          : in    std_logic;
        i_free_running_clk         : in    std_logic;
        i_board_reset_n            : in    std_logic;

        i_serial_data              : in    std_logic_vector(8 downto 0);
        i_redriver_losn            : in    std_logic_vector(8 downto 0);

        o_mutrig_spi_mosi          : out   std_logic;
        o_mutrig_spi_sclk          : out   std_logic;
        o_mutrig_spi_ssn           : out   std_logic_vector(7 downto 0);
        i_mutrig_spi_miso          : in    std_logic;
        o_mutrig_reset             : out   std_logic_vector(1 downto 0);

        o_inject_pulse             : out   std_logic;

        o_max10_link_csn           : out   std_logic;
        o_max10_link_clk           : out   std_logic;
        i_max10_link_mosi_in       : in    std_logic;
        o_max10_link_mosi_out      : out   std_logic;
        o_max10_link_mosi_oe       : out   std_logic;
        i_max10_link_d1_in         : in    std_logic;
        o_max10_link_d1_out        : out   std_logic;
        o_max10_link_d1_oe         : out   std_logic;
        i_max10_link_d2_in         : in    std_logic;
        o_max10_link_d2_out        : out   std_logic;
        o_max10_link_d2_oe         : out   std_logic;
        i_max10_link_d3_in         : in    std_logic;
        o_max10_link_d3_out        : out   std_logic;
        o_max10_link_d3_oe         : out   std_logic;

        i_sense_dq_in              : in    std_logic_vector(5 downto 0);
        o_sense_dq_out             : out   std_logic_vector(5 downto 0);
        o_sense_dq_oe              : out   std_logic_vector(5 downto 0);

        o_si_gpio_out              : out   std_logic_vector(15 downto 0);
        i_si_status_in             : in    std_logic_vector(7 downto 0);

        io_firefly_ucc8_scl        : inout std_logic;
        i_firefly_ucc8_present_n   : in    std_logic_vector(1 downto 0);
        io_firefly_ucc8_sda        : inout std_logic;
        o_firefly_ucc8_reset_n     : out   std_logic_vector(1 downto 0);
        o_firefly_ucc8_select_n    : out   std_logic_vector(1 downto 0);
        i_firefly_ucc8_int_n       : in    std_logic_vector(1 downto 0);

        o_firefly1_tx_data         : out   std_logic_vector(3 downto 0);
        o_firefly2_tx_data         : out   std_logic_vector(3 downto 0);
        i_firefly1_rx_data         : in    std_logic;
        i_firefly2_rx_data         : in    std_logic_vector(2 downto 0)
    );
end entity feb_system;

architecture rtl of feb_system is
    signal upload_data0_sc_rc_data          : std_logic_vector(35 downto 0);
    signal upload_data0_sc_rc_valid         : std_logic;
    signal upload_data1_data                : std_logic_vector(35 downto 0);
    signal upload_data1_valid               : std_logic;

    signal download_sc_data_156             : std_logic_vector(31 downto 0);
    signal download_sc_datak_156            : std_logic_vector(3 downto 0);
    signal download_sc_data_125             : std_logic_vector(31 downto 0);
    signal download_sc_datak_125            : std_logic_vector(3 downto 0);
    signal download_sc_ready                : std_logic;

    signal legacy_firefly_mon_burstcount    : std_logic_vector(0 downto 0);
    signal legacy_firefly_mon_writedata     : std_logic_vector(31 downto 0);
    signal legacy_firefly_mon_address       : std_logic_vector(7 downto 0);
    signal legacy_firefly_mon_write         : std_logic;
    signal legacy_firefly_mon_read          : std_logic;
    signal legacy_firefly_mon_byteenable    : std_logic_vector(3 downto 0);
    signal legacy_firefly_mon_debugaccess   : std_logic;
    signal legacy_firefly_mon_waitrequest   : std_logic;
    signal legacy_firefly_mon_readdata      : std_logic_vector(31 downto 0);
    signal legacy_firefly_mon_readdatavalid : std_logic;
    signal legacy_firefly_mon_response      : std_logic_vector(1 downto 0);
    signal firefly_mon_burstcount           : std_logic_vector(0 downto 0);
    signal firefly_mon_writedata            : std_logic_vector(31 downto 0);
    signal firefly_mon_address              : std_logic_vector(7 downto 0);
    signal firefly_mon_write                : std_logic;
    signal firefly_mon_read                 : std_logic;
    signal firefly_mon_byteenable           : std_logic_vector(3 downto 0);
    signal firefly_mon_debugaccess          : std_logic;
    signal firefly_mon_waitrequest          : std_logic;
    signal firefly_mon_readdata             : std_logic_vector(31 downto 0);
    signal firefly_mon_readdatavalid        : std_logic;
    signal firefly_mon_response             : std_logic_vector(1 downto 0);
    signal control_path_clk125              : std_logic;
begin
    u_qsys : entity feb_system_v3_pipe.feb_system_v3_pipe
        port map (
            cclk156_clk                           => i_xcvr_clk,
            control_path_clk125_clk               => control_path_clk125,
            download_sc_data                      => download_sc_data_125,
            download_sc_datak                     => download_sc_datak_125,
            download_sc_ready                     => download_sc_ready,
            inject_pulse                          => o_inject_pulse,
            inject_masked_pulse                   => open,
            lvds_pll_inclock_clk                  => i_lvds_pll_refclk,
            max10_link_csn                        => o_max10_link_csn,
            max10_link_clk                        => o_max10_link_clk,
            max10_link_mosi_in                    => i_max10_link_mosi_in,
            max10_link_mosi_out                   => o_max10_link_mosi_out,
            max10_link_mosi_oe                    => o_max10_link_mosi_oe,
            max10_link_miso_in                    => '0',
            max10_link_miso_out                   => open,
            max10_link_miso_oe                    => open,
            max10_link_d1_in                      => i_max10_link_d1_in,
            max10_link_d1_out                     => o_max10_link_d1_out,
            max10_link_d1_oe                      => o_max10_link_d1_oe,
            max10_link_d2_in                      => i_max10_link_d2_in,
            max10_link_d2_out                     => o_max10_link_d2_out,
            max10_link_d2_oe                      => o_max10_link_d2_oe,
            max10_link_d3_in                      => i_max10_link_d3_in,
            max10_link_d3_out                     => o_max10_link_d3_out,
            max10_link_d3_oe                      => o_max10_link_d3_oe,
            max10_link_clock_clk                  => i_free_running_clk,
            mclk125_clk                           => i_monitor_clk_125,
            mutrig_cfg_ctrl_0_spi_export2top_miso => i_mutrig_spi_miso,
            mutrig_cfg_ctrl_0_spi_export2top_mosi => o_mutrig_spi_mosi,
            mutrig_cfg_ctrl_0_spi_export2top_sclk => o_mutrig_spi_sclk,
            mutrig_cfg_ctrl_0_spi_export2top_ssn  => o_mutrig_spi_ssn,
            mutrig_reset_reset                    => o_mutrig_reset,
            legacy_firefly_mon_waitrequest        => legacy_firefly_mon_waitrequest,
            legacy_firefly_mon_readdata           => legacy_firefly_mon_readdata,
            legacy_firefly_mon_readdatavalid      => legacy_firefly_mon_readdatavalid,
            legacy_firefly_mon_response           => legacy_firefly_mon_response,
            legacy_firefly_mon_burstcount         => legacy_firefly_mon_burstcount,
            legacy_firefly_mon_writedata          => legacy_firefly_mon_writedata,
            legacy_firefly_mon_address            => legacy_firefly_mon_address,
            legacy_firefly_mon_write              => legacy_firefly_mon_write,
            legacy_firefly_mon_read               => legacy_firefly_mon_read,
            legacy_firefly_mon_byteenable         => legacy_firefly_mon_byteenable,
            legacy_firefly_mon_debugaccess        => legacy_firefly_mon_debugaccess,
            osc_clock_50_in_clk                   => i_free_running_clk,
            pulse_out_conduit_pulse               => open,
            redriver_losn                         => i_redriver_losn,
            reset_3_reset_n                       => i_board_reset_n,
            sense_dq_in                           => i_sense_dq_in,
            sense_dq_out                          => o_sense_dq_out,
            sense_dq_oe                           => o_sense_dq_oe,
            si_gpio_out_export                    => o_si_gpio_out,
            si_status_in_export                   => i_si_status_in,
            serial_data                           => i_serial_data,
            to_firefly_ucc8_scl                   => io_firefly_ucc8_scl,
            to_firefly_ucc8_present_n             => i_firefly_ucc8_present_n,
            to_firefly_ucc8_sda                   => io_firefly_ucc8_sda,
            to_firefly_ucc8_reset_n               => o_firefly_ucc8_reset_n,
            to_firefly_ucc8_select_n              => o_firefly_ucc8_select_n,
            to_firefly_ucc8_int_n                 => i_firefly_ucc8_int_n,
            upload_data0_sc_rc_data               => upload_data0_sc_rc_data,
            upload_data0_sc_rc_valid              => upload_data0_sc_rc_valid,
            upload_data0_sc_rc_ready              => '1',
            upload_data0_sc_rc_startofpacket      => open,
            upload_data0_sc_rc_endofpacket        => open,
            upload_data0_sc_rc_channel            => open,
            upload_data1_data                     => upload_data1_data,
            upload_data1_valid                    => upload_data1_valid,
            upload_data1_ready                    => '1',
            upload_data1_startofpacket            => open,
            upload_data1_endofpacket              => open
        );

    u_sc_downlink_cdc : entity work.sc_downlink_cdc_bridge
        port map (
            i_in_clk     => i_xcvr_clk,
            i_in_reset_n => i_board_reset_n,
            i_in_data    => download_sc_data_156,
            i_in_datak   => download_sc_datak_156,
            i_out_clk    => control_path_clk125,
            i_out_reset_n => i_board_reset_n,
            i_out_ready  => download_sc_ready,
            o_out_data   => download_sc_data_125,
            o_out_datak  => download_sc_datak_125
        );

    u_legacy_firefly_mon_cdc : entity work.legacy_firefly_mon_cdc_bridge
        port map (
            i_s_clk           => control_path_clk125,
            i_s_reset_n       => i_board_reset_n,
            o_s_waitrequest   => legacy_firefly_mon_waitrequest,
            o_s_readdata      => legacy_firefly_mon_readdata,
            o_s_readdatavalid => legacy_firefly_mon_readdatavalid,
            o_s_response      => legacy_firefly_mon_response,
            i_s_burstcount    => legacy_firefly_mon_burstcount,
            i_s_writedata     => legacy_firefly_mon_writedata,
            i_s_address       => legacy_firefly_mon_address,
            i_s_write         => legacy_firefly_mon_write,
            i_s_read          => legacy_firefly_mon_read,
            i_s_byteenable    => legacy_firefly_mon_byteenable,
            i_s_debugaccess   => legacy_firefly_mon_debugaccess,
            i_m_clk           => i_xcvr_clk,
            i_m_reset_n       => i_board_reset_n,
            i_m_waitrequest   => firefly_mon_waitrequest,
            i_m_readdata      => firefly_mon_readdata,
            i_m_readdatavalid => firefly_mon_readdatavalid,
            i_m_response      => firefly_mon_response,
            o_m_burstcount    => firefly_mon_burstcount,
            o_m_writedata     => firefly_mon_writedata,
            o_m_address       => firefly_mon_address,
            o_m_write         => firefly_mon_write,
            o_m_read          => firefly_mon_read,
            o_m_byteenable    => firefly_mon_byteenable,
            o_m_debugaccess   => firefly_mon_debugaccess
        );

    u_firefly_xcvr : entity work.firefly_xcvr_subsystem
        port map (
            i_clk_156                  => i_xcvr_clk,
            i_reset_156_n              => i_board_reset_n,
            i_clk_50                   => i_free_running_clk,
            i_reset_50_n               => i_board_reset_n,
            i_upload_data0_sc_rc_data  => upload_data0_sc_rc_data,
            i_upload_data0_sc_rc_valid => upload_data0_sc_rc_valid,
            i_upload_data1_data        => upload_data1_data,
            i_upload_data1_valid       => upload_data1_valid,
            o_download_sc_data         => download_sc_data_156,
            o_download_sc_datak        => download_sc_datak_156,
            i_mon_address              => firefly_mon_address,
            i_mon_write                => firefly_mon_write,
            i_mon_read                 => firefly_mon_read,
            i_mon_writedata            => firefly_mon_writedata,
            i_mon_byteenable           => firefly_mon_byteenable,
            i_mon_debugaccess          => firefly_mon_debugaccess,
            o_mon_waitrequest          => firefly_mon_waitrequest,
            o_mon_readdata             => firefly_mon_readdata,
            o_mon_readdatavalid        => firefly_mon_readdatavalid,
            o_mon_response             => firefly_mon_response,
            o_firefly1_tx_data         => o_firefly1_tx_data,
            o_firefly2_tx_data         => o_firefly2_tx_data,
            i_firefly1_rx_data         => i_firefly1_rx_data,
            i_firefly2_rx_data         => i_firefly2_rx_data
        );
end architecture rtl;

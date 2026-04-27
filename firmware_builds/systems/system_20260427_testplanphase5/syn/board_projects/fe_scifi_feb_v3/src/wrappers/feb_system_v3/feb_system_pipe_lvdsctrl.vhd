library ieee;
library feb_system_v3;
library feb_system_v3_pipe_lvdsctrl;

use ieee.std_logic_1164.all;

entity feb_system is
    port (
        cclk156_clk                           : in    std_logic                     := '0';
        download_sc_data                      : in    std_logic_vector(31 downto 0) := (others => '0');
        download_sc_datak                     : in    std_logic_vector(3 downto 0)  := (others => '0');
        download_sc_ready                     : out   std_logic;
        inject_pulse                          : out   std_logic;
        lvds_pll_inclock_clk                  : in    std_logic                     := '0';
        max10_link_csn                        : out   std_logic;
        max10_link_clk                        : out   std_logic;
        max10_link_mosi_in                    : in    std_logic                     := '0';
        max10_link_mosi_out                   : out   std_logic;
        max10_link_mosi_oe                    : out   std_logic;
        max10_link_miso_in                    : in    std_logic                     := '0';
        max10_link_miso_out                   : out   std_logic;
        max10_link_miso_oe                    : out   std_logic;
        max10_link_d1_in                      : in    std_logic                     := '0';
        max10_link_d1_out                     : out   std_logic;
        max10_link_d1_oe                      : out   std_logic;
        max10_link_d2_in                      : in    std_logic                     := '0';
        max10_link_d2_out                     : out   std_logic;
        max10_link_d2_oe                      : out   std_logic;
        max10_link_d3_in                      : in    std_logic                     := '0';
        max10_link_d3_out                     : out   std_logic;
        max10_link_d3_oe                      : out   std_logic;
        max10_link_clock_clk                  : in    std_logic                     := '0';
        mclk125_clk                           : in    std_logic                     := '0';
        mutrig_cfg_ctrl_0_spi_export2top_miso : in    std_logic                     := '0';
        mutrig_cfg_ctrl_0_spi_export2top_mosi : out   std_logic;
        mutrig_cfg_ctrl_0_spi_export2top_sclk : out   std_logic;
        mutrig_cfg_ctrl_0_spi_export2top_ssn  : out   std_logic_vector(7 downto 0);
        mutrig_reset_reset                    : out   std_logic_vector(1 downto 0);
        legacy_firefly_mon_waitrequest        : in    std_logic                     := '0';
        legacy_firefly_mon_readdata           : in    std_logic_vector(31 downto 0) := (others => '0');
        legacy_firefly_mon_readdatavalid      : in    std_logic                     := '0';
        legacy_firefly_mon_response           : in    std_logic_vector(1 downto 0)  := (others => '0');
        legacy_firefly_mon_burstcount         : out   std_logic_vector(0 downto 0);
        legacy_firefly_mon_writedata          : out   std_logic_vector(31 downto 0);
        legacy_firefly_mon_address            : out   std_logic_vector(7 downto 0);
        legacy_firefly_mon_write              : out   std_logic;
        legacy_firefly_mon_read               : out   std_logic;
        legacy_firefly_mon_byteenable         : out   std_logic_vector(3 downto 0);
        legacy_firefly_mon_debugaccess        : out   std_logic;
        osc_clock_50_in_clk                   : in    std_logic                     := '0';
        redriver_losn                         : in    std_logic_vector(8 downto 0)  := (others => '0');
        reset_3_reset_n                       : in    std_logic                     := '0';
        sense_dq_in                           : in    std_logic_vector(5 downto 0)  := (others => '0');
        sense_dq_out                          : out   std_logic_vector(5 downto 0);
        sense_dq_oe                           : out   std_logic_vector(5 downto 0);
        si_gpio_out_export                    : out   std_logic_vector(15 downto 0);
        si_status_in_export                   : in    std_logic_vector(7 downto 0)  := (others => '0');
        serial_data                           : in    std_logic_vector(8 downto 0)  := (others => '0');
        to_firefly_ucc8_scl                   : inout std_logic                     := '0';
        to_firefly_ucc8_present_n             : in    std_logic_vector(1 downto 0)  := (others => '0');
        to_firefly_ucc8_sda                   : inout std_logic                     := '0';
        to_firefly_ucc8_reset_n               : out   std_logic_vector(1 downto 0);
        to_firefly_ucc8_select_n              : out   std_logic_vector(1 downto 0);
        to_firefly_ucc8_int_n                 : in    std_logic_vector(1 downto 0)  := (others => '0');
        upload_data0_sc_rc_data               : out   std_logic_vector(35 downto 0);
        upload_data0_sc_rc_valid              : out   std_logic;
        upload_data0_sc_rc_ready              : in    std_logic                     := '0';
        upload_data0_sc_rc_startofpacket      : out   std_logic;
        upload_data0_sc_rc_endofpacket        : out   std_logic;
        upload_data0_sc_rc_channel            : out   std_logic_vector(1 downto 0);
        upload_data1_data                     : out   std_logic_vector(35 downto 0);
        upload_data1_valid                    : out   std_logic;
        upload_data1_ready                    : in    std_logic                     := '0';
        upload_data1_startofpacket            : out   std_logic;
        upload_data1_endofpacket              : out   std_logic
    );
end entity feb_system;

architecture rtl of feb_system is
    component feb_system_v3 is
        port (
            cclk156_clk                           : in    std_logic                     := '0';
            download_sc_data                      : in    std_logic_vector(31 downto 0) := (others => '0');
            download_sc_datak                     : in    std_logic_vector(3 downto 0)  := (others => '0');
            download_sc_ready                     : out   std_logic;
            inject_pulse                          : out   std_logic;
            lvds_pll_inclock_clk                  : in    std_logic                     := '0';
            max10_link_csn                        : out   std_logic;
            max10_link_clk                        : out   std_logic;
            max10_link_mosi_in                    : in    std_logic                     := '0';
            max10_link_mosi_out                   : out   std_logic;
            max10_link_mosi_oe                    : out   std_logic;
            max10_link_miso_in                    : in    std_logic                     := '0';
            max10_link_miso_out                   : out   std_logic;
            max10_link_miso_oe                    : out   std_logic;
            max10_link_d1_in                      : in    std_logic                     := '0';
            max10_link_d1_out                     : out   std_logic;
            max10_link_d1_oe                      : out   std_logic;
            max10_link_d2_in                      : in    std_logic                     := '0';
            max10_link_d2_out                     : out   std_logic;
            max10_link_d2_oe                      : out   std_logic;
            max10_link_d3_in                      : in    std_logic                     := '0';
            max10_link_d3_out                     : out   std_logic;
            max10_link_d3_oe                      : out   std_logic;
            max10_link_clock_clk                  : in    std_logic                     := '0';
            mclk125_clk                           : in    std_logic                     := '0';
            mutrig_cfg_ctrl_0_spi_export2top_miso : in    std_logic                     := '0';
            mutrig_cfg_ctrl_0_spi_export2top_mosi : out   std_logic;
            mutrig_cfg_ctrl_0_spi_export2top_sclk : out   std_logic;
            mutrig_cfg_ctrl_0_spi_export2top_ssn  : out   std_logic_vector(7 downto 0);
            mutrig_reset_reset                    : out   std_logic_vector(1 downto 0);
            legacy_firefly_mon_waitrequest        : in    std_logic                     := '0';
            legacy_firefly_mon_readdata           : in    std_logic_vector(31 downto 0) := (others => '0');
            legacy_firefly_mon_readdatavalid      : in    std_logic                     := '0';
            legacy_firefly_mon_response           : in    std_logic_vector(1 downto 0)  := (others => '0');
            legacy_firefly_mon_burstcount         : out   std_logic_vector(0 downto 0);
            legacy_firefly_mon_writedata          : out   std_logic_vector(31 downto 0);
            legacy_firefly_mon_address            : out   std_logic_vector(7 downto 0);
            legacy_firefly_mon_write              : out   std_logic;
            legacy_firefly_mon_read               : out   std_logic;
            legacy_firefly_mon_byteenable         : out   std_logic_vector(3 downto 0);
            legacy_firefly_mon_debugaccess        : out   std_logic;
            osc_clock_50_in_clk                   : in    std_logic                     := '0';
            redriver_losn                         : in    std_logic_vector(8 downto 0)  := (others => '0');
            reset_3_reset_n                       : in    std_logic                     := '0';
            sense_dq_in                           : in    std_logic_vector(5 downto 0)  := (others => '0');
            sense_dq_out                          : out   std_logic_vector(5 downto 0);
            sense_dq_oe                           : out   std_logic_vector(5 downto 0);
            si_gpio_out_export                    : out   std_logic_vector(15 downto 0);
            si_status_in_export                   : in    std_logic_vector(7 downto 0)  := (others => '0');
            serial_data                           : in    std_logic_vector(8 downto 0)  := (others => '0');
            to_firefly_ucc8_scl                   : inout std_logic                     := '0';
            to_firefly_ucc8_present_n             : in    std_logic_vector(1 downto 0)  := (others => '0');
            to_firefly_ucc8_sda                   : inout std_logic                     := '0';
            to_firefly_ucc8_reset_n               : out   std_logic_vector(1 downto 0);
            to_firefly_ucc8_select_n              : out   std_logic_vector(1 downto 0);
            to_firefly_ucc8_int_n                 : in    std_logic_vector(1 downto 0)  := (others => '0');
            upload_data0_sc_rc_data               : out   std_logic_vector(35 downto 0);
            upload_data0_sc_rc_valid              : out   std_logic;
            upload_data0_sc_rc_ready              : in    std_logic                     := '0';
            upload_data0_sc_rc_startofpacket      : out   std_logic;
            upload_data0_sc_rc_endofpacket        : out   std_logic;
            upload_data0_sc_rc_channel            : out   std_logic_vector(1 downto 0);
            upload_data1_data                     : out   std_logic_vector(35 downto 0);
            upload_data1_valid                    : out   std_logic;
            upload_data1_ready                    : in    std_logic                     := '0';
            upload_data1_startofpacket            : out   std_logic;
            upload_data1_endofpacket              : out   std_logic
        );
    end component feb_system_v3;
begin
    u_feb_system_v3_pipe_lvdsctrl : entity feb_system_v3_pipe_lvdsctrl.feb_system_v3_pipe_lvdsctrl
        port map (
            cclk156_clk                           => cclk156_clk,
            download_sc_data                      => download_sc_data,
            download_sc_datak                     => download_sc_datak,
            download_sc_ready                     => download_sc_ready,
            inject_pulse                          => inject_pulse,
            inject_masked_pulse                   => open,
            lvds_pll_inclock_clk                  => lvds_pll_inclock_clk,
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
            max10_link_clock_clk                  => max10_link_clock_clk,
            mclk125_clk                           => mclk125_clk,
            mutrig_cfg_ctrl_0_spi_export2top_miso => mutrig_cfg_ctrl_0_spi_export2top_miso,
            mutrig_cfg_ctrl_0_spi_export2top_mosi => mutrig_cfg_ctrl_0_spi_export2top_mosi,
            mutrig_cfg_ctrl_0_spi_export2top_sclk => mutrig_cfg_ctrl_0_spi_export2top_sclk,
            mutrig_cfg_ctrl_0_spi_export2top_ssn  => mutrig_cfg_ctrl_0_spi_export2top_ssn,
            mutrig_reset_reset                    => mutrig_reset_reset,
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
            osc_clock_50_in_clk                   => osc_clock_50_in_clk,
            pulse_out_conduit_pulse               => open,
            redriver_losn                         => redriver_losn,
            reset_3_reset_n                       => reset_3_reset_n,
            sense_dq_in                           => sense_dq_in,
            sense_dq_out                          => sense_dq_out,
            sense_dq_oe                           => sense_dq_oe,
            si_gpio_out_export                    => si_gpio_out_export,
            si_status_in_export                   => si_status_in_export,
            serial_data                           => serial_data,
            to_firefly_ucc8_scl                   => to_firefly_ucc8_scl,
            to_firefly_ucc8_present_n             => to_firefly_ucc8_present_n,
            to_firefly_ucc8_sda                   => to_firefly_ucc8_sda,
            to_firefly_ucc8_reset_n               => to_firefly_ucc8_reset_n,
            to_firefly_ucc8_select_n              => to_firefly_ucc8_select_n,
            to_firefly_ucc8_int_n                 => to_firefly_ucc8_int_n,
            upload_data0_sc_rc_data               => upload_data0_sc_rc_data,
            upload_data0_sc_rc_valid              => upload_data0_sc_rc_valid,
            upload_data0_sc_rc_ready              => upload_data0_sc_rc_ready,
            upload_data0_sc_rc_startofpacket      => upload_data0_sc_rc_startofpacket,
            upload_data0_sc_rc_endofpacket        => upload_data0_sc_rc_endofpacket,
            upload_data0_sc_rc_channel            => upload_data0_sc_rc_channel,
            upload_data1_data                     => upload_data1_data,
            upload_data1_valid                    => upload_data1_valid,
            upload_data1_ready                    => upload_data1_ready,
            upload_data1_startofpacket            => upload_data1_startofpacket,
            upload_data1_endofpacket              => upload_data1_endofpacket
        );
end architecture rtl;

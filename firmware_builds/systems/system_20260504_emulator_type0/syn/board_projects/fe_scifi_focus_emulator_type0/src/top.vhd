library ieee;
library focus_emulator_type0_system;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
port (
    fpga_reset                  : in    std_logic;

    LVDS_clk_si1_fpga_A         : in    std_logic;
    LVDS_clk_si1_fpga_B         : in    std_logic;
    transceiver_pll_clock       : in    std_logic_vector(0 downto 0);

    lvds_firefly_clk            : in    std_logic;

    systemclock                 : in    std_logic;
    systemclock_bottom          : in    std_logic;
    clk_125_top                 : in    std_logic;
    clk_125_bottom              : in    std_logic;
    spare_clk_osc               : in    std_logic;

    scifi_din                   : in    std_logic_vector(7 downto 0);
    scifi_syncres               : out   std_logic;
    scifi_syncres2              : out   std_logic;
    scifi_csn                   : out   std_logic_vector(7 downto 0);
    scifi_spi_sclk              : out   std_logic;
    scifi_spi_miso              : in    std_logic;
    scifi_spi_mosi              : out   std_logic;
    scifi_temp_mutrig_old       : inout std_logic_vector(1 downto 0);
    scifi_temp_sipm_old         : inout std_logic_vector(1 downto 0);

    scifi_temp_mutrig           : inout std_logic_vector(1 downto 0);
    scifi_temp_sipm             : inout std_logic_vector(1 downto 0);
    scifi_temp_dab              : inout std_logic_vector(1 downto 0);
    scifi_ds_ctrl               : out   std_logic_vector(11 downto 0);
    scifi_ds_losn               : in    std_logic_vector(13 downto 0);
    scifi_ainj                  : out   std_logic_vector(1 downto 0);

    scifi_spi_sclk2             : out   std_logic;
    scifi_spi_miso2             : in    std_logic;
    scifi_spi_mosi2             : out   std_logic;
    scifi_cec_csn               : out   std_logic_vector(7 downto 0);
    scifi_cec_miso              : in    std_logic;
    scifi_fifo_ext              : out   std_logic;
    scifi_inject                : out   std_logic;
    scifi_cec_miso2             : in    std_logic;
    scifi_fifo_ext2             : out   std_logic;
    scifi_inject2               : out   std_logic;

    Firefly_ModSel_n            : out   std_logic_vector(1 downto 0);
    Firefly_Rst_n               : out   std_logic_vector(1 downto 0);
    Firefly_Scl                 : inout std_logic;
    Firefly_Sda                 : inout std_logic;
    Firefly_Int_n               : in    std_logic_vector(1 downto 0);
    Firefly_ModPrs_n            : in    std_logic_vector(1 downto 0);

    PushButton                  : in    std_logic_vector(1 downto 0);
    FPGA_Test                   : inout std_logic_vector(7 downto 0);

    lcd_csn                     : out   std_logic;
    lcd_d_cn                    : out   std_logic;
    lcd_data                    : out   std_logic_vector(7 downto 0);
    lcd_wen                     : out   std_logic;

    si45_oe_n                   : out   std_logic_vector(1 downto 0);
    si45_intr_n                 : in    std_logic_vector(1 downto 0);
    si45_lol_n                  : in    std_logic_vector(1 downto 0);
    si45_rst_n                  : out   std_logic_vector(1 downto 0);
    si45_spi_cs_n               : out   std_logic_vector(1 downto 0);
    si45_spi_in                 : out   std_logic_vector(1 downto 0);
    si45_spi_out                : in    std_logic_vector(1 downto 0);
    si45_spi_sclk               : out   std_logic_vector(1 downto 0);
    si45_fdec                   : out   std_logic_vector(1 downto 0);
    si45_finc                   : out   std_logic_vector(1 downto 0);

    mscb_fpga_in                : in    std_logic;
    mscb_fpga_out               : out   std_logic;
    mscb_fpga_oe_n              : out   std_logic;

    ref_adr                     : in    std_logic_vector(7 downto 0);

    max10_spi_sclk              : out   std_logic;
    max10_spi_mosi              : inout std_logic;
    max10_spi_miso              : inout std_logic;
    max10_spi_D1                : inout std_logic;
    max10_spi_D2                : inout std_logic;
    max10_spi_D3                : inout std_logic;
    max10_spi_csn               : out   std_logic
);
end entity top;

architecture rtl of top is
    component focus_emulator_type0_system is
        port (
            cclk156_clk                           : in    std_logic;
            download_sc_data                      : in    std_logic_vector(31 downto 0);
            download_sc_datak                     : in    std_logic_vector(3 downto 0);
            download_sc_ready                     : out   std_logic;
            inject_pulse                          : out   std_logic;
            inject_masked_pulse                   : out   std_logic;
            inject_aux_pulse                      : in    std_logic;
            legacy_firefly_mon_waitrequest        : in    std_logic;
            legacy_firefly_mon_readdata           : in    std_logic_vector(31 downto 0);
            legacy_firefly_mon_readdatavalid      : in    std_logic;
            legacy_firefly_mon_response           : in    std_logic_vector(1 downto 0);
            legacy_firefly_mon_burstcount         : out   std_logic_vector(0 downto 0);
            legacy_firefly_mon_writedata          : out   std_logic_vector(31 downto 0);
            legacy_firefly_mon_address            : out   std_logic_vector(7 downto 0);
            legacy_firefly_mon_write              : out   std_logic;
            legacy_firefly_mon_read               : out   std_logic;
            legacy_firefly_mon_byteenable         : out   std_logic_vector(3 downto 0);
            legacy_firefly_mon_debugaccess        : out   std_logic;
            lvds_pll_inclock_clk                  : in    std_logic;
            max10_link_csn                        : out   std_logic;
            max10_link_clk                        : out   std_logic;
            max10_link_mosi_in                    : in    std_logic;
            max10_link_mosi_out                   : out   std_logic;
            max10_link_mosi_oe                    : out   std_logic;
            max10_link_miso_in                    : in    std_logic;
            max10_link_miso_out                   : out   std_logic;
            max10_link_miso_oe                    : out   std_logic;
            max10_link_d1_in                      : in    std_logic;
            max10_link_d1_out                     : out   std_logic;
            max10_link_d1_oe                      : out   std_logic;
            max10_link_d2_in                      : in    std_logic;
            max10_link_d2_out                     : out   std_logic;
            max10_link_d2_oe                      : out   std_logic;
            max10_link_d3_in                      : in    std_logic;
            max10_link_d3_out                     : out   std_logic;
            max10_link_d3_oe                      : out   std_logic;
            max10_link_clock_clk                  : in    std_logic;
            mclk125_clk                           : in    std_logic;
            mutrig_cfg_ctrl_0_spi_export2top_miso : in    std_logic;
            mutrig_cfg_ctrl_0_spi_export2top_mosi : out   std_logic;
            mutrig_cfg_ctrl_0_spi_export2top_sclk : out   std_logic;
            mutrig_cfg_ctrl_0_spi_export2top_ssn  : out   std_logic_vector(7 downto 0);
            mutrig_reset_export                   : out   std_logic_vector(1 downto 0);
            osc_clock_50_in_clk                   : in    std_logic;
            pulse_out_conduit_pulse               : out   std_logic;
            redriver_losn                         : in    std_logic_vector(0 downto 0);
            reset_0_reset_n                       : in    std_logic;
            reset_1_reset_n                       : in    std_logic;
            reset_3_reset_n                       : in    std_logic;
            sense_dq_in                           : in    std_logic_vector(5 downto 0);
            sense_dq_out                          : out   std_logic_vector(5 downto 0);
            sense_dq_oe                           : out   std_logic_vector(5 downto 0);
            serial_data                           : in    std_logic_vector(0 downto 0);
            si_gpio_out_export                    : out   std_logic_vector(15 downto 0);
            si_status_in_export                   : in    std_logic_vector(7 downto 0);
            synclink_data                         : in    std_logic_vector(8 downto 0);
            synclink_error                        : in    std_logic_vector(2 downto 0);
            to_firefly_ucc8_scl                   : inout std_logic;
            to_firefly_ucc8_present_n             : in    std_logic_vector(1 downto 0);
            to_firefly_ucc8_sda                   : inout std_logic;
            to_firefly_ucc8_reset_n               : out   std_logic_vector(1 downto 0);
            to_firefly_ucc8_select_n              : out   std_logic_vector(1 downto 0);
            to_firefly_ucc8_int_n                 : in    std_logic_vector(1 downto 0);
            upload_data0_sc_rc_data               : out   std_logic_vector(35 downto 0);
            upload_data0_sc_rc_valid              : out   std_logic;
            upload_data0_sc_rc_ready              : in    std_logic;
            upload_data0_sc_rc_startofpacket      : out   std_logic;
            upload_data0_sc_rc_endofpacket        : out   std_logic;
            upload_data0_sc_rc_channel            : out   std_logic
        );
    end component focus_emulator_type0_system;

    signal board_reset_n          : std_logic;

    signal mutrig_spi_mosi        : std_logic;
    signal mutrig_spi_sclk        : std_logic;
    signal mutrig_spi_ssn         : std_logic_vector(7 downto 0);
    signal mutrig_reset           : std_logic_vector(1 downto 0);

    signal inject_pulse           : std_logic;
    signal inject_masked_pulse    : std_logic;
    signal charge_inject_pulse    : std_logic;
    signal feb_inject_pulse       : std_logic;

    signal max10_link_csn         : std_logic;
    signal max10_link_clk         : std_logic;
    signal max10_link_mosi_in     : std_logic;
    signal max10_link_mosi_out    : std_logic;
    signal max10_link_mosi_oe     : std_logic;
    signal max10_link_miso_in     : std_logic;
    signal max10_link_miso_out    : std_logic;
    signal max10_link_miso_oe     : std_logic;
    signal max10_link_d1_in       : std_logic;
    signal max10_link_d1_out      : std_logic;
    signal max10_link_d1_oe       : std_logic;
    signal max10_link_d2_in       : std_logic;
    signal max10_link_d2_out      : std_logic;
    signal max10_link_d2_oe       : std_logic;
    signal max10_link_d3_in       : std_logic;
    signal max10_link_d3_out      : std_logic;
    signal max10_link_d3_oe       : std_logic;

    signal sense_dq_in            : std_logic_vector(5 downto 0);
    signal sense_dq_out           : std_logic_vector(5 downto 0);
    signal sense_dq_oe            : std_logic_vector(5 downto 0);

    signal si_gpio_out            : std_logic_vector(15 downto 0);
    signal si_status_in           : std_logic_vector(7 downto 0);
    signal serial_data            : std_logic_vector(0 downto 0);
    signal redriver_losn          : std_logic_vector(0 downto 0);

    signal legacy_firefly_mon_read : std_logic;
begin
    board_reset_n <= (not fpga_reset) and PushButton(0);

    serial_data(0) <= scifi_din(0);
    redriver_losn(0) <= scifi_ds_losn(0);

    scifi_ds_ctrl <= (others => '0');
    scifi_cec_csn <= (others => '1');
    scifi_fifo_ext <= '0';
    scifi_fifo_ext2 <= '0';

    scifi_temp_mutrig_old <= (others => 'Z');
    scifi_temp_sipm_old <= (others => 'Z');

    scifi_csn(0) <= not mutrig_spi_ssn(0);
    scifi_csn(1) <= not mutrig_spi_ssn(1);
    scifi_csn(2) <= not mutrig_spi_ssn(2);
    scifi_csn(3) <= mutrig_spi_ssn(3);
    scifi_csn(4) <= mutrig_spi_ssn(4);
    scifi_csn(5) <= not mutrig_spi_ssn(5);
    scifi_csn(6) <= not mutrig_spi_ssn(6);
    scifi_csn(7) <= mutrig_spi_ssn(7);

    scifi_spi_sclk <= not mutrig_spi_sclk;
    scifi_spi_mosi <= not mutrig_spi_mosi;
    scifi_spi_sclk2 <= not mutrig_spi_sclk;
    scifi_spi_mosi2 <= not mutrig_spi_mosi;

    scifi_syncres <= not mutrig_reset(0);
    scifi_syncres2 <= not mutrig_reset(1);

    feb_inject_pulse <= inject_pulse or inject_masked_pulse or charge_inject_pulse;
    scifi_inject <= feb_inject_pulse;
    scifi_inject2 <= feb_inject_pulse;
    scifi_ainj <= (others => feb_inject_pulse);

    si45_oe_n <= (others => '0');
    si45_rst_n <= si_gpio_out(5 downto 4) when board_reset_n = '1' else (others => '0');
    si45_spi_in <= (others => si_gpio_out(0));
    si45_spi_sclk <= (others => si_gpio_out(1));
    si45_spi_cs_n <= si_gpio_out(3 downto 2);
    si45_fdec <= (others => '0');
    si45_finc <= (others => '0');

    si_status_in(1 downto 0) <= si45_intr_n;
    si_status_in(3 downto 2) <= si45_lol_n;
    si_status_in(5 downto 4) <= si45_spi_out;
    si_status_in(7 downto 6) <= (others => '0');

    lcd_csn <= '1';
    lcd_d_cn <= '1';
    lcd_data <= (others => '0');
    lcd_wen <= '1';

    mscb_fpga_out <= '0';
    mscb_fpga_oe_n <= '1';

    FPGA_Test <= (7 downto 1 => '0', 0 => board_reset_n);

    max10_spi_sclk <= max10_link_clk;
    max10_spi_csn <= max10_link_csn;
    max10_spi_mosi <= max10_link_mosi_out when max10_link_mosi_oe = '1' else 'Z';
    max10_link_mosi_in <= max10_spi_mosi;
    max10_spi_miso <= max10_link_miso_out when max10_link_miso_oe = '1' else 'Z';
    max10_link_miso_in <= max10_spi_miso;
    max10_spi_D1 <= max10_link_d1_out when max10_link_d1_oe = '1' else 'Z';
    max10_link_d1_in <= max10_spi_D1;
    max10_spi_D2 <= max10_link_d2_out when max10_link_d2_oe = '1' else 'Z';
    max10_link_d2_in <= max10_spi_D2;
    max10_spi_D3 <= max10_link_d3_out when max10_link_d3_oe = '1' else 'Z';
    max10_link_d3_in <= max10_spi_D3;

    scifi_temp_mutrig(0) <= sense_dq_out(0) when sense_dq_oe(0) = '1' else 'Z';
    scifi_temp_mutrig(1) <= sense_dq_out(1) when sense_dq_oe(1) = '1' else 'Z';
    scifi_temp_sipm(0) <= sense_dq_out(2) when sense_dq_oe(2) = '1' else 'Z';
    scifi_temp_sipm(1) <= sense_dq_out(3) when sense_dq_oe(3) = '1' else 'Z';
    scifi_temp_dab(0) <= sense_dq_out(4) when sense_dq_oe(4) = '1' else 'Z';
    scifi_temp_dab(1) <= sense_dq_out(5) when sense_dq_oe(5) = '1' else 'Z';

    sense_dq_in(0) <= scifi_temp_mutrig(0);
    sense_dq_in(1) <= scifi_temp_mutrig(1);
    sense_dq_in(2) <= scifi_temp_sipm(0);
    sense_dq_in(3) <= scifi_temp_sipm(1);
    sense_dq_in(4) <= scifi_temp_dab(0);
    sense_dq_in(5) <= scifi_temp_dab(1);

    u_focus_system : focus_emulator_type0_system
        port map (
            cclk156_clk                           => transceiver_pll_clock(0),
            download_sc_data                      => (others => '0'),
            download_sc_datak                     => (others => '0'),
            download_sc_ready                     => open,
            inject_pulse                          => inject_pulse,
            inject_masked_pulse                   => inject_masked_pulse,
            inject_aux_pulse                      => '0',
            legacy_firefly_mon_waitrequest        => '0',
            legacy_firefly_mon_readdata           => (others => '0'),
            legacy_firefly_mon_readdatavalid      => legacy_firefly_mon_read,
            legacy_firefly_mon_response           => (others => '0'),
            legacy_firefly_mon_burstcount         => open,
            legacy_firefly_mon_writedata          => open,
            legacy_firefly_mon_address            => open,
            legacy_firefly_mon_write              => open,
            legacy_firefly_mon_read               => legacy_firefly_mon_read,
            legacy_firefly_mon_byteenable         => open,
            legacy_firefly_mon_debugaccess        => open,
            lvds_pll_inclock_clk                  => LVDS_clk_si1_fpga_A,
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
            max10_link_clock_clk                  => spare_clk_osc,
            mclk125_clk                           => lvds_firefly_clk,
            mutrig_cfg_ctrl_0_spi_export2top_miso => not scifi_spi_miso,
            mutrig_cfg_ctrl_0_spi_export2top_mosi => mutrig_spi_mosi,
            mutrig_cfg_ctrl_0_spi_export2top_sclk => mutrig_spi_sclk,
            mutrig_cfg_ctrl_0_spi_export2top_ssn  => mutrig_spi_ssn,
            mutrig_reset_export                   => mutrig_reset,
            osc_clock_50_in_clk                   => spare_clk_osc,
            pulse_out_conduit_pulse               => charge_inject_pulse,
            redriver_losn                         => redriver_losn,
            reset_0_reset_n                       => board_reset_n,
            reset_1_reset_n                       => board_reset_n,
            reset_3_reset_n                       => board_reset_n,
            sense_dq_in                           => sense_dq_in,
            sense_dq_out                          => sense_dq_out,
            sense_dq_oe                           => sense_dq_oe,
            serial_data                           => serial_data,
            si_gpio_out_export                    => si_gpio_out,
            si_status_in_export                   => si_status_in,
            synclink_data                         => (others => '0'),
            synclink_error                        => (others => '0'),
            to_firefly_ucc8_scl                   => Firefly_Scl,
            to_firefly_ucc8_present_n             => Firefly_ModPrs_n,
            to_firefly_ucc8_sda                   => Firefly_Sda,
            to_firefly_ucc8_reset_n               => Firefly_Rst_n,
            to_firefly_ucc8_select_n              => Firefly_ModSel_n,
            to_firefly_ucc8_int_n                 => Firefly_Int_n,
            upload_data0_sc_rc_data               => open,
            upload_data0_sc_rc_valid              => open,
            upload_data0_sc_rc_ready              => '1',
            upload_data0_sc_rc_startofpacket      => open,
            upload_data0_sc_rc_endofpacket        => open,
            upload_data0_sc_rc_channel            => open
        );
end architecture rtl;

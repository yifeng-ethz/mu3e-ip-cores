library ieee;
library unnamed;
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

    firefly1_tx_data            : out   std_logic_vector(3 downto 0);
    firefly2_tx_data            : out   std_logic_vector(3 downto 0);
    firefly1_rx_data            : in    std_logic;
    firefly2_rx_data            : in    std_logic_vector(2 downto 0);

    firefly1_lvds_rx_in         : in    std_logic;
    firefly2_lvds_rx_in         : in    std_logic;

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
    signal board_reset_n          : std_logic := '0';
    signal lvds_pll_refclk_global : std_logic := '0';

    signal feb_mutrig_spi_mosi    : std_logic := '0';
    signal feb_mutrig_spi_sclk    : std_logic := '0';
    signal feb_mutrig_spi_ssn     : std_logic_vector(7 downto 0) := (others => '1');
    signal feb_mutrig_spi_miso    : std_logic := '0';
    signal feb_mutrig_reset       : std_logic_vector(1 downto 0) := (others => '0');
    signal feb_inject_pulse       : std_logic := '0';

    signal feb_max10_link_csn      : std_logic := '1';
    signal feb_max10_link_clk      : std_logic := '0';
    signal feb_max10_link_mosi_out : std_logic := '0';
    signal feb_max10_link_mosi_oe  : std_logic := '0';
    signal feb_max10_link_mosi_in  : std_logic := '0';
    signal feb_max10_link_d1_out   : std_logic := '0';
    signal feb_max10_link_d1_oe    : std_logic := '0';
    signal feb_max10_link_d1_in    : std_logic := '0';
    signal feb_max10_link_d2_out   : std_logic := '0';
    signal feb_max10_link_d2_oe    : std_logic := '0';
    signal feb_max10_link_d2_in    : std_logic := '0';
    signal feb_max10_link_d3_out   : std_logic := '0';
    signal feb_max10_link_d3_oe    : std_logic := '0';
    signal feb_max10_link_d3_in    : std_logic := '0';

    signal feb_sense_dq_in        : std_logic_vector(5 downto 0);
    signal feb_sense_dq_out       : std_logic_vector(5 downto 0) := (others => '0');
    signal feb_sense_dq_oe        : std_logic_vector(5 downto 0) := (others => '0');

    signal feb_si_gpio_out        : std_logic_vector(15 downto 0) := (others => '0');
    signal feb_si_status_in       : std_logic_vector(7 downto 0) := (others => '0');

    signal feb_serial_data        : std_logic_vector(8 downto 0);
    signal feb_redriver_losn      : std_logic_vector(8 downto 0);
begin
    feb_serial_data <= firefly1_lvds_rx_in & scifi_din;
    feb_redriver_losn <= '1' & scifi_ds_losn(10 downto 7) & scifi_ds_losn(3 downto 0);

    feb_mutrig_spi_miso <= (not scifi_spi_miso2) when feb_mutrig_spi_ssn(7 downto 4) /= x"F" else not scifi_spi_miso;

    scifi_csn(0) <= not feb_mutrig_spi_ssn(0);
    scifi_csn(1) <= not feb_mutrig_spi_ssn(1);
    scifi_csn(2) <= not feb_mutrig_spi_ssn(2);
    scifi_csn(3) <= feb_mutrig_spi_ssn(3);
    scifi_csn(4) <= feb_mutrig_spi_ssn(4);
    scifi_csn(5) <= not feb_mutrig_spi_ssn(5);
    scifi_csn(6) <= not feb_mutrig_spi_ssn(6);
    scifi_csn(7) <= feb_mutrig_spi_ssn(7);

    scifi_syncres <= not feb_mutrig_reset(0);
    scifi_syncres2 <= not feb_mutrig_reset(1);

    scifi_spi_sclk <= not feb_mutrig_spi_sclk;
    scifi_spi_mosi <= not feb_mutrig_spi_mosi;
    scifi_spi_sclk2 <= not feb_mutrig_spi_sclk;
    scifi_spi_mosi2 <= not feb_mutrig_spi_mosi;

    scifi_cec_csn <= (others => '1');
    scifi_fifo_ext <= '0';
    scifi_fifo_ext2 <= '0';
    scifi_inject <= feb_inject_pulse;
    scifi_inject2 <= feb_inject_pulse;
    scifi_ainj <= (others => feb_inject_pulse);
    scifi_ds_ctrl <= (others => '0');

    scifi_temp_mutrig_old <= (others => 'Z');
    scifi_temp_sipm_old <= (others => 'Z');

    si45_oe_n <= (others => '0');
    si45_rst_n <= feb_si_gpio_out(5 downto 4) when board_reset_n = '1' else (others => '0');
    si45_spi_in <= (others => feb_si_gpio_out(0));
    si45_spi_sclk <= (others => feb_si_gpio_out(1));
    si45_spi_cs_n <= feb_si_gpio_out(3 downto 2);
    si45_fdec <= (others => '0');
    si45_finc <= (others => '0');

    feb_si_status_in(1 downto 0) <= si45_intr_n;
    feb_si_status_in(3 downto 2) <= si45_lol_n;
    feb_si_status_in(5 downto 4) <= si45_spi_out;
    feb_si_status_in(7 downto 6) <= (others => '0');

    lcd_csn <= '1';
    lcd_d_cn <= '1';
    lcd_data <= (others => '0');
    lcd_wen <= '1';

    mscb_fpga_out <= '0';
    mscb_fpga_oe_n <= '1';

    FPGA_Test <= (7 downto 1 => '0', 0 => lvds_firefly_clk);

    u_board_reset : entity work.board_reset_adapter
        port map (
            i_clk                  => spare_clk_osc,
            i_reset_release_button => PushButton(0),
            o_board_reset_n        => board_reset_n
        );

    -- Promote the 125 MHz LVDS reference onto the clock network before it
    -- enters the LVDS RX PLL chain. Quartus 18.1 on Arria V is more reliable
    -- with the explicit clock-control block than with implicit promotion.
    u_lvds_refclk_ctrl : entity unnamed.unnamed
        port map (
            inclk  => LVDS_clk_si1_fpga_A,
            outclk => lvds_pll_refclk_global
        );

    u_onewire : entity work.onewire_adapter
        port map (
            i_sense_dq_out       => feb_sense_dq_out,
            i_sense_dq_oe        => feb_sense_dq_oe,
            o_sense_dq_in        => feb_sense_dq_in,
            io_scifi_temp_mutrig => scifi_temp_mutrig,
            io_scifi_temp_sipm   => scifi_temp_sipm,
            io_scifi_temp_dab    => scifi_temp_dab
        );

    u_max10 : entity work.max10_link_adapter
        port map (
            i_clk             => spare_clk_osc,
            i_link_csn        => feb_max10_link_csn,
            i_link_clk        => feb_max10_link_clk,
            i_link_mosi_out   => feb_max10_link_mosi_out,
            i_link_mosi_oe    => feb_max10_link_mosi_oe,
            i_link_d1_out     => feb_max10_link_d1_out,
            i_link_d1_oe      => feb_max10_link_d1_oe,
            i_link_d2_out     => feb_max10_link_d2_out,
            i_link_d2_oe      => feb_max10_link_d2_oe,
            i_link_d3_out     => feb_max10_link_d3_out,
            i_link_d3_oe      => feb_max10_link_d3_oe,
            o_link_mosi_in    => feb_max10_link_mosi_in,
            o_link_d1_in      => feb_max10_link_d1_in,
            o_link_d2_in      => feb_max10_link_d2_in,
            o_link_d3_in      => feb_max10_link_d3_in,
            o_max10_spi_sclk  => max10_spi_sclk,
            o_max10_spi_csn   => max10_spi_csn,
            io_max10_spi_mosi => max10_spi_mosi,
            io_max10_spi_miso => max10_spi_miso,
            io_max10_spi_d1   => max10_spi_D1,
            io_max10_spi_d2   => max10_spi_D2,
            io_max10_spi_d3   => max10_spi_D3
        );

    u_feb_system : entity work.feb_system
        port map (
            i_xcvr_clk               => transceiver_pll_clock(0),
            i_lvds_pll_refclk        => lvds_pll_refclk_global,
            i_monitor_clk_125        => lvds_firefly_clk,
            i_free_running_clk       => spare_clk_osc,
            i_board_reset_n          => board_reset_n,
            i_serial_data            => feb_serial_data,
            i_redriver_losn          => feb_redriver_losn,
            o_mutrig_spi_mosi        => feb_mutrig_spi_mosi,
            o_mutrig_spi_sclk        => feb_mutrig_spi_sclk,
            o_mutrig_spi_ssn         => feb_mutrig_spi_ssn,
            i_mutrig_spi_miso        => feb_mutrig_spi_miso,
            o_mutrig_reset           => feb_mutrig_reset,
            o_inject_pulse           => feb_inject_pulse,
            o_max10_link_csn         => feb_max10_link_csn,
            o_max10_link_clk         => feb_max10_link_clk,
            i_max10_link_mosi_in     => feb_max10_link_mosi_in,
            o_max10_link_mosi_out    => feb_max10_link_mosi_out,
            o_max10_link_mosi_oe     => feb_max10_link_mosi_oe,
            i_max10_link_d1_in       => feb_max10_link_d1_in,
            o_max10_link_d1_out      => feb_max10_link_d1_out,
            o_max10_link_d1_oe       => feb_max10_link_d1_oe,
            i_max10_link_d2_in       => feb_max10_link_d2_in,
            o_max10_link_d2_out      => feb_max10_link_d2_out,
            o_max10_link_d2_oe       => feb_max10_link_d2_oe,
            i_max10_link_d3_in       => feb_max10_link_d3_in,
            o_max10_link_d3_out      => feb_max10_link_d3_out,
            o_max10_link_d3_oe       => feb_max10_link_d3_oe,
            i_sense_dq_in            => feb_sense_dq_in,
            o_sense_dq_out           => feb_sense_dq_out,
            o_sense_dq_oe            => feb_sense_dq_oe,
            o_si_gpio_out            => feb_si_gpio_out,
            i_si_status_in           => feb_si_status_in,
            io_firefly_ucc8_scl      => Firefly_Scl,
            i_firefly_ucc8_present_n => Firefly_ModPrs_n,
            io_firefly_ucc8_sda      => Firefly_Sda,
            o_firefly_ucc8_reset_n   => Firefly_Rst_n,
            o_firefly_ucc8_select_n  => Firefly_ModSel_n,
            i_firefly_ucc8_int_n     => Firefly_Int_n,
            o_firefly1_tx_data       => firefly1_tx_data,
            o_firefly2_tx_data       => firefly2_tx_data,
            i_firefly1_rx_data       => firefly1_rx_data,
            i_firefly2_rx_data       => firefly2_rx_data
        );
end architecture rtl;

-- FEB reg mapping for the firefly transceivers
-- M.Mueller, Jan 2021


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

use work.feb_sc_registers.all;
use work.mudaq.all;


entity firefly_reg_mapping is
generic (
    N_CHANNELS_g : positive := 1;
    CHANNEL_WIDTH_g : positive := 32--;
);
port (
    i_reg_add                   : in    std_logic_vector(15 downto 0);
    i_reg_re                    : in    std_logic;
    o_reg_rdata                 : out   std_logic_vector(31 downto 0);
    i_reg_we                    : in    std_logic;
    i_reg_wdata                 : in    std_logic_vector(31 downto 0);

    o_loopback                  : out   std_logic_vector(N_CHANNELS_g-1 downto 0);
    o_tx_reset                  : out   std_logic_vector(N_CHANNELS_g-1 downto 0);
    o_rx_reset                  : out   std_logic_vector(N_CHANNELS_g-1 downto 0);
    o_lvds_align_reset_n        : out   std_logic;
    i_tx_status                 : in    std_logic_vector(N_CHANNELS_g-1 downto 0) := (others => '0');
    i_tx_errors                 : in    std_logic_vector(N_CHANNELS_g-1 downto 0) := (others => '0');
    i_lvds_controller_state     : in    std_logic_vector(3 downto 0);

    i_rx_ready                  : in    std_logic_vector(N_CHANNELS_g-1 downto 0) := (others => '0');
    i_rx_lockedtoref            : in    std_logic_vector(N_CHANNELS_g-1 downto 0) := (others => '0');
    i_rx_lockedtodata           : in    std_logic_vector(N_CHANNELS_g-1 downto 0) := (others => '0');
    i_rx_locked                 : in    std_logic_vector(N_CHANNELS_g-1 downto 0) := (others => '0');
    i_rx_syncstatus             : in    slv4_array_t(N_CHANNELS_g-1 downto 0) := (others => (others => '0'));
    i_rx_errDetect              : in    slv4_array_t(N_CHANNELS_g-1 downto 0) := (others => (others => '0'));
    i_rx_disperr                : in    slv4_array_t(N_CHANNELS_g-1 downto 0) := (others => (others => '0'));
    i_rx_fifo_error             : in    std_logic_vector(N_CHANNELS_g-1 downto 0) := (others => '0');
    i_lol_cnt                   : in    slv8_array_t(N_CHANNELS_g-1 downto 0) := (others => (others => '0'));
    i_err_cnt                   : in    slv16_array_t(N_CHANNELS_g-1 downto 0) := (others => (others => '0'));
    i_rx_data                   : in    slv32_array_t(N_CHANNELS_g-1 downto 0) := (others => (others => '0'));
    i_rx_datak                  : in    slv4_array_t(N_CHANNELS_g-1 downto 0) := (others => (others => '0'));
    i_gbit                      : in    slv24_array_t(N_CHANNELS_g-1 downto 0) := (others => (others => '0'));

    i_clk                       : in    std_logic;
    i_reset_n                   : in    std_logic--;
);
end entity;

architecture rtl of firefly_reg_mapping is

    signal channel_sel     : std_logic_vector(31 downto 0);
    signal channel_sel_int : integer range 0 to N_CHANNELS_g - 1;
    signal tx_reset        : std_logic_vector(N_CHANNELS_g - 1 downto 0);
    signal rx_reset        : std_logic_vector(N_CHANNELS_g - 1 downto 0);
    signal loopback        : std_logic_vector(N_CHANNELS_g - 1 downto 0);

    signal lvds_align_reset_delay : std_logic_vector(5 downto 0);

begin

    channel_sel_int <= to_integer(unsigned(channel_sel));

    process(i_clk, i_reset_n)
        variable regaddr : integer;
    begin
    if ( i_reset_n = '0' ) then
        channel_sel <= (others => '0');
        loopback <= (others => '0');
        o_lvds_align_reset_n <= '0';
        lvds_align_reset_delay <= (others => '0');

    elsif rising_edge(i_clk) then

        regaddr             := to_integer(unsigned(i_reg_add));
        o_reg_rdata         <= x"CCCCCCCC";

        rx_reset            <= (others => '0');
        tx_reset            <= (others => '0');
        o_tx_reset          <= tx_reset;
        o_rx_reset          <= rx_reset;
        o_loopback          <= loopback;

        o_lvds_align_reset_n <= lvds_align_reset_delay(0);
        lvds_align_reset_delay(5) <= '1';
        for I in 0 to 4 loop
            lvds_align_reset_delay(I) <= lvds_align_reset_delay(I+1);
        end loop;

        -- channel select
        if ( regaddr = FIREFLY_XCVR_CH_SEL_REGISTER_RW and i_reg_re = '1' ) then
            o_reg_rdata <= channel_sel;
        end if;
        if ( regaddr = FIREFLY_XCVR_CH_SEL_REGISTER_RW and i_reg_we = '1' ) then
            if(to_integer(unsigned(i_reg_wdata))<N_CHANNELS_g) then
                channel_sel <= i_reg_wdata;
            end if;
        end if;

        -- Number of Channels
        if ( regaddr = FIREFLY_XCVR_N_CH_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= std_logic_vector(to_unsigned(N_CHANNELS_g,32));
        end if;

        -- Channel width
        if ( regaddr = FIREFLY_XCVR_CH_WIDTH_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= std_logic_vector(to_unsigned(CHANNEL_WIDTH_g,32));
        end if;

        -- tx reset
        if ( regaddr = FIREFLY_XCVR_TX_RESET_REGISTER_RW and i_reg_re = '1' ) then
            o_reg_rdata <= (0 => tx_reset(channel_sel_int), others => '0');
        end if;
        if ( regaddr = FIREFLY_XCVR_TX_RESET_REGISTER_RW and i_reg_we = '1' ) then
            tx_reset(channel_sel_int) <= i_reg_wdata(0);
        end if;

        -- tx_status
        if ( regaddr = FIREFLY_XCVR_TX_STATUS_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= (0 => i_tx_status(channel_sel_int), others => '0');
        end if;

        -- tx_errors
        if ( regaddr = FIREFLY_XCVR_TX_ERROR_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <=(8 => i_tx_errors(channel_sel_int), others => '0');
        end if;

        -- rx reset
        if ( regaddr = FIREFLY_XCVR_RX_RESET_REGISTER_RW and i_reg_re = '1' ) then
            o_reg_rdata <= (0 => rx_reset(channel_sel_int), others => '0');
        end if;
        if ( regaddr = FIREFLY_XCVR_RX_RESET_REGISTER_RW and i_reg_we = '1' ) then
            rx_reset(channel_sel_int) <= i_reg_wdata(0);
        end if;

        -- rx_status
        if ( regaddr = FIREFLY_XCVR_RX_STATUS_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata(0)                                  <= i_rx_ready(channel_sel_int);
            o_reg_rdata(1)                                  <= i_rx_lockedtoref(channel_sel_int);
            o_reg_rdata(2)                                  <= i_rx_lockedtodata(channel_sel_int);
            o_reg_rdata(12)                                 <= i_rx_locked(channel_sel_int);
            o_reg_rdata(CHANNEL_WIDTH_g/8-1 + 8 downto 8) <= i_rx_syncstatus(channel_sel_int);
            o_reg_rdata(31 downto 13)                       <= (others => '0');
        end if;

        -- rx_errors
        if ( regaddr = FIREFLY_XCVR_RX_ERROR_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata(CHANNEL_WIDTH_g/8-1 + 0 downto 0) <= i_rx_errDetect(channel_sel_int);
            o_reg_rdata(CHANNEL_WIDTH_g/8-1 + 4 downto 4) <= i_rx_disperr(channel_sel_int);
            o_reg_rdata(8)                                  <= i_rx_fifo_error(channel_sel_int);
            o_reg_rdata(31 downto 9)                        <= (others => '0');
        end if;

        -- loss of lock
        if ( regaddr = FIREFLY_XCVR_LOL_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata( 7 downto 0) <= i_lol_cnt(channel_sel_int);
            o_reg_rdata(31 downto 0) <= (others => '0');
        end if;

        -- err cnt register
        if ( regaddr = FIREFLY_XCVR_ERR_CNT_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata(15 downto 0) <= i_err_cnt(channel_sel_int);
            o_reg_rdata(31 downto 16) <= (others => '0');
        end if;

        -- rx data register
        if ( regaddr = FIREFLY_XCVR_DATA_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= i_rx_data(channel_sel_int);
        end if;

        -- rx datak register
        if ( regaddr = FIREFLY_XCVR_DATAK_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata( 3 downto 0) <= i_rx_datak(channel_sel_int);
            o_reg_rdata(31 downto 4) <= (others => '0');
        end if;

        -- gbit register
        if ( regaddr = FIREFLY_XCVR_GBIT_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata(23 downto 0) <= i_gbit(channel_sel_int);
            o_reg_rdata(31 downto 24) <= (others => '0');
        end if;

        -- loopback reg
        if ( regaddr = FIREFLY_XCVR_LOOPBACK_REGISTER_RW and i_reg_re = '1' ) then
            o_reg_rdata <= (0 => loopback(channel_sel_int), others => '0');
        end if;
        if ( regaddr = FIREFLY_XCVR_LOOPBACK_REGISTER_RW and i_reg_we = '1' ) then
            loopback(channel_sel_int) <= i_reg_wdata(0);
        end if;

        if ( regaddr = RESET_LINK_RESTART_REGISTER_RW and i_reg_we = '1' ) then
            lvds_align_reset_delay <= (others => '0');
            o_lvds_align_reset_n <= '0';
        end if;

        if ( regaddr = LVDS_CONTROLLER_STATE_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata(3 downto 0) <= i_lvds_controller_state;
            o_reg_rdata(31 downto 4) <= (others => '0');
        end if;

    end if;
    end process;

end architecture;

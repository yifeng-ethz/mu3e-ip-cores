library ieee;
use ieee.std_logic_1164.all;

entity altera_lvds_rx_28nm is
    generic (
        N_LANE : natural
    );
    port (
        pll_areset            : in  std_logic;
        rx_channel_data_align : in  std_logic_vector(N_LANE - 1 downto 0);
        rx_dpa_lock_reset     : in  std_logic_vector(N_LANE - 1 downto 0);
        rx_dpll_hold          : in  std_logic_vector(N_LANE - 1 downto 0);
        rx_fifo_reset         : in  std_logic_vector(N_LANE - 1 downto 0);
        rx_in                 : in  std_logic_vector(N_LANE - 1 downto 0);
        rx_inclock            : in  std_logic;
        rx_reset              : in  std_logic_vector(N_LANE - 1 downto 0);
        rx_cda_max            : out std_logic_vector(N_LANE - 1 downto 0);
        rx_dpa_locked         : out std_logic_vector(N_LANE - 1 downto 0);
        rx_locked             : out std_logic;
        rx_out                : out std_logic_vector(N_LANE * 10 - 1 downto 0);
        rx_outclock           : out std_logic
    );
end entity altera_lvds_rx_28nm;

architecture sim of altera_lvds_rx_28nm is
begin
    rx_outclock <= rx_inclock;

    process
    begin
        rx_locked <= '0';
        wait for 200 ns;
        rx_locked <= '1';
        wait;
    end process;

    process
    begin
        rx_dpa_locked <= (others => '0');
        wait for 300 ns;
        rx_dpa_locked <= (others => '1');
        wait;
    end process;

    rx_out     <= (others => '0');
    rx_cda_max <= (others => '0');
end architecture sim;


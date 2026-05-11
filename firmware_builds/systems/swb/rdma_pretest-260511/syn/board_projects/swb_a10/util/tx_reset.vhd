--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

entity tx_reset is
generic (
    g_CHANNELS : positive := 4;
    -- number of PLLs
    g_N_PLL : positive := 1;
    g_CLK_MHZ : real := 50.0--;
);
port (
    o_analogreset       : out   std_logic_vector(g_CHANNELS-1 downto 0);
    -- asynchronous reset to all digital logic in the transmitter PCS
    o_digitalreset      : out   std_logic_vector(g_CHANNELS-1 downto 0);

    o_ready             : out   std_logic_vector(g_CHANNELS-1 downto 0);

    -- powers down the CMU PLLs
    o_pll_powerdown     : out   std_logic_vector(g_N_PLL-1 downto 0);
    -- status of the transmitter PLL
    i_pll_locked        : in    std_logic_vector(g_N_PLL-1 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture arch of tx_reset is

    -- powerdown pulse length
    -- "Chapter 1: DC and Switching Characteristics for Stratix IV Devices"
    constant PLL_POWERDOWN_WIDTH_NS : positive := 1000; -- ns

    signal pll_powerdown_n : std_logic;
    signal analogreset_n : std_logic;
    signal digitalreset_n : std_logic;

begin

    o_analogreset <= (others => not analogreset_n);
    o_digitalreset <= (others => not digitalreset_n);
    o_ready <= (others => digitalreset_n);
    o_pll_powerdown <= (others => not pll_powerdown_n);

    -- generate powerdown pulse
    e_pll_powerdown_n : entity work.debouncer
    generic map ( W => 1, N => integer(real(PLL_POWERDOWN_WIDTH_NS) * g_CLK_MHZ / 1000.0) )
    port map (
        i_d(0) => '1', o_q(0) => pll_powerdown_n,
        i_reset_n => i_reset_n,
        i_clk => i_clk--,
    );

    analogreset_n <= pll_powerdown_n;

    e_digitalreset_n : entity work.reset_sync
    port map (
        i_areset_n => and_reduce(pll_powerdown_n & i_pll_locked),
        o_reset_n => digitalreset_n,
        i_clk => i_clk--,
    );

end architecture;

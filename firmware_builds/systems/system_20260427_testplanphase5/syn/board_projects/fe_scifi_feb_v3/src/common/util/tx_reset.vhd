--

library ieee;
use ieee.std_logic_1164.all;

entity tx_reset is
generic (
    NUMBER_OF_CHANNELS_g : positive := 4;
    NUMBER_OF_PLLS_g : positive := 1;
    CLK_MHZ_g : positive := 50--;
);
port (
    o_analogreset       : out   std_logic_vector(NUMBER_OF_CHANNELS_g-1 downto 0);
    -- asynchronous reset to all digital logic in the transmitter PCS
    o_digitalreset      : out   std_logic_vector(NUMBER_OF_CHANNELS_g-1 downto 0);

    o_ready             : out   std_logic_vector(NUMBER_OF_CHANNELS_g-1 downto 0);

    -- powers down the CMU PLLs
    o_pll_powerdown     : out   std_logic_vector(NUMBER_OF_PLLS_g-1 downto 0);
    -- status of the transmitter PLL
    i_pll_locked        : in    std_logic_vector(NUMBER_OF_PLLS_g-1 downto 0);

    i_areset_n          : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture arch of tx_reset is

    -- powerdown pulse length
    -- "Chapter 1: DC and Switching Characteristics for Stratix IV Devices"
    constant PLL_POWERDOWN_WIDTH_c : positive := 1000; -- ns

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
    generic map ( W => 1, N => PLL_POWERDOWN_WIDTH_c * CLK_MHZ_g / 1000 )
    port map (
        i_d(0) => '1', o_q(0) => pll_powerdown_n,
        i_reset_n => i_areset_n,
        i_clk => i_clk--,
    );

    analogreset_n <= pll_powerdown_n;

    e_digitalreset_n : entity work.reset_sync
    port map (
        o_reset_n => digitalreset_n,
        i_reset_n => pll_powerdown_n and work.util.and_reduce(i_pll_locked),
        i_clk => i_clk--,
    );

end architecture;

--

library ieee;
use ieee.std_logic_1164.all;

entity rx_reset is
generic (
    g_CHANNELS : positive := 4;
    g_CLK_MHZ : real := 50.0--;
);
port (
    -- reset the receiver CDR present in the receiver channel
    o_analogreset       : out   std_logic_vector(g_CHANNELS-1 downto 0);
    -- reset all digital logic in the receiver PCS
    o_digitalreset      : out   std_logic_vector(g_CHANNELS-1 downto 0);

    o_ready             : out   std_logic_vector(g_CHANNELS-1 downto 0);

    -- status of the receiver CDR lock mode
    i_freqlocked        : in    std_logic_vector(g_CHANNELS-1 downto 0);

    -- status of the dynamic reconfiguration controller
    i_reconfig_busy     : in    std_logic;

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture arch of rx_reset is

    -- lock-to-data delay
    -- "Chapter 1: DC and Switching Characteristics for Stratix IV Devices"
    constant LTD_DELAY_NS : positive := 4000; -- ns

    signal analogreset_n : std_logic;
    signal digitalreset_n : std_logic_vector(g_CHANNELS-1 downto 0);

begin

    o_analogreset <= (others => not analogreset_n);
    o_digitalreset <= not digitalreset_n;
    o_ready <= digitalreset_n;

    e_analogreset_n : entity work.reset_sync
    port map (
        i_areset_n => i_reset_n and not i_reconfig_busy,
        o_reset_n => analogreset_n,
        i_clk => i_clk--,
    );

    -- release digtal reset after delay
    g_digitalreset_n : for i in digitalreset_n'range generate
    begin
        e_digitalreset_n : entity work.debouncer
        generic map ( W => 1, N => integer(real(LTD_DELAY_NS) * g_CLK_MHZ / 1000.0) )
        port map (
            i_d(0) => '1', o_q(0) => digitalreset_n(i),
            i_reset_n => i_reset_n and i_freqlocked(i),
            i_clk => i_clk--,
        );
    end generate;

end architecture;

--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

-- Glitch-Free Clock Multiplexer (from "Quartus User Guide / Clock Multiplexing")
-- - no clock activates until all others are inactive for at least a few cycles
-- - activation occurs while the clock is low
-- - switching from clock requires that clock to operate for at least a few cycles
-- - design can tolerate extreme glitching during the switch process
entity clkmux is
generic (
    g_N : integer := 2--;
);
port (
    -- TODO: false_path on i_sel or use ff_sync
    i_sel       : in    std_logic_vector(g_N-1 downto 0) := (others => '0');

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic_vector(g_N-1 downto 0);

    o_clk       : out   std_logic--;
);
end entity;

architecture arch of clkmux is

    signal clk : std_logic_vector(i_clk'range);
    signal gate : std_logic_vector(g_N-1 downto 0);

    -- `keep` directive on `clk` AND gates ensures that
    -- there are no simultaneous toggles on the input of the `o_clk` OR gate
    attribute keep : boolean;
    attribute keep of clk : signal is true;

begin

    assert ( true
        and work.util.count_bits(i_sel) <= 1
    ) severity failure;

    o_clk <= or_reduce(clk);

    gen_clk : for i in i_clk'range generate
        signal ff1, ff2 : std_logic;
    begin
        clk(i) <= i_clk(i) and gate(i);

        process(i_clk, i_reset_n)
            variable mask : std_logic_vector(i_clk'range);
        begin
        if ( i_reset_n /= '1' ) then
            gate(i) <= '0';
            ff1 <= '0';
            ff2 <= '0';
            --
        elsif falling_edge(i_clk(i)) then
            gate(i) <= ff1;
        elsif rising_edge(i_clk(i)) then
            ff1 <= ff2;
            mask := (others => '1');
            mask(i) := '0';
            ff2 <= i_sel(i) and not or_reduce(gate and mask);
        end if;
        end process;

    end generate;

end architecture;

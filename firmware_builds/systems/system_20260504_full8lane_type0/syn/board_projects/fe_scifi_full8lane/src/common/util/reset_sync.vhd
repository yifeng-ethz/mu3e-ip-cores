--
-- author : Alexandr Kozlinskiy
--

library ieee;
use ieee.std_logic_1164.all;

-- reset synchronizer
-- NOTE: use when i_reset_n is async with i_clk
entity reset_sync is
generic (
    -- number of stages
    N : positive := 2--;
);
port (
    i_reset_n   : in    std_logic;

    o_reset_n   : out   std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of reset_sync is

    -- no 'preserve' attr on final output reg
    -- (see altera_reset_synchronizer)
    signal q : std_logic;

begin

    e_ff_sync : entity work.ff_sync
    generic map (
        W => 1,
        N => N--,
    )
    port map (
        i_d(0) => '1',
        o_q(0) => q,
        i_reset_n => i_reset_n,
        i_clk => i_clk--,
    );

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        o_reset_n <= '0';
    elsif rising_edge(i_clk) then
        o_reset_n <= q;
    end if;
    end process;

end architecture;

--
-- author : Alexandr Kozlinskiy
--

library ieee;
use ieee.std_logic_1164.all;

entity debouncer is
generic (
    -- bus width
    W   : positive := 1;
    -- number of clock cycles (stable signal)
    N   : positive := 16#FFFF#--;
);
port (
    i_d         : in    std_logic_vector(W-1 downto 0);
    o_q         : out   std_logic_vector(W-1 downto 0);
    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of debouncer is

    signal ff0, ff1 : std_logic_vector(i_d'range);

    type cnt_array_t is array(i_d'range) of integer range 0 to N-1;
    signal cnt : cnt_array_t;

begin

    e_ff_sync : entity work.ff_sync
    generic map ( W => W )
    port map ( i_d => i_d, o_q => ff0, i_reset_n => i_reset_n, i_clk => i_clk );

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        o_q <= (others => '0');
        ff1 <= (others => '0');
        cnt <= (others => 0);
        --
    elsif rising_edge(i_clk) then
        ff1 <= ff0;

        for i in i_d'range loop
            if ( ff0(i) /= ff1(i) ) then
                cnt(i) <= 0;
            elsif ( cnt(i) = N-1 ) then
                o_q(i) <= ff1(i);
            else
                cnt(i) <= cnt(i) + 1;
            end if;
        end loop;

        --
    end if; -- rising_edge
    end process;

end architecture;

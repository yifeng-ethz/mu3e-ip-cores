--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- generate one cycle reset signal if input (d) is stable for N cycles
entity watchdog is
generic (
    W : positive := 1;
    N : positive := 16#FFFF#--;
);
port (
    i_d         : in    std_logic_vector(W-1 downto 0);

    o_reset_n   : out   std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of watchdog is

    signal ff0 : std_logic_vector(i_d'range);
    signal cnt : integer range 0 to N;

begin

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        o_reset_n <= '0';
        ff0 <= (others => '0');
        cnt <= 0;
        --
    elsif rising_edge(i_clk) then
        o_reset_n <= '1';
        ff0 <= i_d;
        cnt <= 0;

        if ( cnt = N ) then
            o_reset_n <= '0';
        elsif ( ff0 = i_d ) then
            cnt <= cnt + 1;
        end if;
        --
    end if;
    end process;

end architecture;

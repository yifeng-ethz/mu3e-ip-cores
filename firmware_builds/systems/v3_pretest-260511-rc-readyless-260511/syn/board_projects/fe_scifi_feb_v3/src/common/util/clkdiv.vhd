--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- clock divider
-- period_{o_clk} = min(g_N,i_N) * period_{i_clk}
entity clkdiv is
generic (
    -- static divsor
    g_N : positive := 2--;
);
port (
    o_clk       : out   std_logic;
    -- dynamic divisor
    i_N         : in    integer range 0 to g_N := g_N;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of clkdiv is

    -- output i_clk to o_clk when N = 1
    signal bypass : std_logic;

    -- rising edge and falling edge of divided clock
    signal clk1, clk2 : std_logic;

    -- internal clock with duty cycle close to 0.5 (from above)
    signal clk : std_logic;
    signal cnt : integer range 0 to g_N/2;
    signal N_2 : integer range 0 to g_N/2; -- N_2 = N/2 <= i_N/2
    signal N0 : std_logic; -- <= i_N(0)

begin

    o_clk <=
        (i_clk and bypass) or
        (clk1 and clk2);

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        clk1 <= '0';
        clk2 <= '0';
        bypass <= '0';
        --
    elsif rising_edge(i_clk) then
        clk1 <= clk;
    elsif falling_edge(i_clk) then
        -- just before rising edge of clk1
        if ( clk1 = '0' and clk = '1' ) then
            clk2 <= '1';
            bypass <= '0';
            if ( N_2 = 0 ) then -- N is 0 or 1
                clk2 <= '0';
                bypass <= N0; -- N is 1
            end if;
        end if;
        -- just before falling edge of clk1
        if ( clk1 = '1' and clk = '0' and N0 = '1' ) then
            clk2 <= '0';
        end if;
        --
    end if;
    end process;

    -- generate internal clock
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        clk <= '0';
        cnt <= 0;
        N_2 <= 0;
        N0 <= '0';
        --
    elsif rising_edge(i_clk) then
        if ( clk = '1' and cnt = 1 and N0 = '0' )
            -- N is even: clk = '1' from [N/2] to 1
        or ( clk = '1' and cnt = 0 and N0 = '1' ) then
            -- N is odd: clk = '1' from [N/2] to 0
            clk <= '0';
            cnt <= N_2;
        elsif ( clk = '0' and cnt = 1 ) or ( N_2 = 0 and cnt = 0 ) then
            -- clk = '0' from [N/2] to 1
            clk <= not clk;
            cnt <= i_N/2;
            N_2 <= i_N/2;
            N0 <= work.util.to_std_logic(i_N mod 2 = 1); -- <= N(0)
        elsif ( cnt = 0 ) then
            report "E [clkdiv] cnt = 0" severity error;
            cnt <= N_2;
        else
            cnt <= cnt - 1;
        end if;
        --
    end if;
    end process;

end architecture;

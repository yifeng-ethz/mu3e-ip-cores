--
-- author : Alexandr Kozlinskiy
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
generic (
    EDGE : integer := 0;
    DIV : positive := 1;
    WRAP : boolean := false;
    W : positive := 8--;
);
port (
    o_cnt       : out   std_logic_vector(W-1 downto 0);
    i_ena       : in    std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of counter is

    signal d : std_logic_vector(1 downto 0);

    signal enable : std_logic;

    signal cnt_div : integer range 0 to DIV-1;
    signal cnt : unsigned(W-1 downto 0);

begin

    o_cnt <= std_logic_vector(cnt);

    d(0) <= i_ena;

    process(i_clk)
    begin
    if rising_edge(i_clk) then
        d(1) <= d(0);
    end if;
    end process;

    enable <=
        -- rising edge
        ( d(0) and not d(1) ) when EDGE > 0 else
        -- falling edge
        ( not d(0) and d(1) ) when EDGE < 0 else
        i_ena;

    process(i_clk, i_reset_n, enable)
    begin
    if ( i_reset_n /= '1' ) then
        cnt_div <= 0;
        cnt <= (others => '0');
        --
    elsif rising_edge(i_clk) and enable = '1' then
        if ( DIV > 1 and cnt_div /= DIV-1 ) then
            cnt_div <= cnt_div + 1;
        else
            cnt_div <= 0;
            if ( WRAP or cnt /= 2**W-1 ) then
                cnt <= cnt + 1;
            end if;
        end if;
        --
    end if;
    end process;

end architecture;

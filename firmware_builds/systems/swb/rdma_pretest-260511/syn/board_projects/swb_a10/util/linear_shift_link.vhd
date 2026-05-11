--

library ieee;
use ieee.std_logic_1164.all;

entity linear_shift_link is
generic (
    g_m             : integer           := 7;
    g_poly          : std_logic_vector  := "1100000" -- x^7+x^6+1
);
port (
    i_sync_reset    : in    std_logic;
    i_seed          : in    std_logic_vector(g_m-1 downto 0);
    i_en            : in    std_logic;
    o_lsfr          : out   std_logic_vector(g_m-1 downto 0);
    o_datak         : out   std_logic_vector(3 downto 0);

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture rtl of linear_shift_link is

    signal r_lfsr : std_logic_vector(g_m downto 1);
    signal w_mask : std_logic_vector(g_m downto 1);
    signal w_poly : std_logic_vector(g_m downto 1);

begin

    o_lsfr <= r_lfsr(g_m downto 1);
    w_poly <= g_poly;

    g_mask : for k in g_m downto 1 generate
        w_mask(k) <= w_poly(k) and r_lfsr(1);
    end generate;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        r_lfsr <= x"000000BC";
        o_datak <= "0001";
    elsif rising_edge(i_clk) then
        if ( i_sync_reset = '1' ) then
            r_lfsr <= i_seed;
        elsif ( i_en = '1' ) then
            r_lfsr <= '0' & r_lfsr(g_m downto 2) xor w_mask;
            o_datak <= "0000";
        else
            r_lfsr <= x"000000BC";
            o_datak <= "0001";
        end if;
    end if;
    end process;

end architecture;

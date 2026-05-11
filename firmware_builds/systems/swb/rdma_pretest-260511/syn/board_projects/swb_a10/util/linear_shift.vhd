-- simple linear shiftregister

library ieee;
use ieee.std_logic_1164.all;

entity linear_shift is
generic (
    g_m : positive := 7;
    g_poly : std_logic_vector := "1100000" -- x^7+x^6+1
);
port (
    i_sync_reset    : in    std_logic;
    i_seed          : in    std_logic_vector(g_m-1 downto 0);
    i_en            : in    std_logic;
    o_lfsr          : out   std_logic_vector(g_m-1 downto 0);

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture rtl of linear_shift is

    signal r_lfsr : std_logic_vector(g_m downto 1);
    signal w_mask : std_logic_vector(g_m downto 1);
    signal w_poly : std_logic_vector(g_m downto 1);

begin

    o_lfsr <= r_lfsr(g_m downto 1);
    w_poly <= g_poly;
    g_mask : for k in g_m downto 1 generate
        w_mask(k) <= w_poly(k) and r_lfsr(1);
    end generate;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        r_lfsr <= (others => '1');
    elsif rising_edge(i_clk) then
        if ( i_sync_reset = '1' ) then
            r_lfsr <= i_seed;
        elsif (i_en = '1') then
            r_lfsr <= '0' & r_lfsr(g_m downto 2) xor w_mask;
        end if;
    end if;
    end process;

end architecture;

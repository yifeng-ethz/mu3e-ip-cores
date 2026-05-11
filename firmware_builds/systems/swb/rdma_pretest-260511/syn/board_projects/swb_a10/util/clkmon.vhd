--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- clock monitor
-- ...
entity clkmon is
generic (
    TST_MHZ : positive := 100;
    CLK_MHZ : positive := 100--;
);
port (
    i_tst_clk   : in    std_logic;
    o_tst_ok    : out   std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of clkmon is

    constant W : positive := 8 + work.util.vector_width(CLK_MHZ / TST_MHZ);

    -- clk clock domain
    signal cnt : unsigned(W-1 downto 0);
    signal ff0, ff1 : std_logic;

    -- tst_clk clock domain
    signal tst_reset_n : std_logic;
    signal tst_clk_slow : std_logic;

begin

    -- sync tst_clk_slow to clk domain
    e_ff_sync : entity work.ff_sync
    generic map ( W => 1 )
    port map ( i_d(0) => tst_clk_slow, o_q(0) => ff0, i_reset_n => i_reset_n, i_clk => i_clk );

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        cnt <= (others => '0');
        ff1 <= '0';
        o_tst_ok <= '0';
        --
    elsif rising_edge(i_clk) then
        -- sync tst_clk_slow to clk domain
        ff1 <= ff0;

        if ( ff0 /= ff1 ) then
            cnt <= (others => '0');
            o_tst_ok <= work.util.to_std_logic(cnt(W-1 downto W-4) = X"F");
        elsif ( cnt = 2**W-1 ) then
            o_tst_ok <= '0';
        else
            cnt <= cnt + 1;
        end if;
        --
    end if;
    end process;

    -- sync reset_n to tst_clk domain
    e_tst_reset_n : entity work.reset_sync
    port map ( i_areset_n => i_reset_n, o_reset_n => tst_reset_n, i_clk => i_tst_clk );

    e_tst_clk_slow : entity work.clkdiv
    generic map (
        g_N => 2**W * 63 / 64 * TST_MHZ / CLK_MHZ * 2--,
    )
    port map (
        o_clk => tst_clk_slow,
        i_reset_n => tst_reset_n,
        i_clk => i_tst_clk--,
    );

end architecture;

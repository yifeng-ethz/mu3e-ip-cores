--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

entity register_map_tb is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 1000.0--;
);
end entity;

architecture arch of register_map_tb is

    signal clk : std_logic := '1';
    signal reset_n : std_logic := '0';
    signal cycle : integer := 0;

    signal random : std_logic_vector(1 downto 0);
    signal DONE : std_logic_vector(1 downto 0) := (others => '0');

    signal reg_0, reg_1 : std_logic_vector(31 downto 0);

    signal addr : std_logic_vector(7 downto 0);
    signal wdata : std_logic_vector(31 downto 0) := (others => '0');
    signal we : std_logic := '0';
    signal rdata : std_logic_vector(31 downto 0);
    signal re : std_logic := '0';

begin

    clk <= not clk after (0.5 us / g_CLK_MHZ);
    reset_n <= '0' when ( cycle < 4 ) else '1';
    cycle <= cycle + 1 after (1 us / g_CLK_MHZ);

    process
        variable lfsr : std_logic_vector(31 downto 0) := std_logic_vector(to_signed(g_SEED, 32));
    begin
        for i in random'range loop
            lfsr := work.util.lfsr(lfsr, 31 & 21 & 1 & 0);
            random(i) <= lfsr(0);
        end loop;
        wait until rising_edge(clk);
    end process;

    e_register_map : entity work.register_map
    generic map (
        g_ADDR_WIDTH => addr'length,
        g_MAP => (
            0 => 16#00#,
            1 => 16#00#
        )--,
    )
    port map (
        i_addr      => (others => '0'),
        i_we        => we,
        i_wdata     => X"CAFEBABE",

        i_re        => re,
        o_rdata     => rdata,

        o_regs(0)   => reg_0,
        o_regs(1)   => reg_1,

        i_reset_n   => reset_n,
        i_clk       => clk--,
    );

    -- write
    we <= random(0);

    process
    begin
        wait until rising_edge(clk) and we = '1';

        if ( we = '1' ) then
            --
        end if;

        if ( cycle+10 > g_STOP_TIME_US*integer(g_CLK_MHZ) ) then
            DONE(0) <= '1';
            wait;
        end if;
    end process;

    -- read
    re <= random(1);

    process
    begin
        wait until rising_edge(clk) and re = '1';

        if ( re = '1' ) then
            --
        end if;

        if ( cycle+10 > g_STOP_TIME_US*integer(g_CLK_MHZ) ) then
            DONE(1) <= '1';
            wait;
        end if;
    end process;

    process
    begin
        wait for g_STOP_TIME_US * 1 us;
        if ( and DONE ) then
            report work.util.SGR_FG_GREEN & "DONE" & work.util.SGR_RESET;
        else
            report work.util.SGR_FG_RED & "NOT DONE" & work.util.SGR_RESET;
        end if;
        assert ( and DONE ) severity error;
        wait;
    end process;

end architecture;

--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity fifo_sync_tb is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 1000.0--;
);
end entity;

architecture arch of fifo_sync_tb is

    signal clk : std_logic := '1';
    signal reset_n : std_logic := '0';
    signal cycle : integer := 0;

    shared variable rng : work.sim.rng_lfsr32_t;
    signal DONE : std_logic_vector(1 downto 0) := (others => '0');

    signal wdata : std_logic_vector(15 downto 0) := (others => '0');
    signal rdata : std_logic_vector(15 downto 0) := (others => '0');

begin

    clk <= not clk after (0.5 us / g_CLK_MHZ);
    reset_n <= '0' when ( cycle < 4 ) else '1';
    cycle <= cycle + 1 after (1 us / g_CLK_MHZ);

    e_fifo : entity work.fifo_sync
    generic map (
        --g_DATA_RESET => (wdata'range => '0'),
        g_DATA_WIDTH => wdata'length--,
    )
    port map (
        i_wdata     => wdata,
        i_wclk      => clk,

        o_rdata     => rdata,
        i_rclk      => clk,
        i_rreset_n  => reset_n--,
    );

    -- generate wdata
    process
    begin
        wait until rising_edge(clk) and reset_n = '1';

        if ( rng.random = '1' ) then
            wdata <= wdata + 1;
        end if;

        if ( real(cycle+2) > real(g_STOP_TIME_US)*g_CLK_MHZ ) then
            DONE(0) <= '1';
            wait;
        end if;
    end process;

    -- check rdata
    process
    begin
        wait until rising_edge(clk) and reset_n = '1';

        if ( real(cycle+2) > real(g_STOP_TIME_US)*g_CLK_MHZ ) then
            DONE(1) <= '1';
            wait;
        end if;
    end process;

    process begin
        rng.init(g_SEED);
        wait until ( and DONE );
        report work.util.SGR_FG_GREEN & "I [tb] SIMULATION DONE" & work.util.SGR_RESET;
        wait;
    end process;

    process begin
        wait for g_STOP_TIME_US * 1 us;
        assert ( and DONE )
            report work.util.SGR_FG_RED & "E [tb] SIMULATION NOT DONE" & work.util.SGR_RESET
            severity error;
        wait;
    end process;

end architecture;

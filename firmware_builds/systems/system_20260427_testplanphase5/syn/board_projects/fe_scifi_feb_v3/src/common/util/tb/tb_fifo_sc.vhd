--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fifo_sc is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 1000.0--;
);
end entity;

architecture arch of tb_fifo_sc is

    signal clk : std_logic := '1';
    signal reset_n : std_logic := '0';
    signal cycle : integer := 0;

    signal random : std_logic_vector(1 downto 0);
    signal DONE : std_logic_vector(1 downto 0) := (others => '0');

    signal wdata : std_logic_vector(15 downto 0) := (others => '0');
    signal we, wfull : std_logic := '0';
    signal rdata : std_logic_vector(15 downto 0);
    signal rack, rempty : std_logic := '0';

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

    e_fifo : entity work.fifo_reg
    generic map (
        --g_ADDR_WIDTH => 2,
        g_DATA_WIDTH => wdata'length,
        --g_RADDR_WIDTH => 4,
        --g_RDATA_WIDTH => rdata'length,
        --g_WADDR_WIDTH => 4,
        --g_WDATA_WIDTH => wdata'length,
        --g_RREG_N => 1,
        --g_WREG_N => 1,
        --g_DEVICE_FAMILY => "Arria 10"--
        g_N => 1--,
    )
    port map (
        i_we        => we,
        i_wdata     => wdata,
        o_wfull     => wfull,

        i_rack      => rack,
        o_rdata     => rdata,
        o_rempty    => rempty,

        --i_wclk      => clk,
        --i_rclk      => clk,
        i_clk       => clk,
        i_reset_n   => reset_n--,
    );

    -- write
    we <= -- '0' when ( reset_n = '0' or wfull = '1' ) else
        random(0);

    process
    begin
        wait until rising_edge(clk) and we = '1';

        if ( we = '1' and wfull = '0' ) then
            wdata <= std_logic_vector(unsigned(wdata) + 1);
        end if;

        if ( cycle+10 > g_STOP_TIME_US*integer(g_CLK_MHZ) ) then
            DONE(0) <= '1';
            wait;
        end if;
    end process;

    -- read
    rack <= -- '0' when ( reset_n = '0' or rempty = '1' ) else
        random(1);

    process
        variable rdata_v : std_logic_vector(rdata'range) := (others => '0');
    begin
        wait until rising_edge(clk) and rack = '1';

        if ( rack = '1' and rempty = '0' and rdata /= rdata_v ) then
            report work.util.SGR_FG_RED
                & "[cycle = " & integer'image(cycle) & "]"
                & " rdata = " & to_hstring(rdata)
                & " != " & to_hstring(rdata_v)
                & work.util.SGR_RESET
            severity error;
        end if;

        if ( rack = '1' and rempty = '0' ) then
            rdata_v := std_logic_vector(unsigned(rdata_v) + 1);
        end if;

        if ( cycle+10 > g_STOP_TIME_US*integer(g_CLK_MHZ) ) then
            DONE(1) <= '1';
            wait;
        end if;
    end process;

    process
    begin
        wait for g_STOP_TIME_US * 1 us;
        if ( DONE = (DONE'range => '1') ) then
            report work.util.SGR_FG_GREEN & "DONE" & work.util.SGR_RESET;
        else
            report work.util.SGR_FG_RED & "NOT DONE" & work.util.SGR_RESET;
        end if;
        assert ( DONE = (DONE'range => '1') ) severity error;
        wait;
    end process;

end architecture;

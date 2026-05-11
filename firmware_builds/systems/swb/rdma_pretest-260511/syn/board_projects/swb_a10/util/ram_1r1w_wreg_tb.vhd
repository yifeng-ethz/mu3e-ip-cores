--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram_1r1w_wreg_tb is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 1000.0--;
);
end entity;

architecture arch of ram_1r1w_wreg_tb is

    signal clk : std_logic := '1';
    signal reset_n : std_logic := '0';
    signal cycle : integer := 0;
    signal err : std_logic;

    shared variable rng : work.sim.rng_lfsr32_t;
    signal DONE : std_logic_vector(0 downto 0) := (others => '0');

    signal waddr, raddr, raddr_q : std_logic_vector(1 downto 0);
    signal wdata, dut_rdata, ram_rdata : std_logic_vector(3 downto 0);
    signal we : std_logic;

    type ram_t is array (natural range <>) of std_logic_vector(wdata'range);
    signal ram : ram_t(2**waddr'length-1 downto 0);

begin

    clk <= not clk after (0.5 us / g_CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / g_CLK_MHZ);
    cycle <= cycle + 1 after (1 us / g_CLK_MHZ);

    e_dut : entity work.ram_1r1w_wreg
    generic map (
        g_ADDR_WIDTH => waddr'length,
        g_DATA_WIDTH => wdata'length,
        g_WREG_N => 2--,
    )
    port map (
        i_waddr     => waddr,
        i_wdata     => wdata,
        i_we        => we,

        i_raddr     => raddr,
        o_rdata     => dut_rdata,

        i_clk       => clk--,
    );

    -- ram
    process(clk)
    begin
    if rising_edge(clk) then
        if ( we = '1' ) then
            ram(to_integer(unsigned(waddr))) <= wdata;
        end if;
        ram_rdata <= ram(to_integer(unsigned(raddr)));
        if ( we = '1' and waddr = raddr ) then
            -- read during write
            ram_rdata <= wdata;
        end if;
    end if;
    end process;

    err <= work.util.to_std_logic( to_string(dut_rdata) /= to_string(ram_rdata) );

    process(clk, reset_n)
        variable v_err : std_logic := '0';
    begin
    if ( reset_n /= '1' ) then
        waddr <= (others => '0');
        wdata <= (others => '0');
        we <= '0';
        raddr <= (others => '0');
        raddr_q <= (others => '0');
        --
    elsif rising_edge(clk) then
        waddr <= rng.random(waddr'length);
        wdata <= rng.random(wdata'length);
        we <= rng.random;
        raddr <= rng.random(raddr'length);
        raddr_q <= raddr;

        -- check
        assert ( err = '0' )
            report "E [tb]"
               & ", raddr = " & work.util.to_hstring(raddr_q)
               & ", dut_rdata = " & work.util.to_hstring(dut_rdata)
               & ", ram_rdata = " & work.util.to_hstring(ram_rdata)
            severity error;

        v_err := v_err or err;
        if ( cycle = integer(real(g_STOP_TIME_US)*g_CLK_MHZ)-1 and v_err = '0' ) then
            DONE(0) <= '1';
        end if;
    end if;
    end process;

    process
    begin
        rng.init(g_SEED);
        wait for g_STOP_TIME_US * 1 us;
        if ( and DONE ) then
            report work.util.SGR_FG_GREEN & "I [tb] DONE" & work.util.SGR_RESET;
        else
            report work.util.SGR_FG_RED & "E [tb] NOT DONE" & work.util.SGR_RESET;
        end if;
        assert ( and DONE ) severity error;
        wait;
    end process;

end architecture;

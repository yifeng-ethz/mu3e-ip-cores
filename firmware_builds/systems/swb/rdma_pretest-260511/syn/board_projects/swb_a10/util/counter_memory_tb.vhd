--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity counter_memory_tb is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 1000.0--;
);
end entity;

architecture arch of counter_memory_tb is

    signal clk : std_logic := '1';
    signal reset_n : std_logic := '0';
    signal cycle : integer := 0;
    signal err : std_logic;

    shared variable rng : work.sim.rng_lfsr32_t;
    signal DONE : std_logic_vector(0 downto 0) := (others => '0');

    signal waddr, raddr, raddr_q : std_logic_vector(1 downto 0) := (others => '0');
    signal wdata, dut_rdata, ram_rdata : std_logic_vector(7 downto 0) := (others => '0');
    signal rdata_prev, wdata_prev : std_logic_vector(wdata'range) := (others => '0');
    signal we, ready : std_logic;
    signal wmode : std_logic_vector(3 downto 0);

    type ram_t is array (natural range <>) of std_logic_vector(wdata'range);
    signal ram : ram_t(2**waddr'length-1 downto 0) := (others => (others => '0'));

begin

    clk <= not clk after (0.5 us / g_CLK_MHZ);
    reset_n <= '0' when ( cycle < 4 ) else '1';
    cycle <= cycle + 1 after (1 us / g_CLK_MHZ);

    e_dut : entity work.counter_memory
    generic map (
        g_ADDR_WIDTH => waddr'length,
        g_DATA_WIDTH => wdata'length,
        g_OVERFLOW => true,
        g_RDW_X => false--,
    )
    port map (
        i_waddr => waddr,
        i_wdata => wdata,
        i_we => we,
        i_wmode => wmode,

        o_wdata_prev => wdata_prev,
        o_rdata_prev => rdata_prev,
        i_wdata_new => wdata_prev + rdata_prev,

        i_raddr => raddr,
        o_rdata => dut_rdata,

        o_ready => ready,
        i_reset_n => reset_n,
        i_clk => clk--,
    );

    -- ram
    process(clk)
        variable v_wdata : std_logic_vector(wdata'range);
    begin
    if ( reset_n /= '1' ) then
        --
    elsif rising_edge(clk) then
        v_wdata := wdata;
        if ( wmode = X"1" ) then
            v_wdata := ram(to_integer(unsigned(waddr))) + wdata;
        end if;
        if ( wmode = X"F" ) then
            v_wdata := ram(to_integer(unsigned(waddr))) + wdata;
        end if;

        if ( we = '1' ) then
            ram(to_integer(unsigned(waddr))) <= v_wdata;
        end if;
        ram_rdata <= ram(to_integer(unsigned(raddr)));
        if ( we = '1' and waddr = raddr ) then
            -- read during write
            ram_rdata <= v_wdata;
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
        wmode <= (others => '0');
        raddr <= (others => '0');
        raddr_q <= (others => '0');
        --
    elsif rising_edge(clk) and ready = '1' then
        waddr <= rng.random(waddr'length);
        wdata <= rng.random(wdata'length);
        we <= rng.random;
        wmode <= X"0" when ( rng.random(3) = 0 ) else X"F";
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

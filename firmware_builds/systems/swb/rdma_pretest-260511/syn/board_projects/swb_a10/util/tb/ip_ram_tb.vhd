--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ip_ram_tb is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 1000.0;
    g_PWD : string := "."--;
);
end entity;

architecture arch of ip_ram_tb is

    signal clk : std_logic := '1';
    signal reset_n : std_logic := '0';
    signal cycle : integer := 0;

    shared variable rng : work.sim.rng_lfsr32_t;
    signal DONE : std_logic_vector(0 downto 0);

    signal addr : std_logic_vector(3 downto 0) := (others => '0');
    signal wdata, rdata : std_logic_vector(3 downto 0) := (others => '0');
    signal we, rvalid, re : std_logic := '0';

    -- ...
    type ram_t is array (natural range <>) of std_logic_vector(wdata'range);
    signal ram : ram_t(2**addr'length-1 downto 0);

begin

    clk <= not clk after (0.5 us / g_CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / g_CLK_MHZ);
    cycle <= cycle + 1 after (1 us / g_CLK_MHZ);

    e_ram : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => 4,
        g_DATA0_WIDTH => 4,
        g_ADDR1_WIDTH => 4,
        g_DATA1_WIDTH => 4,
        g_INIT_FILE => g_PWD & "/ip_ram_tb.mif"--,
    )
    port map (
        i_addr0     => addr,
        i_we0       => we,
        i_wdata0    => wdata,
        i_re0       => re,
        o_rvalid0   => rvalid,
        o_rdata0    => rdata,
        i_clk0      => clk,

        i_addr1     => addr,
        i_we1       => '0',
        i_wdata1    => (others => '-'),
        o_rdata1    => open,
        i_clk1      => clk--,
    );


    process begin
        wait until rising_edge(reset_n);
        wait until rising_edge(clk);

        -- test mif
        for i in 0 to 2**addr'length-1 loop
            addr <= std_logic_vector(to_unsigned(i, addr'length));
            re <= '1';
            wait until rising_edge(clk);
            re <= '0';
            if ( rvalid = '0' ) then
                wait until rising_edge(clk) and rvalid = '1';
            end if;

            if ( rdata /= addr ) then
                report "E [tb@" & integer'image(cycle) & "] "
                & "addr = 0x" & work.util.to_hstring(addr)
                & ", rdata = 0x" & work.util.to_hstring(rdata) & " /= 0x" & work.util.to_hstring(addr)
                severity error;
            end if;
            assert rdata = addr severity error;
        end loop;

        -- test random idle/write/read cycles
        for i in 0 to g_STOP_TIME_US*integer(g_CLK_MHZ)/2 loop
            addr <= (others => '0');
            wdata <= (others => '-');
            we <= '0';
            re <= '0';

            if ( rng.random = '0' ) then
                wait until rising_edge(clk);
                -- idle
            elsif ( rng.random = '0' ) then
                -- write
                addr <= rng.random(addr'length);
                wdata <= rng.random(wdata'length);
                we <= '1';
                wait until rising_edge(clk);
                wdata <= (others => '-');
                we <= '0';

                ram(to_integer(unsigned(addr))) <= wdata;
            else
                -- read
                addr <= rng.random(addr'length);
                re <= '1';
                wait until rising_edge(clk);
                re <= '0';
                if ( rvalid = '0' ) then
                    wait until rising_edge(clk) and rvalid = '1';
                end if;

                assert is_X(ram(to_integer(unsigned(addr))))
                    or rdata = ram(to_integer(unsigned(addr)))
                severity error;
            end if;

        end loop;

        DONE(0) <= '1';
        wait;
    end process;

    -- INIT and DONE
    process begin
        rng.init(g_SEED);
        wait until ( and DONE );
        report work.util.SGR_FG_GREEN & "I [tb] SIMULATION DONE" & work.util.SGR_RESET;
        wait;
    end process;

    -- NOT DONE
    process begin
        wait for g_STOP_TIME_US * 1 us;
        assert ( and DONE )
            report work.util.SGR_FG_RED & "E [tb] SIMULATION NOT DONE" & work.util.SGR_RESET
            severity error;
        wait;
    end process;

end architecture;

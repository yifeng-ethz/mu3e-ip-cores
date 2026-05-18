--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

use work.util_slv.all;

entity tb_spi is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 1000.0--;
);
end entity;

architecture arch of tb_spi is

    signal clk, reset_n : std_logic := '0';
    signal cycle : integer := 0;

    signal DONE : std_logic_vector(0 downto 0) := (others => '0');

    signal prbs : slv32_array_t(0 to 15);

    signal wdata, rdata : std_logic_vector(7 downto 0);
    signal we, wfull, rack, rempty : std_logic := '0';

    signal sdo, sdi : std_logic;

begin

    clk <= not clk after (0.5 us / g_CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / g_CLK_MHZ);
    cycle <= cycle + 1 after (1 us / g_CLK_MHZ);

    process
        variable lfsr : std_logic_vector(31 downto 0);
    begin
        lfsr := std_logic_vector(to_signed(g_SEED, lfsr'length));
        for i in prbs'range loop
            for j in prbs(0)'range loop
                lfsr := lfsr sll 1;
                lfsr(0) := xor_reduce(lfsr and "10000000001000000000000000000011");
                prbs(i)(j) <= lfsr(0);
            end loop;
        end loop;
        wait;
    end process;

    e_spi_master : entity work.spi_master
    port map (
        o_sclk => open,
        o_sdo => sdo,
        i_sdi => sdi,
        o_ss_n => open,

        i_wdata => wdata,
        i_we => we,
        o_wfull => wfull,

        o_rdata => rdata,
        i_rack => rack,
        o_rempty => rempty,

        i_sclk_div => X"0010",
        i_cpol => '0',
        i_sdo_cpha => '0',
        i_sdi_cpha => '0',

        i_reset_n => reset_n,
        i_clk => clk--,
    );

    sdi <= sdo;

    process
    begin
        wait until rising_edge(reset_n);

        wait until rising_edge(clk);
        we <= '0';

        wait until rising_edge(clk);
        wdata <= prbs(0)(7 downto 0);
        we <= '1';

        wait until rising_edge(clk);
        we <= '0';

        wait until rising_edge(clk);
        wdata <= prbs(1)(7 downto 0);
        we <= '1';

        wait until rising_edge(clk);
        we <= '0';

        wait until rising_edge(clk) and rempty = '0';
        assert ( rdata = prbs(0)(7 downto 0) ) report work.util.sgr(31) & "ERROR @ cycle = " & integer'image(cycle) & work.util.sgr(0) severity error;
        rack <= '1';

        wait until rising_edge(clk);
        rack <= '0';

        wait until rising_edge(clk) and rempty = '0';
        assert ( rdata = prbs(1)(7 downto 0) ) report work.util.sgr(31) & "ERROR @ cycle = " & integer'image(cycle) & work.util.sgr(0) severity error;
        rack <= '1';

        wait until rising_edge(clk);
        rack <= '0';

        DONE(0) <= '1';

        wait;
    end process;

    process
    begin
        wait for g_STOP_TIME_US * 1 us;
        if ( and DONE ) then
            report work.util.sgr(32) & "DONE" & work.util.sgr(0);
        else
            report work.util.sgr(31) & "NOT DONE" & work.util.sgr(0);
        end if;
        assert ( and DONE ) severity error;
        wait;
    end process;

end architecture;

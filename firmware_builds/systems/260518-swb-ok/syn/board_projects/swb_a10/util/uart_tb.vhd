--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- <https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter>
entity uart_tb is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 100.0--;
);
end entity;

architecture arch of uart_tb is

    constant CLK_MHZ : real := 1000.0; -- MHz
    signal clk, reset_n, reset : std_logic := '0';

    constant BAUD_RATE : positive := positive(CLK_MHZ * 1000000.0 / 10.0);

    type data_t is array (natural range <>) of std_logic_vector(8 downto 0);
    signal data : data_t(15 downto 0) := (
        '0' & X"cd",
        '0' & X"77",
        '0' & X"fe",
        '0' & X"8e",
        '0' & X"33",
        '0' & X"43",
        '0' & X"3e",
        '0' & X"7d",
        '0' & X"65",
        '0' & X"f3",
        '0' & X"0c",
        '0' & X"9e",
        '0' & X"76",
        '0' & X"bd",
        '0' & X"d1",
        '0' & X"f3",
        others => (others => '0')
    );

    signal serial : std_logic;

    signal wdata : std_logic_vector(8 downto 0);
    signal we, wfull : std_logic;

    signal rdata : std_logic_vector(8 downto 0);
    signal rempty, rack : std_logic;

    signal DONE : std_logic_vector(1 downto 0) := (others => '0');

begin

    clk <= not clk after (0.5 us / CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / CLK_MHZ);
    reset <= not reset_n;

    e_uart_tx : entity work.uart_tx
    generic map (
        g_DATA_BITS => 9,
        g_BAUD_RATE => BAUD_RATE,
        g_CLK_MHZ => CLK_MHZ--,
    )
    port map (
        o_data          => serial,

        i_wdata         => wdata,
        i_we            => we,
        o_wfull         => wfull,

        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

    e_uart_rx : entity work.uart_rx
    generic map (
        g_DATA_BITS => 9,
        g_BAUD_RATE => BAUD_RATE,
        g_CLK_MHZ => CLK_MHZ--,
    )
    port map (
        i_data          => serial,

        o_rdata         => rdata,
        o_rempty        => rempty,
        i_rack          => rack,

        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

    process
    begin
        we <= '0';
        wait until rising_edge(reset_n);

        for i in data'range loop
            wait until rising_edge(clk) and wfull = '0';
            wdata <= data(i);
            we <= '1';

            wait until rising_edge(clk);
            we <= '0';
        end loop;

        DONE(0) <= '1';
        wait;
    end process;

    process
    begin
        rack <= '0';
        wait until rising_edge(reset_n);

        for i in data'range loop
            wait until rising_edge(clk) and rempty = '0';
            report "rdata = " & work.util.to_hstring(rdata);
            assert ( data(i) = rdata ) severity error;
            rack <= '1';

            wait until rising_edge(clk);
            rack <= '0';
        end loop;

        DONE(1) <= '1';
        wait;
    end process;

    process
    begin
        wait for 4000 ns;
        assert ( and DONE ) severity failure;
        wait;
    end process;

end architecture;

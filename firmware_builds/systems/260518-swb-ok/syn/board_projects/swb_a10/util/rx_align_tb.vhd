--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity rx_align_tb is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 100.0--;
);
end entity;

architecture arch of rx_align_tb is

    signal clk : std_logic := '1';
    signal reset_n : std_logic := '0';
    signal cycle : integer := 0;

    shared variable rng : work.sim.rng_lfsr32_t;
    signal DONE : std_logic_vector(1 downto 0) := (others => '0');

    signal enc_data : std_logic_vector(7 downto 0);
    signal enc_datak : std_logic_vector(0 downto 0);

    signal enc_data10, dec_data10 : std_logic_vector(9 downto 0);
    signal data10_shift : integer range 0 to 9 := 0;

    signal dec_data : std_logic_vector(7 downto 0);
    signal dec_datak : std_logic_vector(0 downto 0);
    signal dec_error : std_logic;

    signal data : std_logic_vector(7 downto 0);
    signal locked : std_logic;
    signal bitslip : std_logic;

begin

    clk <= not clk after (0.5 us / g_CLK_MHZ);
    reset_n <= '0' when ( cycle < 4 ) else '1';
    cycle <= cycle + 1 after (1 us / g_CLK_MHZ);

    -- generate RX data
    process(clk)
        variable data : std_logic_vector(7 downto 0);
    begin
    if rising_edge(clk) then
        data := rng.random(8);
        enc_data <= data;
        enc_datak <= (others => '0');
        -- generate K (alignment pattern)
        if ( data = X"BC" and rng.random(2) = 0 ) then
            enc_datak(0) <= '1';
        end if;
    end if;
    end process;

    e_enc_8b10b : entity work.enc_8b10b_n
    generic map (
        g_BYTES => 1--,
    )
    port map (
        i_data      => enc_data,
        i_datak     => enc_datak,

        o_data      => enc_data10,
        o_err       => open,

        i_reset_n   => reset_n,
        i_clk       => clk--,
    );

    -- generate line (RX->TX) errors
    process(enc_data10)
    begin
        dec_data10 <= enc_data10;
        -- 1 bit flip with probability 10/1024
        dec_data10 <= enc_data10 xor work.util.shift_left("0000000001", to_integer(unsigned(rng.random(10))));
    end process;

    e_dec_8b10b : entity work.dec_8b10b_n
    generic map (
        g_BYTES => 1--,
    )
    port map (
        i_data      => work.util.rotate_left(dec_data10, data10_shift),

        o_data      => dec_data,
        o_datak     => dec_datak,
        o_err       => dec_error,

        i_reset_n   => reset_n,
        i_clk       => clk--,
    );

    -- report K bytes
    process(clk)
        variable n_K : integer := 0;
    begin
    if rising_edge(clk) then
        if ( is_x(dec_datak & dec_data) ) then
            --
        elsif ( dec_datak & dec_data = '1' & X"BC" ) then
            n_K := n_K + 1;
            --report "I [tb] "
            --    & "n_K = " & integer'image(n_K)
            --    & " @ cycle " & integer'image(cycle);
        end if;
    end if;
    end process;

    process(all)
    begin
    -- generate random non-zero TX bitslip
    if ( falling_edge(clk) and cycle mod integer(real(g_STOP_TIME_US)*g_CLK_MHZ/2.0) = 1 ) then
        data10_shift <= 1 + 9 * to_integer(unsigned(rng.random(10))) / 1024;
    end if;
    -- do TX bitslip
    if rising_edge(bitslip) then
        data10_shift <= (data10_shift + 1) mod 10;
    end if;
    end process;

    e_rx_align : entity work.rx_align
    generic map (
        g_BYTES => 1,
        g_K => ( 0 => work.util.K28_5, 1 => work.util.K28_1 )--,
    )
    port map (
        o_data      => data,
        o_locked    => locked,

        o_bitslip   => bitslip,

        i_data      => dec_data,
        i_datak     => dec_datak,
        i_error     => dec_error,

        i_reset_n   => reset_n,
        i_clk       => clk--,
    );

    process begin
        wait until rising_edge(reset_n);

        wait until rising_edge(locked);
        report "I [tb] locked @ cycle " & integer'image(cycle);
        DONE(0) <= '1';

        wait until rising_edge(locked);
        report "I [tb] locked @ cycle " & integer'image(cycle);
        DONE(1) <= '1';

        wait;
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

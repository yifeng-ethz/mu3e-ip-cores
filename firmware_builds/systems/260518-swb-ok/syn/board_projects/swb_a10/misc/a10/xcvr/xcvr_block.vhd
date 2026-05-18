--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

-- generate g_XCVR_N transceivers each with g_CHANNELS rx/tx channels
-- and map them to one combined interface
entity xcvr_block is
generic (
    g_MODE : string := "std";
    g_XCVR_N : positive := 8; -- g_XCVR_N <= 16
    g_CHANNELS : positive := 6;
    g_REFCLK_MHZ : real;
    g_RATE_MBPS : positive;
    g_CLK_MHZ : real--;
);
port (
    i_rx_serial         : in    std_logic_vector(g_XCVR_N*g_CHANNELS-1 downto 0);
    o_tx_serial         : out   std_logic_vector(g_XCVR_N*g_CHANNELS-1 downto 0);

    i_refclk            : in    std_logic_vector(g_XCVR_N-1 downto 0);

    -- 8b data
    o_rx_data           : out   slv32_array_t(g_XCVR_N*g_CHANNELS-1 downto 0);
    o_rx_datak          : out   slv4_array_t(g_XCVR_N*g_CHANNELS-1 downto 0);
    i_tx_data           : in    slv32_array_t(g_XCVR_N*g_CHANNELS-1 downto 0);
    i_tx_datak          : in    slv4_array_t(g_XCVR_N*g_CHANNELS-1 downto 0);

    -- 10b bypass
    i_tx_mux10          : in    std_logic_vector(g_XCVR_N*g_CHANNELS-1 downto 0) := (others => '0');
    -- 10b (8b10b encoded) data
    i_tx_data10         : in    slv40_array_t(g_XCVR_N*g_CHANNELS-1 downto 0) := (others => (others => '0'));

    o_rx_clk            : out   std_logic_vector(g_XCVR_N*g_CHANNELS-1 downto 0);
    i_rx_clk            : in    std_logic_vector(g_XCVR_N*g_CHANNELS-1 downto 0);
    o_tx_clk            : out   std_logic_vector(g_XCVR_N*g_CHANNELS-1 downto 0);
    i_tx_clk            : in    std_logic_vector(g_XCVR_N*g_CHANNELS-1 downto 0);

    o_rx_error          : out   std_logic_vector(g_XCVR_N*g_CHANNELS-1 downto 0);
    o_rx_locked         : out   std_logic_vector(g_XCVR_N*g_CHANNELS-1 downto 0);
    o_rx_LoL_cnt        : out   work.util_slv.slv8_array_t(g_XCVR_N*g_CHANNELS-1 downto 0);
    o_rx_err_cnt        : out   work.util_slv.slv16_array_t(g_XCVR_N*g_CHANNELS-1 downto 0);

    -- avalon slave interface
    -- # address units words
    -- # read latency 0
    -- address:
    -- # (17 downto 14) select transceiver (from 0 to 15)
    -- # (13 downto 0) avalon interface of selected transceiver
    i_avs_address       : in    std_logic_vector(17 downto 0);
    i_avs_read          : in    std_logic;
    o_avs_readdata      : out   std_logic_vector(31 downto 0);
    i_avs_write         : in    std_logic;
    i_avs_writedata     : in    std_logic_vector(31 downto 0);
    o_avs_waitrequest   : out   std_logic;

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture arch of xcvr_block is

    signal avs_waitrequest : std_logic;
    signal av : work.util.avmm_array_t(g_XCVR_N-1 downto 0);
    -- chip select
    signal cs : integer;
    signal timeout : unsigned(7 downto 0);

begin

    assert ( true
        and ( g_XCVR_N <= 16 )
    ) severity failure;

    generate_xcvr : for i in 0 to g_XCVR_N-1 generate
        signal rx_data, tx_data : std_logic_vector(g_CHANNELS*32-1 downto 0);
        signal rx_datak, tx_datak : std_logic_vector(g_CHANNELS*4-1 downto 0);
        signal tx_data10 : std_logic_vector(g_CHANNELS*40-1 downto 0);
    begin
        generate_data : for j in 0 to g_CHANNELS-1 generate
        begin
            o_rx_data(i*g_CHANNELS+j) <= rx_data((j+1)*32-1 downto j*32);
            o_rx_datak(i*g_CHANNELS+j) <= rx_datak((j+1)*4-1 downto j*4);
            tx_data((j+1)*32-1 downto j*32) <= i_tx_data(i*g_CHANNELS+j);
            tx_datak((j+1)*4-1 downto j*4) <= i_tx_datak(i*g_CHANNELS+j);
            tx_data10((j+1)*40-1 downto j*40) <= i_tx_data10(i*g_CHANNELS+j);
        end generate;

        e_xcvr : entity work.xcvr_enh
        generic map (
            g_MODE => g_MODE,
            g_CHANNELS => g_CHANNELS,
            g_BYTES => 4,
            g_REFCLK_MHZ => g_REFCLK_MHZ,
            g_RATE_MBPS => g_RATE_MBPS,
            g_CLK_MHZ => g_CLK_MHZ--,
        )
        port map (
            i_rx_serial => i_rx_serial((i+1)*g_CHANNELS-1 downto i*g_CHANNELS),
            o_tx_serial => o_tx_serial((i+1)*g_CHANNELS-1 downto i*g_CHANNELS),

            i_refclk    => i_refclk(i),

            o_rx_data   => rx_data,
            o_rx_datak  => rx_datak,
            i_tx_data   => tx_data,
            i_tx_datak  => tx_datak,

            i_tx_mux10  => i_tx_mux10((i+1)*g_CHANNELS-1 downto i*g_CHANNELS),
            i_tx_data10 => tx_data10,

            o_rx_clkout => o_rx_clk((i+1)*g_CHANNELS-1 downto i*g_CHANNELS),
            i_rx_clkin  => i_rx_clk((i+1)*g_CHANNELS-1 downto i*g_CHANNELS),
            o_tx_clkout => o_tx_clk((i+1)*g_CHANNELS-1 downto i*g_CHANNELS),
            i_tx_clkin  => i_tx_clk((i+1)*g_CHANNELS-1 downto i*g_CHANNELS),

            o_rx_error  => o_rx_error((i+1)*g_CHANNELS-1 downto i*g_CHANNELS),
            o_rx_locked => o_rx_locked((i+1)*g_CHANNELS-1 downto i*g_CHANNELS),
            o_rx_LoL_cnt => o_rx_LoL_cnt((i+1)*g_CHANNELS-1 downto i*g_CHANNELS),
            o_rx_err_cnt => o_rx_err_cnt((i+1)*g_CHANNELS-1 downto i*g_CHANNELS),

            i_avs_address     => av(i).address(13 downto 0),
            i_avs_read        => av(i).read,
            o_avs_readdata    => av(i).readdata,
            i_avs_write       => av(i).write,
            i_avs_writedata   => av(i).writedata,
            o_avs_waitrequest => av(i).waitrequest,

            i_reset_n   => i_reset_n,
            i_clk       => i_clk--,
        );

        --
    end generate;

    o_avs_waitrequest <= avs_waitrequest;

    cs <= to_integer(unsigned(i_avs_address(i_avs_address'left downto 14)));

    -- avmm routing
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        avs_waitrequest <= '1';
        timeout <= (others => '0');
        for i in av'range loop
            av(i).read <= '0';
            av(i).write <= '0';
        end loop;
        --
    elsif rising_edge(i_clk) then
        avs_waitrequest <= '1';
        timeout <= timeout + 1;

        if ( i_avs_read = i_avs_write or avs_waitrequest = '0' ) then
            -- idle
            timeout <= (others => '0');
        elsif ( cs >= g_XCVR_N or timeout = (timeout'range => '1') ) then
            -- invalid index or timeout
            o_avs_readdata <= X"CCCCCCCC";
            avs_waitrequest <= '0';
        elsif ( av(cs).read = av(cs).write ) then
            -- start read/write request
            av(cs).address(i_avs_address'range) <= i_avs_address;
            av(cs).read <= i_avs_read;
            av(cs).write <= i_avs_write;
            av(cs).writedata <= i_avs_writedata;
        end if;

        -- check all slaves
        for i in av'range loop
            -- and stop any completed read/write request
            if ( av(i).read /= av(i).write and av(i).waitrequest = '0' ) then
                av(i).read <= '0';
                o_avs_readdata <= av(i).readdata;
                av(i).write <= '0';
                avs_waitrequest <= '0';
            end if;
        end loop;

        --
    end if;
    end process;

end architecture;

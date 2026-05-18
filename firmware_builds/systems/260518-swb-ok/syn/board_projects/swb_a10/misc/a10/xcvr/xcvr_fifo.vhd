--
-- author : Alexandr Kozlinskiy
-- date : 2021-06-08
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity xcvr_fifo is
generic (
    g_BYTES : positive := 4;
    g_IDLE_DATA : std_logic_vector := X"000000BC";
    g_IDLE_DATAK : std_logic_vector := "0001";
    g_FIFO_TX_WREG_N : natural := 1;
    g_FIFO_TX_RREG_N : natural := 1;
    g_FIFO_RX_WREG_N : natural := 1;
    g_FIFO_RX_RREG_N : natural := 1;
    g_FIFO_ADDR_WIDTH : positive := 6--;
);
port (
    i_xcvr_rx_data      : in    std_logic_vector(g_BYTES*8-1 downto 0);
    i_xcvr_rx_datak     : in    std_logic_vector(g_BYTES-1 downto 0);
    o_xcvr_tx_data      : out   std_logic_vector(g_BYTES*8-1 downto 0);
    o_xcvr_tx_datak     : out   std_logic_vector(g_BYTES-1 downto 0);
    o_xcvr_rx_wfull     : out   std_logic;
    i_xcvr_clk          : in    std_logic;

    o_rx_data           : out   std_logic_vector(g_BYTES*8-1 downto 0);
    o_rx_datak          : out   std_logic_vector(g_BYTES-1 downto 0);
    i_tx_data           : in    std_logic_vector(g_BYTES*8-1 downto 0);
    i_tx_datak          : in    std_logic_vector(g_BYTES-1 downto 0);
    o_tx_wfull          : out   std_logic;
    i_clk               : in    std_logic;

    i_reset_n           : in    std_logic--;
);
end entity;

architecture arch of xcvr_fifo is

    subtype DATA_RANGE is integer range g_BYTES*8-1 downto 0;
    subtype DATAK_RANGE is integer range g_BYTES*9-1 downto g_BYTES*8;

    signal rx_fifo_rdata, tx_fifo_rdata : std_logic_vector(g_BYTES*9-1 downto 0);
    signal rx_fifo_rempty, tx_fifo_rempty : std_logic;

begin

    assert ( true
        and ( g_IDLE_DATA'length = g_BYTES*8 )
        and ( g_IDLE_DATAK'length = g_BYTES )
    ) report "ERROR: xcvr_fifo"
        & ", g_IDLE_DATA'length = " & integer'image(g_IDLE_DATA'length)
        & ", g_IDLE_DATAK'length = " & integer'image(g_IDLE_DATAK'length)
    severity failure;

    e_rx_fifo : entity work.ip_dcfifo_v2
    generic map (
        g_ADDR_WIDTH => g_FIFO_ADDR_WIDTH,
        g_DATA_WIDTH => g_BYTES*9,
        g_WREG_N => g_FIFO_RX_WREG_N,
        g_RREG_N => g_FIFO_RX_RREG_N--,
    )
    port map (
        -- write non IDLE data/k
        i_we            => not work.util.to_std_logic(i_xcvr_rx_data = g_IDLE_DATA and i_xcvr_rx_datak = g_IDLE_DATAK),
        i_wdata         => i_xcvr_rx_datak & i_xcvr_rx_data,
        o_wfull         => o_xcvr_rx_wfull,
        i_wclk          => i_xcvr_clk,

        -- always read
        i_rack          => not rx_fifo_rempty,
        o_rdata         => rx_fifo_rdata,
        o_rempty        => rx_fifo_rempty,
        i_rclk          => i_clk,

        i_reset_n       => i_reset_n--,
    );

    -- insert IDLE when rempty
    o_rx_data <= rx_fifo_rdata(DATA_RANGE) when ( rx_fifo_rempty = '0' ) else g_IDLE_DATA;
    o_rx_datak <= rx_fifo_rdata(DATAK_RANGE) when ( rx_fifo_rempty = '0' ) else g_IDLE_DATAk;

    e_tx_fifo : entity work.ip_dcfifo_v2
    generic map (
        g_ADDR_WIDTH => g_FIFO_ADDR_WIDTH,
        g_DATA_WIDTH => g_BYTES*9,
        g_WREG_N => g_FIFO_TX_WREG_N,
        g_RREG_N => g_FIFO_TX_RREG_N--,
    )
    port map (
        -- write non IDLE data/k
        i_we            => not work.util.to_std_logic(i_tx_data = g_IDLE_DATA and i_tx_datak = g_IDLE_DATAK),
        i_wdata         => i_tx_datak & i_tx_data,
        o_wfull         => o_tx_wfull,
        i_wclk          => i_clk,

        -- always read
        i_rack          => not tx_fifo_rempty,
        o_rdata         => tx_fifo_rdata,
        o_rempty        => tx_fifo_rempty,
        i_rclk          => i_xcvr_clk,

        i_reset_n       => i_reset_n--,
    );

    -- insert IDLE when rempty
    o_xcvr_tx_data <= tx_fifo_rdata(DATA_RANGE) when ( tx_fifo_rempty = '0' ) else g_IDLE_DATA;
    o_xcvr_tx_datak <= tx_fifo_rdata(DATAK_RANGE) when ( tx_fifo_rempty = '0' ) else g_IDLE_DATAk;

end architecture;

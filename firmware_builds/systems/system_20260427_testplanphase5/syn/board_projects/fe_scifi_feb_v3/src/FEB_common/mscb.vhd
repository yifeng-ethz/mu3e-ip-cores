library ieee;
use ieee.std_logic_1164.all;

entity mscb is
generic (
    g_BAUD_RATE : positive := 115200;
    g_CLK_MHZ   : real--;
);
port (
    -- avalon slave interface
    -- - read latency 1
    i_avs_address       : in    std_logic_vector(3 downto 0);
    i_avs_read          : in    std_logic;
    o_avs_readdata      : out   std_logic_vector(31 downto 0);
    i_avs_write         : in    std_logic;
    i_avs_writedata     : in    std_logic_vector(31 downto 0);
    o_avs_waitrequest   : out   std_logic;

    i_rx_data           : in    std_logic;
    o_tx_data           : out   std_logic;
    o_tx_data_oe        : out   std_logic;

    o_irq               : out   std_logic;
    i_mscb_address              : in    std_logic_vector(15 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture rtl of mscb is

    signal addressing_rdata : std_logic_vector(8 downto 0);
    signal addressing_rack, addressing_rempty : std_logic;

    signal in_fifo_full :               std_logic;

    signal rx_rdata : std_logic_vector(8 downto 0);
    signal rx_rack, rx_rempty : std_logic;

    signal tx_wdata : std_logic_vector(8 downto 0);
    signal tx_we, tx_wfull : std_logic;

    signal addressing_data_out :        std_logic_vector(8 downto 0);
    signal addressing_wrreq :           std_logic;

begin

    -- memory interface
    -- - 0x00 - status register (mscb decoder rack and rempty, uart tx wfull, uart loopback)
    --   - byte 0x0 - ...
    --   - byte 0x1 - tx_wfull
    --   - byte 0x2 - rx_rempty
    --   - byte 0x3 - decoder_rempty/rack
    -- - 0x01 - write uart tx wdata
    -- - 0x02 - read uart rx rdata
    -- - 0x03 - read mscb decoder rdata
    process(i_clk)
    begin
    if rising_edge(i_clk) then
        o_avs_readdata <= X"CCCCCCCC";
        o_avs_waitrequest <= '0';

        if ( i_avs_address = X"0" and i_avs_read = '1' ) then
            o_avs_readdata <= (others => '0');
            o_avs_readdata(8) <= tx_wfull;
            o_avs_readdata(16) <= rx_rempty;
            o_avs_readdata(24) <= addressing_rempty;
        end if;
        addressing_rack <= '0';
        if ( i_avs_address = X"0" and i_avs_write = '1' ) then
            addressing_rack <= i_avs_writedata(24);
        end if;

        -- uart tx wdata
        tx_we <= '0';
        if ( i_avs_address = X"1" and i_avs_write = '1' ) then
            tx_we <= '1';
            tx_wdata <= i_avs_writedata(tx_wdata'range);
        end if;

        -- uart rx rdata
        if ( i_avs_address = X"2" and i_avs_read = '1' ) then
            o_avs_readdata <= (others => '0');
            o_avs_readdata(rx_rdata'range) <= rx_rdata;
        end if;

        -- mscb decoder rdata
        if ( i_avs_address = X"3" and i_avs_read = '1' ) then
            o_avs_readdata <= (others => '0');
            o_avs_readdata(addressing_rdata'range) <= addressing_rdata;
        end if;

        --
    end if;
    end process;

    o_irq <= not addressing_rempty;

    e_uart_rx : entity work.uart_rx
    generic map (
        g_DATA_BITS => 9,
        g_BAUD_RATE => g_BAUD_RATE,
        g_CLK_MHZ   => g_CLK_MHZ--,
    )
    port map (
        i_data          => i_rx_data,

        o_rdata         => rx_rdata,
        i_rack          => rx_rack,
        o_rempty        => rx_rempty,

        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    -- fifo addressing to nios (addressing is done, only commands intended for this mscb node)
    e_nios_fifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 8,
        g_DATA_WIDTH => 9,
        g_SHOWAHEAD => "OFF",
        g_LPM_HINT => "RAM_BLOCK_TYPE=MLAB"--,
    )
    port map (
        i_we        => addressing_wrreq,
        i_wdata     => addressing_data_out,
        o_wfull     => in_fifo_full,

        i_rack      => addressing_rack,
        o_rdata     => addressing_rdata,
        o_rempty    => addressing_rempty,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    e_uart_tx : entity work.uart_tx
    generic map (
        g_DATA_BITS => 9,
        g_BAUD_RATE => g_BAUD_RATE,
        g_CLK_MHZ   => g_CLK_MHZ--,
    )
    port map (
        o_data          => o_tx_data,
        o_data_oe       => o_tx_data_oe,

        i_wdata         => tx_wdata,
        i_we            => tx_we,
        o_wfull         => tx_wfull,

        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    e_mscb_addressing : entity work.mscb_addressing
    port map (
        i_data          => rx_rdata,
        o_rdreq         => rx_rack,
        i_empty         => rx_rempty,

        o_data          => addressing_data_out,
        o_wrreq         => addressing_wrreq,

        i_address       => i_mscb_address,

        i_reset         => not i_reset_n,
        i_clk           => i_clk--,
    );

end architecture;

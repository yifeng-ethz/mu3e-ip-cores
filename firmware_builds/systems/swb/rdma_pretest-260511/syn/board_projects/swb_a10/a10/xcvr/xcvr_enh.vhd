--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity xcvr_enh is
generic (
    g_MODE : string := "std";
    g_CHANNELS : positive := 4;
    g_BYTES : positive := 4;
    g_K : std_logic_vector(7 downto 0) := work.util.D28_5;
    g_REFCLK_MHZ : real;
    g_RATE_MBPS : positive;
    g_CLK_MHZ : real--;
);
port (
    i_rx_serial         : in    std_logic_vector(g_CHANNELS-1 downto 0);
    o_tx_serial         : out   std_logic_vector(g_CHANNELS-1 downto 0);

    i_refclk            : in    std_logic;

    o_rx_data           : out   std_logic_vector(g_CHANNELS*g_BYTES*8-1 downto 0);
    o_rx_datak          : out   std_logic_vector(g_CHANNELS*g_BYTES-1 downto 0);
    i_tx_data           : in    std_logic_vector(g_CHANNELS*g_BYTES*8-1 downto 0);
    i_tx_datak          : in    std_logic_vector(g_CHANNELS*g_BYTES-1 downto 0);

    -- 8b10b bypass
    i_tx_mux10          : in    std_logic_vector(g_CHANNELS-1 downto 0) := (others => '0');
    -- 8b10b encoded data
    i_tx_data10         : in    std_logic_vector(g_CHANNELS*g_BYTES*10-1 downto 0) := (others => '0');

    o_rx_clkout         : out   std_logic_vector(g_CHANNELS-1 downto 0);
    i_rx_clkin          : in    std_logic_vector(g_CHANNELS-1 downto 0);
    o_tx_clkout         : out   std_logic_vector(g_CHANNELS-1 downto 0);
    i_tx_clkin          : in    std_logic_vector(g_CHANNELS-1 downto 0);

    o_rx_error          : out   std_logic_vector(g_CHANNELS-1 downto 0);
    o_rx_locked         : out   std_logic_vector(g_CHANNELS-1 downto 0);
    o_rx_LoL_cnt        : out   work.util_slv.slv8_array_t(g_CHANNELS-1 downto 0);
    o_rx_err_cnt        : out   work.util_slv.slv16_array_t(g_CHANNELS-1 downto 0);

    -- avalon slave interface
    -- # address units words
    -- # read latency 0
    i_avs_address       : in    std_logic_vector(13 downto 0) := (others => '0');
    i_avs_read          : in    std_logic := '0';
    o_avs_readdata      : out   std_logic_vector(31 downto 0);
    i_avs_write         : in    std_logic := '0';
    i_avs_writedata     : in    std_logic_vector(31 downto 0) := (others => '0');
    o_avs_waitrequest   : out   std_logic;

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture arch of xcvr_enh is

    signal ch : integer range 0 to g_CHANNELS-1 := 0;

    signal av_ctrl : work.util.avalon_t;
    signal av_phy, av_pll : work.util.avalon_t;

    signal rx_parallel_data     :   std_logic_vector(g_CHANNELS*g_BYTES*10-1 downto 0);
    signal tx_parallel_data     :   std_logic_vector(g_CHANNELS*g_BYTES*10-1 downto 0);

    signal tx_reset_n           :   std_logic_vector(g_CHANNELS-1 downto 0);
    signal rx_reset_n           :   std_logic_vector(g_CHANNELS-1 downto 0);

    signal tx_analogreset       :   std_logic_vector(g_CHANNELS-1 downto 0);
    signal tx_digitalreset      :   std_logic_vector(g_CHANNELS-1 downto 0);
    signal rx_analogreset       :   std_logic_vector(g_CHANNELS-1 downto 0);
    signal rx_digitalreset      :   std_logic_vector(g_CHANNELS-1 downto 0);

    signal tx_fifo_error        :   std_logic_vector(g_CHANNELS-1 downto 0);
    signal rx_fifo_error        :   std_logic_vector(g_CHANNELS-1 downto 0);

    signal tx_ready             :   std_logic_vector(g_CHANNELS-1 downto 0);
    signal rx_ready             :   std_logic_vector(g_CHANNELS-1 downto 0);
    signal rx_is_lockedtoref    :   std_logic_vector(g_CHANNELS-1 downto 0);
    signal rx_is_lockedtodata   :   std_logic_vector(g_CHANNELS-1 downto 0);

    signal rx_bitslip           :   std_logic_vector(g_CHANNELS-1 downto 0);

    signal rx_loopback          :   std_logic_vector(g_CHANNELS-1 downto 0);



    type rx_t is record
        -- parallel 10-bit data
        data10  :   std_logic_vector(g_BYTES*10-1 downto 0);
        -- 8b10b decoded data
        idata   :   std_logic_vector(g_BYTES*8-1 downto 0);
        idatak  :   std_logic_vector(g_BYTES-1 downto 0);
        error   :   std_logic;

        -- aligned data
        data    :   std_logic_vector(g_BYTES*8-1 downto 0);
        datak   :   std_logic_vector(g_BYTES-1 downto 0);
        locked  :   std_logic;

        reset_n :   std_logic;

        -- Gbit counter
        Gbit    :   std_logic_vector(23 downto 0);
        -- loss-of-lock counter
        LoL_cnt :   std_logic_vector(7 downto 0);
        -- error counter
        err_cnt :   std_logic_vector(15 downto 0);
    end record;
    type rx_vector_t is array (natural range <>) of rx_t;
    signal rx : rx_vector_t(g_CHANNELS-1 downto 0) := (others => (
        error => '0',
        locked => '0',
        reset_n => '0',
        others => (others => '0')
    ));

begin

    g_rx : for i in g_CHANNELS-1 downto 0 generate
        signal tx_data10 : std_logic_vector(g_BYTES*10-1 downto 0);
    begin
        rx(i).data10 <= rx_parallel_data(g_BYTES*10-1 + g_BYTES*10*i downto g_BYTES*10*i);
        o_rx_data(g_BYTES*8-1 + g_BYTES*8*i downto g_BYTES*8*i) <= rx(i).data;
        o_rx_datak(g_BYTES-1 + g_BYTES*i downto g_BYTES*i) <= rx(i).datak;

        e_rx_8b10b_dec : entity work.dec_8b10b_n
        generic map (
            g_BYTES => g_BYTES--,
        )
        port map (
            i_data => rx(i).data10,
            o_data => rx(i).idata,
            o_datak => rx(i).idatak,
            o_err => rx(i).error,
            i_reset_n => '1',
            i_clk => i_rx_clkin(i)--,
        );

        e_tx_8b10b_enc : entity work.enc_8b10b_n
        generic map (
            g_BYTES => g_BYTES--,
        )
        port map (
            i_data => i_tx_data(g_BYTES*8-1 + g_BYTES*8*i downto g_BYTES*8*i),
            i_datak => i_tx_datak(g_BYTES-1 + g_BYTES*i downto g_BYTES*i),
            o_data => tx_data10,
            o_err => open,
            i_reset_n => '1',
            i_clk => i_tx_clkin(i)--,
        );

        tx_parallel_data(g_BYTES*10*(i+1)-1 downto g_BYTES*10*i) <=
            tx_data10 when ( i_tx_mux10(i) = '0' ) else
            i_tx_data10(g_BYTES*10*(i+1)-1 downto g_BYTES*10*i);

        e_rx_reset_n : entity work.reset_sync
        port map ( i_areset_n => i_reset_n and rx_reset_n(i), o_reset_n => rx(i).reset_n, i_clk => i_rx_clkin(i) );

        e_rx_align : entity work.rx_align
        generic map (
            g_BYTES => g_BYTES,
            g_K => ( 0 => g_K )--,
        )
        port map (
            o_data      => rx(i).data,
            o_datak     => rx(i).datak,
            o_locked    => rx(i).locked,

            o_bitslip   => rx_bitslip(i),

            i_data      => rx(i).idata,
            i_datak     => rx(i).idatak,
            i_error     => rx(i).error,

            i_reset_n   => rx(i).reset_n,
            i_clk       => i_rx_clkin(i)--,
        );

        -- data counter
        e_rx_Gbit : entity work.counter
        generic map ( DIV => 2**30/32, W => rx(i).Gbit'length )
        port map (
            o_cnt => rx(i).Gbit, i_ena => '1',
            i_reset_n => rx(i).reset_n, i_clk => i_rx_clkin(i)
        );

        -- Loss-of-Lock (LoL) counter
        e_rx_LoL_cnt : entity work.counter
        generic map ( W => rx(i).LoL_cnt'length, WRAP => true, EDGE => -1 ) -- falling edge
        port map (
            o_cnt => rx(i).LoL_cnt, i_ena => rx(i).locked,
            i_reset_n => rx(i).reset_n, i_clk => i_rx_clkin(i)
        );

        -- 8b10b error counter
        e_rx_err_cnt : entity work.counter
        generic map ( W => rx(i).err_cnt'length, WRAP => true )
        port map (
            o_cnt => rx(i).err_cnt,
            i_ena => rx(i).locked and rx(i).error,
            i_reset_n => rx(i).reset_n, i_clk => i_rx_clkin(i)
        );

        o_rx_error(i) <= rx(i).error;
        o_rx_locked(i) <= rx(i).locked;
        o_rx_LoL_cnt(i) <= rx(i).LoL_cnt;
        o_rx_err_cnt(i) <= rx(i).err_cnt;
    end generate;

    -- av_ctrl process, avalon interface
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        av_ctrl.waitrequest <= '1';
        ch <= 0;
        rx_loopback <= (others => '0');
        tx_reset_n <= (others => '0');
        rx_reset_n <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        av_ctrl.waitrequest <= '1';

        tx_reset_n <= (others => '1');
        rx_reset_n <= (others => '1');

        if ( av_ctrl.read /= av_ctrl.write and av_ctrl.waitrequest = '1' ) then
            av_ctrl.waitrequest <= '0';

            av_ctrl.readdata <= (others => '0');
            case av_ctrl.address(7 downto 0) is
            when X"00" =>
                -- channel select
                av_ctrl.readdata(7 downto 0) <= std_logic_vector(to_unsigned(ch, 8));
                if ( av_ctrl.write = '1' and av_ctrl.writedata(7 downto 0) < g_CHANNELS ) then
                    ch <= to_integer(unsigned(av_ctrl.writedata(7 downto 0)));
                end if;
                --
            when X"01" =>
                av_ctrl.readdata(7 downto 0) <= std_logic_vector(to_unsigned(g_CHANNELS, 8));
            when X"02" =>
                av_ctrl.readdata(7 downto 0) <= std_logic_vector(to_unsigned(g_BYTES*8, 8));
            when X"10" =>
                -- tx reset
                av_ctrl.readdata(0) <= tx_analogreset(ch);
                av_ctrl.readdata(4) <= tx_digitalreset(ch);
                if ( av_ctrl.write = '1' ) then tx_reset_n(ch) <= not av_ctrl.writedata(0); end if;
                --
            when X"11" =>
                -- tx status
                av_ctrl.readdata(0) <= tx_ready(ch);
                --
            when X"12" =>
                -- tx errors
                av_ctrl.readdata(8) <= tx_fifo_error(ch);
                --
            when X"20" =>
                -- rx reset
                av_ctrl.readdata(0) <= rx_analogreset(ch);
                av_ctrl.readdata(4) <= rx_digitalreset(ch);
                if ( av_ctrl.write = '1' ) then rx_reset_n(ch) <= not av_ctrl.writedata(0); end if;
                --
            when X"21" =>
                -- rx status
                av_ctrl.readdata(0) <= rx_ready(ch);
                av_ctrl.readdata(1) <= rx_is_lockedtoref(ch);
                av_ctrl.readdata(2) <= rx_is_lockedtodata(ch);
                av_ctrl.readdata(12) <= rx(ch).locked;
                --
            when X"22" =>
                -- rx errors
                av_ctrl.readdata(0) <= rx(ch).error;
                av_ctrl.readdata(8) <= rx_fifo_error(ch);
                --
            when X"23" =>
                av_ctrl.readdata(rx(ch).LoL_cnt'range) <= rx(ch).LoL_cnt;
            when X"24" =>
                av_ctrl.readdata(rx(ch).err_cnt'range) <= rx(ch).err_cnt;
                --
            when X"2A" =>
                av_ctrl.readdata(rx(ch).data'range) <= rx(ch).data;
            when X"2B" =>
                av_ctrl.readdata(rx(ch).datak'range) <= rx(ch).datak;
            when X"2C" =>
                av_ctrl.readdata(rx(ch).Gbit'range) <= rx(ch).Gbit;
                --
            when X"2F" =>
                av_ctrl.readdata(0) <= rx_loopback(ch);
                if ( av_ctrl.write = '1' ) then rx_loopback(ch) <= av_ctrl.writedata(0); end if;
                --
            when others =>
                av_ctrl.readdata <= X"CCCCCCCC";
                --
            end case;
        end if;

    end if; -- rising_edge
    end process;

    -- avalon control block
    -- [AK] TODO: impl as separate avalon mux entity
    block_avs : block
        signal av_ctrl_cs, av_phy_cs, av_pll_cs : std_logic;
        signal avs_waitrequest : std_logic;
    begin
        av_ctrl_cs <= '1' when ( i_avs_address(i_avs_address'left downto 8) = "000000" ) else '0';
        av_ctrl.address(i_avs_address'range) <= i_avs_address;
        av_ctrl.writedata <= i_avs_writedata;

        -- (alt_u32*)BASE + 0x1000
        av_phy_cs <= '1' when ( i_avs_address(i_avs_address'left downto 10) = "0100" ) else '0';
        av_phy.address(i_avs_address'range) <= i_avs_address;
        av_phy.writedata <= i_avs_writedata;

        -- (alt_u32*)BASE + 0x2000
        av_pll_cs <= '1' when ( i_avs_address(i_avs_address'left downto 10) = "1000" ) else '0';
        av_pll.address(i_avs_address'range) <= i_avs_address;
        av_pll.writedata <= i_avs_writedata;

        o_avs_waitrequest <= avs_waitrequest;

        process(i_clk, i_reset_n)
        begin
        if ( i_reset_n /= '1' ) then
            avs_waitrequest <= '1';
            av_ctrl.read <= '0';
            av_ctrl.write <= '0';
            av_phy.read <= '0';
            av_phy.write <= '0';
            av_pll.read <= '0';
            av_pll.write <= '0';
            --
        elsif rising_edge(i_clk) then
            avs_waitrequest <= '1';

            -- TODO: add timeout
            if ( i_avs_read = i_avs_write or avs_waitrequest = '0' ) then
                -- idle
            elsif ( av_ctrl_cs = '1' ) then
                if ( av_ctrl.read = av_ctrl.write ) then
                    -- start request
                    av_ctrl.read <= i_avs_read;
                    av_ctrl.write <= i_avs_write;
                elsif ( av_ctrl.waitrequest = '0' ) then
                    -- complete request
                    o_avs_readdata <= av_ctrl.readdata;
                    avs_waitrequest <= '0';
                    av_ctrl.read <= '0';
                    av_ctrl.write <= '0';
                end if;
            elsif ( av_phy_cs = '1' ) then
                if ( av_phy.read = av_phy.write ) then
                    av_phy.read <= i_avs_read;
                    av_phy.write <= i_avs_write;
                elsif ( av_phy.waitrequest = '0' ) then
                    o_avs_readdata <= av_phy.readdata;
                    avs_waitrequest <= '0';
                    av_phy.read <= '0';
                    av_phy.write <= '0';
                end if;
            elsif ( av_pll_cs = '1' ) then
                if ( av_pll.read = av_pll.write ) then
                    av_pll.read <= i_avs_read;
                    av_pll.write <= i_avs_write;
                elsif ( av_pll.waitrequest = '0' ) then
                    o_avs_readdata <= av_pll.readdata;
                    avs_waitrequest <= '0';
                    av_pll.read <= '0';
                    av_pll.write <= '0';
                end if;
            else
                o_avs_readdata <= X"CCCCCCCC";
                avs_waitrequest <= '0';
            end if;
            --
        end if;
        end process;
    end block;

    e_xcvr_base : entity work.xcvr_base
    generic map (
        g_MODE => g_MODE,
        g_CHANNELS => g_CHANNELS,
        g_BITS => g_BYTES * 10,
        g_REFCLK_MHZ => g_REFCLK_MHZ,
        g_RATE_MBPS => g_RATE_MBPS,
        g_CLK_MHZ => g_CLK_MHZ--,
    )
    port map (
        i_rx_serial         => i_rx_serial,
        o_tx_serial         => o_tx_serial,

        i_refclk            => i_refclk,

        o_rx_data           => rx_parallel_data,
        i_tx_data           => tx_parallel_data,

        o_rx_clkout         => o_rx_clkout,
        i_rx_clkin          => i_rx_clkin,
        o_tx_clkout         => o_tx_clkout,
        i_tx_clkin          => i_tx_clkin,

        o_rx_analogreset    => rx_analogreset,
        o_rx_digitalreset   => rx_digitalreset,
        o_tx_analogreset    => tx_analogreset,
        o_tx_digitalreset   => tx_digitalreset,
        o_rx_lockedtoref    => rx_is_lockedtoref,
        o_rx_lockedtodata   => rx_is_lockedtodata,
        o_rx_ready          => rx_ready,
        o_tx_ready          => tx_ready,

        i_rx_bitslip        => rx_bitslip,
        i_rx_seriallpbken   => rx_loopback,

        i_phy_channel       => ch,
        i_phy_address       => av_phy.address(9 downto 0),
        i_phy_read          => av_phy.read,
        o_phy_readdata      => av_phy.readdata,
        i_phy_write         => av_phy.write,
        i_phy_writedata     => av_phy.writedata,
        o_phy_waitrequest   => av_phy.waitrequest,

        i_pll_address       => av_pll.address(9 downto 0),
        i_pll_read          => av_pll.read,
        o_pll_readdata      => av_pll.readdata,
        i_pll_write         => av_pll.write,
        i_pll_writedata     => av_pll.writedata,
        o_pll_waitrequest   => av_pll.waitrequest,

        i_reset_n           => i_reset_n,
        i_clk               => i_clk--,
    );

end architecture;

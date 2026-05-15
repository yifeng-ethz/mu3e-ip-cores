-----------------------------------
--
-- On detector FPGA for layer 0/1
-- Receiver block for all the LVDS links
-- Niklaus Berger, May 2013
--
-- nberger@physi.uni-heidelberg.de
--
-- Adaptions for MuPix8 Telescope
-- Sebastian Dittmeier, April 2016
-- dittmeier@physi.uni-heidelberg.de
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

use work.mudaq.all;

entity scifi_receiver_block is
generic (
    NINPUT : positive := 1;
    LVDS_PLL_FREQ : real := 125.0;
    LVDS_DATA_RATE : real := 1250.0;
    INPUT_SIGNFLIP : std_logic_vector(31 downto 0) := x"00000000"--;
);
port (
    -- serial lines
    i_rx                : in std_logic_vector(NINPUT-1 downto 0) := (others => '0');
    i_scifi_lvds_los_n  : in std_logic_vector(7 downto 0);

    -- ref.clocks
    i_rx_inclock        : in std_logic;

    -- slow control signals
    i_SC_mutrig         : in  work.mutrig_sc_types.t_sc_mutrig;
    o_SC_mutrig         : out work.mutrig_sc_types.t_sc_mutrig;

    -- counters
    o_rx_runcounter     : out slv32_array_t(NINPUT-1 downto 0);
    o_rx_errorcounter   : out slv32_array_t(NINPUT-1 downto 0);
    o_rx_synclosscounter: out slv32_array_t(NINPUT-1 downto 0);

    -- data output
    o_rx_data           : out   std_logic_vector(NINPUT*8-1 downto 0);
    o_rx_datak          : out   std_logic_vector(NINPUT-1 downto 0);
    o_rx_ready          : out   std_logic_vector(NINPUT-1 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture rtl of scifi_receiver_block is

    signal rx_out       : std_logic_vector(NINPUT*10-1 downto 0);
    signal rx_out_order : std_logic_vector(NINPUT*10-1 downto 0);
    signal rx_clk       : std_logic;

    signal rx_dpa_locked    : std_logic_vector (NINPUT-1 DOWNTO 0);
    signal rx_bitslip       : std_logic_vector (NINPUT-1 DOWNTO 0);
    signal rx_fifo_reset    : std_logic_vector (NINPUT-1 DOWNTO 0);
    signal rx_reset         : std_logic_vector (NINPUT-1 DOWNTO 0);

    signal rx_ready_reg     : std_logic_vector (NINPUT-1 DOWNTO 0);
    signal rx_disperr       : std_logic_vector(NINPUT-1 downto 0);

    signal rx_inclock_ctrl    : std_logic;
    signal rx_inclock_pll     : std_logic;
    signal rx_locked          : std_logic := '1';
    signal rx_dpaclock        : std_logic;
    signal rx_syncclock       : std_logic;
    signal rx_enable          : std_logic;
    signal rx_250_clk         : std_logic;

    signal rx_data  : std_logic_vector(NINPUT*8-1 downto 0);
    signal rx_datak : std_logic_vector(NINPUT-1 downto 0);

    signal fifo_rdata               : std_logic_vector(NINPUT*9-1 downto 0);
    signal fifo_wfull, fifo_rempty, rx_sync_fifo_rd  : std_logic_vector(NINPUT-1 downto 0);

begin

    o_SC_mutrig.receivers_dpa_lock(7 downto 0) <= rx_dpa_locked;
    o_SC_mutrig.receivers_pll_lock <= rx_locked;

    rx_clk <= rx_syncclock;

    clk_ctrl : component work.cmp.clk_ctrl_single
        port map (
             inclk  => i_rx_inclock,
             outclk => rx_inclock_ctrl--,
    );

    lpll : entity work.lvdspll
    PORT MAP
    (
        refclk   => rx_inclock_ctrl,
        rst      => '0',
        outclk_0 => rx_inclock_pll,
        outclk_1 => rx_enable,
        outclk_2 => rx_syncclock,
        outclk_3 => rx_dpaclock,
        outclk_4 => rx_250_clk,
        locked   => rx_locked
    );

    -- C7, C8, C3, C6, C4, inclock_B
    lvds_rx : entity work.lvds_receiver_small
    PORT MAP
    (
        pll_areset                  => not rx_locked,
        rx_channel_data_align       => '0' & rx_bitslip(7 downto 0),
        rx_dpaclock                 => rx_dpaclock,
        rx_enable                   => rx_enable,
        rx_fifo_reset(7 downto 0)   => rx_fifo_reset(7 downto 0) or not i_scifi_lvds_los_n,
        rx_in(7 downto 0)           => i_rx(7 downto 0),
        rx_in(8 downto 8)           => (others => '0'),
        rx_inclock                  => rx_inclock_pll,
        rx_reset(7 downto 0)        => rx_reset(7 downto 0),
        rx_syncclock                => rx_syncclock,
        rx_dpa_locked(7 downto 0)   => rx_dpa_locked(7 downto 0),
        rx_out(79 downto 0)         => rx_out(79 downto 0)--,
    );

-----------------------------------------------------------
--------------- decode and sync----------------------------
-----------------------------------------------------------

    -- flip bit order of received data (msb-lsb)
--    flip_bits: process(rx_out)
--    begin
--    for i in NINPUT-1 downto 0 loop
--        for n in 9 downto 0 loop
--           rx_out_order(10*i+n) <= INPUT_SIGNFLIP(i) xor rx_out(10*i+9-n);
--        end loop;
--    end loop;
--    end process flip_bits;

    geninvert_n: FOR i in 0 to NINPUT - 1 GENERATE
        genflip_n: FOR n in 0 to 9 GENERATE
            rx_out_order(10*i+n) <= not rx_out(10*i+9-n) when INPUT_SIGNFLIP(i) = '0' else rx_out(10*i+9-n);
        end generate genflip_n;
    end generate geninvert_n;

    gen_channels: for i in NINPUT-1 downto 0 generate
        e_data_decoder : entity work.data_decoder
        generic map (
            EVAL_WINDOW_WORDCNT_BITS    => 13,
            EVAL_WINDOW_PATTERN_BITS    => 2,
            ALIGN_WORD                  => K28_0--,
        )
        port map (
            --  checker_rst_n   => checker_rst_n(i),
            clk             => rx_clk,
            rx_in           => rx_out_order((i+1)*10-1 downto i*10),

            rx_reset        => rx_reset(i),
            rx_fifo_reset   => rx_fifo_reset(i),
            rx_dpa_locked   => rx_dpa_locked(i),
            rx_locked       => rx_locked,
            rx_bitslip      => rx_bitslip(i),

            ready           => rx_ready_reg(i),
            data            => rx_data((i+1)*8-1 downto i*8),
            k               => rx_datak(i),
            state_out       => o_SC_mutrig.rx_state((i+1)*2-1 downto i*2),
            disp_err        => rx_disperr(i),

            reset_n         => i_reset_n--,
        );


        errcounter: entity work.rx_errcounter
        port map (
            reset_n             => not i_SC_mutrig.reset_counters,
            clk                 => rx_clk,

            rx_sync             => rx_ready_reg(i),
            rx_disperr          => rx_disperr(i),

            o_runcounter        => o_rx_runcounter(i),
            o_errcounter        => o_rx_errorcounter(i),
            o_synclosscounter   => o_rx_synclosscounter(i)
        );

        -- sync rx data to i_clk_global
        e_fifo : entity work.ip_dcfifo_v2
        generic map (
            g_ADDR_WIDTH => 4,
            g_DATA_WIDTH => 9--,
        )
        port map (
            -- if not idle -> write
            i_we            => '1',
            i_wdata         => rx_datak(i) & rx_data((i+1)*8-1 downto i*8),
            o_wfull         => fifo_wfull(i),
            i_wclk          => rx_clk,

            i_rack          => rx_sync_fifo_rd(i),
            o_rdata         => fifo_rdata(i*9+8 downto i*9),
            o_rempty        => fifo_rempty(i),

            i_rclk          => i_clk,
            i_reset_n       => i_reset_n--,
        );

        process(i_clk)
        begin
        if rising_edge(i_clk) then
            rx_sync_fifo_rd(i)                  <= not fifo_rempty(i);
            o_SC_mutrig.receivers_ready(i)      <= rx_ready_reg(i);
            o_rx_ready(i)                       <= rx_ready_reg(i);
            o_rx_data(i*8+7 downto i*8)         <= fifo_rdata(i*9+7 downto i*9);
            o_rx_datak(i)                       <= fifo_rdata(i*9+8);
        end if;
        end process;

    end generate;

end architecture;

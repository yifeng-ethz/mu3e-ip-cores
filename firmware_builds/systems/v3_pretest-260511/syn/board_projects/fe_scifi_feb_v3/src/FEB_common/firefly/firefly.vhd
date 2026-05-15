----------------------------------------------------------------------------
-- Entity to talk to Firefly transceivers on V2 Frontent board
-- opt. data 8TX, 4RX + alignment
-- LVDS data 2RX + alignment + 8b10b decoder
-- I2C reading of firefly regs
-- Avalon interface
--
-- Martin Mueller muellem@uni-mainz.de
--
-- Transceiver plan:
-- one 4-channel TX-only (all ffly2_tx)
-- one 4-channel RX/TX (ffly1_rx0/tx0, ffly2rx0/ffly1tx1, ffly2rx1/ffly1tx2, ffly2rx2/ffly1tx3)
-- one 2-channel LVDS-RX
--
-- Avalon channel map:
-- ch0 : ffly_1_tx_data_0 -- ffly_1_rx_data_0
-- ch1 : ffly_1_tx_data_1 -- ffly_2_rx_data_0
-- ch2 : ffly_1_tx_data_2 -- ffly_2_rx_data_1
-- ch3 : ffly_1_tx_data_3 -- ffly_2_rx_data_2
-- ch4 : ffly_2_tx_data_0 -- RX_CLK_1
-- ch5 : ffly_2_tx_data_1 -- RX_CLK_2
-- ch6 : ffly_2_tx_data_2 -- ffly_1_lvds_in
-- ch7 : ffly_2_tx_data_3 -- ffly_2_lvds_in
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_slv.all;

entity firefly is
generic (
    g_SIM_USE_LEGACY_TX_CORECLK : boolean := true;
    g_SIM_BYPASS_RX_ALIGN       : boolean := false
);
port (
    i_shutdown              : in    std_logic;

    --rx
    i_data_fast_serial      : in    std_logic_vector(3 downto 0);
    o_data_fast_parallel    : out   std_logic_vector(127 downto 0);
    o_datak                 : out   std_logic_vector(15 downto 0);

    --tx
    o_data_fast_serial      : out   std_logic_vector(7 downto 0);
    i_data_fast_parallel    : in    std_logic_vector(255 downto 0);
    i_datak                 : in    std_logic_vector(31 downto 0);

    --I2C
--    i_i2c_enable            : in    std_logic;
--    o_Mod_Sel_n             : out   std_logic_vector(1 downto 0);
--    o_Rst_n                 : out   std_logic_vector(1 downto 0);
--    io_scl                  : inout std_logic;
--    io_sda                  : inout std_logic;
--    i_int_n                 : in    std_logic_vector(1 downto 0);
--    i_modPrs_n              : in    std_logic_vector(1 downto 0);

    i_reg_add               : in    std_logic_vector(15 downto 0);
    i_reg_re                : in    std_logic;
    o_reg_rdata             : out   std_logic_vector(31 downto 0);
    i_reg_we                : in    std_logic;
    i_reg_wdata             : in    std_logic_vector(31 downto 0);
    i_mon_reg_add           : in    std_logic_vector(15 downto 0) := (others => '0');
    i_mon_reg_re            : in    std_logic                     := '0';
    o_mon_reg_rdata         : out   std_logic_vector(31 downto 0);
    i_mon_reg_we            : in    std_logic                     := '0';
    i_mon_reg_wdata         : in    std_logic_vector(31 downto 0) := (others => '0');
    o_mon_reg_rvalid        : out   std_logic;


    -- outputs to slow control
    o_pwr                   : out   std_logic_vector(127 downto 0); -- RX optical power in mW
    o_temp                  : out   std_logic_vector(15 downto 0);  -- temperature in °C
    o_alarm                 : out   std_logic_vector(63 downto 0);  -- latched alarm bits
    o_vcc                   : out   std_logic_vector(31 downto 0);  -- operating voltagein units of 100 uV

    i_clk_156               : in    std_logic;
    i_reset_156_n           : in    std_logic;



    -- lvds rx
    i_data_lvds_serial      : in    std_logic_vector(1 downto 0);
    o_data_lvds_parallel    : out   std_logic_vector(15 downto 0);
    o_lvds_ready            : out   std_logic;
	
	i_resetlink_8bdata_sysclk	: in std_logic_vector(8 downto 0);

    -- lvds recovered clock
    o_lvds_rx_clk           : out   std_logic;
    o_lvds_rx_reset_n       : out   std_logic;

    -- lvds reference clock
    i_clk_125               : in    std_logic;
    i_reset_125_n           : in    std_logic;

    -- xcvr reconfig clock
    i_clk_50                : in    std_logic;
    i_reset_50_n            : in    std_logic--;
);
end entity;

architecture rtl of firefly is

    -- fast rx transceiver status signals ----------------------
    signal xcvr1_rx_clk_vec : std_logic_vector(3 downto 0);
    signal xcvr1_tx_clk_vec : std_logic_vector(3 downto 0);
    signal xcvr2_tx_clk_vec : std_logic_vector(3 downto 0);
    signal xcvr1_tx_coreclk : std_logic_vector(3 downto 0);
    signal xcvr2_tx_coreclk : std_logic_vector(3 downto 0);
    signal xcvr1_rx_reset_n_vec : std_logic_vector(3 downto 0);

    signal rx_data_parallel : std_logic_vector(127 downto 0);
    signal rx_datak         : std_logic_vector(15 downto 0);

    signal datak_not_aligned: std_logic_vector(15 downto 0);
    signal data_not_aligned : std_logic_vector(127 downto 0);
    signal enapatternalign  : std_logic_vector(3 downto 0);
    signal syncstatus       : std_logic_vector(15 downto 0);
    signal patterndetect    : std_logic_vector(15 downto 0);
    signal errdetect        : std_logic_vector(15 downto 0);
    signal disperr          : std_logic_vector(15 downto 0);

    signal rx_analogreset   : std_logic_vector(3 downto 0):= (others => '0');
    signal rx_digitalreset  : std_logic_vector(3 downto 0):= (others => '0');


    signal pll_powerdown    : std_logic_vector(3 downto 0):= (others => '0');
    signal pll_locked       : std_logic_vector(3 downto 0):= (others => '0');
    signal pll_locked2      : std_logic_vector(3 downto 0);
    signal pll_powerdown2   : std_logic_vector(3 downto 0);

    signal tx_cal_busy      : std_logic_vector(3 downto 0):= (others => '0');
    signal tx_cal_busy2     : std_logic_vector(3 downto 0);
    signal rx_cal_busy      : std_logic_vector(3 downto 0):= (others => '0');

    signal reconfig_to_xcvr_r   : std_logic_vector(559 downto 0):= (others => '0');
    signal reconfig_from_xcvr_r : std_logic_vector(367 downto 0):= (others => '0');

    signal reconfig_to_xcvr_r2  : std_logic_vector(559 downto 0);
    signal reconfig_from_xcvr_r2: std_logic_vector(367 downto 0);

    signal rx_is_lockedtodata   : std_logic_vector(7 downto 0):= (others => '0');
    signal rx_is_lockedtoref    : std_logic_vector(7 downto 0):= (others => '0');

    -- lvds receiver control signals
    signal lvds_pll_areset      : std_logic;
    signal lvds_data_align      : std_logic;
    signal lvds_dpa_lock_reset  : std_logic;
    signal lvds_dpa_lock_reset_n : std_logic;
    signal lvds_fifo_reset      : std_logic;
    signal lvds_rx_reset        : std_logic;
    signal lvds_cda_max         : std_logic;
    signal lvds_dpa_locked      : std_logic;
    signal lvds_rx_locked       : std_logic;
    signal lvds_align_clicks    : std_logic_vector(7 downto 0);
    signal lvds_ready           : std_logic;
    signal lvds_controller_state: std_logic_vector(3 downto 0);

    -- lvds data signals
    signal lvds_in_10b                      : std_logic_vector(9 downto 0);
    signal lvds_8b10b_in                    : std_logic_vector(9 downto 0);
    signal lvds_8b10b_out                   : std_logic_vector(7 downto 0);
    signal lvds_rx_clk                      : std_logic;
    signal lvds_rx_reset_n                  : std_logic;
    signal lvds_8b10b_out_in_clk125_global  : std_logic_vector(7 downto 0);
    signal lvds_align_reset_n               : std_logic;

    -- avalon interface
    signal rx_seriallpbken      : std_logic_vector(7 downto 0);
    signal tx_analogreset       : std_logic_vector(7 downto 0);
    signal tx_digitalreset      : std_logic_vector(7 downto 0);
    signal tx_ready             : std_logic_vector(7 downto 0);
    signal rx_ready             : std_logic_vector(7 downto 0);
    signal locked               : std_logic_vector(7 downto 0);

    signal av_rx_data_parallel  : std_logic_vector(127 downto 0);
    signal av_rx_datak          : std_logic_vector(15 downto 0);
    signal regmap_rx_syncstatus : slv4_array_t(7 downto 0) := (others => (others => '0'));
    signal regmap_rx_errdetect  : slv4_array_t(7 downto 0) := (others => (others => '0'));
    signal regmap_rx_disperr    : slv4_array_t(7 downto 0) := (others => (others => '0'));
    signal regmap_rx_data       : slv32_array_t(7 downto 0) := (others => (others => '0'));
    signal regmap_rx_datak      : slv4_array_t(7 downto 0) := (others => (others => '0'));
    signal mon_reg_rdata        : std_logic_vector(31 downto 0) := (others => '0');
    signal mon_reg_rvalid       : std_logic := '0';

begin

    -- Keep the TX write-side fabric in the external 156.25 MHz domain.
    -- The uplink producer chain is still clocked by i_clk_156, so do not
    -- self-feed tx_std_clkout back into tx_std_coreclkin in production RTL.
    xcvr1_tx_coreclk <= (others => i_clk_156);
    xcvr2_tx_coreclk <= (others => i_clk_156);

    -- o_Rst_n <= (others => '1') when i_shutdown = '0' else (others => '0'); --DO NOT DO THIS: (others => i_reset_n); !!! Phase will be not fixed
    o_pwr <= (others => '0');
    o_temp <= (others => '0');
    o_alarm <= (others => '0');
    o_vcc <= (others => '0');
    o_lvds_ready <= lvds_ready;
    o_lvds_rx_clk <= lvds_rx_clk;
    o_lvds_rx_reset_n <= lvds_rx_reset_n;
    o_mon_reg_rdata <= mon_reg_rdata;
    o_mon_reg_rvalid <= mon_reg_rvalid;

    process(i_clk_156)
    begin
    if rising_edge(i_clk_156) then
        -- spending a round of registers for timing improvement
        o_data_fast_parallel    <= av_rx_data_parallel;
        o_datak                 <= av_rx_datak;
        mon_reg_rvalid          <= i_mon_reg_re;
    end if;
    end process;

    regmap_rx_syncstatus(3) <= syncstatus(15 downto 12);
    regmap_rx_syncstatus(2) <= syncstatus(11 downto 8);
    regmap_rx_syncstatus(1) <= syncstatus(7 downto 4);
    regmap_rx_syncstatus(0) <= syncstatus(3 downto 0);

    regmap_rx_errdetect(3) <= errdetect(15 downto 12);
    regmap_rx_errdetect(2) <= errdetect(11 downto 8);
    regmap_rx_errdetect(1) <= errdetect(7 downto 4);
    regmap_rx_errdetect(0) <= errdetect(3 downto 0);

    regmap_rx_disperr(3) <= disperr(15 downto 12);
    regmap_rx_disperr(2) <= disperr(11 downto 8);
    regmap_rx_disperr(1) <= disperr(7 downto 4);
    regmap_rx_disperr(0) <= disperr(3 downto 0);

    regmap_rx_data(6) <= x"000000" & i_resetlink_8bdata_sysclk(7 downto 0);
    regmap_rx_data(3) <= av_rx_data_parallel(127 downto 96);
    regmap_rx_data(2) <= av_rx_data_parallel(95 downto 64);
    regmap_rx_data(1) <= av_rx_data_parallel(63 downto 32);
    regmap_rx_data(0) <= av_rx_data_parallel(31 downto 0);

    regmap_rx_datak(3) <= av_rx_datak(15 downto 12);
    regmap_rx_datak(2) <= av_rx_datak(11 downto 8);
    regmap_rx_datak(1) <= av_rx_datak(7 downto 4);
    regmap_rx_datak(0) <= av_rx_datak(3 downto 0);

    --------------------------------------------------
    -- transceiver (2)
    --------------------------------------------------

    -- 4-channel RX/TX
    e_xcvr1 : component work.cmp.ip_altera_xcvr_native_av
    port map (
        --clocks
        tx_pll_refclk           => (others => i_clk_156),
        rx_cdr_refclk           => (others => i_clk_156),
        tx_std_coreclkin        => xcvr1_tx_coreclk,
        rx_std_coreclkin        => xcvr1_rx_clk_vec,
        tx_std_clkout           => xcvr1_tx_clk_vec,
        rx_std_clkout           => xcvr1_rx_clk_vec,

        --resets
        tx_analogreset          => tx_analogreset(3 downto 0),
        tx_digitalreset         => tx_digitalreset(3 downto 0),
        rx_analogreset          => rx_analogreset,
        rx_digitalreset         => rx_digitalreset,

        -- tx data
        tx_serial_data          => o_data_fast_serial(3 downto 0),
        tx_parallel_data        => i_data_fast_parallel(127 downto 0),
        tx_datak                => i_datak(15 downto 0),

        -- rx data
        rx_serial_data          => i_data_fast_serial,
        rx_parallel_data        => data_not_aligned,
        rx_datak                => datak_not_aligned,

        -- control outputs
        rx_is_lockedtoref       => rx_is_lockedtoref(3 downto 0),
        rx_is_lockedtodata      => rx_is_lockedtodata(3 downto 0),
        pll_locked              => pll_locked,
        tx_cal_busy             => tx_cal_busy,
        rx_cal_busy             => rx_cal_busy,
        rx_errdetect            => errdetect,
        rx_disperr              => disperr,
        rx_runningdisp          => open,
        rx_patterndetect        => patterndetect,
        rx_syncstatus           => syncstatus,

        -- control inputs
        pll_powerdown           => pll_powerdown,
        rx_seriallpbken         => rx_seriallpbken(3 downto 0),
        rx_std_wa_patternalign  => enapatternalign,

        -- reconfig
        reconfig_to_xcvr        => reconfig_to_xcvr_r,
        reconfig_from_xcvr      => reconfig_from_xcvr_r,

        unused_tx_parallel_data => (others => '0'),
        unused_rx_parallel_data => open--,
    );

    -- 4-channel TX
    -- TODO: rename ip_...
    e_xcvr2 : component work.cmp.fastlink_small
    port map (
        --clocks
        tx_pll_refclk           => (others => i_clk_156),
        tx_std_coreclkin        => xcvr2_tx_coreclk,
        tx_std_clkout           => xcvr2_tx_clk_vec,

        --resets
        tx_analogreset          => tx_analogreset(7 downto 4),
        tx_digitalreset         => tx_digitalreset(7 downto 4),

        -- tx data
        tx_serial_data          => o_data_fast_serial(7 downto 4),
        tx_parallel_data        => i_data_fast_parallel(127 downto 0),
        tx_datak                => i_datak(15 downto 0),

        -- control outputs
        pll_locked              => pll_locked2,
        tx_cal_busy             => tx_cal_busy2,

        -- control inputs
        pll_powerdown           => pll_powerdown2,

        -- reconfig
        reconfig_to_xcvr        => reconfig_to_xcvr_r2,
        reconfig_from_xcvr      => reconfig_from_xcvr_r2,

        unused_tx_parallel_data => (others => '0')--,
    );

    --------------------------------------------------
    -- rx byte alignment (4)
    --------------------------------------------------
    generate_rx_align_bypass: if g_SIM_BYPASS_RX_ALIGN generate
        rx_data_parallel <= data_not_aligned;
        rx_datak <= datak_not_aligned;
        locked(3 downto 0) <= (others => '1');
        enapatternalign <= (others => '0');
    end generate;

    generate_rx_align: if not g_SIM_BYPASS_RX_ALIGN generate
        generate_rx_align_lanes: for I in 0 to 3 generate
            e_rx_align: entity work.rx_align
            generic map (
                g_BYTES => 4--,
            )
            port map (
                o_data                  => rx_data_parallel(31+I*32 downto I*32),
                o_datak                 => rx_datak(3+I*4 downto I*4),
                o_locked                => locked(I),

                o_bitslip               => enapatternalign(I),

                i_data                  => data_not_aligned(31+I*32 downto I*32),
                i_datak                 => datak_not_aligned(3+I*4 downto I*4),
                i_error                 => work.util.or_reduce(errdetect(3+I*4 downto I*4) or disperr(3+I*4 downto I*4)),

                i_clk                   => xcvr1_rx_clk_vec(I),
                i_reset_n               => xcvr1_rx_reset_n_vec(I)--,
            );
        end generate;
    end generate;

    generate_xcvr1_rx_reset_n: for I in 0 to 3 generate
        e_xcvr1_rx_reset_n : entity work.reset_sync
        port map (
            o_reset_n => xcvr1_rx_reset_n_vec(I),
            i_reset_n => i_reset_156_n,
            i_clk     => xcvr1_rx_clk_vec(I)--,
        );
    end generate;

    --------------------------------------------------
    -- reset controller (2)
    --------------------------------------------------

    e_xcvr1_reset_control : component work.cmp.ip_altera_xcvr_reset_control
    port map (
        pll_powerdown           => pll_powerdown,
        tx_analogreset          => tx_analogreset(3 downto 0),
        tx_digitalreset         => tx_digitalreset(3 downto 0),
        tx_ready                => tx_ready(3 downto 0),
        pll_locked              => pll_locked,
        pll_select              => (others => '0'),
        tx_cal_busy             => tx_cal_busy,
        rx_analogreset          => rx_analogreset,
        rx_digitalreset         => rx_digitalreset,
        rx_ready                => rx_ready(3 downto 0),
        rx_is_lockedtodata      => rx_is_lockedtodata(3 downto 0),
        rx_cal_busy             => rx_cal_busy,
        clock                   => i_clk_156,
        reset                   => not i_reset_156_n--,
    );

    e_xcvr2_reset_control : component work.cmp.native_reset_tx
    port map (
        pll_powerdown           => pll_powerdown2,
        tx_analogreset          => tx_analogreset(7 downto 4),
        tx_digitalreset         => tx_digitalreset(7 downto 4),
        tx_ready                => tx_ready(7 downto 4),
        pll_locked              => pll_locked2,
        pll_select              => (others => '0'),
        tx_cal_busy             => tx_cal_busy2,
        clock                   => i_clk_156,
        reset                   => not i_reset_156_n--,
    );

    --------------------------------------------------
    -- reconfig controller (2)
    --------------------------------------------------

    e_xcvr_reconfig : component work.cmp.ip_alt_xcvr_reconfig
    port map (
        reconfig_busy             => open,
        reconfig_mgmt_address     => (others => '0'),
        reconfig_mgmt_read        => '0',
        reconfig_mgmt_readdata    => open,
        reconfig_mgmt_waitrequest => open,
        reconfig_mgmt_write       => '0',
        reconfig_mgmt_writedata   => (others => '0'),
        ch0_7_to_xcvr             => reconfig_to_xcvr_r,
        ch0_7_from_xcvr           => reconfig_from_xcvr_r,
        ch8_15_to_xcvr            => reconfig_to_xcvr_r2,
        ch8_15_from_xcvr          => reconfig_from_xcvr_r2,
        mgmt_clk_clk              => i_clk_50,
        mgmt_rst_reset            => not i_reset_50_n--,
    );

    --------------------------------------------------
    -- lvds receiver + alignment and 8b10b decode
    --------------------------------------------------

--    e_lvds_rx : entity work.lvds_rx
--    port map (
--        pll_areset                  => lvds_pll_areset,
--        rx_channel_data_align(0)    => lvds_data_align,
--        rx_dpa_lock_reset(0)        => not lvds_dpa_lock_reset_n,
--        rx_fifo_reset(0)            => lvds_fifo_reset,
--        rx_in(0)                    => i_data_lvds_serial(0),
--        rx_inclock                  => i_clk_125,
--        rx_reset(0)                 => lvds_rx_reset,
--        rx_cda_max(0)               => lvds_cda_max,
--        rx_dpa_locked(0)            => lvds_dpa_locked,
--        rx_locked                   => lvds_rx_locked,
--        rx_out                      => lvds_in_10b,
--        rx_outclock                 => lvds_rx_clk--,
--    );
--    e_lvds_rx_reset_n : entity work.reset_sync
--    port map ( o_reset_n => lvds_rx_reset_n, i_reset_n => i_reset_125_n, i_clk => lvds_rx_clk);

    -- sync lvds_dpa_lock_reset into lvds_rx_clk domain
    --e_lvds_dpa_lock_reset_n : entity work.reset_sync
    --port map ( o_reset_n => lvds_dpa_lock_reset_n, i_reset_n => not lvds_dpa_lock_reset, i_clk => lvds_rx_clk);
--    lvds_dpa_lock_reset_n <= not lvds_dpa_lock_reset;
--
--    e_lvds_controller : entity work.lvds_controller
--    port map (
--        -- controller MUST run on 125 Global. DO NOT CHANGE TO lvds_rx_clk !!!
--        i_clk               => i_clk_125,
--        i_areset_n          => lvds_align_reset_n,
--        i_data              => lvds_8b10b_out_in_clk125_global, -- feed alignment with 8b10b decoded data in global clk domain
--        i_cda_max           => lvds_cda_max,
--        i_dpa_locked        => lvds_dpa_locked,
--        i_rx_locked         => lvds_rx_locked,
--        o_ready             => lvds_ready,
--        o_data_align        => lvds_data_align,
--        o_pll_areset        => lvds_pll_areset,
--        o_dpa_lock_reset    => lvds_dpa_lock_reset,
--        o_fifo_reset        => lvds_fifo_reset,
--        o_rx_reset          => lvds_rx_reset,
--        o_cda_reset         => open, -- not available on ArriaV
--        o_align_clicks      => lvds_align_clicks,
--        o_lvds_state        => lvds_controller_state--,
--    );

--    process(lvds_rx_clk)
--    begin
--    if rising_edge(lvds_rx_clk) then
--        lvds_8b10b_in <= lvds_in_10b;
--    end if;
--    end process;

--    e_dec_8b10b : entity work.dec_8b10b_n
--    generic map (
--        g_BYTES => 1--,
--    )
--    port map (
--        i_data => work.util.reverse(lvds_8b10b_in),
--        o_data => lvds_8b10b_out,
--        o_datak => open, -- TODO: datak
--        o_err => open, -- TODO: check error
--        i_reset_n => lvds_rx_reset_n,
--        i_clk => lvds_rx_clk--,
--    );

    -- sync 8b10b_out properly into i_clk_lvds for alignment in lvds_controller (e_fifo8b)
    -- forward the "not-synced" signal to state controller (running on reconstructed clock lvds_rx_clk)
    o_data_lvds_parallel(15 downto 8) <= (others => '0');
    o_data_lvds_parallel(7 downto 0) <= (others => '0'); --lvds_8b10b_out;

    --------------------------------------------------
    -- I2C reading
    --------------------------------------------------

--    e_firefly_i2c : entity work.firefly_i2c
--    generic map (
--        g_CLK_MHZ => 156.25--,
--    )
--    port map (
--        i_i2c_enable    => i_i2c_enable,
--        o_Mod_Sel_n     => o_Mod_Sel_n,
--        io_scl          => io_scl,
--        io_sda          => io_sda,
--        i_int_n         => i_int_n,
--        i_modPrs_n      => i_modPrs_n,
--
--        o_pwr           => o_pwr,
--        o_temp          => o_temp,
--        o_alarm         => o_alarm,
--        o_vcc           => o_vcc,
--
--        i_clk           => i_clk_156,
--        i_reset_n       => i_reset_156_n--,
--    );


    --------------------------------------------------
    -- SC connection
    --------------------------------------------------

    e_firefly_reg_mapping : entity work.firefly_reg_mapping
    generic map (
        N_CHANNELS_g => 8,
        CHANNEL_WIDTH_g => 32--,
    )
    port map (
        i_reg_add         => i_reg_add,
        i_reg_re          => i_reg_re,
        o_reg_rdata       => o_reg_rdata,
        i_reg_we          => i_reg_we,
        i_reg_wdata       => i_reg_wdata,

        o_loopback        => rx_seriallpbken,
        o_tx_reset        => open,
        o_rx_reset        => open,
        o_lvds_align_reset_n => lvds_align_reset_n,
        i_lvds_controller_state => lvds_controller_state,

        i_tx_status         => tx_ready,
        i_rx_ready          => rx_ready,
        i_rx_lockedtoref    => rx_is_lockedtoref,
        i_rx_lockedtodata   => rx_is_lockedtodata,
        i_rx_locked         => locked,
        i_rx_syncstatus     => regmap_rx_syncstatus,
        i_rx_errDetect      => regmap_rx_errdetect,
        i_rx_disperr        => regmap_rx_disperr,
        i_rx_data           => regmap_rx_data,
        i_rx_datak          => regmap_rx_datak,

        i_reset_n           => i_reset_156_n,
        i_clk               => i_clk_156--,
    );

    e_firefly_reg_mapping_monitor : entity work.firefly_reg_mapping
    generic map (
        N_CHANNELS_g => 8,
        CHANNEL_WIDTH_g => 32--,
    )
    port map (
        i_reg_add               => i_mon_reg_add,
        i_reg_re                => i_mon_reg_re,
        o_reg_rdata             => mon_reg_rdata,
        i_reg_we                => i_mon_reg_we,
        i_reg_wdata             => i_mon_reg_wdata,

        o_loopback              => open,
        o_tx_reset              => open,
        o_rx_reset              => open,
        o_lvds_align_reset_n    => open,
        i_lvds_controller_state => lvds_controller_state,

        i_tx_status             => tx_ready,
        i_rx_ready              => rx_ready,
        i_rx_lockedtoref        => rx_is_lockedtoref,
        i_rx_lockedtodata       => rx_is_lockedtodata,
        i_rx_locked             => locked,
        i_rx_syncstatus         => regmap_rx_syncstatus,
        i_rx_errDetect          => regmap_rx_errdetect,
        i_rx_disperr            => regmap_rx_disperr,
        i_rx_data               => regmap_rx_data,
        i_rx_datak              => regmap_rx_datak,

        i_reset_n               => i_reset_156_n,
        i_clk                   => i_clk_156--,
    );

    --------------------------------------------------
    -- Sync FIFO's
    --------------------------------------------------
    e_sync_lvds_rx : entity work.ip_dcfifo_v2
    generic map (
        g_ADDR_WIDTH => 4,
        g_DATA_WIDTH => 8,
        g_SHOWAHEAD => "OFF"--,
    )
    port map (
        i_we => '1',
        i_wdata => lvds_8b10b_out,
        i_wclk => lvds_rx_clk,
        i_rack => '1',
        o_rdata => lvds_8b10b_out_in_clk125_global,
        i_rclk => i_clk_125,
        i_reset_n => not lvds_fifo_reset--,
    );

    generate_sync_xcvr1_rx_bypass: if g_SIM_BYPASS_RX_ALIGN generate
        av_rx_data_parallel <= data_not_aligned;
        av_rx_datak <= datak_not_aligned;
    end generate;

    generate_sync_xcvr1_rx: if not g_SIM_BYPASS_RX_ALIGN generate
        generate_sync_xcvr1_rx_lanes: for I in 0 to 3 generate
            e_sync_xcvr1_rx : entity work.ip_dcfifo_v2
            generic map (
                g_ADDR_WIDTH => 4,
                g_DATA_WIDTH => 36,
                g_SHOWAHEAD  => "OFF"--,
            )
            port map (
                i_we                => '1',
                i_wdata(35 downto 4)=> rx_data_parallel(31+I*32 downto I*32),
                i_wdata(3 downto 0) => rx_datak(3+I*4 downto I*4),
                i_wclk              => xcvr1_rx_clk_vec(I),
                i_rack              => '1',
                o_rdata(35 downto 4)=> av_rx_data_parallel(31+I*32 downto I*32),
                o_rdata(3 downto 0) => av_rx_datak(3+I*4 downto I*4),
                i_rclk              => i_clk_156,
                i_reset_n           => lvds_align_reset_n--,
            );
        end generate;
    end generate;

    locked(6) <= lvds_ready;

end architecture;

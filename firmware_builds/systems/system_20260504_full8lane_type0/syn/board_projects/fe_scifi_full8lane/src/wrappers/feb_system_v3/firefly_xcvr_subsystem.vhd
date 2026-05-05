library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util.all;
use work.util_slv.all;

entity firefly_xcvr_subsystem is
    port (
        i_clk_156                    : in    std_logic;
        i_reset_156_n                : in    std_logic;
        i_clk_50                     : in    std_logic;
        i_reset_50_n                 : in    std_logic;

        i_upload_data0_sc_rc_data    : in    std_logic_vector(35 downto 0);
        i_upload_data0_sc_rc_valid   : in    std_logic;
        i_upload_data1_data          : in    std_logic_vector(35 downto 0);
        i_upload_data1_valid         : in    std_logic;

        o_download_sc_data           : out   std_logic_vector(31 downto 0);
        o_download_sc_datak          : out   std_logic_vector(3 downto 0);

        i_mon_address                : in    std_logic_vector(7 downto 0);
        i_mon_write                  : in    std_logic;
        i_mon_read                   : in    std_logic;
        i_mon_writedata              : in    std_logic_vector(31 downto 0);
        i_mon_byteenable             : in    std_logic_vector(3 downto 0);
        i_mon_debugaccess            : in    std_logic;
        o_mon_waitrequest            : out   std_logic;
        o_mon_readdata               : out   std_logic_vector(31 downto 0);
        o_mon_readdatavalid          : out   std_logic;
        o_mon_response               : out   std_logic_vector(1 downto 0);

        o_firefly1_tx_data           : out   std_logic_vector(3 downto 0);
        o_firefly2_tx_data           : out   std_logic_vector(3 downto 0);
        i_firefly1_rx_data           : in    std_logic;
        i_firefly2_rx_data           : in    std_logic_vector(2 downto 0)
    );
end entity firefly_xcvr_subsystem;

architecture rtl of firefly_xcvr_subsystem is
    type word36_array_t is array (natural range <>) of std_logic_vector(35 downto 0);

    function any_high(i_vec : std_logic_vector) return std_logic is
        variable result_v : std_logic := '0';
    begin
        for i in i_vec'range loop
            result_v := result_v or i_vec(i);
        end loop;
        return result_v;
    end function any_high;

    constant IDLE_WORD_C : std_logic_vector(35 downto 0) := "0001" & x"000000BC";

    signal reset_156_n           : std_logic := '0';
    signal reset_50_n            : std_logic := '0';
    signal tx_words              : word36_array_t(7 downto 0) := (others => IDLE_WORD_C);

    signal xcvr1_tx_clk_vec      : std_logic_vector(3 downto 0);
    signal xcvr2_tx_clk_vec      : std_logic_vector(3 downto 0);
    signal xcvr1_rx_clk_vec      : std_logic_vector(3 downto 0);
    signal xcvr1_rx_reset_n_vec  : std_logic_vector(3 downto 0);

    signal tx_parallel_native    : std_logic_vector(127 downto 0);
    signal tx_datak_native       : std_logic_vector(15 downto 0);
    signal tx_parallel_small     : std_logic_vector(127 downto 0);
    signal tx_datak_small        : std_logic_vector(15 downto 0);

    signal rx_data_unaligned     : std_logic_vector(127 downto 0);
    signal rx_datak_unaligned    : std_logic_vector(15 downto 0);
    signal rx_data_aligned       : std_logic_vector(127 downto 0);
    signal rx_datak_aligned      : std_logic_vector(15 downto 0);
    signal rx_data_sys           : std_logic_vector(127 downto 0);
    signal rx_datak_sys          : std_logic_vector(15 downto 0);
    signal rx_locked             : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_bitslip            : std_logic_vector(3 downto 0);

    signal syncstatus            : std_logic_vector(15 downto 0);
    signal errdetect             : std_logic_vector(15 downto 0);
    signal disperr               : std_logic_vector(15 downto 0);

    signal tx_ready              : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_ready              : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_is_lockedtoref     : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_is_lockedtodata    : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_seriallpbken       : std_logic_vector(7 downto 0) := (others => '0');

    signal tx_analogreset_0      : std_logic_vector(3 downto 0);
    signal tx_digitalreset_0     : std_logic_vector(3 downto 0);
    signal tx_analogreset_1      : std_logic_vector(3 downto 0);
    signal tx_digitalreset_1     : std_logic_vector(3 downto 0);
    signal rx_analogreset        : std_logic_vector(3 downto 0);
    signal rx_digitalreset       : std_logic_vector(3 downto 0);
    signal pll_powerdown_0       : std_logic_vector(3 downto 0);
    signal pll_powerdown_1       : std_logic_vector(3 downto 0);
    signal pll_locked_0          : std_logic_vector(3 downto 0);
    signal pll_locked_1          : std_logic_vector(3 downto 0);
    signal tx_cal_busy_0         : std_logic_vector(3 downto 0);
    signal tx_cal_busy_1         : std_logic_vector(3 downto 0);
    signal rx_cal_busy           : std_logic_vector(3 downto 0);

    signal reconfig_to_xcvr_0    : std_logic_vector(559 downto 0);
    signal reconfig_from_xcvr_0  : std_logic_vector(367 downto 0);
    signal reconfig_to_xcvr_1    : std_logic_vector(559 downto 0);
    signal reconfig_from_xcvr_1  : std_logic_vector(367 downto 0);

    signal regmap_rx_syncstatus  : slv4_array_t(7 downto 0) := (others => (others => '0'));
    signal regmap_rx_errdetect   : slv4_array_t(7 downto 0) := (others => (others => '0'));
    signal regmap_rx_disperr     : slv4_array_t(7 downto 0) := (others => (others => '0'));
    signal regmap_rx_data        : slv32_array_t(7 downto 0) := (others => (others => '0'));
    signal regmap_rx_datak       : slv4_array_t(7 downto 0) := (others => (others => '0'));
    signal regmap_rx_fifo_error  : std_logic_vector(7 downto 0) := (others => '0');
    signal regmap_rx_lol_cnt     : slv8_array_t(7 downto 0) := (others => (others => '0'));
    signal regmap_rx_err_cnt     : slv16_array_t(7 downto 0) := (others => (others => '0'));
    signal regmap_rx_gbit        : slv24_array_t(7 downto 0) := (others => (others => '0'));

    signal mon_readdata          : std_logic_vector(31 downto 0) := (others => '0');
    signal mon_readdatavalid     : std_logic := '0';
begin
    o_download_sc_data <= rx_data_sys(31 downto 0);
    o_download_sc_datak <= rx_datak_sys(3 downto 0);

    o_mon_waitrequest <= '0';
    o_mon_readdata <= mon_readdata;
    o_mon_readdatavalid <= mon_readdatavalid;
    o_mon_response <= (others => '0');

    u_reset_156_sync : entity work.reset_sync
        port map (
            o_reset_n => reset_156_n,
            i_reset_n => i_reset_156_n,
            i_clk     => i_clk_156
        );

    u_reset_50_sync : entity work.reset_sync
        port map (
            o_reset_n => reset_50_n,
            i_reset_n => i_reset_50_n,
            i_clk     => i_clk_50
        );

    process (i_clk_156)
    begin
        if rising_edge(i_clk_156) then
            if reset_156_n /= '1' then
                tx_words <= (others => IDLE_WORD_C);
            else
                tx_words <= (others => IDLE_WORD_C);

                if i_upload_data0_sc_rc_valid = '1' then
                    tx_words(0) <= i_upload_data0_sc_rc_data;
                end if;

                if i_upload_data1_valid = '1' then
                    tx_words(4) <= i_upload_data1_data;
                end if;
            end if;
        end if;
    end process;

    tx_parallel_native <=
        tx_words(3)(31 downto 0) &
        tx_words(2)(31 downto 0) &
        tx_words(1)(31 downto 0) &
        tx_words(0)(31 downto 0);
    tx_datak_native <=
        tx_words(3)(35 downto 32) &
        tx_words(2)(35 downto 32) &
        tx_words(1)(35 downto 32) &
        tx_words(0)(35 downto 32);

    tx_parallel_small <=
        tx_words(7)(31 downto 0) &
        tx_words(6)(31 downto 0) &
        tx_words(5)(31 downto 0) &
        tx_words(4)(31 downto 0);
    tx_datak_small <=
        tx_words(7)(35 downto 32) &
        tx_words(6)(35 downto 32) &
        tx_words(5)(35 downto 32) &
        tx_words(4)(35 downto 32);

    -- Preserve the old board channel map:
    -- lane 0 = firefly1 rx/tx, lanes 1..3 = firefly2 rx paired with firefly1 tx(1..3).
    u_xcvr_native : component work.cmp.ip_altera_xcvr_native_av
        port map (
            tx_pll_refclk           => (others => i_clk_156),
            rx_cdr_refclk           => (others => i_clk_156),
            tx_std_coreclkin        => (others => i_clk_156),
            rx_std_coreclkin        => xcvr1_rx_clk_vec,
            tx_std_clkout           => xcvr1_tx_clk_vec,
            rx_std_clkout           => xcvr1_rx_clk_vec,
            tx_analogreset          => tx_analogreset_0,
            tx_digitalreset         => tx_digitalreset_0,
            pll_powerdown           => pll_powerdown_0,
            rx_analogreset          => rx_analogreset,
            rx_digitalreset         => rx_digitalreset,
            tx_serial_data          => o_firefly1_tx_data,
            tx_parallel_data        => tx_parallel_native,
            tx_datak                => tx_datak_native,
            rx_serial_data          => i_firefly2_rx_data & i_firefly1_rx_data,
            rx_parallel_data        => rx_data_unaligned,
            rx_datak                => rx_datak_unaligned,
            rx_is_lockedtoref       => rx_is_lockedtoref(3 downto 0),
            rx_is_lockedtodata      => rx_is_lockedtodata(3 downto 0),
            pll_locked              => pll_locked_0,
            tx_cal_busy             => tx_cal_busy_0,
            rx_cal_busy             => rx_cal_busy,
            rx_errdetect            => errdetect,
            rx_disperr              => disperr,
            rx_runningdisp          => open,
            rx_patterndetect        => open,
            rx_syncstatus           => syncstatus,
            rx_seriallpbken         => rx_seriallpbken(3 downto 0),
            rx_std_wa_patternalign  => rx_bitslip,
            reconfig_to_xcvr        => reconfig_to_xcvr_0,
            reconfig_from_xcvr      => reconfig_from_xcvr_0,
            unused_tx_parallel_data => (others => '0'),
            unused_rx_parallel_data => open
        );

    -- The second XCVR block remains TX-only and still drives firefly2 tx(3 downto 0).
    u_xcvr_tx_only : component work.cmp.fastlink_small
        port map (
            tx_pll_refclk           => (others => i_clk_156),
            tx_std_coreclkin        => (others => i_clk_156),
            tx_std_clkout           => xcvr2_tx_clk_vec,
            tx_analogreset          => tx_analogreset_1,
            tx_digitalreset         => tx_digitalreset_1,
            tx_serial_data          => o_firefly2_tx_data,
            tx_parallel_data        => tx_parallel_small,
            tx_datak                => tx_datak_small,
            pll_locked              => pll_locked_1,
            tx_cal_busy             => tx_cal_busy_1,
            pll_powerdown           => pll_powerdown_1,
            reconfig_to_xcvr        => reconfig_to_xcvr_1,
            reconfig_from_xcvr      => reconfig_from_xcvr_1,
            unused_tx_parallel_data => (others => '0')
        );

    u_xcvr_reset_rx_tx : component work.cmp.ip_altera_xcvr_reset_control
        port map (
            pll_powerdown      => pll_powerdown_0,
            tx_analogreset     => tx_analogreset_0,
            tx_digitalreset    => tx_digitalreset_0,
            tx_ready           => tx_ready(3 downto 0),
            pll_locked         => pll_locked_0,
            pll_select         => (others => '0'),
            tx_cal_busy        => tx_cal_busy_0,
            rx_analogreset     => rx_analogreset,
            rx_digitalreset    => rx_digitalreset,
            rx_ready           => rx_ready(3 downto 0),
            rx_is_lockedtodata => rx_is_lockedtodata(3 downto 0),
            rx_cal_busy        => rx_cal_busy,
            clock              => i_clk_156,
            reset              => not reset_156_n
        );

    u_xcvr_reset_tx_only : component work.cmp.native_reset_tx
        port map (
            pll_powerdown   => pll_powerdown_1,
            tx_analogreset  => tx_analogreset_1,
            tx_digitalreset => tx_digitalreset_1,
            tx_ready        => tx_ready(7 downto 4),
            pll_locked      => pll_locked_1,
            pll_select      => (others => '0'),
            tx_cal_busy     => tx_cal_busy_1,
            clock           => i_clk_156,
            reset           => not reset_156_n
        );

    u_xcvr_reconfig : component work.cmp.ip_alt_xcvr_reconfig
        port map (
            reconfig_busy             => open,
            reconfig_mgmt_address     => (others => '0'),
            reconfig_mgmt_read        => '0',
            reconfig_mgmt_readdata    => open,
            reconfig_mgmt_waitrequest => open,
            reconfig_mgmt_write       => '0',
            reconfig_mgmt_writedata   => (others => '0'),
            ch0_7_to_xcvr             => reconfig_to_xcvr_0,
            ch0_7_from_xcvr           => reconfig_from_xcvr_0,
            ch8_15_to_xcvr            => reconfig_to_xcvr_1,
            ch8_15_from_xcvr          => reconfig_from_xcvr_1,
            mgmt_clk_clk              => i_clk_50,
            mgmt_rst_reset            => not reset_50_n
        );

    g_rx_reset_sync : for i in 0 to 3 generate
        u_rx_reset_sync : entity work.reset_sync
            port map (
                o_reset_n => xcvr1_rx_reset_n_vec(i),
                i_reset_n => reset_156_n,
                i_clk     => xcvr1_rx_clk_vec(i)
            );

        u_rx_align : entity work.rx_align
            generic map (
                g_BYTES => 4
            )
            port map (
                o_data    => rx_data_aligned(31 + i * 32 downto i * 32),
                o_datak   => rx_datak_aligned(3 + i * 4 downto i * 4),
                o_locked  => rx_locked(i),
                o_bitslip => rx_bitslip(i),
                i_data    => rx_data_unaligned(31 + i * 32 downto i * 32),
                i_datak   => rx_datak_unaligned(3 + i * 4 downto i * 4),
                i_error   => any_high(errdetect(3 + i * 4 downto i * 4) or disperr(3 + i * 4 downto i * 4)),
                i_reset_n => xcvr1_rx_reset_n_vec(i),
                i_clk     => xcvr1_rx_clk_vec(i)
            );

        u_rx_crossing : entity work.ip_dcfifo_v2
            generic map (
                g_ADDR_WIDTH => 4,
                g_DATA_WIDTH => 36,
                g_SHOWAHEAD  => "OFF"
            )
            port map (
                i_we                 => '1',
                i_wdata(35 downto 4) => rx_data_aligned(31 + i * 32 downto i * 32),
                i_wdata(3 downto 0)  => rx_datak_aligned(3 + i * 4 downto i * 4),
                o_wfull              => open,
                o_wfull_n            => open,
                o_wusedw             => open,
                i_wclk               => xcvr1_rx_clk_vec(i),
                i_rack               => '1',
                o_rdata(35 downto 4) => rx_data_sys(31 + i * 32 downto i * 32),
                o_rdata(3 downto 0)  => rx_datak_sys(3 + i * 4 downto i * 4),
                o_rempty             => open,
                o_rempty_n           => open,
                o_rusedw             => open,
                i_rclk               => i_clk_156,
                i_reset_n            => reset_156_n
            );
    end generate;

    regmap_rx_syncstatus(0) <= syncstatus(3 downto 0);
    regmap_rx_syncstatus(1) <= syncstatus(7 downto 4);
    regmap_rx_syncstatus(2) <= syncstatus(11 downto 8);
    regmap_rx_syncstatus(3) <= syncstatus(15 downto 12);

    regmap_rx_errdetect(0) <= errdetect(3 downto 0);
    regmap_rx_errdetect(1) <= errdetect(7 downto 4);
    regmap_rx_errdetect(2) <= errdetect(11 downto 8);
    regmap_rx_errdetect(3) <= errdetect(15 downto 12);

    regmap_rx_disperr(0) <= disperr(3 downto 0);
    regmap_rx_disperr(1) <= disperr(7 downto 4);
    regmap_rx_disperr(2) <= disperr(11 downto 8);
    regmap_rx_disperr(3) <= disperr(15 downto 12);

    regmap_rx_data(0) <= rx_data_sys(31 downto 0);
    regmap_rx_data(1) <= rx_data_sys(63 downto 32);
    regmap_rx_data(2) <= rx_data_sys(95 downto 64);
    regmap_rx_data(3) <= rx_data_sys(127 downto 96);

    regmap_rx_datak(0) <= rx_datak_sys(3 downto 0);
    regmap_rx_datak(1) <= rx_datak_sys(7 downto 4);
    regmap_rx_datak(2) <= rx_datak_sys(11 downto 8);
    regmap_rx_datak(3) <= rx_datak_sys(15 downto 12);

    u_firefly_monitor : entity work.firefly_reg_mapping
        generic map (
            N_CHANNELS_g    => 8,
            CHANNEL_WIDTH_g => 32
        )
        port map (
            i_reg_add               => x"00" & i_mon_address,
            i_reg_re                => i_mon_read,
            o_reg_rdata             => mon_readdata,
            i_reg_we                => i_mon_write,
            i_reg_wdata             => i_mon_writedata,
            o_loopback              => rx_seriallpbken,
            o_tx_reset              => open,
            o_rx_reset              => open,
            o_lvds_align_reset_n    => open,
            i_tx_status             => tx_ready,
            i_tx_errors             => (others => '0'),
            i_lvds_controller_state => (others => '0'),
            i_rx_ready              => rx_ready,
            i_rx_lockedtoref        => rx_is_lockedtoref,
            i_rx_lockedtodata       => rx_is_lockedtodata,
            i_rx_locked             => rx_locked,
            i_rx_syncstatus         => regmap_rx_syncstatus,
            i_rx_errDetect          => regmap_rx_errdetect,
            i_rx_disperr            => regmap_rx_disperr,
            i_rx_fifo_error         => regmap_rx_fifo_error,
            i_lol_cnt               => regmap_rx_lol_cnt,
            i_err_cnt               => regmap_rx_err_cnt,
            i_rx_data               => regmap_rx_data,
            i_rx_datak              => regmap_rx_datak,
            i_gbit                  => regmap_rx_gbit,
            i_clk                   => i_clk_156,
            i_reset_n               => reset_156_n
        );

    process (i_clk_156)
    begin
        if rising_edge(i_clk_156) then
            if reset_156_n /= '1' then
                mon_readdatavalid <= '0';
            else
                mon_readdatavalid <= i_mon_read;
            end if;
        end if;
    end process;
end architecture rtl;

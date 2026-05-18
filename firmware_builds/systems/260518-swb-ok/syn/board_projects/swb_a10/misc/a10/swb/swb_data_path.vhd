-------------------------------------------------------
--! @swb_data_path.vhd
--! @brief the swb_data_path can be used
--! for the LCHb Board and the development board
--! mainly it includes the datapath which includes
--! merging hits from multiple FEBs.
--! Author: mkoeppel@uni-mainz.de
-------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

use work.a10_pcie_registers.all;
use work.mudaq.all;

entity swb_data_path is
generic (
    g_ADDR_WIDTH : positive := 11;
    g_NLINKS_DATA : integer := 8;
    g_LINK_SWB : std_logic_vector(3 downto 0) := "0000";
    g_gen_time_merger : boolean := true--;
);
port (
    -- link inputs
    i_rx                : in  work.mu3e.link32_array_t(g_NLINKS_DATA-1 downto 0) := (others => work.mu3e.LINK32_IDLE);
    i_rmask_n           : in  std_logic_vector(g_NLINKS_DATA-1 downto 0);

    -- pcie regs
    i_writeregs         : in  slv32_array_t(63 downto 0);

    -- chip lookup
    i_lookup_ctrl       : in  std_logic_vector(31 downto 0);

    -- counters
    o_counter           : out slv32_array_t(95 downto 0) := (others => (others => '0'));
    o_link_to_fifo_cnt  : out slv32_array_t(8*13-1 downto 0);

    -- farm data
    o_farm_data         : out work.mu3e.link32_t := work.mu3e.LINK32_IDLE;

    -- dma debug path
    i_rack_debug        : in  std_logic;
    o_data_debug        : out work.mu3e.link64_t;
    o_rempty_debug      : out std_logic;

    i_data_type         : in  std_logic_vector(5 downto 0) := MUPIX_HEADER_ID;

    i_resets_n          : in  std_logic_vector(31 downto 0);

    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

architecture arch of swb_data_path is

    --! data gen links
    signal gen_link, gen_link_error, gen_link_scifi, gen_test_data0, gen_test_data1 : work.mu3e.link32_t;

    --! data link signals
    signal rx : work.mu3e.link32_array_t(g_NLINKS_DATA-1 downto 0);
    signal rx_zero_suppressed : work.mu3e.link32_array_t(g_NLINKS_DATA-1 downto 0);
    signal rx_ren, rx_mask_n, rx_rdempty : std_logic_vector(g_NLINKS_DATA-1 downto 0) := (others => '0');
    signal rx_q : work.mu3e.link64_array_t(g_NLINKS_DATA-1 downto 0);

    --! stream merger
    signal stream_rdata, stream_rdata_debug : work.mu3e.link64_t;
    signal stream_counters : slv32_array_t(1 downto 0);
    signal stream_rempty, stream_ren, stream_en : std_logic;
    signal stream_rempty_debug, stream_ren_debug : std_logic;
    signal stream_rack : std_logic_vector(g_NLINKS_DATA-1 downto 0);

    --! timer merger
    signal merger_rdata : work.mu3e.link64_t;
    signal merger_counters : slv32_array_t(3 * (N_LINKS_TREE(3) + N_LINKS_TREE(2) + N_LINKS_TREE(1)) downto 0);
    signal merger_rdata_debug : work.mu3e.link64_t;
    signal merger_rempty, merger_ren, merger_header, merger_trailer, merger_error : std_logic;
    signal merger_rempty_debug, merger_ren_debug : std_logic;
    signal merger_rack : std_logic_vector(g_NLINKS_DATA-1 downto 0);

    --! links to farm
    signal farm_data : work.mu3e.link64_t;
    signal farm_rack, farm_rempty, farm_rempty_del0 : std_logic;

    --! status counters
    signal events_to_farm_cnt : std_logic_vector(31 downto 0);

    signal use_header_suppression : std_logic_vector(g_NLINKS_DATA-1 downto 0);
    signal use_subhdr_suppression : std_logic_vector(g_NLINKS_DATA-1 downto 0);

begin

    --! status counter
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! TODO: add this to counters
    -- tag_fifo_empty;
    -- dma_write_state;
    -- rx_rdempty;

    -- dma and farm counters
    o_counter(0) <= stream_counters(0);  --! e_stream_fifo full
    o_counter(1) <= stream_counters(1);  --! e_debug_stream_fifo almost full
    o_counter(2) <= (others => '0');
    o_counter(3) <= (others => '0');
    o_counter(4) <= (others => '0');
    o_counter(5) <= (others => '0');
    o_counter(6) <= events_to_farm_cnt;  --! events send to the farm
    o_counter(7) <= merger_counters(0);  --! e_debug_time_merger_fifo almost full
    o_counter(7 + 3 * (N_LINKS_TREE(3) + N_LINKS_TREE(2) + N_LINKS_TREE(1)) downto 8) <= merger_counters(3 * (N_LINKS_TREE(3) + N_LINKS_TREE(2) + N_LINKS_TREE(1)) downto 1);

    e_cnt_farm_events : entity work.counter
    generic map ( WRAP => true, W => 32 )
    port map ( o_cnt => events_to_farm_cnt, i_ena => farm_data.sop, i_reset_n => i_reset_n, i_clk => i_clk );


    --! data_generator_a10
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_data_gen_link : entity work.data_generator_a10
    generic map (
        DATA_TYPE => MUPIX_HEADER_ID,
        go_to_sh => 3,
        test_error => false,
        go_to_trailer => 4--,
    )
    port map (
        i_enable            => i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_GEN_LINK),
        i_seed              => (others => '1'),
        o_data              => gen_link,
        i_slow_down         => i_writeregs(DATAGENERATOR_DIVIDER_REGISTER_W),
        o_state             => open,

        i_reset_n           => i_resets_n(RESET_BIT_DATAGEN),
        i_clk               => i_clk--,
    );

    e_data_gen_different_type : entity work.data_generator_a10
    generic map (
        DATA_TYPE => SCIFI_HEADER_ID,
        go_to_sh => 3,
        test_error => false,
        go_to_trailer => 4--,
    )
    port map (
        i_enable            => i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_GEN_LINK),
        i_seed              => (others => '1'),
        o_data              => gen_link_scifi,
        i_slow_down         => i_writeregs(DATAGENERATOR_DIVIDER_REGISTER_W),
        o_state             => open,

        i_reset_n           => i_resets_n(RESET_BIT_DATAGEN),
        i_clk               => i_clk--,
    );

    e_data_gen_error_test : entity work.data_generator_a10
    generic map (
        DATA_TYPE => MUPIX_HEADER_ID,
        go_to_sh => 3,
        test_error => true,
        go_to_trailer => 4--,
    )
    port map (
        i_enable            => i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_GEN_LINK),
        i_seed              => (others => '1'),
        o_data              => gen_link_error,
        i_slow_down         => i_writeregs(DATAGENERATOR_DIVIDER_REGISTER_W),
        o_state             => open,

        i_reset_n           => i_resets_n(RESET_BIT_DATAGEN),
        i_clk               => i_clk--,
    );

    -- synthesis translate_off
        e_a10_real_data_gen : entity work.a10_real_data_gen
            port map (
            i_enable            => i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_TEST_DATA),
            o_data0             => gen_test_data0,
            o_data1             => gen_test_data1,
            i_slow_down         => i_writeregs(DATAGENERATOR_DIVIDER_REGISTER_W),

            i_reset_n           => i_resets_n(RESET_BIT_DATAGEN),
            i_clk               => i_clk--,
        );
    -- synthesis translate_on

    gen_link_data : FOR i in 0 to g_NLINKS_DATA - 1 GENERATE

        process(i_clk, i_reset_n)
        begin
        if ( i_reset_n /= '1' ) then
            rx(i) <= work.mu3e.LINK32_ZERO;
        elsif rising_edge(i_clk) then
            if ( i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_TEST_DATA) = '1' ) then
                if ( i mod 2 = 0) then
                    rx(i) <= work.mu3e.to_link(gen_test_data0.data, gen_test_data0.datak);
                else
                    rx(i) <= work.mu3e.to_link(gen_test_data1.data, gen_test_data1.datak);
                end if;
            elsif ( i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_GEN_LINK) = '1' ) then
                if ( i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_TEST_ERROR) = '1' and i = 0 ) then
                    rx(i) <= work.mu3e.to_link(gen_link_error.data, gen_link_error.datak);
                else
                    rx(i) <= work.mu3e.to_link(gen_link.data, gen_link.datak);
                end if;
            else
                rx(i) <= work.mu3e.to_link(i_rx(i).data, i_rx(i).datak);
            end if;
        end if;
        end process;

    END GENERATE;


    --! generate zero suppression
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------

    lbl: process(i_clk, i_reset_n) is
    begin
    if rising_edge(i_clk) then
        if ( i_reset_n = '0' ) then
            use_subhdr_suppression <= (others => '0');
            use_header_suppression <= (others => '0');
        else
            --use_header_suppression <= stream_en and i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_HEAD_SUPPRESS);
            --use_subhdr_suppression <= stream_en and i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_SUBHDR_SUPPRESS);
            for i in 0 to g_NLINKS_DATA - 1 loop
                use_header_suppression(i) <= stream_en and i_writeregs(SWB_SUBHEAD_SUPPRESS_REGISTER_W)(i);
                use_subhdr_suppression(i) <= stream_en and i_writeregs(SWB_HEAD_SUPPRESS_REGISTER_W)(i);
            end loop;
        end if;
    end if;
    end process;

    gen_zero_suppression : FOR i in 0 to g_NLINKS_DATA - 1 generate
        zero_suppression_inst: entity work.zero_suppression
        port map (
            i_ena_subh_suppression => use_subhdr_suppression(i),
            i_ena_head_suppression => use_header_suppression(i),
            i_data                 => rx(i),
            o_data                 => rx_zero_suppressed(i),
            i_reset_n              => i_reset_n,
            i_clk                  => i_clk--,
        );
    end generate;

    --! generate links_to_fifos
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    -- TODO: If its full stop --> tell MIDAS --> stop run --> no event mixing
    e_links_to_fifos : entity work.links_to_fifos
    generic map (
        g_LINK_N => g_NLINKS_DATA--,
    )
    port map (
        i_rx            => rx_zero_suppressed,
        i_rmask_n       => i_rmask_n,

        i_lookup_ctrl   => i_lookup_ctrl,
        i_sync_enable   => i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_FEB_SYNC),

        o_q             => rx_q,
        i_ren           => rx_ren,
        o_rdempty       => rx_rdempty,

        o_counter       => o_link_to_fifo_cnt(g_NLINKS_DATA*13-1 downto 0),
        i_reset_n_cnt   => i_resets_n(RESET_BIT_SWB_COUNTERS),

        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    --! stream merger
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_stream : entity work.swb_stream_merger
    generic map (
        g_ADDR_WIDTH => g_ADDR_WIDTH,
        N => g_NLINKS_DATA--,
    )
    port map (
        i_rdata     => rx_q,
        i_rempty    => rx_rdempty,
        i_rmask_n   => i_rmask_n,
        o_rack      => stream_rack,

        -- farm data
        o_wdata     => stream_rdata,
        o_rempty    => stream_rempty,
        i_ren       => stream_ren,

        -- data for debug readout
        o_wdata_debug   => stream_rdata_debug,
        o_rempty_debug  => stream_rempty_debug,
        i_ren_debug     => stream_ren_debug,

        o_counters  => stream_counters,

        i_en        => stream_en,
        i_reset_n   => i_resets_n(RESET_BIT_SWB_STREAM_MERGER),
        i_clk       => i_clk--,
    );
    stream_en <= '1' when not g_gen_time_merger else i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_STREAM);

    --! time merger
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    generate_time_merger : if ( g_gen_time_merger ) generate
        e_time_merger : entity work.swb_time_merger
        generic map (
            g_ADDR_WIDTH => g_ADDR_WIDTH,
            g_NLINKS_DATA => g_NLINKS_DATA,
            g_LINK_SWB => g_LINK_SWB--,
        )
        port map (
            i_rx            => rx_q,
            i_rempty        => rx_rdempty,
            i_rmask_n       => i_rmask_n,
            o_rack          => merger_rack,

            o_counters      => merger_counters,

            -- farm data
            o_wdata         => merger_rdata,
            o_rempty        => merger_rempty,
            i_ren           => merger_ren,

            -- data for debug readout
            o_wdata_debug   => merger_rdata_debug,
            o_rempty_debug  => merger_rempty_debug,
            i_ren_debug     => merger_ren_debug,

            o_error         => open,

            i_data_type     => i_data_type,

            i_en            => i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER),
            i_reset_n       => i_resets_n(RESET_BIT_SWB_TIME_MERGER),
            i_clk           => i_clk--,
        );
    end generate;

    --! readout switches
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    rx_ren          <=  not rx_rdempty when i_writeregs(SWB_ZERO_HISTOS_REGISTER_W)(0) = '1' else
                        stream_rack when stream_en = '1' else
                        merger_rack when i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER) = '1' else
                        (others => '0');

    o_data_debug    <=  stream_rdata_debug when stream_en = '1' else
                        merger_rdata_debug when i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER) = '1' else
                        work.mu3e.LINK64_ZERO;
    o_rempty_debug  <=  stream_rempty_debug when stream_en = '1' else
                        merger_rempty_debug when i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER) = '1' else
                        '0';
    stream_ren_debug <= i_rack_debug when stream_en = '1' else '0';
    merger_ren_debug <= i_rack_debug when i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER) = '1' else '0';

    farm_data       <=  stream_rdata when stream_en = '1' else
                        merger_rdata when i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER) = '1' else
                        work.mu3e.LINK64_ZERO;
    farm_rempty     <=  stream_rempty when stream_en = '1' else
                        merger_rempty when i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER) = '1' else
                        '0';
    stream_ren      <=  farm_rack when stream_en = '1' else '0';
    merger_ren      <=  farm_rack when i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER) = '1' else '0';

    --! generate farm output data
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        o_farm_data <= work.mu3e.LINK32_IDLE;
        farm_rack <= '0';
        --
    elsif rising_edge(i_clk) then
        o_farm_data <= work.mu3e.LINK32_IDLE;
        farm_rack <= '0';

        -- first cycle (rack is 0 and not empty):
        --      write low 32 bits and set rack to 1
        -- second cycle (rack is 1):
        --      write high 32 bit and set rack to 0
        if ( farm_rack = '0' and farm_rempty = '0' ) then
            o_farm_data <= work.mu3e.to_link(farm_data.data(31 downto 0), "000" & farm_data.k);
            farm_rack <= '1';
        elsif ( farm_rack = '1' ) then
            o_farm_data <= work.mu3e.to_link(farm_data.data(63 downto 32), "000" & "0");
        end if;
    end if;
    end process;

end architecture;

-- Mu3e Scifi Datapath
-- Marius Köppel, Konrad Briggle based on Simon Corrodi based on KIP DAQ
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;
use work.mutrig.all;
use work.sorter_pkg.all;
use work.mudaq.all;
use work.mutrig_hit_types.all;


entity scifi_datapath is
generic(
    N_INPUTSRX          : positive := 13;
    LVDS_PLL_FREQ       : real := 125.0;
    LVDS_DATA_RATE      : real := 1250.0;
    INPUT_SIGNFLIP      : std_logic_vector(31 downto 0):=x"00000000";
    C_ASICNO_PREFIX     : std_logic_vector(13*4-1 downto 0):=x"CBA9876543210"--;
);
port (
    -- RX part
    i_rst_rx                    : in  std_logic;    -- logic reset of lvds receivers (125MHz clock synced)
    i_data                      : in  std_logic_vector(N_INPUTSRX-1 downto 0);   -- serial data
    i_refclk_125_A              : in  std_logic;    -- ref clk for lvds pll (A-Side)
    i_refclk_125_B              : in  std_logic;    -- ref clk for lvds pll (B-Side)
    i_scifi_lvds_los_n	        : in std_logic_vector(7 downto 0);

    -- interface to asic fifos
    o_fifo_data                 : out std_logic_vector(71 downto 0);
    o_fifo_wr                   : out std_logic_vector(1 downto 0);
    i_common_fifos_almost_full  : in  std_logic_vector(1 downto 0);
    o_fifo_debug_data           : out std_logic_vector(71 downto 0);
    o_fifo_debug_wr             : out std_logic_vector(1 downto 0);
    i_debug_almost_full         : in  std_logic_vector(1 downto 0);

    -- slow control / monitoring
    i_SC_mutrig                 : in  work.mutrig_sc_types.t_sc_mutrig;
    o_SC_mutrig                 : out work.mutrig_sc_types.t_sc_mutrig;
    o_counters                  : out slv32_array_t(10 * 2 * N_INPUTSRX - 1 downto 0);
    o_ch_rate                   : out std_logic_vector(31 downto 0);

    -- slow control node
    mt_sorter_regs              : inout work.util.rw32_array_t(1 downto 0);

    -- run control
    i_RC_may_generate           : in  std_logic :='1'; --do not generate new frames for runstates that are not RUNNING, allows to let fifos run empty
    o_RC_all_done               : out std_logic; --all fifos empty, all data read
    i_run_state_125             : in  run_state_t;

    -- simulation input
    i_enablesim                 : in  std_logic := '0';
    i_simdata                   : in  std_logic_vector(8*N_INPUTSRX-1 downto 0) := (others => '0');
    i_simdatak                  : in  std_logic_vector(N_INPUTSRX-1 downto 0) := (others => '0');

    -- reset / clk
    i_reset_156_n               : in  std_logic;
    i_clk_156                   : in  std_logic;
    i_ts_rst                    : in  std_logic;
    i_reset_125_n               : in  std_logic;
    i_clk_125                   : in  std_logic--;
);
end entity;

architecture rtl of scifi_datapath is

    -- serdes-frame_rcv
    signal s_receivers_ready : std_logic_vector(N_INPUTSRX-1 downto 0);
    signal s_receivers_data, s_receivers_data_reg : std_logic_vector(8*N_INPUTSRX-1 downto 0);
    signal s_receivers_data_isk, s_receivers_data_isk_reg : std_logic_vector(N_INPUTSRX-1 downto 0);
    signal s_receivers_all_ready : std_logic;
    signal s_receivers_block : std_logic;

    -- frame_rcv/datagen - fifo: fifo side, frame-receiver side, dummy datagenerator side
    signal s_crc_error, s_rec_new_frame, s_rec_frame_info_rdy, s_rec_event_ready, s_rec_end_of_frame, s_frec_busy : std_logic_vector(N_INPUTSRX-1 downto 0);
    signal s_rec_frame_number, s_rec_frame_info : slv16_array_t(N_INPUTSRX-1 downto 0);
    signal s_rec_event_data, s_data : work.mutrig_hit_types.t_v_hit_presort(N_INPUTSRX-1 downto 0);
    signal s_data_ch : work.mutrig_hit_types.t_hit_presort;
    signal v_ch_rate : slv32_array_t(31 downto 0);
    signal s_any_framegen_busy : std_logic;

    -- data generator
    signal s_gen_event_data : work.mutrig_hit_types.t_v_hit_presort(N_INPUTSRX-1 downto 0);
    signal s_gen_busy : std_logic_vector(N_INPUTSRX-1 downto 0);

    -- mux
    signal s_mux_data, s_mux_q_debug, s_mux_data_debug, s_mux_data_prbs_t, s_mux_data_prbs_t_reg : work.mutrig_hit_types.t_v_hit_presort(3 downto 0);
    signal s_mux_wrfull_debug, s_mux_empty_debug, s_mux_rack_debug : std_logic_vector(3 downto 0);

    -- cc corrections
    signal s_CC_corrected : slv15_array_t(3 downto 0);

    -- sorter
    signal s_running : std_logic;
    signal s_counter125 : std_logic_vector(63 downto 0);
    signal s_mux_data_prbs_t_div : work.mutrig_hit_types.t_v_hit_presort_div(5 downto 0);
    signal tile_sorter_reg : work.util.rw_t;
    signal sorter_reset_n : std_logic := '1';

    -- sync fifo
    signal fifo_wdata, sync_fifo_wdata_out : std_logic_vector(71 downto 0);
    signal fifo_write, sync_fifo_empty, sync_fifo_write_out : std_logic_vector(1 downto 0);

    -- Mutrig Counters per ASIC N_INPUTSRX
    -- mutrig store:
    --  0: s_eventcounter
    --  1: s_timecounter low
    --  2: s_timecounter high
    --  3: s_crcerrorcounter
    --  4: s_framecounter
    --  5: s_prbs_wrd_cnt
    --  6: s_prbs_err_cnt
    -- rx
    --  7: s_receivers_runcounter
    --  8: s_receivers_errorcounter
    --  9: s_receivers_synclosscounter
    signal s_eventcounter               : slv32_array_t(N_INPUTSRX-1 downto 0);
    signal s_timecounter                : slv64_array_t(N_INPUTSRX-1 downto 0);
    signal s_crcerrorcounter            : slv32_array_t(N_INPUTSRX-1 downto 0);
    signal s_framecounter               : slv64_array_t(N_INPUTSRX-1 downto 0);
    signal s_prbs_wrd_cnt               : slv64_array_t(N_INPUTSRX-1 downto 0);
    signal s_prbs_err_cnt               : slv32_array_t(N_INPUTSRX-1 downto 0);
    signal s_receivers_runcounter       : slv32_array_t(N_INPUTSRX-1 downto 0);
    signal s_receivers_errorcounter     : slv32_array_t(N_INPUTSRX-1 downto 0);
    signal s_receivers_synclosscounter  : slv32_array_t(N_INPUTSRX-1 downto 0);

    -- signals for inputs / outputs
    signal RC_all_done : std_logic_vector(0 downto 0) := (others => '0');

begin

    --! output counter
    gen_counters : for i in 0 to N_INPUTSRX-1 generate
        o_counters(0+i*10) <= s_eventcounter(i);
        o_counters(1+i*10) <= s_timecounter(0)(31 downto 0); -- take only the first one
        o_counters(2+i*10) <= s_timecounter(0)(63 downto 32);
        o_counters(3+i*10) <= s_crcerrorcounter(i);
        o_counters(4+i*10) <= s_framecounter(i)(31 downto 0); -- we only take the low bits for now
        o_counters(5+i*10) <= s_prbs_wrd_cnt(i)(31 downto 0); -- we only take the low bits for now
        o_counters(6+i*10) <= s_prbs_err_cnt(i);
        o_counters(7+i*10) <= s_receivers_runcounter(i);
        o_counters(8+i*10) <= s_receivers_errorcounter(i);
        o_counters(9+i*10) <= s_receivers_synclosscounter(i);
    end generate;

    
    -- u_rxdeser: entity work.scifi_receiver_block
    -- generic map(
    --     NINPUT          => N_INPUTSRX,
    --     LVDS_PLL_FREQ   => LVDS_PLL_FREQ,
    --     LVDS_DATA_RATE  => LVDS_DATA_RATE,
    --     INPUT_SIGNFLIP  => INPUT_SIGNFLIP
    -- )
    -- port map(
    --     i_rx                => i_data,
    --     i_scifi_lvds_los_n  => i_scifi_lvds_los_n,

    --     i_rx_inclock        => i_refclk_125_A,

    --     i_SC_mutrig         => i_SC_mutrig,
    --     o_SC_mutrig         => o_SC_mutrig,

    --     o_rx_runcounter     => s_receivers_runcounter,
    --     o_rx_errorcounter   => s_receivers_errorcounter,
    --     o_rx_synclosscounter=> s_receivers_synclosscounter,

    --     o_rx_data           => s_receivers_data,
    --     o_rx_datak          => s_receivers_data_isk,
    --     o_rx_ready          => s_receivers_ready,

    --     i_reset_n           => not i_rst_rx,
    --     i_clk               => i_clk_125
    -- );
	-- synthesis read_comments_as_HDL on
    -- synthesis read_comments_as_HDL off

    -- generate a pll-synchronous all-ready signal for the data receivers.
    -- this assures all start dumping data into the fifos at the same time, and we do not enter a deadlock scenario from the start
    gen_ready_all : process (i_clk_125, i_rst_rx, s_receivers_ready, i_SC_mutrig.mask_rx)
    variable v_ready : std_logic_vector(N_INPUTSRX-1 downto 0);
    begin
    if ( i_rst_rx = '1' ) then
        s_receivers_all_ready <= '0';
        --
    elsif rising_edge(i_clk_125) then
        v_ready := s_receivers_ready or i_SC_mutrig.mask_rx(N_INPUTSRX-1 downto 0);
        if ( v_ready = ((v_ready'range)=>'1') ) then
            s_receivers_all_ready <= '1';
        end if;
        --
    end if;
    end process;

    -- if i_SC_mutrig.rx_wait_for_all is set, wait for all (not masked) receivers to become ready before letting any data pass through the frame unpacking blocks.
    -- if i_SC_mutrig.rx_wait_for_all_sticky is set in addition, the all_ready property is sticky: once all receivers become ready do not block data again.
    --            The sticky bit is cleared with i_reset
    --            Otherwise, data is blocked as soon as one receiver is loosing the pattern or sync.
    releasedata_p : process(i_clk_125, i_rst_rx)
    begin
    if rising_edge(i_clk_125) then
        if ( i_rst_rx = '1' ) then
            s_receivers_block <= '1';
            --
        elsif ( i_SC_mutrig.rx_wait_for_all_sticky = '1' ) then
            if(s_receivers_all_ready='1') then
                s_receivers_block <= '0';
            end if;
        else
            s_receivers_block <= not s_receivers_all_ready;
        end if;
        --
    end if;
    end process;

    gen_frame: for i in 0 to N_INPUTSRX-1 generate begin
        -- data generator
        u_data_dummy : entity work.mutrig_dummy_data
        generic map (
            ASIC_ID => C_ASICNO_PREFIX(4*i+3 downto i*4)--,
        )
        port map (
            -- reset / clock / enable
            i_reset             => not i_reset_125_n,
            i_clk               => i_clk_125,
            i_enable            => i_SC_mutrig.datagen_enable and i_RC_may_generate,

            -- slow control signals
            i_SC_mutrig         => i_SC_mutrig,

            -- stream of hits
            o_event_data        => s_gen_event_data(i),

            -- header information
            o_frame_number      => open,
            o_frame_info        => open,
            o_frame_info_rdy    => open,
            o_new_frame         => open,
            o_busy              => s_gen_busy(i),

            -- trailer information
            o_end_of_frame      => open--,
        );

        -- simulation data input
        process(i_clk_125, i_reset_125_n)
        begin
        if ( i_reset_125_n /= '1' ) then
            s_receivers_data_reg((i+1)*8-1 downto i*8) <= x"BC";
            s_receivers_data_isk_reg(i) <= '1';
            --
        elsif rising_edge(i_clk_125) then
            if ( i_enablesim = '0' ) then
                s_receivers_data_reg((i+1)*8-1 downto i*8) <= s_receivers_data((i+1)*8-1 downto i*8);
                s_receivers_data_isk_reg(i) <= s_receivers_data_isk(i);
            else
                s_receivers_data_reg((i+1)*8-1 downto i*8) <= i_simdata((i+1)*8-1 downto i*8);
                s_receivers_data_isk_reg(i) <= i_simdatak(i);
            end if;
            --
        end if;
        end process;

        -- mutrig frame unpacker
        u_frame_rcv : entity work.frame_rcv
        generic map (
            ASIC_ID => C_ASICNO_PREFIX(4*i+3 downto i*4)--,
        )
        port map (
            -- reset / clock / enable
            i_rst               => not i_reset_125_n,
            i_clk               => i_clk_125,
            i_enable            => i_RC_may_generate,-- and not (s_receivers_block or (not s_receivers_ready(i) and not i_SC_mutrig.rx_wait_for_all)),

            -- data from lvds receiver
            i_data              => s_receivers_data_reg((i+1)*8-1 downto i*8),
            i_byteisk           => s_receivers_data_isk_reg(i),

            -- stream of hits
            o_hits              => s_rec_event_data(i),

            -- mutrig header information
            o_frame_number      => s_rec_frame_number(i),
            o_frame_info        => s_rec_frame_info(i),
            o_frame_info_ready  => s_rec_frame_info_rdy(i),
            o_new_frame         => s_rec_new_frame(i),
            o_busy              => s_frec_busy(i),

            -- mutrig trailer information
            o_end_of_frame      => s_rec_end_of_frame(i),
            o_crc_error         => s_crc_error(i),
            o_crc_err_count     => open--,
        );

        -- multiplex between physical and generated data sent to the elastic buffers
        process(i_clk_125, i_reset_125_n)
        begin
        if ( i_reset_125_n /= '1' ) then
            s_data(i) <= work.mutrig_hit_types.t_hit_presort_zero;
            --
        elsif ( rising_edge(i_clk_125) ) then
            -- use busy from datagenerator to ensure safe takeover
            if ( i_SC_mutrig.datagen_enable = '1' or work.util.or_reduce(s_gen_busy) = '1') then
                s_data(i) <= s_gen_event_data(i);
            else
                s_data(i) <= s_rec_event_data(i);
            end if;
        end if;
        end process;
    end generate;

    e_channel_rate : entity work.ch_rate
    generic map(
        num_ch => 32
    )
    port map(
        i_hit       => s_data_ch,

        o_ch_rate   => v_ch_rate,

        i_clk       => i_clk_125,
        i_reset_n   => i_reset_125_n--,
    );
    s_data_ch <= s_data(to_integer(unsigned(i_SC_mutrig.asic_select)));
    o_ch_rate <= v_ch_rate(to_integer(unsigned(i_SC_mutrig.ch_select)));

    -- p_frec_busy_sync
    process(i_clk_125)
    begin
    if rising_edge(i_clk_125) then
        s_any_framegen_busy <= '0';
        if ( i_SC_mutrig.datagen_enable = '1' and work.util.or_reduce(s_gen_busy) = '1' ) then
            s_any_framegen_busy <= '1';
        end if;
        if ( i_SC_mutrig.datagen_enable='0' and work.util.or_reduce(s_gen_busy) = '1' ) then
            s_any_framegen_busy <= '1';
        end if;
    end if;
    end process;

    gen_sorter_path: for i in 0 to 1 generate begin

        -- set four 2->1 mux
        gen_mux: for j in 0 to 1 generate begin
            mux : entity work.channelmux
            generic map (
                NPORTS => 2--,
            )
            port map (
                i_clk   => i_clk_125,
                i_rst   => not i_reset_125_n,
                i_mask  => i_SC_mutrig.mask_rx((2 + (j+i*2)*2) - 1 downto (j+i*2)*2),
                i_data  => s_data((2 + (j+i*2)*2) - 1 downto (j+i*2)*2),
                o_data  => s_mux_data(j+i*2)--,
            );
        end generate;

        -- set prbs decoder
        e_prbs_t_presorter : entity work.prbs_decoder
        generic map (
            DECODE_E_A => false,
            DECODE_E_B => false--,
        )
        port map (
            -- system
            i_coreclk       => i_clk_125,
            i_rst           => not i_reset_125_n,
            o_initializing  => open,

            -- data stream input
            i_A_data        => s_mux_data(i*2),
            i_B_data        => s_mux_data(i*2+1),

            -- data stream output
            o_A_data        => s_mux_data_prbs_t(i*2),
            o_B_data        => s_mux_data_prbs_t(i*2+1),

            -- disable block (make transparent)
            i_SC_disable_dec => i_SC_mutrig.disable_dec--;
        );

        -- we set one sorter input to zero since sorter only takes multiple of 3
        s_mux_data_prbs_t_div(2+i*3) <= work.mutrig_hit_types.t_hit_presort_div_zero;

        gen_div_t: for j in 0 to 1 generate begin
            -- cc correction
            e_cc_correction : entity work.lapse_counter
            generic map (
                N_CC => 15--,
            )
            port map (
                i_clk               => i_clk_125,
                i_reset_n           => i_reset_125_n,
                i_CC                => s_mux_data_prbs_t(j+i*2).T_CC, -- TODO: add pipeline in lapse counter and dont put T_CC only in
                i_upper_bnd         => i_SC_mutrig.upper_bnd,
                i_lower_bnd         => i_SC_mutrig.lower_bnd,
                o_CC                => s_CC_corrected(j+i*2),
                o_cnt               => open--,
            );

            s_mux_data_prbs_t_reg(j+i*2).T_CC <= s_CC_corrected(j+i*2) when i_SC_mutrig.en_lapse_counter = '1' else s_mux_data_prbs_t(j+i*2).T_CC;
            s_mux_data_prbs_t_reg(j+i*2).channel <= s_mux_data_prbs_t(j+i*2).channel;
            s_mux_data_prbs_t_reg(j+i*2).E_CC <= s_mux_data_prbs_t(j+i*2).E_CC;
            s_mux_data_prbs_t_reg(j+i*2).T_Fine <= s_mux_data_prbs_t(j+i*2).T_Fine;
            s_mux_data_prbs_t_reg(j+i*2).valid <= s_mux_data_prbs_t(j+i*2).valid;
            s_mux_data_prbs_t_reg(j+i*2).asic <= s_mux_data_prbs_t(j+i*2).asic;

            -- divider from 1.6ns to 8ns
            e_div_t : entity work.T_CC_adapt
            port map (
                --system
                i_clk  => i_clk_125,
                i_rst  => not i_reset_125_n,

                --data stream
                i_data => s_mux_data_prbs_t_reg(j+i*2),
                o_data => s_mux_data_prbs_t_div(j+i*3)--,
            );
        end generate;

        scifi_sorter : entity work.hitsorter
        generic map(
            IS_SORTER_TWO => i,
            USE_TRIGGER_g => '0',
            NSORTERINPUTS => 3,
            -- NOTE: minus ISMUTRIG is not the best way to do this.
            --       we need this because the sorter is only designed for
            --       multiple of 3 inputs but we have 2 for Scifi
            --       at the moment this is not working for tile
            TIMESTAMPSIZE => 12,
            g_NOTSHITSIZE => len_hit_presort_div_no_ts,
            DATATYPE => MUTRIG,
            ISMUTRIG => 1
        )
        port map(
            -- run control and hit data input
            i_running       => s_running,
            i_currentts     => s_counter125(12-1 downto 0),
            i_hit           => s_mux_data_prbs_t_div(i*3+2 downto i*3),

            -- hit output
            data_out        => fifo_wdata((i+1)*36 - 5 downto i*36),
            out_ena         => fifo_write(i),
            out_type        => fifo_wdata((i+1)*36 - 1 downto i*36+32),
            out_is_hit      => open,

            -- slow control sorter register
            i_clk156        => i_clk_156,
            i_reset_n_regs  => i_reset_156_n,
            i_reg_add       => mt_sorter_regs(i).addr(15 downto 0),
            i_reg_re        => mt_sorter_regs(i).re,
            o_reg_rdata     => mt_sorter_regs(i).rdata,
            i_reg_we        => mt_sorter_regs(i).we,
            i_reg_wdata     => mt_sorter_regs(i).wdata,

            -- clk / reset
            i_reset_n       => sorter_reset_n,
            i_clk           => i_clk_125--,
        );

         -- sync some things ..
        sync_fifo_cnt : entity work.ip_dcfifo
        generic map (
            ADDR_WIDTH  => 4,
            DATA_WIDTH  => 1+36,
            SHOWAHEAD   => "OFF",
            DEVICE      => "Arria V",
            g_LPM_HINT => "RAM_BLOCK_TYPE=MLAB"--,
        )
        port map (
            data(36)            => fifo_write(i),
            data(35 downto 0)   => fifo_wdata((i+1)*36 - 1 downto i*36),
            wrreq               => '1',
            wrclk               => i_clk_125,

            rdreq               => '1',
            q(36)               => sync_fifo_write_out(i),
            q(35 downto 0)      => sync_fifo_wdata_out((i+1)*36 - 1 downto i*36),
            rdempty             => sync_fifo_empty(i),
            rdclk               => i_clk_156,

            aclr                => '0'--,
        );

        process(i_clk_156)
        begin
        if rising_edge(i_clk_156)  then
            if ( sync_fifo_empty(i) = '0' ) then
                o_fifo_data((i+1)*36 - 1 downto i*36) <= sync_fifo_wdata_out((i+1)*36 - 1 downto i*36);
                o_fifo_wr(i) <= sync_fifo_write_out(i);
            else
                o_fifo_wr(i) <= '0';
            end if;
        end if;
        end process;

        --------------------------
        ----- debug datapath -----
        --------------------------
        -- gen_fifo_sorter_replacement: for i in 0 to 2 generate begin
        --     -- buffer output of the mux for debug path
        --     process(i_clk_125, i_reset_125_n)
        --     begin
        --     if ( i_reset_125_n /= '1' ) then
        --         s_mux_data_debug(i) <= work.mutrig_hit_types.t_hit_presort_zero;
        --         --
        --     elsif ( rising_edge(i_clk_125) ) then
        --         if ( s_mux_wrfull_debug(i) = '0' ) then
        --             s_mux_data_debug(i) <= s_mux_data(i);
        --         else
        --             s_mux_data_debug(i) <= work.mutrig_hit_types.t_hit_presort_zero;
        --         end if;
        --     end if;
        --     end process;

        --     e_mux_debug_fifo : entity work.mutrig_rec1_scfifo
        --     generic map (
        --         g_ADDR_WIDTH => 8,
        --         g_WREG_N => 2,
        --         g_RREG_N => 2--,
        --     )
        --     port map (
        --         i_wdata         => s_mux_data_debug(i),
        --         i_we            => s_mux_data_debug(i).valid,
        --         o_wfull         => s_mux_wrfull_debug(i),

        --         o_rdata         => s_mux_q_debug(i),
        --         o_rempty        => s_mux_empty_debug(i),
        --         i_rack          => s_mux_rack_debug(i),

        --         i_clk           => i_clk_125,
        --         i_reset_n       => i_reset_125_n--,
        --     );
        -- end generate;

        -- e_sorter_replacement : entity work.sorter_replacement
        -- generic map (
        --         N => 3--,
        -- )
        -- port map (
        --     -- event data input in rec1 type
        --     i_data      => s_mux_q_debug,
        --     i_mask      => i_SC_mutrig.mask(2 downto 0),
        --     i_short     => i_SC_mutrig.datagen_shortmode,
        --     i_rempty    => s_mux_empty_debug,
        --     o_ren       => s_mux_rack_debug,

        --     -- event data output in 32bit
        --     o_data      => o_fifo_debug_data,
        --     i_wfull     => i_debug_almost_full,
        --     o_wen       => o_fifo_debug_wr,

        --     i_clk       => i_clk_125,
        --     i_ts_reset_n=> not i_ts_rst,
        --     i_reset_n   => i_reset_125_n--,
        -- );
        --------------------------
        ----- debug datapath -----
        --------------------------

    end generate;

    -- generate running signal for sorter
    process(i_clk_125, i_reset_125_n)
    begin
    if ( i_reset_125_n = '0' ) then
        s_counter125 <= (others => '0');
        s_running <= '0';
        sorter_reset_n <= '0';
        --
    elsif ( rising_edge(i_clk_125) ) then
        -- run state running
        if ( i_run_state_125 = RUN_STATE_RUNNING ) then
            s_running <= '1';
        else
            s_running <= '0';
        end if;

        -- reset sorter
        if ( i_run_state_125 = RUN_STATE_IDLE ) then
            sorter_reset_n  <= '0';
        else
            sorter_reset_n  <= '1';
        end if;

        -- count current time
        if ( i_run_state_125 = RUN_STATE_SYNC ) then
            s_counter125 <= (others => '0');
        else
            s_counter125 <= s_counter125 + '1';
        end if;
        --
    end if;
    end process;

    -- p_RC_all_done
    process(i_clk_125)
    begin
    if rising_edge(i_clk_125) then
        if( s_any_framegen_busy = '0') then
            RC_all_done(0) <='1';
        else
            RC_all_done(0) <= '0';
        end if;
    end if;
    end process;

    e_sync_RC_all_done : entity work.ff_sync
    generic map ( W => RC_all_done'length )
    port map (
        i_d => RC_all_done, o_q(0) => o_RC_all_done,
        i_reset_n => i_reset_156_n, i_clk => i_clk_156--,
    );

end architecture;

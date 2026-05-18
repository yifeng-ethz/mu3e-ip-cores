--
-- Marius Koeppel, November 2020
--
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.util_slv.all;
use work.mudaq.all;


entity swb_midas_event_builder is
port (
    i_rx                : in  work.mu3e.link64_t;
    i_rempty            : in  std_logic;
    i_use_sop_type      : in  std_logic := '0';
    i_event_id          : in  std_logic_vector(31 downto 0);
    i_get_serial_number : in  std_logic_vector(31 downto 0);

    i_get_n_words       : in  std_logic_vector(31 downto 0);
    i_dmamemhalffull    : in  std_logic;
    i_wen               : in  std_logic;
    o_data              : out std_logic_vector(255 downto 0);
    o_wen               : out std_logic;
    o_ren               : out std_logic;
    o_dma_cnt_words     : out std_logic_vector(31 downto 0);
    o_serial_num        : out std_logic_vector(31 downto 0);
    o_endofevent        : out std_logic;
    o_done              : out std_logic;
    o_state_out         : out std_logic_vector(3 downto 0);

    o_counters          : out slv32_array_t(3 downto 0);

    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

architecture arch of swb_midas_event_builder is

    -- tagging fifo
    type event_tagging_state_type is (
        event_head_num, event_time_size, bank_size_flags,
        bank_name_type, bank_reserved_length, bank_data, bank_set_length,
        DEBUG_bank_type_name, DEBUG_bank_reserved_length, DEBUG_bank_data_0,
        DEBUG_bank_data_1, DEBUG_bank_data_2, set_algin_word, DEBUG_bank_set_length,
        event_set_size, bank_set_size, write_tagging_fifo, EVENT_IDLE--,
    );
    signal event_tagging_state : event_tagging_state_type;
    signal e_size_addr, b_size_addr, b_length_addr, w_ram_add_reg, w_ram_addr, last_event_addr, align_event_size : std_logic_vector(10 downto 0);
    signal w_fifo_data, r_fifo_data : std_logic_vector(11 downto 0);
    signal w_fifo_en, r_fifo_en, tag_fifo_empty, tag_fifo_full, is_error, is_error_q, tag_almost_full, saw_data : std_logic;

    -- ram
    signal w_ram_en : std_logic;
    signal r_ram_addr : std_logic_vector(8 downto 0);
    signal w_ram_data : std_logic_vector(63 downto 0);
    signal r_ram_data : std_logic_vector(255 downto 0);

    -- midas event
    signal event_id, trigger_mask, shead_cnt, package_counter, ts_low : std_logic_vector(15 downto 0);
    signal header_cnt : std_logic_vector(7 downto 0);
    signal serial_number, time_cnt, time_cnt_reg, type_bank, flags, bank_size_cnt, event_size_cnt : std_logic_vector(31 downto 0);
    signal header, debug0, debug1, ts_high : std_logic_vector(31 downto 0);

    -- event readout state machine
    type event_counter_state_type is (waiting, get_data, set_serial_number, runing, skip_event, wait_last_word, write_4kb_padding);
    signal event_counter_state : event_counter_state_type;
    signal done, word_counter_written : std_logic;
    signal event_last_ram_addr : std_logic_vector(8 downto 0);
    signal tag_wrusedw : std_logic_vector(12 - 1 downto 0);
    signal word_counter, word_counter_endofevent, cnt_4kb : std_logic_vector(31 downto 0);

    -- counters
    signal cnt_skip_event_dma, cnt_event_dma, cnt_hits : std_logic_vector(31 downto 0);

    signal reset_n : std_logic;

begin

    e_reset_n : entity work.ff_sync
    port map ( o_q(0) => reset_n, i_d(0) => '1', i_reset_n => i_reset_n, i_clk => i_clk );

    --! set output done
    o_done <= done;

    --! counter
    o_counters(0) <= cnt_hits;
    o_counters(1) <= cnt_skip_event_dma;
    o_counters(2) <= cnt_event_dma;
    e_cnt_tag_fifo : entity work.counter
    generic map ( WRAP => true, W => 32 )
    port map ( o_cnt => o_counters(3), i_ena => tag_fifo_full, i_reset_n => reset_n, i_clk => i_clk );

    --! data out
    o_data <= (others => '1')                                                       when event_counter_state = write_4kb_padding and is_error_q = '0' else
              r_ram_data(255 downto 64) & serial_number & r_ram_data(31 downto 0)   when event_counter_state = set_serial_number else
              r_ram_data;
    o_serial_num <= serial_number;

    e_ram_64_256 : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => 11,
        g_ADDR1_WIDTH => 9,
        g_DATA0_WIDTH => 64,
        g_DATA1_WIDTH => 256--,
    )
    port map (
        i_addr0     => w_ram_addr,
        i_addr1     => r_ram_addr,
        i_clk0      => i_clk,
        i_clk1      => i_clk,
        i_wdata0    => w_ram_data,
        i_wdata1    => (others => '0'),
        i_we0       => w_ram_en,
        i_we1       => '0',
        o_rdata0    => open,
        o_rdata1    => r_ram_data--,
    );

    e_tagging_fifo_event : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 12,
        g_DATA_WIDTH => 12--,
    )
    port map (
        i_we        => w_fifo_en,
        i_wdata     => w_fifo_data,
        o_wfull     => tag_fifo_full,

        i_rack      => r_fifo_en,
        o_rdata     => r_fifo_data,
        o_rempty    => tag_fifo_empty,

        o_usedw     => tag_wrusedw,

        i_reset_n   => reset_n,
        i_clk       => i_clk--,
    );

    process(i_clk, reset_n)
    begin
    if ( reset_n /= '1' ) then
        tag_almost_full <= '0';
    elsif rising_edge(i_clk) then
        if ( tag_wrusedw(12 - 1) = '1' ) then
            tag_almost_full <= '1';
        else
            tag_almost_full <= '0';
        end if;
    end if;
    end process;

    o_ren <=
        '1' when ( event_tagging_state = bank_data and i_rempty = '0' ) else
        '1' when ( event_tagging_state = EVENT_IDLE and i_rempty = '0' and i_rx.sop = '0' ) else
        '0';

    -- write link data to event ram
    process(i_clk, reset_n)
    begin
    if ( reset_n = '0' ) then
        e_size_addr         <= (others => '0');
        b_size_addr         <= (others => '0');
        b_length_addr       <= (others => '0');
        w_ram_add_reg       <= (others => '0');
        last_event_addr     <= (others => '0');
        align_event_size    <= (others => '0');
        header_cnt          <= (others => '0');
        shead_cnt           <= (others => '0');
        header              <= (others => '0');

        -- ram and tagging fifo write signals
        w_ram_en            <= '0';
        w_ram_data          <= (others => '0');
        w_ram_addr          <= (others => '1');
        w_fifo_en           <= '0';
        saw_data            <= '0';
        w_fifo_data         <= (others => '0');
        is_error            <= '0';

        -- midas signals
        event_id            <= x"0001";
        trigger_mask        <= (others => '0');
        time_cnt            <= (others => '0');
        flags               <= x"00000031";
        type_bank           <= x"00000006"; -- MIDAS Bank Type TID_DWORD

        -- for size counting in bytes
        bank_size_cnt       <= (others => '0');
        event_size_cnt      <= (others => '0');
        cnt_hits            <= (others => '0');
        cnt_event_dma       <= (others => '0');

        -- state machine singals
        event_tagging_state <= EVENT_IDLE;
        --
    elsif rising_edge(i_clk) then
        flags           <= x"00000031";
        trigger_mask    <= i_event_id(31 downto 16);
        event_id        <= i_event_id(15 downto 0);
        type_bank       <= x"00000006";
        w_ram_en        <= '0';
        w_fifo_en       <= '0';

        if ( event_tagging_state /= EVENT_IDLE ) then
            -- count time for midas event header
            time_cnt <= time_cnt + '1';
        end if;

        case event_tagging_state is

        when EVENT_IDLE =>
            -- start if at least one not masked link has data
            if ( i_rempty = '0' and i_rx.sop = '1' ) then
                if ( tag_almost_full = '1' ) then
                    event_tagging_state <= EVENT_IDLE;
                else
                    event_tagging_state <= event_head_num;
                end if;
            end if;

        when event_head_num =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_data          <= x"00000000" & trigger_mask & event_id;
            last_event_addr     <= w_ram_addr + 1;
            event_tagging_state <= event_time_size;

        when event_time_size =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            e_size_addr         <= w_ram_addr + 1;
            time_cnt_reg        <= time_cnt;
            w_ram_data          <= (others => '0');
            event_tagging_state <= bank_size_flags;

        when bank_size_flags =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            b_size_addr         <= w_ram_addr + 1;
            w_ram_data          <= flags & x"00000000";
            event_size_cnt      <= event_size_cnt + 8;
            event_tagging_state <= bank_name_type;

        when bank_name_type =>
            -- here we check if the link is empty and if we saw a header
            if ( i_rempty = '0' and i_rx.sop = '1' ) then
                w_ram_en    <= '1';
                w_ram_addr  <= w_ram_addr + 1;
                header <= i_rx.data(31 downto 0);
                if ( i_rx.data(31 downto 26) = MUPIX_HEADER_ID or i_rx.data(31 downto 26) = OUTER_HEADER_ID ) then
                    w_ram_data <= type_bank & DebugPixelHitSWB;
                elsif ( i_rx.data(31 downto 26) = SCIFI_HEADER_ID ) then
                    w_ram_data <= type_bank & DebugFibreHitSWB;
                elsif ( i_rx.data(31 downto 26) = TILE_HEADER_ID ) then
                    w_ram_data <= type_bank & DebugTileHitDownstream;
                elsif ( i_rx.data(31 downto 26) = GENERIC_HEADER_ID ) then
                    w_ram_data <= type_bank & DebugGenHitSWB;
                else
                    w_ram_data <= type_bank & NONEBankName;
                end if;
                event_size_cnt <= event_size_cnt + 8;
                event_tagging_state <= bank_reserved_length;
            end if;

        when bank_reserved_length =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            b_length_addr       <= w_ram_addr + 1;
            w_ram_data          <= (others => '0');
            event_size_cnt      <= event_size_cnt + 8;
            event_tagging_state <= bank_data;

        when bank_data =>
            -- check again if the fifo is empty
            if ( i_rempty = '0' ) then
                if ( i_rx.err = '1' ) then
                    is_error <= '1';
                    w_ram_en <= '1';
                    w_ram_addr <= w_ram_addr + 1;
                    event_tagging_state <= bank_set_length;
                    w_ram_data <= (others => '0'); -- TODO: what to write in this case?
                    event_size_cnt <= event_size_cnt + 8;
                    bank_size_cnt <= bank_size_cnt + 8;
                end if;
                if ( i_rx.dthdr = '1' ) then
                    saw_data <= '1';
                    w_ram_en <= '1';
                    w_ram_data <= i_rx.data;
                    w_ram_addr <= w_ram_addr + 1;
                    event_size_cnt <= event_size_cnt + 8;
                    bank_size_cnt <= bank_size_cnt + 8;
                    cnt_hits <= cnt_hits + 1;
                elsif ( i_rx.t0 = '1' ) then
                    ts_high <= i_rx.data(31 downto 0);
                elsif ( i_rx.t1 = '1' ) then
                    ts_low <= i_rx.data(31 downto 16);
                    package_counter <= i_rx.data(15 downto 0);
                elsif ( i_rx.d0 = '1' ) then
                    debug0 <= i_rx.data(31 downto 0);
                elsif ( i_rx.d1 = '1' ) then
                    debug1 <= i_rx.data(31 downto 0);
                elsif ( i_rx.eop = '1' ) then
                    shead_cnt <= i_rx.data(23 downto 8);
                    header_cnt <= i_rx.data(31 downto 24);
                    event_tagging_state <= bank_set_length;
                    cnt_event_dma <= cnt_event_dma + '1';
                end if;
            end if;

        when bank_set_length =>
            saw_data <= '0';
            if ( saw_data = '0' and is_error = '0' ) then
                event_size_cnt <= (others => '0');
                bank_size_cnt <= (others => '0');
                w_ram_addr <= last_event_addr - 1;
                event_tagging_state <= EVENT_IDLE;
            else
                w_ram_en            <= '1';
                w_ram_addr          <= b_length_addr;
                w_ram_add_reg       <= w_ram_addr;
                w_ram_data          <= x"00000000" & bank_size_cnt;
                bank_size_cnt       <= (others => '0');
                event_tagging_state <= DEBUG_bank_type_name;
            end if;

        when DEBUG_bank_type_name =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_add_reg + 1;
            event_size_cnt      <= event_size_cnt + 8;
            -- bank name DebugSwmINfo (DSIN)
            w_ram_data          <= type_bank & x"4E495344";
            event_tagging_state <= DEBUG_bank_reserved_length;

        when DEBUG_bank_reserved_length =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            b_length_addr       <= w_ram_addr + 1;
            w_ram_data          <= (others => '0');
            event_size_cnt      <= event_size_cnt + 8;
            event_tagging_state <= DEBUG_bank_data_0;

        when DEBUG_bank_data_0 =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_data          <= ts_high & header;
            event_size_cnt      <= event_size_cnt + 8;
            bank_size_cnt       <= bank_size_cnt + 8;
            event_tagging_state <= DEBUG_bank_data_1;

        when DEBUG_bank_data_1 =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_data          <= debug0 & ts_low & package_counter;
            event_size_cnt      <= event_size_cnt + 8;
            bank_size_cnt       <= bank_size_cnt + 8;
            event_tagging_state <= DEBUG_bank_data_2;

        when DEBUG_bank_data_2 =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_data          <= x"00" & header_cnt & shead_cnt & debug1;
            event_size_cnt      <= event_size_cnt + 8;
            bank_size_cnt       <= bank_size_cnt + 8;
            align_event_size    <= w_ram_addr + 1 - last_event_addr;
            event_tagging_state <= set_algin_word;

        -- when set_algin_word =>
        --     -- check if the size of the bank data
        --     -- is in 256 bit
        --     -- if not add a dummy words
        --     if ( align_event_size(1 downto 0) + '1' = "00" ) then
        --         event_tagging_state <= DEBUG_bank_set_length;
        --     end if;
        --     bank_size_cnt <= bank_size_cnt + 8;
        --     event_size_cnt <= event_size_cnt + 8;
        --     w_ram_en <= '1';
        --     w_ram_addr <= w_ram_addr + 1;
        --     w_ram_add_reg <= w_ram_addr + 1;
        --     w_ram_data <= x"AFFEAFFE" & x"AFFEAFFE";
        --     align_event_size <= align_event_size + 1;

        when set_algin_word =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_add_reg       <= w_ram_addr + 1;
            w_ram_data          <= x"AFFEAFFE" & x"AFFEAFFE";
            align_event_size    <= align_event_size + 1;
            -- check if the size of the bank data
            -- is in 256 bit
            -- if not add a dummy words
            if ( align_event_size(1 downto 0) + '1' = "00" ) then
                event_tagging_state <= DEBUG_bank_set_length;
            else
                bank_size_cnt   <= bank_size_cnt + 8;
                event_size_cnt  <= event_size_cnt + 8;
            end if;

        when DEBUG_bank_set_length =>
            w_ram_en            <= '1';
            w_ram_addr          <= b_length_addr;
            w_ram_data          <= x"00000000" & bank_size_cnt;
            bank_size_cnt       <= (others => '0');
            event_tagging_state <= event_set_size;

        when event_set_size =>
            w_ram_en            <= '1';
            w_ram_addr          <= e_size_addr;
            -- Event Data Size: The event data size contains the size of the event in bytes excluding the event header
            w_ram_data          <= event_size_cnt & time_cnt_reg;
            event_tagging_state <= bank_set_size;

        when bank_set_size =>
            w_ram_en            <= '1';
            w_ram_addr          <= b_size_addr;
            -- All Bank Size : Size in bytes of the following data banks including their bank names
            w_ram_data          <= flags & event_size_cnt - 8;
            event_size_cnt      <= (others => '0');
            event_tagging_state <= write_tagging_fifo;

        when write_tagging_fifo =>
            w_fifo_en           <= '1';
            if ( is_error = '1' ) then
                w_fifo_data     <= '1' & w_ram_add_reg;
            else
                w_fifo_data     <= '0' & w_ram_add_reg;
            end if;
            last_event_addr     <= w_ram_add_reg;
            w_ram_addr          <= w_ram_add_reg - 1;
            event_tagging_state <= EVENT_IDLE;
            b_length_addr       <= (others => '0');

        when others =>
            event_tagging_state <= EVENT_IDLE;

        end case;

    end if;
    end process;


    -- dma end of events, count events and write control
    process(i_clk, reset_n)
    begin
    if ( reset_n = '0' ) then
        o_wen               <= '0';
        done                <= '0';
        o_endofevent        <= '0';
        word_counter_written<= '0';
        o_state_out         <= x"A";
        cnt_skip_event_dma  <= (others => '0');
        serial_number       <= (others => '0');
        r_fifo_en           <= '0';
        is_error_q          <= '0';
        r_ram_addr          <= (others => '1');
        event_last_ram_addr <= (others => '0');
        event_counter_state <= waiting;
        word_counter        <= (others => '0');
        o_dma_cnt_words     <= (others => '0');
        word_counter_endofevent <= (others => '0');
        --
    elsif rising_edge(i_clk) then

        r_fifo_en       <= '0';
        o_wen           <= '0';
        o_endofevent    <= '0';

        if ( i_wen = '0' ) then
            word_counter <= (others => '0');
            done <= '0';
            word_counter_written <= '0';
        end if;

        case event_counter_state is
        when waiting =>
            o_state_out             <= x"1";
            if ( i_wen = '1' and tag_fifo_empty = '0' and i_get_n_words /= 0 and done = '0' and i_dmamemhalffull = '0' ) then
                if ( word_counter_written = '0' ) then
                    word_counter            <= i_get_n_words;
                    serial_number           <= i_get_serial_number;
                    word_counter_written    <= '1';
                end if;
                r_fifo_en           <= '1';
                event_last_ram_addr <= r_fifo_data(10 downto 2);
                is_error_q          <= r_fifo_data(11);
                r_ram_addr          <= r_ram_addr + '1';
                event_counter_state <= get_data;
            elsif ( tag_fifo_empty = '0' ) then
                event_counter_state <= skip_event;
                r_fifo_en           <= '1';
                event_last_ram_addr <= r_fifo_data(10 downto 2);
                is_error_q          <= r_fifo_data(11);
                r_ram_addr          <= r_ram_addr + '1';
                cnt_skip_event_dma  <= cnt_skip_event_dma + '1';
            end if;

        when get_data =>
            o_state_out <= x"2";
            o_wen <= i_wen;
            if ( word_counter /= 0 ) then
                word_counter <= word_counter - '1';
            end if;
            word_counter_endofevent <= word_counter_endofevent + '1';
            event_counter_state     <= set_serial_number;
            r_ram_addr <= r_ram_addr + '1';

        when set_serial_number =>
            o_state_out <= x"3";
            serial_number <= serial_number + '1';
            o_wen <= i_wen;
            if ( word_counter /= 0 ) then
                word_counter <= word_counter - '1';
            end if;
            word_counter_endofevent <= word_counter_endofevent + '1';
            event_counter_state     <= runing;
            if(r_ram_addr = event_last_ram_addr - '1') then
                if ( is_error_q = '1' or word_counter = 0 ) then
                    event_counter_state <= wait_last_word;
                    cnt_4kb             <= (others => '0');
                else
                    event_counter_state <= waiting;
                end if;
            else
                r_ram_addr <= r_ram_addr + '1';
            end if;

        when runing =>
            o_state_out <= x"4";
            o_wen <= i_wen;
            if ( word_counter /= 0 ) then
                word_counter <= word_counter - '1';
            end if;
            word_counter_endofevent <= word_counter_endofevent + '1';
            if(r_ram_addr = event_last_ram_addr - '1') then
                if ( is_error_q = '1' or word_counter = 0 ) then
                    event_counter_state <= wait_last_word;
                    cnt_4kb             <= (others => '0');
                else
                    event_counter_state <= waiting;
                end if;
            else
                r_ram_addr <= r_ram_addr + '1';
            end if;

        when wait_last_word =>
            o_state_out             <= x"4";
            o_endofevent        <= '1'; -- end of last event
            event_counter_state <= write_4kb_padding;

        when write_4kb_padding =>
            o_state_out <= x"5";
            if ( is_error_q = '1' ) then
                is_error_q <= '0';
            else
                o_wen       <= i_wen;
                if ( cnt_4kb = "01111111" ) then
                    done <= '1';
                    o_dma_cnt_words <= word_counter_endofevent;
                    event_counter_state <= waiting;
                else
                    cnt_4kb <= cnt_4kb + '1';
                end if;
            end if;

        when skip_event =>
            o_state_out <= x"6";
            if(r_ram_addr = event_last_ram_addr - '1') then
                event_counter_state <= waiting;
            else
                r_ram_addr <= r_ram_addr + '1';
            end if;

        when others =>
            o_state_out <= x"7";
            event_counter_state <= waiting;

        end case;

    end if;
    end process;

end architecture;

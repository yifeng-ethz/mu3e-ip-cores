-----------------------------------------------------------------------------
-- Handling of the data flow for the farm PCs
--
-- Niklaus Berger, JGU Mainz
-- niberger@uni-mainz.de
-- Marius Koeppel, JGU Mainz
-- mkoeppel@uni-mainz.de
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;

entity farm_data_path is
generic (
    RAM_ADDR_R : positive :=  18--;
);
port (
    -- Input from merging (first board) or links (subsequent boards)
    i_data              : in  std_logic_vector(511 downto 0);
    i_data_en           : in  std_logic;
    i_ts                : in  std_logic_vector(31 downto 0);
    o_ddr_ready         : out std_logic;
    i_err               : in  std_logic;
    i_sop               : in  std_logic;
    i_eop               : in  std_logic;

    -- request sub headers from DDR memory
    i_ts_req_A          : in  std_logic_vector(31 downto 0);
    i_req_en_A          : in  std_logic;
    i_ts_req_B          : in  std_logic_vector(31 downto 0);
    i_req_en_B          : in  std_logic;

    -- dynamic limit when we change from writing to reading
    i_tsblock_done      : in  std_logic_vector(15 downto 0);
    o_tsblocks          : out std_logic_vector(31 downto 0);

    -- Output to DMA
    o_dma_data          : out std_logic_vector(255 downto 0);
    o_dma_wren          : out std_logic;
    o_dma_eoe           : out std_logic;
    i_dmamemhalffull    : in  std_logic;
    i_num_req_events    : in  std_logic_vector(31 downto 0);
    o_dma_done          : out std_logic;
    i_dma_wen           : in  std_logic;

    --! status counters
    --! 0: cnt_skip_event_dma
    --! 1: A_almost_full
    --! 2: B_almost_full
    --! 3: i_dmamemhalffull
    o_counters          : out work.util_slv.slv32_array_t(3 downto 0);

    -- Interface to memory bank A
    A_mem_calibrated    : in  std_logic;
    A_mem_ready         : in  std_logic;
    A_mem_addr          : out std_logic_vector(25 downto 0);
    A_mem_data          : out std_logic_vector(511 downto 0);
    A_mem_write         : out std_logic;
    A_mem_read          : out std_logic;
    A_mem_q             : in  std_logic_vector(511 downto 0);
    A_mem_q_valid       : in  std_logic;

    -- Interface to memory bank B
    B_mem_calibrated    : in  std_logic;
    B_mem_ready         : in  std_logic;
    B_mem_addr          : out std_logic_vector(25 downto 0);
    B_mem_data          : out std_logic_vector(511 downto 0);
    B_mem_write         : out std_logic;
    B_mem_read          : out std_logic;
    B_mem_q             : in  std_logic_vector(511 downto 0);
    B_mem_q_valid       : in  std_logic;

    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

architecture rtl of farm_data_path is

    type mem_mode_type is (disabled, ready, writing, reading);
    signal mem_mode_A, mem_mode_B : mem_mode_type;

    type ddr3if_type is (disabled, ready, writing, reading, overwriting);
    signal ddr3if_state_A, ddr3if_state_B : ddr3if_type;

    signal A_tsrange, B_tsrange, tsupper_last_A, tsupper_last_B : tsrange_type;

    signal A_writestate, B_writestate, A_readstate, B_readstate, A_done, B_done : std_logic;
    signal tofifo_A, tofifo_B : dataplusts_type;
    signal A_data, B_data : std_logic_vector(527 downto 0);

    signal writefifo_A, writefifo_B, A_fifo_empty, B_fifo_empty, A_fifo_empty_last, B_fifo_empty_last : std_logic;
    signal A_reqfifo_empty, B_reqfifo_empty, A_tagram_write, B_tagram_write : std_logic;
    signal A_tagram_data, A_tagram_q, B_tagram_data, B_tagram_q : std_logic_vector(31 downto 0);
    signal A_tagram_address, B_tagram_address : tsrange_type;

    signal A_mem_addr_reg, A_mem_addr_tag, B_mem_addr_reg, B_mem_addr_tag : std_logic_vector(25 downto 0);

    signal readfifo_A, readfifo_B, A_wstarted, B_wstarted, A_wstarted_last, B_wstarted_last : std_logic;
    signal qfifo_A, qfifo_B : dataplusts_type;
    signal A_tagts_last, B_tagts_last : tsrange_type;
    signal A_numwords, B_numwords : std_logic_vector(5 downto 0);

    signal A_readreqfifo, B_readreqfifo : std_logic;
    signal A_ts_req, A_ts_req_last, B_ts_req, B_ts_req_last : tsrange_type;

    type readsubstate_type is (fifowait, tagmemwait_1, tagmemwait_2, tagmemwait_3, reading);
    signal A_readsubstate, B_readsubstate : readsubstate_type;
    signal A_readwords, B_readwords : std_logic_vector(5 downto 0);

    signal A_memreadfifo_data, A_memreadfifo_q, B_memreadfifo_data, B_memreadfifo_q : std_logic_vector(21 downto 0);
    signal A_memreadfifo_write, A_memreadfifo_read, B_memreadfifo_write, B_memreadfifo_read: std_logic;
    signal A_memreadfifo_empty, B_memreadfifo_empty: std_logic;

    signal A_memdatafifo_empty, B_memdatafifo_empty, A_memdatafifo_read, B_memdatafifo_read: std_logic;
    signal A_memdatafifo_q, B_memdatafifo_q : std_logic_vector(255 downto 0);

    type output_write_type is (waiting, eventA, eventB, skip_event_A, skip_event_B, write_4kb_padding);
    signal output_write_state : output_write_type;
    signal nummemwords : std_logic_vector(6 downto 0);
    signal tagmemwait_3_state : std_logic_vector(3 downto 0);

    signal sync_A_empty, sync_B_empty : std_logic;

    signal ddr_ready_A, ddr_ready_B, sync_ddr_A_empty, sync_ddr_B_empty, sync_ddr_A_q, sync_ddr_B_q : std_logic;

    signal ts_in_upper, ts_in_lower, ts_in_upper_A, ts_in_upper_B : tsrange_type;

    signal A_almost_full, B_almost_full, A_disabled, B_disabled, cnt_4kb_done : std_logic;
    signal A_mem_word_cnt, B_mem_word_cnt : std_logic_vector(5 downto 0);
    signal cnt_skip_event_dma, cnt_num_req_events : std_logic_vector(31 downto 0);
    signal cnt_4kb : std_logic_vector(7 downto 0);

begin

    --! counters
    o_counters(0) <= cnt_skip_event_dma;

    e_a_almost_full : entity work.counter
    generic map ( WRAP => true, W => 32 )
    port map ( o_cnt => o_counters(1), i_ena => A_almost_full, i_reset_n => i_reset_n, i_clk => i_clk );

    e_b_almost_full : entity work.counter
    generic map ( WRAP => true, W => 32 )
    port map ( o_cnt => o_counters(2), i_ena => B_almost_full, i_reset_n => i_reset_n, i_clk => i_clk );

    e_dmamemhalffull : entity work.counter
    generic map ( WRAP => true, W => 32 )
    port map ( o_cnt => o_counters(3), i_ena => i_dmamemhalffull, i_reset_n => i_reset_n, i_clk => i_clk );


    --! backpressure to bank builder
    A_almost_full <= '1' when A_mem_addr(25 downto 10) = x"FFFF" else '0';
    B_almost_full <= '1' when B_mem_addr(25 downto 10) = x"FFFF" else '0';

    ddr_ready_A <= not A_almost_full when A_writestate = '1' else
                 '0' when A_disabled = '1' else
                 '0' when A_readstate = '1' else
                 '1';

    ddr_ready_B <= not B_almost_full when B_writestate = '1' else
                 '0' when B_disabled = '1' else
                 '0' when B_readstate = '1' else
                 '1';

    o_ddr_ready <= ddr_ready_A or ddr_ready_B;


    --! time stamp handling
    o_tsblocks <= x"0000" & B_tsrange & A_tsrange;
    ts_in_upper <= i_ts(tsupper); -- 15 downto 8 from 35 downto 4 of the 48b TS
    ts_in_lower <= i_ts(tslower); --  7 downto 0 from 35 downto 4 of the 48b TS

    A_data <= ts_in_upper & ts_in_lower & i_data;

    ts_in_upper_A <= A_data(527 downto 520);
    ts_in_upper_B <= A_data(527 downto 520);


    --! request handling
    A_ts_req <= i_ts_req_A(tslower);
    B_ts_req <= i_ts_req_B(tslower);

    --! write process to fifo
    process(i_clk, i_reset_n)
        variable tsupperchangeA : boolean;
        variable tsupperchangeB : boolean;
    begin
    if ( i_reset_n = '0' ) then
        mem_mode_A      <= disabled;
        A_disabled      <= '1';
        writefifo_A     <= '0';
        A_readstate     <= '0';
        A_writestate    <= '0';
        tsupper_last_A  <= (others => '1');

        mem_mode_B      <= disabled;
        B_disabled      <= '1';
        writefifo_B     <= '0';
        B_readstate     <= '0';
        B_writestate    <= '0';
        tsupper_last_B  <= (others => '1');
        --
    elsif rising_edge(i_clk) then

        tofifo_A    <= A_data(519 downto 0);
        writefifo_A <= '0';
        A_readstate <= '0';
        A_writestate<= '0';

        tofifo_B    <= B_data(519 downto 0);
        writefifo_B <= '0';
        B_readstate <= '0';
        B_writestate<= '0';

        -- start when data is ready
        -- TODO: MK: can this break if calibration takes to long?
        -- maybe the run should only start when calibration
        -- is done
        tsupperchangeA := false;
        if ( sync_A_empty = '0' ) then
            tsupper_last_A <= ts_in_upper_A;
            if ( ts_in_upper_A /=  tsupper_last_A ) then
                tsupperchangeA := true;
            end if;
        end if;

        tsupperchangeB := false;
        if ( sync_B_empty = '0' ) then
            tsupper_last_B <= ts_in_upper_B;
            if ( ts_in_upper_B /=  tsupper_last_B ) then
                tsupperchangeB := true;
            end if;
        end if;

        case mem_mode_A is
        when disabled =>
            if ( A_mem_calibrated = '1' ) then
                mem_mode_A <= ready;
                A_disabled <= '0';
            end if;

        when ready =>
            if ( tsupperchangeA and A_done = '1' ) then
                mem_mode_A    <= writing;
                A_tsrange     <= ts_in_upper_A;
                writefifo_A   <= '1';
            end if;

        when writing =>
            A_writestate    <= '1';

            writefifo_A     <= not sync_A_empty;
            if ( tsupperchangeA or A_almost_full = '1' ) then
                mem_mode_A  <= reading;
                writefifo_A <= '0';
            end if;

        when reading =>
            A_readstate <= '1';

            if ( i_tsblock_done = A_tsrange ) then
                mem_mode_A <= ready;
            end if;

        when others =>
            mem_mode_A <= disabled;

        end case;

        case mem_mode_B is
        when disabled =>
            if ( B_mem_calibrated = '1' )then
                mem_mode_B <= ready;
                B_disabled <= '0';
            end if;

        when ready  =>
            if ( tsupperchangeB and (mem_mode_A /= ready or (mem_mode_A = ready and A_done = '0')) and B_done ='1' ) then
                mem_mode_B      <= writing;
                B_tsrange       <= ts_in_upper_B;
                writefifo_B     <= '1';
            end if;

        when writing =>
            B_writestate <= '1';

            writefifo_B     <= not sync_B_empty;
            if ( tsupperchangeB or B_almost_full = '1' ) then
                mem_mode_B  <= reading;
                writefifo_B <= '0';
            end if;

        when reading =>
            B_readstate     <= '1';

            if ( i_tsblock_done = B_tsrange ) then
                mem_mode_B <= ready;
            end if;
        when others =>
            mem_mode_B <= disabled;

        end case;
    end if;
    end process;

    --! ram data for DDR
    tomemfifo_A : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 8,
        g_DATA_WIDTH => 520--,
    )
    port map (
        i_we        => writefifo_A,
        i_wdata     => tofifo_A,

        i_rack      => readfifo_A,
        o_rdata     => qfifo_A,
        o_rempty    => A_fifo_empty,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    tomemfifo_B : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 8,
        g_DATA_WIDTH => 520--,
    )
    port map (
        i_we        => writefifo_B,
        i_wdata     => tofifo_B,

        i_rack      => readfifo_B,
        o_rdata     => qfifo_B,
        o_rempty    => B_fifo_empty,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    A_mem_data  <= qfifo_A(511 downto 0);
    B_mem_data  <= qfifo_B(511 downto 0);


    --! Process for writing the memory
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        ddr3if_state_A  <= disabled;
        A_tagram_write  <= '0';
        readfifo_A      <= '0';
        A_readreqfifo   <= '0';
        A_mem_write     <= '0';
        A_mem_read      <= '0';
        A_memreadfifo_write <= '0';
        A_done          <= '0';

        ddr3if_state_B  <= disabled;
        B_tagram_write  <= '0';
        readfifo_B      <= '0';
        B_readreqfifo   <= '0';
        B_mem_write     <= '0';
        B_mem_read      <= '0';
        B_memreadfifo_write <= '0';
        B_done          <= '0';
        --
    elsif rising_edge(i_clk) then
        A_tagram_write      <= '0';
        readfifo_A          <= '0';
        A_mem_write         <= '0';
        A_mem_read          <= '0';
        A_readreqfifo       <= '0';
        A_memreadfifo_write <= '0';
        case ddr3if_state_A is
        when disabled =>
            if ( A_mem_calibrated = '1' ) then
                A_tagram_address    <= (others => '1');
                ddr3if_state_A      <= overwriting;
                -- TODO: MK: is overwriting needed?
                    -- Skip memory overwriting for simulation
                -- synthesis translate_off
                    ddr3if_state_A      <= ready;
                    A_done              <= '1';
                -- synthesis translate_on
            end if;

        when ready =>
            if ( A_writestate = '1' ) then
                ddr3if_state_A      <= writing;
                A_mem_addr          <= (others => '1');
                A_mem_word_cnt      <= (others => '0');
                A_tagram_address    <= (others => '0');
                A_tagts_last        <= (others => '1');
                A_done              <= '0';
            end if;

        when writing =>
            if ( A_readstate = '1' and A_fifo_empty = '1' ) then
                ddr3if_state_A  <= reading;
                A_readsubstate  <= fifowait;
            end if;

            if ( A_fifo_empty = '0' and A_mem_ready = '1' ) then
                readfifo_A      <= '1';

                -- write DDR memory
                A_mem_write     <= '1';
                A_mem_addr      <= A_mem_addr + '1';
                A_mem_word_cnt  <= A_mem_word_cnt + '1';

                if ( A_tagts_last /= qfifo_A(519 downto 512) ) then
                    A_tagts_last                <= qfifo_A(519 downto 512);
                    A_tagram_write              <= '1';
                    -- address of tag ram are x"00" & (7 downto 0) from 35 downto 4 of the 48b TS
                    A_tagram_address            <= qfifo_A(519 downto 512);
                    -- data of tag is the last DDR RAM Address of this event (25 downto 0)
                    -- and the number of words (512b) (31 downto 26)
                    A_tagram_data(31 downto 26) <= A_mem_word_cnt;
                    A_tagram_data(25 downto 0)  <= A_mem_addr + '1';
                    A_mem_word_cnt              <= (others => '0');
                end if;
            end if;

        when reading =>
            if ( A_readstate = '0' and A_reqfifo_empty = '1' and A_readsubstate = fifowait ) then
                ddr3if_state_A      <= overwriting;
                A_tagram_address    <= (others => '1');
            end if;

            case A_readsubstate is
            when fifowait =>
                if ( A_reqfifo_empty = '0' ) then
                    A_tagram_address    <= A_ts_req;
                    A_ts_req_last          <= A_ts_req;
                    A_readreqfifo       <= '1';
                    if ( A_ts_req /= A_ts_req_last ) then
                        A_readsubstate  <= tagmemwait_1;
                    end if;
                end if;
            when tagmemwait_1 =>
                A_readsubstate <= tagmemwait_2;
            when tagmemwait_2 =>
                A_readsubstate <= tagmemwait_3;
            when tagmemwait_3 =>
                A_mem_addr  <= A_tagram_q(25 downto 0);
                A_readwords <= A_tagram_q(31 downto 26) - '1';
                if ( A_mem_ready = '1' ) then
                    A_mem_read <= '1';
                    A_readsubstate  <= reading;
                    -- save number of 512b words, ts_in(tsupper), tagram address
                    A_memreadfifo_data  <= A_tagram_q(31 downto 26) & A_tsrange & A_tagram_address;
                    A_memreadfifo_write <= '1';
                end if;
            when reading =>
                if ( A_mem_ready = '1' ) then
                    A_mem_addr      <= A_mem_addr_reg;
                    A_mem_addr_reg  <= A_mem_addr_reg + '1';
                    A_readwords     <= A_readwords - '1';
                    A_mem_read      <= '1';
                end if;
                if ( A_readwords = "00001" ) then
                    A_readsubstate  <= fifowait;
                end if;
            end case;

        when overwriting =>
            A_tagram_address    <= A_tagram_address + '1';
            A_tagram_write      <= '1';
            A_tagram_data       <= (others => '0');
            if ( A_tagram_address = tsone and A_tagram_write = '1' ) then
                ddr3if_state_A  <= ready;
                A_done          <= '1';
            end if;

        when others =>
            ddr3if_state_A <= disabled;

        end case;

        B_tagram_write      <= '0';
        readfifo_B          <= '0';
        B_mem_write         <= '0';
        B_mem_read          <= '0';
        B_readreqfifo       <= '0';
        B_memreadfifo_write <= '0';
        case ddr3if_state_B is
        when disabled =>
            if ( B_mem_calibrated = '1' ) then
                B_tagram_address    <= (others => '1');
                ddr3if_state_B      <= overwriting;
                -- TODO: MK: is overwriting needed?
                    -- Skip memory overwriting for simulation
                -- synthesis translate_off
                    ddr3if_state_B      <= ready;
                    B_done              <= '1';
                -- synthesis translate_on
            end if;

        when ready =>
            if ( B_writestate = '1' ) then
                ddr3if_state_B      <= writing;
                B_mem_addr          <= (others => '1');
                B_mem_word_cnt      <= (others => '0');
                B_tagram_address    <= (others => '0');
                B_tagts_last        <= (others => '1');
                B_done              <= '0';
            end if;

        when writing =>
            if ( B_readstate = '1' and B_fifo_empty = '1' ) then
                ddr3if_state_B  <= reading;
                B_readsubstate  <= fifowait;
            end if;

            if ( B_fifo_empty = '0' and B_mem_ready = '1' ) then
                readfifo_B      <= '1';

                -- write DDR memory
                B_mem_write     <= '1';
                B_mem_addr      <= B_mem_addr + '1';
                B_mem_word_cnt  <= B_mem_word_cnt + '1';

                if ( B_tagts_last /= qfifo_B(519 downto 512) ) then
                    B_tagts_last                <= qfifo_B(519 downto 512);
                    B_tagram_write              <= '1';
                    -- address of tag ram are x"00" & (7 downto 0) from 35 downto 4 of the 48b TS
                    B_tagram_address            <= qfifo_B(519 downto 512);
                    -- data of tag is the last DDR RAM Address of this event (25 downto 0)
                    -- and the number of words (512b) (31 downto 26)
                    B_tagram_data(31 downto 26) <= B_mem_word_cnt;
                    B_tagram_data(25 downto 0)  <= B_mem_addr + '1';
                    B_mem_word_cnt              <= (others => '0');
                end if;
            end if;

        when reading =>
            if ( B_readstate = '0' and B_reqfifo_empty = '1' and B_readsubstate = fifowait ) then
                ddr3if_state_B      <= overwriting;
                B_tagram_address    <= (others => '1');
            end if;

            case B_readsubstate is
            when fifowait =>
                if ( B_reqfifo_empty = '0' ) then
                    B_tagram_address    <= B_ts_req;
                    B_ts_req_last          <= B_ts_req;
                    B_readreqfifo       <= '1';
                    if ( B_ts_req /= B_ts_req_last ) then
                        B_readsubstate  <= tagmemwait_1;
                    end if;
                end if;
            when tagmemwait_1 =>
                B_readsubstate <= tagmemwait_2;
            when tagmemwait_2 =>
                B_readsubstate <= tagmemwait_3;
            when tagmemwait_3 =>
                B_mem_addr  <= B_tagram_q(25 downto 0);
                B_readwords <= B_tagram_q(31 downto 26) - '1';
                if ( B_mem_ready = '1' ) then
                    B_mem_read <= '1';
                    B_readsubstate  <= reading;
                    -- save number of 512b words, ts_in(tsupper), tagram address
                    B_memreadfifo_data  <= B_tagram_q(31 downto 26) & B_tsrange & B_tagram_address;
                    B_memreadfifo_write <= '1';
                end if;
            when reading =>
                if ( B_mem_ready = '1' ) then
                    B_mem_addr      <= B_mem_addr_reg;
                    B_mem_addr_reg  <= B_mem_addr_reg + '1';
                    B_readwords     <= B_readwords - '1';
                    B_mem_read      <= '1';
                end if;
                if ( B_readwords = "00001" ) then
                    B_readsubstate  <= fifowait;
                end if;
            end case;

        when overwriting =>
            B_tagram_address    <= B_tagram_address + '1';
            B_tagram_write      <= '1';
            B_tagram_data       <= (others => '0');
            if ( A_tagram_address = tsone and B_tagram_write = '1' ) then
                ddr3if_state_B  <= ready;
                B_done          <= '1';
            end if;

        when others =>
            ddr3if_state_B <= disabled;

        end case;
    end if;
    end process;

    --! readout data to PCIe
    A_memreadfifo_read <= '1' when output_write_state = waiting and A_memreadfifo_empty = '0' else '0';
    A_memdatafifo_read <= '1' when output_write_state = eventA and A_memdatafifo_empty = '0' else '0';
    B_memreadfifo_read <= '1' when output_write_state = waiting and B_memreadfifo_empty = '0' else '0';
    B_memdatafifo_read <= '1' when output_write_state = eventB and B_memdatafifo_empty = '0' else '0';

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        output_write_state  <= waiting;
        o_dma_wren          <= '0';
        o_dma_eoe             <= '0';
        o_dma_done          <= '0';
        cnt_4kb_done        <= '0';
        cnt_skip_event_dma  <= (others => '0');
        cnt_num_req_events  <= (others => '0');
        cnt_4kb             <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        o_dma_wren  <= '0';
        o_dma_eoe     <= '0';
        o_dma_done  <= '0';

        if ( i_dma_wen = '0' ) then
            cnt_num_req_events <= (others => '0');
            cnt_4kb_done <= '0';
        end if;

        if ( i_dma_wen = '1' and cnt_num_req_events >= i_num_req_events and cnt_4kb_done = '1' ) then
            o_dma_done <= '1';
        end if;

        case output_write_state is
        when waiting =>
            if ( i_dma_wen = '1' and cnt_num_req_events >= i_num_req_events and cnt_4kb_done = '0' ) then
                output_write_state  <= write_4kb_padding;
            elsif ( A_memreadfifo_empty = '0' ) then
                -- input is 512b from DDR output is 256b to PCIe
                -- we cnt the 512b words before so multi by 2
                nummemwords <= A_memreadfifo_q(21 downto 16) & '0';
                if ( o_dma_done = '1' or i_dmamemhalffull = '1' or ( i_num_req_events /= 0 and cnt_num_req_events >= i_num_req_events ) ) then
                    output_write_state  <= skip_event_A;
                    cnt_skip_event_dma  <= cnt_skip_event_dma + '1';
                    -- cnt req event even if we skip
                    cnt_num_req_events <= cnt_num_req_events + '1';
                else
                    output_write_state <= eventA;
                    o_dma_wren <= i_dma_wen;
                    o_dma_data <= A_memdatafifo_q;
                    cnt_num_req_events <= cnt_num_req_events + '1';
                end if;
            elsif ( B_memreadfifo_empty = '0' ) then
                -- input is 512b from DDR output is 256b to PCIe
                -- we cnt the 512b words before so multi by 2
                nummemwords <= B_memreadfifo_q(21 downto 16) & '0';
                if ( o_dma_done = '1' or i_dmamemhalffull = '1' or ( i_num_req_events /= 0 and cnt_num_req_events >= i_num_req_events ) ) then
                    output_write_state  <= skip_event_B;
                    cnt_skip_event_dma  <= cnt_skip_event_dma + '1';
                    -- cnt req event even if we skip
                    cnt_num_req_events <= cnt_num_req_events + '1';
                else
                    output_write_state <= eventB;
                    o_dma_wren <= i_dma_wen;
                    o_dma_data <= B_memdatafifo_q;
                    cnt_num_req_events <= cnt_num_req_events + '1';
                end if;
            end if;

        when eventA =>
            if ( A_memdatafifo_empty = '0' ) then
                o_dma_wren      <= i_dma_wen;
                o_dma_data    <= A_memdatafifo_q;
                nummemwords     <= nummemwords - '1';
                if ( nummemwords = "0000001" ) then
                    output_write_state <= waiting;
                    o_dma_eoe     <= '1';
                end if;
            end if;

        when eventB =>
            if ( B_memdatafifo_empty = '0' ) then
                o_dma_wren      <= i_dma_wen;
                o_dma_data    <= B_memdatafifo_q;
                nummemwords     <= nummemwords - '1';
                if ( nummemwords = "0000001" ) then
                    output_write_state <= waiting;
                    o_dma_eoe     <= '1';
                end if;
            end if;

        when skip_event_A =>
            if ( A_memdatafifo_empty = '0' ) then
                nummemwords     <= nummemwords - '1';
                if ( nummemwords = "0000001" ) then
                    output_write_state <= waiting;
                end if;
            end if;

        when skip_event_B =>
            if ( B_memdatafifo_empty = '0' ) then
                nummemwords     <= nummemwords - '1';
                if ( nummemwords = "0000001" ) then
                    output_write_state <= waiting;
                end if;
            end if;

        when write_4kb_padding =>
            o_dma_data <= (others => '1');
            o_dma_wren <= '1';
            if ( cnt_4kb = "01111111" ) then
                cnt_4kb_done <= '1';
                cnt_4kb <= (others => '0');
                output_write_state <= waiting;
            else
                cnt_4kb <= cnt_4kb + '1';
            end if;

        when others =>
            output_write_state <= waiting;

        end case;
    end if;
    end process;

    tagram_A : entity work.ip_ram_1rw
    generic map (
        g_ADDR_WIDTH => 8,
        g_DATA_WIDTH => 32,
        g_RDATA_REG => 1--,
    )
    port map (
        i_addr  => A_tagram_address,
        i_wdata => A_tagram_data,
        i_we    => A_tagram_write,
        o_rdata => A_tagram_q,
        i_clk   => i_clk--,
    );

    tagram_B : entity work.ip_ram_1rw
    generic map (
        g_ADDR_WIDTH => 8,
        g_DATA_WIDTH => 32,
        g_RDATA_REG => 1--,
    )
    port map (
        i_addr  => B_tagram_address,
        i_wdata => B_tagram_data,
        i_we    => B_tagram_write,
        o_rdata => B_tagram_q,
        i_clk   => i_clk--,
    );

    A_mreadfifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH    => 4,
        g_DATA_WIDTH    => A_memreadfifo_data'length,
        g_WREG_N        => 1,
        g_RREG_N        => 1--,
    )
    port map (
        i_we            => A_memreadfifo_write,
        i_wdata         => A_memreadfifo_data,
        o_wfull         => open,

        i_rack          => A_memreadfifo_read,
        o_rdata         => A_memreadfifo_q,
        o_rempty        => A_memreadfifo_empty,

        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    B_mreadfifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH    => 4,
        g_DATA_WIDTH    => B_memreadfifo_data'length,
        g_WREG_N        => 1,
        g_RREG_N        => 1--,
    )
    port map (
        i_we            => B_memreadfifo_write,
        i_wdata         => B_memreadfifo_data,
        o_wfull         => open,

        i_rack          => B_memreadfifo_read,
        o_rdata         => B_memreadfifo_q,
        o_rempty        => B_memreadfifo_empty,

        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    A_mdatafdfifo : entity work.ip_dcfifo_v2
    generic map (
        g_WADDR_WIDTH   => 4,
        g_RADDR_WIDTH   => 5,
        g_DATA_WIDTH    => A_mem_q'length,
        g_RDATA_WIDTH   => A_memdatafifo_q'length,
        g_WREG_N        => 1,
        g_RREG_N        => 1--,
    )
    port map (
        i_we            => A_mem_q_valid,
        i_wdata         => A_mem_q,
        o_wfull         => open,
        i_wclk          => i_clk,

        i_rack          => A_memdatafifo_read,
        o_rdata         => A_memdatafifo_q,
        o_rempty        => A_memdatafifo_empty,
        i_rclk          => i_clk,

        i_reset_n       => i_reset_n--,
    );

    B_mdatafdfifo : entity work.ip_dcfifo_v2
    generic map (
        g_WADDR_WIDTH   => 4,
        g_RADDR_WIDTH   => 5,
        g_DATA_WIDTH    => B_mem_q'length,
        g_RDATA_WIDTH   => B_memdatafifo_q'length,
        g_WREG_N        => 1,
        g_RREG_N        => 1--,
    )
    port map (
        i_we            => B_mem_q_valid,
        i_wdata         => B_mem_q,
        o_wfull         => open,
        i_wclk          => i_clk,

        i_rack          => B_memdatafifo_read,
        o_rdata         => B_memdatafifo_q,
        o_rempty        => B_memdatafifo_empty,
        i_rclk          => i_clk,

        i_reset_n       => i_reset_n--,
    );

end architecture;

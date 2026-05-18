-------------------------------------------------------
--! @farm_coordinate_converter_dummy.vhd
--! @brief the farm_coordinate_converter_dummy can be used
--! to simple pack the injected hits
--! Author: mkoeppel@uni-mainz.de
-------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;
use work.a10_pcie_registers.all;

entity farm_gpu_event_builder_onboard_RAM is
port (
    --! hits per layer input
    i_float_hit         : in  slv128_array_t(3 downto 0);
    i_sop               : in  std_logic_vector(3 downto 0);
    i_eop               : in  std_logic_vector(3 downto 0);
    i_eor               : in  std_logic_vector(3 downto 0) := (others => '0'); -- end of run
    i_valid             : in  std_logic_vector(3 downto 0);
    i_max_padding_size  : in  std_logic_vector(15 downto 0);
    o_almost_full       : out std_logic;

    --! DMA
    i_dmamemhalffull    : in  std_logic;
    i_wen               : in  std_logic;
    i_get_n_events      : in  std_logic_vector(31 downto 0);
    o_dma_wen           : out std_logic;
    o_dma_data          : out std_logic_vector(255 downto 0);
    o_endofevent        : out std_logic;
    o_dma_done          : out std_logic;

    --! 250 MHz clock pice / reset_n
    i_reset_n       : in  std_logic;
    i_clk           : in  std_logic--;
);
end entity;

architecture arch of farm_gpu_event_builder_onboard_RAM is

    -- input to buffer signals
    -- NOTE: we work with Mebibytes NOT Megabytes
    -- the last addr is for the flags etc. so the first pointer is at addr for 0.5MiB-256bits
    constant pointer_to_first_offset : std_logic_vector(13 downto 0) := std_logic_vector(to_unsigned(512*1024*8/256-2, 14));
    constant pointer_to_half_MiB : std_logic_vector(13 downto 0) := std_logic_vector(to_unsigned(512*1024*8/256-1, 14));
    signal buffer_fifo_empty, buffer_fifo_wen, buffer_almost_full, buffer_fifo_ren, we_write_this_package : std_logic_vector(3 downto 0);
    signal write_ts, skip_ts : std_logic_vector(31 downto 0) := (others => '0');
    signal ts : slv32_array_t(3 downto 0);
    signal dma_first_half : std_logic;
    signal buffer_fifo_wdata, buffer_fifo_rdata : slv132_array_t(3 downto 0);
    signal buffer_fifo_wrusedw : slv12_array_t(3 downto 0);

    -- buffer to RAM singals
    type gpu_event_state_type is (idle, delay_startup_0, delay_startup_1, startup, reading, write_pointer, closing_hits, closing_pointers, closing, delay_idle);
    type gpu_event_state_array is array ( natural range <> ) of gpu_event_state_type;
    signal read_buffer_fifo_state : gpu_event_state_array(3 downto 0);
    signal sop, eop, valid, eor, w_ram_wen, pointer_written_last, write_done, timestamp_aligned, close_event : std_logic_vector(3 downto 0);
    signal hit_cnt : slv4_array_t(3 downto 0);
    signal float_hit : slv128_array_t(3 downto 0);
    signal w_ram_addr, hit_addr, pointer_addr, r_ram_addr, diff : slv14_array_t(3 downto 0);
    signal num_total_hits, cnt_timestamp : slv32_array_t(3 downto 0);
    signal global_timestamp : slv64_array_t(3 downto 0);
    signal w_ram_data, r_ram_data, data_16_pointers : slv256_array_t(3 downto 0);
    type int_array is array( natural range <> ) of integer;
    signal data_16_pointers_idx : int_array(3 downto 0);

    -- DMA readout
    type state_type_dma is (idle, data, wait_state, write_4kb_padding);
    signal state_dma : state_type_dma;
    signal done, event_counter_written, dma_wen_next : std_logic;
    signal event_counter, cnt_4kb : std_logic_vector(31 downto 0);
    signal layer_idx, layer_idx_last, layer_idx_last_last : integer range 0 to 4;

begin

    --! some rate notes
    -- * we produce every 2 cycles (we run here at 250 MHz) one 8ns timestamp
    -- * we can get every second cycle 4 64-bit hits and can output one 256-bit word
    -- * since `2**x * 64 = 2**y * 256` does not give a int number for x and y
    --   we have to fill-up the 256bit word
    -- * we write for each timestamp one 16bit pointer
    --   at the output of the pointer we read every cycle 16 pointers
    -- * the padding is also only 64-bit per cycle which can be increased to 256bit

    --! backpressure output
    -- NOTE: we "or" here when one of the layer FIFOs is almost full
    -- at the backpressure side we have to make sure to skip the same
    -- timestampe from each of the layers.
    -- One way would be to get back a signal from where the backpressures
    -- is handled which says I have skipped now from each layer equally
    -- amount of timestamp we can now reset the global almost full bit
    o_almost_full <= or_reduce(buffer_almost_full);

    --! TODO: output counters for full and almost full value here

    --! check for fifo state
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        ts <= (others => (others => '0'));
        write_ts <= (others => '0');
        skip_ts <= (others => '0');
        buffer_fifo_wdata <= (others => (others => '0'));
        buffer_fifo_wen <= (others => '0');
        buffer_almost_full <= (others => '0');
        we_write_this_package <= (others => '0');
        --
    elsif rising_edge(i_clk) then

        for i in 0 to 3 loop

            if ( buffer_fifo_wrusedw(i)(11) = '1' ) then --12-1
                buffer_almost_full(i) <= '1';
            else
                buffer_almost_full(i) <= '0';
            end if;

            buffer_fifo_wen(i) <= '0';
            buffer_fifo_wdata(i) <= i_float_hit(i) & i_sop(i) & i_eop(i) & i_eor(i) & i_valid(i);

            if ( i_sop(i) = '1' ) then
                if ( ts(i) <= write_ts ) then
                    we_write_this_package(i) <= '1';
                    buffer_fifo_wen(i) <= '1';
                elsif ( buffer_almost_full /= 0 ) then
                    if ( ts(i) > skip_ts ) then
                        skip_ts <= ts(i);
                    end if;
                    -- we skip here
                elsif ( ts(i) <= skip_ts ) then
                    -- we skip here
                else
                    -- assert(ts(i) > write_ts)
                    we_write_this_package(i) <= '1';
                    buffer_fifo_wen(i) <= '1';
                    write_ts <= ts(i);
                end if;
            end if;

            if ( we_write_this_package(i) = '1' and i_valid(i) = '1' ) then
                buffer_fifo_wen(i) <= '1';
            end if;

            if ( i_eop(i) = '1' ) then
                ts(i) <= ts(i) + '1';
                we_write_this_package(i) <= '0';
            end if;
        end loop;
    end if;
    end process;

    gen_per_layer : for i in 0 to 3 GENERATE

        e_buffer_fifo : entity work.ip_scfifo_v2
        generic map (
            g_RREG_N => 1,
            g_ADDR_WIDTH => 12,
            g_DATA_WIDTH => 128+4--,
        )
        port map (
            i_we        => buffer_fifo_wen(i),
            i_wdata     => buffer_fifo_wdata(i),
            o_usedw     => buffer_fifo_wrusedw(i),

            i_rack      => buffer_fifo_ren(i),
            o_rdata     => buffer_fifo_rdata(i),
            o_rempty    => buffer_fifo_empty(i),

            i_reset_n   => i_reset_n,
            i_clk       => i_clk--,
        );
        float_hit(i) <= buffer_fifo_rdata(i)(131 downto 4) when buffer_fifo_empty(i) = '0' else (others => '0');
        sop(i) <= buffer_fifo_rdata(i)(3) and not buffer_fifo_empty(i);
        eop(i) <= buffer_fifo_rdata(i)(2) and not buffer_fifo_empty(i);
        eor(i) <= buffer_fifo_rdata(i)(1) and not buffer_fifo_empty(i);
        valid(i) <= buffer_fifo_rdata(i)(0) and not buffer_fifo_empty(i);
        buffer_fifo_ren(i) <= '1' when read_buffer_fifo_state(i) = reading and valid(i) = '1' else '0';

        --! check for the timestamps of all layers
        timestamp_aligned(i) <= '1' when cnt_timestamp(0)(3 downto 0) = cnt_timestamp(1)(3 downto 0) and cnt_timestamp(0)(3 downto 0) = cnt_timestamp(2)(3 downto 0) and cnt_timestamp(0)(3 downto 0) = cnt_timestamp(3)(3 downto 0) else '0';

        --! closing condition of the GPU event
        process(i_clk, i_reset_n)
        begin
        if ( i_reset_n = '0' ) then
            close_event(i) <= '0';
            diff(i) <= (others => '1');
        --
        elsif rising_edge(i_clk) then
            close_event(i) <= '0';
            diff(i) <= pointer_addr(i) - hit_addr(i);
            if ( diff(i) <= i_max_padding_size(13 downto 0) and and_reduce(hit_addr(i)) = '0' ) then
                close_event(i) <= '1';
            end if;
        end if;
        end process;

        process(i_clk, i_reset_n)
        begin
        if ( i_reset_n = '0' ) then
            read_buffer_fifo_state(i) <= idle;
            w_ram_addr(i) <= (others => '0');
            hit_addr(i) <= (others => '1');
            w_ram_data(i) <= (others => '0');
            cnt_timestamp(i) <= (others => '0');
            global_timestamp(i) <= (others => '0');
            w_ram_wen(i) <= '0';
            hit_cnt(i) <= (others => '0');
            pointer_written_last(i) <= '0';
            data_16_pointers_idx(i) <= 1; -- we start from 1 since the first pointer/offset will be zero and the last will be nHits
            data_16_pointers(i) <= (others => '0'); -- we store the number of hits for 16 timestamps to write a once
            pointer_addr(i) <= pointer_to_first_offset;
            num_total_hits(i) <= (others => '0');
            write_done(i) <= '0';
            --
        elsif rising_edge(i_clk) then

            w_ram_wen(i) <= '0';

            case read_buffer_fifo_state(i) is

            when idle =>

                -- we wait until we are enabled and than we start to readout
                if ( i_wen = '1' and sop(i) = '1' and dma_first_half = '0' ) then
                    read_buffer_fifo_state(i) <= delay_startup_0;
                    -- we start writing now
                    write_done(i) <= '0';
                end if;

            -- we delay here so close_event can be set
            when delay_startup_0 =>
                read_buffer_fifo_state(i) <= delay_startup_1;

            when delay_startup_1 =>
                read_buffer_fifo_state(i) <= startup;

            when startup =>

                -- we wait until all have a start of event
                if ( and_reduce(sop) = '1' ) then

                    -- we close the GPU package if for one of the layers padding: addr_pointer - addr_hits <= i_max_padding_size is true
                    if ( or_reduce(close_event) = '1' ) then
                        read_buffer_fifo_state(i) <= closing_hits;
                    -- we also check if the timestamps are aligned -- only check lower bits to save resources
                    -- we also check that all other layers are in startup for a new package
                    elsif ( timestamp_aligned(i) = '1' and read_buffer_fifo_state = (read_buffer_fifo_state'range => startup) ) then
                        w_ram_data(i) <= X"AFFEAFFE" & X"AFFEAFFE" & X"AFFEAFFE" & X"AFFEAFFE" & X"AFFEAFFE" & X"AFFEAFFE" & X"AFFEAFFE" & X"AFFEAFFE";
                        read_buffer_fifo_state(i) <= reading;
                    end if;

                end if;

            when reading =>
                -- counting of the current size
                -- | 0 hits N | padding | N pointer 0 | rest | = 0.5MB
                -- hits: num_hits in 64-bit
                -- pointer: the pointers are 16bit
                -- rest: 256bit
                -- padding: addr_pointer - addr_hits <= i_max_padding_size

                -- count the hits and write them to the FIFO
                if ( valid(i) = '1' ) then
                    hit_cnt(i) <= hit_cnt(i) + 1;
                    if ( hit_cnt(i) = 3 ) then
                        hit_cnt(i) <= (others => '0');
                        -- write 32-bit hit id and 32-bit ts (currently zero)
                        w_ram_data(i)(255 downto 192) <= float_hit(i)(127 downto 64);
                        hit_addr(i) <= hit_addr(i) + '1';
                        w_ram_addr(i) <= hit_addr(i) + '1';
                        w_ram_wen(i) <= '1';
                    elsif ( hit_cnt(i) = 2 ) then
                        w_ram_data(i)(191 downto 128) <= float_hit(i)(127 downto 64);
                    elsif ( hit_cnt(i) = 1 ) then
                        w_ram_data(i)(127 downto  64) <= float_hit(i)(127 downto 64);
                    elsif ( hit_cnt(i) = 0 ) then
                        -- also write fillers
                        w_ram_data(i)(255 downto 192) <= X"AFFEAFFE" & X"AFFEAFFE";
                        w_ram_data(i)(191 downto 128) <= X"AFFEAFFE" & X"AFFEAFFE";
                        w_ram_data(i)(127 downto  64) <= X"AFFEAFFE" & X"AFFEAFFE";
                        w_ram_data(i)( 63 downto   0) <= float_hit(i)(127 downto 64);
                    end if;

                    num_total_hits(i) <= num_total_hits(i) + '1';
                    -- count up the pointers for 16 timestamps
                    -- NOTE: we swap the bytes of the counters and we swap the 16bits in the 256bit word
                    data_16_pointers(i)((15-data_16_pointers_idx(i) + 1) * 16 - 1 downto (15-data_16_pointers_idx(i)) * 16) <= num_total_hits(i)(15 downto 0) + '1';
                end if;

                -- handle end of package
                if ( eop(i) = '1' ) then
                    cnt_timestamp(i) <= cnt_timestamp(i) + '1';
                    global_timestamp(i) <= global_timestamp(i) + '1';
                    data_16_pointers_idx(i) <= data_16_pointers_idx(i) + 1;
                    pointer_written_last(i) <= '0';
                    if ( (data_16_pointers_idx(i) + 1) = 16 ) then
                        data_16_pointers_idx(i) <= 0;
                        read_buffer_fifo_state(i) <= write_pointer;
                    else
                        read_buffer_fifo_state(i) <= delay_startup_0;
                    end if;
                end if;

                -- TODO: think about end of run - flow chart for the whole system DAQ week
                if ( eor(i) = '1' ) then
                    read_buffer_fifo_state(i) <= idle;
                end if;

            when write_pointer =>
                w_ram_wen(i) <= '1';
                pointer_written_last(i) <= '1';
                pointer_addr(i) <= pointer_addr(i) - 1;
                w_ram_addr(i) <= pointer_addr(i);
                w_ram_data(i) <= data_16_pointers(i);
                read_buffer_fifo_state(i) <= delay_startup_0;

            when closing_hits =>
                if ( hit_cnt(i) /= 0 ) then
                    hit_cnt(i) <= (others => '0');
                    hit_addr(i) <= hit_addr(i) + '1';
                    w_ram_addr(i) <= hit_addr(i) + '1';
                    w_ram_wen(i) <= '1';
                end if;

                if ( pointer_written_last(i) = '1' ) then
                    read_buffer_fifo_state(i) <= closing;
                else
                    read_buffer_fifo_state(i) <= closing_pointers;
                end if;

            when closing_pointers =>

                -- we write zeros for the pointer if they are not 16
                data_16_pointers_idx(i) <= data_16_pointers_idx(i) + 1;
                if ( data_16_pointers_idx(i) = 16 ) then
                    data_16_pointers_idx(i) <= 1;
                    data_16_pointers(i) <= (others => '0');
                    w_ram_wen(i) <= '1';
                    pointer_addr(i) <= pointer_addr(i) - 1;
                    w_ram_addr(i) <= pointer_addr(i);
                    w_ram_data(i) <= data_16_pointers(i);
                    read_buffer_fifo_state(i) <= closing;
                else
                    data_16_pointers(i)((15-data_16_pointers_idx(i) + 1) * 16 - 1 downto (15-data_16_pointers_idx(i)) * 16) <= x"AFFE";
                end if;

            when closing =>

                w_ram_wen(i) <= '1';
                w_ram_addr(i) <= hit_addr(i) + '1';
                hit_addr(i) <= hit_addr(i) + '1';
                w_ram_data(i) <= x"AFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFE"; --NOTE: for DEBUG we write AFFEAFFE (others => '0');
                -- we are done
                if ( hit_addr(i) = pointer_addr(i) ) then
                    num_total_hits(i) <= (others => '0');
                    cnt_timestamp(i) <= (others => '0');
                    data_16_pointers(i) <= (others => '0');
                    hit_cnt(i) <= (others => '0');
                    -- we have to wait one cycle so dma_first_half can be set to 1
                    read_buffer_fifo_state(i) <= delay_idle;
                    write_done(i) <= '1';
                    pointer_addr(i) <= pointer_to_first_offset;
                    hit_addr(i) <= (others => '1');
                    w_ram_addr(i) <= pointer_to_half_MiB;
                    w_ram_data(i)(15 downto 0) <= num_total_hits(i)(15 downto 0); -- number of hits N_H
                    w_ram_data(i)(31 downto 16) <= cnt_timestamp(i)(15 downto 0); -- number of timestamps N_{TS}
                    w_ram_data(i)(63 downto 32) <= (others => '1'); -- flags
                    w_ram_data(i)(127 downto 64) <= global_timestamp(i); -- global TS
                    w_ram_data(i)(255 downto 128) <= x"DEEDDEEDDEEDDEEDDEEDDEEDDEEDDEED";
                end if;

            when delay_idle =>
                -- TODO: add timeout
                if ( and_reduce(write_done) = '1' ) then
                    read_buffer_fifo_state(i) <= idle;
                end if;

            when others =>
                read_buffer_fifo_state(i) <= idle;

            end case;
            --
        end if;
        end process;

        e_dma_ram : entity work.ip_ram_2rw
        generic map (
            g_ADDR0_WIDTH => 14,
            g_ADDR1_WIDTH => 14,
            g_DATA0_WIDTH => 256,
            g_DATA1_WIDTH => 256--,
        )
        port map (
            i_addr0     => w_ram_addr(i)(13 downto 0),
            i_addr1     => r_ram_addr(i)(13 downto 0),
            i_clk0      => i_clk,
            i_clk1      => i_clk,
            i_wdata0    => w_ram_data(i),
            i_wdata1    => (others => '0'),
            i_we0       => w_ram_wen(i),
            i_we1       => '0',
            o_rdata0    => open,
            o_rdata1    => r_ram_data(i)--,
        );

    end generate;

    --! output data and read signal for GPU DMA FIFO
    o_dma_data <= (others => '1') when state_dma = write_4kb_padding else r_ram_data(layer_idx_last_last)(255 downto 0);
    o_dma_done <= done;

    --! send out GPU events
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        state_dma               <= idle;
        o_endofevent            <= '0';
        event_counter           <= (others => '0');
        done                    <= '0';
        event_counter_written   <= '0';
        dma_wen_next            <= '0';
        o_dma_wen               <= '0';
        layer_idx               <= 0;
        layer_idx_last          <= 0;
        layer_idx_last_last     <= 0;
        r_ram_addr(0)           <= (others => '1');
        r_ram_addr(1)           <= (others => '1');
        r_ram_addr(2)           <= (others => '1');
        r_ram_addr(3)           <= (others => '1');
        dma_first_half          <= '0';
        --
    elsif rising_edge(i_clk) then

        -- enable and default values
        o_endofevent <= '0';
        dma_wen_next <= '0';
        o_dma_wen <= dma_wen_next;
        layer_idx_last <= layer_idx;
        layer_idx_last_last <= layer_idx_last;

        if ( i_wen = '0' ) then
            event_counter           <= (others => '0');
            done                    <= '0';
            event_counter_written   <= '0';
        end if;

        case state_dma is
        when idle =>
            if ( event_counter_written = '1' and event_counter = (event_counter'range => '0') and i_wen = '1' and done = '0' and i_dmamemhalffull = '0' ) then
                o_endofevent    <= '1';
                state_dma       <= write_4kb_padding;
                o_dma_wen       <= '1';
                cnt_4kb         <= (others => '0');
            -- if we are enabled, have a new request (i_get_n_events), not backpressure (i_dmamemhalffull) and have a SOP in the event FIFO we start the readout
            elsif ( i_wen = '1' and i_get_n_events /= (i_get_n_events'range => '0') and done = '0' and i_dmamemhalffull = '0' and and_reduce(write_done) = '1' ) then
                dma_first_half <= '1';
                state_dma <= data;
                r_ram_addr(layer_idx) <= r_ram_addr(layer_idx) + '1';
                dma_wen_next <= '1';
                -- if we come here after a reset we reset the event_counter for reading out the number of requested events
                if ( event_counter_written = '0' ) then
                    event_counter            <= i_get_n_events;
                    event_counter_written    <= '1';
                end if;
            end if;
            --
        when data =>
            -- we check if we have no backpressure
            if ( i_dmamemhalffull = '0' ) then
                dma_wen_next <= '1';
                r_ram_addr(layer_idx) <= r_ram_addr(layer_idx) + '1';
                -- we have read 0.5 MB from this layer
                if ( r_ram_addr(layer_idx) + '1' = pointer_to_half_MiB ) then
                    if ( layer_idx = 3 ) then
                        layer_idx <= 0;
                        dma_first_half <= '0';
                        state_dma <= wait_state; -- we need to wait on cycle to reset the write_done
                        -- we just have written a full event so we decrease the event counter
                        if ( event_counter /= (event_counter'range => '0') ) then
                            event_counter <= event_counter - '1';
                        end if;
                    else
                        layer_idx <= layer_idx + 1;
                    end if;
                end if;
            end if;
            --
        when wait_state =>
            state_dma <= idle;
            --
        when write_4kb_padding =>
            -- we just make sure to trigger one DMA readout 4kB
            if ( i_dmamemhalffull = '0' ) then
                o_dma_wen <= '1';
                if ( cnt_4kb = "01111111" ) then
                    done <= '1';
                    o_dma_wen <= '0';
                    state_dma <= idle;
                else
                    cnt_4kb <= cnt_4kb + '1';
                end if;
            end if;
            --
        when others =>
            state_dma <= idle;
            --
        end case;
    end if;
    end process;

end architecture;

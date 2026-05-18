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

entity farm_gpu_event_builder is
port (
    --! hits per layer input
    i_float_hit     : in  slv96_array_t(3 downto 0);
    i_sop           : in  std_logic_vector(3 downto 0);
    i_eop           : in  std_logic_vector(3 downto 0);
    i_valid         : in  std_logic_vector(3 downto 0);
    i_padding       : in  std_logic_vector(31 downto 0);
    i_gpu_size      : in  std_logic_vector(31 downto 0);
    o_almost_full   : out std_logic;

    --! DMA
    i_dmamemhalffull    : in  std_logic;
    i_wen               : in  std_logic;
    i_get_n_events      : in  std_logic_vector(31 downto 0);
    o_dma_wen           : out std_logic;
    o_dma_data          : out std_logic_vector(255 downto 0);
    o_endofevent        : out std_logic;
    o_dma_cnt_words     : out std_logic_vector(31 downto 0);
    o_dma_done          : out std_logic;

    --! 250 MHz clock pice / reset_n
    i_reset_n       : in  std_logic;
    i_clk           : in  std_logic--;
);
end entity;

architecture arch of farm_gpu_event_builder is

    -- buffer hits
    signal cnt_hits, cur_frame : slv32_array_t(3 downto 0);
    signal fifo_wdata, fifo_rdata : slv96_array_t(3 downto 0);
    signal tag_fifo_wdata, tag_fifo_rdata : slv64_array_t(3 downto 0);
    signal start_buffer, tag_fifo_wen, tag_fifo_empty, tag_fifo_ren, fifo_wen, fifo_empty, fifo_ren : std_logic_vector(3 downto 0);
    signal tag_fifo_wrusedw, fifo_wrusedw : slv12_array_t(3 downto 0);
    signal almost_full : std_logic_vector(4 + 4 + 2 downto 0);

    -- create GPU events
    signal gpu_dma_cnt : std_logic_vector(2 downto 0);
    signal buffer_event_fifo : std_logic_vector(63 downto 0);
    signal gpu_dma_data, gpu_dma_rdata : std_logic_vector(257 downto 0);
    signal gpu_event_cnt, gpu_padding_cnt, num_frames, total_frames, gpu_tag_fifo_data, gpu_tag_fifo_rdata, cur_num_hits : std_logic_vector(31 downto 0);
    signal gpu_tag_fifo_wrusedw, gpu_event_wrusedw, gpu_dma_wrusedw : std_logic_vector(11 downto 0);
    signal gpu_hit_cnt, tag_dma_data : std_logic_vector(1 downto 0);
    signal layer_index : integer range 0 to 4;
    signal gpu_event_wen, gpu_tag_fifo_ren, started, gpu_tag_fifo_wen, gpu_tag_fifo_empty, gpu_event_ren, gpu_event_empty, gpu_dma_wen, gpu_dma_ren, gpu_dma_empty : std_logic;
    signal gpu_event_data, gpu_event_rdata : std_logic_vector(97 downto 0);
    type gpu_event_state_type is (startup, startNextFrame, startNextRead, getNextLayer, readHits, writeNumHits, closeGPUEvent);
    signal gpu_event_state : gpu_event_state_type;

    -- dma signals
    type state_type_dma is (idle, data, write_4kb_padding);
    signal state_dma : state_type_dma;
    signal done, event_counter_written, endofevent : std_logic;
    signal event_counter, word_counter_endofevent, cnt_4kb, dma_cnt_words : std_logic_vector(31 downto 0);

begin

    --! backpressure output
    -- NOTE: we "or" here when one of the layer FIFOs is almost full
    -- at the backpressure side we have to make sure to skip the same
    -- frames from each of the layers.
    -- One way would be to get back a signal from where the backpressures
    -- is handled which says I have skipped now from each layer equally
    -- amount of frames we can now reset the global almost full bit
    o_almost_full <= or_reduce(almost_full);

    --! get float hits per layer fill them to buffer FIFO and count the hits
    gen_buffer_hits : for i in 0 to 3 generate
    process(i_clk, i_reset_n)
        variable cur_cnt_hits : std_logic_vector(31 downto 0) := (others => '0');
    begin
    if ( i_reset_n = '0' ) then
        cnt_hits(i)         <= (others => '0');
        cur_frame(i)        <= (others => '0');
        tag_fifo_wdata(i)   <= (others => '0');
        tag_fifo_wen(i)     <= '0';
        fifo_wdata(i)       <= (others => '0');
        start_buffer(i)     <= '0';
        fifo_wen(i)         <= '0';
        --
    elsif rising_edge(i_clk) then

        cur_cnt_hits := (others => '0');
        tag_fifo_wen(i) <= '0';
        fifo_wen(i) <= '0';
        fifo_wdata(i) <= i_float_hit(i);

        -- TODO: The stop logic needs to be send an end of request marker
        -- which needs to be pushed out to the 2MB GPU event. We can use
        -- this also for the end of run.
        -- We wait until we are enabled and than we can start to get data
        -- if we see SOP otherwise we throw data away.
        if ( i_wen = '1' and i_sop(i) = '1' ) then
            start_buffer(i) <= '1';
        -- if we stopped we read until the EOP
        elsif ( i_wen = '0' and i_eop(i) = '1' ) then
            start_buffer(i) <= '0';
        end if;

        if ( almost_full(i) = '0' and almost_full(i+4) = '0' and (start_buffer(i) = '1' or (i_wen = '1' and i_sop(i) = '1'))) then
            if ( i_valid(i) = '1' ) then
                fifo_wen(i) <= '1';
                cnt_hits(i) <= cnt_hits(i) + '1';
            end if;

            -- at the end of the package we store the number of hits we stored in the buffer
            -- we also store the current frame number
            -- NOTE: we always increase the frame counter even if there was no hit in the frame
            -- i_valid(i) = '0' and i_eop(i) = '1' -> no hits in the frame
            -- TODO: maybe better to count the current frames outside and use it also for the DDR RAM
            if ( i_eop(i) = '1' ) then
                cur_frame(i) <= cur_frame(i) + '1';
                cnt_hits(i) <= x"00000000";
                tag_fifo_wen(i) <= '1';
                if ( i_valid(i) = '1' ) then
                    cur_cnt_hits := cnt_hits(i) + '1';
                else
                    cur_cnt_hits := cnt_hits(i);
                end if;
                tag_fifo_wdata(i) <= cur_frame(i) & cur_cnt_hits;
            end if;
        end if;
    end if;
    end process;

    e_tag_fifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 12,
        g_DATA_WIDTH => 64,
        g_RREG_N => 1--,
    )
    port map (
        i_we        => tag_fifo_wen(i),
        i_wdata     => tag_fifo_wdata(i),
        o_usedw     => tag_fifo_wrusedw(i),

        i_rack      => tag_fifo_ren(i),
        o_rdata     => tag_fifo_rdata(i),
        o_rempty    => tag_fifo_empty(i),

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    e_layer_fifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 12,
        g_DATA_WIDTH => 96--,
    )
    port map (
        i_we        => fifo_wen(i),
        i_wdata     => fifo_wdata(i),
        o_usedw     => fifo_wrusedw(i),

        i_rack      => fifo_ren(i),
        o_rdata     => fifo_rdata(i),
        o_rempty    => fifo_empty(i),

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        almost_full(i) <= '0';
        almost_full(i+4) <= '0';
    elsif rising_edge(i_clk) then
        if ( tag_fifo_wrusedw(i)(11) = '1' ) then
            almost_full(i) <= '1';
        else
            almost_full(i) <= '0';
        end if;
        if ( fifo_wrusedw(i)(11) = '1' ) then
            almost_full(i+4) <= '1';
        else
            almost_full(i+4) <= '0';
        end if;
    end if;
    end process;
    end generate;

    --! MUX 4->1 readout of the different layers, create 2MB GPU package
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        gpu_event_cnt       <= i_gpu_size; -- 166666.67 x 96b = 2MB | 28B0A x 96b + 64b = 2MB
        gpu_padding_cnt     <= (others => '0');
        num_frames          <= (others => '0');
        total_frames        <= (others => '0');
        gpu_hit_cnt         <= "00";
        layer_index         <= 0;
        gpu_event_state     <= startup;
        --
    elsif rising_edge(i_clk) then

        -- default values
        gpu_event_wen <= '0';
        gpu_tag_fifo_wen <= '0';
        gpu_tag_fifo_ren <= '0';
        tag_fifo_ren <= (others => '0');
        fifo_ren <= (others => '0');

        case gpu_event_state is

        when startup =>
            -- wait until the entity is started
            if ( i_wen = '1' ) then
                gpu_event_state <= startNextFrame;
                num_frames <= (others => '0');
                started <= '0';
                gpu_event_cnt <= i_gpu_size; -- 166666.67 x 96b = 2MB | 0x28B0A x 96b + 64b = 2MB
            end if;

        when startNextFrame =>
            -- we close the event if the counter is less than 1000 96b words
            -- space for the counters of 1000 frames in the GPU event left
            -- NOTE: this value has to be tuned
            if ( gpu_event_cnt <= i_padding ) then
                -- change state to write padding
                gpu_event_state <= writeNumHits;
                gpu_hit_cnt <= "00";

                -- to calculate the padding between hits and counters substract the num_frames from the gpu_event_cnt
                -- NOTE: at the end we have 64bit left which we fill with the #frames and #totalFrames
                gpu_padding_cnt <= gpu_event_cnt - num_frames;

            elsif ( tag_fifo_empty(layer_index) = '0' and fifo_empty(layer_index) = '0' and almost_full(9) = '0' ) then
                gpu_event_state <= getNextLayer;
                num_frames <= num_frames + '1';
                if ( not (tag_fifo_rdata(layer_index)(31 downto 0) = 0) ) then
                    fifo_ren(layer_index) <= '1'; -- preread if we have hits
                end if;
            end if;

        when startNextRead =>
            -- TODO: we need this to preread the FIFO, one can think of doing this before in the state change of readHits since we loose a cycle here
            if ( tag_fifo_empty(layer_index) = '0' and fifo_empty(layer_index) = '0' and almost_full(9) = '0' ) then
                gpu_event_state <= getNextLayer;
                if ( not (tag_fifo_rdata(layer_index)(31 downto 0) = 0) ) then
                    fifo_ren(layer_index) <= '1'; -- preread if we have hits
                end if;
            end if;

        when getNextLayer =>
            -- check if the next tag fifo is empty and the GPU event FIFO has space left
            -- NOTE: we block here to have a fair round robin (no frame should be skipped)
            if ( tag_fifo_empty(layer_index) = '0' and fifo_empty(layer_index) = '0' and almost_full(9) = '0' ) then

                -- readout tag FIFO and store number of hits of the current layer in GPU tag FIFO
                tag_fifo_ren(layer_index) <= '1';
                gpu_tag_fifo_wen <= '1';
                gpu_tag_fifo_data <= tag_fifo_rdata(layer_index)(31 downto 0);

                -- for simulation
                -- check if we have the correct frame number
                -- synthesis translate_off
                if ( not (tag_fifo_rdata(layer_index)(63 downto 32) = total_frames) ) then
                    report "total_frames " & work.util.to_hstring(total_frames);
                    report "tag_fifo_rdata " & work.util.to_hstring(tag_fifo_rdata(layer_index)(63 downto 32));
                end if;
                -- synthesis translate_on

                -- if we have 0 words for this layer we just increase the index and count up the counter numbers
                if ( tag_fifo_rdata(layer_index)(31 downto 0) = 0 ) then
                    layer_index <= layer_index + 1;
                    if ( layer_index = 3 ) then
                        layer_index <= 0;
                        gpu_event_state <= startNextFrame;
                        total_frames <= total_frames + '1';
                    else
                        gpu_event_state <= startNextRead; -- we go to read the next layer
                    end if;
                else
                    -- if we have words in the fifo we read out
                    -- words and store them in the GPU event fifo
                    fifo_ren(layer_index) <= '1';
                    -- store the current number of hits
                    cur_num_hits <= tag_fifo_rdata(layer_index)(31 downto 0) - '1';
                    if ( started = '0' ) then
                        started <= '1';
                        gpu_event_data <= "01" & fifo_rdata(layer_index); -- SOP for the full 2MB GPU
                    else
                        gpu_event_data <= "00" & fifo_rdata(layer_index); -- Hit data
                    end if;
                    gpu_event_wen <= '1';
                    gpu_event_cnt <= gpu_event_cnt - '1';
                    -- if we only have one hit just increase the layer_index
                    if ( tag_fifo_rdata(layer_index)(31 downto 0) = 1 ) then
                        layer_index <= layer_index + 1;
                        if ( layer_index = 3 ) then
                            layer_index <= 0;
                            gpu_event_state <= startNextFrame;
                            total_frames <= total_frames + '1';
                        else
                            gpu_event_state <= startNextRead; -- we go to read the next layer
                        end if;
                    else
                        gpu_event_state <= readHits; -- we have more than one hit
                    end if;
                end if;
            end if;

        when readHits =>
            -- read until cur_num_hits is zero
            if ( fifo_empty(layer_index) = '0' and almost_full(9) = '0' ) then
                -- if we have words in the fifo we readout these
                -- words and store them in the GPU event fifo
                fifo_ren(layer_index) <= '1';
                cur_num_hits <= cur_num_hits - '1';
                gpu_event_data <= "00" & fifo_rdata(layer_index); -- Hit data
                gpu_event_wen <= '1';
                gpu_event_cnt <= gpu_event_cnt - '1';
                -- if we only have one hit we just increase the layer_index
                if ( cur_num_hits = 1 ) then
                    layer_index <= layer_index + 1;
                    if ( layer_index = 3 ) then
                        layer_index <= 0;
                        gpu_event_state <= startNextFrame;
                        total_frames <= total_frames + '1';
                    else
                        gpu_event_state <= startNextRead; -- we go to read the next layer
                    end if;
                end if;
            end if;

        when writeNumHits =>
            if ( almost_full(9) = '0' ) then
                if ( gpu_padding_cnt = 0 ) then
                    -- write out number of hits
                    if ( gpu_tag_fifo_empty = '0' ) then
                        -- the gpu_tag_fifo should look like
                        ------------------ <- 96bit word
                        -- #Hits Frame1 L3 <- last word
                        -- #Hits Frame1 L2
                        -- #Hits Frame1 L1
                        -- #Hits Frame1 L0
                        ------------------ <- 96bit word
                        -- #Hits Frame0 L3
                        -- #Hits Frame0 L2
                        -- #Hits Frame0 L1
                        -- #Hits Frame0 L0 <- first word
                        ------------------
                        -- read the number of hits from the fifo and write them into the GPU event FIFO
                        gpu_tag_fifo_ren <= '1';
                        gpu_hit_cnt <= gpu_hit_cnt + '1';
                        gpu_event_data(97 downto 96) <= "11"; -- marker for counter values
                        if ( gpu_hit_cnt = "00" ) then
                            gpu_event_data(23 downto  0) <= gpu_tag_fifo_rdata(23 downto 0);
                        elsif ( gpu_hit_cnt = "01" ) then
                            gpu_event_data(47 downto 24) <= gpu_tag_fifo_rdata(23 downto 0);
                        elsif ( gpu_hit_cnt = "10" ) then
                            gpu_event_data(71 downto 48) <= gpu_tag_fifo_rdata(23 downto 0);
                        end if;
                        -- if we have all 4 counters we write out the GPU event count
                        if ( gpu_hit_cnt = "11" ) then
                            gpu_hit_cnt <= (others => '0');
                            gpu_event_cnt <= gpu_event_cnt - '1';
                            gpu_event_wen <= '1';
                            -- set the last word of the counter
                            gpu_event_data(95 downto 72) <= gpu_tag_fifo_rdata(23 downto 0);
                            -- if we at the end of the event cnt we close the GPU event
                            -- NOTE: if everything was done correctly this should be 1 if we have
                            -- written 2MB - 64bits
                            if ( gpu_event_cnt = 1 ) then
                                gpu_event_state <= closeGPUEvent;
                            end if;
                        end if;
                    end if;
                else
                    -- write out padding
                    gpu_padding_cnt <= gpu_padding_cnt - '1';
                    gpu_event_cnt <= gpu_event_cnt - '1';
                    gpu_event_data <= (others => '0');
                    gpu_event_wen <= '1';
                end if;
            end if;

        when closeGPUEvent =>
            if ( almost_full(9) = '0' ) then
                -- we have two 64bit words left for 2MB we write a 96bit word but dont care about the upper 32bit later
                gpu_event_wen <= '1';
                gpu_event_data(97 downto 96) <= "10"; -- EOP GPU
                gpu_event_data(95 downto 64) <= (others => '0');
                gpu_event_data(63 downto 32) <= num_frames;
                gpu_event_data(31 downto  0) <= total_frames;
                -- reset signals change state
                gpu_hit_cnt <= (others => '0');
                gpu_event_state <= startup;
            end if;

        when others =>
            gpu_event_state <= startup;

        end case;

    end if;
    end process;

    e_gpu_event_fifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 12,
        g_DATA_WIDTH => 98--,
    )
    port map (
        i_we        => gpu_event_wen,
        i_wdata     => gpu_event_data,
        o_usedw     => gpu_event_wrusedw,

        i_rack      => gpu_event_ren,
        o_rdata     => gpu_event_rdata,
        o_rempty    => gpu_event_empty,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    --! convert 96bit hits into 256bit hits
    gpu_event_ren <= not gpu_event_empty and not almost_full(10); -- read when we have space and the FIFO is not empty
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        gpu_dma_data <= (others => '0');
        gpu_dma_cnt <= (others => '0');
        buffer_event_fifo <= (others => '0');
        tag_dma_data <= "00";
        --
    elsif rising_edge(i_clk) then
        -- default values
        gpu_dma_wen <= '0';

        -- check if the the dma FIFO has space and if we have hits
        if ( almost_full(10) = '0' and gpu_event_empty = '0' ) then

            -- check if we are at the end of the 2MB package and reset counter
            if ( gpu_event_rdata(97 downto 96) = "10" ) then
                gpu_dma_cnt <= (others => '0');
            else
                gpu_dma_cnt <= gpu_dma_cnt + '1';
            end if;

            -- store SOP/EOP for tagging FIFO
            if ( gpu_event_rdata(97 downto 96) = "01" or gpu_event_rdata(97 downto 96) = "10" ) then
                tag_dma_data <= gpu_event_rdata(97 downto 96);
            end if;

            -- for simulation
            -- check if we are at the end of the GPU package and gpu_dma_cnt = "010"
            -- synthesis translate_off
            if ( gpu_event_rdata(97 downto 96) = "10" and not ( gpu_dma_cnt = "010" ) ) then
                report "We saw EOP but gpu_dma_cnt is not 010 but " & work.util.to_hstring(gpu_dma_cnt);
            end if;
            -- synthesis translate_on

            -- different unpack states
            if ( gpu_dma_cnt = "000" ) then
                gpu_dma_data(95 downto 0) <= gpu_event_rdata(95 downto 0);
            elsif ( gpu_dma_cnt = "001" ) then
                gpu_dma_data(191 downto 96) <= gpu_event_rdata(95 downto 0);
            elsif ( gpu_dma_cnt = "010" ) then
                buffer_event_fifo(31 downto 0) <= gpu_event_rdata(95 downto 64);
                if ( gpu_event_rdata(97 downto 96) = "10" ) then
                    gpu_dma_data(257 downto 256) <= "10";
                else
                    gpu_dma_data(257 downto 256) <= tag_dma_data;
                end if;
                gpu_dma_data(255 downto 192) <= gpu_event_rdata(63 downto 0);
                gpu_dma_wen <= '1';
                tag_dma_data <= "00"; -- reset tagging data
            elsif ( gpu_dma_cnt = "011" ) then
                gpu_dma_data(31 downto 0) <= buffer_event_fifo(31 downto 0);
                gpu_dma_data(127 downto 32) <= gpu_event_rdata(95 downto 0);
            elsif ( gpu_dma_cnt = "100" ) then
                gpu_dma_data(223 downto 128) <= gpu_event_rdata(95 downto 0);
            elsif ( gpu_dma_cnt = "101" ) then
                buffer_event_fifo(63 downto 0) <= gpu_event_rdata(95 downto 32);
                gpu_dma_data(257 downto 256) <= tag_dma_data;
                gpu_dma_data(255 downto 224) <= gpu_event_rdata(31 downto 0);
                gpu_dma_wen <= '1';
                tag_dma_data <= "00"; -- reset tagging data
            elsif ( gpu_dma_cnt = "110" ) then
                gpu_dma_data(63 downto 0) <= buffer_event_fifo(63 downto 0);
                gpu_dma_data(159 downto 64) <= gpu_event_rdata(95 downto 0);
            elsif ( gpu_dma_cnt = "111" ) then
                gpu_dma_data(257 downto 256) <= tag_dma_data;
                gpu_dma_data(255 downto 160) <= gpu_event_rdata(95 downto 0);
                gpu_dma_wen <= '1';
                tag_dma_data <= "00"; -- reset tagging data
            end if;
        end if;
    end if;
    end process;

    e_gpu_dma_fifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 12,
        g_DATA_WIDTH => 258--,
    )
    port map (
        i_we        => gpu_dma_wen,
        i_wdata     => gpu_dma_data,
        o_usedw     => gpu_dma_wrusedw,

        i_rack      => gpu_dma_ren,
        o_rdata     => gpu_dma_rdata,
        o_rempty    => gpu_dma_empty,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    e_gpu_tag_fifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 12,
        g_DATA_WIDTH => 32--,
    )
    port map (
        i_we        => gpu_tag_fifo_wen,
        i_wdata     => gpu_tag_fifo_data,
        o_usedw     => gpu_tag_fifo_wrusedw,

        i_rack      => gpu_tag_fifo_ren,
        o_rdata     => gpu_tag_fifo_rdata,
        o_rempty    => gpu_tag_fifo_empty,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        almost_full(8) <= '0';
        almost_full(9) <= '0';
        almost_full(10) <= '0';
    elsif rising_edge(i_clk) then
        if ( gpu_tag_fifo_wrusedw(11) = '1' ) then
            almost_full(8) <= '1';
        else
            almost_full(8) <= '0';
        end if;
        if ( gpu_event_wrusedw(11) = '1' ) then
            almost_full(9) <= '1';
        else
            almost_full(9) <= '0';
        end if;
        if ( gpu_dma_wrusedw(11) = '1' ) then
            almost_full(10) <= '1';
        else
            almost_full(10) <= '0';
        end if;
    end if;
    end process;

    --! output data and read signal for GPU DMA FIFO
    o_dma_data <= (others => '1') when state_dma = write_4kb_padding else gpu_dma_rdata(255 downto 0);
    gpu_dma_ren <= '1' when state_dma = data and gpu_dma_empty = '0' and i_dmamemhalffull = '0' else '0';
    o_dma_wen <= '1' when (state_dma = write_4kb_padding or (state_dma = data and gpu_dma_empty = '0')) and i_dmamemhalffull = '0' else '0';
    o_endofevent <= endofevent;
    o_dma_cnt_words <= dma_cnt_words;
    o_dma_done <= done;

    --! send out GPU events
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        state_dma                   <= idle;
        endofevent                  <= '0';
        event_counter               <= (others => '0');
        done                        <= '0';
        event_counter_written       <= '0';
        word_counter_endofevent    <= (others => '0');
        --
    elsif rising_edge(i_clk) then

        -- enable and default values
        endofevent <= '0';
        if ( i_wen = '0' ) then
            event_counter           <= (others => '0');
            done                    <= '0';
            event_counter_written   <= '0';
            word_counter_endofevent <= (others => '0');
        end if;

        case state_dma is
        when idle =>
            if ( event_counter_written = '1' and event_counter = 0 and i_wen = '1' and done = '0' and i_dmamemhalffull = '0' ) then
                endofevent  <= '1';
                state_dma   <= write_4kb_padding;
                cnt_4kb     <= (others => '0');
            -- if we are enabled, have a new request (i_get_n_events), not backpressure (i_dmamemhalffull) and have a SOP in the event FIFO we start the readout
            elsif ( i_wen = '1' and i_get_n_events /= 0 and done = '0' and i_dmamemhalffull = '0' and gpu_dma_empty = '0' and gpu_dma_rdata(257 downto 256) = "01" ) then
                state_dma <= data;
                -- if we come here after a reset we reset the event_counter for reading out the number of requested events
                if ( event_counter_written = '0' ) then
                    event_counter            <= i_get_n_events;
                    event_counter_written    <= '1';
                end if;
            end if;
            --
        when data =>
            -- we check again if the event FIFO has entries and we don't have backpressure
            if ( gpu_dma_empty = '0' and i_dmamemhalffull = '0' ) then
                -- if we see the EOP we go back to IDLE
                if ( gpu_dma_rdata(257 downto 256) = "10" ) then
                    state_dma <= idle;
                    -- we just have written a full event so we decrease the event counter
                    if ( event_counter /= 0 ) then
                        event_counter <= event_counter - '1';
                    end if;
                end if;
                -- we increase the word counter to keep track of the 256b words we have written
                word_counter_endofevent <= word_counter_endofevent + '1';
            end if;
            --
        when write_4kb_padding =>
            -- we just make sure to trigger one DMA readout 4kB
            if ( i_dmamemhalffull = '0' ) then
                if ( cnt_4kb = "01111111" ) then
                    done <= '1';
                    -- set the last 256b word written to a register output
                    dma_cnt_words <= word_counter_endofevent;
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

-------------------------------------------------------
--! @links_to_fifos.vhd
--! @brief the links_to_fifos takes n input links and
--! stores them in FIFOs. it also takes care that each
--! link sends the same amount of events
--! Author: mkoepp@phys.ethz.ch
-------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;
use work.mudaq.all;

entity links_to_fifos is
generic (
    g_LINK_N        : positive := 8--;
);
port (
    i_rx            : in  work.mu3e.link32_array_t(g_LINK_N-1 downto 0);
    i_rmask_n       : in  std_logic_vector(g_LINK_N-1 downto 0);

    i_lookup_ctrl   : in  std_logic_vector(31 downto 0);
    i_sync_enable   : in  std_logic;

    o_q             : out work.mu3e.link64_array_t(g_LINK_N-1 downto 0);
    i_ren           : in  std_logic_vector(g_LINK_N-1 downto 0);
    o_rdempty       : out std_logic_vector(g_LINK_N-1 downto 0);

    o_counter       : out slv32_array_t(13*g_LINK_N-1 downto 0) := (others => (others => '0'));
    i_reset_n_cnt   : in  std_logic;

    i_reset_n       : in  std_logic;
    i_clk           : in  std_logic--;
);
end entity;

architecture arch of links_to_fifos is

    signal cnt_skipped_sorter_package, cnt_subheaders, cnt_almost_full, cnt_full, cnt_full_subheader_overflow, cnt_skip_hits, cnt_skip_subheader, cnt_full_ts_overflow, cnt_hits : slv32_array_t(g_LINK_N-1 downto 0);
    signal cnt_sorter_package : slv64_array_t(g_LINK_N-1 downto 0);
    signal write_events, skip_events : std_logic_vector(15 downto 0);
    signal full_subheader_overflow : slv3_array_t(g_LINK_N-1 downto 0);

    signal q_rx_buffer, in_rx, q_subheader_buffer : work.mu3e.link32_array_t(g_LINK_N-1 downto 0);
    signal rack_rx_buffer, rdempty_rx_buffer, rack_subheader_buffer, rempty_subheader_buffer, valid_fifos, valid_sop, valid_sbhdr, valid_eop, valid_sbhdr_or_sop, valid_sbhdr_or_eop : std_logic_vector(g_LINK_N-1 downto 0);
    signal ts_high, shift_data : slv32_array_t(g_LINK_N-1 downto 0);
    signal ts_low, last_subheader_overflow, saw_input_chipIDs : slv16_array_t(g_LINK_N-1 downto 0);
    signal last_subheader_time : slv8_array_t(g_LINK_N-1 downto 0);

    signal rx : work.mu3e.link64_array_t(g_LINK_N-1 downto 0);
    signal rx_wen, wrfull, we_write_this_package, skip_subheader : std_logic_vector(g_LINK_N-1 downto 0);
    signal wrusedw : slv14_array_t(g_LINK_N-1 downto 0);

    signal package_stage : slv3_array_t(g_LINK_N-1 downto 0);
    signal globalChipID : slv14_array_t(g_LINK_N-1 downto 0);
    signal data_type : slv6_array_t(g_LINK_N-1 downto 0);
    signal FEBChipID : slv6_array_t(g_LINK_N-1 downto 0);

    signal local_resets_n : std_logic_vector(7 downto 0);

begin

    e_local_resets_n : entity work.ff_sync
    generic map ( W => local_resets_n'length )
    port map (
        o_q => local_resets_n,
        i_d => (others => '1'),
        i_reset_n => i_reset_n,
        i_clk => i_clk--,
    );

    gen_chip_lookup_and_fifos : for i in 0 to g_LINK_N-1 GENERATE

        --! shift subheader overflow
        -- we have the following hit data from the sorter:
        --------- PACKAGE ---------
        -- HEADER
        -- T0
        -- T1
        -- D0
        -- D1
        -- SUBHEADER0
        -- HIT with TS 0
        -- HIT with TS 0
        -- ...
        -- OVERFLOW at TS 0   <--|
        -- HITs                  |
        -- SUBHEADER1 ----------- The overflow of TS0 is stored in the next subheader
        -- HITs
        -- SUBHEADER2
        -- SUBHEADER3
        -- ..
        -- SUBHEADER127
        -- HIT with TS 0
        -- HIT with TS 0
        -- ...
        -- OVERFLOW at TS 0   <--|
        -- HITs                  |
        -- TRAILER -------------- The last overflow of TS0 is stored in the trailer
        --------- PACKAGE ---------
        -- The following code is shifting this overlflow information from e.g. SUBHEADER1 to SUBHEADER0
        -- and from the trailer to SUBHEADER127
        e_buffer_full_package : entity work.link32_scfifo
        generic map (
            -- NOTE: one subheader can have 16 TS * 16 HITs * 12 LINKS so we need a bit of headroom
            g_ADDR_WIDTH => 12,
            g_WREG_N => 2,
            g_RREG_N => 2--,
        )
        port map (
            i_wdata     => i_rx(i),
            i_we        => not i_rx(i).idle,

            o_rdata     => q_rx_buffer(i),
            i_rack      => rack_rx_buffer(i),
            o_rempty    => rdempty_rx_buffer(i),

            i_reset_n   => local_resets_n(0),
            i_clk       => i_clk--,
        );

        e_buffer_subheaders : entity work.link32_scfifo
        generic map (
            -- NOTE: we have 128 subheader for one mupix package and for Sci* we have 256
            g_ADDR_WIDTH => 10,
            g_WREG_N => 2,
            g_RREG_N => 2--
        )
        port map (
            i_wdata     => i_rx(i),
            i_we        => i_rx(i).sbhdr or i_rx(i).eop,

            o_rdata     => q_subheader_buffer(i),
            i_rack      => rack_subheader_buffer(i),
            o_rempty    => rempty_subheader_buffer(i),

            i_reset_n   => local_resets_n(1),
            i_clk       => i_clk--,
        );

        -- generate valid signals
        valid_fifos(i) <= '1' when rdempty_rx_buffer(i) = '0' and rempty_subheader_buffer(i) = '0' else '0';
        valid_sop(i) <= '1' when q_rx_buffer(i).sop = '1' and valid_fifos(i) = '1' else '0';
        valid_sbhdr(i) <= '1' when q_rx_buffer(i).sbhdr = '1' and valid_fifos(i) = '1' else '0';
        valid_eop(i) <= '1' when q_rx_buffer(i).eop = '1' and valid_fifos(i) = '1' else '0';
        valid_sbhdr_or_sop(i) <= valid_sbhdr(i) or valid_sop(i);
        valid_sbhdr_or_eop(i) <= valid_sbhdr(i) or valid_eop(i);

        -- we replace the subheader information with the next one for the trailer we put zero for the overflow
        shift_data(i) <= q_rx_buffer(i).data(31 downto 24) & q_subheader_buffer(i).data(23 downto 8) & q_rx_buffer(i).data(7 downto 0) when valid_sbhdr(i) = '1' else
                         q_rx_buffer(i).data(31 downto 24) & x"0000" & q_rx_buffer(i).data(7 downto 0);

        -- generate rack
        -- NOTE: the first subheader has no overflow information so we read it (sop)
        rack_rx_buffer(i) <= '1' when valid_fifos(i) = '1' else '0';
        rack_subheader_buffer(i) <= '1' when valid_sbhdr_or_sop(i) = '1' else '0';

        -- process to shift the subheader
        process(i_clk, local_resets_n)
        begin
        if ( local_resets_n(2) /= '1' ) then
            in_rx(i) <= work.mu3e.LINK32_IDLE;
        elsif rising_edge(i_clk) then
            in_rx(i) <= work.mu3e.LINK32_IDLE;
            if ( valid_sbhdr_or_eop(i) = '1' ) then
                in_rx(i) <= work.mu3e.to_link(shift_data(i), "0001");
            elsif ( valid_fifos(i) = '1' ) then
                in_rx(i) <= q_rx_buffer(i);
            end if;
        end if;
        end process;

        -- in the next step we replace the local chipID to the global one, change the hit from 32bit to 64bit and store the data in another FIFO
        FEBChipID(i) <= in_rx(i).data(27 downto 22) when data_type(i) = OUTER_HEADER_ID else
                        "00" & in_rx(i).data(25 downto 22) when data_type(i) = MUPIX_HEADER_ID or data_type(i) = TILE_HEADER_ID else
                        "000" & in_rx(i).data(24 downto 22) when data_type(i) = SCIFI_HEADER_ID else
                        (others => '0');

        e_lookup : entity work.chip_lookup
        port map (
            i_fpgaID        => work.mudaq.link_36_to_std(i),
            i_FEBChipID     => FEBChipID(i),
            i_data_type     => data_type(i),

            i_lookup_ctrl   => i_lookup_ctrl,

            o_globalChipID  => globalChipID(i),

            i_reset_n       => local_resets_n(3),
            i_clk           => i_clk--,
        );

        e_fifo : entity work.link64_scfifo
        generic map (
            g_ADDR_WIDTH => 14,
            g_WREG_N => 2,
            g_RREG_N => 2--,
        )
        port map (
            i_wdata     => rx(i),
            i_we        => rx_wen(i),
            o_wfull     => wrfull(i),
            o_usedw     => wrusedw(i),

            o_rdata     => o_q(i),
            i_rack      => i_ren(i),
            o_rempty    => o_rdempty(i),

            i_reset_n   => local_resets_n(4),
            i_clk       => i_clk--,
        );

        o_counter(i*13+ 0) <= cnt_almost_full(i);
        o_counter(i*13+ 1) <= cnt_full(i);
        o_counter(i*13+ 2) <= cnt_skipped_sorter_package(i);
        o_counter(i*13+ 3) <= cnt_sorter_package(i)(31 downto 0);
        o_counter(i*13+ 4) <= cnt_sorter_package(i)(63 downto 32);
        o_counter(i*13+ 5) <= cnt_subheaders(i);
        o_counter(i*13+ 6) <= cnt_full_subheader_overflow(i);
        o_counter(i*13+ 7) <= cnt_skip_hits(i);
        o_counter(i*13+ 8) <= cnt_skip_subheader(i);
        o_counter(i*13+ 9) <= cnt_full_ts_overflow(i);
        o_counter(i*13+10) <= cnt_hits(i);
        o_counter(i*13+11)(15 downto 0) <= saw_input_chipIDs(i);
        o_counter(i*13+12) <= write_events & skip_events;

    end generate;

    --! write only if not idle
    process(i_clk, local_resets_n)
    begin
    if ( local_resets_n(5) /= '1' ) then
        rx <= (others => work.mu3e.LINK64_ZERO);
        data_type <= (others => (others => '0'));
        rx_wen <= (others => '0');
        skip_events <= (others => '0');
        write_events <= (others => '0');
        we_write_this_package <= (others => '0');
        package_stage <= (others => (others => '0'));
        --
    elsif rising_edge(i_clk) then

        -- reset sop/eop/sh etc.
        rx <= (others => work.mu3e.LINK64_ZERO);

        -- reset counters
        if ( i_reset_n_cnt /= '1' ) then
            cnt_skipped_sorter_package <= (others => (others => '0'));
            cnt_subheaders <= (others => (others => '0'));
            cnt_sorter_package <= (others => (others => '0'));
            cnt_almost_full <= (others => (others => '0'));
            cnt_full <= (others => (others => '0'));
            cnt_full_subheader_overflow <= (others => (others => '0'));
            cnt_full_ts_overflow <= (others => (others => '0'));
            cnt_skip_hits <= (others => (others => '0'));
            cnt_hits <= (others => (others => '0'));
            cnt_skip_subheader <= (others => (others => '0'));
            saw_input_chipIDs <= (others => (others => '0'));
            full_subheader_overflow <= (others => (others => '0'));
        end if;

        for i in 0 to g_LINK_N-1 loop

            rx_wen(i) <= '0';

            -- reset sop/eop/sh
            rx(i).sop <= '0';
            rx(i).eop <= '0';
            rx(i).sbhdr <= '0';
            rx(i).t0 <= '0';
            rx(i).t1 <= '0';
            rx(i).d0 <= '0';
            rx(i).d1 <= '0';
            rx(i).dthdr <= '0';
            rx(i).err <= '0';
            rx(i).k <= '0';

            if ( in_rx(i).idle = '0' and i_rmask_n(i) = '1' ) then

                -- count how many times we are almost full or full when we want to write stuff
                if ( wrusedw(i)(13) = '1' ) then
                    cnt_almost_full(i) <= cnt_almost_full(i) + '1';
                end if;
                if ( wrfull(i) = '1' ) then
                    cnt_full(i) <= cnt_full(i) + '1';
                end if;

                if ( in_rx(i).sop = '1' ) then
                    -- check if we can accept the package
                    if ( wrfull(i) = '0' ) then
                        we_write_this_package(i) <= '1';
                        package_stage(i) <= "000";
                        rx_wen(i) <= '1';
                        -- set 64bit data
                        rx(i).sop <= '1';
                        rx(i).data(31 downto 0) <= in_rx(i).data;
                        rx(i).k <= '1';
                    else
                        cnt_skipped_sorter_package(i) <= cnt_skipped_sorter_package(i) + '1';
                    end if;
                    -- store package type
                    data_type(i) <= in_rx(i).data(31 downto 26);
                end if;

                if ( we_write_this_package(i) = '1' ) then
                    rx_wen(i) <= '1';
                    if ( package_stage(i) = "000" ) then
                        ts_high(i) <= in_rx(i).data;
                        package_stage(i) <= "001";
                        -- set 64bit data
                        rx(i).t0 <= '1';
                        rx(i).data(31 downto 0) <= in_rx(i).data;
                    elsif ( package_stage(i) = "001" ) then
                        ts_low(i) <= in_rx(i).data(31 downto 16);
                        package_stage(i) <= "010";
                        -- set 64bit data
                        rx(i).t1 <= '1';
                        rx(i).data(31 downto 0) <= in_rx(i).data;
                    elsif ( package_stage(i) = "010" ) then
                        package_stage(i) <= "011";
                        -- set 64bit data
                        rx(i).d0 <= '1';
                        rx(i).data(31 downto 0) <= in_rx(i).data;
                    elsif ( package_stage(i) = "011" ) then
                        package_stage(i) <= "100";
                        -- set 64bit data
                        rx(i).d1 <= '1';
                        rx(i).data(31 downto 0) <= in_rx(i).data;
                    elsif ( in_rx(i).eop = '1' ) then
                        cnt_sorter_package(i) <= cnt_sorter_package(i) + '1';
                        we_write_this_package(i) <= '0';
                        -- set 64bit data
                        rx(i).eop <= '1';
                        rx(i).k <= '1';
                        rx(i).data(31 downto 0) <= in_rx(i).data;
                        if ( full_subheader_overflow(i)(2) = '1' or full_subheader_overflow(i) = "010" ) then
                            rx(i).data(8) <= '1'; -- this means one of the subheaders before had an overflow and there was no hits (sorter overflow)
                            full_subheader_overflow(i) <= "000";
                        end if;
                    elsif ( in_rx(i).sbhdr = '1' ) then
                        cnt_subheaders(i) <= cnt_subheaders(i) + '1';
                        last_subheader_time(i) <= in_rx(i).data(31 downto 24);
                        last_subheader_overflow(i) <= in_rx(i).data(23 downto 8);
                        full_subheader_overflow(i)(0) <= '0';

                        -- we have two options here which we have to check when we write a hit
                        -- 1. if we dont have hits then we had a full subheader overflow in the sorter
                        --    or in this entity wrusedw(i)(13) = '1'
                        -- 2. if we have hits then all timestamps had an overflow
                        -- 3. we have a full overflow then a subheader with no hits then another one with an
                        --    overflow of all timestamps
                        if ( in_rx(i).data(23 downto 8) = x"FFFF" or wrusedw(i)(13) = '1' ) then
                            -- 1. first bit is used to count up the first case because in this case we
                            --    dont have hits but directly another subheader
                            -- 2. second bit is sticky until we see a hit and then we set a bit in the hit
                            -- 3. third bit is set to one to write also the correct bit in the next hit
                            if ( full_subheader_overflow(i)(1) = '1' ) then
                                full_subheader_overflow(i) <= "111";
                            else
                                full_subheader_overflow(i) <= "011";
                            end if;
                            cnt_full_ts_overflow(i) <= cnt_full_ts_overflow(i) + '1'; -- option 2. is always true
                        end if;

                        -- if we have another subheader before full_subheader_overflow(0)
                        -- was reset we had no hits which means 1. was true
                        if ( full_subheader_overflow(i)(0) = '1' ) then
                            cnt_full_subheader_overflow(i) <= cnt_full_subheader_overflow(i) + '1';
                        end if;

                        -- if the FIFO is almost full we skip the hits afterwords
                        skip_subheader(i) <= '0';
                        if ( wrusedw(i)(13) = '1' ) then
                            skip_subheader(i) <= '1';
                            cnt_skip_subheader(i) <= cnt_skip_subheader(i) + '1';
                        end if;

                        -- set 64bit data
                        rx(i).sbhdr <= '1';
                        rx(i).k <= '1';
                        rx(i).data(31 downto 0) <= in_rx(i).data;
                    else
                        -- we skip all hits here
                        if ( skip_subheader(i) = '1' or wrusedw(i)(13) = '1' or wrfull(i) = '1' ) then
                            rx_wen(i) <= '0';
                            cnt_skip_hits(i) <= cnt_skip_hits(i) + '1';
                            if ( wrfull(i) = '1' ) then
                                cnt_full(i) <= cnt_full(i) + '1';
                            end if;
                        else
                            -- count hits per FEB
                            cnt_hits(i) <= cnt_hits(i) + '1';

                            -- set bits if we saw this chipID from the FEB
                            saw_input_chipIDs(i)(to_integer(unsigned(FEBChipID(i)))) <= '1';

                            -- Bits 63 and 62 tell us if an overflow happend
                            --  bit63/62 = 0: no overflow
                            --  bit62    = 1: overflow in this subheader at time ts8ns(3 downto 0)
                            --  bit63    = 1: at least one subheader before was thrown away
                            full_subheader_overflow(i) <= "000"; -- we reset both bits
                            if ( full_subheader_overflow(i)(2) = '1' or full_subheader_overflow(i) = "010" ) then -- this is case 2./3.
                                rx(i).data(63) <= '1';
                            end if;
                            rx(i).data(62) <= last_subheader_overflow(i)(to_integer(unsigned(in_rx(i).data(31 downto 28))));

                            -- set 64bit data
                            rx(i).dthdr <= '1';
                            if ( data_type(i) = MUPIX_HEADER_ID or data_type(i) = OUTER_HEADER_ID ) then
                                -- MuPix 64bit format (PHIT)
                                -- Bits 61-32:  Pixel address in global addressing scheme
                                --              Upper 16 bits global sensor ID
                                rx(i).data(61 downto 48) <= globalChipID(i);
                                --              8 bit column
                                rx(i).data(47 downto 40) <= in_rx(i).data(21 downto 14);
                                --              8 bit row
                                rx(i).data(39 downto 32) <= in_rx(i).data(13 downto 6);
                                -- Bits 31-27:  ToT
                                rx(i).data(31 downto 27) <= in_rx(i).data(5 downto 1);
                                -- Bits 26-0: Hit time                           11 +                       5 +                                  7 +                          4
                                rx(i).data(26 downto  0) <= ts_high(i)(10 downto 0) & ts_low(i)(15 downto 11) & last_subheader_time(i)(6 downto 0) & in_rx(i).data(31 downto 28);
                            elsif ( data_type(i) = SCIFI_HEADER_ID or data_type(i) = TILE_HEADER_ID ) then
                                -- SciFi/Tile 64bit format (FHIT / THIT)
                                -- Bit 61 is always 0
                                -- Bits 60-53: ASIC ID
                                rx(i).data(60 downto 53) <= globalChipID(i)(7 downto 0);
                                -- Bits 52-48: Channel ID
                                rx(i).data(52 downto 48) <= in_rx(i).data(21 downto 17);
                                -- Bits 47-41: Reserved
                                rx(i).data(47 downto 41) <= (others => '0');
                                -- Bits 40-32: E-T (0 for the short hit format and 0x1ff for the energy flag)
                                rx(i).data(40 downto 32) <= in_rx(i).data(8 downto 0);
                                -- Bits 31-8: Time in 8 ns                      8 +                       4 +                      8 +                          4
                                rx(i).data(31 downto 8) <= ts_high(i)(7 downto 0) & ts_low(i)(15 downto 12) & last_subheader_time(i) & in_rx(i).data(31 downto 28);
                                -- Bits 7-5: Time in 1.6 ns reminder bit
                                rx(i).data(7 downto 5) <= in_rx(i).data(16 downto 14);
                                -- Bits 4-0: Fine time
                                rx(i).data(4 downto 0) <= in_rx(i).data(13 downto 9);
                            end if;
                        end if;
                    end if;
                end if;

            end if;
        end loop;
        --
    end if;
    end process;

end architecture;

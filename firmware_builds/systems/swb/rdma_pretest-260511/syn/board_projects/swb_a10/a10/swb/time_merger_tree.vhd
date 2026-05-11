library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

use work.mudaq.all;

entity time_merger_tree is
generic (
    g_LINK_SWB   : std_logic_vector(3 downto 0) := "0000";
    g_ADDR_WIDTH : positive  := 11;
    N_LINKS_IN   : positive  := 8;
    N_LINKS_OUT  : positive  := 4--;
);
port (
    -- input data stream
    i_data          : in  work.mu3e.link64_array_t(N_LINKS_IN-1 downto 0);
    i_empty         : in  std_logic_vector(N_LINKS_IN-1 downto 0);
    i_mask_n        : in  std_logic_vector(N_LINKS_IN-1 downto 0);
    o_rack          : out std_logic_vector(N_LINKS_IN-1 downto 0) := (others => '0');

    -- output data stream
    o_data          : out work.mu3e.link64_array_t(N_LINKS_OUT-1 downto 0);
    o_empty         : out std_logic_vector(N_LINKS_OUT-1 downto 0);
    o_mask_n        : out std_logic_vector(N_LINKS_OUT-1 downto 0);
    i_rack          : in  std_logic_vector(N_LINKS_OUT-1 downto 0);

    -- counters
    -- 0: HEADER counters
    -- 1: SHEADER counters
    -- 2: HIT counters
    o_counters      : out slv32_array_t(3 * N_LINKS_OUT-1 downto 0);

    i_data_type     : in  std_logic_vector(5 downto 0) := MUPIX_HEADER_ID;

    i_en            : in  std_logic;
    i_reset_n       : in  std_logic;
    i_clk           : in  std_logic--;
);
end entity;

architecture arch of time_merger_tree is

    signal reset_n, en_reg : std_logic;

    -- merger signals
    constant size : integer := N_LINKS_IN/2;
    signal mask_n : std_logic_vector(N_LINKS_IN-1 downto 0);

    -- layer states
    type layer_state_type is (SWB_IDLE,ONEMASK,WAITING,HEADER,TS0,TS1,D0,D1,SHEADER,HIT,ONEHIT0,ONEHIT1,TRAILER,ONEERROR);
    type layer_state_array is array (N_LINKS_OUT-1 downto 0) of layer_state_type;
    signal layer_state, last_state : layer_state_array;
    signal state_reset : std_logic;

    -- fifo signals
    signal data, data_reg, q_data : work.mu3e.link64_array_t(N_LINKS_OUT-1 downto 0);
    signal wrreq, wrreq_reg, almost_full : std_logic_vector(N_LINKS_OUT-1 downto 0);

    -- hit signals
    signal a, b : slv4_array_t(N_LINKS_OUT-1 downto 0) := (others => (others => '1'));
    signal a_h, b_h : work.mu3e.link64_array_t(N_LINKS_OUT-1 downto 0);
    signal overflow : slv16_array_t(N_LINKS_OUT-1 downto 0) := (others => (others => '0'));

    -- error signals
    signal sbhdr_time0, sbhdr_time1 : slv8_array_t(N_LINKS_OUT-1 downto 0) := (others => (others => '0'));
    signal cnt_waiting : slv32_array_t(N_LINKS_OUT-1 downto 0);
    signal error_s : slv2_array_t(N_LINKS_OUT-1 downto 0) := (others => (others => '0'));

    -- counters
    signal countSop, countSbhdr, countHit : std_logic_vector(N_LINKS_OUT-1 downto 0);

    -- default link types
    signal headerHit : work.mu3e.link64_array_t(N_LINKS_OUT-1 downto 0) := (others => work.mu3e.LINK64_SOP);
    signal sbhdrHit : work.mu3e.link64_array_t(N_LINKS_OUT-1 downto 0) := (others => work.mu3e.LINK64_SBHDR);
    signal d0Hit : work.mu3e.link64_array_t(N_LINKS_OUT-1 downto 0) := (others => work.mu3e.LINK64_D0);
    signal trailerHit : work.mu3e.link64_array_t(N_LINKS_OUT-1 downto 0) := (others => work.mu3e.LINK64_EOP);
    signal errorHit : work.mu3e.link64_array_t(N_LINKS_OUT-1 downto 0) := (others => work.mu3e.LINK64_ERR);

begin

    e_reset_n : entity work.ff_sync
    port map ( o_q(0) => reset_n, i_d(0) => '1', i_reset_n => i_reset_n, i_clk => i_clk );

    --! reset / enable for tree
    process(i_clk, reset_n)
    begin
    if ( reset_n /= '1' ) then
        state_reset <= '1';
        en_reg <= '0';
        --
    elsif rising_edge(i_clk) then
        state_reset <= '0';
        en_reg <= i_en;
    end if;
    end process;

    gen_hits:
    FOR i in 0 to N_LINKS_OUT-1 GENERATE

        --! HEADER counters
        countSop(i) <= '1' when layer_state(i) = HEADER else '0';
        e_cnt_header_state : entity work.counter
        generic map (
            WRAP => true,
            W => o_counters(0+i*3)'length--,
        )
        port map (
            o_cnt => o_counters(0+i*3),
            i_ena => countSop(i),
            i_reset_n => reset_n,
            i_clk => i_clk--,
        );

        --! SHEADER counters
        countSbhdr(i) <= '1' when layer_state(i) = SHEADER else '0';
        e_cnt_sheader_state : entity work.counter
        generic map (
            WRAP => true,
            W => o_counters(1+i*3)'length--,
        )
        port map (
            o_cnt => o_counters(1+i*3),
            i_ena => countSbhdr(i),
            i_reset_n => reset_n,
            i_clk => i_clk--,
        );

        --! HIT counters
        countHit(i) <= '1' when layer_state(i) = HIT else '0';
        e_cnt_hit_state : entity work.counter
        generic map (
            WRAP => true,
            W => o_counters(2+i*3)'length--,
        )
        port map (
            o_cnt => o_counters(2+i*3),
            i_ena => countHit(i),
            i_reset_n => reset_n,
            i_clk => i_clk--,
        );

        --! store the hit timestamp
        a(i) <= i_data(i).data(3 downto 0) when mask_n(i) = '1' and i_data_type = MUPIX_HEADER_ID else
                i_data(i).data(11 downto 8) when mask_n(i) = '1' and (i_data_type = TILE_HEADER_ID or i_data_type = SCIFI_HEADER_ID) else
                (others => '1');

        b(i) <= i_data(i+size).data(3 downto 0) when mask_n(i+size) = '1' and i_data_type = MUPIX_HEADER_ID else
                i_data(i+size).data(11 downto 8) when mask_n(i+size) = '1' and (i_data_type = TILE_HEADER_ID or i_data_type = SCIFI_HEADER_ID) else
                (others => '1');

        --! store the hit
        a_h(i) <= i_data(i);
        b_h(i) <= i_data(i+size);

        --! reg mask and write data for timing
        process(i_clk, reset_n)
        begin
        if ( reset_n /= '1' ) then
            mask_n(i) <= '0';
            o_mask_n(i) <= '0';
            data_reg(i) <= work.mu3e.LINK64_ZERO;
            wrreq_reg(i) <= '0';
            --
        elsif rising_edge(i_clk) then
            data_reg(i) <= data(i);
            wrreq_reg(i) <= wrreq(i);
            mask_n(i) <= i_mask_n(i);
            mask_n(i + size) <= i_mask_n(i + size);
            o_mask_n(i) <= i_mask_n(i) or i_mask_n(i + size);
        end if;
        end process;

        e_tree_fifo : entity work.link64_scfifo
        generic map (
            g_ADDR_WIDTH => g_ADDR_WIDTH,
            g_WREG_N => 2,
            g_RREG_N => 2--,
        )
        port map (
            i_wdata         => data(i),
            i_we            => wrreq(i),
            o_almost_full   => almost_full(i),

            o_rdata         => o_data(i),
            o_rempty        => o_empty(i),
            i_rack          => i_rack(i),

            i_reset_n       => reset_n,
            i_clk           => i_clk--,
        );

        -- Tree setup
        -- x => empty, h => header, t => time header, tr => trailer, sh => sub header
        -- [a]               [a]                   [a]
        -- [1]  -> [[2],[1]] [tr]  -> [[tr],[2]]   [4,sh]   -> [[4],[3],[sh],[2]]
        -- [2]               [tr,2]                [3,sh,2]
        -- [b]               [b]                   [b]
        layer_state(i) <=             -- check if both are mask or if we are in enabled or in reset
                            SWB_IDLE  when (mask_n(i) = '0' and mask_n(i+size) = '0') or en_reg = '0' or state_reset = '1' else
                                      -- we forword the error
                            ONEERROR  when (i_data(i).err = '1' or i_data(i+size).err = '1') else
                                      -- simple case on of the links is mask so we just send the other one
                            ONEMASK   when (mask_n(i) = '0' or mask_n(i+size) = '0') else
                                      -- wait if one input is empty or the output fifo is full
                            WAITING   when i_empty(i) = '1' or i_empty(i+size) = '1' else
                                      -- since we check before that we should have two links not masked and both are not empty we
                                      -- wait until we see from both a header
                            HEADER    when i_data(i).sop = '1' and i_data(i+size).sop = '1' else
                                      -- we now want to see from both inputs ts0
                            TS0       when i_data(i).t0 = '1' and i_data(i+size).t0 = '1' and last_state(i) = HEADER else
                                      -- we now want to see from both inputs ts1
                            TS1       when i_data(i).t1 = '1' and i_data(i+size).t1 = '1' and last_state(i) = TS0 else
                                      -- we now want to see from both inputs d0
                            D0        when i_data(i).d0 = '1' and i_data(i+size).d0 = '1' and last_state(i) = TS1 else
                                      -- we now want to see from both inputs d1
                            D1        when i_data(i).d1 = '1' and i_data(i+size).d1 = '1' and last_state(i) = D0 else
                                      -- we check if both inputs have a subheader
                            SHEADER   when i_data(i).sbhdr = '1' and i_data(i+size).sbhdr = '1' and (last_state(i) = D1 or last_state(i) = HIT or last_state(i) = ONEHIT0 or last_state(i) = ONEHIT1 or last_state(i) = SHEADER) else
                                      -- we check if both inputs have a hit
                            HIT       when i_data(i).dthdr = '1' and i_data(i+size).dthdr = '1' and (last_state(i) = SHEADER or last_state(i) = HIT) else
                                      -- we check if one has a subheader or trailer and the other link has a hit
                            ONEHIT0   when (i_data(i).dthdr = '1'      and (i_data(i+size).sbhdr = '1' or i_data(i+size).eop = '1')) and (last_state(i) = SHEADER or last_state(i) = HIT or last_state(i) = ONEHIT0) else
                            ONEHIT1   when (i_data(i+size).dthdr = '1' and (i_data(i).sbhdr = '1'      or i_data(i).eop = '1'))      and (last_state(i) = SHEADER or last_state(i) = HIT or last_state(i) = ONEHIT1) else
                                      -- we check if both inputs have a trailer
                            TRAILER   when i_data(i).eop = '1' and i_data(i+size).eop = '1' and (last_state(i) = SHEADER or last_state(i) = HIT or last_state(i) = ONEHIT0 or last_state(i) = ONEHIT1) else
                            WAITING;

        -- TODO: simplifiy same when cases
        -- NOTE: if timing problem maybe add reg for writing

        wrreq(i)        <=  '1' when layer_state(i) = HEADER or layer_state(i) = TS0 or layer_state(i) = TS1 or layer_state(i) = D0 or layer_state(i) = D1 or layer_state(i) = SHEADER or layer_state(i) = TRAILER or layer_state(i) = ONEERROR else
                            '0' when almost_full(i) = '1' else -- we drop only hits
                            '1' when layer_state(i) = HIT or layer_state(i) = ONEHIT0 or layer_state(i) = ONEHIT1 else
                            not i_empty(i) when layer_state(i) = ONEMASK and mask_n(i) = '1' else
                            not i_empty(i+size) when layer_state(i) = ONEMASK and mask_n(i+size) = '1' else
                            '0';

        o_rack(i)       <=  '1' when layer_state(i) = HEADER or layer_state(i) = TS0 or layer_state(i) = TS1 or layer_state(i) = D0 or layer_state(i) = D1 or layer_state(i) = SHEADER or layer_state(i) = TRAILER or layer_state(i) = ONEHIT0 else
                            '0' when almost_full(i) = '1' and layer_state(i) = ONEHIT1 else -- if we have a trailer or subh on 0 we dont read it
                            '1' when almost_full(i) = '1' else -- we drop the hit
                            '1' when layer_state(i) = HIT and a(i) <= b(i) else
                            not i_empty(i) when layer_state(i) = ONEERROR and i_data(i).err = '1' else
                            not i_empty(i) when layer_state(i) = ONEMASK and mask_n(i) = '1' else
                            '0';

        o_rack(i+size)  <=  '1' when layer_state(i) = HEADER or layer_state(i) = TS0 or layer_state(i) = TS1 or layer_state(i) = D0 or layer_state(i) = D1 or layer_state(i) = SHEADER or layer_state(i) = TRAILER or layer_state(i) = ONEHIT1 else
                            '0' when almost_full(i) = '1' and layer_state(i) = ONEHIT0 else -- if we have a trailer or subh on 1 we dont read it
                            '1' when almost_full(i) = '1' else -- we drop the hit
                            '1' when layer_state(i) = HIT and b(i) < a(i) else
                            not i_empty(i+size) when layer_state(i) = ONEERROR and i_data(i+size).err = '1' else
                            not i_empty(i+size) when layer_state(i) = ONEMASK and mask_n(i+size) = '1' else
                            '0';

        -- or'ed overflow
        overflow(i) <=  a_h(i).data(23 downto 8) or b_h(i).data(23 downto 8) when layer_state(i) = SHEADER else
                        a_h(i).data(23 downto 8) or b_h(i).data(23 downto 8) when layer_state(i) = TRAILER else
                        (others => '0');

        -- do some error checking
        sbhdr_time0(i) <= a_h(i).data(31 downto 24);
        sbhdr_time1(i) <= b_h(i).data(31 downto 24);

                         -- we check if the header counts are the same
        error_s(i)    <= "10"   when layer_state(i) = TS1 and a_h(i).data(15 downto 0) /= b_h(i).data(15 downto 0) else
                         -- we check here if SUBs are the same
                         "11"   when layer_state(i) = SHEADER and sbhdr_time0(i) /= sbhdr_time1(i) else
                         -- we check if the subheader_counter is different
                         "01"   when layer_state(i) = D0 and a_h(i).data(31 downto 16) /= b_h(i).data(31 downto 16) else
                         -- TODO: activate this waiting counter -- more bits for the error state
                         -- "XX"   when cnt_waiting(i) = (others => '1') else
                         i_data(i).data(31 downto 30) when layer_state(i) = ONEERROR and i_data(i).err = '1' else
                         i_data(i+size).data(31 downto 30) when layer_state(i) = ONEERROR and i_data(i+size).err = '1' else
                         (others => '0');

        errorHit(i).err <=  '1' when layer_state(i) = ONEERROR and i_data(i).err = '1' else
                            '1' when layer_state(i) = ONEERROR and i_data(i+size).err = '1' else
                            '1' when or_reduce(error_s(i)) = '1' else
                            '0';

        -- set data for no hit types
        headerHit(i).data  <= x"00000000" & i_data_type & "00" & g_LINK_SWB & x"000BC";
        -- we add the hitcounter of both packages
        d0Hit(i).data      <= x"00000000" & a_h(i).data(31 downto 16) & (a_h(i).data(15 downto 0) + b_h(i).data(15 downto 0));
        sbhdrHit(i).data   <= x"00000000" & a_h(i).data(31 downto 24) & overflow(i) & a_h(i).data(7 downto 0);
        trailerHit(i).data <= x"00000000" & a_h(i).data(31 downto 24) & overflow(i) & x"9C";
        errorHit(i).data   <= x"00000000" & error_s(i) & "00" & x"FFFFF9C";

        --synthesis translate_off
        -- assert ( or_reduce(error_s(i)) = '0'
        -- ) report "Tree ERROR"
        --    & ", a_h = " & work.util.to_hstring(a_h(i).data)
        --    & ", b_h = " & work.util.to_hstring(b_h(i).data)
        --    & ", a_sbhdr_ts = " & work.util.to_hstring(sbhdr_time0(i))
        --    & ", b_sbhdr_ts = " & work.util.to_hstring(sbhdr_time1(i))
        --    & ", sbhdr = " & work.util.to_hstring(a_h(i).sbhdr & b_h(i).sbhdr)
        --    & ", error = " & work.util.to_hstring(error_s(i))
        --severity note;
        --synthesis translate_on

        -- write out data
        data(i)         <=  errorHit(i) when or_reduce(error_s(i)) = '1' or layer_state(i) = ONEERROR else
                            headerHit(i) when layer_state(i) = HEADER else
                            a_h(i) when layer_state(i) = TS0 else
                            a_h(i) when layer_state(i) = TS1 else
                            d0Hit(i) when layer_state(i) = D0 else
                            a_h(i) when layer_state(i) = D1 else
                            sbhdrHit(i) when layer_state(i) = SHEADER else
                            trailerHit(i) when layer_state(i) = TRAILER else
                            a_h(i) when layer_state(i) = ONEHIT0 and i_data(i).dthdr = '1' else
                            b_h(i) when layer_state(i) = ONEHIT1 and i_data(i+size).dthdr = '1' else
                            a_h(i) when layer_state(i) = HIT and not (b(i) < a(i)) else
                            b_h(i) when layer_state(i) = HIT and     (b(i) < a(i)) else
                            headerHit(i) when layer_state(i) = ONEMASK and mask_n(i) = '1' and i_data(i).sop = '1' else
                            a_h(i) when layer_state(i) = ONEMASK and mask_n(i) = '1' and i_data(i).sop = '0' else
                            headerHit(i) when layer_state(i) = ONEMASK and mask_n(i+size) = '1' and i_data(i+size).sop = '1' else
                            b_h(i) when layer_state(i) = ONEMASK and mask_n(i+size) = '1' and i_data(i+size).sop = '0' else
                            work.mu3e.LINK64_ZERO;

        -- set last layer state
        process(i_clk, reset_n)
        begin
        if ( reset_n /= '1' ) then
            last_state(i) <= SWB_IDLE;
            cnt_waiting(i) <= (others => '0');
            --
        elsif rising_edge(i_clk) then
            if ( layer_state(i) /= WAITING ) then
                last_state(i) <= layer_state(i);
                cnt_waiting(i) <= (others => '0');
            else
                cnt_waiting(i) <= cnt_waiting(i) + '1';
            end if;
        end if;
        end process;

    END GENERATE;

end architecture;

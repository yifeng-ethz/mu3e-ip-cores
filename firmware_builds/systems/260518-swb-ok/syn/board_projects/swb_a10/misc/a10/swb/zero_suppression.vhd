-- zero suppression for Mupix Data frames as descibed in the scpec book (might need adaptation for scifi/tile)
-- assuming sop and eop of link32_t_t_t to be set correctly, not assuming anything about subhdr of link32_t (so we can insert it also before link32_to_fifo entity)
-- M. Mueller, June 2022


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity zero_suppression is
port (
    i_ena_subh_suppression  : in    std_logic := '0';
    i_ena_head_suppression  : in    std_logic := '0';

    i_data                  : in    work.mu3e.link32_t;
    o_data                  : out   work.mu3e.link32_t;

    i_reset_n               : in    std_logic;
    i_clk                   : in    std_logic--;
);
end entity;

architecture arch of zero_suppression is

    signal subh_suppression : std_logic;
    signal head_suppression : std_logic;

    signal data_subh_suppressed : work.mu3e.link32_t;
    signal data_head_suppressed : work.mu3e.link32_t;

    signal data_buffer      : work.mu3e.link32_array_t(4 downto 0);
    signal next_subhdr      : work.mu3e.link32_t;
    signal next_hit         : work.mu3e.link32_t;
    type   subhdr_suppression_state_t is (head, ts0,ts1,d0,d1, waitingForFirstHit, waitingForMoreHits);
    signal subhdr_suppression_state   : subhdr_suppression_state_t;
    signal is_subh          : std_logic;
    signal reset0_n         : std_logic;
    signal reset1_n         : std_logic;

begin

    subh_suppression <= i_ena_subh_suppression or i_ena_head_suppression;
    head_suppression <= i_ena_head_suppression;

    is_subh <= '1' when (i_data.data(31 downto 26) = "111111" and i_data.datak = "0000") else '0';

    process(i_clk)
    begin
      if rising_edge(i_clk) then
        reset0_n <= i_reset_n;
        reset1_n <= reset0_n;
      end if;
    end process;

    process(i_clk, reset1_n)
    begin
    if ( reset1_n = '0' ) then
        o_data                      <= work.mu3e.LINK32_IDLE;
        subhdr_suppression_state    <= head;
        data_buffer                 <= (others => work.mu3e.LINK32_IDLE);
        data_subh_suppressed        <= work.mu3e.LINK32_IDLE;
        data_head_suppressed        <= work.mu3e.LINK32_IDLE;
        next_hit                    <= work.mu3e.LINK32_IDLE;
        next_subhdr                 <= work.mu3e.LINK32_IDLE;

    elsif rising_edge(i_clk) then
        -- default to idle
        o_data <= work.mu3e.LINK32_IDLE;
        next_hit <= work.mu3e.LINK32_IDLE;
        data_subh_suppressed <= work.mu3e.LINK32_IDLE;
        data_head_suppressed <= work.mu3e.LINK32_IDLE;

        -- assign output based on ena signals
        if(subh_suppression = '0' and head_suppression = '0') then
            o_data <= i_data;
        elsif(head_suppression = '1') then
            o_data <= data_head_suppressed;
        elsif(subh_suppression = '1' and head_suppression = '0') then
            o_data <= data_subh_suppressed;
        end if;

        -- -----------------------------------------------------------------
        -- generate subhdr zero-suppressed datastream data_subh_suppressed

        if(i_data.idle = '0') then -- we have a non-idle input
            case subhdr_suppression_state is
            when head =>
                data_subh_suppressed <= i_data;
                if(i_data.sop = '1') then
                    subhdr_suppression_state <= ts0;
                end if;
                -- else nonsense, but we still transmitt it
            when ts0 =>
                subhdr_suppression_state <= ts1;
                data_subh_suppressed <= i_data;
            when ts1 =>
                subhdr_suppression_state <= d0;
                data_subh_suppressed <= i_data;
            when d0 =>
                subhdr_suppression_state <= d1;
                data_subh_suppressed <= i_data;
            when d1 =>
                subhdr_suppression_state <= waitingForFirstHit;
                data_subh_suppressed <= i_data;
            when waitingForFirstHit =>
                if(i_data.eop = '1') then
                    data_subh_suppressed <= i_data;
                    subhdr_suppression_state <= head;
                elsif(is_subh = '1') then  -- new next subh, skip prev. one
                    next_subhdr <= i_data;
                    subhdr_suppression_state <= waitingForFirstHit;
                else -- --> we have a hit --> send saved subh, save hit
                    subhdr_suppression_state <= waitingForMoreHits;
                    data_subh_suppressed <= next_subhdr;
                    next_hit <= i_data;
                end if;
            when waitingForMoreHits =>
                if(i_data.eop = '1') then
                    data_subh_suppressed <= i_data;
                    subhdr_suppression_state <= head;
                elsif(is_subh = '1') then  -- subh with hits done --> send last hit of prev. subh
                    next_subhdr <= i_data;
                    subhdr_suppression_state <= waitingForFirstHit;
                    data_subh_suppressed <= next_hit;
                else -- --> we have a hit --> send saved hit, save new hit
                    subhdr_suppression_state <= waitingForMoreHits;
                    data_subh_suppressed <= next_hit;
                    next_hit <= i_data;
                end if;
            when others =>
                subhdr_suppression_state <= head;
            end case;
        elsif(next_hit.idle = '0') then
            data_subh_suppressed <= next_hit;
        end if;

        -- --------------------------------------------------
        -- gernerate header suppressed datastream

        if(data_buffer(0).sop='1') then
            -- there is a sop at the end of the buffer --> the next not-idle word on data_subh_suppressed decides what todo
            -- next word is eop --> throw away buffer, including the eop that is just arriving
            -- next word is not eop --> we have a hit in the event, start rolling data buffer again
            if(data_subh_suppressed.idle = '0') then
                if(data_subh_suppressed.eop = '1') then
                    data_buffer <= (others => work.mu3e.LINK32_IDLE);
                else
                    for I in 0 to 3 loop
                        data_buffer(I) <= data_buffer(I+1);
                    end loop;
                    data_buffer(4) <= data_subh_suppressed;
                    data_head_suppressed <= data_buffer(0);
                end if;
            end if;
        elsif(data_buffer(1).sop='1' or data_buffer(2).sop='1' or data_buffer(3).sop='1' or data_buffer(4).sop='1') then
            -- there is a sop somwhere else in the buffer
            --> we need to filter idle words out so we can save really only the 5 header words in here
            if(data_subh_suppressed.idle = '0') then
                for I in 0 to 3 loop
                    data_buffer(I) <= data_buffer(I+1);
                end loop;
                data_buffer(4) <= data_subh_suppressed;
                data_head_suppressed <= data_buffer(0);
            end if;
        else
            -- no sop in sight --> we just roll the data through the shift reg
            for I in 0 to 3 loop
                data_buffer(I) <= data_buffer(I+1);
            end loop;
            data_buffer(4) <= data_subh_suppressed;
            data_head_suppressed <= data_buffer(0);
        end if;

    end if;
    end process;

end architecture;

-------------------------------------------------------
--! We always read from the link fifo into a fifo (link to fifo)
--! (if possible), while we tag the processed data for the
--! next farm (farm aligne link). We align by the event #.
--!
--! @farm_link_to_fifo.vhd
--! @brief the farm_link_to_fifo sorts out the data from the
--! link and provides it as a fifo output
--! Author: mkoeppel@uni-mainz.de
-------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;
use work.mudaq.all;

entity farm_link_to_fifo is
generic (
    g_LINK_N : positive :=  3--;
);
port (
    -- link data
    i_rx            : in  work.mu3e.link32_array_t(g_LINK_N-1 downto 0) := (others => work.mu3e.LINK32_IDLE);
    o_tx            : out work.mu3e.link32_array_t(g_LINK_N-1 downto 0) := (others => work.mu3e.LINK32_IDLE);
    i_mask_n        : in  std_logic_vector(g_LINK_N-1 downto 0);

    -- data out for farm path
    o_q             : out work.mu3e.link64_array_t(g_LINK_N-1 downto 0);
    i_ren           : in  std_logic_vector(g_LINK_N-1 downto 0);
    o_rdempty       : out std_logic_vector(g_LINK_N-1 downto 0);

    --! counters
    o_counter       : out slv32_array_t(13*g_LINK_N-1 downto 0) := (others => (others => '0'));
    i_reset_n_cnt   : in std_logic;

    i_reset_n       : in std_logic;
    i_clk           : in std_logic--;
);
end entity;

architecture arch of farm_link_to_fifo is

    signal rx_in_reg : work.mu3e.link32_array_t(g_LINK_N-1 downto 0);
    signal rx : work.mu3e.link64_array_t(g_LINK_N-1 downto 0);
    signal reg_cnt, rx_wen, sop, eop, sbhdr, wrfull : std_logic_vector(g_LINK_N-1 downto 0);
    signal wrusedw : slv12_array_t(g_LINK_N-1 downto 0);
    signal header_cnt : slv3_array_t(g_LINK_N-1 downto 0);
    signal cnt_skipped_sorter_package, cnt_subheaders, cnt_almost_full, cnt_full, cnt_full_subheader_overflow, cnt_skip_hits, cnt_skip_subheader, cnt_full_ts_overflow, cnt_hits : slv32_array_t(g_LINK_N-1 downto 0);
    signal cnt_sorter_package : slv64_array_t(g_LINK_N-1 downto 0);

begin

    --! sync link data from link to pcie clk
    gen_link_to_fifo : FOR i in 0 to g_LINK_N-1 GENERATE

        -- map output counters
        o_counter(i*13+ 0) <= cnt_almost_full(i);
        o_counter(i*13+ 1) <= cnt_full(i);
        o_counter(i*13+ 2) <= (others => '0'); --cnt_skipped_sorter_package(i);
        o_counter(i*13+ 3) <= cnt_sorter_package(i)(31 downto 0);
        o_counter(i*13+ 4) <= cnt_sorter_package(i)(63 downto 32);
        o_counter(i*13+ 5) <= cnt_subheaders(i);
        o_counter(i*13+ 6) <= (others => '0');
        o_counter(i*13+ 7) <= cnt_skip_hits(i);
        o_counter(i*13+ 8) <= (others => '0'); --cnt_skip_subheader(i);
        o_counter(i*13+ 9) <= (others => '0');
        o_counter(i*13+10) <= cnt_hits(i);
        o_counter(i*13+11)(15 downto 0) <= (others => '0'); --saw_input_chipIDs(i);
        o_counter(i*13+12) <= (others => '0');

        --! write only if not idle
        process(i_clk, i_reset_n)
        begin
        if ( i_reset_n /= '1' ) then
            rx(i) <= work.mu3e.LINK64_ZERO;
            rx_in_reg(i) <= work.mu3e.LINK32_ZERO;
            o_tx(i) <= work.mu3e.LINK32_IDLE;
            reg_cnt(i) <= '0';
            header_cnt(i) <= "100";
            rx_wen(i) <= '0';
            cnt_subheaders(i) <= (others => '0');
            cnt_sorter_package(i) <= (others => '0');
            cnt_almost_full(i) <= (others => '0');
            cnt_full(i) <= (others => '0');
            cnt_skip_hits(i) <= (others => '0');
            cnt_hits(i) <= (others => '0');
            --
        elsif rising_edge(i_clk) then

            -- reset counters
            if ( i_reset_n_cnt /= '1' ) then
                cnt_subheaders(i) <= (others => '0');
                cnt_sorter_package(i) <= (others => '0');
                cnt_almost_full(i) <= (others => '0');
                cnt_full(i) <= (others => '0');
                cnt_skip_hits(i) <= (others => '0');
                cnt_hits(i) <= (others => '0');
            end if;

            -- send to the next farm is this input is not active
            if (i_mask_n(i) = '0') then
                o_tx(i) <= i_rx(i);
            else
                o_tx(i) <= i_rx(i);--work.mu3e.LINK32_IDLE;

                -- fifo half full counter
                if ( wrusedw(i)(11) = '1' ) then
                    cnt_almost_full(i) <= cnt_almost_full(i) + '1';
                end if;
                cnt_full(i) <= cnt_full(i) + wrfull(i);

                -- reset sop/eop/sh etc.
                rx(i) <= work.mu3e.LINK64_ZERO;
                rx_wen(i) <= '0';

                -- if the input is not idle we reg it
                if (i_rx(i).idle = '0') then
                    sop(i) <= '0';
                    sbhdr(i) <= '0';
                    eop(i) <= '0';
                    if (i_rx(i).data(7 downto 0) = x"BC" and i_rx(i).datak(0) = '1') then
                        sop(i) <= '1';
                    end if;
                    if (i_rx(i).data(7 downto 0) = x"F7" and i_rx(i).datak(0) = '1') then
                        sbhdr(i) <= '1';
                    end if;
                    if (i_rx(i).data(7 downto 0) = x"9C" and i_rx(i).datak(0) = '1') then
                        eop(i) <= '1';
                    end if;
                    rx_in_reg(i) <= i_rx(i);
                    reg_cnt(i) <= not reg_cnt(i);
                end if;

                if (i_rx(i).idle = '0' and reg_cnt(i) = '1') then
                    rx(i).data <= i_rx(i).data & rx_in_reg(i).data;
                    rx(i).k <= rx_in_reg(i).datak(0);
                    rx(i).sop <= sop(i);
                    rx(i).sbhdr <= sbhdr(i);
                    rx(i).eop <= eop(i);
                    rx_wen(i) <= '1';

                    cnt_subheaders(i) <= cnt_subheaders(i) + sbhdr(i);
                    cnt_sorter_package(i) <= cnt_sorter_package(i) + eop(i);

                    -- logic for the package bits
                    if (sop(i) = '1') then
                        header_cnt(i) <= "000";
                    end if;
                    if ( header_cnt(i) = "000") then
                        rx(i).t0 <= '1';
                        header_cnt(i) <= "001";
                    end if;
                    if ( header_cnt(i) = "001") then
                        rx(i).t1 <= '1';
                        header_cnt(i) <= "010";
                    end if;
                    if ( header_cnt(i) = "010") then
                        rx(i).d0 <= '1';
                        header_cnt(i) <= "011";
                    end if;
                    if ( header_cnt(i) = "011") then
                        rx(i).d1 <= '1';
                        header_cnt(i) <= "100";
                    end if;
                    if (header_cnt(i) = "100" and sbhdr(i) = '0' and sop(i) = '0' and eop(i) = '0') then
                        rx(i).dthdr <= '1';
                    end if;

                    -- fifo full logic
                    if (header_cnt(i) = "100" and sbhdr(i) = '0' and wrusedw(i)(11) = '1') then 
                        cnt_skip_hits(i) <= cnt_skip_hits(i) + '1';
                        rx_wen(i) <= '0';
                    else
                        cnt_hits(i) <= cnt_hits(i) + '1';
                    end if;
                end if;
            end if;
        end if;
        end process;

        e_fifo : entity work.link64_scfifo
        generic map (
            g_ADDR_WIDTH => 12,
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

            i_reset_n   => i_reset_n,
            i_clk       => i_clk--,
        );

    END GENERATE;

end architecture;

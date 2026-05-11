--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.util_slv.all;

--  A testbench has no ports.
entity tb_tree is
end entity;

architecture behav of tb_tree is

    --  Specifies which entity is bound with the component.
    signal clk : std_logic := '1';
    signal reset_n : std_logic := '1';
    constant CLK_MHZ : real := 10000.0; -- MHz
    signal rx, rx_q : work.mu3e.link64_array_t(4 downto 0);
    signal rx_rdempty, merger_rack : std_logic_vector(4 downto 0);
    signal state : slv4_array_t(4 downto 0);
    signal subh, delay : slv8_array_t(4 downto 0);
    signal hits : slv16_array_t(4 downto 0);
    signal farm_rempty, farm_rack : std_logic;
    signal farm_data, data : work.mu3e.link64_t;
    signal o_farm_data : work.mu3e.link32_t;

    -- merger signals
    signal priority : integer range 0 to 4 := 0;
    signal sop, eop, t0, t1, d0, d1, sbhdr, dthdr, rack_idx : std_logic_vector(4 downto 0);
    type merger_state_type is (idle_state,d0_state,d1_state,t0_state,t1_state,merge_state,waiting,eop_state,sbhdr_state);
    signal merger_state, last_state : merger_state_type;
    signal almost_full, we : std_logic;
    signal min_idx_s : integer;
    signal min_time_s : std_logic_vector(11 downto 0);

begin

    clk <= not clk after (0.5 us / CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / CLK_MHZ);

    gen_input: FOR i in 0 to 4 GENERATE
        --! write only if not idle
        process(clk, reset_n)
        begin
        if ( reset_n /= '1' ) then
            rx(i) <= work.mu3e.LINK64_IDLE;
            state(i) <= (others => '0');
            subh(i) <= (others => '0');
            hits(i) <= (others => '0');
            delay(i) <= (others => '0');
            --
        elsif rising_edge(clk) then
            if (delay(i) /= 1) then
                delay(i) <= delay(i) + '1';
                rx(i) <= work.mu3e.LINK64_IDLE;
            else
                delay(i) <= (others => '0');
                rx(i) <= work.mu3e.LINK64_ZERO;
                if (state(i) /= "0110") then
                    state(i) <= state(i) + '1';
                end if;
                if (state(i) = "0000") then
                    rx(i).data <= x"00000000E80000BC";
                    rx(i).sop <= '1';
                end if;
                if (state(i) = "0001") then
                    rx(i).data <= x"00000000E8E8E8E8";
                    rx(i).t0 <= '1';
                end if;
                if (state(i) = "0010") then
                    rx(i).data <= x"00000000DDDDDDDD";
                    rx(i).t1 <= '1';
                end if;
                if (state(i) = "0011") then
                    rx(i).data <= x"00000000AAAAAAAA";
                    rx(i).d0 <= '1';
                end if;
                if (state(i) = "0100") then
                    rx(i).data <= x"00000000BBBBBBBB";
                    rx(i).d1 <= '1';
                end if;
                if (state(i) = "0101") then
                    subh(i) <= subh(i) + '1';
                    hits(i) <= (others => '0');
                    rx(i).data <= x"000000000000" & subh(i) & x"7F";
                    rx(i).sbhdr <= '1';
                end if;
                if (state(i) = "0110") then
                    if (hits(i) = 16) then
                        subh(i) <= subh(i) + '1';
                        hits(i) <= (others => '0');
                        rx(i).data <= x"000000000000" & subh(i) & x"7F";
                        rx(i).sbhdr <= '1';
                    elsif (subh(i) = 128) then
                        rx(i).data <= x"00000000BBBBBB9C";
                        subh(i) <= (others => '0');
                        rx(i).eop <= '1';
                        state(i) <= "0000";
                    else
                        rx(i).data(11 downto 0) <= hits(i)(11 downto 0);
                        rx(i).data(15 downto 12) <= std_logic_vector(to_unsigned(i, 4));
                        hits(i) <= hits(i) + '1';
                        rx(i).dthdr <= '1';
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
            i_we        => not rx(i).idle,

            o_rdata     => rx_q(i),
            i_rack      => merger_rack(i),
            o_rempty    => rx_rdempty(i),

            i_reset_n   => reset_n,
            i_clk       => clk--,
        );
        sop(i) <= (rx_q(i).sop and not rx_rdempty(i));
        eop(i) <= rx_q(i).eop and not rx_rdempty(i);
        t0(i) <= rx_q(i).t0 and not rx_rdempty(i);
        t1(i) <= rx_q(i).t1 and not rx_rdempty(i);
        d0(i) <= rx_q(i).d0 and not rx_rdempty(i);
        d1(i) <= rx_q(i).d1 and not rx_rdempty(i);
        sbhdr(i) <= rx_q(i).sbhdr and not rx_rdempty(i);
        dthdr(i) <= rx_q(i).dthdr and not rx_rdempty(i);

    END GENERATE;

    merger_state <= idle_state when and_reduce(sop) = '1' else
                    t0_state when and_reduce(t0) = '1' and last_state = idle_state else
                    -- TODO: check for rx_q(0).data(31 downto 16) = rx_q(1).data(31 downto 16)... in t1
                    t1_state when and_reduce(t1) = '1' and last_state = t0_state else
                    d0_state when and_reduce(d0) = '1' and last_state = t1_state else
                    d1_state when and_reduce(d1) = '1' and last_state = d0_state else
                    sbhdr_state when and_reduce(sbhdr) = '1' else
                    eop_state when and_reduce(eop) = '1' else
                    merge_state;

    merger_rack <= "11111" when merger_state /= merge_state else rack_idx;

    rack_idx <= "00000" when or_reduce(rx_rdempty) = '1' else
                "00001" when merger_state = merge_state and dthdr(0) = '1' and
                                (rx_q(0).data(3 downto 0) <= rx_q(1).data(3 downto 0) or dthdr(1) = '0') and
                                (rx_q(0).data(3 downto 0) <= rx_q(2).data(3 downto 0) or dthdr(2) = '0') and
                                (rx_q(0).data(3 downto 0) <= rx_q(3).data(3 downto 0) or dthdr(3) = '0') and
                                (rx_q(0).data(3 downto 0) <= rx_q(4).data(3 downto 0) or dthdr(4) = '0') else
                "00010" when merger_state = merge_state and dthdr(1) = '1' and
                                (rx_q(1).data(3 downto 0) <= rx_q(0).data(3 downto 0) or dthdr(0) = '0') and
                                (rx_q(1).data(3 downto 0) <= rx_q(2).data(3 downto 0) or dthdr(2) = '0') and
                                (rx_q(1).data(3 downto 0) <= rx_q(3).data(3 downto 0) or dthdr(3) = '0') and
                                (rx_q(1).data(3 downto 0) <= rx_q(4).data(3 downto 0) or dthdr(4) = '0') else
                "00100" when merger_state = merge_state and dthdr(2) = '1' and
                                (rx_q(2).data(3 downto 0) <= rx_q(0).data(3 downto 0) or dthdr(0) = '0') and
                                (rx_q(2).data(3 downto 0) <= rx_q(1).data(3 downto 0) or dthdr(1) = '0') and
                                (rx_q(2).data(3 downto 0) <= rx_q(3).data(3 downto 0) or dthdr(3) = '0') and
                                (rx_q(2).data(3 downto 0) <= rx_q(4).data(3 downto 0) or dthdr(4) = '0') else
                "01000" when merger_state = merge_state and dthdr(3) = '1' and
                                (rx_q(3).data(3 downto 0) <= rx_q(0).data(3 downto 0) or dthdr(0) = '0') and
                                (rx_q(3).data(3 downto 0) <= rx_q(1).data(3 downto 0) or dthdr(1) = '0') and
                                (rx_q(3).data(3 downto 0) <= rx_q(2).data(3 downto 0) or dthdr(2) = '0') and
                                (rx_q(3).data(3 downto 0) <= rx_q(4).data(3 downto 0) or dthdr(4) = '0') else
                "10000" when merger_state = merge_state and dthdr(4) = '1' and
                                (rx_q(4).data(3 downto 0) <= rx_q(0).data(3 downto 0) or dthdr(0) = '0') and
                                (rx_q(4).data(3 downto 0) <= rx_q(1).data(3 downto 0) or dthdr(1) = '0') and
                                (rx_q(4).data(3 downto 0) <= rx_q(2).data(3 downto 0) or dthdr(2) = '0') and
                                (rx_q(4).data(3 downto 0) <= rx_q(3).data(3 downto 0) or dthdr(3) = '0') else
                "00000";

    we <= '1' when merger_state /= merge_state else or_reduce(rack_idx) and not almost_full;

    data <= rx_q(0) when rack_idx = "00001" else
            rx_q(1) when rack_idx = "00010" else
            rx_q(2) when rack_idx = "00100" else
            rx_q(3) when rack_idx = "01000" else
            rx_q(4) when rack_idx = "10000" else
            rx_q(0);

    -- set last layer state
    process(clk, reset_n)
    begin
    if ( reset_n /= '1' ) then
        last_state <= idle_state;
        --
    elsif rising_edge(clk) then
        if ( merger_state /= merge_state ) then
            last_state <= merger_state;
        end if;
    end if;
    end process;

    -- process(clk, reset_n)
    --     variable idx : integer := 0;
    --     variable min_time : std_logic_vector(11 downto 0);
    --     variable min_idx : integer;
    --     variable found : boolean;
    -- begin
    --     if (reset_n /= '1') then
    --         priority <= 0;
    --         we <= '0';
    --         merger_state <= idle_state;
    --     elsif rising_edge(clk) then
    --         we <= '0';
    --         merger_rack <= (others => '0');
    --         case merger_state is

    --         when idle_state =>
    --             if ( sop = "11111" ) then
    --                 merger_rack <= "11111";
    --                 data <= rx_q(0);
    --                 merger_state <= t0_state;
    --                 we <= '1';
    --             end if;

    --         when t0_state =>
    --             if ( t0 = "11111" ) then
    --                 merger_rack <= "11111";
    --                 data <= rx_q(0);
    --                 merger_state <= t1_state;
    --                 we <= '1';
    --             end if;

    --         when t1_state =>
    --             if ( t1 = "11111" ) then
    --                 merger_rack <= "11111";
    --                 data <= rx_q(0);
    --                 merger_state <= d0_state;
    --                 we <= '1';
    --             end if;

    --         when d0_state =>
    --             if ( d0 = "11111" and 
    --                     (rx_q(0).data(31 downto 15) = rx_q(1).data(31 downto 15)) and
    --                     (rx_q(0).data(31 downto 15) = rx_q(2).data(31 downto 15)) and
    --                     (rx_q(0).data(31 downto 15) = rx_q(3).data(31 downto 15)) and
    --                     (rx_q(0).data(31 downto 15) = rx_q(4).data(31 downto 15))
    --             ) then
    --                 merger_rack <= "11111";
    --                 data <= rx_q(0);
    --                 merger_state <= d1_state;
    --                 we <= '1';
    --             end if;

    --         when d1_state =>
    --             if ( d1 = "11111" ) then
    --                 merger_rack <= "11111";
    --                 data <= rx_q(0);
    --                 merger_state <= merge_state;
    --                 we <= '1';
    --             end if;

    --         when merge_state =>
    --             if ( eop = "11111" ) then
    --                 merger_rack <= "11111";
    --                 data <= rx_q(0);
    --                 merger_state <= idle_state;
    --                 we <= '1';
    --             elsif (almost_full = '1') then
    --                 merger_rack <= sbhdr or dthdr;
    --             else
    --                 -- read when we have a subheader
    --                 merger_rack <= sbhdr;

    --                 -- Default values
    --                 min_time := (others => '1');
    --                 min_idx := priority;
    --                 found := false;

    --                 -- Timestamp comparison with round-robin preference
    --                 for i in 0 to 4 loop
    --                     if rx_q(i).dthdr = '1' then
    --                         if rx_q(i).data(11 downto 0) < min_time then
    --                             min_time := rx_q(i).data(11 downto 0);
    --                             min_idx := i;
    --                             min_idx_s <= i;
    --                             min_time_s <= rx_q(i).data(11 downto 0);
    --                             found := true;
    --                         end if;
    --                     end if;
    --                 end loop;

    --                 if found then
    --                     data <= rx_q(min_idx);
    --                     merger_rack(min_idx) <= '1';
    --                     priority <= (min_idx + 1) mod 5;
    --                     we <= '1';
    --                 end if;
    --             end if;
    --         end case;
    --     end if;
    -- end process;

    -- e_time_merger : entity work.swb_time_merger
    -- generic map (
    --     g_ADDR_WIDTH => 12,
    --     g_NLINKS_DATA => 5--,
    -- )
    -- port map (
    --     i_rx            => rx_q,
    --     i_rempty        => rx_rdempty,
    --     i_rmask_n       => "11111",
    --     o_rack          => merger_rack,

    --     o_counters      => open,

    --     -- farm data
    --     o_wdata         => farm_data,
    --     o_rempty        => farm_rempty,
    --     i_ren           => farm_rack,

    --     -- data for debug readout
    --     o_wdata_debug   => open,
    --     o_rempty_debug  => open,
    --     i_ren_debug     => '0',

    --     o_error         => open,

    --     i_en            => '1',
    --     i_reset_n       => reset_n,
    --     i_clk           => clk--,
    -- );

    e_fifo_out : entity work.link64_scfifo
    generic map (
        g_ADDR_WIDTH => 12,
        g_WREG_N => 2,
        g_RREG_N => 2--,
    )
    port map (
        i_wdata     => data,
        i_we        => we,
        o_almost_full => almost_full,

        o_rdata     => farm_data,
        i_rack      => farm_rack,
        o_rempty    => farm_rempty,

        i_reset_n   => reset_n,
        i_clk       => clk--,
    );


    --! generate farm output data
    process(clk, reset_n)
    begin
    if ( reset_n /= '1' ) then
        o_farm_data <= work.mu3e.LINK32_IDLE;
        farm_rack <= '0';
        --
    elsif rising_edge(clk) then
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

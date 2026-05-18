library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.util_slv.all;

use work.mudaq.all;

-- merge packets delimited by SOP and EOP from N input streams
entity time_merger is
generic (
    g_ADDR_WIDTH : positive := 11;
    g_LINK_SWB : std_logic_vector(3 downto 0) := "0000";
    g_NLINKS_DATA : positive := 8--;
);
port (
    -- input streams
    i_data          : in    work.mu3e.link64_array_t(g_NLINKS_DATA-1 downto 0);
    i_empty         : in    std_logic_vector(g_NLINKS_DATA-1 downto 0);
    i_mask_n        : in    std_logic_vector(g_NLINKS_DATA-1 downto 0);
    o_rack          : out   std_logic_vector(g_NLINKS_DATA-1 downto 0); -- read ACK

    -- output stream
    o_rdata         : out   work.mu3e.link64_t; -- output is hit
    i_rack          : in    std_logic;
    o_empty         : out   std_logic;

    -- counters
    o_counters      : out   slv32_array_t(3 * (N_LINKS_TREE(3) + N_LINKS_TREE(2) + N_LINKS_TREE(1)) - 1 downto 0);

    i_data_type     : in    std_logic_vector(5 downto 0) := MUPIX_HEADER_ID;

    i_en            : in    std_logic;
    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture arch of time_merger is

    -- input signals
    signal data : work.mu3e.link64_array_t(N_LINKS_TREE(0) - 1 downto 0);
    signal countersL0 : slv32_array_t(3 * N_LINKS_TREE(1) - 1 downto 0);
    signal empty, mask_n, rack : std_logic_vector(N_LINKS_TREE(0) - 1 downto 0) := (others => '0');

    -- layer0
    signal data0 : work.mu3e.link64_array_t(N_LINKS_TREE(1) - 1 downto 0);
    signal countersL1 : slv32_array_t(3 * N_LINKS_TREE(2) - 1 downto 0);
    signal empty0, mask0_n, rack0 : std_logic_vector(N_LINKS_TREE(1) - 1 downto 0);

    -- layer1
    signal data1 : work.mu3e.link64_array_t(N_LINKS_TREE(2) - 1 downto 0);
    signal countersL2 : slv32_array_t(3 * N_LINKS_TREE(3) - 1 downto 0);
    signal empty1, mask1_n, rack1 : std_logic_vector(N_LINKS_TREE(2) - 1 downto 0);

    -- merger signals
    signal sop, eop, t0, t1, d0, d1, sbhdr, dthdr, rack_idx : std_logic_vector(4 downto 0);
    type merger_state_type is (idle_state,d0_state,d1_state,t0_state,t1_state,merge_state,waiting,eop_state,sbhdr_state);
    signal merger_state, last_state : merger_state_type;
    signal almost_full, we : std_logic;
    signal w_data : work.mu3e.link64_t;
    signal cnt_t1_error : std_logic_vector(31 downto 0);

begin

    gen_input: FOR i in 0 to 4 GENERATE
        sop(i) <= (i_data(i).sop and not i_empty(i)) or not i_mask_n(i);
        eop(i) <= (i_data(i).eop and not i_empty(i)) or not i_mask_n(i);
        t0(i) <= (i_data(i).t0 and not i_empty(i)) or not i_mask_n(i);
        t1(i) <= (i_data(i).t1 and not i_empty(i)) or not i_mask_n(i);
        d0(i) <= (i_data(i).d0 and not i_empty(i)) or not i_mask_n(i);
        d1(i) <= (i_data(i).d1 and not i_empty(i)) or not i_mask_n(i);
        sbhdr(i) <= (i_data(i).sbhdr and not i_empty(i)) or not i_mask_n(i);
        dthdr(i) <= i_data(i).dthdr and not i_empty(i);
    END GENERATE;

    merger_state <= idle_state when and_reduce(sop) = '1' else
                    t0_state when and_reduce(t0) = '1' and last_state = idle_state else
                    t1_state when and_reduce(t1) = '1' and last_state = t0_state else
                    d0_state when and_reduce(d0) = '1' and last_state = t1_state else
                    d1_state when and_reduce(d1) = '1' and last_state = d0_state else
                    -- TODO: check for same subheader
                    -- sbhdr_state when and_reduce(sbhdr) = '1' else
                    eop_state when and_reduce(eop) = '1' else
                    merge_state;

    o_rack(4 downto 0) <= "11111" when merger_state /= merge_state else rack_idx or sbhdr;

    rack_idx <= "00000" when (not i_empty) = 0 else
                "00000" when or_reduce(sbhdr) = '1' else -- we dont compare when there is a subheader to have no mixing between sbhdr and hits
                -- TODO: for now we dont care if we have unsorted hits in the second half since the hope is that the sorter
                -- dont run away. Later it would be better to add a half_of_package marker
                "00001" when merger_state = merge_state and dthdr(0) = '1' and
                                (i_data(0).data(5 downto 0) <= i_data(1).data(5 downto 0) or dthdr(1) = '0') and
                                (i_data(0).data(5 downto 0) <= i_data(2).data(5 downto 0) or dthdr(2) = '0') and
                                (i_data(0).data(5 downto 0) <= i_data(3).data(5 downto 0) or dthdr(3) = '0') and
                                (i_data(0).data(5 downto 0) <= i_data(4).data(5 downto 0) or dthdr(4) = '0') else
                "00010" when merger_state = merge_state and dthdr(1) = '1' and
                                (i_data(1).data(5 downto 0) <= i_data(0).data(5 downto 0) or dthdr(0) = '0') and
                                (i_data(1).data(5 downto 0) <= i_data(2).data(5 downto 0) or dthdr(2) = '0') and
                                (i_data(1).data(5 downto 0) <= i_data(3).data(5 downto 0) or dthdr(3) = '0') and
                                (i_data(1).data(5 downto 0) <= i_data(4).data(5 downto 0) or dthdr(4) = '0') else
                "00100" when merger_state = merge_state and dthdr(2) = '1' and
                                (i_data(2).data(5 downto 0) <= i_data(0).data(5 downto 0) or dthdr(0) = '0') and
                                (i_data(2).data(5 downto 0) <= i_data(1).data(5 downto 0) or dthdr(1) = '0') and
                                (i_data(2).data(5 downto 0) <= i_data(3).data(5 downto 0) or dthdr(3) = '0') and
                                (i_data(2).data(5 downto 0) <= i_data(4).data(5 downto 0) or dthdr(4) = '0') else
                "01000" when merger_state = merge_state and dthdr(3) = '1' and
                                (i_data(3).data(5 downto 0) <= i_data(0).data(5 downto 0) or dthdr(0) = '0') and
                                (i_data(3).data(5 downto 0) <= i_data(1).data(5 downto 0) or dthdr(1) = '0') and
                                (i_data(3).data(5 downto 0) <= i_data(2).data(5 downto 0) or dthdr(2) = '0') and
                                (i_data(3).data(5 downto 0) <= i_data(4).data(5 downto 0) or dthdr(4) = '0') else
                "10000" when merger_state = merge_state and dthdr(4) = '1' and
                                (i_data(4).data(5 downto 0) <= i_data(0).data(5 downto 0) or dthdr(0) = '0') and
                                (i_data(4).data(5 downto 0) <= i_data(1).data(5 downto 0) or dthdr(1) = '0') and
                                (i_data(4).data(5 downto 0) <= i_data(2).data(5 downto 0) or dthdr(2) = '0') and
                                (i_data(4).data(5 downto 0) <= i_data(3).data(5 downto 0) or dthdr(3) = '0') else
                "00000";

    we <= '1' when merger_state /= merge_state else or_reduce(rack_idx) and not almost_full;

    w_data <=   i_data(0) when rack_idx = "00001" else
                i_data(1) when rack_idx = "00010" else
                i_data(2) when rack_idx = "00100" else
                i_data(3) when rack_idx = "01000" else
                i_data(4) when rack_idx = "10000" else
                i_data(0) when i_mask_n(0) = '1' else
                i_data(1) when i_mask_n(1) = '1' else
                i_data(2) when i_mask_n(2) = '1' else
                i_data(3) when i_mask_n(3) = '1' else
                i_data(4) when i_mask_n(4) = '1' else
                work.mu3e.LINK64_ZERO;

    -- set last layer state
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        last_state <= idle_state;
        cnt_t1_error <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        if ( merger_state /= merge_state ) then
            last_state <= merger_state;
        end if;
        if ( merger_state = t1_state and i_data(0).data(31 downto 16) /= i_data(1).data(31 downto 16) ) then
            cnt_t1_error <= cnt_t1_error + 1;
        end if;
    end if;
    end process;

    e_fifo_out : entity work.link64_scfifo
    generic map (
        g_ADDR_WIDTH => 14,
        g_WREG_N => 2,
        g_RREG_N => 2--,
    )
    port map (
        i_wdata     => w_data,
        i_we        => we,
        o_almost_full => almost_full,

        o_rdata     => o_rdata,
        i_rack      => i_rack,
        o_rempty    => o_empty,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    -- --! map input signals to always have vectors of size 8 for the first layer
    -- data(g_NLINKS_DATA-1 downto 0) <= i_data(g_NLINKS_DATA-1 downto 0);
    -- empty(g_NLINKS_DATA-1 downto 0) <= i_empty(g_NLINKS_DATA-1 downto 0);
    -- mask_n(g_NLINKS_DATA-1 downto 0) <= i_mask_n(g_NLINKS_DATA-1 downto 0);
    -- o_rack(g_NLINKS_DATA-1 downto 0) <= rack(g_NLINKS_DATA-1 downto 0);

    -- --! map counters
    -- o_counters(3 * (N_LINKS_TREE(1)) - 1 downto 0) <= countersL0;
    -- o_counters(3 * (N_LINKS_TREE(2)+N_LINKS_TREE(1)) - 1 downto 3*N_LINKS_TREE(1)) <= countersL1;
    -- o_counters(3 * (N_LINKS_TREE(3)+N_LINKS_TREE(2)+N_LINKS_TREE(1)) - 1 downto 3*(N_LINKS_TREE(2)+N_LINKS_TREE(1))) <= countersL2;

    -- --! setup tree from layer0 8-4, layer1 4-2, layer2 2-1
    -- layer0 : entity work.time_merger_tree
    -- generic map (
    --     g_LINK_SWB => g_LINK_SWB, g_ADDR_WIDTH => g_ADDR_WIDTH, N_LINKS_IN => N_LINKS_TREE(0), N_LINKS_OUT => N_LINKS_TREE(1)--,
    -- )
    -- port map (
    --     -- input data stream
    --     i_data          => data,
    --     i_empty         => empty,
    --     i_mask_n        => mask_n,
    --     o_rack          => rack,

    --     -- output data stream
    --     o_data          => data0,
    --     o_empty         => empty0,
    --     o_mask_n        => mask0_n,
    --     i_rack          => rack0,

    --     -- counters
    --     o_counters      => countersL0,

    --     i_data_type     => i_data_type,

    --     i_en            => i_en,
    --     i_reset_n       => i_reset_n,
    --     i_clk           => i_clk--,
    -- );

    -- layer1 : entity work.time_merger_tree
    -- generic map (
    --     g_LINK_SWB => g_LINK_SWB, g_ADDR_WIDTH => g_ADDR_WIDTH, N_LINKS_IN => N_LINKS_TREE(1), N_LINKS_OUT => N_LINKS_TREE(2)--,
    -- )
    -- port map (
    --     -- input data stream
    --     i_data          => data0,
    --     i_empty         => empty0,
    --     i_mask_n        => mask0_n,
    --     o_rack          => rack0,

    --     -- output data stream
    --     o_data          => data1,
    --     o_empty         => empty1,
    --     o_mask_n        => mask1_n,
    --     i_rack          => rack1,

    --     -- counters
    --     o_counters      => countersL1,

    --     i_data_type     => i_data_type,

    --     i_en            => i_en,
    --     i_reset_n       => i_reset_n,
    --     i_clk           => i_clk--,
    -- );

    -- layer2 : entity work.time_merger_tree
    -- generic map (
    --     g_LINK_SWB => g_LINK_SWB, g_ADDR_WIDTH => g_ADDR_WIDTH, N_LINKS_IN => N_LINKS_TREE(2), N_LINKS_OUT => N_LINKS_TREE(3)--,
    -- )
    -- port map (
    --     -- input data stream
    --     i_data          => data1,
    --     i_empty         => empty1,
    --     i_mask_n        => mask1_n,
    --     o_rack          => rack1,

    --     -- output data stream
    --     o_data(0)       => o_rdata,
    --     o_empty(0)      => o_empty,
    --     o_mask_n        => open,
    --     i_rack(0)       => i_rack,

    --     -- counters
    --     o_counters      => countersL2,

    --     i_data_type     => i_data_type,

    --     i_en            => i_en,
    --     i_reset_n       => i_reset_n,
    --     i_clk           => i_clk--,
    -- );

end architecture;

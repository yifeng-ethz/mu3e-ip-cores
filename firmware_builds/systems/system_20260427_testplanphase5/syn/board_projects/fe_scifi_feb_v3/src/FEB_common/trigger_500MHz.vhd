library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_slv.all;
use work.mudaq.all;

entity trigger_500MHz is
generic (
    -- NOTE: the entity can generate 4 trigger
    g_N : positive := 1;
    g_INDEX : std_logic_vector(7 downto 0) := "11100100";
    g_ToT : std_logic_vector(3 downto 0) := "0000"--;
);
port (
    o_trig          : out   std_logic_vector(31 downto 0);
    o_trig_en       : out   std_logic;
    i_trigger       : in    std_logic_vector(g_N - 1 downto 0);
    i_run_state_125 : in    run_state_t;
    i_reset_n       : in    std_logic;
    i_clk_fast      : in    std_logic := '0';
    i_clk           : in    std_logic--;
);
end entity;

architecture rtl of trigger_500MHz is

    signal triggerclk, reset_fast_n : std_logic;
    signal run_state_fast : run_state_t;

    signal trig_buffer_125, trig_buffer_125_reg, trig_buffer_125_prev, Trig_TTL_reg, Trig_TTL_prev, dead_time, trig_en, rack, rempty, sop, eop, wfull, we : std_logic_vector(g_N - 1 downto 0);
    signal trig_timestamp_save, fastcounter, time_over_th_cnt, trig_ts_final, rdata : slv32_array_t(g_N - 1 downto 0);
    signal dead_cnt : slv8_array_t(g_N - 1 downto 0);
    signal data : std_logic_vector(g_N * 32 - 1 downto 0);

begin

    -- generate 500MHz fast trigger clk from 125MHz clk
    -- synthesis read_comments_as_HDL on
    -- e_trigPLL : component work.cmp.trigPLL
    -- port map (
    --     refclk      => i_clk,
    --     rst         => not i_reset_n,
    --     outclk_0    => triggerclk,
    --     locked      => open
    -- );
    -- synthesis read_comments_as_HDL off

    -- synthesis translate_off
    triggerclk <= i_clk_fast;
    -- synthesis translate_on

    e_reset_fast_n : entity work.reset_sync
    port map ( o_reset_n => reset_fast_n, i_reset_n => i_reset_n, i_clk => triggerclk );

    -- get runstate into fast clk domain
    process(triggerclk)
    begin
    if rising_edge(triggerclk) then
        run_state_fast <= i_run_state_125;
    end if;
    end process;

    gen_trigger : for i in 0 to g_N - 1 generate

        -- slow clock process
        process(i_clk)
        begin
        if rising_edge(i_clk) then
            trig_buffer_125_reg(i)  <= trig_buffer_125(i);
            trig_buffer_125_prev(i) <= trig_buffer_125_reg(i);            
            trig_en(i)              <= '0';

            if ( trig_buffer_125_prev(i) = '0' and trig_buffer_125_reg(i) = '1' ) then
                trig_en(i)        <= '1';
                trig_ts_final(i)  <= trig_timestamp_save(i);
            end if;
        end if;
        end process;

        -- fast clk process
        process(triggerclk, reset_fast_n)
        begin
        if ( reset_fast_n /= '1' ) then
            time_over_th_cnt(i) <= (others => '0');
            fastcounter(i)      <= (others => '0');
            dead_time(i)        <= '0';
            dead_cnt(i)         <= (others => '0');
            --
        elsif rising_edge(triggerclk) then
            Trig_TTL_reg(i)     <= i_trigger(i);
            Trig_TTL_prev(i)    <= Trig_TTL_reg(i);

            if ( run_state_fast = RUN_STATE_SYNC ) then
                fastcounter(i) <= (others => '0');
            end if;

            if ( run_state_fast = RUN_STATE_RUNNING ) then
                fastcounter(i) <= fastcounter(i) + 1;
            end if;

            -- falling edge on input and not in artificial dead time
            if ( Trig_TTL_reg(i) = '0' and Trig_TTL_prev(i) = '1' and dead_time(i) = '0' ) then
                dead_time(i) <= '1';
                dead_cnt(i) <= (others => '0');
                time_over_th_cnt(i) <= (others => '0');
                if ( g_ToT(i) = '1' ) then
                    trig_timestamp_save(i) <= fastcounter(i)(15 downto 0) & time_over_th_cnt(i)(15 downto 0);
                else
                    trig_timestamp_save(i) <= fastcounter(i);
                end if;
            end if;

            if ( Trig_TTL_reg(i) = '0' and dead_time(i) = '0' ) then
                time_over_th_cnt(i) <= time_over_th_cnt(i) + '1';
            end if;

            if ( dead_time(i) = '1') then
                dead_cnt(i) <= dead_cnt(i) + '1';
                -- read trig_timestamp_save on rising edge of trig_buffer_125 in 125 MHz clock
                if ( dead_cnt(i) = x"20" ) then -- dead time counter needs to be 32
                    trig_buffer_125(i) <= '1';
                end if;

                -- end artificial dead time
                if ( dead_cnt(i) >= x"3F" ) then -- dead time counter needs to be >= 63
                    dead_time(i) <= '0';
                    trig_buffer_125(i) <= '0';
                end if;
            end if;

        end if;
        end process;

        -- we throw the trigger away if the FIFO is full
        we(i) <= '1' when wfull(i) = '0' and trig_en(i) = '1' else '0';

        e_fifo : entity work.ip_scfifo_v2
        generic map (
            g_ADDR_WIDTH => 8,
            g_DATA_WIDTH => 32--,
        )
        port map (
            i_we        => we(i),
            i_wdata     => g_INDEX(i*2 + 1 downto i*2) & trig_ts_final(i)(29 downto 0),
            o_wfull     => wfull(i),

            i_rack      => rack(i),
            o_rdata     => rdata(i),
            o_rempty    => rempty(i),

            i_reset_n   => i_reset_n,
            i_clk       => i_clk--,
        );

        -- combine output data
        data((i+1)*32-1 downto i*32) <= rdata(i);
        sop(i) <= not rempty(i);
        eop(i) <= not rempty(i);

    end generate;

    -- MUX trigger to one output
    e_stream_merger : entity work.stream_merger
    generic map (
        W => 32,
        N => g_N--,
    )
    port map (
        -- input stream
        i_rdata     => data,
        i_rsop      => sop,
        i_reop      => eop,
        i_rempty    => rempty,
        o_rack      => rack,

        -- output stream
        o_wdata     => o_trig,
        i_wfull     => '0',
        o_we        => o_trig_en,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

end architecture;

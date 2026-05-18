library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity merging_demerging_tb is
end entity;


architecture TB of merging_demerging_tb is

    signal reset_n : std_logic;
    signal clk : std_logic;

    constant NLINKS : positive := 8;

    signal r_fifo_data, w_fifo_data  : std_logic_vector(NLINKS*38-1 downto 0);
    signal w_fifo_en, r_fifo_en, fifo_empty, fifo_full : std_logic;
    signal o_data : std_logic_vector(NLINKS*32-1 downto 0);

    type sim_merger_state_type is (pre, t1, t2, sh, data, tr);
    signal event_counter_state : sim_merger_state_type;

    signal data_counter : std_logic_vector(31 downto 0);

    signal FEB_num : fifo_array_6(5 downto 0);
    signal FEB_num_in : fifo_array_6(7 downto 0);
    -- clk period
    constant clk_period : time := 4 ns;


begin

    --clk
    process begin
        clk <= '0';
        wait for clk_period;
        clk <= '1';
        wait for clk_period;
    end process;

    -- reset_n
    process begin
        reset_n <= '0';
        wait for 20 ns;
        reset_n <= '1';
        wait;
    end process;

    -- write to merger
    -- TODO: here the time alignment will be paced
    process(clk, reset_n)
    begin
    if ( reset_n <= '0' ) then
        w_fifo_data         <= (others => '0');
        data_counter        <= (others => '0');
        w_fifo_en           <= '0';
        event_counter_state <= pre;
    elsif rising_edge(clk) then

        w_fifo_en   <= '0';
        w_fifo_data <= (others => '0');


        if ( fifo_full = '0' ) then
            case event_counter_state is
            when pre =>
                event_counter_state <= t1;
                w_fifo_data(37 downto 32) <= pre_marker;
                w_fifo_data(7 downto 0) <= x"BC";
                w_fifo_en <= '1';
            when t1 =>
                event_counter_state <= t2;
                w_fifo_data(37 downto 32) <= ts1_marker;
                w_fifo_en <= '1';
            when t2 =>
                event_counter_state <= sh;
                w_fifo_data(37 downto 32) <= ts2_marker;
                w_fifo_en <= '1';
            when sh =>
                event_counter_state <= data;
                w_fifo_data(37 downto 32) <= sh_marker;
                w_fifo_en <= '1';
            when data =>
                if ( data_counter >= x"000000FF" ) then
                    event_counter_state <= tr;
                end if;
                data_counter <= data_counter + "1000";
                w_fifo_data(37 downto 0)    <= data_counter(5 downto 0)         & x"11111111";
                w_fifo_data(75 downto 38)   <= data_counter(5 downto 0) + '1'   & x"22222222";
                w_fifo_data(113 downto 76)  <= data_counter(5 downto 0) + "10"  & x"33333333";
                w_fifo_data(151 downto 114) <= data_counter(5 downto 0) + "11"  & x"44444444";
                w_fifo_data(189 downto 152) <= data_counter(5 downto 0) + "100" & x"55555555";
                w_fifo_data(227 downto 190) <= data_counter(5 downto 0) + "101" & x"66666666";
                w_fifo_data(265 downto 228) <= data_counter(5 downto 0) + "110" & x"77777777";
                w_fifo_data(303 downto 266) <= data_counter(5 downto 0) + "111" & x"88888888";
                w_fifo_en <= '1';
            when tr =>
                event_counter_state <= pre;
                data_counter <= (others => '0');
                w_fifo_data(37 downto 32) <= tr_marker;
                w_fifo_data(7 downto 0) <= x"9C";
                w_fifo_en <= '1';
            when others =>
                event_counter_state <= pre;
            end case;
        end if;
    end if;
    end process;

    -- TODO: here the time alignment will be paced
    e_merger_fifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 10,
        g_DATA_WIDTH => NLINKS * 38--,
        --g_SHOWAHEAD => "OFF",
    )
    port map (
        i_we        => w_fifo_en,
        i_wdata     => w_fifo_data,
        o_wfull     => fifo_full,

        i_rack      => r_fifo_en,
        o_rdata     => r_fifo_data,
        o_rempty    => fifo_empty,

        i_reset_n   => reset_n,
        i_clk       => clk--,
    );

    -- data merger swb
    e_data_merger_swb : entity work.data_merger_swb
    generic map (
        NLINKS  => NLINKS,
        DT      => x"01"--,
    )
    port map (
        i_data      => r_fifo_data,
        i_empty     => fifo_empty,

        i_swb_id    => x"01",

        o_ren       => r_fifo_en,
        o_wen       => open,
        o_data      => o_data,
        o_datak     => open,

        i_reset_n   => reset_n,
        i_clk       => clk--,
    );

    FEB_num(0) <= o_data(37 downto 32);
    FEB_num(1) <= o_data(75 downto 70);
    FEB_num(2) <= o_data(113 downto 108);
    FEB_num(3) <= o_data(151 downto 146);
    FEB_num(4) <= o_data(189 downto 184);
    FEB_num(5) <= o_data(227 downto 222);

    FEB_num_in(0) <= r_fifo_data(37 downto 32);
    FEB_num_in(1) <= r_fifo_data(75 downto 70);
    FEB_num_in(2) <= r_fifo_data(113 downto 108);
    FEB_num_in(3) <= r_fifo_data(151 downto 146);
    FEB_num_in(4) <= r_fifo_data(189 downto 184);
    FEB_num_in(5) <= r_fifo_data(227 downto 222);
    FEB_num_in(6) <= r_fifo_data(265 downto 260);
    FEB_num_in(7) <= r_fifo_data(303 downto 298);

end architecture;

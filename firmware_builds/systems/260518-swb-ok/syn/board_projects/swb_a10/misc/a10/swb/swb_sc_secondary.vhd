----------------------------------------------------------------------------
-- Slow Control Secondary Unit for Switching Board
-- Marius Koeppel, Mainz University
-- mkoeppel@uni-mainz.de
--
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity swb_sc_secondary is
generic (
    NLINKS      : positive := 4;
    skip_init   : std_logic := '0'
);
port (
    i_link_enable               : in    std_logic_vector(NLINKS-1 downto 0);
    i_link_data                 : in    work.mu3e.link32_array_t(NLINKS-1 downto 0);

    o_mem_addr                  : out   std_logic_vector(15 downto 0);
    o_mem_addr_finished         : out   std_logic_vector(15 downto 0);
    o_mem_data                  : out   std_logic_vector(31 downto 0);
    o_mem_we                    : out   std_logic;

    o_state                     : out   std_logic_vector(3 downto 0);

    i_reset_n                   : in    std_logic;
    i_clk                       : in    std_logic--;
);
end entity;

architecture arch of swb_sc_secondary is

    constant FIFO_POP_LATENCY_CONST : natural := 8;
    constant DEBUG_LINK_INDEX_CONST : natural := 2;
    constant DEBUG_LINK_ID_CONST    : std_logic_vector(7 downto 0) := x"02";

    signal link_data : work.mu3e.link32_array_t(NLINKS-1 downto 0);
    signal rdempty, wrfull, ren : std_logic_vector(NLINKS-1 downto 0);

    signal mem_data_o          : std_logic_vector(31 downto 0);
    signal mem_addr_o          : std_logic_vector(15 downto 0);
    signal mem_wren_o          : std_logic;
    signal current_link        : integer range 0 to NLINKS - 1;
    signal captured_link       : work.mu3e.link32_t;
    signal packet_active       : std_logic;
    signal pop_wait_cnt        : natural range 0 to FIFO_POP_LATENCY_CONST;
    signal dbg_link2_fifo_data : std_logic_vector(31 downto 0);
    signal dbg_link2_fifo_datak : std_logic_vector(3 downto 0);
    signal dbg_link2_fifo_sop  : std_logic;
    signal dbg_link2_fifo_eop  : std_logic;
    signal dbg_link2_fifo_idle : std_logic;
    signal dbg_link2_fifo_rack : std_logic;
    signal dbg_link2_fifo_rempty : std_logic;
    signal dbg_link2_data      : std_logic_vector(31 downto 0);
    signal dbg_link2_datak     : std_logic_vector(3 downto 0);
    signal dbg_link2_sop       : std_logic;
    signal dbg_link2_eop       : std_logic;
    signal dbg_link2_idle      : std_logic;
    signal dbg_link2_word_valid : std_logic;
    signal dbg_link2_header_pulse : std_logic;
    signal dbg_link2_packet_active : std_logic;

    type state_type is (init, waiting, rearm_wait, rearm_pop, capture_head, capture_body, write_word, drop_word, pop_word, wait_word);
    signal state : state_type;

    attribute keep : boolean;
    attribute preserve : boolean;
    attribute noprune : boolean;
    attribute keep of dbg_link2_fifo_data       : signal is true;
    attribute keep of dbg_link2_fifo_datak      : signal is true;
    attribute keep of dbg_link2_fifo_sop        : signal is true;
    attribute keep of dbg_link2_fifo_eop        : signal is true;
    attribute keep of dbg_link2_fifo_idle       : signal is true;
    attribute keep of dbg_link2_fifo_rack       : signal is true;
    attribute keep of dbg_link2_fifo_rempty     : signal is true;
    attribute keep of dbg_link2_data            : signal is true;
    attribute keep of dbg_link2_datak           : signal is true;
    attribute keep of dbg_link2_sop             : signal is true;
    attribute keep of dbg_link2_eop             : signal is true;
    attribute keep of dbg_link2_idle            : signal is true;
    attribute keep of dbg_link2_word_valid      : signal is true;
    attribute keep of dbg_link2_header_pulse    : signal is true;
    attribute keep of dbg_link2_packet_active   : signal is true;
    attribute preserve of dbg_link2_data          : signal is true;
    attribute preserve of dbg_link2_datak         : signal is true;
    attribute preserve of dbg_link2_sop           : signal is true;
    attribute preserve of dbg_link2_eop           : signal is true;
    attribute preserve of dbg_link2_idle          : signal is true;
    attribute preserve of dbg_link2_word_valid    : signal is true;
    attribute preserve of dbg_link2_header_pulse  : signal is true;
    attribute preserve of dbg_link2_packet_active : signal is true;
    attribute noprune of dbg_link2_data          : signal is true;
    attribute noprune of dbg_link2_datak         : signal is true;
    attribute noprune of dbg_link2_sop           : signal is true;
    attribute noprune of dbg_link2_eop           : signal is true;
    attribute noprune of dbg_link2_idle          : signal is true;
    attribute noprune of dbg_link2_word_valid    : signal is true;
    attribute noprune of dbg_link2_header_pulse  : signal is true;
    attribute noprune of dbg_link2_packet_active : signal is true;

begin

    o_mem_data <= mem_data_o;
    o_mem_addr <= mem_addr_o;
    o_mem_we <= mem_wren_o;

    debug_link2_present_gen : if DEBUG_LINK_INDEX_CONST < NLINKS generate
    begin
        dbg_link2_fifo_data   <= link_data(DEBUG_LINK_INDEX_CONST).data;
        dbg_link2_fifo_datak  <= link_data(DEBUG_LINK_INDEX_CONST).datak;
        dbg_link2_fifo_sop    <= link_data(DEBUG_LINK_INDEX_CONST).sop;
        dbg_link2_fifo_eop    <= link_data(DEBUG_LINK_INDEX_CONST).eop;
        dbg_link2_fifo_idle   <= link_data(DEBUG_LINK_INDEX_CONST).idle;
        dbg_link2_fifo_rack   <= ren(DEBUG_LINK_INDEX_CONST);
        dbg_link2_fifo_rempty <= rdempty(DEBUG_LINK_INDEX_CONST);
    end generate;

    debug_link2_absent_gen : if DEBUG_LINK_INDEX_CONST >= NLINKS generate
    begin
        dbg_link2_fifo_data   <= (others => '0');
        dbg_link2_fifo_datak  <= (others => '0');
        dbg_link2_fifo_sop    <= '0';
        dbg_link2_fifo_eop    <= '0';
        dbg_link2_fifo_idle   <= '1';
        dbg_link2_fifo_rack   <= '0';
        dbg_link2_fifo_rempty <= '1';
    end generate;

    gen_buffer_sc : FOR i in 0 to NLINKS - 1 GENERATE

        e_fifo : entity work.link32_scfifo
        generic map (
            g_ADDR_WIDTH=> 8,
            g_WREG_N    => 1,
            g_RREG_N    => 2--,
        )
        port map (
            i_wdata     => i_link_data(i),
            i_we        => not i_link_data(i).idle,
            o_wfull     => wrfull(i),

            o_rdata     => link_data(i),
            i_rack      => ren(i),
            o_rempty    => rdempty(i),

            i_reset_n   => i_reset_n,
            i_clk       => i_clk--,
        );

    END GENERATE;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        mem_data_o <= (others => '0');
        mem_addr_o <= (others => '1');
        o_mem_addr_finished <= (others => '1');
        o_state <= (others => '0');
        ren <= (others => '0');
        mem_wren_o <= '0';
        current_link <= 0;
        captured_link <= work.mu3e.LINK32_IDLE;
        packet_active <= '0';
        pop_wait_cnt <= 0;
        dbg_link2_data <= (others => '0');
        dbg_link2_datak <= (others => '0');
        dbg_link2_sop <= '0';
        dbg_link2_eop <= '0';
        dbg_link2_idle <= '1';
        dbg_link2_word_valid <= '0';
        dbg_link2_header_pulse <= '0';
        dbg_link2_packet_active <= '0';
        if ( skip_init = '0' ) then
            state <= init;
        else
            state <= waiting;
        end if;

    elsif rising_edge(i_clk) then
        o_state <= (others => '0');
        mem_data_o <= (others => '0');
        ren <= (others => '0');
        mem_wren_o <= '0';
        mem_wren_o <= '0';
        dbg_link2_word_valid <= '0';
        dbg_link2_header_pulse <= '0';

        case state is
        when init =>
            o_state(3 downto 0) <= x"1";
            mem_addr_o <= mem_addr_o + '1';
            mem_data_o <= (others => '0');
            mem_wren_o <= '1';
            if ( mem_addr_o = x"FFFE" ) then
                o_mem_addr_finished <= (others => '1');
                state <= waiting;
            end if;
            --
        when waiting =>
            o_state(3 downto 0) <= x"2";
            -- LOOP link mux take the last one for prio
            link_mux:
            FOR i in 0 to NLINKS - 1 LOOP
                if ( i_link_enable(i) = '1' and rdempty(i) = '0' and link_data(i).sop = '1' ) then
                    state <= capture_head;
                    current_link <= i;
                end if;
            END LOOP;

        when rearm_wait =>
            o_state(3 downto 0) <= x"9";
            if ( rdempty(current_link) = '1' ) then
                state <= waiting;
            elsif ( link_data(current_link).sop = '1' ) then
                state <= capture_head;
            elsif ( link_data(current_link).eop = '1' ) then
                ren(current_link) <= '1';
                pop_wait_cnt <= FIFO_POP_LATENCY_CONST;
                state <= rearm_pop;
            end if;

        when rearm_pop =>
            o_state(3 downto 0) <= x"A";
            if ( pop_wait_cnt = 0 ) then
                state <= rearm_wait;
            else
                pop_wait_cnt <= pop_wait_cnt - 1;
            end if;

        when capture_head =>
            o_state(3 downto 0) <= x"3";
            if ( rdempty(current_link) = '0' ) then
                captured_link <= link_data(current_link);
                if ( link_data(current_link).sop = '1' ) then
                    packet_active <= '1';
                    if ( link_data(current_link).data(15 downto 8) = DEBUG_LINK_ID_CONST ) then
                        dbg_link2_packet_active <= '1';
                    else
                        dbg_link2_packet_active <= '0';
                    end if;
                    state <= write_word;
                else
                    packet_active <= '0';
                    dbg_link2_packet_active <= '0';
                    state <= drop_word;
                end if;
            else
                dbg_link2_packet_active <= '0';
                state <= waiting;
            end if;

        when capture_body =>
            o_state(3 downto 0) <= x"4";
            if ( rdempty(current_link) = '0' ) then
                captured_link <= link_data(current_link);
                state <= write_word;
            else
                state <= capture_body;
            end if;

        when write_word =>
            o_state(3 downto 0) <= x"5";
            mem_addr_o <= mem_addr_o + '1';
            mem_data_o <= captured_link.data;
            mem_wren_o <= '1';
            if ( dbg_link2_packet_active = '1' ) then
                dbg_link2_data <= captured_link.data;
                dbg_link2_datak <= captured_link.datak;
                dbg_link2_sop <= captured_link.sop;
                dbg_link2_eop <= captured_link.eop;
                dbg_link2_idle <= captured_link.idle;
                dbg_link2_word_valid <= '1';
                if ( captured_link.sop = '1' ) then
                    dbg_link2_header_pulse <= '1';
                end if;
            end if;
            state <= pop_word;

        when drop_word =>
            o_state(3 downto 0) <= x"6";
            state <= pop_word;

        when pop_word =>
            o_state(3 downto 0) <= x"7";
            ren(current_link) <= '1';
            pop_wait_cnt <= FIFO_POP_LATENCY_CONST;
            state <= wait_word;

        when wait_word =>
            o_state(3 downto 0) <= x"8";
            if ( pop_wait_cnt = 0 ) then
                if ( packet_active = '1' and captured_link.eop = '1' ) then
                    packet_active <= '0';
                    dbg_link2_packet_active <= '0';
                    o_mem_addr_finished <= mem_addr_o;
                    state <= rearm_wait;
                elsif ( packet_active = '1' ) then
                    state <= capture_body;
                else
                    dbg_link2_packet_active <= '0';
                    state <= waiting;
                end if;
            else
                pop_wait_cnt <= pop_wait_cnt - 1;
            end if;
            --
        when others =>
            o_state(3 downto 0) <= x"E";
            mem_data_o <= (others => '0');
            mem_wren_o <= '0';
            dbg_link2_packet_active <= '0';
            state <= waiting;
            --
        end case;

    end if;
    end process;

end architecture;

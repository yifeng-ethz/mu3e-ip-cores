library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.finish;

entity tb_swb_data_demerger_feb_v3 is
end entity;

architecture sim of tb_swb_data_demerger_feb_v3 is
    constant CLK_PERIOD                 : time := 8 ns;
    constant FRAME_PERIOD_CYCLES        : natural := 2048;
    constant FRAMES_TO_REPLAY           : natural := 64;
    constant HITS_PER_FRAME             : natural := 1;
    constant SUBHEADERS_PER_FRAME       : natural := 128;
    constant WORDS_PER_FRAME            : natural := 5 + SUBHEADERS_PER_FRAME + HITS_PER_FRAME + 1;
    constant DRIVE_CYCLES_PER_FRAME     : natural := WORDS_PER_FRAME * 2;
    constant FEB_V3_SOP                 : std_logic_vector(31 downto 0) := x"A50000BC";

    signal clk                          : std_logic := '0';
    signal reset_n                      : std_logic := '0';
    signal aligned                      : std_logic := '1';
    signal rx_in                        : work.mu3e.link32_t := work.mu3e.LINK32_IDLE;
    signal rx_data                      : work.mu3e.link32_t;
    signal rx_sc                        : work.mu3e.link32_t;
    signal rx_rc                        : work.mu3e.link32_t;
    signal fpga_id                      : std_logic_vector(15 downto 0);
    signal done                         : boolean := false;
    signal data_words                   : natural := 0;
    signal sc_words                     : natural := 0;
    signal rc_words                     : natural := 0;
    signal opq_ingress_words            : natural := 0;
    signal opq_sop_count                : natural := 0;
    signal opq_eop_count                : natural := 0;

    procedure drive_word(
        signal data_i : out work.mu3e.link32_t;
        signal clk_i  : in  std_logic;
        constant word : in  std_logic_vector(31 downto 0);
        constant k    : in  std_logic_vector(3 downto 0)
    ) is
    begin
        wait until rising_edge(clk_i);
        data_i <= work.mu3e.to_link(word, k);
        wait until rising_edge(clk_i);
        data_i <= work.mu3e.LINK32_IDLE;
    end procedure;

    procedure drive_feb_v3_frame(
        signal data_i       : out work.mu3e.link32_t;
        signal clk_i        : in  std_logic;
        constant frame_idx  : in  natural
    ) is
        variable page_base  : unsigned(7 downto 0);
        variable subh_ts    : unsigned(7 downto 0);
        variable frame_cnt  : unsigned(15 downto 0);
        variable payload    : std_logic_vector(31 downto 0);
    begin
        if (frame_idx mod 2) = 0 then
            page_base := to_unsigned(0, 8);
        else
            page_base := to_unsigned(128, 8);
        end if;
        frame_cnt := to_unsigned(frame_idx mod 65536, 16);

        drive_word(data_i, clk_i, FEB_V3_SOP, "0001");
        drive_word(data_i, clk_i, x"2026" & std_logic_vector(frame_cnt), "0000");
        drive_word(data_i, clk_i, std_logic_vector(page_base(7 downto 4)) & x"000" & std_logic_vector(frame_cnt), "0000");
        drive_word(data_i, clk_i, '0' & std_logic_vector(to_unsigned(SUBHEADERS_PER_FRAME, 15)) & std_logic_vector(to_unsigned(HITS_PER_FRAME, 16)), "0000");
        drive_word(data_i, clk_i, x"C001" & std_logic_vector(frame_cnt), "0000");

        for shd in 0 to SUBHEADERS_PER_FRAME - 1 loop
            subh_ts := page_base + to_unsigned(shd, 8);
            if shd = ((frame_idx / 2) mod SUBHEADERS_PER_FRAME) then
                drive_word(data_i, clk_i, std_logic_vector(subh_ts) & x"00" & x"01" & work.util.K23_7, "0001");
                payload := std_logic_vector(to_unsigned(frame_idx mod 16, 4)) & x"0" & std_logic_vector(to_unsigned(frame_idx, 24));
                drive_word(data_i, clk_i, payload, "0000");
            else
                drive_word(data_i, clk_i, std_logic_vector(subh_ts) & x"00" & x"00" & work.util.K23_7, "0001");
            end if;
        end loop;

        drive_word(data_i, clk_i, x"000000" & work.util.K28_4, "0001");
    end procedure;

begin
    clk <= not clk after CLK_PERIOD / 2 when not done else clk;

    dut : entity work.swb_data_demerger
    port map (
        i_aligned => aligned,
        i_data    => rx_in,
        o_data    => rx_data,
        o_sc      => rx_sc,
        o_rc      => rx_rc,
        o_fpga_id => fpga_id,
        i_reset_n => reset_n,
        i_clk     => clk
    );

    monitor : process
    begin
        wait until rising_edge(clk);
        wait for 1 ps;
        if reset_n = '1' then
            if rx_data.idle = '0' then
                data_words <= data_words + 1;
                opq_ingress_words <= opq_ingress_words + 1;
                if rx_data.sop = '1' then
                    opq_sop_count <= opq_sop_count + 1;
                end if;
                if rx_data.eop = '1' then
                    opq_eop_count <= opq_eop_count + 1;
                end if;
            end if;
            if rx_sc.idle = '0' then
                sc_words <= sc_words + 1;
            end if;
            if rx_rc.idle = '0' then
                rc_words <= rc_words + 1;
            end if;
        end if;
    end process;

    stimulus : process
        variable expected_words : natural;
    begin
        rx_in <= work.mu3e.LINK32_IDLE;
        reset_n <= '0';
        repeat_reset : for i in 0 to 8 loop
            wait until rising_edge(clk);
        end loop;
        reset_n <= '1';
        for frame_idx in 0 to FRAMES_TO_REPLAY - 1 loop
            drive_feb_v3_frame(rx_in, clk, frame_idx);
            if frame_idx /= FRAMES_TO_REPLAY - 1 then
                for wait_idx in 1 to FRAME_PERIOD_CYCLES - DRIVE_CYCLES_PER_FRAME loop
                    wait until rising_edge(clk);
                end loop;
            end if;
        end loop;

        for i in 0 to 16 loop
            wait until rising_edge(clk);
        end loop;
        expected_words := FRAMES_TO_REPLAY * WORDS_PER_FRAME;
        report "[SWB_DEMUX_REPLAY] frames=" & integer'image(FRAMES_TO_REPLAY)
            & " frame_period_cycles=" & integer'image(FRAME_PERIOD_CYCLES)
            & " sop=0xA50000BC"
            & " data_words=" & integer'image(data_words)
            & " opq_ingress_words=" & integer'image(opq_ingress_words)
            & " sc_words=" & integer'image(sc_words)
            & " rc_words=" & integer'image(rc_words);

        assert data_words = expected_words
            report "FEB v3 frame did not reach SWB data path: data_words="
                & integer'image(data_words) & " expected=" & integer'image(expected_words)
            severity failure;
        assert opq_ingress_words = expected_words
            report "FEB v3 frame did not reach OPQ ingress model: opq_ingress_words="
                & integer'image(opq_ingress_words) & " expected=" & integer'image(expected_words)
            severity failure;
        assert opq_sop_count = FRAMES_TO_REPLAY
            report "SOP count mismatch: got=" & integer'image(opq_sop_count)
                & " expected=" & integer'image(FRAMES_TO_REPLAY)
            severity failure;
        assert opq_eop_count = FRAMES_TO_REPLAY
            report "EOP count mismatch: got=" & integer'image(opq_eop_count)
                & " expected=" & integer'image(FRAMES_TO_REPLAY)
            severity failure;
        assert sc_words = 0
            report "FEB v3 data leaked into SC path: sc_words=" & integer'image(sc_words)
            severity failure;
        assert rc_words = 0
            report "FEB v3 data leaked into RC path: rc_words=" & integer'image(rc_words)
            severity failure;

        report "*** TEST PASSED ***";
        done <= true;
        finish;
        wait;
    end process;
end architecture;

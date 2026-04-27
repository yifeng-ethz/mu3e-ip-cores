-- simulates mutrig data
-- Simon Corrodi, November 2017
-- corrodis@phys.ethz.ch

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity stic_dummy_data is
port (
    i_clk            : in  std_logic;                                        -- byte clk
    i_reset          : in  std_logic;                                        -- async but at least one 125Mhz cycle long
    i_enable         : in  std_logic;                                        --
    i_fast           : in  std_logic;                                        -- if enable, fast data format
    i_cnt            : in  std_logic_vector( 9 downto 0);                    -- number of events per frame
    o_event_data     : out std_logic_vector(48 -1 downto 0);                 --
    o_event_ready    : out std_logic;                                        -- new word ready
    o_end_of_frame   : out std_logic;                                        -- end of frame: new_frame_info
    o_frame_number   : out std_logic_vector(15 downto 0);                    -- counter
    o_frame_info     : out std_logic_vector(15 downto 0);                    -- frame_flags(6) + frame_length(10)
    o_new_frame      : out std_logic;                                        -- begin of new frame
    o_frame_info_rdy : out std_logic;
    o_busy           : out std_logic                                         --currently transmitting frame, do not cut off
);
end entity;


architecture rtl of stic_dummy_data is

  type fsm_state is (fs_idle, fs_new_frame, fs_new_word, fs_end_of_frame, fs_wait);
  signal p_state, n_state : fsm_state;

  signal n_event_cnt, p_event_cnt, s_cnt: std_logic_vector( 9 downto 0);
  signal n_wait_cnt, p_wait_cnt         : std_logic_vector(10 downto 0);

  signal n_event_ready, p_event_ready       : std_logic;
  signal n_end_of_frame, p_end_of_frame     : std_logic;
  signal n_new_frame, p_new_frame           : std_logic;
  signal n_frame_info_rdy, p_frame_info_rdy : std_logic;
  signal n_frame_number, p_frame_number     : std_logic_vector(15 downto 0)      := (others => '0');
  signal n_event_data, p_event_data         : std_logic_vector(48 -1  downto 0)  := (others => '0');

begin


    o_busy <= '0' when ( p_state = fs_idle or p_state = fs_wait ) else '1';

    s_cnt  <= i_cnt(9 downto 2) & i_cnt(0) & '0' when i_fast = '0' else
              i_cnt;

    fsm_comb : process(p_state, s_cnt, i_fast, i_enable, p_wait_cnt, p_event_cnt, p_frame_number, p_event_data)
    begin
    n_state <= p_state;

    n_event_cnt     <= p_event_cnt;
    n_wait_cnt  <= std_logic_vector(unsigned(p_wait_cnt)-1);

    n_event_ready   <= '0';
    n_end_of_frame  <= '0';
    n_new_frame     <= '0';
    n_frame_info_rdy<= '0';
    n_frame_number  <= p_frame_number;
    n_event_data    <= p_event_data;

    case p_state is
        when fs_idle =>
            if i_enable = '1' then
                n_wait_cnt <= "00000000110";
                n_state <= fs_new_frame;
            end if;
        --build frame header
        when fs_new_frame =>
            n_wait_cnt <= std_logic_vector(unsigned(p_wait_cnt)-1);
            if p_wait_cnt = "000000000010" then
                n_new_frame <= '1';
            end if;
            if p_wait_cnt = "00000000000" then
                n_frame_info_rdy <= '1';
                if i_fast = '0' then
                    n_wait_cnt <= "00000000110"; -- 6 bytes
                else
                    n_wait_cnt <= "00000000011"; -- 3 bytes
                end if;
                if(unsigned(s_cnt) = 0) then
                    n_state <= fs_end_of_frame;
                else
                    n_event_cnt <= s_cnt - 1;
                    n_state <= fs_new_word;
                end if;
            end if;
        --build hits
        when fs_new_word =>
            if p_wait_cnt = "00000000000" then
                n_event_data  <= std_logic_vector(unsigned(p_event_data) + 1);
                n_event_cnt   <= std_logic_vector(unsigned(p_event_cnt) - 1);
                if p_event_cnt = "0000000000" then
                    n_wait_cnt <= "00000000001"; -- >= 001 needed
                    n_state <= fs_end_of_frame;
                else
                    if i_fast = '0' then
                        n_wait_cnt <= "00000000110"; -- 6 bytes
                    else
                        n_wait_cnt <= "00000000011"; -- 3 bytes
                    end if;
                    n_state <= fs_new_word;
                end if;
            else
                if  p_wait_cnt = "00000000001" then
                    n_event_ready <= '1';
                end if;
            end if;
        --build trailer
        when fs_end_of_frame =>
            if p_wait_cnt = "00000000001" then
                n_end_of_frame <= '1';
            end if;
            if p_wait_cnt = "00000000000" then
                n_frame_number <= std_logic_vector(unsigned(p_frame_number) + 1);
                n_wait_cnt <= std_logic_vector(to_unsigned((255-to_integer(unsigned(i_cnt))* 6),11));
                n_state <= fs_wait;
            end if;
        --wait for start of next frame
        when fs_wait =>
            if p_wait_cnt = "00000000000" then
                n_state <= fs_idle;
            end if;
        when others => n_state <= fs_idle;
    end case;

    end process;

-------------------------------------------------------------------------------

    fsm_syn : process (i_clk, i_reset)
    begin
    if ( i_reset = '1' ) then
        p_state          <= fs_idle;
        p_event_ready    <= '0';
        p_end_of_frame   <= '0';
        p_new_frame      <= '0';
        p_frame_info_rdy <= '0';
        p_frame_number   <= (others=>'0');
        p_event_data     <= (others =>'0');
        --
    elsif rising_edge(i_clk) then
        p_state          <= n_state;
        p_event_ready    <= n_event_ready;
        p_end_of_frame   <= n_end_of_frame;
        p_new_frame      <= n_new_frame;
        p_frame_number   <= n_frame_number;
        p_frame_info_rdy <= n_frame_info_rdy;
        p_event_data     <= n_event_data;
        p_event_cnt      <= n_event_cnt;
        p_wait_cnt       <= n_wait_cnt;
    end if;
    end process;

    -------------------------------------------------------------------------------

    o_event_data <= p_event_data;
    o_event_ready <= p_event_ready;
    o_end_of_frame <= p_end_of_frame;
    o_frame_number <= p_frame_number;
    o_frame_info <= '1' & i_fast & "0000" & i_cnt;
    o_new_frame <= p_new_frame;
    o_frame_info_rdy <= p_frame_info_rdy;

end architecture;


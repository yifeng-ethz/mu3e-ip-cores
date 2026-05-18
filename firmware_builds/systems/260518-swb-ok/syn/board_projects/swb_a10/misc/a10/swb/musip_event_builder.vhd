--
-- Marius Koeppel, March 2026
--
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;


entity musip_event_builder is
port (
    i_rx                : in  std_logic_vector(255 downto 0);
    i_valid             : in  std_logic;

    i_get_n_words       : in  std_logic_vector(31 downto 0);
    i_dmamemhalffull    : in  std_logic;
    i_wen               : in  std_logic;
    o_data              : out std_logic_vector(255 downto 0);
    o_wen               : out std_logic;
    o_endofevent        : out std_logic;
    o_done              : out std_logic;

    o_hit_cnt           : out std_logic_vector(63 downto 0);
    o_hit_drop_cnt      : out std_logic_vector(63 downto 0);
    o_full_cnt          : out std_logic_vector(63 downto 0);
    o_hit_rate          : out std_logic_vector(31 downto 0);

    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

architecture arch of musip_event_builder is

    constant PAD_WORD_COUNT_C    : natural := 128;
    constant PAD_WORD_LAST_IDX_C : unsigned(31 downto 0) := to_unsigned(PAD_WORD_COUNT_C - 1, 32);

    ------------------------------------------------------------------------
    -- State machine
    ------------------------------------------------------------------------
    type event_builder_state_t is (
        waiting,
        write_payload,
        write_last_payload,
        write_4kb_padding
    );

    signal event_builder_state : event_builder_state_t := waiting;
    signal payload_words_remaining : unsigned(31 downto 0) := (others => '0');
    signal padding_words_sent      : unsigned(31 downto 0) := (others => '0');


    ------------------------------------------------------------------------
    -- FIFO interface signals
    ------------------------------------------------------------------------
    signal fifo_full    : std_logic := '0';
    signal fifo_empty   : std_logic := '1';
    signal fifo_en      : std_logic := '0';
    signal fifo_data    : std_logic_vector(255 downto 0);
    signal wrusedw  : std_logic_vector(13 downto 0);  -- matches g_ADDR_WIDTH=12
    signal drop_hit : std_logic;

    ------------------------------------------------------------------------
    -- Counters
    ------------------------------------------------------------------------
    signal hit_cnt : std_logic_vector(63 downto 0) := (others => '0');
    signal hit_drop_cnt : std_logic_vector(63 downto 0) := (others => '0');
    signal full_cnt : std_logic_vector(63 downto 0) := (others => '0');

    ------------------------------------------------------------------------
    -- Control signals
    ------------------------------------------------------------------------
    signal done               : std_logic := '0';
    signal launch_request     : std_logic := '0';
    signal payload_write_fire : std_logic := '0';
    signal padding_write_fire : std_logic := '0';

begin

    --! counter
    o_hit_cnt <= hit_cnt;
    o_hit_drop_cnt <= hit_drop_cnt;
    o_full_cnt <= full_cnt;

    e_fifo_event : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 14,
        g_DATA_WIDTH => 256,
        g_RREG_N     => 1--,
    )
    port map (
        i_we        => i_valid,
        i_wdata     => i_rx,
        o_wfull     => fifo_full,
        o_usedw     => wrusedw,

        i_rack      => fifo_en or wrusedw(13),
        o_rdata     => fifo_data,
        o_rempty    => fifo_empty,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    --! data out
    launch_request <= '1' when i_wen = '1' and unsigned(i_get_n_words) /= to_unsigned(0, i_get_n_words'length) and done = '0' else '0';
    payload_write_fire <= '1' when (fifo_empty = '0' and i_dmamemhalffull = '0') and (event_builder_state = write_payload or event_builder_state = write_last_payload) else '0';
    padding_write_fire <= '1' when event_builder_state = write_4kb_padding and i_dmamemhalffull = '0' else '0';
    fifo_en <= payload_write_fire;
    drop_hit <= '1' when fifo_en = '0' and wrusedw(13) = '1' else '0';
    o_wen <= padding_write_fire or payload_write_fire;
    o_data <= fifo_data when event_builder_state = write_payload or event_builder_state = write_last_payload else (others => '1');
    o_endofevent <= '1' when payload_write_fire = '1' and event_builder_state = write_last_payload else '0';
    o_done <= done;

    e_hit_rate : entity work.word_rate
    generic map ( g_CLK_MHZ => 250.0 )
    port map (
        i_valid => fifo_en, o_rate => o_hit_rate,
        i_reset_n => i_reset_n, i_clk => i_clk--,
    );

    -- dma end of events, count events and write control
    process(i_clk)
    begin
    if rising_edge(i_clk) then
        if ( i_reset_n = '0' ) then
            done <= '0';
            event_builder_state <= waiting;
            hit_cnt <= (others => '0');
            hit_drop_cnt <= (others => '0');
            full_cnt <= (others => '0');
            payload_words_remaining <= (others => '0');
            padding_words_sent <= (others => '0');
            --
        else

            if ( drop_hit = '1' ) then
                hit_drop_cnt <= std_logic_vector(unsigned(hit_drop_cnt) + 1);
            end if;

            if ( i_wen = '0' ) then
                done <= '0';
            end if;

            if ( fifo_full = '1' ) then
                full_cnt <= std_logic_vector(unsigned(full_cnt) + 1);
            end if;

            case event_builder_state is
                when waiting =>
                    -- A zero-word request is treated as "no launch" because this block
                    -- has no independent event-start strobe. The completion latch stays
                    -- low until a non-zero request is armed and retired.
                    if ( launch_request = '1' ) then
                        payload_words_remaining <= unsigned(i_get_n_words);
                        if ( unsigned(i_get_n_words) = to_unsigned(1, i_get_n_words'length) ) then
                            event_builder_state <= write_last_payload;
                        else
                            event_builder_state <= write_payload;
                        end if;
                    end if;

                when write_payload =>
                    if ( payload_write_fire = '1' ) then
                        hit_cnt <= std_logic_vector(unsigned(hit_cnt) + 1);
                        if ( payload_words_remaining = to_unsigned(2, payload_words_remaining'length) ) then
                            payload_words_remaining <= to_unsigned(1, payload_words_remaining'length);
                            event_builder_state <= write_last_payload;
                        elsif ( payload_words_remaining > to_unsigned(2, payload_words_remaining'length) ) then
                            payload_words_remaining <= payload_words_remaining - 1;
                        end if;
                    end if;

                when write_last_payload =>
                    if ( payload_write_fire = '1' ) then
                        payload_words_remaining <= (others => '0');
                        padding_words_sent <= (others => '0');
                        event_builder_state <= write_4kb_padding;
                        hit_cnt <= std_logic_vector(unsigned(hit_cnt) + 1);
                    end if;

                when write_4kb_padding =>
                    if ( padding_write_fire = '1' ) then
                        if ( padding_words_sent = PAD_WORD_LAST_IDX_C ) then
                            done <= '1';
                            event_builder_state <= waiting;
                        else
                            padding_words_sent <= padding_words_sent + 1;
                        end if;
                    end if;

                when others =>
                    event_builder_state <= waiting;

            end case;
        end if;

    end if;
    end process;

end architecture;

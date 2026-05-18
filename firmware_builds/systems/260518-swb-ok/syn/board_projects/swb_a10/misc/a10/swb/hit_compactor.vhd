--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity hit_compactor is
  generic (
    g_WORD_WIDTH : positive := 64;
    g_WORDS_IN   : positive := 4;
    g_WORDS_OUT  : positive := 4
  );
  port (
    i_clk        : in  std_logic;
    i_reset_n    : in  std_logic;

    i_data       : in  std_logic_vector(g_WORDS_IN*g_WORD_WIDTH-1 downto 0);
    i_valid      : in  std_logic;

    o_data       : out std_logic_vector(g_WORDS_OUT*g_WORD_WIDTH-1 downto 0);
    o_valid      : out std_logic
  );
end entity;

architecture rtl of hit_compactor is

  constant c_INVALID_WORD : std_logic_vector(g_WORD_WIDTH-1 downto 0) := (others => '1');
  constant c_INVALID_DATA : std_logic_vector(g_WORDS_IN*g_WORD_WIDTH-1 downto 0) := (others => '1');
  constant c_HOLD_DEPTH   : positive := g_WORDS_OUT - 1;
  constant c_MERGE_DEPTH  : positive := g_WORDS_OUT + g_WORDS_IN - 1;

  type word_array_in_t   is array (0 to g_WORDS_IN-1) of std_logic_vector(g_WORD_WIDTH-1 downto 0);
  type hold_array_t      is array (0 to c_HOLD_DEPTH-1) of std_logic_vector(g_WORD_WIDTH-1 downto 0);
  type merge_array_t     is array (0 to c_MERGE_DEPTH-1) of std_logic_vector(g_WORD_WIDTH-1 downto 0);

  signal input_data_r     : std_logic_vector(g_WORDS_IN*g_WORD_WIDTH-1 downto 0) := c_INVALID_DATA;
  signal input_valid_r    : std_logic := '0';
  signal compact_words_r  : word_array_in_t := (others => c_INVALID_WORD);
  signal compact_count_r  : integer range 0 to g_WORDS_IN := 0;

  signal hold_reg   : hold_array_t := (others => c_INVALID_WORD);
  signal hold_count : integer range 0 to c_HOLD_DEPTH := 0;

  signal o_data_r   : std_logic_vector(g_WORDS_OUT*g_WORD_WIDTH-1 downto 0) := (others => '1');
  signal o_valid_r  : std_logic := '0';

begin

  assert (g_WORDS_IN = 4) and (g_WORDS_OUT = 4)
    report "hit_compactor timing-clean implementation currently supports only 4 input and 4 output words"
    severity failure;

  p_input_compact : process(i_clk)
    variable in_words_v      : word_array_in_t;
    variable compact_words_v : word_array_in_t;
    variable compact_count_v : integer range 0 to g_WORDS_IN;
    variable valid_mask_v    : std_logic_vector(3 downto 0);
  begin
    if rising_edge(i_clk) then
      if i_reset_n /= '1' then
        input_data_r    <= c_INVALID_DATA;
        input_valid_r   <= '0';
        compact_words_r <= (others => c_INVALID_WORD);
        compact_count_r <= 0;
      else
        input_data_r    <= i_data;
        input_valid_r   <= i_valid;
        compact_words_v := (others => c_INVALID_WORD);
        compact_count_v := 0;
        valid_mask_v    := (others => '0');

        for i in 0 to g_WORDS_IN-1 loop
          in_words_v(i) := input_data_r((i+1)*g_WORD_WIDTH-1 downto i*g_WORD_WIDTH);
        end loop;

        if input_valid_r = '1' then
          if in_words_v(0) /= c_INVALID_WORD then
            valid_mask_v(0) := '1';
          end if;
          if in_words_v(1) /= c_INVALID_WORD then
            valid_mask_v(1) := '1';
          end if;
          if in_words_v(2) /= c_INVALID_WORD then
            valid_mask_v(2) := '1';
          end if;
          if in_words_v(3) /= c_INVALID_WORD then
            valid_mask_v(3) := '1';
          end if;
        end if;

        case valid_mask_v is
          when "0000" =>
            compact_count_v := 0;
          when "0001" =>
            compact_words_v(0) := in_words_v(0);
            compact_count_v := 1;
          when "0010" =>
            compact_words_v(0) := in_words_v(1);
            compact_count_v := 1;
          when "0011" =>
            compact_words_v(0) := in_words_v(0);
            compact_words_v(1) := in_words_v(1);
            compact_count_v := 2;
          when "0100" =>
            compact_words_v(0) := in_words_v(2);
            compact_count_v := 1;
          when "0101" =>
            compact_words_v(0) := in_words_v(0);
            compact_words_v(1) := in_words_v(2);
            compact_count_v := 2;
          when "0110" =>
            compact_words_v(0) := in_words_v(1);
            compact_words_v(1) := in_words_v(2);
            compact_count_v := 2;
          when "0111" =>
            compact_words_v(0) := in_words_v(0);
            compact_words_v(1) := in_words_v(1);
            compact_words_v(2) := in_words_v(2);
            compact_count_v := 3;
          when "1000" =>
            compact_words_v(0) := in_words_v(3);
            compact_count_v := 1;
          when "1001" =>
            compact_words_v(0) := in_words_v(0);
            compact_words_v(1) := in_words_v(3);
            compact_count_v := 2;
          when "1010" =>
            compact_words_v(0) := in_words_v(1);
            compact_words_v(1) := in_words_v(3);
            compact_count_v := 2;
          when "1011" =>
            compact_words_v(0) := in_words_v(0);
            compact_words_v(1) := in_words_v(1);
            compact_words_v(2) := in_words_v(3);
            compact_count_v := 3;
          when "1100" =>
            compact_words_v(0) := in_words_v(2);
            compact_words_v(1) := in_words_v(3);
            compact_count_v := 2;
          when "1101" =>
            compact_words_v(0) := in_words_v(0);
            compact_words_v(1) := in_words_v(2);
            compact_words_v(2) := in_words_v(3);
            compact_count_v := 3;
          when "1110" =>
            compact_words_v(0) := in_words_v(1);
            compact_words_v(1) := in_words_v(2);
            compact_words_v(2) := in_words_v(3);
            compact_count_v := 3;
          when others =>
            compact_words_v(0) := in_words_v(0);
            compact_words_v(1) := in_words_v(1);
            compact_words_v(2) := in_words_v(2);
            compact_words_v(3) := in_words_v(3);
            compact_count_v := 4;
        end case;

        compact_words_r <= compact_words_v;
        compact_count_r <= compact_count_v;
      end if;
    end if;
  end process;

  p_merge_and_buffer : process(i_clk)
    variable merged_v      : merge_array_t;
    variable next_hold_v   : hold_array_t;
    variable total_count_v : integer range 0 to c_MERGE_DEPTH;
    variable out_flat_v    : std_logic_vector(g_WORDS_OUT*g_WORD_WIDTH-1 downto 0);
  begin
    if rising_edge(i_clk) then
      if i_reset_n /= '1' then
        hold_reg   <= (others => c_INVALID_WORD);
        hold_count <= 0;
        o_data_r   <= (others => '1');
        o_valid_r  <= '0';

      else
        -- defaults
        merged_v      := (others => c_INVALID_WORD);
        next_hold_v   := (others => c_INVALID_WORD);
        out_flat_v    := (others => '1');
        total_count_v := hold_count + compact_count_r;

        -- Build the packed stream with fixed 4-lane muxing instead of a
        -- loop-carried variable index. This is the critical 250 MHz path.
        case hold_count is
          when 0 =>
            merged_v(0) := compact_words_r(0);
            merged_v(1) := compact_words_r(1);
            merged_v(2) := compact_words_r(2);
            merged_v(3) := compact_words_r(3);
          when 1 =>
            merged_v(0) := hold_reg(0);
            merged_v(1) := compact_words_r(0);
            merged_v(2) := compact_words_r(1);
            merged_v(3) := compact_words_r(2);
            merged_v(4) := compact_words_r(3);
          when 2 =>
            merged_v(0) := hold_reg(0);
            merged_v(1) := hold_reg(1);
            merged_v(2) := compact_words_r(0);
            merged_v(3) := compact_words_r(1);
            merged_v(4) := compact_words_r(2);
            merged_v(5) := compact_words_r(3);
          when others =>
            merged_v(0) := hold_reg(0);
            merged_v(1) := hold_reg(1);
            merged_v(2) := hold_reg(2);
            merged_v(3) := compact_words_r(0);
            merged_v(4) := compact_words_r(1);
            merged_v(5) := compact_words_r(2);
            merged_v(6) := compact_words_r(3);
        end case;

        -- only emit when we have a full output word
        if total_count_v >= g_WORDS_OUT then
          for i in 0 to g_WORDS_OUT-1 loop
            out_flat_v((i+1)*g_WORD_WIDTH-1 downto i*g_WORD_WIDTH) := merged_v(i);
          end loop;

          o_data_r  <= out_flat_v;
          o_valid_r <= '1';

          -- keep leftover words in the holding register
          case total_count_v is
            when 5 =>
              next_hold_v(0) := merged_v(4);
            when 6 =>
              next_hold_v(0) := merged_v(4);
              next_hold_v(1) := merged_v(5);
            when 7 =>
              next_hold_v(0) := merged_v(4);
              next_hold_v(1) := merged_v(5);
              next_hold_v(2) := merged_v(6);
            when others =>
              null;
          end case;

          hold_reg   <= next_hold_v;
          hold_count <= total_count_v - g_WORDS_OUT;

        else
          -- not enough valid words yet, just buffer them
          o_data_r  <= (others => '1');
          o_valid_r <= '0';

          case total_count_v is
            when 1 =>
              next_hold_v(0) := merged_v(0);
            when 2 =>
              next_hold_v(0) := merged_v(0);
              next_hold_v(1) := merged_v(1);
            when 3 =>
              next_hold_v(0) := merged_v(0);
              next_hold_v(1) := merged_v(1);
              next_hold_v(2) := merged_v(2);
            when others =>
              null;
          end case;

          hold_reg   <= next_hold_v;
          hold_count <= total_count_v;
        end if;
      end if;
    end if;
  end process;

  o_data  <= o_data_r;
  o_valid <= o_valid_r;

end architecture;

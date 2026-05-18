library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

entity tb_subtime_merger is
end entity;

architecture sim of tb_subtime_merger is
  constant c_LINK_N : positive := 4;
  constant c_SUB_BITS : positive := 3;
  constant c_DATA_WIDTH : positive := 64;

  signal clk : std_logic := '0';
  signal reset_n : std_logic := '0';
  signal data_i : slv64_array_t(c_LINK_N-1 downto 0) := (others => (others => '0'));
  signal valid_i : std_logic_vector(c_LINK_N-1 downto 0) := (others => '0');
  signal cur_subtime_i : slv8_array_t(c_LINK_N-1 downto 0) := (others => (others => '0'));
  signal mask_n_i : std_logic_vector(c_LINK_N-1 downto 0) := (others => '1');
  signal data_o : std_logic_vector(c_LINK_N*c_DATA_WIDTH-1 downto 0);
  signal valid_o : std_logic;
  signal word_cnt_o : std_logic_vector(63 downto 0);
  signal fifo_full_cnt_o : std_logic_vector(31 downto 0);

  type word_array_t is array (0 to c_LINK_N-1) of std_logic_vector(c_DATA_WIDTH-1 downto 0);

  function make_word(subtime : natural; lane : natural; tag : natural) return std_logic_vector is
    variable word_v : std_logic_vector(c_DATA_WIDTH-1 downto 0) := (others => '0');
  begin
    word_v(63 downto 56) := std_logic_vector(to_unsigned(16#A0# + lane, 8));
    word_v(15 downto 8) := std_logic_vector(to_unsigned(tag, 8));
    word_v(c_SUB_BITS+3 downto 4) := std_logic_vector(to_unsigned(subtime, c_SUB_BITS));
    return word_v;
  end function;

  procedure drive_cur_subtime(signal cur_subtime : out slv8_array_t(c_LINK_N-1 downto 0);
                              value : natural) is
  begin
    for lane in 0 to c_LINK_N-1 loop
      cur_subtime(lane) <= std_logic_vector(to_unsigned(value, 8));
    end loop;
  end procedure;

  procedure push_window(signal data : out slv64_array_t(c_LINK_N-1 downto 0);
                        signal valid : out std_logic_vector(c_LINK_N-1 downto 0);
                        signal cur_subtime : out slv8_array_t(c_LINK_N-1 downto 0);
                        subtime : natural;
                        tag : natural) is
  begin
    for lane in 0 to c_LINK_N-1 loop
      data(lane) <= make_word(subtime, lane, tag);
    end loop;
    valid <= (others => '1');
    wait until rising_edge(clk);
    valid <= (others => '0');
    wait until rising_edge(clk);
    drive_cur_subtime(cur_subtime, (subtime + 1) mod 2**c_SUB_BITS);
    wait until rising_edge(clk);
  end procedure;

  procedure expect_window(signal data : in std_logic_vector(c_LINK_N*c_DATA_WIDTH-1 downto 0);
                          signal valid : in std_logic;
                          subtime : natural;
                          tag : natural) is
    variable seen_v : boolean := false;
    variable got_v : std_logic_vector(c_DATA_WIDTH-1 downto 0);
  begin
    for cycle in 0 to 31 loop
      wait until rising_edge(clk);
      if valid = '1' then
        seen_v := true;
        for lane in 0 to c_LINK_N-1 loop
          got_v := data((lane+1)*c_DATA_WIDTH-1 downto lane*c_DATA_WIDTH);
          assert got_v = make_word(subtime, lane, tag)
            report "unexpected output word for lane " & integer'image(lane)
            severity failure;
        end loop;
        exit;
      end if;
    end loop;

    assert seen_v
      report "timed out waiting for merged subtime window"
      severity failure;
  end procedure;
begin
  clk <= not clk after 2 ns;

  dut : entity work.subtime_merger
    generic map (
      g_LINK_N => c_LINK_N,
      g_N_SUBTIME_BITS => c_SUB_BITS,
      g_DATA_WIDTH => c_DATA_WIDTH,
      g_FIFO_ADDR_WIDTH => 4
    )
    port map (
      i_data => data_i,
      i_valid => valid_i,
      i_cur_subtime => cur_subtime_i,
      i_mask_n => mask_n_i,
      o_data => data_o,
      o_valid => valid_o,
      o_word_cnt => word_cnt_o,
      o_fifo_full_cnt => fifo_full_cnt_o,
      i_reset_n => reset_n,
      i_clk => clk
    );

  p_stim : process
  begin
    drive_cur_subtime(cur_subtime_i, 0);
    wait for 20 ns;
    wait until rising_edge(clk);
    reset_n <= '1';
    wait until rising_edge(clk);

    push_window(data_i, valid_i, cur_subtime_i, 0, 1);
    expect_window(data_o, valid_o, 0, 1);

    push_window(data_i, valid_i, cur_subtime_i, 1, 2);
    expect_window(data_o, valid_o, 1, 2);

    for cycle in 0 to 5 loop
      wait until rising_edge(clk);
      assert valid_o = '0'
        report "duplicate output valid after drained windows"
        severity failure;
    end loop;

    assert unsigned(word_cnt_o) = 2
      report "word counter mismatch"
      severity failure;
    assert unsigned(fifo_full_cnt_o) = 0
      report "unexpected FIFO full count"
      severity failure;

    report "tb_subtime_merger passed" severity note;
    std.env.stop;
  end process;
end architecture;

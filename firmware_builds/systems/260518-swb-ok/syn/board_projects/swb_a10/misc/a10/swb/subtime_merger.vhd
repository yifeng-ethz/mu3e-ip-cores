--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;


use work.util_slv.all;


entity subtime_merger is
  generic (
    g_LINK_N          : positive := 4;
    g_N_SUBTIME_BITS  : positive := 3;
    g_DATA_WIDTH      : positive := 64;
    g_FIFO_ADDR_WIDTH : positive := 8   -- FIFO depth = 2**g_FIFO_ADDR_WIDTH
  );
  port (
    i_data          : in  slv64_array_t(g_LINK_N-1 downto 0);
    i_valid         : in  std_logic_vector(g_LINK_N-1 downto 0);
    i_cur_subtime   : in  slv8_array_t(g_LINK_N-1 downto 0);
    i_mask_n        : in  std_logic_vector(g_LINK_N-1 downto 0);

    o_data          : out std_logic_vector(g_LINK_N*g_DATA_WIDTH-1 downto 0);
    o_valid         : out std_logic;

    o_word_cnt      : out std_logic_vector(63 downto 0);
    o_fifo_full_cnt : out std_logic_vector(31 downto 0);

    i_reset_n       : in  std_logic;
    i_clk           : in  std_logic
  );
end entity;

architecture rtl of subtime_merger is

  constant c_N_WINDOWS : positive := 2**g_N_SUBTIME_BITS;
  constant c_INVALID_HIT : std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others => '1');

  type subtime_array_t is array (0 to g_LINK_N-1) of std_logic_vector(g_N_SUBTIME_BITS-1 downto 0);
  type word_fifo_array_t is array (0 to c_N_WINDOWS-1, 0 to g_LINK_N-1) of std_logic_vector(g_DATA_WIDTH-1 downto 0);
  type sl_fifo_array_t   is array (0 to c_N_WINDOWS-1, 0 to g_LINK_N-1) of std_logic;
  type out_array_t       is array (0 to g_LINK_N-1) of std_logic_vector(g_DATA_WIDTH-1 downto 0);
  type subtime_done_array_t is array (0 to c_N_WINDOWS-1) of std_logic_vector(g_LINK_N-1 downto 0);
  type cnt_fifo_array_t  is array (0 to c_N_WINDOWS-1, 0 to g_LINK_N-1) of unsigned(g_FIFO_ADDR_WIDTH downto 0);

  -- Subtime encoded inside the hit payload
  signal hit_subtime : subtime_array_t;

  -- External current subtime per lane
  signal cur_subtime_ext : subtime_array_t;

  -- FIFO signals: fifo(window, lane)
  signal fifo_din    : word_fifo_array_t;
  signal fifo_dout   : word_fifo_array_t;
  signal fifo_wr_en  : sl_fifo_array_t;
  signal fifo_rd_en  : sl_fifo_array_t;
  signal fifo_full   : sl_fifo_array_t;
  signal fifo_empty  : sl_fifo_array_t;

  -- Local occupancy bookkeeping for each FIFO
  signal fifo_count  : cnt_fifo_array_t := (others => (others => (others => '0')));

  -- subtime_changed(win)(lane) = lane has moved away from this window
  signal subtime_changed         : subtime_done_array_t := (others => (others => '0'));
  signal cur_subtime_reading_win : unsigned(g_N_SUBTIME_BITS-1 downto 0) := (others => '0');
  signal last_cur_subtime        : subtime_array_t := (others => (others => '0'));

  -- Read-plan and output pipeline. The plan register cuts the 250 MHz path
  -- from current-window selection through FIFO-availability reduction.
  signal out_data : std_logic_vector(g_LINK_N*g_DATA_WIDTH-1 downto 0);
  signal out_data_arr_r    : out_array_t := (others => c_INVALID_HIT);
  signal read_data_arr_next : out_array_t := (others => c_INVALID_HIT);
  signal read_sel_r         : sl_fifo_array_t := (others => (others => '0'));
  signal read_sel_next      : sl_fifo_array_t := (others => (others => '0'));
  signal read_plan_valid_r  : std_logic := '0';
  signal read_plan_valid_next : std_logic := '0';
  signal read_plan_advance_r  : std_logic := '0';
  signal read_plan_advance_next : std_logic := '0';
  signal out_valid_r       : std_logic := '0';
  signal o_valid_s : std_logic := '0';

  signal word_cnt_u      : unsigned(63 downto 0) := (others => '0');
  signal fifo_full_cnt_u : unsigned(31 downto 0) := (others => '0');
  signal state_reset_n   : std_logic := '0';
  signal compactor_reset_n : std_logic := '0';
  signal fifo_reset_n    : sl_fifo_array_t := (others => (others => '0'));

begin

  ----------------------------------------------------------------------------
  -- Extract subtime from incoming hit payload
  -- Assumes subtime is in bits [g_N_SUBTIME_BITS+3:4]
  ----------------------------------------------------------------------------
  p_extract_hit_subtime : process(all)
  begin
    for i in 0 to g_LINK_N-1 loop
      hit_subtime(i) <= i_data(i)(g_N_SUBTIME_BITS+3 downto 4);
    end loop;
  end process;

  ----------------------------------------------------------------------------
  -- Unpack external current subtime vector into array
  ----------------------------------------------------------------------------
  gen_unpack_subtime : for i in 0 to g_LINK_N-1 generate
    cur_subtime_ext(i) <= i_cur_subtime(i)(g_N_SUBTIME_BITS-1 downto 0);
  end generate;

  p_reset_pipe : process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_reset_n /= '1' then
        state_reset_n <= '0';
        compactor_reset_n <= '0';
        fifo_reset_n <= (others => (others => '0'));
      else
        state_reset_n <= '1';
        compactor_reset_n <= '1';
        fifo_reset_n <= (others => (others => '1'));
      end if;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- Write side: one write per lane per cycle into fifo(subtime, lane)
  -- FIFO selection is based on subtime carried in the hit payload.
  ----------------------------------------------------------------------------
  p_write_comb : process(all)
    variable s_v : integer range 0 to c_N_WINDOWS-1;
  begin
    fifo_wr_en <= (others => (others => '0'));
    fifo_din   <= (others => (others => c_INVALID_HIT));

    for lane in 0 to g_LINK_N-1 loop
      if i_valid(lane) = '1' then
        s_v := to_integer(unsigned(hit_subtime(lane)));
        fifo_wr_en(s_v, lane) <= '1';
        fifo_din(s_v, lane)   <= i_data(lane);
      end if;
    end loop;
  end process;

  ----------------------------------------------------------------------------
  -- Read-plan selector:
  -- Drain only when the current window is complete for all enabled lanes.
  -- Masked lanes are treated as already complete.
  --
  -- Select up to one word from each enabled lane FIFO of the current window.
  -- Use fifo_count to decide availability and to know whether anything remains
  -- after the planned pops. The registered plan executes one cycle later.
  ----------------------------------------------------------------------------
  p_read_plan_comb : process(all)
    variable cur_win_v         : integer range 0 to c_N_WINDOWS-1;
    variable found_any_v       : boolean;
    variable any_left_after_v  : boolean;
    variable selected_v        : sl_fifo_array_t;
    variable win_complete_v    : std_logic_vector(g_LINK_N-1 downto 0);
  begin
    selected_v          := (others => (others => '0'));
    read_sel_next       <= (others => (others => '0'));
    read_plan_valid_next   <= '0';
    read_plan_advance_next <= '0';

    cur_win_v   := to_integer(cur_subtime_reading_win);
    found_any_v := false;

    for lane in 0 to g_LINK_N-1 loop
      win_complete_v(lane) := subtime_changed(cur_win_v)(lane) or (not i_mask_n(lane));
    end loop;

    if (read_plan_valid_r = '0') and (read_plan_advance_r = '0') and
       (and_reduce(win_complete_v) = '1') then

      -- Pick up to one hit from each enabled lane FIFO for this window.
      for lane in 0 to g_LINK_N-1 loop
        if i_mask_n(lane) = '1' then
          if fifo_count(cur_win_v, lane) /= 0 then
            selected_v(cur_win_v, lane) := '1';
            found_any_v := true;
          end if;
        end if;
      end loop;

      -- Check if anything remains in this window after these selected pops.
      any_left_after_v := false;
      for lane in 0 to g_LINK_N-1 loop
        if i_mask_n(lane) = '1' then
          if selected_v(cur_win_v, lane) = '1' then
            if fifo_count(cur_win_v, lane) > 1 then
              any_left_after_v := true;
            end if;
          else
            if fifo_count(cur_win_v, lane) /= 0 then
              any_left_after_v := true;
            end if;
          end if;
        end if;
      end loop;

      read_sel_next <= selected_v;

      if found_any_v then
        read_plan_valid_next <= '1';
        if not any_left_after_v then
          read_plan_advance_next <= '1';
        end if;
      else
        -- completed window but no data stored in it
        read_plan_advance_next <= '1';
      end if;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- Execute one registered read plan. FIFO show-ahead data is captured on the
  -- same edge that acknowledges the planned pop.
  ----------------------------------------------------------------------------
  p_read_data_comb : process(all)
    variable out_v : out_array_t;
  begin
    out_v := (others => c_INVALID_HIT);

    for s in 0 to c_N_WINDOWS-1 loop
      for lane in 0 to g_LINK_N-1 loop
        if read_sel_r(s, lane) = '1' then
          out_v(lane) := fifo_dout(s, lane);
        end if;
      end loop;
    end loop;

    read_data_arr_next <= out_v;
    fifo_rd_en <= read_sel_r;
  end process;

  ----------------------------------------------------------------------------
  -- Sequential state update
  ----------------------------------------------------------------------------
  p_read_seq : process(i_clk)
    variable old_sub_v          : integer range 0 to c_N_WINDOWS-1;
    variable new_sub_v          : integer range 0 to c_N_WINDOWS-1;
    variable cur_rd_v           : integer range 0 to c_N_WINDOWS-1;
    variable wr_accept_v        : std_logic;
    variable rd_accept_v        : std_logic;
  begin
    if rising_edge(i_clk) then
      if state_reset_n /= '1' then
        out_data_arr_r          <= (others => c_INVALID_HIT);
        out_valid_r             <= '0';
        read_sel_r              <= (others => (others => '0'));
        read_plan_valid_r       <= '0';
        read_plan_advance_r     <= '0';
        cur_subtime_reading_win <= (others => '0');
        last_cur_subtime        <= (others => (others => '0'));
        subtime_changed         <= (others => (others => '0'));
        fifo_count              <= (others => (others => (others => '0')));
        word_cnt_u              <= (others => '0');
        fifo_full_cnt_u         <= (others => '0');

      else
        out_data_arr_r      <= read_data_arr_next;
        out_valid_r         <= read_plan_valid_r;
        read_sel_r          <= read_sel_next;
        read_plan_valid_r   <= read_plan_valid_next;
        read_plan_advance_r <= read_plan_advance_next;

        if o_valid_s = '1' then
          word_cnt_u <= word_cnt_u + 1;
        end if;

        -- Update local FIFO occupancy counters using accepted writes/reads.
        for s in 0 to c_N_WINDOWS-1 loop
          for l in 0 to g_LINK_N-1 loop
            wr_accept_v := fifo_wr_en(s, l) and (not fifo_full(s, l));
            rd_accept_v := fifo_rd_en(s, l) and (not fifo_empty(s, l));

            if (wr_accept_v = '1') and (rd_accept_v = '0') then
              fifo_count(s, l) <= fifo_count(s, l) + 1;
            elsif (wr_accept_v = '0') and (rd_accept_v = '1') then
              fifo_count(s, l) <= fifo_count(s, l) - 1;
            else
              fifo_count(s, l) <= fifo_count(s, l);
            end if;
          end loop;
        end loop;

        -- Count writes attempted into full FIFOs.
        for lane in 0 to g_LINK_N-1 loop
          if i_valid(lane) = '1' then
            new_sub_v := to_integer(unsigned(hit_subtime(lane)));
            if fifo_full(new_sub_v, lane) = '1' then
              fifo_full_cnt_u <= fifo_full_cnt_u + 1;
            end if;
          end if;
        end loop;

        -- Track external lane subtime progression independently of hits.
        for lane in 0 to g_LINK_N-1 loop
          if i_mask_n(lane) = '1' then
            old_sub_v := to_integer(unsigned(last_cur_subtime(lane)));
            new_sub_v := to_integer(unsigned(cur_subtime_ext(lane)));

            if last_cur_subtime(lane) /= cur_subtime_ext(lane) then
              -- Mark the OLD window complete for this lane.
              subtime_changed(old_sub_v)(lane) <= '1';
            end if;

            last_cur_subtime(lane) <= cur_subtime_ext(lane);
          end if;
        end loop;

        -- Advance the current read window after the registered read plan has
        -- executed and determined that this was the final beat for the window.
        cur_rd_v := to_integer(cur_subtime_reading_win);

        if read_plan_advance_r = '1' then
          subtime_changed(cur_rd_v) <= (others => '0');

          if cur_subtime_reading_win = to_unsigned(c_N_WINDOWS-1, g_N_SUBTIME_BITS) then
            cur_subtime_reading_win <= (others => '0');
          else
            cur_subtime_reading_win <= cur_subtime_reading_win + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- Pack outputs
  ----------------------------------------------------------------------------
  gen_pack : for i in 0 to g_LINK_N-1 generate
    out_data((i+1)*g_DATA_WIDTH-1 downto i*g_DATA_WIDTH) <= out_data_arr_r(i);
  end generate;

  o_valid         <= o_valid_s;
  o_word_cnt      <= std_logic_vector(word_cnt_u);
  o_fifo_full_cnt <= std_logic_vector(fifo_full_cnt_u);

  e_hit_compactor : entity work.hit_compactor
  generic map (
    g_WORD_WIDTH => g_DATA_WIDTH,
    g_WORDS_IN => g_LINK_N,
    g_WORDS_OUT => g_LINK_N--,
  )
  port map (
    i_data    => out_data,
    i_valid   => out_valid_r,

    o_data    => o_data,
    o_valid   => o_valid_s,

    i_reset_n => compactor_reset_n,
    i_clk     => i_clk--,
  );

  ----------------------------------------------------------------------------
  -- FIFO instances: one FIFO per (subtime window, lane)
  ----------------------------------------------------------------------------
  gen_fifo_sub : for s in 0 to c_N_WINDOWS-1 generate
    gen_fifo_lane : for l in 0 to g_LINK_N-1 generate
      u_fifo : entity work.ip_scfifo_v2
        generic map (
          g_ADDR_WIDTH => g_FIFO_ADDR_WIDTH,
          g_DATA_WIDTH => g_DATA_WIDTH,
          g_RREG_N => 1--,
        )
        port map (
          i_we      => fifo_wr_en(s, l),
          i_wdata   => fifo_din(s, l),
          o_wfull   => fifo_full(s, l),

          i_rack    => fifo_rd_en(s, l),
          o_rdata   => fifo_dout(s, l),
          o_rempty  => fifo_empty(s, l),

          i_clk     => i_clk,
          i_reset_n => fifo_reset_n(s, l)
        );
    end generate;
  end generate;

end architecture;

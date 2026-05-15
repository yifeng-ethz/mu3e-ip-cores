-- File name: coalescing_queue.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Mar 20, 2026
-- Revision: 1.1
--      Date: Apr 27, 2026
--      Change: Register the peak occupancy update from the previous
--              cycle's queue level. This keeps the max statistic exact
--              while removing the hit-bin decode from the timing path
--              into queue_level_max.
-- =========
-- Description:	[Queued post-divider coalescer for histogram bin updates]
--
--			Accepts single-increment hits from the bin_divider and coalesces
--			repeated hits to the same bin into a single (bin, count) pair.
--			A circular queue tracks which bins are "in-flight"; a per-bin
--			kick counter accumulates hits until the queue head is drained.
--			Reports queue occupancy, peak occupancy, and overflow count.
--

-- ================ synthsizer configuration ===================
-- altera vhdl_input_version vhdl_2008
-- =============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.histogram_statistics_v2_pkg.all;

entity coalescing_queue is
    generic (
        N_BINS          : natural := 256;
        QUEUE_DEPTH     : natural := 256;
        KICK_WIDTH      : natural := 8;
        OVERFLOW_WIDTH  : natural := 16
    );
    port (
        i_clk            : in  std_logic;
        i_rst            : in  std_logic;
        i_clear          : in  std_logic;
        i_hit_valid      : in  std_logic;
        i_hit_bin        : in  unsigned(clog2(N_BINS) - 1 downto 0);
        i_drain_ready    : in  std_logic;
        o_drain_valid    : out std_logic;
        o_drain_bin      : out unsigned(clog2(N_BINS) - 1 downto 0);
        o_drain_count    : out unsigned(KICK_WIDTH - 1 downto 0);
        o_occupancy      : out unsigned(clog2(QUEUE_DEPTH + 1) - 1 downto 0);
        o_occupancy_max  : out unsigned(clog2(QUEUE_DEPTH + 1) - 1 downto 0);
        o_overflow_count : out unsigned(OVERFLOW_WIDTH - 1 downto 0)
    );
end entity coalescing_queue;

architecture rtl of coalescing_queue is

    constant BIN_INDEX_WIDTH_CONST   : natural := clog2(N_BINS);
    constant QUEUE_ADDR_WIDTH_CONST  : natural := clog2(QUEUE_DEPTH);
    constant OCC_WIDTH_CONST         : natural := clog2(QUEUE_DEPTH + 1);

    subtype bin_index_t  is unsigned(BIN_INDEX_WIDTH_CONST - 1 downto 0);
    subtype kick_t       is unsigned(KICK_WIDTH - 1 downto 0);
    subtype occ_t        is unsigned(OCC_WIDTH_CONST - 1 downto 0);
    subtype queue_addr_t is unsigned(QUEUE_ADDR_WIDTH_CONST - 1 downto 0);
    constant KICK_MAX    : kick_t := (others => '1');

    type kick_ram_t  is array (0 to N_BINS - 1) of kick_t;
    type queued_t    is array (0 to N_BINS - 1) of std_logic;
    type queue_mem_t is array (0 to QUEUE_DEPTH - 1) of bin_index_t;

    signal kick_ram         : kick_ram_t  := (others => (others => '0'));
    signal queued           : queued_t    := (others => '0');
    signal queue_mem        : queue_mem_t := (others => (others => '0'));
    signal queue_rd_ptr     : queue_addr_t := (others => '0');
    signal queue_wr_ptr     : queue_addr_t := (others => '0');
    signal queue_level      : occ_t := (others => '0');
    signal queue_level_max  : occ_t := (others => '0');
    signal overflow_count_q : unsigned(OVERFLOW_WIDTH - 1 downto 0) := (others => '0');
    signal clear_active     : std_logic := '0';
    signal clear_index      : bin_index_t := (others => '0');
    signal queue_head_bin_q   : bin_index_t := (others => '0');
    signal queue_head_valid_q : std_logic := '0';
    signal drain_valid_q      : std_logic := '0';
    signal drain_bin_q        : bin_index_t := (others => '0');
    signal drain_count_q      : kick_t := (others => '0');
    signal drain_fire_c       : std_logic := '0';
    signal drain_head_bin_c   : bin_index_t := (others => '0');
    signal head_count_c       : kick_t := (others => '0');
    signal queue_room_c       : std_logic := '0';

    attribute ramstyle : string;
    attribute ramstyle of kick_ram : signal is "MLAB,no_rw_check";
    attribute ramstyle of queue_mem : signal is "MLAB,no_rw_check";

    function next_queue_ptr_f(ptr : queue_addr_t) return queue_addr_t is
    begin
        if to_integer(ptr) = QUEUE_DEPTH - 1 then
            return (others => '0');
        end if;
        return ptr + 1;
    end function next_queue_ptr_f;

begin

    o_drain_valid    <= drain_valid_q;
    o_drain_bin      <= drain_bin_q;
    o_drain_count    <= drain_count_q;
    o_occupancy      <= queue_level;
    o_occupancy_max  <= queue_level_max;
    o_overflow_count <= overflow_count_q;
    drain_fire_c <= '1' when (clear_active = '0') and (i_drain_ready = '1') and (queue_head_valid_q = '1') else '0';
    drain_head_bin_c <= queue_head_bin_q;
    head_count_c <= kick_ram(to_integer(queue_head_bin_q));
    queue_room_c <= '1' when (to_integer(queue_level) < QUEUE_DEPTH) or (drain_fire_c = '1') else '0';

    gen_kick_bins : for i in 0 to N_BINS - 1 generate
        constant BIN_INDEX_C : bin_index_t := to_unsigned(i, BIN_INDEX_WIDTH_CONST);
    begin
        bin_reg : process (i_clk)
            variable kick_next_v      : kick_t;
            variable queued_effective : std_logic;
            variable queued_next_v    : std_logic;
        begin
            if rising_edge(i_clk) then
                if (i_rst = '1') or (i_clear = '1') then
                    null;
                elsif clear_active = '1' then
                    if clear_index = BIN_INDEX_C then
                        kick_ram(i) <= (others => '0');
                        queued(i)   <= '0';
                    end if;
                else
                    kick_next_v      := kick_ram(i);
                    queued_next_v    := queued(i);
                    queued_effective := queued(i);

                    if (drain_fire_c = '1') and (drain_head_bin_c = BIN_INDEX_C) then
                        kick_next_v      := (others => '0');
                        queued_next_v    := '0';
                        queued_effective := '0';
                    end if;

                    if (i_hit_valid = '1') and (i_hit_bin = BIN_INDEX_C) then
                        if queued_effective = '1' then
                            if kick_ram(i) /= KICK_MAX then
                                kick_next_v := kick_ram(i) + 1;
                            end if;
                        elsif queue_room_c = '1' then
                            kick_next_v   := to_unsigned(1, KICK_WIDTH);
                            queued_next_v := '1';
                        end if;
                    end if;

                    kick_ram(i) <= kick_next_v;
                    queued(i)   <= queued_next_v;
                end if;
            end if;
        end process bin_reg;
    end generate gen_kick_bins;

    queue_reg : process (i_clk)
        variable clear_index_v    : natural;
        variable head_bin_v       : natural;
        variable hit_bin_v        : natural;
        variable level_v          : occ_t;
        variable overflow_v       : unsigned(OVERFLOW_WIDTH - 1 downto 0);
        variable queued_hit_v     : std_logic;
        variable rd_ptr_v         : queue_addr_t;
        variable wr_ptr_v         : queue_addr_t;
        variable next_head_bin_v   : bin_index_t;
        variable next_head_valid_v : std_logic;
    begin
        if rising_edge(i_clk) then
            drain_valid_q <= '0';

            if i_rst = '1' then
                queue_rd_ptr     <= (others => '0');
                queue_wr_ptr     <= (others => '0');
                queue_level      <= (others => '0');
                queue_level_max  <= (others => '0');
                overflow_count_q <= (others => '0');
                clear_active     <= '1';
                clear_index      <= (others => '0');
                queue_head_bin_q <= (others => '0');
                queue_head_valid_q <= '0';
                drain_bin_q      <= (others => '0');
                drain_count_q    <= (others => '0');
            elsif i_clear = '1' then
                queue_rd_ptr     <= (others => '0');
                queue_wr_ptr     <= (others => '0');
                queue_level      <= (others => '0');
                queue_level_max  <= (others => '0');
                overflow_count_q <= (others => '0');
                clear_active     <= '1';
                clear_index      <= (others => '0');
                queue_head_bin_q <= (others => '0');
                queue_head_valid_q <= '0';
                drain_bin_q      <= (others => '0');
                drain_count_q    <= (others => '0');
            elsif clear_active = '1' then
                clear_index_v := to_integer(clear_index);
                queue_head_bin_q <= (others => '0');
                queue_head_valid_q <= '0';

                if clear_index_v = N_BINS - 1 then
                    clear_active <= '0';
                    clear_index  <= (others => '0');
                else
                    clear_index <= to_unsigned(clear_index_v + 1, clear_index'length);
                end if;
            else
                head_bin_v   := 0;
                hit_bin_v    := 0;
                level_v      := queue_level;
                overflow_v   := overflow_count_q;
                rd_ptr_v     := queue_rd_ptr;
                wr_ptr_v     := queue_wr_ptr;
                next_head_bin_v := queue_head_bin_q;
                next_head_valid_v := queue_head_valid_q;
                drain_valid_q <= drain_fire_c;
                drain_bin_q   <= queue_head_bin_q;
                drain_count_q <= head_count_c;

                if (next_head_valid_v = '0') and (queue_level /= 0) then
                    next_head_bin_v   := queue_mem(to_integer(queue_rd_ptr));
                    next_head_valid_v := '1';
                end if;

                if drain_fire_c = '1' then
                    head_bin_v  := to_integer(queue_head_bin_q);

                    rd_ptr_v     := next_queue_ptr_f(rd_ptr_v);
                    level_v      := level_v - 1;

                    if queue_level > 1 then
                        next_head_bin_v := queue_mem(to_integer(rd_ptr_v));
                        next_head_valid_v := '1';
                    else
                        next_head_valid_v := '0';
                    end if;
                end if;

                if i_hit_valid = '1' then
                    hit_bin_v    := to_integer(i_hit_bin);
                    queued_hit_v := queued(hit_bin_v);

                    if (drain_fire_c = '1') and (head_bin_v = hit_bin_v) then
                        queued_hit_v := '0';
                    end if;

                    if queued_hit_v = '1' then
                        if kick_ram(hit_bin_v) = KICK_MAX then
                            overflow_v := sat_inc(overflow_v);
                        end if;
                    elsif queue_room_c = '1' then
                        queue_mem(to_integer(wr_ptr_v)) <= i_hit_bin;
                        wr_ptr_v := next_queue_ptr_f(wr_ptr_v);
                        level_v  := level_v + 1;
                    else
                        overflow_v := sat_inc(overflow_v);
                    end if;
                end if;

                queue_rd_ptr <= rd_ptr_v;
                queue_wr_ptr <= wr_ptr_v;
                queue_level  <= level_v;
                queue_head_bin_q <= next_head_bin_v;
                queue_head_valid_q <= next_head_valid_v;
                overflow_count_q <= overflow_v;

                if queue_level > queue_level_max then
                    queue_level_max <= queue_level;
                end if;
            end if;
        end if;
    end process queue_reg;

end architecture rtl;

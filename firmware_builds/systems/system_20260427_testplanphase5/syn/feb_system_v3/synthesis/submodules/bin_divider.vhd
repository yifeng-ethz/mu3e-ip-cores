-- File name: bin_divider.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Mar 20, 2026
-- =========
-- Description:	[Pipelined bin-index calculator for histogram_statistics_v2]
--
--			Computes bin_index = (key - left_bound) / bin_width with a
--			bounded-quotient restoring divider. The quotient only needs
--			BIN_INDEX_WIDTH bits, so the divide is spread across one range
--			check stage plus BIN_INDEX_WIDTH compare/subtract stages.
--			Reports underflow/overflow when the key falls outside
--			[left_bound, right_bound).
--

-- ================ synthsizer configuration ===================
-- altera vhdl_input_version vhdl_2008
-- =============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bin_divider is
    generic (
        TICK_WIDTH       : natural := 32;
        BIN_INDEX_WIDTH  : natural := 8;
        COUNT_WIDTH      : natural := 16
    );
    port (
        i_clk         : in  std_logic;
        i_rst         : in  std_logic;
        i_clear       : in  std_logic;
        i_valid       : in  std_logic;
        i_key         : in  signed(TICK_WIDTH - 1 downto 0);
        i_count       : in  unsigned(COUNT_WIDTH - 1 downto 0);
        i_left_bound  : in  signed(TICK_WIDTH - 1 downto 0);
        i_right_bound : in  signed(TICK_WIDTH - 1 downto 0);
        i_bin_width   : in  unsigned(TICK_WIDTH - 1 downto 0);
        o_valid       : out std_logic;
        o_underflow   : out std_logic;
        o_overflow    : out std_logic;
        o_bin_index   : out unsigned(BIN_INDEX_WIDTH - 1 downto 0);
        o_count       : out unsigned(COUNT_WIDTH - 1 downto 0)
    );
end entity bin_divider;

architecture rtl of bin_divider is

    constant QUOTIENT_STAGE_COUNT_CONST : natural := BIN_INDEX_WIDTH;
    constant EXT_WIDTH_CONST            : natural := TICK_WIDTH + BIN_INDEX_WIDTH;

    subtype ext_tick_t is unsigned(EXT_WIDTH_CONST - 1 downto 0);

    type count_array_t     is array (natural range <>) of unsigned(COUNT_WIDTH - 1 downto 0);
    type bin_index_array_t is array (natural range <>) of unsigned(BIN_INDEX_WIDTH - 1 downto 0);
    type ext_tick_array_t  is array (natural range <>) of ext_tick_t;

    signal valid_pipe      : std_logic_vector(0 to QUOTIENT_STAGE_COUNT_CONST) := (others => '0');
    signal underflow_pipe  : std_logic_vector(0 to QUOTIENT_STAGE_COUNT_CONST) := (others => '0');
    signal overflow_pipe   : std_logic_vector(0 to QUOTIENT_STAGE_COUNT_CONST) := (others => '0');
    signal count_pipe      : count_array_t(0 to QUOTIENT_STAGE_COUNT_CONST) := (others => (others => '0'));
    signal bin_index_pipe  : bin_index_array_t(0 to QUOTIENT_STAGE_COUNT_CONST) := (others => (others => '0'));
    signal remainder_pipe  : ext_tick_array_t(0 to QUOTIENT_STAGE_COUNT_CONST) := (others => (others => '0'));
    signal bin_width_pipe  : ext_tick_array_t(0 to QUOTIENT_STAGE_COUNT_CONST) := (others => (others => '0'));

begin

    o_valid     <= valid_pipe(QUOTIENT_STAGE_COUNT_CONST);
    o_underflow <= underflow_pipe(QUOTIENT_STAGE_COUNT_CONST);
    o_overflow  <= overflow_pipe(QUOTIENT_STAGE_COUNT_CONST);
    o_bin_index <= bin_index_pipe(QUOTIENT_STAGE_COUNT_CONST);
    o_count     <= count_pipe(QUOTIENT_STAGE_COUNT_CONST);

    divider_pipe : process (i_clk)
        variable delta_v         : unsigned(TICK_WIDTH - 1 downto 0);
        variable remainder_v     : ext_tick_t;
        variable shifted_width_v : ext_tick_t;
        variable bin_index_v     : unsigned(BIN_INDEX_WIDTH - 1 downto 0);
        variable bit_idx_v       : natural;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or i_clear = '1' then
                valid_pipe     <= (others => '0');
                underflow_pipe <= (others => '0');
                overflow_pipe  <= (others => '0');
                count_pipe     <= (others => (others => '0'));
                bin_index_pipe <= (others => (others => '0'));
                remainder_pipe <= (others => (others => '0'));
                bin_width_pipe <= (others => (others => '0'));
            else
                valid_pipe(0)     <= i_valid;
                underflow_pipe(0) <= '0';
                overflow_pipe(0)  <= '0';
                count_pipe(0)     <= i_count;
                bin_index_pipe(0) <= (others => '0');
                remainder_pipe(0) <= (others => '0');
                bin_width_pipe(0) <= (others => '0');

                if i_valid = '1' then
                    if i_key < i_left_bound then
                        underflow_pipe(0) <= '1';
                    elsif i_key >= i_right_bound then
                        overflow_pipe(0) <= '1';
                    elsif i_bin_width = (i_bin_width'range => '0') then
                        overflow_pipe(0) <= '1';
                    else
                        delta_v                      := unsigned(i_key) - unsigned(i_left_bound);
                        remainder_v                  := (others => '0');
                        remainder_v(TICK_WIDTH - 1 downto 0) := delta_v;
                        remainder_pipe(0)            <= remainder_v;
                        bin_width_pipe(0)            <= resize(i_bin_width, EXT_WIDTH_CONST);
                    end if;
                end if;

                for stage_idx in 0 to QUOTIENT_STAGE_COUNT_CONST - 1 loop
                    valid_pipe(stage_idx + 1)     <= valid_pipe(stage_idx);
                    underflow_pipe(stage_idx + 1) <= underflow_pipe(stage_idx);
                    overflow_pipe(stage_idx + 1)  <= overflow_pipe(stage_idx);
                    count_pipe(stage_idx + 1)     <= count_pipe(stage_idx);
                    bin_index_pipe(stage_idx + 1) <= bin_index_pipe(stage_idx);
                    remainder_pipe(stage_idx + 1) <= remainder_pipe(stage_idx);
                    bin_width_pipe(stage_idx + 1) <= bin_width_pipe(stage_idx);

                    if (valid_pipe(stage_idx) = '1')
                       and (underflow_pipe(stage_idx) = '0')
                       and (overflow_pipe(stage_idx) = '0') then
                        bit_idx_v       := (BIN_INDEX_WIDTH - 1) - stage_idx;
                        remainder_v     := remainder_pipe(stage_idx);
                        shifted_width_v := shift_left(bin_width_pipe(stage_idx), bit_idx_v);
                        bin_index_v     := bin_index_pipe(stage_idx);

                        if remainder_v >= shifted_width_v then
                            remainder_v         := remainder_v - shifted_width_v;
                            bin_index_v(bit_idx_v) := '1';
                        end if;

                        remainder_pipe(stage_idx + 1) <= remainder_v;
                        bin_index_pipe(stage_idx + 1) <= bin_index_v;
                    end if;
                end loop;
            end if;
        end if;
    end process divider_pipe;

end architecture rtl;

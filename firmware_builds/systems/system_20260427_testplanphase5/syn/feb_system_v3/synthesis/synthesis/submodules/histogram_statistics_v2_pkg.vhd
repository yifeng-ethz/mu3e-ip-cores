-- File name: histogram_statistics_v2_pkg.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Mar 20, 2026
-- =========
-- Description:	[Shared types and helper functions for histogram_statistics_v2]
--
--			Provides unconstrained array types (hs_slv_array_t, hs_unsigned_array_t),
--			ceiling-log2, boolean-to-std_logic conversion, saturating arithmetic,
--			and bit-field extraction utilities used by all v2 sub-modules.
--

-- ================ synthsizer configuration ===================
-- altera vhdl_input_version vhdl_2008
-- =============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package histogram_statistics_v2_pkg is

    constant HS_MAX_PORTS_CONST  : natural := 8;
    constant HS_MAX_DEBUG_CONST  : natural := 6;
    constant HS_COUNT_W_CONST    : natural := 32;
    constant HS_KICK_W_CONST     : natural := 16;

    type hs_slv_array_t is array (natural range <>) of std_logic_vector;
    type hs_unsigned_array_t is array (natural range <>) of unsigned;

    function clog2(value : positive) return natural;
    function bool_to_sl(flag : boolean) return std_logic;
    function sat_inc(value : unsigned) return unsigned;
    function sat_add(lhs : unsigned; rhs : unsigned) return unsigned;
    function extract_unsigned(
        data   : std_logic_vector;
        bit_hi : natural;
        bit_lo : natural
    ) return unsigned;
    function extract_signed(
        data   : std_logic_vector;
        bit_hi : natural;
        bit_lo : natural
    ) return signed;

end package histogram_statistics_v2_pkg;

package body histogram_statistics_v2_pkg is

    function clog2(value : positive) return natural is
        variable shifted_v : natural := value - 1;
        variable result_v  : natural := 0;
    begin
        while shifted_v > 0 loop
            shifted_v := shifted_v / 2;
            result_v  := result_v + 1;
        end loop;
        return result_v;
    end function clog2;

    function bool_to_sl(flag : boolean) return std_logic is
    begin
        if flag then
            return '1';
        end if;
        return '0';
    end function bool_to_sl;

    function sat_inc(value : unsigned) return unsigned is
        variable result_v : unsigned(value'range) := value;
    begin
        if value /= (value'range => '1') then
            result_v := value + 1;
        end if;
        return result_v;
    end function sat_inc;

    function sat_add(lhs : unsigned; rhs : unsigned) return unsigned is
        variable lhs_ext_v : unsigned(lhs'length downto 0);
        variable rhs_ext_v : unsigned(lhs'length downto 0);
        variable sum_v     : unsigned(lhs'length downto 0);
        variable result_v  : unsigned(lhs'range);
    begin
        lhs_ext_v := '0' & lhs;
        rhs_ext_v := resize(rhs, rhs_ext_v'length);
        sum_v     := lhs_ext_v + rhs_ext_v;
        if sum_v(sum_v'high) = '1' then
            result_v := (others => '1');
        else
            result_v := sum_v(result_v'range);
        end if;
        return result_v;
    end function sat_add;

    function extract_unsigned(
        data   : std_logic_vector;
        bit_hi : natural;
        bit_lo : natural
    ) return unsigned is
        variable result_v  : unsigned(data'range) := (others => '0');
        variable src_idx_v : natural;
    begin
        for dst_idx_v in result_v'range loop
            src_idx_v := dst_idx_v + bit_lo;
            if (dst_idx_v <= (bit_hi - bit_lo)) and (src_idx_v >= data'low) and (src_idx_v <= data'high) then
                result_v(dst_idx_v) := data(src_idx_v);
            end if;
        end loop;
        return result_v;
    end function extract_unsigned;

    function extract_signed(
        data   : std_logic_vector;
        bit_hi : natural;
        bit_lo : natural
    ) return signed is
        variable raw_v      : unsigned(data'range) := (others => '0');
        variable result_v   : signed(data'range);
        variable sign_bit_v : std_logic := '0';
        variable src_idx_v  : natural;
    begin
        if bit_hi <= data'high then
            sign_bit_v := data(bit_hi);
        end if;

        raw_v := (others => sign_bit_v);
        for dst_idx_v in raw_v'range loop
            src_idx_v := dst_idx_v + bit_lo;
            if (dst_idx_v <= (bit_hi - bit_lo)) and (src_idx_v >= data'low) and (src_idx_v <= data'high) then
                raw_v(dst_idx_v) := data(src_idx_v);
            end if;
        end loop;

        result_v := signed(raw_v);
        return result_v;
    end function extract_signed;

end package body histogram_statistics_v2_pkg;

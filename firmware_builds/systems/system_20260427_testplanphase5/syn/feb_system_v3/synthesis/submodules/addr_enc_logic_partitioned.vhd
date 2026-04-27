-- File name: addr_enc_logic_partitioned.vhd
-- Author: Codex
-- =======================================
-- Revision: 3.2 (flattened staged encoder)
--      Date: Mar 19, 2026
-- ================ synthsizer configuration ===================
-- altera vhdl_input_version vhdl_2008
-- ============================================================
-- Description:
--      Registered one-hot encoder for a large CAM partition.
--      The encoder only returns match-present, LSB address, and
--      whether more matches remain after the selected LSB hit.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity addr_enc_logic_partitioned is
generic(
    PARTITION_SIZE      : natural := 512;
    PARTITION_ADDR_BITS : natural := 9;
    LEAF_WIDTH          : natural := 16;
    PIPE_STAGES         : natural := 2
);
port(
    i_clk                       : in  std_logic;
    i_rst                       : in  std_logic;
    i_load                      : in  std_logic;
    i_advance                   : in  std_logic;
    i_cam_address_onehot        : in  std_logic_vector(PARTITION_SIZE-1 downto 0);
    o_result_valid              : out std_logic;
    o_cam_address_binary_lsb    : out std_logic_vector(PARTITION_ADDR_BITS-1 downto 0);
    o_cam_match_flag            : out std_logic;
    o_cam_has_more_matches      : out std_logic;
    o_cam_match_count           : out std_logic_vector(PARTITION_ADDR_BITS downto 0);
    o_cam_address_onehot_next   : out std_logic_vector(PARTITION_SIZE-1 downto 0);
    o_dbg_eval_match_stage0_valid : out std_logic
);
end entity addr_enc_logic_partitioned;

architecture rtl of addr_enc_logic_partitioned is

    function min_nat (
        lhs : natural;
        rhs : natural
    ) return natural is
    begin
        if (lhs < rhs) then
            return lhs;
        end if;
        return rhs;
    end function;

    function max_nat (
        lhs : natural;
        rhs : natural
    ) return natural is
    begin
        if (lhs > rhs) then
            return lhs;
        end if;
        return rhs;
    end function;

    function ceil_div (
        numer : natural;
        denom : natural
    ) return natural is
    begin
        return (numer + denom - 1) / denom;
    end function;

    function clear_onehot_bit (
        vec_v   : std_logic_vector;
        bit_idx : natural
    ) return std_logic_vector is
        variable next_v : std_logic_vector(vec_v'range);
    begin
        next_v := vec_v;
        if (bit_idx < vec_v'length) then
            next_v(bit_idx) := '0';
        end if;
        return next_v;
    end function;

    constant ACTIVE_PIPE_STAGES_CONST   : natural := min_nat(max_nat(PIPE_STAGES, 1), 4);
    constant EXTRA_VALID_STAGES_CONST   : natural := PIPE_STAGES - ACTIVE_PIPE_STAGES_CONST;
    constant EXTRA_VALID_VEC_LEN_CONST  : natural := max_nat(EXTRA_VALID_STAGES_CONST, 1);
    constant LEAF_SIZE_CONST            : natural := min_nat(max_nat(LEAF_WIDTH, 1), PARTITION_SIZE);
    constant N_LEAVES_CONST             : natural := ceil_div(PARTITION_SIZE, LEAF_SIZE_CONST);
    constant MID_GROUP_SIZE_CONST       : natural := 8;
    constant N_MIDS_CONST               : natural := ceil_div(N_LEAVES_CONST, MID_GROUP_SIZE_CONST);

    subtype part_addr_t       is unsigned(PARTITION_ADDR_BITS-1 downto 0);
    -- Only the active encoder datapath uses up to 4 pipeline-valid bits.
    -- Wider PIPE_STAGES are handled by result_valid_extra, and low-stage
    -- builds must not index beyond the physical valid vector width.
    subtype pipe_valid_t      is std_logic_vector(3 downto 0);
    subtype extra_valid_t     is std_logic_vector(EXTRA_VALID_VEC_LEN_CONST-1 downto 0);

    type part_addr_arr_t is array (natural range <>) of part_addr_t;

    signal start_eval                 : std_logic;
    signal active_match_vec           : std_logic_vector(PARTITION_SIZE-1 downto 0);
    signal eval_match_vec             : std_logic_vector(PARTITION_SIZE-1 downto 0);
    signal leaf_match_vec             : std_logic_vector(PARTITION_SIZE-1 downto 0);
    signal pipe_valid                 : pipe_valid_t;
    signal eval_match_stage0          : std_logic_vector(PARTITION_SIZE-1 downto 0);
    signal leaf_flag_comb             : std_logic_vector(N_LEAVES_CONST-1 downto 0);
    signal leaf_flag_reg              : std_logic_vector(N_LEAVES_CONST-1 downto 0);
    signal leaf_has_more_comb         : std_logic_vector(N_LEAVES_CONST-1 downto 0);
    signal leaf_has_more_reg          : std_logic_vector(N_LEAVES_CONST-1 downto 0);
    signal leaf_lsb_addr_comb         : part_addr_arr_t(0 to N_LEAVES_CONST-1);
    signal leaf_lsb_addr_reg          : part_addr_arr_t(0 to N_LEAVES_CONST-1);
    signal mid_flag_comb              : std_logic_vector(N_MIDS_CONST-1 downto 0);
    signal mid_flag_reg               : std_logic_vector(N_MIDS_CONST-1 downto 0);
    signal mid_has_more_comb          : std_logic_vector(N_MIDS_CONST-1 downto 0);
    signal mid_has_more_reg           : std_logic_vector(N_MIDS_CONST-1 downto 0);
    signal mid_lsb_addr_comb          : part_addr_arr_t(0 to N_MIDS_CONST-1);
    signal mid_lsb_addr_reg           : part_addr_arr_t(0 to N_MIDS_CONST-1);
    signal result_stage1_flag_comb    : std_logic;
    signal result_stage1_has_more_comb: std_logic;
    signal result_stage1_lsb_comb     : part_addr_t;
    signal result_stage2_flag_comb    : std_logic;
    signal result_stage2_has_more_comb: std_logic;
    signal result_stage2_lsb_comb     : part_addr_t;
    signal result_stage3_flag_comb    : std_logic;
    signal result_stage3_has_more_comb: std_logic;
    signal result_stage3_lsb_comb     : part_addr_t;
    signal result_flag_reg            : std_logic;
    signal result_has_more_reg        : std_logic;
    signal result_lsb_reg             : part_addr_t;
    signal result_valid_reg           : std_logic;
    signal result_valid_extra         : extra_valid_t;

begin

    assert PIPE_STAGES >= 1
        report "addr_enc_logic_partitioned requires PIPE_STAGES >= 1"
        severity failure;

    start_eval <= i_load or
                  (i_advance and result_valid_reg and result_flag_reg and result_has_more_reg);

    eval_match_vec <= i_cam_address_onehot when i_load = '1' else
                      clear_onehot_bit(active_match_vec, to_integer(result_lsb_reg))
                      when (i_advance = '1' and result_valid_reg = '1' and result_flag_reg = '1') else
                      active_match_vec;

    leaf_match_vec <= eval_match_stage0 when ACTIVE_PIPE_STAGES_CONST = 4 else eval_match_vec;

    proc_leaf_comb : process (all)
        variable flag_v       : std_logic_vector(N_LEAVES_CONST-1 downto 0);
        variable more_v       : std_logic_vector(N_LEAVES_CONST-1 downto 0);
        variable addr_v       : part_addr_arr_t(0 to N_LEAVES_CONST-1);
        variable src_idx_v    : natural;
        variable first_seen_v : boolean;
    begin
        flag_v := (others => '0');
        more_v := (others => '0');
        addr_v := (others => (others => '0'));

        for leaf_idx in 0 to N_LEAVES_CONST-1 loop
            first_seen_v := false;
            for bit_idx in 0 to LEAF_SIZE_CONST-1 loop
                src_idx_v := leaf_idx * LEAF_SIZE_CONST + bit_idx;
                if (src_idx_v < PARTITION_SIZE and leaf_match_vec(src_idx_v) = '1') then
                    if (first_seen_v = false) then
                        flag_v(leaf_idx) := '1';
                        addr_v(leaf_idx) := to_unsigned(src_idx_v, PARTITION_ADDR_BITS);
                        first_seen_v     := true;
                    else
                        more_v(leaf_idx) := '1';
                        exit;
                    end if;
                end if;
            end loop;
        end loop;

        leaf_flag_comb     <= flag_v;
        leaf_has_more_comb <= more_v;
        leaf_lsb_addr_comb <= addr_v;
    end process;

    proc_mid_comb : process (all)
        variable flag_v     : std_logic_vector(N_MIDS_CONST-1 downto 0);
        variable more_v     : std_logic_vector(N_MIDS_CONST-1 downto 0);
        variable addr_v     : part_addr_arr_t(0 to N_MIDS_CONST-1);
        variable leaf_idx_v : natural;
        variable found_v    : boolean;
    begin
        flag_v := (others => '0');
        more_v := (others => '0');
        addr_v := (others => (others => '0'));

        for mid_idx in 0 to N_MIDS_CONST-1 loop
            found_v := false;
            for grp_idx in 0 to MID_GROUP_SIZE_CONST-1 loop
                leaf_idx_v := mid_idx * MID_GROUP_SIZE_CONST + grp_idx;
                if (leaf_idx_v < N_LEAVES_CONST and leaf_flag_reg(leaf_idx_v) = '1') then
                    if (found_v = false) then
                        flag_v(mid_idx) := '1';
                        more_v(mid_idx) := leaf_has_more_reg(leaf_idx_v);
                        addr_v(mid_idx) := leaf_lsb_addr_reg(leaf_idx_v);
                        found_v         := true;
                    else
                        more_v(mid_idx) := '1';
                        exit;
                    end if;
                end if;
            end loop;
        end loop;

        mid_flag_comb     <= flag_v;
        mid_has_more_comb <= more_v;
        mid_lsb_addr_comb <= addr_v;
    end process;

    proc_result_stage1 : process (all)
        variable result_flag_v : std_logic;
        variable result_more_v : std_logic;
        variable result_addr_v : part_addr_t;
    begin
        result_flag_v := '0';
        result_more_v := '0';
        result_addr_v := (others => '0');

        for leaf_idx in 0 to N_LEAVES_CONST-1 loop
            if (leaf_flag_comb(leaf_idx) = '1') then
                if (result_flag_v = '0') then
                    result_flag_v := '1';
                    result_more_v := leaf_has_more_comb(leaf_idx);
                    result_addr_v := leaf_lsb_addr_comb(leaf_idx);
                else
                    result_more_v := '1';
                    exit;
                end if;
            end if;
        end loop;

        result_stage1_flag_comb     <= result_flag_v;
        result_stage1_has_more_comb <= result_more_v;
        result_stage1_lsb_comb      <= result_addr_v;
    end process;

    proc_result_stage2 : process (all)
        variable result_flag_v : std_logic;
        variable result_more_v : std_logic;
        variable result_addr_v : part_addr_t;
    begin
        result_flag_v := '0';
        result_more_v := '0';
        result_addr_v := (others => '0');

        for mid_idx in 0 to N_MIDS_CONST-1 loop
            if (mid_flag_comb(mid_idx) = '1') then
                if (result_flag_v = '0') then
                    result_flag_v := '1';
                    result_more_v := mid_has_more_comb(mid_idx);
                    result_addr_v := mid_lsb_addr_comb(mid_idx);
                else
                    result_more_v := '1';
                    exit;
                end if;
            end if;
        end loop;

        result_stage2_flag_comb     <= result_flag_v;
        result_stage2_has_more_comb <= result_more_v;
        result_stage2_lsb_comb      <= result_addr_v;
    end process;

    proc_result_stage3 : process (all)
        variable result_flag_v : std_logic;
        variable result_more_v : std_logic;
        variable result_addr_v : part_addr_t;
    begin
        result_flag_v := '0';
        result_more_v := '0';
        result_addr_v := (others => '0');

        for mid_idx in 0 to N_MIDS_CONST-1 loop
            if (mid_flag_reg(mid_idx) = '1') then
                if (result_flag_v = '0') then
                    result_flag_v := '1';
                    result_more_v := mid_has_more_reg(mid_idx);
                    result_addr_v := mid_lsb_addr_reg(mid_idx);
                else
                    result_more_v := '1';
                    exit;
                end if;
            end if;
        end loop;

        result_stage3_flag_comb     <= result_flag_v;
        result_stage3_has_more_comb <= result_more_v;
        result_stage3_lsb_comb      <= result_addr_v;
    end process;

    proc_pipe : process (i_clk, i_rst)
        variable pipe_valid_v      : pipe_valid_t;
        variable result_done_v     : std_logic;
    begin
        if (i_rst = '1') then
            active_match_vec     <= (others => '0');
            pipe_valid          <= (others => '0');
            eval_match_stage0   <= (others => '0');
            leaf_flag_reg       <= (others => '0');
            leaf_has_more_reg   <= (others => '0');
            leaf_lsb_addr_reg   <= (others => (others => '0'));
            mid_flag_reg        <= (others => '0');
            mid_has_more_reg    <= (others => '0');
            mid_lsb_addr_reg    <= (others => (others => '0'));
            result_flag_reg     <= '0';
            result_has_more_reg <= '0';
            result_lsb_reg      <= (others => '0');
            result_valid_reg    <= '0';
            result_valid_extra  <= (others => '0');
        elsif (rising_edge(i_clk)) then
            pipe_valid_v  := (others => '0');
            result_done_v := '0';

            eval_match_stage0 <= eval_match_stage0;
            mid_flag_reg      <= mid_flag_reg;
            mid_has_more_reg  <= mid_has_more_reg;
            mid_lsb_addr_reg  <= mid_lsb_addr_reg;

            if (ACTIVE_PIPE_STAGES_CONST > 1) then
                pipe_valid_v(ACTIVE_PIPE_STAGES_CONST-1 downto 1)
                    := pipe_valid(ACTIVE_PIPE_STAGES_CONST-2 downto 0);
            end if;
            pipe_valid_v(0) := start_eval;

            if (start_eval = '1') then
                active_match_vec <= eval_match_vec;
                if (ACTIVE_PIPE_STAGES_CONST = 1) then
                    result_flag_reg     <= result_stage1_flag_comb;
                    result_has_more_reg <= result_stage1_has_more_comb;
                    result_lsb_reg      <= result_stage1_lsb_comb;
                elsif (ACTIVE_PIPE_STAGES_CONST = 4) then
                    eval_match_stage0   <= eval_match_vec;
                else
                    leaf_flag_reg     <= leaf_flag_comb;
                    leaf_has_more_reg <= leaf_has_more_comb;
                    leaf_lsb_addr_reg <= leaf_lsb_addr_comb;
                end if;
            end if;

            if (ACTIVE_PIPE_STAGES_CONST = 2 and pipe_valid(0) = '1') then
                result_flag_reg     <= result_stage2_flag_comb;
                result_has_more_reg <= result_stage2_has_more_comb;
                result_lsb_reg      <= result_stage2_lsb_comb;
                result_done_v       := '1';
            elsif (ACTIVE_PIPE_STAGES_CONST = 3) then
                if (pipe_valid(0) = '1') then
                    mid_flag_reg     <= mid_flag_comb;
                    mid_has_more_reg <= mid_has_more_comb;
                    mid_lsb_addr_reg <= mid_lsb_addr_comb;
                end if;
                if (pipe_valid(1) = '1') then
                    result_flag_reg     <= result_stage3_flag_comb;
                    result_has_more_reg <= result_stage3_has_more_comb;
                    result_lsb_reg      <= result_stage3_lsb_comb;
                    result_done_v       := '1';
                end if;
            elsif (ACTIVE_PIPE_STAGES_CONST = 4) then
                if (pipe_valid(0) = '1') then
                    leaf_flag_reg     <= leaf_flag_comb;
                    leaf_has_more_reg <= leaf_has_more_comb;
                    leaf_lsb_addr_reg <= leaf_lsb_addr_comb;
                end if;
                if (pipe_valid(1) = '1') then
                    mid_flag_reg     <= mid_flag_comb;
                    mid_has_more_reg <= mid_has_more_comb;
                    mid_lsb_addr_reg <= mid_lsb_addr_comb;
                end if;
                if (pipe_valid(2) = '1') then
                    result_flag_reg     <= result_stage3_flag_comb;
                    result_has_more_reg <= result_stage3_has_more_comb;
                    result_lsb_reg      <= result_stage3_lsb_comb;
                    result_done_v       := '1';
                end if;
            elsif (ACTIVE_PIPE_STAGES_CONST = 1 and pipe_valid(0) = '1') then
                result_done_v := '1';
            end if;

            if (start_eval = '1') then
                result_valid_reg <= '0';
            elsif (EXTRA_VALID_STAGES_CONST = 0) then
                if (result_done_v = '1') then
                    result_valid_reg <= '1';
                end if;
            elsif (result_valid_extra(EXTRA_VALID_STAGES_CONST-1) = '1') then
                result_valid_reg <= '1';
            end if;

            if (EXTRA_VALID_STAGES_CONST > 0) then
                if (EXTRA_VALID_STAGES_CONST > 1) then
                    result_valid_extra(EXTRA_VALID_STAGES_CONST-1 downto 1)
                        <= result_valid_extra(EXTRA_VALID_STAGES_CONST-2 downto 0);
                end if;
                result_valid_extra(0) <= result_done_v;
            else
                result_valid_extra <= (others => '0');
            end if;

            pipe_valid <= pipe_valid_v;
        end if;
    end process;

    o_result_valid            <= result_valid_reg;
    o_cam_address_binary_lsb  <= std_logic_vector(result_lsb_reg);
    o_cam_match_flag          <= result_flag_reg;
    o_cam_has_more_matches    <= result_has_more_reg;
    o_cam_match_count         <= std_logic_vector(to_unsigned(1, o_cam_match_count'length))
                                 when result_flag_reg = '1' else
                                 (others => '0');
    o_cam_address_onehot_next <= active_match_vec;
    o_dbg_eval_match_stage0_valid <= '1'
                                     when ACTIVE_PIPE_STAGES_CONST = 4 and
                                          eval_match_stage0 /= (eval_match_stage0'range => '0')
                                     else '0';

end architecture rtl;

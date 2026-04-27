-- File name: mutrig_injector_multiheader.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Version: 3.3 (Jul 24, 2025)
-- =======================================
-- Description:
--   MuTRiG injector variant that monitors all 8 header streams directly.
--   The existing CSR header selector keeps the same meaning: select which
--   MuTRiG header channel triggers header-synchronous injection.

-- altera vhdl_input_version vhdl_2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mutrig_injector_multiheader is
generic(
    MIN_PULSE_W          : natural := 5;
    CLK_FREQUENCY        : natural := 125000000;
    ASYNC_CLK_FREQUENCY  : natural := 50000000;
    HEADERINFO_CHANNEL_W : natural := 4;
    DEBUG                : natural := 1
);
port (
    -- AVMM <csr>
    avs_csr_writedata        : in  std_logic_vector(31 downto 0);
    avs_csr_readdata         : out std_logic_vector(31 downto 0);
    avs_csr_read             : in  std_logic;
    avs_csr_write            : in  std_logic;
    avs_csr_waitrequest      : out std_logic;
    avs_csr_address          : in  std_logic_vector(3 downto 0);

    -- AVST <runctl>
    asi_runctl_data          : in  std_logic_vector(8 downto 0);
    asi_runctl_valid         : in  std_logic;
    asi_runctl_ready         : out std_logic;

    -- AVST <headerinfo0>
    asi_headerinfo0_data     : in  std_logic_vector(41 downto 0);
    asi_headerinfo0_valid    : in  std_logic;
    asi_headerinfo0_channel  : in  std_logic_vector(HEADERINFO_CHANNEL_W-1 downto 0);

    -- AVST <headerinfo1>
    asi_headerinfo1_data     : in  std_logic_vector(41 downto 0);
    asi_headerinfo1_valid    : in  std_logic;
    asi_headerinfo1_channel  : in  std_logic_vector(HEADERINFO_CHANNEL_W-1 downto 0);

    -- AVST <headerinfo2>
    asi_headerinfo2_data     : in  std_logic_vector(41 downto 0);
    asi_headerinfo2_valid    : in  std_logic;
    asi_headerinfo2_channel  : in  std_logic_vector(HEADERINFO_CHANNEL_W-1 downto 0);

    -- AVST <headerinfo3>
    asi_headerinfo3_data     : in  std_logic_vector(41 downto 0);
    asi_headerinfo3_valid    : in  std_logic;
    asi_headerinfo3_channel  : in  std_logic_vector(HEADERINFO_CHANNEL_W-1 downto 0);

    -- AVST <headerinfo4>
    asi_headerinfo4_data     : in  std_logic_vector(41 downto 0);
    asi_headerinfo4_valid    : in  std_logic;
    asi_headerinfo4_channel  : in  std_logic_vector(HEADERINFO_CHANNEL_W-1 downto 0);

    -- AVST <headerinfo5>
    asi_headerinfo5_data     : in  std_logic_vector(41 downto 0);
    asi_headerinfo5_valid    : in  std_logic;
    asi_headerinfo5_channel  : in  std_logic_vector(HEADERINFO_CHANNEL_W-1 downto 0);

    -- AVST <headerinfo6>
    asi_headerinfo6_data     : in  std_logic_vector(41 downto 0);
    asi_headerinfo6_valid    : in  std_logic;
    asi_headerinfo6_channel  : in  std_logic_vector(HEADERINFO_CHANNEL_W-1 downto 0);

    -- AVST <headerinfo7>
    asi_headerinfo7_data     : in  std_logic_vector(41 downto 0);
    asi_headerinfo7_valid    : in  std_logic;
    asi_headerinfo7_channel  : in  std_logic_vector(HEADERINFO_CHANNEL_W-1 downto 0);

    -- CONDUIT <inject>
    coe_inject_pulse         : out std_logic;

    -- clock and reset interface
    i_clk                    : in  std_logic;
    i_osc_clk                : in  std_logic := '0';
    i_rst                    : in  std_logic
);
end entity;

architecture rtl of mutrig_injector_multiheader is

    constant DEFAULT_HEADER_DELAY_CONST           : integer := 100;
    constant DEFAULT_HEADER_INTERVAL_CONST        : integer := 1;
    constant DEFAULT_INJECTION_MULTIPLICITY_CONST : integer := 1;
    constant DEFAULT_HEADER_CH_CONST              : integer := 0;
    constant DEFAULT_PULSE_INTERVAL_CONST         : integer := 1000;
    constant DEFAULT_PULSE_HIGH_CYCLES_CONST      : integer := 5;
    constant DEFAULT_PRBS_RATE_CONST              : integer := 999;
    constant DEFAULT_PRBS_PATTERN_CONST           : std_logic_vector(31 downto 0) := x"00000001";
    constant DEFAULT_PRBS_SEED_CONST              : std_logic_vector(31 downto 0) := x"0000ACE1";
    -- PRBS_CTRL[1:0] selects PRBS7/15/23/31, PRBS_CTRL[7:2] stores match width.
    constant DEFAULT_PRBS_CTRL_CONST              : std_logic_vector(31 downto 0) := x"00000004";
    constant CSR_GENERAL_REG_BITS_CONST           : natural := 32;
    constant MIN_PULSE_CYCLES_CONST               : integer := 5;

    type header_channel_array_t is array (natural range <>) of std_logic_vector(HEADERINFO_CHANNEL_W-1 downto 0);

    type csr_t is record
        mode                   : std_logic_vector(3 downto 0);
        header_delay           : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0);
        header_interval        : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0);
        injection_multiplicity : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0);
        header_ch              : std_logic_vector(HEADERINFO_CHANNEL_W-1 downto 0);
        pulse_interval         : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0);
        pulse_high_cycles      : std_logic_vector(7 downto 0);
        prbs_rate              : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0);
        prbs_pattern           : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0);
        prbs_seed              : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0);
        prbs_ctrl              : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0);
    end record;

    type header_injector_state_t is (IDLE, DELAYING, INJECTING, WAITING_LOW, RESETTING);
    type periodic_injector_state_t is (INJECTING, WAITING_LOW, IDLING, RESETTING);

    constant CSR_DEF_CONST : csr_t := (
        mode                   => (others => '0'),
        header_delay           => std_logic_vector(to_unsigned(DEFAULT_HEADER_DELAY_CONST, CSR_GENERAL_REG_BITS_CONST)),
        header_interval        => std_logic_vector(to_unsigned(DEFAULT_HEADER_INTERVAL_CONST, CSR_GENERAL_REG_BITS_CONST)),
        injection_multiplicity => std_logic_vector(to_unsigned(DEFAULT_INJECTION_MULTIPLICITY_CONST, CSR_GENERAL_REG_BITS_CONST)),
        header_ch              => std_logic_vector(to_unsigned(DEFAULT_HEADER_CH_CONST, HEADERINFO_CHANNEL_W)),
        pulse_interval         => std_logic_vector(to_unsigned(DEFAULT_PULSE_INTERVAL_CONST, CSR_GENERAL_REG_BITS_CONST)),
        pulse_high_cycles      => std_logic_vector(to_unsigned(DEFAULT_PULSE_HIGH_CYCLES_CONST, 8)),
        prbs_rate              => std_logic_vector(to_unsigned(DEFAULT_PRBS_RATE_CONST, CSR_GENERAL_REG_BITS_CONST)),
        prbs_pattern           => DEFAULT_PRBS_PATTERN_CONST,
        prbs_seed              => DEFAULT_PRBS_SEED_CONST,
        prbs_ctrl              => DEFAULT_PRBS_CTRL_CONST
    );

    function gcd(
        lhs_v : natural;
        rhs_v : natural
    ) return natural is
        variable a_v : natural := lhs_v;
        variable b_v : natural := rhs_v;
        variable t_v : natural := 0;
    begin
        while b_v /= 0 loop
            t_v := a_v mod b_v;
            a_v := b_v;
            b_v := t_v;
        end loop;
        return a_v;
    end function;

    function ceil_div(
        num_v : natural;
        den_v : natural
    ) return natural is
    begin
        if den_v = 0 then
            return 0;
        end if;
        return (num_v + den_v - 1) / den_v;
    end function;

    constant ASYNC_SCALE_GCD_CONST       : natural := gcd(CLK_FREQUENCY, ASYNC_CLK_FREQUENCY);
    constant ASYNC_SCALE_NUM_CONST       : natural := ASYNC_CLK_FREQUENCY / ASYNC_SCALE_GCD_CONST;
    constant ASYNC_SCALE_DEN_CONST       : natural := CLK_FREQUENCY / ASYNC_SCALE_GCD_CONST;
    constant ASYNC_SCALE_SHIFT_CONST     : natural := 7;
    constant ASYNC_SCALE_FIXED_NUM_CONST : natural := (ASYNC_SCALE_NUM_CONST * (2 ** ASYNC_SCALE_SHIFT_CONST) + (ASYNC_SCALE_DEN_CONST / 2)) / ASYNC_SCALE_DEN_CONST;

    function scale_async_cycles(
        cycles_v     : natural;
        min_cycles_v : natural
    ) return natural is
        variable scaled_cycles_v : natural := 0;
    begin
        if cycles_v = 0 then
            return 0;
        end if;

        scaled_cycles_v := (cycles_v * ASYNC_SCALE_NUM_CONST + (ASYNC_SCALE_DEN_CONST / 2)) / ASYNC_SCALE_DEN_CONST;
        if scaled_cycles_v < min_cycles_v then
            scaled_cycles_v := min_cycles_v;
        end if;

        return scaled_cycles_v;
    end function;

    -- Runtime mode-3 scaling is intentionally implemented as a fixed-point
    -- multiply-and-shift so the CSR domain precompute path does not infer
    -- divider megafunctions.
    function scale_async_cycles_runtime(
        cycles_v     : unsigned;
        min_cycles_v : natural
    ) return unsigned is
        variable cycles_ext_v : unsigned(cycles_v'length + ASYNC_SCALE_SHIFT_CONST downto 0) := (others => '0');
        variable scaled_acc_v : unsigned(cycles_v'length + ASYNC_SCALE_SHIFT_CONST downto 0) := (others => '0');
        variable scaled_value_v : unsigned(cycles_v'range) := (others => '0');
    begin
        if cycles_v /= 0 then
            cycles_ext_v := resize(cycles_v, cycles_ext_v'length);
            for bit_i in 0 to ASYNC_SCALE_SHIFT_CONST loop
                if ((ASYNC_SCALE_FIXED_NUM_CONST / (2 ** bit_i)) mod 2) = 1 then
                    scaled_acc_v := scaled_acc_v + shift_left(cycles_ext_v, bit_i);
                end if;
            end loop;
            if ASYNC_SCALE_SHIFT_CONST > 0 then
                scaled_acc_v := scaled_acc_v + to_unsigned(2 ** (ASYNC_SCALE_SHIFT_CONST - 1), scaled_acc_v'length);
            end if;
            scaled_value_v := resize(shift_right(scaled_acc_v, ASYNC_SCALE_SHIFT_CONST), scaled_value_v'length);
            if scaled_value_v < to_unsigned(min_cycles_v, scaled_value_v'length) then
                scaled_value_v := to_unsigned(min_cycles_v, scaled_value_v'length);
            end if;
        end if;

        return scaled_value_v;
    end function;

    constant ASYNC_MIN_PULSE_CYCLES_CONST      : natural := scale_async_cycles(MIN_PULSE_CYCLES_CONST, 1);
    constant ASYNC_DEFAULT_INTERVAL_CONST      : unsigned(CSR_GENERAL_REG_BITS_CONST-1 downto 0) := to_unsigned(scale_async_cycles(to_integer(unsigned(CSR_DEF_CONST.pulse_interval)), 1), CSR_GENERAL_REG_BITS_CONST);
    constant ASYNC_DEFAULT_HIGH_CYCLES_CONST   : unsigned(7 downto 0) := to_unsigned(scale_async_cycles(to_integer(unsigned(CSR_DEF_CONST.pulse_high_cycles)), 1), 8);
    constant ASYNC_CFG_STRETCH_CYCLES_CONST    : natural := ceil_div(CLK_FREQUENCY, ASYNC_CLK_FREQUENCY) + 2;

    function any_header_match(
        valid_v            : std_logic_vector;
        channel_v          : header_channel_array_t;
        selected_channel_v : std_logic_vector
    ) return std_logic is
        variable match_v : std_logic := '0';
    begin
        for i in valid_v'range loop
            if valid_v(i) = '1' and channel_v(i) = selected_channel_v then
                match_v := '1';
            end if;
        end loop;
        return match_v;
    end function;

    function prbs_width(
        ctrl_v : std_logic_vector(1 downto 0)
    ) return natural is
    begin
        case ctrl_v is
            when "00" =>
                return 7;
            when "01" =>
                return 15;
            when "10" =>
                return 23;
            when others =>
                return 31;
        end case;
    end function;

    function prbs_match_width(
        ctrl_v : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0)
    ) return natural is
        variable match_width_v : natural := to_integer(unsigned(ctrl_v(7 downto 2)));
        variable lfsr_width_v  : natural := prbs_width(ctrl_v(1 downto 0));
    begin
        if match_width_v = 0 then
            match_width_v := 1;
        elsif match_width_v > lfsr_width_v then
            match_width_v := lfsr_width_v;
        end if;

        return match_width_v;
    end function;

    function sanitize_prbs_state(
        seed_v : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0);
        ctrl_v : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0)
    ) return std_logic_vector is
        variable sanitized_v : std_logic_vector(30 downto 0) := seed_v(30 downto 0);
        variable width_v     : natural := prbs_width(ctrl_v(1 downto 0));
        variable zero_v      : std_logic := '1';
    begin
        for i in sanitized_v'range loop
            if i >= width_v then
                sanitized_v(i) := '0';
            elsif sanitized_v(i) = '1' then
                zero_v := '0';
            end if;
        end loop;

        if zero_v = '1' then
            sanitized_v := (others => '0');
            sanitized_v(0) := '1';
        end if;

        return sanitized_v;
    end function;

    function prbs_next_state(
        state_v : std_logic_vector(30 downto 0);
        ctrl_v  : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0)
    ) return std_logic_vector is
        variable next_v     : std_logic_vector(state_v'range) := state_v;
        variable width_v    : natural := prbs_width(ctrl_v(1 downto 0));
        variable feedback_v : std_logic := '0';
    begin
        case ctrl_v(1 downto 0) is
            when "00" =>
                feedback_v := state_v(6) xor state_v(5);   -- PRBS7: x^7 + x^6 + 1
            when "01" =>
                feedback_v := state_v(14) xor state_v(13); -- PRBS15: x^15 + x^14 + 1
            when "10" =>
                feedback_v := state_v(22) xor state_v(17); -- PRBS23: x^23 + x^18 + 1
            when others =>
                feedback_v := state_v(30) xor state_v(27); -- PRBS31: x^31 + x^28 + 1
        end case;

        next_v := (others => '0');
        next_v(0) := feedback_v;
        for i in 1 to next_v'high loop
            if i < width_v then
                next_v(i) := state_v(i-1);
            end if;
        end loop;

        return next_v;
    end function;

    function prbs_pattern_match(
        state_v   : std_logic_vector(30 downto 0);
        pattern_v : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0);
        ctrl_v    : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0)
    ) return std_logic is
        variable match_v       : std_logic := '1';
        variable match_width_v : natural := prbs_match_width(ctrl_v);
    begin
        for i in state_v'range loop
            if i < match_width_v and state_v(i) /= pattern_v(i) then
                match_v := '0';
            end if;
        end loop;

        return match_v;
    end function;

    signal csr                     : csr_t := CSR_DEF_CONST;
    signal header_injector         : header_injector_state_t := RESETTING;
    signal periodic_injector       : periodic_injector_state_t := RESETTING;
    signal periodic_async_injector : periodic_injector_state_t := RESETTING;
    signal random_injector         : periodic_injector_state_t := RESETTING;

    signal header_injector_hcnt      : unsigned(15 downto 0) := (others => '0');
    signal header_injector_delay     : unsigned(15 downto 0) := (others => '0');
    signal header_injector_icnt      : unsigned(7 downto 0)  := (others => '0');
    signal header_injector_pcnt      : unsigned(15 downto 0) := (others => '0');
    signal header_injector_idle_cnt  : unsigned(7 downto 0)  := (others => '0');
    signal header_injector_pulse     : std_logic := '0';

    signal periodic_injector_i_cnt   : unsigned(31 downto 0) := (others => '0');
    signal periodic_injector_j_cnt   : unsigned(7 downto 0)  := (others => '0');
    signal periodic_injector_pulse   : std_logic := '0';
    signal periodic_async_i_cnt      : unsigned(31 downto 0) := (others => '0');
    signal periodic_async_j_cnt      : unsigned(7 downto 0)  := (others => '0');
    signal periodic_async_pulse      : std_logic := '0';
    signal periodic_async_mode              : std_logic_vector(3 downto 0) := CSR_DEF_CONST.mode;
    signal periodic_async_interval          : unsigned(31 downto 0) := ASYNC_DEFAULT_INTERVAL_CONST;
    signal periodic_async_high_cycles       : unsigned(7 downto 0)  := ASYNC_DEFAULT_HIGH_CYCLES_CONST;
    signal periodic_async_cfg_req           : std_logic := '0';
    signal periodic_async_cfg_hold          : unsigned(7 downto 0) := (others => '0');
    signal periodic_async_cfg_meta          : std_logic := '0';
    signal periodic_async_cfg_sync          : std_logic := '0';
    signal periodic_async_cfg_sync_d1       : std_logic := '0';
    signal periodic_async_mode_shadow       : std_logic_vector(3 downto 0) := CSR_DEF_CONST.mode;
    signal periodic_async_mode_meta         : std_logic_vector(3 downto 0) := CSR_DEF_CONST.mode;
    signal periodic_async_mode_sync         : std_logic_vector(3 downto 0) := CSR_DEF_CONST.mode;
    signal periodic_async_interval_shadow   : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0) := std_logic_vector(ASYNC_DEFAULT_INTERVAL_CONST);
    signal periodic_async_interval_meta     : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0) := std_logic_vector(ASYNC_DEFAULT_INTERVAL_CONST);
    signal periodic_async_interval_sync     : std_logic_vector(CSR_GENERAL_REG_BITS_CONST-1 downto 0) := std_logic_vector(ASYNC_DEFAULT_INTERVAL_CONST);
    signal periodic_async_high_cycles_shadow: std_logic_vector(7 downto 0) := std_logic_vector(ASYNC_DEFAULT_HIGH_CYCLES_CONST);
    signal periodic_async_high_cycles_meta  : std_logic_vector(7 downto 0) := std_logic_vector(ASYNC_DEFAULT_HIGH_CYCLES_CONST);
    signal periodic_async_high_cycles_sync  : std_logic_vector(7 downto 0) := std_logic_vector(ASYNC_DEFAULT_HIGH_CYCLES_CONST);
    signal periodic_async_rst_meta          : std_logic := '1';
    signal periodic_async_rst               : std_logic := '1';
    signal random_injector_rate_cnt         : unsigned(31 downto 0) := (others => '0');
    signal random_injector_icnt             : unsigned(7 downto 0)  := (others => '0');
    signal random_injector_pcnt             : unsigned(15 downto 0) := (others => '0');
    signal random_injector_idle_cnt         : unsigned(7 downto 0)  := (others => '0');
    signal random_injector_lfsr             : std_logic_vector(30 downto 0) := sanitize_prbs_state(CSR_DEF_CONST.prbs_seed, CSR_DEF_CONST.prbs_ctrl);
    signal random_injector_req_pending      : std_logic := '0';
    signal random_injector_pulse            : std_logic := '0';
    signal random_reseed_pulse              : std_logic := '0';

    signal onclick_injector_pulse    : std_logic := '0';
    signal onclick_injector_started  : std_logic := '0';
    signal onclick_injector_timer    : unsigned(31 downto 0) := (others => '0');
    signal onclick_write_pulse       : std_logic := '0';

    signal header_valid              : std_logic_vector(0 to 7);
    signal header_channel            : header_channel_array_t(0 to 7);
    signal header_match_valid        : std_logic;

    attribute altera_attribute : string;
    attribute altera_attribute of periodic_async_cfg_req : signal is "-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of periodic_async_mode_shadow : signal is "-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of periodic_async_interval_shadow : signal is "-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of periodic_async_high_cycles_shadow : signal is "-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of periodic_async_cfg_meta : signal is "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of periodic_async_cfg_sync : signal is "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of periodic_async_mode_meta : signal is "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of periodic_async_mode_sync : signal is "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of periodic_async_interval_meta : signal is "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of periodic_async_interval_sync : signal is "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of periodic_async_high_cycles_meta : signal is "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of periodic_async_high_cycles_sync : signal is "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of periodic_async_rst_meta : signal is "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of periodic_async_rst : signal is "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name GLOBAL_SIGNAL OFF";

begin

    header_valid(0)   <= asi_headerinfo0_valid;
    header_valid(1)   <= asi_headerinfo1_valid;
    header_valid(2)   <= asi_headerinfo2_valid;
    header_valid(3)   <= asi_headerinfo3_valid;
    header_valid(4)   <= asi_headerinfo4_valid;
    header_valid(5)   <= asi_headerinfo5_valid;
    header_valid(6)   <= asi_headerinfo6_valid;
    header_valid(7)   <= asi_headerinfo7_valid;

    header_channel(0) <= asi_headerinfo0_channel;
    header_channel(1) <= asi_headerinfo1_channel;
    header_channel(2) <= asi_headerinfo2_channel;
    header_channel(3) <= asi_headerinfo3_channel;
    header_channel(4) <= asi_headerinfo4_channel;
    header_channel(5) <= asi_headerinfo5_channel;
    header_channel(6) <= asi_headerinfo6_channel;
    header_channel(7) <= asi_headerinfo7_channel;

    header_match_valid <= any_header_match(header_valid, header_channel, csr.header_ch);

    csr_reg : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                csr                              <= CSR_DEF_CONST;
                avs_csr_waitrequest              <= '1';
                avs_csr_readdata                 <= (others => '0');
                onclick_write_pulse              <= '0';
                random_reseed_pulse              <= '0';
                periodic_async_cfg_req           <= '0';
                periodic_async_cfg_hold          <= (others => '0');
            else
                avs_csr_waitrequest <= '1';
                avs_csr_readdata    <= (others => '0');
                onclick_write_pulse <= '0';
                random_reseed_pulse <= '0';
                if periodic_async_cfg_req = '1' then
                    if periodic_async_cfg_hold = to_unsigned(0, periodic_async_cfg_hold'length) then
                        periodic_async_cfg_req <= '0';
                    else
                        periodic_async_cfg_hold <= periodic_async_cfg_hold - 1;
                    end if;
                end if;
                if avs_csr_read = '1' then
                    avs_csr_waitrequest <= '0';
                    case to_integer(unsigned(avs_csr_address)) is
                        when 0 =>
                            avs_csr_readdata(csr.mode'high downto 0) <= csr.mode;
                        when 1 =>
                            avs_csr_readdata(csr.header_delay'high downto 0) <= csr.header_delay;
                        when 2 =>
                            avs_csr_readdata(csr.header_interval'high downto 0) <= csr.header_interval;
                        when 3 =>
                            avs_csr_readdata(csr.injection_multiplicity'high downto 0) <= csr.injection_multiplicity;
                        when 4 =>
                            avs_csr_readdata(csr.header_ch'high downto 0) <= csr.header_ch;
                        when 5 =>
                            avs_csr_readdata(csr.pulse_interval'high downto 0) <= csr.pulse_interval;
                        when 6 =>
                            avs_csr_readdata(csr.pulse_high_cycles'high downto 0) <= csr.pulse_high_cycles;
                        when 7 =>
                            avs_csr_readdata(csr.prbs_rate'high downto 0) <= csr.prbs_rate;
                        when 8 =>
                            avs_csr_readdata(csr.prbs_pattern'high downto 0) <= csr.prbs_pattern;
                        when 9 =>
                            avs_csr_readdata(csr.prbs_seed'high downto 0) <= csr.prbs_seed;
                        when 10 =>
                            avs_csr_readdata(csr.prbs_ctrl'high downto 0) <= csr.prbs_ctrl;
                        when others =>
                            null;
                    end case;
                elsif avs_csr_write = '1' then
                    avs_csr_waitrequest <= '0';
                    case to_integer(unsigned(avs_csr_address)) is
                        when 0 =>
                            if to_integer(unsigned(avs_csr_writedata(csr.mode'high downto 0))) = 4 then
                                onclick_write_pulse <= '1';
                                csr.mode <= std_logic_vector(to_unsigned(0, csr.mode'length));
                            else
                                csr.mode <= avs_csr_writedata(csr.mode'high downto 0);
                                if to_integer(unsigned(avs_csr_writedata(csr.mode'high downto 0))) = 5 then
                                    random_reseed_pulse <= '1';
                                end if;
                            end if;
                            periodic_async_cfg_req  <= '1';
                            periodic_async_cfg_hold <= to_unsigned(ASYNC_CFG_STRETCH_CYCLES_CONST - 1, periodic_async_cfg_hold'length);
                        when 1 =>
                            csr.header_delay <= avs_csr_writedata(csr.header_delay'high downto 0);
                        when 2 =>
                            csr.header_interval <= avs_csr_writedata(csr.header_interval'high downto 0);
                        when 3 =>
                            csr.injection_multiplicity <= avs_csr_writedata(csr.injection_multiplicity'high downto 0);
                        when 4 =>
                            csr.header_ch <= avs_csr_writedata(csr.header_ch'high downto 0);
                        when 5 =>
                            csr.pulse_interval <= avs_csr_writedata(csr.pulse_interval'high downto 0);
                            periodic_async_cfg_req        <= '1';
                            periodic_async_cfg_hold       <= to_unsigned(ASYNC_CFG_STRETCH_CYCLES_CONST - 1, periodic_async_cfg_hold'length);
                        when 6 =>
                            csr.pulse_high_cycles <= avs_csr_writedata(csr.pulse_high_cycles'high downto 0);
                            periodic_async_cfg_req            <= '1';
                            periodic_async_cfg_hold           <= to_unsigned(ASYNC_CFG_STRETCH_CYCLES_CONST - 1, periodic_async_cfg_hold'length);
                        when 7 =>
                            csr.prbs_rate <= avs_csr_writedata(csr.prbs_rate'high downto 0);
                        when 8 =>
                            csr.prbs_pattern <= avs_csr_writedata(csr.prbs_pattern'high downto 0);
                            random_reseed_pulse <= '1';
                        when 9 =>
                            csr.prbs_seed <= avs_csr_writedata(csr.prbs_seed'high downto 0);
                            random_reseed_pulse <= '1';
                        when 10 =>
                            csr.prbs_ctrl <= avs_csr_writedata(csr.prbs_ctrl'high downto 0);
                            random_reseed_pulse <= '1';
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process;

    periodic_async_source_reg : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                periodic_async_mode_shadow        <= CSR_DEF_CONST.mode;
                periodic_async_interval_shadow    <= std_logic_vector(ASYNC_DEFAULT_INTERVAL_CONST);
                periodic_async_high_cycles_shadow <= std_logic_vector(ASYNC_DEFAULT_HIGH_CYCLES_CONST);
            else
                periodic_async_mode_shadow        <= csr.mode;
                periodic_async_interval_shadow    <= std_logic_vector(scale_async_cycles_runtime(unsigned(csr.pulse_interval), 1));
                periodic_async_high_cycles_shadow <= std_logic_vector(scale_async_cycles_runtime(unsigned(csr.pulse_high_cycles), 1));
            end if;
        end if;
    end process;

    periodic_async_reset_sync_reg : process(i_osc_clk)
    begin
        if rising_edge(i_osc_clk) then
            periodic_async_rst_meta <= i_rst;
            periodic_async_rst      <= periodic_async_rst_meta;
        end if;
    end process;

    periodic_async_cfg_reg : process(i_osc_clk)
    begin
        if rising_edge(i_osc_clk) then
            if periodic_async_rst = '1' then
                periodic_async_cfg_meta    <= '0';
                periodic_async_cfg_sync    <= '0';
                periodic_async_cfg_sync_d1 <= '0';
                periodic_async_mode_meta   <= CSR_DEF_CONST.mode;
                periodic_async_mode_sync   <= CSR_DEF_CONST.mode;
                periodic_async_mode        <= CSR_DEF_CONST.mode;
                periodic_async_interval_meta <= std_logic_vector(ASYNC_DEFAULT_INTERVAL_CONST);
                periodic_async_interval_sync <= std_logic_vector(ASYNC_DEFAULT_INTERVAL_CONST);
                periodic_async_interval    <= ASYNC_DEFAULT_INTERVAL_CONST;
                periodic_async_high_cycles_meta <= std_logic_vector(ASYNC_DEFAULT_HIGH_CYCLES_CONST);
                periodic_async_high_cycles_sync <= std_logic_vector(ASYNC_DEFAULT_HIGH_CYCLES_CONST);
                periodic_async_high_cycles <= ASYNC_DEFAULT_HIGH_CYCLES_CONST;
            else
                periodic_async_cfg_meta    <= periodic_async_cfg_req;
                periodic_async_cfg_sync    <= periodic_async_cfg_meta;
                periodic_async_cfg_sync_d1 <= periodic_async_cfg_sync;
                periodic_async_mode_meta   <= periodic_async_mode_shadow;
                periodic_async_mode_sync   <= periodic_async_mode_meta;
                periodic_async_interval_meta <= periodic_async_interval_shadow;
                periodic_async_interval_sync <= periodic_async_interval_meta;
                periodic_async_high_cycles_meta <= periodic_async_high_cycles_shadow;
                periodic_async_high_cycles_sync <= periodic_async_high_cycles_meta;
                if periodic_async_cfg_sync_d1 = '1' and periodic_async_cfg_sync = '0' then
                    periodic_async_mode        <= periodic_async_mode_sync;
                    periodic_async_interval    <= unsigned(periodic_async_interval_sync);
                    periodic_async_high_cycles <= unsigned(periodic_async_high_cycles_sync);
                end if;
            end if;
        end if;
    end process;

    header_injector_reg : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                header_injector          <= RESETTING;
                header_injector_hcnt     <= (others => '0');
                header_injector_delay    <= (others => '0');
                header_injector_icnt     <= (others => '0');
                header_injector_pcnt     <= (others => '0');
                header_injector_idle_cnt <= (others => '0');
                header_injector_pulse    <= '0';
            else
                case header_injector is
                    when IDLE =>
                        if to_integer(unsigned(csr.mode)) = 1 then
                            if header_match_valid = '1' then
                                header_injector_hcnt <= header_injector_hcnt + 1;
                                if to_integer(header_injector_hcnt) + 1 = to_integer(unsigned(csr.header_interval)) then
                                    header_injector      <= DELAYING;
                                    header_injector_hcnt <= (others => '0');
                                end if;
                            end if;
                        end if;
                    when DELAYING =>
                        header_injector_delay <= header_injector_delay + 1;
                        if header_injector_delay = unsigned(csr.header_delay) then
                            header_injector       <= INJECTING;
                            header_injector_delay <= (others => '0');
                        end if;
                    when INJECTING =>
                        header_injector_icnt <= header_injector_icnt + 1;
                        if header_injector_icnt = to_unsigned(0, header_injector_icnt'length) then
                            header_injector_pulse <= '1';
                        elsif header_injector_icnt = unsigned(csr.pulse_high_cycles) then
                            header_injector_pulse <= '0';
                            header_injector_pcnt  <= header_injector_pcnt + 1;
                            if to_integer(header_injector_pcnt) + 1 = to_integer(unsigned(csr.injection_multiplicity)) then
                                header_injector      <= RESETTING;
                                header_injector_pcnt <= (others => '0');
                                header_injector_icnt <= (others => '0');
                            else
                                header_injector      <= WAITING_LOW;
                                header_injector_icnt <= (others => '0');
                            end if;
                        end if;
                    when WAITING_LOW =>
                        header_injector_idle_cnt <= header_injector_idle_cnt + 1;
                        if header_injector_idle_cnt = to_unsigned(MIN_PULSE_CYCLES_CONST, header_injector_idle_cnt'length) then
                            header_injector          <= INJECTING;
                            header_injector_idle_cnt <= (others => '0');
                        end if;
                    when RESETTING =>
                        header_injector          <= IDLE;
                        header_injector_hcnt     <= (others => '0');
                        header_injector_delay    <= (others => '0');
                        header_injector_icnt     <= (others => '0');
                        header_injector_pcnt     <= (others => '0');
                        header_injector_idle_cnt <= (others => '0');
                        header_injector_pulse    <= '0';
                end case;
            end if;
        end if;
    end process;

    periodic_injector_reg : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                periodic_injector       <= RESETTING;
                periodic_injector_i_cnt <= (others => '0');
                periodic_injector_j_cnt <= (others => '0');
                periodic_injector_pulse <= '0';
            else
                case periodic_injector is
                    when INJECTING =>
                        periodic_injector_i_cnt <= periodic_injector_i_cnt + 1;
                        periodic_injector_j_cnt <= periodic_injector_j_cnt + 1;
                        periodic_injector_pulse <= '1';
                        if periodic_injector_j_cnt = unsigned(csr.pulse_high_cycles) then
                            periodic_injector_pulse <= '0';
                            periodic_injector_j_cnt <= (others => '0');
                            periodic_injector       <= WAITING_LOW;
                        end if;
                    when WAITING_LOW =>
                        periodic_injector_i_cnt <= periodic_injector_i_cnt + 1;
                        if periodic_injector_i_cnt > to_unsigned(MIN_PULSE_CYCLES_CONST, periodic_injector_i_cnt'length) then
                            if periodic_injector_i_cnt >= unsigned(csr.pulse_interval) then
                                periodic_injector <= IDLING;
                            end if;
                        end if;
                    when IDLING =>
                        if to_integer(unsigned(csr.mode)) = 2 then
                            periodic_injector <= INJECTING;
                        end if;
                        periodic_injector_i_cnt <= (others => '0');
                    when RESETTING =>
                        periodic_injector       <= IDLING;
                        periodic_injector_i_cnt <= (others => '0');
                        periodic_injector_j_cnt <= (others => '0');
                        periodic_injector_pulse <= '0';
                end case;
            end if;
        end if;
    end process;

    periodic_async_injector_reg : process(i_osc_clk)
    begin
        if rising_edge(i_osc_clk) then
            if periodic_async_rst = '1' then
                periodic_async_injector <= RESETTING;
                periodic_async_i_cnt    <= (others => '0');
                periodic_async_j_cnt    <= (others => '0');
                periodic_async_pulse    <= '0';
            else
                case periodic_async_injector is
                    when INJECTING =>
                        periodic_async_i_cnt <= periodic_async_i_cnt + 1;
                        periodic_async_j_cnt <= periodic_async_j_cnt + 1;
                        periodic_async_pulse <= '1';
                        if periodic_async_j_cnt = periodic_async_high_cycles then
                            periodic_async_pulse <= '0';
                            periodic_async_j_cnt <= (others => '0');
                            periodic_async_injector <= WAITING_LOW;
                        end if;
                    when WAITING_LOW =>
                        periodic_async_i_cnt <= periodic_async_i_cnt + 1;
                        if periodic_async_i_cnt > to_unsigned(ASYNC_MIN_PULSE_CYCLES_CONST, periodic_async_i_cnt'length) then
                            if periodic_async_i_cnt >= periodic_async_interval then
                                periodic_async_injector <= IDLING;
                            end if;
                        end if;
                    when IDLING =>
                        if to_integer(unsigned(periodic_async_mode)) = 3 then
                            periodic_async_injector <= INJECTING;
                        end if;
                        periodic_async_i_cnt <= (others => '0');
                    when RESETTING =>
                        periodic_async_injector <= IDLING;
                        periodic_async_i_cnt    <= (others => '0');
                        periodic_async_j_cnt    <= (others => '0');
                        periodic_async_pulse    <= '0';
                end case;
            end if;
        end if;
    end process;

    random_injector_reg : process(i_clk)
        variable random_v_next_lfsr : std_logic_vector(30 downto 0);
        variable random_v_match     : std_logic;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                random_injector          <= RESETTING;
                random_injector_rate_cnt <= (others => '0');
                random_injector_icnt     <= (others => '0');
                random_injector_pcnt     <= (others => '0');
                random_injector_idle_cnt <= (others => '0');
                random_injector_lfsr     <= sanitize_prbs_state(CSR_DEF_CONST.prbs_seed, CSR_DEF_CONST.prbs_ctrl);
                random_injector_req_pending <= '0';
                random_injector_pulse    <= '0';
            else
                if random_reseed_pulse = '1' then
                    random_injector          <= IDLING;
                    random_injector_rate_cnt <= (others => '0');
                    random_injector_icnt     <= (others => '0');
                    random_injector_pcnt     <= (others => '0');
                    random_injector_idle_cnt <= (others => '0');
                    random_injector_lfsr     <= sanitize_prbs_state(csr.prbs_seed, csr.prbs_ctrl);
                    random_injector_req_pending <= '0';
                    random_injector_pulse    <= '0';
                elsif to_integer(unsigned(csr.mode)) /= 5 then
                    random_injector          <= RESETTING;
                    random_injector_rate_cnt <= (others => '0');
                    random_injector_icnt     <= (others => '0');
                    random_injector_pcnt     <= (others => '0');
                    random_injector_idle_cnt <= (others => '0');
                    random_injector_lfsr     <= sanitize_prbs_state(csr.prbs_seed, csr.prbs_ctrl);
                    random_injector_req_pending <= '0';
                    random_injector_pulse    <= '0';
                else
                    random_v_match := '0';
                    if random_injector_rate_cnt >= unsigned(csr.prbs_rate) then
                        random_v_next_lfsr := prbs_next_state(random_injector_lfsr, csr.prbs_ctrl);
                        random_injector_rate_cnt <= (others => '0');
                        random_injector_lfsr     <= random_v_next_lfsr;
                        if prbs_pattern_match(random_v_next_lfsr, csr.prbs_pattern, csr.prbs_ctrl) = '1' then
                            random_v_match := '1';
                            random_injector_req_pending <= '1';
                        end if;
                    else
                        random_injector_rate_cnt <= random_injector_rate_cnt + 1;
                    end if;

                    case random_injector is
                        when INJECTING =>
                            random_injector_icnt  <= random_injector_icnt + 1;
                            if random_injector_icnt = to_unsigned(0, random_injector_icnt'length) then
                                random_injector_pulse <= '1';
                            elsif random_injector_icnt = unsigned(csr.pulse_high_cycles) then
                                random_injector_pulse <= '0';
                                random_injector_pcnt  <= random_injector_pcnt + 1;
                                if to_integer(random_injector_pcnt) + 1 = to_integer(unsigned(csr.injection_multiplicity)) then
                                    random_injector      <= IDLING;
                                    random_injector_pcnt <= (others => '0');
                                    random_injector_icnt <= (others => '0');
                                else
                                    random_injector      <= WAITING_LOW;
                                    random_injector_icnt <= (others => '0');
                                end if;
                            end if;
                        when WAITING_LOW =>
                            random_injector_idle_cnt <= random_injector_idle_cnt + 1;
                            if random_injector_idle_cnt = to_unsigned(MIN_PULSE_CYCLES_CONST, random_injector_idle_cnt'length) then
                                random_injector          <= INJECTING;
                                random_injector_idle_cnt <= (others => '0');
                            end if;
                        when IDLING =>
                            if random_injector_req_pending = '1' then
                                random_injector <= INJECTING;
                                if random_v_match = '1' then
                                    random_injector_req_pending <= '1';
                                else
                                    random_injector_req_pending <= '0';
                                end if;
                            end if;
                        when RESETTING =>
                            random_injector          <= IDLING;
                            random_injector_rate_cnt <= (others => '0');
                            random_injector_icnt     <= (others => '0');
                            random_injector_pcnt     <= (others => '0');
                            random_injector_idle_cnt <= (others => '0');
                            random_injector_lfsr     <= sanitize_prbs_state(csr.prbs_seed, csr.prbs_ctrl);
                            random_injector_req_pending <= '0';
                            random_injector_pulse    <= '0';
                    end case;
                end if;
            end if;
        end if;
    end process;

    onclick_injector_reg : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                onclick_injector_pulse   <= '0';
                onclick_injector_started <= '0';
                onclick_injector_timer   <= (others => '0');
            else
                if onclick_write_pulse = '1' then
                    onclick_injector_pulse   <= '1';
                    onclick_injector_started <= '1';
                    onclick_injector_timer   <= (others => '0');
                elsif onclick_injector_started = '1' then
                    onclick_injector_timer <= onclick_injector_timer + 1;
                    if onclick_injector_timer = unsigned(csr.pulse_high_cycles) then
                        onclick_injector_pulse   <= '0';
                        onclick_injector_started <= '0';
                        onclick_injector_timer   <= (others => '0');
                    end if;
                end if;
            end if;
        end if;
    end process;

    pulse_arb : process(all)
    begin
        case to_integer(unsigned(csr.mode)) is
            when 0 =>
                coe_inject_pulse <= onclick_injector_pulse;
            when 1 =>
                coe_inject_pulse <= header_injector_pulse;
            when 2 =>
                coe_inject_pulse <= periodic_injector_pulse;
            when 3 =>
                coe_inject_pulse <= periodic_async_pulse;
            when 5 =>
                coe_inject_pulse <= random_injector_pulse;
            when others =>
                coe_inject_pulse <= '0';
        end case;
    end process;

    run_management_agent : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                asi_runctl_ready <= '0';
            else
                asi_runctl_ready <= '1';
            end if;
        end if;
    end process;

end architecture;

--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- generate 40 bits of clock and reset to drive 6250 Gbps link at 156.26 MHz
-- such that output is observed as 125 MHz clock and 1250 Gbps reset link
entity reset_clock_gen is
generic (
    g_CLOCK40_MHz : real := 125.0;
    g_CLK_MHZ : real := 156.25--;
);
port (
    -- input reset datak & data (K28_5 is idle)
    i_reset9        : in    std_logic_vector(8 downto 0);
    -- reset link (8b10b encoded reset link where each bit takes 5 bits)
    o_reset40       : out   std_logic_vector(39 downto 0);

    -- clock link (stream of 25 bits of ones followed by 25 bits of zeros)
    o_clock40       : out   std_logic_vector(39 downto 0);

    i_reset_156_n   : in    std_logic;
    i_clk_156       : in    std_logic--;
);
end entity;

architecture arch of reset_clock_gen is

    signal reset : std_logic_vector(31 downto 0);
    -- number of valid bits in reset register, i.e. `reset(reset_bits-1 downto 0)`
    signal reset_bits : integer range 0 to reset'length := 8;

    signal reset_data10 : std_logic_vector(9 downto 0);
    signal reset_disp, reset_disp_out : std_logic;

    -- (40 bits * 156.25 MHz) / 125 MHz = 50 bits per output clock cycle
    constant CLOCK40_BITS : integer := integer(real(40) * g_CLK_MHZ / g_CLOCK40_MHz);
    constant GCD_BITS : integer := work.util.gcd(40, CLOCK40_BITS/2);

    signal clock : std_logic_vector(4*CLOCK40_BITS/GCD_BITS-1 downto 0);

begin

    assert ( true
        -- check that input/output rates match
        and ( real(40) * g_CLK_MHZ = real(CLOCK40_BITS) * g_CLOCK40_MHz )
    ) severity failure;

    o_reset40 <= work.util.expand(reset(7 downto 0), 5);
    o_clock40 <= work.util.expand(clock(40/GCD_BITS-1 downto 0), GCD_BITS);

    -- reset at 125 => 10 bits in 8 ns => 50 bits at 156.25
    -- - 200-bit ring buffer: add 50 bits at 125, remove 40 bits at 156.25
    --   (generate K28_5 when not enough bits)
    -- - fifo to sync 1 byte (10 bits) from 125 to 156
    process(i_clk_156, i_reset_156_n)
    begin
    if ( i_reset_156_n /= '1' ) then
        reset <= (others => '0');
        -- [AK] NOTE: bit 0 of reset_bits is never changed
        --            and may produce latch warnings in Quartus
        reset_bits <= 8;
        reset_disp <= '0';
        --
    elsif rising_edge(i_clk_156) then
        assert ( true
            and reset_bits >= 8
            and reset_bits <= reset'length
        ) severity error;

        -- remove 8 bits
        reset <= work.util.shift_right(reset, 8);
        reset_bits <= reset_bits - 8;

        if (
            -- need more bits
            reset_bits <= 8 + 6
            -- or not idle input (may overflow)
            or i_reset9 /= '1' & work.util.K28_5
        ) then
            reset_disp <= reset_disp_out;
            if ( reset_bits > reset'length - 2 ) then
                -- ERROR: overflow
            else
                -- add 10 bits
                reset(reset_bits + 1 downto reset_bits - 8) <= reset_data10;
                reset_bits <= reset_bits + 2;
            end if;
        end if;
    end if;
    end process;

    e_reset_data10 : entity work.enc_8b10b
    port map (
        i_data => i_reset9,
        i_disp => reset_disp,
        o_data => reset_data10,
        o_disp => reset_disp_out,
        o_err => open--,
    );

    -- at 156.25 => 40 bits in 6.4 ns => 1 bit in 0.16 ns
    -- clock at 125 => 1 cycle in 8 ns => 25 bits of 1 and 25 bits of 0 at 156.25
    -- - 200-bit shift register with sequence of 25 bits of 1s and 0s
    -- - rotate by 40 bits at 156.25
    process(i_clk_156, i_reset_156_n)
    begin
    if ( i_reset_156_n /= '1' ) then
        clock <= work.util.rotate_right(
            work.util.expand("10101010", CLOCK40_BITS/2/GCD_BITS),
            0 -- optional phase shift
        );
        --
    elsif rising_edge(i_clk_156) then
        clock <= work.util.rotate_right(clock, 40/GCD_BITS);
        --
    end if;
    end process;

end architecture;

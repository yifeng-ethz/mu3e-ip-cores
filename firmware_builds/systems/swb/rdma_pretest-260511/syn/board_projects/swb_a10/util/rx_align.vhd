--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rx_align is
generic (
    -- channel width in bytes
    g_BYTES : positive := 4;
    -- trigger bitslip every `2^g_BITSLIP_PERIOD` clock cycles
    g_BITSLIP_PERIOD : positive := 8;
    g_QUALITY : positive := 4;
    -- control symbol
    g_K : work.util_slv.slv8_array_t := ( 0 => work.util.K28_5 )--;
);
port (
    o_data              : out   std_logic_vector(g_BYTES*8-1 downto 0);
    o_datak             : out   std_logic_vector(g_BYTES-1 downto 0);
    o_locked            : out   std_logic;

    o_bitslip           : out   std_logic;
    o_bitslip_errors    : out   std_logic_vector(g_BITSLIP_PERIOD-1 downto 0);

    i_data              : in    std_logic_vector(g_BYTES*8-1 downto 0);
    i_datak             : in    std_logic_vector(g_BYTES-1 downto 0);
    i_error             : in    std_logic;

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture arch of rx_align is

    signal data : std_logic_vector(63 downto 0);
    signal datak : std_logic_vector(7 downto 0);

    signal bitslip_timeout, bitslip_errors : unsigned(g_BITSLIP_PERIOD-1 downto 0);

    signal locked : std_logic;
    signal pattern, pattern_q : std_logic_vector(3 downto 0);

    -- quality counter (increment if good pattern)
    signal quality : integer range 0 to g_QUALITY;
    -- require 64 errors to decrement quality
    -- - with error rate of 0.25 this requires at least 256 cycles
    -- - random stream produces one K in 256-512 cycles
    -- - stream with error rate of 0.25 produces one K in 1024 cycles
    signal errors : unsigned(5 downto 0);

begin

    o_locked <= locked;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        data <= (others => '0');
        datak <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        data <= (others => '0');
        datak <= (others => '0');
        -- assume link is LSBit first
        data(g_BYTES*8-1 downto 0) <= data(g_BYTES*8-1 + g_BYTES*8 downto g_BYTES*8);
        datak(g_BYTES-1 downto 0) <= datak(g_BYTES-1 + g_BYTES downto g_BYTES);
        data(g_BYTES*8-1 + g_BYTES*8 downto g_BYTES*8) <= i_data;
        datak(g_BYTES-1 + g_BYTES downto g_BYTES) <= i_datak;
        --
    end if;
    end process;

    -- generate bitslip signal if error rate is above 0.25
    -- - stream with invalid alignment to dec_8b10b has error rate of 0.30-0.50
    -- - stream of random bits to dec_8b10b has error rate of 0.70-0.80
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        o_bitslip <= '0';
        bitslip_timeout <= (others => '1');
        bitslip_errors <= (others => '0');
        o_bitslip_errors <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        o_bitslip <= '0';

        -- generate rising edge if not locked
        if ( locked = '0' )
        -- error rate > 0.25
        and ( bitslip_errors(bitslip_errors'left downto bitslip_errors'left-1) /= 0 )
        -- assert rx_bitslip signal for two parallel clock cycles
        and ( bitslip_timeout < 2 ) then
            o_bitslip <= '1';
        end if;

        if ( locked = '1' or bitslip_timeout = 0 ) then
            if ( work.util.SIMULATION and bitslip_errors > 0 ) then
                report "I [rx_align] bitslip_errors = "
                     & "0x" & work.util.to_hstring(std_logic_vector(bitslip_errors))
                     & " (" & integer'image(100*to_integer(bitslip_errors)/2**g_BITSLIP_PERIOD) & "%)";
            end if;
            -- reset counters
            bitslip_timeout <= (others => '1');
            bitslip_errors  <= (others => '0');
            o_bitslip_errors <= std_logic_vector(bitslip_errors);
        else
            -- update counter
            bitslip_timeout <= bitslip_timeout - 1;
            bitslip_errors <= bitslip_errors + ("" & i_error);
        end if;
        --
    end if;
    end process;

    process(i_data, i_datak)
    begin
        pattern <= (others => '0');
        for i in i_datak'range loop
            if ( work.util.SIMULATION
            and ( is_X(i_data((i+1)*8-1 downto i*8)) or is_X(i_datak(i)) ) ) then
                --
            else for j in g_K'range loop
                if ( i_datak(i) = '1' and i_data((i+1)*8-1 downto i*8) = g_K(j) ) then
                    pattern(i) <= '1';
                end if;
            end loop; end if;
        end loop;
    end process;

    process(i_clk, i_reset_n)
        variable error_v : boolean;
        --
    begin
    if ( i_reset_n /= '1' ) then
        pattern_q <= (others => '0');
        errors <= (others => '0');
        quality <= 0;
        locked <= '0';
        o_data <= (others => '0');
        o_datak <= (others => '1');
        --
    elsif rising_edge(i_clk) then
        error_v := false;

        if ( pattern = "0001" or pattern = "0010" or pattern = "0100" or pattern = "1000" ) then
            if ( pattern_q /= "0000" and pattern_q /= pattern ) then
                -- unexpected pattern
                error_v := true;
            end if;
        elsif ( pattern /= "0000" ) then
            -- invalid pattern
            error_v := true;
        end if;

        errors <= errors + ("" & i_error);

        if ( error_v )
        or ( i_error = '1' and errors = (errors'range => '1') ) then
            if ( quality = 0 ) then
                -- unlock and reset pattern
                locked <= '0';
                pattern_q <= "0000";
            else
                quality <= quality - 1;
                errors <= (others => '0');
            end if;
        elsif ( pattern /= "0000" ) then
            -- good pattern
            if ( quality = g_QUALITY ) then
                -- lock and save pattern
                locked <= '1';
                pattern_q <= pattern;
            else
                quality <= quality + 1;
                errors <= (others => '0');
            end if;
        end if;

        -- default output is invalid K bytes
        o_data <= (others => '0');
        o_datak <= (others => '1');

        -- align such that LSByte is K (comma)
        case pattern_q is
        when "0001" =>
            o_data <= data(g_BYTES*8-1 + 0 downto 0);
            o_datak <= datak(g_BYTES-1 + 0 downto 0);
        when "0010" =>
            o_data <= data(g_BYTES*8-1 + 8 downto 8);
            o_datak <= datak(g_BYTES-1 + 1 downto 1);
        when "0100" =>
            o_data <= data(g_BYTES*8-1 + 16 downto 16);
            o_datak <= datak(g_BYTES-1 + 2 downto 2);
        when "1000" =>
            o_data <= data(g_BYTES*8-1 + 24 downto 24);
            o_datak <= datak(g_BYTES-1 + 3 downto 3);
        when others =>
            null;
        end case;

        --
    end if; -- rising_edge
    end process;

end architecture;

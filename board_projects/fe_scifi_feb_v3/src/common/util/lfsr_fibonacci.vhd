library ieee;
use ieee.std_logic_1164.all;

--
-- <https://en.wikipedia.org/wiki/Linear-feedback_shift_register>
--
entity lfsr_fibonacci is
generic (
    -- taps (e.g. poly 'x^8 + x^6 + x^5 + x^4 + 1' corresponds to "10111000")
    g_TAPS : std_logic_vector;
    g_INIT : std_logic_vector := "1"--;
);
port (
    o_lfsr      : out   std_logic_vector(g_TAPS'length-1 downto 0);

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of lfsr_fibonacci is

    signal lfsr : std_logic_vector(o_lfsr'range);

begin

    o_lfsr <= lfsr;

    process(i_clk, i_reset_n)
        variable feedback : std_logic;
    begin
    if ( i_reset_n /= '1' ) then
        lfsr <= (others => '0');
        lfsr(g_INIT'length-1 downto 0) <= g_INIT;
        --
    elsif rising_edge(i_clk) then
        feedback := '0';
        -- handle taps
        for i in lfsr'range loop
            if ( g_TAPS(i) = '1' ) then
                feedback := feedback xor lfsr(i);
            end if;
        end loop;
        lfsr <= lfsr(lfsr'left-1 downto 0) & feedback;
        --
    end if;
    end process;

end architecture;

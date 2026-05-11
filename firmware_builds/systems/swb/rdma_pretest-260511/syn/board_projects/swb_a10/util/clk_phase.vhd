--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- measure phase between two clocks of _same_ frequency
entity clk_phase is
generic (
    W : positive := 16--;
);
port (
    i_clk1              : in    std_logic;
    i_clk2              : in    std_logic;

    o_phase             : out   std_logic_vector(W-1 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic
);
end entity;

architecture arch of clk_phase is

    signal d, q : std_logic_vector(1 downto 0) := (others => '0');

    signal cnt, phase : unsigned(o_phase'range) := (others => '0');

    -- avoid registers merge between clk_phase entities
    attribute ALTERA_ATTRIBUTE : string;
    attribute ALTERA_ATTRIBUTE of d : signal is "-name DONT_MERGE_REGISTER ON";

begin

    -- convert clk1 to ff output
    process(i_clk1)
    begin
    if rising_edge(i_clk1) then
        d(0) <= not d(0);
    end if;
    end process;

    -- convert clk2 to ff output
    process(i_clk2)
    begin
    if rising_edge(i_clk2) then
        d(1) <= not d(1);
    end if;
    end process;

    -- sync ff outputs to i_clk clock domain
    e_ff_sync : entity work.ff_sync
    generic map ( W => 2 )
    port map (
        i_d => d,
        o_q => q,
        i_reset_n => i_reset_n,
        i_clk => i_clk--,
    );

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        cnt <= (others => '0');
        phase <= (others => '0');
        o_phase <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        cnt <= cnt + 1;

        if ( q(1) /= q(0) ) then
            phase <= phase + 1;
        end if;

        if ( cnt = 0 ) then
            phase <= (others => '0');
            o_phase <= std_logic_vector(phase);
        end if;
        --
    end if;
    end process;

end architecture;

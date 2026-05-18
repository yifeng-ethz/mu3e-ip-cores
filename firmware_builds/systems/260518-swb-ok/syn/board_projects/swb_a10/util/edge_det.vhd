--

library ieee;
use ieee.std_logic_1164.all;

-- edge detector
entity edge_det is
generic (
    -- EDGE > 0 - rising edge
    -- EDGE < 0 - falling edge
    -- EDGE = 0 (default) - both edges
    EDGE : integer := 0;
    -- bus width
    W : positive := 1--;
);
port (
    i_d     : in    std_logic_vector(W-1 downto 0);
    o_q     : out   std_logic_vector(W-1 downto 0);
    i_clk   : in    std_logic--;
);
end entity;

architecture arch of edge_det is

    signal d0, d1 : std_logic_vector(W-1 downto 0);

begin

    d0 <= i_d;

    process(i_clk)
    begin
    if rising_edge(i_clk) then
        d1 <= d0;
        --
    end if;
    end process;

    gen_rising_edge : if EDGE > 0 generate
        o_q <= d0 and not d1;
    end generate;

    gen : if EDGE = 0 generate
        o_q <= d1 xor d0;
    end generate;

    gen_faling_edge : if EDGE < 0 generate
        o_q <= not d0 and d1;
    end generate;

end architecture;

--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--
-- ring buffer
--
entity ring_reg is
generic (
    g_WDATA_WIDTH : positive := 32;
    g_RDATA_WIDTH : positive := 32;
    g_ADDR_WIDTH : positive := 8--;
);
port (
    i_we        : in    std_logic;
    i_wdata     : in    std_logic_vector(g_WDATA_WIDTH-1 downto 0);
    o_wfull     : out   std_logic;

    i_rack      : in    std_logic;
    o_rdata     : out   std_logic_vector(g_RDATA_WIDTH-1 downto 0);
    o_rvalid    : out   std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of ring_reg is

begin

    assert (true
        and false -- TODO: implement
    ) severity error;

end architecture;

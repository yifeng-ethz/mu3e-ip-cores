--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

entity tb_pcie_register_mapping is
end entity;

architecture TB of tb_pcie_register_mapping is

    constant CLK_MHZ : real := 10000.0; -- MHz

    signal dataclk : std_logic := '0';
    signal pcieclk : std_logic := '0';
    signal reset_n : std_logic;

    signal rregs_156 : slv32_array_t(63 downto 0);

begin

    pcieclk <= not pcieclk  after (0.1 us / CLK_MHZ);
    dataclk <= not dataclk  after (0.5 us / CLK_MHZ);
    reset_n <= '0', '1'     after (1.0 us / CLK_MHZ);

    rregs_156(62) <= x"FFFFFFFF";
    rregs_156(63) <= x"BBBBBBBB";

    e_mapping : entity work.pcie_register_mapping
    port map (
        --! register inputs for pcie0
        i_pcie0_rregs_A         => (others => (others => '0')),
        i_pcie0_rregs_B         => rregs_156,
        i_pcie0_rregs_C         => (others => (others => '0')),

        --! register inputs for pcie0 from a10_block
        i_local_pcie0_rregs_A   => (others => (others => '0')),
        i_local_pcie0_rregs_B   => (others => (others => '0')),
        i_local_pcie0_rregs_C   => (others => (others => '0')),

        --! register outputs for pcie0
        o_pcie0_rregs           => open,

        i_reset_n               => reset_n,

        -- slow 156 MHz clock
        i_clk_A                 => pcieclk,
        i_clk_B                 => dataclk,
        i_clk_C                 => dataclk--,
    );

end architecture;

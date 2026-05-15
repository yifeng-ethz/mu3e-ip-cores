--

library ieee;
use ieee.std_logic_1164.all;

-- @deprecated
entity ip_ram is
generic (
    ADDR_WIDTH_A : positive := 8;
    ADDR_WIDTH_B : positive := 8;
    DATA_WIDTH_A : positive := 8;
    DATA_WIDTH_B : positive := 8;
    DEVICE : string := "Arria 10"--;
);
port (
    address_a   : in    std_logic_vector(ADDR_WIDTH_A-1 downto 0);
    address_b   : in    std_logic_vector(ADDR_WIDTH_B-1 downto 0);
    clock_a     : in    std_logic := '1';
    clock_b     : in    std_logic ;
    data_a      : in    std_logic_vector(DATA_WIDTH_A-1 downto 0);
    data_b      : in    std_logic_vector(DATA_WIDTH_B-1 downto 0);
    wren_a      : in    std_logic := '0';
    wren_b      : in    std_logic := '0';
    q_a         : out   std_logic_vector(DATA_WIDTH_A-1 downto 0);
    q_b         : out   std_logic_vector(DATA_WIDTH_B-1 downto 0)
);
end entity;

architecture arch of ip_ram is
begin

    e_ip_ram_2rw : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => ADDR_WIDTH_A,
        g_DATA0_WIDTH => DATA_WIDTH_A,
        g_ADDR1_WIDTH => ADDR_WIDTH_B,
        g_DATA1_WIDTH => DATA_WIDTH_B,
        g_RDATA0_REG => 0,
        g_RDATA1_REG => 0,
        g_DEVICE_FAMILY => DEVICE--;
    )
    port map (
        i_addr0     => address_a,
        o_rdata0    => q_a,
        i_wdata0    => data_a,
        i_we0       => wren_a,
        i_clk0      => clock_a,

        i_addr1     => address_b,
        o_rdata1    => q_b,
        i_wdata1    => data_b,
        i_we1       => wren_b,
        i_clk1      => clock_b--,
    );

end architecture;

--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

--
--
--
entity register_map is
generic (
    g_ADDR_WIDTH : positive := 16;
    g_RDATA_EMPTY : std_logic_vector := X"CCCCCCCC";
    g_MAP : integer_vector--;
);
port (
    -- rw interface
    i_addr      : in    std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    i_we        : in    std_logic;
    i_wdata     : in    std_logic_vector(31 downto 0);
    i_re        : in    std_logic;
    o_rdata     : out   std_logic_vector(31 downto 0);
    o_rvalid    : out   std_logic;

    i_regs_ff   : in    std_logic_vector(g_MAP'range) := (others => '0');
    -- registers that can be read via rw interface
    i_regs      : in    slv32_array_t(g_MAP'range) := (others => (others => '0'));
    -- registers that can be written via rw interface
    o_regs      : out   slv32_array_t(g_MAP'range);

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of register_map is

    signal addr : integer range 0 to 2**g_ADDR_WIDTH-1;
    signal regs : slv32_array_t(g_MAP'range);

begin

    addr <= to_integer(unsigned(i_addr));
    o_regs <= regs;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        o_rdata <= g_RDATA_EMPTY;
        o_rvalid <= '0';
        regs <= (others => (others => '0'));
        --
    elsif rising_edge(i_clk) then
        o_rdata <= g_RDATA_EMPTY;
        o_rvalid <= '0';

        for i in g_MAP'range loop
            if ( addr = g_MAP(i) ) then
                if ( i_re = '1' ) then
                    o_rdata <= regs(i) xor i_regs(i);
                    o_rvalid <= '1';
                end if;
                if ( i_we = '1' ) then
                    regs(addr) <= i_wdata;
                end if;
            end if;
        end loop;
        --
    end if;
    end process;

end architecture;

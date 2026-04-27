-- Quartus Prime VHDL Template
-- True Dual-Port RAM with single clock
--
-- Read-during-write on the same port returns the newly written data.
-- Mixed-port same-address read-during-write also returns the newly written data.

library ieee;
use ieee.std_logic_1164.all;

entity true_dual_port_ram_single_clock is

    generic (
        DATA_WIDTH : natural := 8;
        ADDR_WIDTH : natural := 6
    );

    port (
        clk    : in  std_logic;
        addr_a : in  natural range 0 to 2 ** ADDR_WIDTH - 1;
        addr_b : in  natural range 0 to 2 ** ADDR_WIDTH - 1;
        data_a : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        data_b : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        we_a   : in  std_logic := '0';
        we_b   : in  std_logic := '0';
        q_a    : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        q_b    : out std_logic_vector(DATA_WIDTH - 1 downto 0)
    );

end true_dual_port_ram_single_clock;

architecture rtl of true_dual_port_ram_single_clock is

    subtype word_t is std_logic_vector(DATA_WIDTH - 1 downto 0);
    type memory_t is array (0 to 2 ** ADDR_WIDTH - 1) of word_t;

    signal ram              : memory_t;
    signal q_a_ram_q        : word_t := (others => '0');
    signal q_b_ram_q        : word_t := (others => '0');
    signal q_a_bypass_q     : std_logic := '0';
    signal q_b_bypass_q     : std_logic := '0';
    signal q_a_bypass_data_q: word_t := (others => '0');
    signal q_b_bypass_data_q: word_t := (others => '0');

    attribute ramstyle : string;
    attribute ramstyle of ram : signal is "M10K,no_rw_check";

begin

    q_a <= q_a_bypass_data_q when q_a_bypass_q = '1' else q_a_ram_q;
    q_b <= q_b_bypass_data_q when q_b_bypass_q = '1' else q_b_ram_q;

    ram_reg : process (clk)
    begin
        if rising_edge(clk) then
            if we_a = '1' then
                ram(addr_a) <= data_a;
                q_a_ram_q   <= data_a;
            else
                q_a_ram_q <= ram(addr_a);
            end if;

            if we_b = '1' then
                ram(addr_b) <= data_b;
                q_b_ram_q   <= data_b;
            else
                q_b_ram_q <= ram(addr_b);
            end if;

            if (we_a = '0') and (we_b = '1') and (addr_a = addr_b) then
                q_a_bypass_q      <= '1';
                q_a_bypass_data_q <= data_b;
            else
                q_a_bypass_q <= '0';
            end if;

            if (we_b = '0') and (we_a = '1') and (addr_a = addr_b) then
                q_b_bypass_q      <= '1';
                q_b_bypass_data_q <= data_a;
            else
                q_b_bypass_q <= '0';
            end if;
        end if;
    end process ram_reg;

end architecture rtl;

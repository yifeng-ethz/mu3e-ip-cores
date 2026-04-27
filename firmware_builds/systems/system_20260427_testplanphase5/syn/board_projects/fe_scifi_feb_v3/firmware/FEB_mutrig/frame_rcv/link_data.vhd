
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mutrig.all;
use work.mudaq.all;

entity link_data is
generic (
    N_ASICS_TOTAL : natural := 1--;
);
port (
    i_reset_n   : in  std_logic;
    i_clk       : in  std_logic;

    i_data      : in  std_logic_vector(8 * N_ASICS_TOTAL - 1 downto 0);
    i_byteisk   : in  std_logic_vector(N_ASICS_TOTAL - 1 downto 0);
    i_link      : in  std_logic_vector(3 downto 0);

    o_data      : out std_logic_vector(33 downto 0);
    o_data_en   : out std_logic--;
);
end entity;

architecture rtl of link_data is

    signal data    : std_logic_vector(7 downto 0);
    signal byteisk : std_logic;

    type FSM_states is (IDLE, T1, HITS);
    signal FSM_state : FSM_states;

begin

    --! mux input
    data    <= i_data((to_integer(unsigned(i_link))+1)*8-1 downto to_integer(unsigned(i_link))*8);
    byteisk <= i_byteisk(to_integer(unsigned(i_link)));

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        o_data          <= (others => '0');
        o_data_en       <= '0';
        FSM_state       <= IDLE;
        --
    elsif rising_edge(i_clk) then

        o_data    <= (others => '0');
        o_data_en <= '0';

        if ( byteisk = '1' and data = x"BC" ) then
            --
        else
            case FSM_state is
                when IDLE =>
                    -- wait for header
                    if ( byteisk = '1' and data = c_header ) then
                        o_data(33 downto 32)    <= MERGER_FIFO_PAKET_START_MARKER(1 downto 0);
                        o_data(11 downto 8)     <= i_link;
                        o_data(7 downto 0)      <= data;
                        o_data_en               <= '1';
                        FSM_state               <= T1;
                    end if;

                when T1 =>
                    o_data(33 downto 32)    <= MERGER_FIFO_PAKET_T1_MARKER(1 downto 0);
                    o_data(7 downto 0)      <= data;
                    o_data_en               <= '1';
                    FSM_state               <= HITS;

                when HITS =>
                    if ( byteisk = '1' and data /= x"BC" ) then
                        o_data(33 downto 32)    <= MERGER_FIFO_PAKET_END_MARKER(1 downto 0);
                        o_data(7 downto 0)      <= data;
                        o_data_en               <= '1';
                        FSM_state               <= IDLE;
                    else
                        o_data(7 downto 0)      <= data;
                        o_data_en               <= '1';
                    end if;

                when others =>
                    FSM_state   <= IDLE;

            end case;
        end if;
    end if;
    end process;

end architecture;

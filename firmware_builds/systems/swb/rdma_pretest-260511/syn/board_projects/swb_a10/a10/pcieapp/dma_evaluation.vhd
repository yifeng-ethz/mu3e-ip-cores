-- fpga back pressure and dma halffull evaluation
-- Marius Koeppel, July 2019

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity dma_evaluation is
port (
    i_dmamemhalffull        : in    std_logic;
    i_dmamem_endofevent     : in    std_logic;

    o_halffull_counter      : out   std_logic_vector(31 downto 0);
    o_nothalffull_counter   : out   std_logic_vector(31 downto 0);
    o_endofevent_counter    : out   std_logic_vector(31 downto 0);
    o_notendofevent_counter : out   std_logic_vector(31 downto 0);

    i_reset_n               : in    std_logic;
    i_clk                   : in    std_logic--;
);
end entity;

architecture arch of dma_evaluation is

    signal reset : std_logic;

    signal halffull_counter_local       : std_logic_vector(31 downto 0);
    signal nothalffull_counter_local    : std_logic_vector(31 downto 0);
    signal endofevent_counter_local     : std_logic_vector(31 downto 0);
    signal notendofevent_counter_local  : std_logic_vector(31 downto 0);

begin

    o_halffull_counter        <= halffull_counter_local;
    o_nothalffull_counter     <= nothalffull_counter_local;
    o_endofevent_counter      <= endofevent_counter_local;
    o_notendofevent_counter   <= notendofevent_counter_local;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        halffull_counter_local      <= (others => '0');
        nothalffull_counter_local   <= (others => '0');
        endofevent_counter_local    <= (others => '0');
        notendofevent_counter_local <= (others => '0');
    elsif rising_edge(i_clk) then
        if ( i_dmamemhalffull = '1' ) then
            halffull_counter_local      <= halffull_counter_local + '1';
        else
            nothalffull_counter_local   <= nothalffull_counter_local + '1';
        end if;

        if ( i_dmamem_endofevent = '1') then
            endofevent_counter_local    <= endofevent_counter_local + '1';
        else
            notendofevent_counter_local <= notendofevent_counter_local + '1';
        end if;
    end if;
    end process;

end architecture;

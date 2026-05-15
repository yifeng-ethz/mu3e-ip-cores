-- ------------------------------------------------------------------------------------------------------------
-- IP Name: pseudo_clock_down_convertor
-- Author: Alexandr Kozlinskiy
-- Author2: Yifeng Wang (yifenwan@phys.ethz.ch)
-- Date: Aug 23, 2024
-- Revision: 2.0 (upgrade to sync_reset, add tick of output pseudo clock, fix bugs, IP wrapping)
-- Version : 26.2.1
-- Date    : 20260428
-- Change  : Fix odd clock-divider counter so 125 MHz REF_CLOCK_RATE produces 1 us ticks.
-- Description:
--   Down-convert a fast clock to a pseudo slow clock and a one-fast-cycle tick.
--   Clock divider: period(pseudo_clk) = CLK_DOWN_FACTOR * period(clk).
-- ------------------------------------------------------------------------------------------------------------
-- altera vhdl_input_version vhdl_2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pseudo_clock_down_convertor is
    generic (
        CLK_DOWN_FACTOR : positive := 1
    );
    port (
        clk           : in  std_logic;
        reset_n       : in  std_logic;
        pseudo_clk    : out std_logic;
        tick          : out std_logic
    );
end entity;

architecture rtl of pseudo_clock_down_convertor is
begin

    gen_bypass : if CLK_DOWN_FACTOR = 1 generate
        pseudo_clk    <= clk;
        tick          <= '1';
    end generate gen_bypass;

    assert not (CLK_DOWN_FACTOR = 1)
        report "CLK_DOWN_FACTOR is set to 1. The output tick is forced high."
        severity warning;

    gen_even : if CLK_DOWN_FACTOR > 1 and CLK_DOWN_FACTOR mod 2 = 0 generate
        signal even_counter        : natural range 0 to CLK_DOWN_FACTOR - 1    := 0;
        signal even_pseudo_clk     : std_logic                                 := '0';
    begin
        pseudo_clk <= even_pseudo_clk;

        even_divider : process (clk)
        begin
            if rising_edge(clk) then
                if reset_n /= '1' then
                    even_pseudo_clk    <= '0';
                    tick               <= '0';
                    even_counter       <= 0;
                else
                    tick <= '0';

                    if even_counter = (CLK_DOWN_FACTOR / 2) - 1 then
                        even_counter       <= 0;
                        even_pseudo_clk    <= not even_pseudo_clk;

                        if even_pseudo_clk = '0' then
                            tick <= '1';
                        end if;
                    else
                        even_counter <= even_counter + 1;
                    end if;
                end if;
            end if;
        end process;
    end generate gen_even;

    gen_odd : if CLK_DOWN_FACTOR > 1 and CLK_DOWN_FACTOR mod 2 = 1 generate
        signal odd_counter        : natural range 0 to CLK_DOWN_FACTOR - 1    := 0;
        signal odd_pseudo_clk     : std_logic                                 := '0';
    begin
        pseudo_clk <= odd_pseudo_clk;

        odd_divider : process (clk)
        begin
            if rising_edge(clk) then
                if reset_n /= '1' then
                    odd_pseudo_clk    <= '0';
                    tick              <= '0';
                    odd_counter       <= 0;
                else
                    tick <= '0';

                    if odd_counter = CLK_DOWN_FACTOR / 2 then
                        odd_pseudo_clk    <= '1';
                        tick              <= '1';
                    elsif odd_counter = CLK_DOWN_FACTOR - 1 then
                        odd_pseudo_clk <= '0';
                    end if;

                    if odd_counter = CLK_DOWN_FACTOR - 1 then
                        odd_counter <= 0;
                    else
                        odd_counter <= odd_counter + 1;
                    end if;
                end if;
            end if;
        end process;
    end generate gen_odd;

end architecture rtl;

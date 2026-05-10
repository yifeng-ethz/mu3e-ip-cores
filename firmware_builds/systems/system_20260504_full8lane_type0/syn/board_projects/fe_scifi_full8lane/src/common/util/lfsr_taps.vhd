-- lfsr taps for maximal length
-- https://www.xilinx.com/support/documentation/application_notes/xapp052.pdf

library ieee;
use ieee.std_logic_1164.all;

package lfsr_taps is

    constant lfsr_taps3  : std_logic_vector(2 downto 0) := (2 => '1', 1 => '1', others => '0');
    constant lfsr_taps4  : std_logic_vector(3 downto 0) := (3 => '1', 2 => '1', others => '0');
    constant lfsr_taps5  : std_logic_vector(4 downto 0) := (4 => '1', 2 => '1', others => '0');
    constant lfsr_taps6  : std_logic_vector(5 downto 0) := (5 => '1', 4 => '1', others => '0');
    constant lfsr_taps7  : std_logic_vector(6 downto 0) := (6 => '1', 5 => '1', others => '0');
    constant lfsr_taps8  : std_logic_vector(7 downto 0) := (7 => '1', 5 => '1', 4 => '1', 3 => '1', others => '0');

    constant lfsr_taps64  : std_logic_vector(63 downto 0) := (63 => '1', 62 => '1', 60 => '1' , 59 => '1', others => '0');
    constant lfsr_taps65  : std_logic_vector(64 downto 0) := (64 => '1', 46 => '1', others => '0');

end package;

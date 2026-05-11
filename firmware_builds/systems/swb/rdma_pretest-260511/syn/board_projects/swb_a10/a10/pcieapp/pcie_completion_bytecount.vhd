-----------------------------------------------------------------------------
-- PCIe completer bytecount, constructs byte count from length and
-- ldw_be and fdw_be
--
-- Niklaus Berger, Heidelberg University
-- nberger@physi.uni-heidelberg.de
--
-- This implements table 2-21 (page 90) in the PCIe 1.1 standart
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity pcie_completion_bytecount is
port (
    fdw_be          : in    std_logic_vector(3 downto 0);
    ldw_be          : in    std_logic_vector(3 downto 0);
    plength         : in    std_logic_vector(9 downto 0);
    bytecount       : out   std_logic_vector(11 downto 0);
    lower_address   : out   std_logic_vector(1 downto 0)
);
end entity;

architecture RTL of pcie_completion_bytecount is

    signal onewordbytecount : std_logic_vector(2 downto 0);
    signal morewordbytecount : std_logic_vector(11 downto 0);
    signal lengthshifted : std_logic_vector(11 downto 0);

begin

    bytecount <=
        "000000000" & onewordbytecount when ldw_be = "0000" else
        morewordbytecount;

    onewordbytecount <=
        "100" when fdw_be(0) = '1' and fdw_be(3) = '1' else
        "011" when fdw_be(0) = '0' and fdw_be(1) = '1' and fdw_be(3) = '1' else
        "011" when fdw_be(0) = '1' and fdw_be(2) = '1' and fdw_be(3) = '0' else
        "010" when fdw_be = "0011" or fdw_be = "0110" or fdw_be = "1100" else
        "001";

    lengthshifted <= plength & "00";

    morewordbytecount <=
        lengthshifted when fdw_be(0) = '1' and ldw_be(3) = '1' else
        lengthshifted - '1' when fdw_be(0) = '1' and ldw_be(2) = '1' and ldw_be(3) = '0' else
        lengthshifted - "10" when fdw_be(0) = '1' and ldw_be(1) = '1' and ldw_be(2) = '0' and ldw_be(3) = '0' else
        lengthshifted - "11" when fdw_be(0) = '1' and ldw_be = "0001" else
        lengthshifted - '1' when fdw_be(1 downto 0) = "10" and ldw_be(3) = '1' else
        lengthshifted - "10" when fdw_be(1 downto 0) = "10" and ldw_be(2) = '1' and ldw_be(3) = '0' else
        lengthshifted - "11" when fdw_be(1 downto 0) = "10" and ldw_be(1) = '1' and ldw_be(2) = '0' and ldw_be(3) = '0' else
        lengthshifted - "100" when fdw_be(1 downto 0) = "10" and ldw_be = "0001" else
        lengthshifted - "10" when fdw_be(2 downto 0) = "100" and ldw_be(3) = '1' else
        lengthshifted - "11" when fdw_be(2 downto 0) = "100" and ldw_be(2) = '1' and ldw_be(3) = '0' else
        lengthshifted - "100" when fdw_be(2 downto 0) = "100" and ldw_be(1) = '1' and ldw_be(2) = '0' and ldw_be(3) = '0' else
        lengthshifted - "101" when fdw_be(2 downto 0) = "100" and ldw_be = "0001" else
        lengthshifted - "11" when fdw_be = "1000" and ldw_be(3) = '1' else
        lengthshifted - "100" when fdw_be = "1000" and ldw_be(2) = '1' and ldw_be(3) = '0' else
        lengthshifted - "101" when fdw_be = "1000" and ldw_be(1) = '1' and ldw_be(2) = '0' and ldw_be(3) = '0' else
        lengthshifted - "110";

    lower_address <=
        "00" when fdw_be = "0000" or fdw_be(0) = '1' else
        "01" when fdw_be(1 downto 0) = "10" else
        "10" when fdw_be(2 downto 0) = "100" else
        "11";

end architecture;

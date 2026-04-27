-- testbench for mscb addressing
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mscb_addressing_tb is
end entity;

architecture rtl of mscb_addressing_tb is

    signal clk :                        std_logic := '1';
    signal reset :                      std_logic;
    signal addressing_data_in :         std_logic_vector(8 downto 0);
    signal addressing_data_out :        std_logic_vector(8 downto 0);
    signal addressing_wrreq :           std_logic;
    signal addressing_rdreq :           std_logic;
    signal rec_fifo_empty :             std_logic;
    signal i_mscb_address :             std_logic_vector(15 downto 0);


begin

    clk <= not clk after 4 ns;

    e_mscb_addressing : entity work.mscb_addressing
    port map (
        i_clk           => clk,
        i_reset         => reset,
        i_data          => addressing_data_in,
        i_empty         => rec_fifo_empty,
        i_address       => i_mscb_address,
        o_data          => addressing_data_out,
        o_wrreq         => addressing_wrreq,
        o_rdreq         => addressing_rdreq
    );

end architecture;

-- QUARTUS_SYNTH

library ieee;
use ieee.std_logic_1164.all;

entity avalon_proxy is
generic (
    ADDRESS_WIDTH : positive := 16;
    DATA_WIDTH : positive := 32--;
);
port (
    avs_address         : in    std_logic_vector(ADDRESS_WIDTH-1 downto 0);
    avs_read            : in    std_logic;
    avs_readdata        : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    avs_write           : in    std_logic;
    avs_writedata       : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    avs_waitrequest     : out   std_logic;
--{RDV}    avs_readdatavalid   : out   std_logic;

    avm_address         : out   std_logic_vector(ADDRESS_WIDTH-1 downto 0);
    avm_read            : out   std_logic;
    avm_readdata        : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    avm_write           : out   std_logic;
    avm_writedata       : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    avm_waitrequest     : in    std_logic;
--{RDV}    avm_readdatavalid   : in    std_logic;

    reset               : in    std_logic;
    clk                 : in    std_logic--;
);
end entity;

architecture arch of avalon_proxy is
begin

    avm_address         <= avs_address;
    avm_read            <= avs_read;
    avs_readdata        <= avm_readdata;
    avm_write           <= avs_write;
    avm_writedata       <= avs_writedata;
    avs_waitrequest     <= avm_waitrequest;
--{RDV}    avs_readdatavalid   <= avm_readdatavalid;

end architecture;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package nios_pkg is
	component nios_avalon_proxy_11_kaji5di is
		generic (
			DATA_WIDTH    : integer := 32;
			ADDRESS_WIDTH : integer := 32
		);
		port (
			clk             : in  std_logic                     := 'X';             -- clk
			reset           : in  std_logic                     := 'X';             -- reset
			avs_address     : in  std_logic_vector(13 downto 0) := (others => 'X'); -- address
			avs_read        : in  std_logic                     := 'X';             -- read
			avs_readdata    : out std_logic_vector(31 downto 0);                    -- readdata
			avs_write       : in  std_logic                     := 'X';             -- write
			avs_writedata   : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			avs_waitrequest : out std_logic;                                        -- waitrequest
			avm_address     : out std_logic_vector(13 downto 0);                    -- address
			avm_read        : out std_logic;                                        -- read
			avm_readdata    : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			avm_write       : out std_logic;                                        -- write
			avm_writedata   : out std_logic_vector(31 downto 0);                    -- writedata
			avm_waitrequest : in  std_logic                     := 'X'              -- waitrequest
		);
	end component nios_avalon_proxy_11_kaji5di;

	component nios_avalon_proxy_11_gqppolq is
		generic (
			DATA_WIDTH    : integer := 32;
			ADDRESS_WIDTH : integer := 32
		);
		port (
			clk             : in  std_logic                     := 'X';             -- clk
			reset           : in  std_logic                     := 'X';             -- reset
			avs_address     : in  std_logic_vector(17 downto 0) := (others => 'X'); -- address
			avs_read        : in  std_logic                     := 'X';             -- read
			avs_readdata    : out std_logic_vector(31 downto 0);                    -- readdata
			avs_write       : in  std_logic                     := 'X';             -- write
			avs_writedata   : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			avs_waitrequest : out std_logic;                                        -- waitrequest
			avm_address     : out std_logic_vector(17 downto 0);                    -- address
			avm_read        : out std_logic;                                        -- read
			avm_readdata    : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			avm_write       : out std_logic;                                        -- write
			avm_writedata   : out std_logic_vector(31 downto 0);                    -- writedata
			avm_waitrequest : in  std_logic                     := 'X'              -- waitrequest
		);
	end component nios_avalon_proxy_11_gqppolq;

end nios_pkg;

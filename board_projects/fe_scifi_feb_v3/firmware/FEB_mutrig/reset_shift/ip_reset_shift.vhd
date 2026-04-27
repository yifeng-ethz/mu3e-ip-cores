
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

-- synthesis read_comments_as_HDL on
--LIBRARY arriav;
--USE arriav.all;
-- synthesis read_comments_as_HDL off

entity ip_reset_shift is
port (
    datashift           : in    std_logic_vector (0 downto 0);
    datain              : in    std_logic_vector (0 downto 0);
    io_config_clk       : in    std_logic;
    io_config_clkena    : in    std_logic_vector (0 downto 0);
    io_config_datain    : in    std_logic;
    io_config_update    : in    std_logic;
    --oe                  : in    std_logic_vector (0 downto 0);
    dataout             : out   std_logic_vector (0 downto 0);
    i_reset_n           : in    std_logic;
    clk                 : in    std_logic--;
);
end entity;

architecture rtl of ip_reset_shift is
	 COMPONENT  arriav_delay_chain IS
	 GENERIC
	 (
		sim_falling_delay_increment	:	NATURAL := 10;
		sim_intrinsic_falling_delay	:	NATURAL := 200;
		sim_intrinsic_rising_delay	:	NATURAL := 200;
		sim_rising_delay_increment	:	NATURAL := 10;
		lpm_type					:	STRING := "arriav_delay_chain"
	 );
	 PORT
	 (
		datain	:	IN STD_LOGIC := '0';
		dataout	:	OUT STD_LOGIC;
		delayctrlin :	IN STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0')
	 );
	 END COMPONENT;
	 COMPONENT  arriav_io_config IS
	 PORT
	 (
		clk	: IN STD_LOGIC 	:= '0';
		datain	: IN STD_LOGIC 	:= '0';
		dataout	: OUT STD_LOGIC;
		ena	: IN STD_LOGIC 	:= '0';
		outputenabledelaysetting : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		outputhalfratebypass : OUT STD_LOGIC;
		outputregdelaysetting : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		padtoinputregisterdelaysetting : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		readfifomode : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
		readfiforeadclockselect	: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		update : IN STD_LOGIC := '0'
	 );
	 END COMPONENT;


signal s_delay_ctrl  : STD_LOGIC_VECTOR (4 DOWNTO 0);
signal s_sig_from_ddio : STD_LOGIC_VECTOR (0 DOWNTO 0) := "0";
signal s_data : STD_LOGIC_VECTOR(0 DOWNTO 0) := "0";
signal s_data_del : STD_LOGIC_VECTOR(0 DOWNTO 0) := "0";
signal datashift_clk : std_logic_vector (0 downto 0);
begin

	ioconfiga : arriav_io_config
    port map (
		clk 			=> io_config_clk,
		datain 			=> io_config_datain,
		ena 			=> io_config_clkena(0),
		outputregdelaysetting 	=> s_delay_ctrl,
		update 			=> io_config_update
	  );

	 e_datashift : entity work.ff_sync
    generic map ( W => datashift_clk'length )
    port map (
        i_d => datashift, o_q => datashift_clk,
        i_reset_n => i_reset_n, i_clk => clk--,
    );

	-- TODO : IMPLEMENT SHIFT OF HALF CLOCK CYCLE DEPENDING ON DATASHIFT(=)
	half_cycle : process(clk, datashift_clk)
	begin
	if rising_edge(clk) then
		s_data <= datain;
		if datashift_clk(0) = '1' then
			s_data_del <= s_data;
		else
			s_data_del <= datain;
		end if;

	end if;

	end process;
	buf : altddio_out
    generic map (
               	extend_oe_disable 	=> "OFF",
              	intended_device_family 	=> "Arria V",
              	invert_output 		=> "OFF",
              	lpm_hint 		=> "UNUSED",
               	lpm_type 		=> "altddio_out",
              	oe_reg 			=> "UNREGISTERED",
             	power_up_high 		=> "OFF",
                width 			=> 1
        )
    port map (
		datain_h		=> s_data_del,
		datain_l		=> s_data,
		outclock		=> clk,
		dataout			=> s_sig_from_ddio
	);

	sd1 : arriav_delay_chain
    generic map (
        sim_falling_delay_increment => 200,
        sim_rising_delay_increment => 200
    )
    port map (
		datain 			=> s_sig_from_ddio(0),
		dataout 		=> dataout(0),
		delayctrlin 		=> s_delay_ctrl
	);

end architecture;

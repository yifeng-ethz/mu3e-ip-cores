--------------------------------------------------
-- CRC-16 calculator for 8-bits inputs
-- using CRC-16-ANSI, MSBF/normal (0x8005)
-- rename the crc16_8 to crc16_calc to have a different module in ModelSim for simulation



Library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity crc16_calc is
port (
	i_clk : in std_logic;
	i_rst : in std_logic;
	i_d_valid: in std_logic;
	i_din : in std_logic_vector(7 downto 0);
	o_crc_reg : out std_logic_vector(15 downto 0);
	o_crc_8 : out std_logic_vector(7 downto 0)
);
end entity;

architecture rtl of crc16_calc is

	signal p_crc, n_crc : std_logic_vector(15 downto 0);
	signal s_data : std_logic_vector(7 downto 0);

begin

	s_data <= i_din;
	o_crc_reg <= not p_crc;
	o_crc_8 <= not n_crc(15 downto 8);

	n_crc(0)  <= p_crc(15) xor s_data(7) xor p_crc(14) xor s_data(6) xor p_crc(13) xor s_data(5) xor p_crc(12) xor s_data(4) xor p_crc(11) xor s_data(3) xor p_crc(10) xor s_data(2) xor p_crc(9) xor s_data(1) xor p_crc(8) xor s_data(0);
	n_crc(1)  <= p_crc(15) xor s_data(7) xor p_crc(14) xor s_data(6) xor p_crc(13) xor s_data(5) xor p_crc(12) xor s_data(4) xor p_crc(11) xor s_data(3) xor p_crc(10) xor s_data(2) xor p_crc(9) xor s_data(1);
	n_crc(2)  <= p_crc(9) xor s_data(1) xor p_crc(8) xor s_data(0);
	n_crc(3)  <= p_crc(10) xor s_data(2) xor p_crc(9) xor s_data(1);
	n_crc(4)  <= p_crc(11) xor s_data(3) xor p_crc(10) xor s_data(2);
	n_crc(5)  <= p_crc(12) xor s_data(4) xor p_crc(11) xor s_data(3);
	n_crc(6)  <= p_crc(13) xor s_data(5) xor p_crc(12) xor s_data(4);
	n_crc(7)  <= p_crc(14) xor s_data(6) xor p_crc(13) xor s_data(5);
	n_crc(8)  <= p_crc(15) xor s_data(7) xor p_crc(14) xor s_data(6) xor p_crc(0);
	n_crc(9)  <= p_crc(15) xor s_data(7) xor p_crc(1);
	n_crc(10) <= p_crc(2);
	n_crc(11) <= p_crc(3);
	n_crc(12) <= p_crc(4);
	n_crc(13) <= p_crc(5);
	n_crc(14) <= p_crc(6);
	n_crc(15) <= p_crc(15) xor s_data(7) xor p_crc(14) xor s_data(6) xor p_crc(13) xor s_data(5) xor p_crc(12) xor s_data(4) xor p_crc(11) xor s_data(3) xor p_crc(10) xor s_data(2) xor p_crc(9) xor s_data(1) xor p_crc(8) xor s_data(0) xor p_crc(7);

	crc_syn : process (i_rst, i_clk)
	begin
	if rising_edge(i_clk) then
		if i_rst = '1' then
			p_crc <= (others => '1');
		else
			if i_d_valid = '1' then
				p_crc <= n_crc;
			end if;
		end if;
	end if;
	end process;

end architecture;

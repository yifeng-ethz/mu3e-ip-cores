-- File name: addr_enc_logic_small.vhd 
-- Author: Yifeng Wang
-- =======================================
-- Revision: 1.0 (file created)
--		Date: September 20, 2023
-- Revision: 2.0 (add the onehot next output)
--		Date: Jul 16, 2024
-- Revision: 2.1 (fix the max size)
--		Date: Jul 19, 2024
-- Revision: 2.2 (improve timing on flag)
--      Date: Mar 25, 2025
-- ================ synthsizer configuration =================== 		
-- altera vhdl_input_version vhdl_2008
-- ============================================================= 
-- Description: encoding the output of CAM. turning the found array (one-hot) into match-address (binary)  

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.or_reduce;

entity addr_enc_logic_small is
generic(
	CAM_SIZE			: natural := 64; -- after some experiments, this is the safest max option, 128 entry (22 stages post-layout) could incurr minor violation in slow model
	CAM_ADDR_BITS		: natural := 6
);
port(
	i_cam_address_onehot		: in  std_logic_vector(CAM_SIZE-1 downto 0);
	o_cam_address_binary		: out std_logic_vector(CAM_ADDR_BITS-1 downto 0); -- msb '1' binary
	o_cam_address_binary_lsb	: out std_logic_vector(CAM_ADDR_BITS-1 downto 0); -- lsb '1' in binary
	o_cam_match_flag			: out std_logic;
	o_cam_match_count			: out std_logic_vector(CAM_ADDR_BITS downto 0);
	o_cam_address_onehot_next	: out std_logic_vector(CAM_SIZE-1 downto 0) -- the next onehot, trimmed of both lsb '1'. 
);
end entity addr_enc_logic_small;

architecture rtl of addr_enc_logic_small is 


	component b2o_encoder
	generic(
		INPUT_W		: natural 	:= CAM_ADDR_BITS;
		OUTPUT_W	: natural 	:= CAM_SIZE
	);
	port(
		binary_code		: in  std_logic_vector(CAM_ADDR_BITS-1 downto 0);
		onehot_code		: out std_logic_vector(CAM_SIZE-1 downto 0)
	);
	end component;
	
	signal cam_address_onehot							: std_logic_vector(CAM_SIZE-1 downto 0);
	signal cam_address_onehot_inv						: std_logic_vector(CAM_SIZE-1 downto 0);
	signal cam_address_binary							: std_logic_vector(CAM_ADDR_BITS-1 downto 0);
	signal cam_match_count								: std_logic_vector(CAM_ADDR_BITS downto 0);
	signal cam_address_binary_lsb						: std_logic_vector(CAM_ADDR_BITS-1 downto 0);
	signal cam_match_flag								: std_logic;
	signal cam_address_onehot_current					: std_logic_vector(CAM_SIZE-1 downto 0);
	signal cam_address_onehot_current_lsb				: std_logic_vector(CAM_SIZE-1 downto 0);
	
	begin
		-- instantiation
		b2o_enc : b2o_encoder
		port map (
			binary_code		=> cam_address_binary,
			onehot_code		=> cam_address_onehot_current
		);
		b2o_enc_lsb	: b2o_encoder
		port map(
			binary_code		=> cam_address_binary_lsb,
			onehot_code		=> cam_address_onehot_current_lsb
		);
		
		-- wire i/o
		cam_address_onehot				<= i_cam_address_onehot;
		o_cam_address_binary			<= cam_address_binary;
		o_cam_match_flag				<= cam_match_flag;
		o_cam_match_count				<= cam_match_count;
		o_cam_address_binary_lsb		<= cam_address_binary_lsb;
		
		-- main comb logic, onehot to binary encoding
		proc_onehot2bin_comb : process (all)
			variable code			: std_logic_vector(CAM_ADDR_BITS-1 downto 0); -- find leading '1' position in binary
			variable code_lsb		: std_logic_vector(CAM_ADDR_BITS-1 downto 0); -- find lagging '1' position in binary
			variable count			: unsigned(CAM_ADDR_BITS downto 0); -- TODO: fix this! (fixed) 0 to 127, for msb, it is overflow, which means all '1's. 
		
		begin
			-- default
			code 			:= (others => '0');
			code_lsb		:= (others => '0');
			count			:= (others => '0');

			-- detect the leading 1 (from msb) and output binary code, and count the number of 1s in onehot
			gen_binary : for i in 0 to CAM_SIZE-1 loop -- from lsb to msb, msb will overwrite lsb ones.  
				-- casecade mux many stages, compare if '1', sel and go to next stage
				-- input: stage index, (last stage counter+1) and last stage code and count 
				-- output: code, count
				if (cam_address_onehot(i) = '1') then 
					code 		:= std_logic_vector(to_unsigned(i, code'length));
					count 		:= count + 1;
				else
					code 		:= code;
					count		:= count;
				end if;
			end loop gen_binary;
			
			-- detect the lagging 1 (from lsb) and output binary code
			gen_binary_lsb : for i in CAM_SIZE-1 downto 0 loop -- from msb to lsb, lsb will overwrite lsb ones.  
				if (cam_address_onehot(i) = '1') then 
					code_lsb 	:= std_logic_vector(to_unsigned(i, code_lsb'length));
				else
					code_lsb 	:= code_lsb;
				end if;
			end loop gen_binary_lsb;
		
			
			-- valid flag for binary code
--			if (to_integer(count) /= 0) then
--				cam_match_flag <= '1';
--			else
--				cam_match_flag <= '0';
--			end if;
            
            
            cam_match_flag  <= or_reduce(cam_address_onehot);
            
			
			-- wire last stage to output
			cam_match_count 		<= std_logic_vector(count) ;
			cam_address_binary 		<= code;
			cam_address_binary_lsb	<= code_lsb;
			
		end process;
		
		-- 
		proc_onehot_next_comb : process (all)
		-- trims the leading and lagging (msb and lsb) bits of the input onehot code
			type state_flag_t	is array (0 to CAM_SIZE-1) of std_logic_vector(1 downto 0);
			variable state_flag 			: state_flag_t;
			variable cam_address_onehot_inv_minus1			: std_logic_vector(CAM_SIZE-1 downto 0);
			variable cam_address_onehot_inv_minus1_flip		: std_logic_vector(CAM_SIZE-1 downto 0);
			variable cam_address_onehot_inv_minus1_flip_and	: std_logic_vector(CAM_SIZE-1 downto 0);
		begin
			
--			gen_next : for i in 0 to CAM_SIZE-1 loop
--				state_flag(i)		:= i_cam_address_onehot(i) & cam_address_onehot_current(i) & cam_address_onehot_current_lsb(i);
--				case (state_flag(i)) is
--					when "000" => -- do not trim, pass-through '0' 
--						o_cam_address_onehot_next(i)		<= '0';
--					when "110" => -- trim msb
--						o_cam_address_onehot_next(i)		<= '0';
--					when "011" => -- trim lsb
--						o_cam_address_onehot_next(i)		<= '0';
--					when "111" => -- lsb and msb equal, still trim this bit
--						o_cam_address_onehot_next(i)		<= '0';
--					when "010" => -- do not trim, pass-through '1'
--						o_cam_address_onehot_next(i)		<= '1';
--					when others =>
--						o_cam_address_onehot_next(i)		<= 'X';
--				end case;
--			end loop gen_next;


			
--			for i in 0 to CAM_SIZE-1 loop
--				cam_address_onehot_inv(i)		<= cam_address_onehot(CAM_SIZE-1-i);
--			end loop;
			-- calculate the next onehot without lsb '1'
			-- (wrong here) 110-1 = 101, not 100. 
			--cam_address_onehot_inv_minus1			:= std_logic_vector(to_unsigned( to_integer(unsigned(cam_address_onehot))-1 , o_cam_address_onehot_next'length ));
--			cam_address_onehot_inv_minus1_flip		:= not cam_address_onehot_inv_minus1;
--			cam_address_onehot_inv_minus1_flip_and	:= cam_address_onehot_inv_minus1_flip and cam_address_onehot;
--			
			gen_next : for i in 0 to CAM_SIZE-1 loop
				state_flag(i)		:= i_cam_address_onehot(i) & cam_address_onehot_current_lsb(i);
				case (state_flag(i)) is
					when "10" =>
						o_cam_address_onehot_next(i)		<= '1';
					when "11" =>
						o_cam_address_onehot_next(i)		<= '0';
					when "00" =>
						o_cam_address_onehot_next(i)		<= '0';
					when others =>
						o_cam_address_onehot_next(i)		<= 'X';
				end case;
			end loop gen_next;
--			o_cam_address_onehot_next		<= cam_address_onehot_inv_minus1;
		end process;

end architecture rtl;





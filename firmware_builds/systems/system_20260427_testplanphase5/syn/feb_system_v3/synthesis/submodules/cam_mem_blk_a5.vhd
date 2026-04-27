-- File name: cam_mem.vhd 
-- Author: Yifeng Wang
-- Revision: 1.0 (file created)
--		Date: August 28, 2023
-- Revision: 2.0 (add two implementations of BRAM types)
--		Date: August 28, 2023
-- Description:	Instantiate the Intel M10K BRAM on Arria V.
--
--		Two implementations: 1) Simple Dual-Port RAM, 2) True Dual-Port RAM. Type 1) is larger, but does not
--		allow read-during-write (old). 
--		1)
--		Generic for the CAM of 32 x 8. Write port: 8k x 1; Read port: 256 x 32. [words x data_width_in_bits] 
-- 		Possible CAM size: 32 x 8, 16 x 9, 8 x 10, 4 x 11, 2 x 12, 1 x 13.
--				
--		2)
--		Possible CAM size: ## x #, 16 x 9, 8 x 10, 4 x 11, 2 x 12, 1 x 13. (# indicates non-supporting size)
--
--     Note: this file is modified from		
	-- 	   Quartus Prime VHDL Template:
	--
		-- "Simple Dual-Port RAM with separate read and write addresses and data widths
		-- that are controlled by the parameters RW and WW.  RW and WW must specify a
		-- read/write ratio that's supported by the memory blocks in your target
		-- device.  Otherwise, no RAM will be inferred."

library ieee;
use ieee.std_logic_1164.all;
use IEEE.math_real.log2;
use IEEE.math_real.ceil;
use work.cam_helper_pkg.all;

entity cam_mem_blk_a5 is
    
	generic (
		WORDS : natural := 256;
		RW    : natural := 32;
		WW    : natural := 1);

	port (
		we    : in std_logic;
		clk   : in std_logic;
		waddr : in natural range 0 to (WORDS * cam_max(RW, WW)) / WW - 1; -- 256x32=8k
		wdata : in std_logic_vector(WW - 1 downto 0); -- 1
		raddr : in natural range 0 to (WORDS * cam_max(RW, WW)) / RW - 1; -- 256
		q     : out std_logic_vector(RW - 1 downto 0)); -- 32

end cam_mem_blk_a5;

architecture rtl_simple_dpram of cam_mem_blk_a5 is

	constant B : natural := cam_min(RW, WW); -- 1
	constant R : natural := cam_max(RW, WW)/B; -- 32

	-- Use a multidimensional array to model mixed-width 
	type word_t is array(R - 1 downto 0) of std_logic_vector(B - 1 downto 0);
	type ram_t is array (0 to WORDS - 1) of word_t;

	signal ram : ram_t; -- 256 x 32 x (1)
    
begin  -- rtl

	-- Must handle read < write and write > read separately 
	smaller_read: if RW < WW generate
		signal wdata_local : word_t;
	begin 

		-- Re-organize the write data to match the RAM word type
		unpack: for i in 0 to R - 1 generate    
			wdata_local(i) <= wdata(B*(i+1) - 1 downto B*i);
		end generate unpack;

		process(clk, we)
		begin
			if(rising_edge(clk)) then 
				if(we = '1') then
					ram(waddr) <= wdata_local;
				end if;
				q <= ram(raddr / R )(raddr mod R);
			end if;
		end process;  
	end generate smaller_read;

	not_smaller_read: if RW >= WW generate
		signal q_local : word_t;
	begin

		-- Re-organize the read data from the RAM to match the output
		unpack: for i in 0 to R - 1 generate    
			q(B*(i+1) - 1 downto B*i) <= q_local(i);
		end generate unpack;
        
		process(clk, we)
		begin
			if(rising_edge(clk)) then 
				if(we = '1') then
					ram(waddr / R)(waddr mod R) <= wdata;
				end if;
				q_local <= ram(raddr);
			end if;
		end process;  
	end generate not_smaller_read;

end architecture rtl_simple_dpram;


-- ===========================================================================================
-- Below is for the true-dual port RAM. This is one size smaller. So, 32x8 CAM is not supported, rather 16x9 CAM is.

architecture rtl_true_dpram of cam_mem_blk_a5 is

	-- derive missing generics 
	constant DATA_WIDTH1 	: natural := 1;
	constant ADDRESS_WIDTH1	: natural := integer(ceil(log2(real(WORDS))))*integer(ceil(log2(real(RW))));
	constant ADDRESS_WIDTH2	: natural := integer(ceil(log2(real(WORDS))));
	-- existing generics
	constant RATIO       : natural := 2 ** (ADDRESS_WIDTH1 - ADDRESS_WIDTH2);
	constant DATA_WIDTH2 : natural := DATA_WIDTH1 * RATIO;
	constant RAM_DEPTH   : natural := 2 ** ADDRESS_WIDTH2;
	-- define missing ports as signals
	signal we1, we2			: std_logic;
	signal addr1 			: natural range 0 to (2 ** ADDRESS_WIDTH1 - 1);
	signal addr2 			: natural range 0 to (2 ** ADDRESS_WIDTH2 - 1);
	signal data_in1 		: std_logic_vector(DATA_WIDTH1 - 1 downto 0);
	signal data_in2 		: std_logic_vector(DATA_WIDTH2 - 1 downto 0);
	signal data_out1   		: std_logic_vector(DATA_WIDTH1 - 1 downto 0);
	signal data_out2   		: std_logic_vector(DATA_WIDTH1 * 2 ** (ADDRESS_WIDTH1 - ADDRESS_WIDTH2) - 1 downto 0);

	-- Use a multidimensional array to model mixed-width 
	type word_t is array(RATIO - 1 downto 0) of std_logic_vector(DATA_WIDTH1 - 1 downto 0);
	type ram_t is array (0 to RAM_DEPTH - 1) of word_t;

	-- declare the RAM
	signal ram : ram_t;

	signal d2_local : word_t;
	signal q2_local : word_t;

begin  -- rtl

	-- derive missing ports
	we1 		<= we;
	we2 		<= '0';
	addr1 		<= waddr;
	addr2 		<= raddr;
	data_in1 	<= wdata;
	data_in2 	<= (others=>'0');
	q			<= data_out2;
	
	-- Re-organize the write data to match the RAM word type
	unpack: for i in 0 to RATIO - 1 generate    
		d2_local(i) <= data_in2(DATA_WIDTH1*(i+1) - 1 downto DATA_WIDTH1*i);
		data_out2(DATA_WIDTH1*(i+1) - 1 downto DATA_WIDTH1*i) <= q2_local(i);
	end generate unpack;

	--port B (explicitly read port)
	process(clk)
	begin
		if(rising_edge(clk)) then 
			if(we2 = '1') then
				ram(addr2) <= d2_local;
			end if;
			q2_local <= ram(addr2);
		end if;
	end process;

	-- port A (explicitly write port)
	process(clk)
	begin
		if(rising_edge(clk)) then 
			data_out1 <= ram(addr1 / RATIO )(addr1 mod RATIO);
			if(we1 ='1') then
				ram(addr1 / RATIO)(addr1 mod RATIO) <= data_in1;
			end if;
		end if;
	end process;  
end architecture rtl_true_dpram;

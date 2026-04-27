-- File name: cam_mem_a5.vhd 
-- Author: Yifeng Wang
-- Revision: 1.0 (file created)
--		Date: August 28, 2023
-- Revision: 2.0 (add two implementations of BRAM types)
--		Date: August 28, 2023
-- Revision: 3.0 (extend to the full-size of M10K BRAM)
--		Date: August 29, 2023
-- Revision: 4.0 (feat. width and depth expansion)
--		Date: August 30, 2023
-- Description:	Initiate the Intel M10K BRAM on Arria V.
-- Description:	CAM := Input = search keyword, output = address. 
-- 				Init the Intel RAM IP for the CAM customized IP core. Control the erase and in/out signals to the ram block.
--				WARNING: REG OUTPUT, so the lookup latency is 2
-- altera vhdl_input_version vhdl_2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;
use IEEE.math_real.ceil;

entity cam_mem_a5 is
	generic (
		CAM_SIZE 			: natural := 128; -- 32 -> 128
		CAM_WIDTH			: natural := 16; -- 8 -> 16
		WR_ADDR_WIDTH		: natural := 7;
		RAM_TYPE			: string := "Simple Dual-Port RAM"
		
		); -- "True Dual-Port RAM"
	
	port (
		i_clk 				: in	std_logic;
		i_rst				: in	std_logic := '1';
		i_erase_en			: in 	std_logic := '0';
		i_wr_en				: in	std_logic := '0';
		i_wr_data			: in	std_logic_vector(CAM_WIDTH-1 downto 0); -- 8 -> 16
		i_wr_addr			: in 	std_logic_vector(WR_ADDR_WIDTH-1 downto 0); -- 5 -> 7
		i_cmp_din			: in	std_logic_vector(CAM_WIDTH-1 downto 0); -- 8 -> 16
		o_match_addr		: out	std_logic_vector(CAM_SIZE-1 downto 0) -- 7 [encoded] | (32 -> 128)[unencoded]
	); 
end cam_mem_a5;

architecture rtl of cam_mem_a5 is

	-- large CAM dimensions
	constant CAM_DATA_BITS			: natural := CAM_WIDTH; -- 16
	constant CAM_ADDR_BITS			: natural := integer(ceil(log2(real(CAM_SIZE)))); -- 7
	-- sub-CAM dimensions -- fixed to be (32 x 8)
	constant SUB_CAM_DATA_BITS		: natural := 8; 
	constant SUB_CAM_ADDR_BITS		: natural := 5; 
	constant SUB_CAM_SIZE			: natural := 32; 
	-- derive the required sub-CAM config
	constant DEPTH_FACTOR			: natural := CAM_SIZE/32; -- 4
	constant WIDTH_FACTOR			: natural := CAM_WIDTH/8; -- 2
	constant ADDR_PAGE_BITS			: natural := DEPTH_FACTOR; -- 4 
	constant DATA_PAGE_BITS			: natural := integer(ceil(log2(real(WIDTH_FACTOR)))); -- 1
	-- sub-CAM ports width -- fixed
	constant WR_PORT_ADDR_BITS	: natural := SUB_CAM_DATA_BITS + SUB_CAM_ADDR_BITS; -- 8+5=13
	constant WR_PORT_DATA_BITS	: natural := 1; 
	constant RD_PORT_ADDR_BITS	: natural := SUB_CAM_DATA_BITS; -- 8
	constant RD_PORT_DATA_BITS	: natural := 2**SUB_CAM_ADDR_BITS; -- 32
	-- for RAM_IP
	constant RAM_SIZE_WORDS		: natural := 2**SUB_CAM_DATA_BITS; -- 256
	-- general signals
	signal clk, rst		: std_logic;
	signal wr_en		: std_logic_vector(0 downto 0);
	signal erase_en		: std_logic;
	-- CAM miscellaneous
	type data_paged_t	is array(WIDTH_FACTOR-1 downto 0) of std_logic_vector(SUB_CAM_DATA_BITS-1 downto 0); -- 2x(8)
	type addr_paged_t	is array(DEPTH_FACTOR-1 downto 0) of std_logic_vector(SUB_CAM_ADDR_BITS-1 downto 0);	-- 4x(5)
	type addr_matrix_t	is array(WIDTH_FACTOR-1 downto 0) of addr_paged_t; -- 2x4x(5)
	signal wr_data		: data_paged_t; -- 2x(8)
	signal wr_addr		: std_logic_vector(CAM_ADDR_BITS-1 downto 0); -- 7
	type waddr_to_ram_t	is array(WIDTH_FACTOR-1 downto 0) of std_logic_vector(WR_PORT_ADDR_BITS-1 downto 0);
	signal waddr_to_ram	: waddr_to_ram_t;
	signal CMP_DIN		: data_paged_t;
	signal MATCH_ADDR	: std_logic_vector(DEPTH_FACTOR*SUB_CAM_SIZE-1 downto 0); -- 128
	signal wr_addr_page 		: std_logic_vector(ADDR_PAGE_BITS-1 downto 0); -- 4, one-hot
	signal wr_addr_subcam		: std_logic_vector(SUB_CAM_ADDR_BITS-1 downto 0); -- 5
	type une_addr_t		is array(DEPTH_FACTOR-1 downto 0) of std_logic_vector(RD_PORT_DATA_BITS-1 downto 0); -- 4x(32)
	type une_addr_t2	is array(WIDTH_FACTOR-1 downto 0) of une_addr_t; -- 2x4x(32)
	type une_addr_t3	is array(WIDTH_FACTOR-2 downto 0) of une_addr_t; -- 1x4x(32), NOT USED when WIDTH_FACTOR<=2
	signal une_addr				: une_addr_t2; -- 2x4x(32)
	signal une_addr_bond 		: une_addr_t; -- 4x(32)
	signal une_addr_bond_temp	: une_addr_t3; -- in case of WIDTH_FACTOR=4, 2x4x(32)
	type sum_addr_t		is array(DEPTH_FACTOR-1 downto 0) of natural;
	signal sum_addr				: sum_addr_t; -- 4x(natural)
	--signal match_flag_subcam	: std_logic_vector(DEPTH_FACTOR-1 downto 0); -- (4)
	--signal match_flag,match_flag_reg			: std_logic;
	--signal match_addr_int		: natural;
	signal match_addr_unreg		: std_logic_vector(DEPTH_FACTOR*SUB_CAM_SIZE-1 downto 0); -- (128)
	signal sub_cam_we			: std_logic_vector(DEPTH_FACTOR-1 downto 0); -- (4)
	signal sub_cam_wrdata		: std_logic_vector(0 downto 0);
	-- Intermediate natural signals for port maps (avoid to_integer of metavalues in port map expressions)
	type nat_arr_t is array(WIDTH_FACTOR-1 downto 0) of natural;
	signal raddr_nat			: nat_arr_t := (others => 0);
	signal waddr_nat			: nat_arr_t := (others => 0);

	-- Safe conversion: returns 0 if vector contains metavalues
	function safe_to_nat(v : std_logic_vector) return natural is
	begin
		for i in v'range loop
			if v(i) /= '0' and v(i) /= '1' then
				return 0;
			end if;
		end loop;
		return to_integer(unsigned(v));
	end function;

begin
	
	clk <= i_clk;
	rst <= i_rst;
	erase_en	<= i_erase_en;
	wr_en(0) 	<= i_wr_en;
	sub_cam_wrdata(0) <= wr_en(0) when erase_en='0' else '0'; -- always write '1' when not erase
	-- sub-cam we, controlled by overall i_we_en
	gen_sub_cam_we: for i in 0 to DEPTH_FACTOR-1 generate -- if erase or write, addr page is transparent
		sub_cam_we(i) <= wr_addr_page(i) when wr_en(0)='1' or erase_en='1' else '0';
	end generate gen_sub_cam_we;
	
	-- re-organize the input to mapped to sub-cams 
	-- for wr_data: just paged/warped
	wr_data_encode : for i in 0 to WIDTH_FACTOR-1 generate -- 0 to 1
		wr_data(i) <= i_wr_data(SUB_CAM_DATA_BITS*(i+1)-1 downto SUB_CAM_DATA_BITS*i);
	end generate wr_data_encode;
	-- for wr_addr -> wr_addr_page / wr_addr_subcam 
	wr_addr			<= i_wr_addr;
	wr_addr_subcam	<= wr_addr(SUB_CAM_ADDR_BITS-1 downto 0); -- 5
	-- === Binary to One-Hot begin ===
	wr_addr_page_encode : for i in 0 to ADDR_PAGE_BITS-1 generate -- slv(2bit) to integer to one-hot(4bit)
		wr_addr_page(i) <= '1' when (to_integer(unsigned(wr_addr(CAM_ADDR_BITS-1 downto SUB_CAM_ADDR_BITS))))=i else '0'; -- 6 downto 5
	end generate wr_addr_page_encode;
	-- === Binary to One-Hot end ===
	cat_waddr_to_ram : for i in 0 to WIDTH_FACTOR-1 generate -- 0 to 1 -- sub-cam in a row has same address but different din segment
		waddr_to_ram(i) <= wr_data(i) & wr_addr_subcam;
	end generate cat_waddr_to_ram;
	
	-- for CMP_DIN: just paged/warped
		-- input search keyword to the CAM!
	CMP_DIN_encode : for i in 0 to WIDTH_FACTOR-1 generate -- 0 to 1
		CMP_DIN(i) <= i_cmp_din(SUB_CAM_DATA_BITS*(i+1)-1 downto SUB_CAM_DATA_BITS*i);
	end generate CMP_DIN_encode;
	
	-- for MATCH_ADDR
	-- output search result from the CAM!
	-- to be encoded outside of this entity
	addr_bond : if WIDTH_FACTOR>2 generate -- for example: n(WIDTH_FACTOR)=4 
		-- to be tested...
		g3: for i in 0 to DEPTH_FACTOR-1 generate 
			g4: for j in 0 to RD_PORT_DATA_BITS-1 generate -- bond the first two columns
				une_addr_bond_temp(0)(i)(j) <= une_addr(0)(i)(j) and une_addr(1)(i)(j);
			end generate g4;
		end generate g3;
		g5: for n in 0 to WIDTH_FACTOR-3 generate -- 0 to 1
			g6: for a in 0 to DEPTH_FACTOR-1 generate
				g7: for b in 0 to RD_PORT_DATA_BITS-1 generate -- bond third and onward with the first two columns (cascade)
					une_addr_bond_temp(n+1)(a)(b) <= une_addr_bond_temp(n)(a)(b) and une_addr(n+2)(a)(b);
				end generate g7;
			end generate g6;
		end generate g5;
		une_addr_bond <= une_addr_bond_temp(WIDTH_FACTOR-2); -- select the end of this cascade bond
	elsif WIDTH_FACTOR=2 generate -- this case was verified
		g1: for a in 0 to DEPTH_FACTOR-1 generate 
			g2: for b in 0 to RD_PORT_DATA_BITS-1 generate -- bond two columns
				une_addr_bond(a)(b) <= une_addr(0)(a)(b) and une_addr(1)(a)(b); 
			end generate g2;
		end generate g1;
	else generate -- width = 1
		g8: for a in 0 to DEPTH_FACTOR-1 generate -- there is only one column
			g9: for b in 0 to RD_PORT_DATA_BITS-1 generate 
				une_addr_bond(a)(b) <= une_addr(0)(a)(b); 
			end generate g9;
		end generate g8;
	end generate addr_bond;
	
	-- concatenate the match_addr
	cat_match_addr : for i in 0 to DEPTH_FACTOR-1 generate 
		match_addr_unreg((i+1)*RD_PORT_DATA_BITS-1 downto i*RD_PORT_DATA_BITS) <= une_addr_bond(i);
	end generate cat_match_addr;
	
	-- reg the address output (MATCH_ADDR) [overall search latency = 1]
	process(clk,rst)
	begin
		if (rst='1') then
			MATCH_ADDR <= (others=>'0');
		elsif rising_edge(clk) then
			MATCH_ADDR <= match_addr_unreg;
		end if;
	end process;
	
	o_match_addr <= MATCH_ADDR;

	-- Safe address conversion (avoids to_integer of metavalues in port map)
	gen_addr_conv: for i in 0 to WIDTH_FACTOR-1 generate
		raddr_nat(i) <= safe_to_nat(CMP_DIN(i));
		waddr_nat(i) <= safe_to_nat(waddr_to_ram(i));
	end generate gen_addr_conv;

	sub_cam: for i in 0 to WIDTH_FACTOR-1 generate
		sub_cam2: for j in 0 to DEPTH_FACTOR-1 generate
			ram_block : entity work.cam_mem_blk_a5(rtl_simple_dpram)
			generic map(
				WORDS => RAM_SIZE_WORDS, -- 256
				RW    => RD_PORT_DATA_BITS, -- 32
				WW    => WR_PORT_DATA_BITS) -- 1
			port map(
				clk   				=> clk,
				we   				=> sub_cam_we(j),	-- 1
				waddr 				=> waddr_nat(i), -- 8+5
				wdata 				=> sub_cam_wrdata, -- 1
				raddr 				=> raddr_nat(i), -- 8
				q   				=> une_addr(i)(j)); -- 32
		end generate sub_cam2;
	end generate sub_cam;

	
end architecture rtl;





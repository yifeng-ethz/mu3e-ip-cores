-- Sort hits by timestamp
-- New version for up to 45 input links and with memory for counter transmission
-- November 2019
-- niberger@uni-mainz.de

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mupix.all;
use work.mudaq.all;

entity hitsorter_scint_tb is
end entity;

architecture rtl of hitsorter_scint_tb is

constant WRITECLK_PERIOD : time := 10 ns;
constant READCLK_PERIOD  : time := 8 ns;
constant REGCLK_PERIOD   : time := 6.3 ns;

signal		reset_n							: std_logic;										-- async reset
signal		writeclk						: std_logic;										-- clock for write/input side
signal 		tsclk							: std_logic;										-- clock for ts generation
signal		running							: std_logic;
signal		currentts						: ts_t;
signal		hit_in							: hit_array;
signal		hit_ena_in						: std_logic_vector(NCHIPS-1 downto 0);			-- valid hit
signal		readclk							: std_logic;										-- clock for read/output side
signal		data_out						: reg32;										-- packaged data out
signal		out_ena							: STD_LOGIC;									-- valid output data
signal		out_type						: std_logic_vector(3 downto 0);
signal 		diagnostic_out					: sorter_reg_array;
signal		counter							: std_logic_vector(7 downto 0);
signal		localts							: ts_t;

signal 		clk156							: std_logic;
signal		reset_n_regs					: std_logic;
signal		reg_add       					: std_logic_vector(15 downto 0);
signal 		reg_re        					: std_logic;
signal 		reg_rdata     					: std_logic_vector(31 downto 0);
signal		reg_we        					: std_logic;
signal 		reg_wdata     					: std_logic_vector(31 downto 0);

signal		genmode							: std_logic_vector(3 downto 0);

signal 		currentblock					: std_logic_vector(6 downto 0);

begin


    dut : entity work.hitsorter
    port map (
		reset_n							=> reset_n,
		writeclk						=> writeclk,
		running							=> running,
		currentts						=> currentts,
		hit_in							=> hit_in,
		hit_ena_in						=> hit_ena_in,
		readclk							=> readclk,
		data_out						=> data_out,
		out_ena							=> out_ena,
		out_type						=> out_type,
        i_clk156       					=> clk156,
        i_reset_n_regs  				=> reset_n_regs,
        i_reg_add       				=> reg_add,
        i_reg_re        				=> reg_re,
        o_reg_rdata    					=> reg_rdata,
        i_reg_we        				=> reg_we,
        i_reg_wdata    					=> reg_wdata
    );

wclockgen: process
begin
	writeclk	<= '0';
	wait for WRITECLK_PERIOD/2;
	writeclk	<= '1';
	wait for WRITECLK_PERIOD/2;
end process;

tsclockgen: process
begin
	tsclk	<= '0';
	wait for WRITECLK_PERIOD/2;
	tsclk	<= '1';
	wait for WRITECLK_PERIOD/2;
end process;

rclockgen: process
begin
	readclk	<= '0';
	wait for READCLK_PERIOD/2;
	readclk	<= '1';
	wait for READCLK_PERIOD/2;
end process;

regclockgen: process
begin
	clk156	<= '0';
	wait for REGCLK_PERIOD/2;
	clk156	<= '1';
	wait for REGCLK_PERIOD/2;
end process;

regresetgen: process
begin
	reset_n_regs <= '0';
	wait for REGCLK_PERIOD*5;
	reset_n_regs <= '1';
	wait;
end process;
reg_re <= '0';
reg_we <= '0';
reg_add <= (others => '0');
reg_wdata <= (others => '0');

resetgen: process
begin
	reset_n <= '0';
	running <= '0';
	wait for 100 ns;
	reset_n	<= '1';
	wait for 150 ns;
	running <= '1';
	--wait for 60000 ns;
	--running <= '0';
	wait;
end process;

tsgen: process(reset_n, tsclk)
begin
if(reset_n = '0') then
	currentts	<= (others => '0');
elsif rising_edge(tsclk) then
	if(running = '1') then
		currentts 	<= currentts + '1';
	end if;
end if;
end process;

subheadtest: process(reset_n, tsclk)
begin
if(reset_n = '0') then
	currentblock	<= (others => '1');
elsif rising_edge(tsclk) then
	if(running = '1') then
		if(out_ena = '1' and data_out(31 downto 24) = X"FC")then
			currentblock 	<= data_out(22 downto 16);
			assert(data_out(22 downto 16) = currentblock + '1') report"Subheader Mismatch" severity error;
		end if;
	end if;
end if;
end process;

genmode <= "0011";

hitgen: process
begin
	counter <= (others => '0');
	localts	<= (others => '0');
	for i in NCHIPS-1 downto 0 loop
		hit_in(i)	<= (others => '0');
		hit_ena_in(i)	<= '0';
	end loop;
	wait for 100*WRITECLK_PERIOD;
	localts			<= currentts;
	wait for WRITECLK_PERIOD;
	if(genmode = "0000") then
		for i in 0 to 222048 loop
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"0";
			hit_ena_in(0)	<= '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= X"00000000";
			hit_ena_in(0)	<= '0';
			wait for 15*WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"F";
			hit_ena_in(0)	<= '1';
			counter			<= counter + '1';
			localts			<= localts +  X"10";
			wait for WRITECLK_PERIOD;
		end loop;
	elsif(genmode = "0001") then
		for i in 0 to 2048*2048 loop
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;

			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;

			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;

			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= (others => '0');
			hit_ena_in(0)	<= '0';
			hit_in(1)		<= (others => '0');
			hit_ena_in(1)	<= '0';

			counter			<= counter + '1';
			localts			<= localts +  X"10";
			wait for WRITECLK_PERIOD;
		end loop;
	elsif(genmode = "0010") then
		for i in 0 to 2048*2048 loop
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"F";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"F";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= (others => '0');
			hit_ena_in(1)	<= '0';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"F";
			hit_ena_in(0)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"F";
			hit_ena_in(0)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"F";
			hit_ena_in(0)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"F";
			hit_ena_in(0)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"F";
			hit_ena_in(0)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"F";
			hit_ena_in(0)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;

			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"F";
			hit_ena_in(0)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"F";
			hit_ena_in(0)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"F";
			hit_ena_in(0)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"F";
			hit_ena_in(0)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"F";
			hit_ena_in(0)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= (others => '0');
			hit_ena_in(0)	<= '0';
			hit_in(1)		<= (others => '0');
			hit_ena_in(1)	<= '0';
			counter			<= counter + '1';
			localts			<= localts +  X"10";
			wait for 2*WRITECLK_PERIOD;
		end loop;
	elsif(genmode = "0011") then
		for i in 0 to 32 loop
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;

			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;

			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;

			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= (others => '0');
			hit_ena_in(0)	<= '0';
			hit_in(1)		<= (others => '0');
			hit_ena_in(1)	<= '0';

			counter			<= counter + '1';
			localts			<= localts +  X"10";
			wait for WRITECLK_PERIOD;
		end loop;
		for i in 0 to 16 loop
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;

			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;

			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;

			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			counter			<= counter + '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= counter & counter & "00000" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(0)	<= '1';
			hit_in(1)		<= counter & counter & "00001" & localts(TSBLOCKRANGE) & X"7";
			hit_ena_in(1)	<= '1';
			wait for WRITECLK_PERIOD;
			hit_in(0)		<= (others => '0');
			hit_ena_in(0)	<= '0';
			hit_in(1)		<= (others => '0');
			hit_ena_in(1)	<= '0';

			counter			<= counter + '1';
			localts			<= localts +  X"10";
			wait for 3*WRITECLK_PERIOD;
		end loop;
	end if;
	wait;
end process;

end architecture;

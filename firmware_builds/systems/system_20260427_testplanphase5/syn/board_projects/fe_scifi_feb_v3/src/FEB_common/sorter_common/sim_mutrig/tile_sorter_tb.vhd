

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.mutrig.all;
use work.mutrig_hit_types.all;
use work.mudaq.all;
use work.sorter_pkg.all;


entity tile_sorter_tb is
end tile_sorter_tb;


architecture RTL of tile_sorter_tb is

constant WRITECLK_PERIOD : time := 10 ns;

constant REGCLK_PERIOD	 : time := 6.3 ns;
constant TIMESTAMPSIZE : integer := 12;
constant NSORTERINPUTS : integer := 3;

    signal i_reset_n       : std_logic;                            -- async reset
    signal i_clk        	: std_logic;                            -- clock for write/input side
    signal i_clk156         : std_logic;
    signal i_running       : std_logic;
    signal i_currentts     : std_logic_vector(TIMESTAMPSIZE-1 downto 0);  -- 12 bit ts
    signal i_hit          	: t_v_hit_presort_div(NSORTERINPUTS-1 downto 0);
    signal data_out        	: reg32;    
    signal out_ena          : std_logic;
    signal out_type         : std_logic_vector(3 downto 0);
    signal out_is_hit       : std_logic;                 
    signal i_reset_n_regs  : std_logic;
    signal i_reg_add       : std_logic_vector(15 downto 0);
    signal i_reg_re        : std_logic;
    signal o_reg_rdata     : std_logic_vector(31 downto 0);
    signal i_reg_we        : std_logic;
    signal i_reg_wdata     : std_logic_vector(31 downto 0);


    signal hcounter       : std_logic_vector(14 downto 0);

component hitsorter is
	generic (
		-- should be a multiple of 3 and not more than 15.
		NSORTERINPUTS : integer := 3;
		TIMESTAMPSIZE : integer := 12;
		IS_SORTER_TWO : integer := 0;
		DATATYPE : datatype_t := MUTRIG;
        ISMUTRIG : integer := 0
	);
    port (
        i_reset_n       : in  std_logic;                            -- async reset
        i_clk        	: in  std_logic;                            -- clock for write/input side
        i_running       : in  std_logic;
        i_currentts     : in  std_logic_vector(TIMESTAMPSIZE-1 downto 0);  -- 13 bit ts
        i_hit          	: in  t_v_hit_presort_div(NSORTERINPUTS-1 downto 0);

		data_out        : out reg32;                     			-- packaged data out
		out_ena         : out std_logic;                            -- valid output data
        out_type		: out std_logic_vector(3 downto 0);			-- start/end of an output package, hits, end of run
		out_is_hit      : out std_logic;                            -- same as out_ena, but only hits, no trailer header etc.

		i_clk156        : in  std_logic;
        i_reset_n_regs  : in  std_logic;
        i_reg_add       : in  std_logic_vector(15 downto 0);
        i_reg_re        : in  std_logic;
        o_reg_rdata     : out std_logic_vector(31 downto 0);
        i_reg_we        : in  std_logic;
        i_reg_wdata     : in  std_logic_vector(31 downto 0)--;
    );
end component;

begin

    i_dut: hitsorter
    GENERIC MAP (
        NSORTERINPUTS => 3,
        TIMESTAMPSIZE => 12,
        IS_SORTER_TWO => 0,
        DATATYPE => MUTRIG,
        ISMUTRIG => 1
    )
    PORT MAP (
        i_reset_n           => i_reset_n,
        i_clk               => i_clk,
        i_running           => i_running, 
        i_currentts         => i_currentts,
        i_hit               => i_hit,

        data_out            => data_out,
		out_ena             => out_ena,                            -- valid output data
        out_type		    => out_type,
		out_is_hit          => out_is_hit, 

        i_clk156            => i_clk156,
        i_reset_n_regs      => i_reset_n_regs,
        i_reg_add           => i_reg_add,
        i_reg_re            => i_reg_re,
        o_reg_rdata         => o_reg_rdata,
        i_reg_we            => i_reg_we,
        i_reg_wdata         => i_reg_wdata
    );

    clockgen: process
    begin
	i_clk	<= '0';
	wait for WRITECLK_PERIOD/2;
	i_clk	<= '1';
	wait for WRITECLK_PERIOD/2;
    end process;

    regclockgen: process
    begin
	i_clk156	<= '0';
	wait for REGCLK_PERIOD/2;
	i_clk156	<= '1';
	wait for REGCLK_PERIOD/2;
    end process;

    regresetgen: process
    begin
	i_reset_n_regs <= '0';
	wait for 10 ns;
	i_reset_n_regs <= '1';
	wait;
    end process;

    i_reg_re <= '0';
    i_reg_we <= '0';
    i_reg_add <= (others => '0');
    i_reg_wdata <= (others => '0');

    resetgen: process
    begin
	i_reset_n <= '0';
	i_running <= '0';
	wait for 100 ns;
	i_reset_n	<= '1';
	wait for 150 ns;
	i_running <= '1';
	wait;
    end process;

    tsgen: process(i_reset_n, i_clk)
    begin
    if(i_reset_n = '0') then
	    i_currentts	<= (others => '0');
    elsif(i_clk'event and i_clk = '1') then
	    if(i_running = '1') then
		    i_currentts 	<= i_currentts + '1';
	    end if;
    end if;
    end process;

    datagen: process
    begin
    hcounter       <= (others => '0');
    i_hit(0).valid <= '0';
    i_hit(1).valid <= '0';
    i_hit(2).valid <= '0';
	wait for 300 ns;
    i_hit(0).asic   <= X"A";
    i_hit(0).channel <= "00001";
    i_hit(0).E_CC    <= hcounter;
    hcounter         <= hcounter + '1';
    i_hit(0).T_CC_div <= i_currentts - "100";
    i_hit(0).T_CC_rem <= (others => '0');
    i_hit(0).T_Fine   <= (others => '0');
    i_hit(0).valid    <= '1';
    wait for WRITECLK_PERIOD;
    i_hit(0).asic   <= X"0";
    i_hit(0).channel <= "00000";
    i_hit(0).valid    <= '0';
    wait for WRITECLK_PERIOD;
    i_hit(0).asic   <= X"B";
    i_hit(0).channel <= "00001";
    i_hit(0).E_CC    <= hcounter;
    hcounter         <= hcounter + '1';
    i_hit(0).T_CC_div <= i_currentts - "100";
    i_hit(0).valid    <= '1';
    wait for WRITECLK_PERIOD;
    i_hit(0).asic   <= X"0";
    i_hit(0).channel <= "00000";
    i_hit(0).valid    <= '0';
    for i in 0 to 100 loop
        wait for WRITECLK_PERIOD;
        i_hit(0).asic   <= X"B";
        i_hit(0).channel <= "00001";
        i_hit(0).E_CC    <= hcounter;
        hcounter         <= hcounter + '1';
        i_hit(0).T_CC_div <= i_currentts - "100";
        i_hit(0).valid    <= '1';
        wait for WRITECLK_PERIOD;
        i_hit(0).asic   <= X"0";
        i_hit(0).channel <= "00000";
        i_hit(0).valid    <= '0';
    end loop;
	wait;
    end process;

end architecture RTL;
-- Sort hits by timestamp
-- Version Tile 125 MHz TS
-- November 2022, Niklaus Berger
-- niberger@uni-mainz.de


-- General idea: Write hits to a memory location according to their timestamp; 
-- one memory per chip, 16  slots in memory per chip and timestamp
-- After a fixed delay, the counters of how many hits there are get collected and are transferred to the
-- read side via another memory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.mutrig_hit_types.all;
use work.mupix.all;
use work.mudaq.all;
use work.sorter_pkg.all;

LIBRARY altera_mf;


entity hitsorter is
	generic (
		-- should be a multiple of 3 and not more than 15.
		NSORTERINPUTS : integer := 3;
		TIMESTAMPSIZE : integer := 13;
		g_NOTSHITSIZE : integer := 13;
		IS_SORTER_TWO : integer := 0;
		USE_TRIGGER_g : std_logic := '0';
		DATATYPE : datatype_t := MUTRIG;
        ISMUTRIG : integer := 0
	);
    port (
        i_reset_n       : in  std_logic;                            -- async reset
        i_clk        	: in  std_logic;                            -- clock for write/input side
        i_running       : in  std_logic;
        i_currentts     : in  std_logic_vector(TIMESTAMPSIZE-1 downto 0);  -- 13 bit ts
		i_hit   		: in  t_v_hit_presort_div(NSORTERINPUTS-1 downto 0) := (others => t_hit_presort_div_zero);
		i_hit_mupix     : in  hit_array := (others => (others => '0'));
		i_hit_ena_mupix : in  std_logic_vector(NSORTERINPUTS-1 downto 0) := (others => '0');  -- valid hit

		data_out        : out reg32;                     			-- packaged data out
		out_ena         : out std_logic;                            -- valid output data
        out_type		: out std_logic_vector(3 downto 0);			-- start/end of an output package, hits, end of run
		out_is_hit      : out std_logic;                            -- same as out_ena, but only hits, no trailer header etc.
		
--		avs_s0_address			: in  std_logic_vector(5 downto 0);
--		avs_s0_readdata			: out std_logic_vector(31 downto 0);
--		avs_s0_writedata		: in  std_logic_vector(31 downto 0);
--		avs_s0_waitrequest		: out std_logic;
--		avs_s0_read				: in  std_logic;
--		avs_s0_write			: in  std_logic;

		i_clk156        : in  std_logic;
        i_reset_n_regs  : in  std_logic;
        i_reg_add       : in  std_logic_vector(15 downto 0);
        i_reg_re        : in  std_logic;
        o_reg_rdata     : out std_logic_vector(31 downto 0);
        i_reg_we        : in  std_logic;
        i_reg_wdata     : in  std_logic_vector(31 downto 0)--;
    );
end hitsorter;

architecture rtl of hitsorter is

-- We create the types here in order to stay generic...
constant COUNTERMEMADDRSIZE     :  integer := 10;--9;
constant COUNTERMEMDATASIZE     :  integer := 5;
subtype COUNTERMEMSELRANGE      is integer range TIMESTAMPSIZE-1 downto COUNTERMEMADDRSIZE;
subtype COUNTERMEMADDRRANGE     is integer range COUNTERMEMADDRSIZE-1 downto 0;
constant NMEMS                  :  integer := 2**(TIMESTAMPSIZE-COUNTERMEMADDRSIZE);
constant HITSORTERBINBITS       :  integer := 4;
constant H                      :  integer := HITSORTERBINBITS;
constant HITSORTERADDRSIZE      :  integer := TIMESTAMPSIZE + HITSORTERBINBITS;
subtype TSRANGE                 is integer range TIMESTAMPSIZE-1 downto 0; -- 10 downto 0
subtype TSNONBLOCKRANGE         is integer range BITSPERTSBLOCK-1 downto 0;

-- Bit positions in the counter fifo of the sorter
subtype MEMCOUNTERRANGE        is integer range 2*NSORTERINPUTS*HITSORTERBINBITS-1 downto 0;
constant MEMOVERFLOWBIT        :  integer := 2*NSORTERINPUTS*HITSORTERBINBITS;
constant HASMEMBIT             :  integer := 2*NSORTERINPUTS*HITSORTERBINBITS+1;
subtype TSINFIFORANGE           is integer range HASMEMBIT+TIMESTAMPSIZE downto HASMEMBIT+1;
subtype TSBLOCKINFIFORANGE      is integer range TSINFIFORANGE'left downto TSINFIFORANGE'right+BITSPERTSBLOCK;
subtype TSINBLOCKINFIFORANGE    is integer range TSINFIFORANGE'right+BITSPERTSBLOCK-1  downto TSINFIFORANGE'right;
subtype SORTERFIFORANGE         is integer range TSINFIFORANGE'left downto 0;
subtype TSINBLOCKRANGE          is integer range BITSPERTSBLOCK-1 downto 0;
  
subtype ts_t is                 std_logic_vector(TIMESTAMPSIZE-1 downto 0);
subtype nots_t                  is std_logic_vector(g_NOTSHITSIZE-1 downto 0);
type nots_hit_array             is array (NSORTERINPUTS-1 downto 0) of nots_t;

type ts_array                   is array (NSORTERINPUTS-1 downto 0) of ts_t;
subtype input_bits_t             is std_logic_vector(NSORTERINPUTS-1 downto 0);

subtype doublecounter_t         is std_logic_vector(COUNTERMEMDATASIZE-1 downto 0);
type doublecounter_array        is array (NMEMS-1 downto 0) of doublecounter_t;
type doublecounter_inputarray    is array (NSORTERINPUTS-1 downto 0) of doublecounter_t;
type alldoublecounter_array     is array (NSORTERINPUTS-1 downto 0) of doublecounter_array;

subtype addr_t                  is std_logic_vector(HITSORTERADDRSIZE-1 downto 0);
subtype counter_t               is std_logic_vector(HITSORTERBINBITS-1 downto 0);

type addr_array                 is array (NSORTERINPUTS-1 downto 0) of addr_t;

subtype counteraddr_t           is std_logic_vector(COUNTERMEMADDRSIZE-1 downto 0);
type counteraddr_array          is array (NMEMS-1 downto 0) of counteraddr_t;
type counteraddr_chiparray      is array (NSORTERINPUTS-1 downto 0) of counteraddr_t;
type allcounteraddr_array       is array (NSORTERINPUTS-1 downto 0) of counteraddr_array;

type counterwren_array          is array (NMEMS-1 downto 0) of std_logic;
type allcounterwren_array       is array (NSORTERINPUTS-1 downto 0) of counterwren_array;

subtype sorterfifodata_t        is std_logic_vector(SORTERFIFORANGE);

type counter_inputs              is array (NSORTERINPUTS-1 downto 0) of counter_t;
subtype counter2_inputs          is std_logic_vector(2*NSORTERINPUTS*HITSORTERBINBITS-1 downto 0);

type hitcounter_sum3_type is array (NSORTERINPUTS/3-1 downto 0) of integer;

-- Commands from the sequencer
constant COMMANDBITS            :  integer := TIMESTAMPSIZE + HITSORTERBINBITS + 4 + 1; -- 11+4+4+1=20
constant COMMANDSCIFIASICBIT    :  integer := TIMESTAMPSIZE + HITSORTERBINBITS;
subtype command_t               is std_logic_vector(COMMANDBITS-1 downto 0);
constant COMMAND_HEADER1        :  std_logic_vector(3 downto 0) := X"8";-- & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
constant COMMAND_HEADER2        :  std_logic_vector(3 downto 0) := X"9";-- & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
constant COMMAND_SUBHEADER      :  std_logic_vector(3 downto 0) := X"C";-- & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
constant COMMAND_FOOTER         :  std_logic_vector(3 downto 0) := X"E";-- & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
constant COMMAND_DEBUGHEADER1   :  std_logic_vector(3 downto 0) := X"A";-- & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
constant COMMAND_DEBUGHEADER2   :  std_logic_vector(3 downto 0) := X"B";-- & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
subtype COMMANDRANGE is integer range COMMANDBITS-1 downto COMMANDBITS-4;
subtype COMMANDINPUTSELRANGE is integer range COMMANDBITS-2 downto COMMANDBITS-5;
subtype COMMANDBINSELRANGE is integer range COMMANDBITS-6 downto TIMESTAMPSIZE;


-- For run start/stop process
signal running_last:   std_logic;
signal running_read:   std_logic;
signal running_read_last:   std_logic;
signal running_read_last2:   std_logic;
signal running_seq:	   std_logic;

signal tslow 	: ts_t;
signal tshi  	: ts_t;
signal tsread	: ts_t;
signal tsreadmemdelay	: ts_t;

signal runstartup : std_logic;
signal runshutdown: std_logic;
signal runend	  : std_logic;

-- For hit writing process
signal hit_last1:	 t_v_hit_presort_div(NSORTERINPUTS-1 downto 0);
signal hit_last2:	 t_v_hit_presort_div(NSORTERINPUTS-1 downto 0);
signal hit_last3:	 t_v_hit_presort_div(NSORTERINPUTS-1 downto 0);
signal hit_last1_mupix:	 hit_array;
signal hit_last2_mupix:	 hit_array;
signal hit_last3_mupix:	 hit_array;
signal hit_ena_last1: std_logic_vector(NSORTERINPUTS-1 downto 0);
signal hit_ena_last2: std_logic_vector(NSORTERINPUTS-1 downto 0);
signal hit_ena_last3: std_logic_vector(NSORTERINPUTS-1 downto 0);

signal tshit : ts_array;

signal sametsafternext: input_bits_t;
signal sametsnext: input_bits_t;

signal dcountertemp	: doublecounter_inputarray;
signal dcountertemp2: doublecounter_inputarray;

-- Actual sorter memory
signal tomem : nots_hit_array;
signal frommem : nots_hit_array;
signal memwren : std_logic_vector(NSORTERINPUTS-1 downto 0);
signal waddr	: addr_array;
signal raddr	: addr_array;

-- Counter memory
signal tocmem 	: alldoublecounter_array;
signal tocmem_hitwriter 	: alldoublecounter_array;
signal fromcmem	: alldoublecounter_array;
signal fromcmem_hitreader : doublecounter_inputarray;
signal cmemreadaddr : allcounteraddr_array;
signal cmemwriteaddr : allcounteraddr_array;
signal cmemreadaddr_hitwriter : allcounteraddr_array;
signal cmemwriteaddr_hitwriter : allcounteraddr_array;
signal cmemreadaddr_hitreader : counteraddr_t;
signal addrcounterreset : counteraddr_t := (others => '0');
signal cmemwren		: allcounterwren_array;
signal cmemwren_hitwriter	: allcounterwren_array;

-- Fifo for counters to sequencer
signal reset : std_logic;
signal tofifo_counters : sorterfifodata_t;
signal fromfifo_counters : sorterfifodata_t;
signal read_counterfifo: std_logic;
signal write_counterfifo: std_logic;
signal counterfifo_almostfull: std_logic;
signal counterfifo_empty: std_logic;

signal block_nonempty_accumulate : std_logic;
signal block_empty_del2 : std_logic;

signal stopwrite : std_logic;
signal stopwrite_del1 : std_logic;
signal stopwrite_del2 : std_logic;
signal stopwrite_del3 : std_logic;

signal blockchange : std_logic;
signal blockchange_del1 : std_logic;
signal blockchange_del2 : std_logic;

constant counter2inputszero : counter2_inputs := (others => '0');

signal mem_nnonempty: std_logic_vector(3 downto 0);	-- for sim only
signal mem_neinputs	 : input_bits_t;
signal mem_neinputs2 : input_bits_t;
signal mem_countinputs: counter_inputs;
signal mem_countinputs_m1: counter2_inputs;
signal mem_countinputs_m2: counter2_inputs;
signal hashits: std_logic;
signal mem_overflow: std_logic;
signal mem_overflow_del1: std_logic;
signal mem_overflow_del2: std_logic;

signal credits: integer range -128 to 127;
signal credits32: std_logic_vector(31 downto 0);
signal credittemp : integer range -256 to 255;
signal hitcounter_sum_m3_mem : hitcounter_sum3_type;
signal hitcounter_sum_mem : integer;
signal hitcounter_sum : integer; 		-- for sim only
signal creditchange_reg : integer;		-- for sim only

signal readcommand: 	command_t;
signal readcommand_last1: command_t;
signal readcommand_last2: command_t;
signal readcommand_last3: command_t;
signal readcommand_last4: command_t;

signal readcommand_ena:	std_logic;
signal readcommand_ena_last1:	std_logic;
signal readcommand_ena_last2:	std_logic;
signal readcommand_ena_last3:	std_logic;
signal readcommand_ena_last4:	std_logic;

signal outoverflow:	std_logic_vector(15 downto 0);
signal overflow_last1:	std_logic_vector(15 downto 0);
signal overflow_last2:	std_logic_vector(15 downto 0);
signal overflow_last3:	std_logic_vector(15 downto 0);
signal overflow_last4:	std_logic_vector(15 downto 0);

signal header_counter: std_logic_vector(15 downto 0);
signal subheader_counter: std_logic_vector(15 downto 0);

signal memmultiplex: nots_t;
signal tscounter : std_logic_vector(47-11 downto 0); --we could only in 16us so we dont need the lower 11 bits
signal sendtscounter : std_logic_vector(47 downto 0); --47 bit, LSB would run at double frequency, but not needed

-- end of run sequence on output side
signal terminate_output : std_logic;
signal terminated_output : std_logic;

signal debug_subheadercounter : std_logic_vector(15 downto 0);
signal debug_hitcounter 	  : std_logic_vector(15 downto 0);

-- diagnostics
signal noutoftime       : reg32array(NSORTERINPUTS-1 downto 0);
signal noverflow        : reg32array(NSORTERINPUTS-1 downto 0);
signal nintime          : reg32array(NSORTERINPUTS-1 downto 0);
signal nout             : reg32;
signal delay            : ts_t;

-- copy of diagnostics (timing)
signal noutoftime2: reg32array(NSORTERINPUTS-1 downto 0);
signal noverflow2 : reg32array(NSORTERINPUTS-1 downto 0);
signal nintime2   : reg32array(NSORTERINPUTS-1 downto 0);
signal nout2      : reg32;

signal sorter_debug : reg32;

constant TSONE : ts_t := (TIMESTAMPSIZE-1 downto 1 => '0') & "1";--"0000000000001";
constant TSZERO : ts_t := (others => '0');--"0000000000000";
constant WINDOWSIZE : ts_t := (TIMESTAMPSIZE-1 => '1', others => '0');--"1000000000000";
constant READOFFSET : ts_t := (TIMESTAMPSIZE-3 => '1', 1 => '1', 0 => '1', others => '0');--"0010000000011";

signal qsys_avs_s0_address			: std_logic_vector(5 downto 0);
signal qsys_avs_s0_readdata			: std_logic_vector(31 downto 0);
signal qsys_avs_s0_writedata		: std_logic_vector(31 downto 0);
signal qsys_avs_s0_waitrequest		: std_logic;
signal qsys_avs_s0_read				: std_logic;
signal qsys_avs_s0_write			: std_logic;

begin
	
--	qsys_avs_s0_address		<= avs_s0_address;
--	avs_s0_readdata			<= qsys_avs_s0_readdata;
--	qsys_avs_s0_writedata	<= avs_s0_writedata;
--	avs_s0_waitrequest		<= qsys_avs_s0_waitrequest;
--	qsys_avs_s0_read		<= avs_s0_read;
--	qsys_avs_s0_write		<= avs_s0_write;

-- Generate timestamps that define windows for writing, reading and clearing
-- Including run start and stop logic
process(i_reset_n, i_clk)
begin
if(i_reset_n = '0') then
	running_last 	<= '0';
	running_read	<= '0';
	running_read_last	<= '0';
	running_read_last2	<= '0';
	running_seq		<= '0';
	
	runstartup		<= '0';
	runshutdown		<= '0';
	runend			<= '0';
	
	tslow 		<= TSZERO;
	tshi		<= TSZERO;
	tsread		<= TSZERO;
	tsreadmemdelay <= TSZERO;
elsif (i_clk'event and i_clk = '1') then

	tsread	  <= tslow - READOFFSET;
	tsreadmemdelay <= tsread;

	running_last	<= i_running;
	running_read_last  <= running_read;
	running_read_last2	<= running_read_last;

	if(i_running = '0') then
		runstartup		<= '0';
	end if;
	
	if(i_running = '1' and running_last = '0') then
		runstartup <= '1';
	end if;
	
	if(i_running = '0' and running_last = '1') then
		runshutdown <= '1';
	end if;
	
	if(i_running = '1' and runstartup = '1') then
		tslow <= TSONE;
		tshi  <= WINDOWSIZE;
		if(i_currentts = WINDOWSIZE + delay - "11") then
			runstartup <= '0';
		end if;
	elsif(i_running = '1' and running_last = '1' and runshutdown = '0') then
		tslow <= tslow + '1';
		tshi  <= tshi  + '1';
		if(running_read = '0' and tslow >= READOFFSET) then
			running_read	<= '1';
			running_seq		<= '1';
		end if;
	elsif(runshutdown = '1') then-- shutdown sequence
		tshi  <= tshi  + '1';
		tslow <= tslow + '1';
		if(tshi = TSZERO) then
			tshi	<= TSZERO;
			if(tslow = TSZERO) then
				tslow <= tszero;
				tsread <= tsread + '1';
				
				if(tsread - "10100" = TSZERO) then
					running_read <= '0';
					runend		 <= '1';
					running_seq  <= '0';
				end if;				
			end if;
		end if;
	else
		tshi	<= TSZERO;	
		tslow 	<= TSZERO;
	end if;
end if;
end process;

-- we need to run through addresses for resetteing the memory
process(i_clk)
begin
if (i_clk'event and i_clk = '1') then
	addrcounterreset <= addrcounterreset + '1';
end if;
end process;

-- MK: @Nik: This are all multiple drivers better set them to zero as default values
-- gennomem: for i in NSORTERINPUTS-1 downto NSORTERINPUTS-ISMUTRIG-1 generate

-- 	frommem(i)	<= (others => '0');
-- 	gennocmem: for k in NMEMS-1 downto 0 generate
-- 		fromcmem(i)(k) <= (others => '0');

-- 	end generate gennocmem;
-- 	fromcmem_hitreader(i)	<=  (others => '0');
-- end generate gennomem;

-- Memory for the actual sorting
-- NOTE: -ISMUTRIG is not the best way to do this.
--		 we need this because the sorter is only designed for
--		 multiple of 3 inputs but we have 2 for Scifi
genmem: for i in NSORTERINPUTS-ISMUTRIG-1 downto 0 generate

		hsmem : altera_mf.altera_mf_components.altsyncram
		GENERIC MAP (
			address_aclr_b => "NONE",
			address_reg_b => "CLOCK1",
			clock_enable_input_a => "BYPASS",
			clock_enable_input_b => "BYPASS",
			clock_enable_output_b => "BYPASS",
			intended_device_family => "Arria V",
			lpm_type => "altsyncram",
			numwords_a => 2**HITSORTERADDRSIZE,
			numwords_b => 2**HITSORTERADDRSIZE,
			operation_mode => "DUAL_PORT",
			outdata_aclr_b => "NONE",
			outdata_reg_b => "CLOCK1",
			power_up_uninitialized => "FALSE",
			widthad_a => HITSORTERADDRSIZE,
			widthad_b => HITSORTERADDRSIZE,
			width_a => g_NOTSHITSIZE,
			width_b => g_NOTSHITSIZE,
			width_byteena_a => 1
	)
	PORT MAP (
		address_a => waddr(i),
		address_b => raddr(i),
		clock0 => i_clk,
		clock1 => i_clk,
		data_a => tomem(i),
		wren_a => memwren(i),
		q_b => frommem(i)
	);


	-- In order to have enough ports also for clearing, we divide the memories for the counters
	-- into NMEMS memories, one address holds one TS 
	gencmem: for k in NMEMS-1 downto 0 generate

		cmem:	altera_mf.altera_mf_components.altsyncram
		GENERIC MAP (
			address_aclr_b => "NONE",
			address_reg_b => "CLOCK0",
			clock_enable_input_a => "BYPASS",
			clock_enable_input_b => "BYPASS",
			clock_enable_output_b => "BYPASS",
			intended_device_family => "Arria V",
			lpm_type => "altsyncram",
			numwords_a => 2**COUNTERMEMADDRSIZE,
			numwords_b => 2**COUNTERMEMADDRSIZE,
			operation_mode => "DUAL_PORT",
			outdata_aclr_b => "NONE",
			outdata_reg_b => "UNREGISTERED",
			power_up_uninitialized => "FALSE",
			read_during_write_mode_mixed_ports => "OLD_DATA",
			widthad_a => COUNTERMEMADDRSIZE,
			widthad_b => COUNTERMEMADDRSIZE,
			width_a => COUNTERMEMDATASIZE,
			width_b => COUNTERMEMDATASIZE,
			width_byteena_a => 1
		)
		PORT MAP (
		address_a => cmemwriteaddr(i)(k),
		address_b => cmemreadaddr(i)(k),
		clock0 => i_clk,
		data_a => tocmem(i)(k),
		wren_a => cmemwren(i)(k),
		q_b => fromcmem(i)(k)
	);

	
		tocmem(i)(k)			<= (others => '0') when k = conv_integer(tsread(COUNTERMEMSELRANGE)) or i_reset_n = '0'
									else tocmem_hitwriter(i)(k);
		cmemreadaddr(i)(k)		<= 	cmemreadaddr_hitreader when 	k = conv_integer(tsread(COUNTERMEMSELRANGE))
									else cmemreadaddr_hitwriter(i)(k);
		cmemwriteaddr(i)(k)		<= 	cmemwriteaddr_hitwriter(i)(k) when i_reset_n = '0'
									else cmemreadaddr_hitreader when k = conv_integer(tsread(COUNTERMEMSELRANGE)) 
									else cmemwriteaddr_hitwriter(i)(k);
		cmemwren(i)(k)			<= 	'1' when 	k = conv_integer(tsread(COUNTERMEMSELRANGE)) or i_reset_n = '0'
									else cmemwren_hitwriter(i)(k);
	end generate gencmem;
	
	fromcmem_hitreader(i)	<= fromcmem(i)(conv_integer(tsreadmemdelay(COUNTERMEMSELRANGE)));
	
	
	-- Write side: Put hits into memory at the right place and count them
	-- TODO: make a common rec type
	g_MUTRIG_WRITE : if DATATYPE = MUTRIG generate
		process(i_reset_n, i_clk)
			variable counterfrommem : doublecounter_t;
		begin
		if (i_reset_n = '0') then
			memwren(i) <= '0';		
			noutoftime(i) 	<= (others => '0');
			nintime(i)		<= (others => '0');
			noverflow(i)	<= (others => '0');
			
			for k in NMEMS-1 downto 0 loop
				cmemwren_hitwriter(i)(k) 		<= '1';
				cmemreadaddr_hitwriter(i)(k)	<= (others => '0');
				cmemwriteaddr_hitwriter(i)(k)	<= addrcounterreset;
			end loop;

			hit_last1(i)	<= t_hit_presort_div_zero;
			hit_last2(i)	<= t_hit_presort_div_zero;
			hit_last3(i)	<= t_hit_presort_div_zero;

			sametsnext(i)		<= '0';
			sametsafternext(i)	<= '0';

			for k in NMEMS-1 downto 0 loop
				tocmem_hitwriter(i)(k) <= (others => '0');
			end loop;

			
		elsif (i_clk'event and i_clk = '1') then

			memwren(i) <= '0';

			tshit(i) 	 	<= hit_last1(i).T_CC_div(TSRANGE);
			hit_last1(i) 	<= i_hit(i);
			hit_last2(i) 	<= hit_last1(i);
			hit_last3(i) 	<= hit_last2(i);
			tomem(i) 	 	<= presort_div_to_vector_no_ts(hit_last2(i));

			for k in NMEMS-1 downto 0 loop
				cmemreadaddr_hitwriter(i)(k) <= i_hit(i).T_CC_div(COUNTERMEMADDRRANGE);
				cmemwriteaddr_hitwriter(i)(k) <= hit_last2(i).T_CC_div(COUNTERMEMADDRRANGE);
			end loop;		
			counterfrommem := fromcmem(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE)));

			for k in NMEMS-1 downto 0 loop
				cmemwren_hitwriter(i)(k) <= '0';
			end loop;
		
			-- Reading from the memory, incrementing the counter and storing it again takes three
			-- cycles, so we cannot rely on what was written to the memory for incrementing and have to deal
			-- with this out-of-memory
			-- TODO: Should this be hit last 2?
			if(hit_last1(i).valid = '1' and hit_last1(i).T_CC_div = hit_last2(i).T_CC_div) then
				sametsnext(i)	<= '1';
				sametsafternext(i)	<= '0';
			elsif(hit_last3(i).valid = '1' and hit_last1(i).T_CC_div = hit_last3(i).T_CC_div) then
				sametsnext(i)	<= '0';
				sametsafternext(i)	<= '1';
			else
				sametsnext(i) <= '0';
				sametsafternext(i)	<= '0';
			end if;

			dcountertemp2(i) <= dcountertemp(i);

			if((i_running = '1' or runshutdown = '1') and hit_last2(i).valid ='1') then -- Hit coming in during run
				if(((tshi > tslow) and (tshit(i) >= tslow and tshit(i) < tshi)) or
					((tslow > tshi) and (tshit(i) >= tslow or tshit(i) < tshi))) then
					-- Hit TS in the range we can accept
					if(sametsnext(i) = '0' and sametsafternext(i) = '0') then -- not the same memory location as the last hit
						waddr(i) 	<= tshit(i) & counterfrommem(3 downto 0);
						if(counterfrommem(3 downto 0) /= "1111") then -- no overflow yet
							memwren(i)	<= '1';
							nintime(i)	<= nintime(i) + '1';
							for k in NMEMS-1 downto 0 loop
								tocmem_hitwriter(i)(k)	<=  '0' & counterfrommem(3 downto 0) + '1';
							end loop;
							cmemwren_hitwriter(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE))) <= '1';
							dcountertemp(i)	<= '0' & counterfrommem(3 downto 0) + '1';
						else -- overflow, mark this
							noverflow(i)	<= noverflow(i) + '1';
							for k in NMEMS-1 downto 0 loop
								tocmem_hitwriter(i)(k)	<= '1' & "1111";
							end loop;
							cmemwren_hitwriter(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE))) <= '1';
							dcountertemp(i)	<= '1' & "1111";
						end if;
					elsif(sametsnext(i) = '1') then -- same memory location in last cycle
						waddr(i) 	<= tshit(i) & dcountertemp(i)(3 downto 0);
						if(dcountertemp(i)(3 downto 0) /= "1111") then -- no overflow yet
							nintime(i)	<= nintime(i) + '1';
							memwren(i)	<= '1';
							for k in NMEMS-1 downto 0 loop
								tocmem_hitwriter(i)(k)	<= '0' & dcountertemp(i)(3 downto 0) + '1';
							end loop;
							cmemwren_hitwriter(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE))) <= '1';
							dcountertemp(i)	<= '0' & dcountertemp(i)(3 downto 0) + '1';
						else -- overflow, mark this
							noverflow(i)	<= noverflow(i) + '1';
							for k in NMEMS-1 downto 0 loop
								tocmem_hitwriter(i)(k)	<= '1' & "1111";
							end loop;
							cmemwren_hitwriter(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE))) <= '1';
							dcountertemp(i)	<= '1' & "1111";
						end if;
					else -- same memory location two cycles ago
						waddr(i) 	<= tshit(i) & dcountertemp2(i)(3 downto 0);
						if(dcountertemp2(i)(3 downto 0) /= "1111") then -- no overflow yet
							nintime(i)	<= nintime(i) + '1';
							memwren(i)	<= '1';
							for k in NMEMS-1 downto 0 loop
								tocmem_hitwriter(i)(k)	<= '0' & dcountertemp2(i)(3 downto 0) + '1';
							end loop;
							cmemwren_hitwriter(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE))) <= '1';
							dcountertemp(i)	<= '0' & dcountertemp2(i)(3 downto 0) + '1';
						else -- overflow, mark this
							noverflow(i)	<= noverflow(i) + '1';
							for k in NMEMS-1 downto 0 loop
								tocmem_hitwriter(i)(k)	<= '1' & "1111";
							end loop;
							cmemwren_hitwriter(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE))) <= '1';
							dcountertemp(i)	<=  '1' & "1111";
						end if;
					end if; -- same/ not same memory location
				else -- in/out of time
					-- we have an out of time hit: some diagnosis
					noutoftime(i) <= noutoftime(i) + '1';
				end if;
			end if; -- hit coming in during run;
		end if; -- clk event
		end process;
	end generate g_MUTRIG_WRITE;

	g_MUPIX_WRITE : if DATATYPE = MUPIX generate
		process(i_reset_n, i_clk)
			variable counterfrommem : doublecounter_t;
		begin
		if (i_reset_n = '0') then
			memwren(i) <= '0';		
			noutoftime(i) 	<= (others => '0');
			nintime(i)		<= (others => '0');
			noverflow(i)	<= (others => '0');
			
			for k in NMEMS-1 downto 0 loop
				cmemwren_hitwriter(i)(k) 		<= '1'; 	
				cmemreadaddr_hitwriter(i)(k)	<= (others => '0');
				cmemwriteaddr_hitwriter(i)(k)	<= addrcounterreset;
			end loop;

			hit_last1_mupix(i)	<= (others => '0');
			hit_last2_mupix(i)	<= (others => '0');
			hit_last3_mupix(i)	<= (others => '0');

			sametsnext(i)		<= '0';
			sametsafternext(i)	<= '0';

			for k in NMEMS-1 downto 0 loop
				tocmem_hitwriter(i)(k) <= (others => '0'); 		
			end loop;

			
		elsif (i_clk'event and i_clk = '1') then

			memwren(i) <= '0';

			tshit(i) 	 		<= hit_last1_mupix(i)(TSRANGE);

			hit_last1_mupix(i) 	<= i_hit_mupix(i);
			hit_last2_mupix(i) 	<= hit_last1_mupix(i);
			hit_last3_mupix(i) 	<= hit_last2_mupix(i);

			hit_ena_last1(i)	<= i_hit_ena_mupix(i);
			hit_ena_last2(i)	<= hit_ena_last1(i);
			hit_ena_last3(i)	<= hit_ena_last2(i);

			tomem(i) 			<= hit_last2_mupix(i)(NOTSRANGE);

			for k in NMEMS-1 downto 0 loop
				cmemreadaddr_hitwriter(i)(k) <= i_hit_mupix(i)(COUNTERMEMADDRRANGE);
				cmemwriteaddr_hitwriter(i)(k) <= hit_last2_mupix(i)(COUNTERMEMADDRRANGE);
			end loop;
			counterfrommem := fromcmem(i)(conv_integer(hit_last2_mupix(i)(COUNTERMEMSELRANGE)));

			for k in NMEMS-1 downto 0 loop
				cmemwren_hitwriter(i)(k) <= '0';
			end loop;

			-- Reading from the memory, incrementing the counter and storing it again takes three
			-- cycles, so we cannot rely on what was written to the memory for incrementing and have to deal
			-- with this out-of-memory
			if(hit_ena_last2(i) = '1' and hit_last1_mupix(i)(TSRANGE) = hit_last2_mupix(i)(TSRANGE)) then
				sametsnext(i)	<= '1';
				sametsafternext(i)	<= '0';
			elsif(hit_ena_last3(i) = '1' and hit_last1_mupix(i)(TSRANGE) = hit_last3_mupix(i)(TSRANGE)) then
				sametsnext(i)	<= '0';
				sametsafternext(i)	<= '1';
			else
				sametsnext(i) <= '0';
				sametsafternext(i)	<= '0';
			end if;

			dcountertemp2(i) <= dcountertemp(i);

			if((i_running = '1' or runshutdown = '1') and hit_ena_last2(i) ='1') then -- Hit coming in during run
				if(((tshi > tslow) and (tshit(i) >= tslow and tshit(i) < tshi)) or
					((tslow > tshi) and (tshit(i) >= tslow or tshit(i) < tshi))) then
					-- Hit TS in the range we can accept
					if(sametsnext(i) = '0' and sametsafternext(i) = '0') then -- not the same memory location as the last hit
						waddr(i) 	<= tshit(i) & counterfrommem(3 downto 0);
						if(counterfrommem(3 downto 0) /= "1111") then -- no overflow yet
							memwren(i)	<= '1';
							nintime(i)	<= nintime(i) + '1';
							for k in NMEMS-1 downto 0 loop
								tocmem_hitwriter(i)(k)	<=  '0' & counterfrommem(3 downto 0) + '1';
							end loop;
							cmemwren_hitwriter(i)(conv_integer(hit_last2_mupix(i)(COUNTERMEMSELRANGE))) <= '1';
							dcountertemp(i)	<= '0' & counterfrommem(3 downto 0) + '1';
						else -- overflow, mark this
							noverflow(i)	<= noverflow(i) + '1';
							for k in NMEMS-1 downto 0 loop
								tocmem_hitwriter(i)(k)	<= '1' & "1111";
							end loop;
							cmemwren_hitwriter(i)(conv_integer(hit_last2_mupix(i)(COUNTERMEMSELRANGE))) <= '1';
							dcountertemp(i)	<= '1' & "1111";
						end if;
					elsif(sametsnext(i) = '1') then -- same memory location in last cycle
						waddr(i) 	<= tshit(i) & dcountertemp(i)(3 downto 0);
						if(dcountertemp(i)(3 downto 0) /= "1111") then -- no overflow yet
							nintime(i)	<= nintime(i) + '1';
							memwren(i)	<= '1';
							for k in NMEMS-1 downto 0 loop
								tocmem_hitwriter(i)(k)	<= '0' & dcountertemp(i)(3 downto 0) + '1';
							end loop;
							cmemwren_hitwriter(i)(conv_integer(hit_last2_mupix(i)(COUNTERMEMSELRANGE))) <= '1';
							dcountertemp(i)	<= '0' & dcountertemp(i)(3 downto 0) + '1';
						else -- overflow, mark this
							noverflow(i)	<= noverflow(i) + '1';
							for k in NMEMS-1 downto 0 loop
								tocmem_hitwriter(i)(k)	<= '1' & "1111";
							end loop;
							cmemwren_hitwriter(i)(conv_integer(hit_last2_mupix(i)(COUNTERMEMSELRANGE))) <= '1';
							dcountertemp(i)	<= '1' & "1111";
						end if;
					else -- same memory location two cycles ago
						waddr(i) 	<= tshit(i) & dcountertemp2(i)(3 downto 0);
						if(dcountertemp2(i)(3 downto 0) /= "1111") then -- no overflow yet
							nintime(i)	<= nintime(i) + '1';
							memwren(i)	<= '1';
							for k in NMEMS-1 downto 0 loop
								tocmem_hitwriter(i)(k)	<= '0' & dcountertemp2(i)(3 downto 0) + '1';
							end loop;
							cmemwren_hitwriter(i)(conv_integer(hit_last2_mupix(i)(COUNTERMEMSELRANGE))) <= '1';
							dcountertemp(i)	<= '0' & dcountertemp2(i)(3 downto 0) + '1';
						else -- overflow, mark this
							noverflow(i)	<= noverflow(i) + '1';
							for k in NMEMS-1 downto 0 loop
								tocmem_hitwriter(i)(k)	<= '1' & "1111";
							end loop;
							cmemwren_hitwriter(i)(conv_integer(hit_last2_mupix(i)(COUNTERMEMSELRANGE))) <= '1';
							dcountertemp(i)	<=  '1' & "1111";
						end if;
					end if; -- same/ not same memory location
				else -- in/out of time
					-- we have an out of time hit: some diagnosis
					noutoftime(i) <= noutoftime(i) + '1';
				end if;
			end if; -- hit coming in during run;
		end if; -- clk event
		end process;
	end generate g_MUPIX_WRITE;

end generate genmem;	

reset <= not i_reset_n;

scfifo_component : altera_mf.altera_mf_components.scfifo
        GENERIC MAP (
                add_ram_output_register => "ON",
                almost_full_value => 120,
                intended_device_family => "Arria V",
                lpm_numwords => 128,
                lpm_showahead => "OFF",
                lpm_type => "scfifo",
                lpm_width => SORTERFIFORANGE'left + 1,
                lpm_widthu => 7,
                overflow_checking => "ON",
                underflow_checking => "ON",
                use_eab => "ON"
        )
        PORT MAP (
                aclr => '0',
                clock => i_clk,
                data => tofifo_counters,
                rdreq => read_counterfifo,
                sclr => reset,
                wrreq => write_counterfifo,
                almost_full => counterfifo_almostfull,
                empty => counterfifo_empty,
                q => fromfifo_counters
        );



-- collect data for transmission to read side
-- read one line in the countermemories per cycle, condense counters and push to fifo if nonempty
process(i_reset_n, i_clk)
	variable mem_ne : std_logic;
	variable mem_ov : std_logic;
	variable mem_nonemptycount : std_logic_vector(3 downto 0);	
	variable mem_nfilled : integer;
	
	variable countersum_temp : integer;
	
	variable creditchange : integer range -2048 to 2047;
	
begin
if (i_reset_n = '0') then
	cmemreadaddr_hitreader	<= (others => '0');
	write_counterfifo <= '0';
	block_nonempty_accumulate <= '0';
	block_empty_del2	<= '0';
	
	stopwrite <= '0';
	stopwrite_del1 <= '0';	
	stopwrite_del2 <= '0';
	
	blockchange <= '0';
	blockchange_del1 <= '0';
	blockchange_del2 <= '0';
	
	credits <= 127;
	credittemp <= 127;
	for i in NSORTERINPUTS/3-1 downto 0 loop
		hitcounter_sum_m3_mem(i) <= 0;
	end loop;
	hitcounter_sum_mem <= 0;
	hitcounter_sum 		<= 0;
	
elsif (i_clk'event and i_clk = '1') then
	write_counterfifo <= '0';
	
	mem_countinputs_m1	<= (others => '0');
	mem_countinputs_m2	<= (others => '0');

	
	if(running_read = '1')then
		cmemreadaddr_hitreader	<= tsread(COUNTERMEMADDRRANGE)+'1';
		
		-- or nonempty, read counters
		mem_ov	:= '0';
		for i in NSORTERINPUTS-1 downto 0 loop
			mem_neinputs(i) 		<= or_reduce(fromcmem_hitreader(i)(3 downto 0));
			mem_countinputs(i)	<= fromcmem_hitreader(i)(3 downto 0);
			mem_ov				:= mem_ov or fromcmem_hitreader(i)(4);
		end loop;
		
		mem_overflow <= mem_ov;
	
		
		mem_nonemptycount := (others => '0');
		mem_ne := '0';

		if(running_read_last2 = '1') then
			for i in NSORTERINPUTS-1 downto 0 loop
				mem_ne := mem_ne or mem_neinputs(i);
				mem_nonemptycount := mem_nonemptycount + mem_neinputs(i);
			end loop;
			mem_nnonempty 	<= mem_nonemptycount;
		end if;
		
		blockchange	<= '0';
		if((or_reduce(tsread(TSNONBLOCKRANGE))) = '0' and running_read_last = '1') then -- no block change at startup
			blockchange <= '1';
			if(counterfifo_almostfull = '1' or credits <= 0) then
				stopwrite <= '1';
			else
				stopwrite <= '0';
			end if;
		
		end if;
		
		block_empty_del2 <= '0';
		if(blockchange_del1 = '1') then
            block_nonempty_accumulate <= mem_ne;
            if(block_nonempty_accumulate = '0')then
                block_empty_del2 <= '1';
            end if;
		else
			block_nonempty_accumulate <= mem_ne or block_nonempty_accumulate;
		end if;
		
		
		-- multiplexing of counters -- here we pack groups of three towards the LSB
		-- Even
		mem_neinputs2	<= (others => '0');
		for i in NSORTERINPUTS/3-1 downto 0 loop
			hitcounter_sum_m3_mem(i) <= conv_integer(mem_countinputs(3*i))
										+ conv_integer(mem_countinputs(3*i+1))
										+ conv_integer(mem_countinputs(3*i+2));
			if(mem_neinputs(i*3) = '1')then
				mem_countinputs_m1(H*2*3*i + H-1 downto H*2*3*i) <= mem_countinputs(3*i);
				mem_countinputs_m1(H*2*3*i + 2*H-1 downto H*2*3*i + H) <= conv_std_logic_vector(3*i+0, H);
				mem_neinputs2(i*3) <= '1';
				if(mem_neinputs(i*3+1) = '1')then
					mem_countinputs_m1(H*2*3*i + 3*H-1 downto H*2*3*i + 2*H) <= mem_countinputs(3*i+1);
					mem_countinputs_m1(H*2*3*i + 4*H-1 downto H*2*3*i + 3*H) <= conv_std_logic_vector(3*i+1, H);
					mem_neinputs2(i*3+1) <= '1';
					if(mem_neinputs(i*3+2) = '1')then
						mem_countinputs_m1(H*2*3*i + 5*H-1 downto H*2*3*i + 4*H) <= mem_countinputs(3*i+2);
						mem_countinputs_m1(H*2*3*i + 6*H-1 downto H*2*3*i + 5*H) <= conv_std_logic_vector(3*i+2, H);
						mem_neinputs2(i*3+2) <= '1';
					end if;
				elsif(mem_neinputs(i*3+2) = '1')then
					mem_countinputs_m1(H*2*3*i + 3*H-1 downto H*2*3*i + 2*H) <= mem_countinputs(3*i+2);
					mem_countinputs_m1(H*2*3*i + 4*H-1 downto H*2*3*i + 3*H) <= conv_std_logic_vector(3*i+2, H);
					mem_neinputs2(i*3+1) <= '1';
				end if;
				
			elsif(mem_neinputs(i*3+1) = '1')then
				mem_countinputs_m1(H*2*3*i + H-1 downto H*2*3*i) <= mem_countinputs(3*i+1);
				mem_countinputs_m1(H*2*3*i + 2*H-1 downto H*2*3*i + H) <= conv_std_logic_vector(3*i+1, H);
				mem_neinputs2(i*3) <= '1';
				if(mem_neinputs(i*3+2) = '1')then
					mem_countinputs_m1(H*2*3*i + 3*H-1 downto H*2*3*i + 2*H) <= mem_countinputs(3*i+2);
					mem_countinputs_m1(H*2*3*i + 4*H-1 downto H*2*3*i + 3*H) <= conv_std_logic_vector(3*i+2, H);
					mem_neinputs2(i*3+1) <= '1';
				end if;
			elsif(mem_neinputs(i*3+2) = '1')then
				mem_countinputs_m1(H*2*3*i + H-1 downto H*2*3*i) <= mem_countinputs(3*i+2);
				mem_countinputs_m1(H*2*3*i + 2*H-1 downto H*2*3*i + H) <= conv_std_logic_vector(3*i+2, H);
				mem_neinputs2(i*3) <= '1';
			end if;
		end loop;
		
		mem_overflow_del1 	<= mem_overflow;
		stopwrite_del1		<= stopwrite;
		blockchange_del1	<= blockchange;
		
		-- multiplexing of counters, step 2
		hashits <= or_reduce(mem_neinputs2);
		mem_nfilled := 0;
		countersum_temp := 0;
		mem_countinputs_m2 <= (others => '0');
		
		for i in  0 to NSORTERINPUTS/3-1 loop
			countersum_temp := countersum_temp + hitcounter_sum_m3_mem(i);
			mem_countinputs_m2(2*H*mem_nfilled + 2*3*H-1 downto 2*H*mem_nfilled) 
			<= mem_countinputs_m1(2*3*i*H + 2*3*H-1 downto 2*3*i*H);
			if(mem_neinputs2(i*3+2 downto i*3) = "001") then
				mem_nfilled := mem_nfilled + 1;
			elsif(mem_neinputs2(i*3+2 downto i*3) = "011") then
				mem_nfilled := mem_nfilled + 2;
			elsif(mem_neinputs2(i*3+2 downto i*3) = "111") then
				mem_nfilled := mem_nfilled + 3;
			end if; 
		end loop;
		hitcounter_sum_mem <= countersum_temp;
		
		
		mem_overflow_del2 	<= mem_overflow_del1;
		stopwrite_del2		<= stopwrite_del1;
		blockchange_del2	<= blockchange_del1;

		-- one more delay cycle for stopwrite, as it supresses the NEXT block
		stopwrite_del3		<= stopwrite_del2;
		
		-- we substract "100" because after read the pipeline to sum up the counters is 4 cycles long
		tofifo_counters <=  tsread - "100" & hashits & mem_overflow_del2 & mem_countinputs_m2;
		creditchange := 1;

		
		if(stopwrite_del3 = '0' and (hashits = '1' or block_empty_del2 = '1')) then
			write_counterfifo <= '1';
			if(hitcounter_sum_mem < 48) then -- limit number of hits per ts
				creditchange := creditchange - hitcounter_sum_mem;
			else
				tofifo_counters(HASMEMBIT) 		<= '1';
				tofifo_counters(MEMOVERFLOWBIT)	<= '1';
				tofifo_counters(MEMCOUNTERRANGE)	<= counter2inputszero;
				creditchange := creditchange - 1;
			end if;
						
			if(blockchange_del2 = '1') then
				creditchange := creditchange  -1;
			end if;

		elsif(stopwrite_del3 ='1' and blockchange_del2 = '1' and block_empty_del2 = '1') then -- we were overfull but just got an empty block
			write_counterfifo <= '1';
			creditchange := creditchange  -1;
		elsif(stopwrite_del3 ='1' and blockchange_del2 = '1') then -- we were overfull and have suppressed hits
			write_counterfifo <= '1';
			tofifo_counters <= tsread - "100" & "0" & "1" & counter2inputszero;
			creditchange := creditchange  -1;
		end if;
		credittemp <= credittemp + creditchange;
		creditchange_reg  <= creditchange;
		if(credittemp  + creditchange > 127) then
			credits <= 127;
			credittemp <= 127;
		elsif(credittemp +creditchange < -128) then
			credits <= -128;
			credittemp <= -128;
		else
			credits <= credittemp;
		end if;
	end if;
end if;
end process;



-- Here we generate the sequence of read commands etc.
seq:entity work.sequencer_ng 
	generic map(  
		HITSORTERBINBITS 	=> HITSORTERBINBITS,
		NSORTERINPUTS 		=> NSORTERINPUTS,
		TIMESTAMPSIZE		=> TIMESTAMPSIZE,
		ISMUTRIG			=> ISMUTRIG
	)
	port map(
		reset_n							=> i_reset_n,
		clk								=> i_clk,
		runend							=> runend,
		from_fifo						=> fromfifo_counters,
		fifo_empty						=> counterfifo_empty,
		read_fifo						=> read_counterfifo,
		outcommand						=> readcommand,
		command_enable					=> readcommand_ena,
		outoverflow						=> outoverflow
		);

-- The ouput command has the TS in the LSBs, followed by four bits hit address
-- four bits channel/chip ID and the MSB inciating command (1) or hit (0)	

-- And the reading (use writeclk for the moment, FIFO comes after)
process(i_clk, i_reset_n)
begin
if(i_reset_n = '0') then
	data_out						<= (others => '0');
	out_ena							<= '0';
	out_type						<= (others => '0');
	readcommand_ena_last1			<= '0';
	readcommand_ena_last2			<= '0';
	readcommand_ena_last3			<= '0';
	readcommand_ena_last4			<= '0';
	tscounter						<= (others => '0');
	sendtscounter					<= (others => '0');
	nout							<= (others => '0');
	terminate_output				<= '0';
	terminated_output				<= '0';
	header_counter					<= (others => '0');
	subheader_counter				<= (others => '0');
	debug_subheadercounter			<= (others => '0');
	debug_hitcounter				<= (others => '0');
	sorter_debug					<= (others => '0');
elsif(i_clk'event and i_clk = '1') then
    noutoftime2 <= noutoftime;
    noverflow2  <= noverflow;
    nintime2    <= nintime;
    nout2       <= nout;

    out_ena							<= '0';
	out_is_hit						<= '0';
	for i in NSORTERINPUTS-1 downto 0 loop
		raddr(i)							<= 	readcommand(TSRANGE) & --MSBs: Timestamp
												readcommand(COMMANDBITS-6 downto TIMESTAMPSIZE); -- LSBs: hit address in TS
	end loop;

	readcommand_last1				<= readcommand;
	readcommand_last2				<= readcommand_last1;
	readcommand_last3				<= readcommand_last2;
	readcommand_last4				<= readcommand_last3;

	readcommand_ena_last1			<= readcommand_ena;
	readcommand_ena_last2			<= readcommand_ena_last1;
	readcommand_ena_last3			<= readcommand_ena_last2;
	readcommand_ena_last4			<= readcommand_ena_last3;

	overflow_last1					<= outoverflow;
	overflow_last2					<= overflow_last1;
	overflow_last3					<= overflow_last2;
	overflow_last4					<= overflow_last3;

	out_ena							<= readcommand_ena_last4;

	if(conv_integer(readcommand_last3(COMMANDBITS-2 downto TIMESTAMPSIZE+4)) < NSORTERINPUTS) then
		memmultiplex						<= frommem(conv_integer(readcommand_last3(COMMANDBITS-2 downto TIMESTAMPSIZE+4))); -- 18 downto 15
	end if;

	if(running_seq = '1') then
		sendtscounter <= sendtscounter + '1';
	end if;

	case readcommand_last4(COMMANDBITS-1 downto COMMANDBITS-4) is
	when COMMAND_HEADER1 =>
		data_out		<= tscounter(47-11 downto 16-11);
		out_type		<= MERGER_FIFO_PAKET_START_MARKER;
	when COMMAND_HEADER2 =>
		data_out		<= tscounter(15-11 downto 0) & "000" & x"00" & header_counter;
		out_type		<= "0000";
		if(readcommand_ena_last4 = '1') then
 			header_counter <= header_counter + '1';
			tscounter <= tscounter + '1';
		end if;
	when COMMAND_DEBUGHEADER1 =>
		data_out		<= "0" & debug_subheadercounter(14 downto 0) & debug_hitcounter;
		out_type		<= "0000";
		debug_subheadercounter <= (others => '0');
		debug_hitcounter	   <= (others => '0');
	when COMMAND_DEBUGHEADER2 =>
		data_out		<= "0" & sendtscounter(30 downto 0);
		out_type		<= "0000";
	when COMMAND_SUBHEADER =>
        if ( TIMESTAMPSIZE = 11 ) then
		    data_out		<= "111111" & "000" & readcommand_last4(TIMESTAMPSIZE-1 downto 4) & overflow_last4;
		    sorter_debug	<= "111111" & "000" & readcommand_last4(TIMESTAMPSIZE-1 downto 4) & overflow_last4;
		elsif ( TIMESTAMPSIZE = 12 ) then
		    data_out		<= "111111" & "00" & readcommand_last4(TIMESTAMPSIZE-1 downto 4) & overflow_last4;
		    sorter_debug	<= "111111" & "00" & readcommand_last4(TIMESTAMPSIZE-1 downto 4) & overflow_last4;
        elsif ( TIMESTAMPSIZE = 13 ) then
		    data_out		<= "111111" & "0" & readcommand_last4(TIMESTAMPSIZE-1 downto 4) & overflow_last4;
		    sorter_debug	<= "111111" & "0" & readcommand_last4(TIMESTAMPSIZE-1 downto 4) & overflow_last4;
        end if;
        out_type		<= "0000";
		if(readcommand_ena_last4 = '1') then
 			subheader_counter <= subheader_counter + '1';
			debug_subheadercounter <= debug_subheadercounter + '1';
		end if;
	when COMMAND_FOOTER =>
		data_out 		<= header_counter & overflow_last4;
		out_type		<= MERGER_FIFO_PAKET_END_MARKER;
		if(runshutdown = '1')then
			terminate_output <= '1';
		end if;
	when others =>
						-- ts(3:0) & chipID(5:0, the upper 2 bits are 0 here since we have max. 12 links at the moment)& row(7:0) & col(7:0) & tot(4:0) & '0'
		if(DATATYPE = MUPIX)then
			data_out	<= readcommand_last4(3 downto 0) & "00" & readcommand_last4(COMMANDINPUTSELRANGE) & memmultiplex & "0";
			if ( USE_TRIGGER_g = '1' and readcommand_last4(COMMANDBITS-2 downto TIMESTAMPSIZE+4) = "1011" ) then
				-- upper two bits are from trigger MUX
				-- ts(3:0) & chipID(5:0) & "00" & trigger(18:0) & '0'
				if ( memmultiplex(20 downto 19) = "00" ) then
					data_out <= readcommand_last4(3 downto 0) & "001011" & "00" & memmultiplex(18 downto 0) & "0"; -- chipID 11
				elsif ( memmultiplex(20 downto 19) = "01" ) then
					data_out <= readcommand_last4(3 downto 0) & "001100" & "00" & memmultiplex(18 downto 0) & "0"; -- chipID 12
				elsif ( memmultiplex(20 downto 19) = "10" ) then
					data_out <= readcommand_last4(3 downto 0) & "001101" & "00" & memmultiplex(18 downto 0) & "0"; -- chipID 13
				elsif ( memmultiplex(20 downto 19) = "11" ) then
					data_out <= readcommand_last4(3 downto 0) & "001110" & "00" & memmultiplex(18 downto 0) & "0"; -- chipID 14
				end if;
			end if;
		end if;
		-- NOTE: this is scifi here
		if(DATATYPE = MUTRIG)then -- ts(3:0) & ts(12:11) & asic(2:0) & channel(4:0) & CC 1.6ns (2:0) & fine (4:0) & E-Flag & E-T (10:0) = zero at the moment
			-- NOTE: this is for debugging now to check if readcommand_last4(COMMANDINPUTSELRANGE) = asic(3:0)
            -- TODO: the memmultiplex has 29 bits and we can use the readcommand_last4(COMMANDINPUTSELRANGE) for getting the ASIC
            -- TODO: also the E-flag is missing at the moment
			-- vec(17 downto 16)  := rec.asic(1 downto 0);
			-- vec(15 downto 11)  := rec.channel;
			-- vec(10 downto  9)  := rec.T_CC_upper_div;
			-- vec( 8 downto  6)  := rec.T_CC_rem;
			-- vec( 5 downto  1)  := rec.T_Fine;
			-- vec(0)			  := rec.E_flag
			if ( IS_SORTER_TWO = 1 ) then
				data_out	<= readcommand_last4(3 downto 0) & "0" & memmultiplex(10 downto 9) & "1" & memmultiplex(17 downto 11) & memmultiplex(8 downto 0) & x"00";
			else
				data_out	<= readcommand_last4(3 downto 0) & "0" & memmultiplex(10 downto 9) & "0" & memmultiplex(17 downto 11) & memmultiplex(8 downto 0) & x"00";
			end if;
		end if;
		if(readcommand_ena_last4 = '1') then
			out_is_hit		<= '1';
			nout <= nout + '1';
			debug_hitcounter <= debug_hitcounter + '1';
		end if;
	end case;
	if(terminate_output = '1') then
		data_out 		<= (others => '0');
		out_type		<= MERGER_FIFO_RUN_END_MARKER;
		out_ena			<= '1';
		terminate_output    <= '0';
		terminated_output	<= '1';
	end if;
	if(terminated_output = '1') then
		out_ena			<= '0';
	end if;
end if;
end process;

credits32 <= conv_std_logic_vector(credits, 32);

--	e_sorter_debug_interface : entity work.reg2mm_wrp(rtl_sorter)
--	generic map(
--		ADDRESS_WIDTH			=> 6,
--		N_WRITE_REG				=> 1,
--		N_READ_REG				=> 12,
--		REG_WIDTH				=> 32
--	)
--	port map(
--		i_clk					=> i_clk,
--		i_rst					=> not i_reset_n,
		
--		o_w_regs(delay'length-1 downto 0)				=> delay,
--		i_r_regs				=> nintime2(0) & nintime2(1) & nintime2(2) & noutoftime2(0) & noutoftime2(1) & noutoftime2(2) & noverflow2(0) & noverflow2(1) & noverflow2(2) & nout2 & credits32 & sorter_debug,
		
--		avs_s0_address			=> qsys_avs_s0_address,
--		avs_s0_readdata			=> qsys_avs_s0_readdata,
--		avs_s0_writedata		=> qsys_avs_s0_writedata,
--		avs_s0_waitrequest		=> qsys_avs_s0_waitrequest,
--		avs_s0_read				=> qsys_avs_s0_read,
--  	avs_s0_write			=> qsys_avs_s0_write
--	);

e_sorter_reg_mapping: entity work.sorter_reg_mapping
	generic map (
		IS_SORTER_TWO   => IS_SORTER_TWO,
		NSORTERINPUTS	=> NSORTERINPUTS,
		TIMESTAMPSIZE	=> TIMESTAMPSIZE
	)
    port map (
        i_clk156       => i_clk156,
        i_reset_n      => i_reset_n_regs,

        i_reg_add      => i_reg_add,
        i_reg_re       => i_reg_re,
        o_reg_rdata    => o_reg_rdata,
        i_reg_we       => i_reg_we,
        i_reg_wdata    => i_reg_wdata,

        i_nintime           => nintime2,
        i_noutoftime        => noutoftime2,
        i_noverflow         => noverflow2,
        i_nout              => nout2,
        i_credit            => credits32,
		i_sorter_debug		=> sorter_debug,
        o_sorter_delay      => open -- delay--,
    );
end architecture RTL;

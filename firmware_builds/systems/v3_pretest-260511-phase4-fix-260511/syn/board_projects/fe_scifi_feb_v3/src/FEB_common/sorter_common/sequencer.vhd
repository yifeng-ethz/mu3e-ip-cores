-- Sequencer.vhd
-- Niklaus Berger, November 2019
-- niberger@uni-mainz.de
--
-- Take the front-stacked counters and bit arrays of busy timestamps to
-- create a sequence of memory adrreses to be read and multiplexer settings
-- for the read part of the hit sorter

-- The ouput command has the TS in the LSBs, followed by four bits hit address
-- four bits channel/chip ID and the MSB inciating command (1) or hit (0)


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mupix.all;

entity sequencer is
port (
	reset_n							: in std_logic; -- async reset
	clk								: in std_logic; -- clock
	from_fifo						: in sorterfifodata_t;
	fifo_empty						: in std_logic;
	read_fifo						: out std_logic;
	outcommand						: out command_t;
	command_enable					: out std_logic;
	outoverflow						: out std_logic_vector(15 downto 0)
);
end entity;

architecture rtl of sequencer is

    type state_type is (idle, header1, header2, subheader, hits, footer);
    signal state : state_type;
    signal state_last : state_type;

    signal current_block : block_t;
    constant block_max : block_t := (others => '1');
    signal block_from_fifo : block_t;


    signal fifo_reg : sorterfifodata_t;
    signal counters_reg : std_logic_vector(MEMCOUNTERRANGE);
    signal domem : std_logic;
    signal subaddr : counter_t;
    signal overflowts : std_logic_vector(15 downto 0);

    signal fifo_empty_last : std_logic;
    signal fifo_reading_last : boolean;
    signal newblocknext_reg : boolean;

    signal timesinceheader : integer;

begin

    process(reset_n, clk)
        variable do_fifo_reading : boolean;
        variable newblocknext: boolean;
    begin
        if ( reset_n = '0' ) then
            state <= idle;
            read_fifo <= '0';
            command_enable <= '0';
            outcommand <= (others => '0');
            outoverflow <= (others => '0');
            current_block <= (others => '0');
            overflowts <= (others => '0');
            domem <= '0';
            fifo_empty_last <= '1';
            timesinceheader <= 0;
        elsif rising_edge(clk) then

        read_fifo <= '0';

        fifo_empty_last <= fifo_empty;

        state_last <= state;

        do_fifo_reading := false;
        newblocknext := from_fifo(TSBLOCKINFIFORANGE) /= current_block;
        newblocknext_reg <= newblocknext;
        if(fifo_empty = '0') then
            block_from_fifo <= from_fifo(TSBLOCKINFIFORANGE);
        end if;

        if(state /= idle) then
            timesinceheader <= timesinceheader + 1;
        end if;


    	-- State machine for creating commands: We want to send a HEADER once per TS overflow, a SUBHEADER for every block
    	-- and ordered read commands for the hits, where the read commands contain both the memory address (corresponding to the TS)
    	-- and the MUX setting (corresponding to the input channel).
    	case state is
    	when idle =>
    		if(fifo_empty = '0') then -- We start when we have data in the FIFO...
    			state <= header1;
    		end if;
    	when header1 =>
    		outcommand 		<= COMMAND_HEADER1;
    		command_enable 	<= '1';
    		timesinceheader <= 0;
    		state			<= header2;
    	when header2 =>
    		outcommand 		<= COMMAND_HEADER2;
    		command_enable 	<= '1';
    		state 			<= subheader;
    		do_fifo_reading 	:= true;
    	when subheader =>
    		outcommand 					<= COMMAND_SUBHEADER;
    		outcommand(TSRANGE)			<= from_fifo(TSBLOCKINFIFORANGE) & std_logic_vector(to_unsigned(0, BITSPERTSBLOCK));
    		command_enable 				<= '1';
    		outoverflow					<= overflowts;
    		overflowts					<= (others => '0');
    		-- Look at FIFO - either it is empty or it shows a word with hits - then process them
    		-- or it is one without, then we can output the next subheader, or in case of overflow, the next header
    		if(fifo_empty = '1') then
    			do_fifo_reading 	:= true;
    			current_block		<= block_from_fifo;
    			command_enable 		<= '0';
    			current_block		<= current_block;
    		elsif(from_fifo(HASMEMBIT) = '0') then
    			do_fifo_reading 	:= true;
    			subaddr				<= (others => '0');
    			current_block		<= block_from_fifo;
    			if(block_from_fifo = block_max) then
    				state			    <= footer;
    				command_enable 		<= '0';
    			else
    				state 			<= subheader;
    			end if;
    		else
                if(from_fifo(3 downto 0) = "0001" and from_fifo(11 downto 8) = "0000") then
                    do_fifo_reading 	:= true;
                else
                    do_fifo_reading 	:= false;
                end if;
    			state				<= hits;
    			subaddr				<= "0000";
    		end if;

    	when hits =>
    		-- note here that fifo_reg contains the counters we are working on and (if ready) the fifo shows the next
    		-- active TS
    		outcommand(COMMANDBITS-1)	<= '0'; -- Hits, not a command
    		outcommand(TSRANGE)			<= fifo_reg(TSINFIFORANGE);


    		if(domem = '1') then
    			outcommand(COMMANDBITS-2 downto TIMESTAMPSIZE+4) <= counters_reg(7 downto 4);
    			outcommand(COMMANDBITS-6 downto TIMESTAMPSIZE)   <= subaddr;
    			command_enable 	<= '1';

    			if(counters_reg(3 downto 0) = "0010" and counters_reg(11 downto 8) = "0000" and fifo_empty = '0' and not newblocknext) then
    				do_fifo_reading := true;
    			end if;

                --if(counters_reg(3 downto 0) = "0001" and counters_reg(11 downto 8) = "0000" and fifo_empty = '0' and newblocknext) then
    			--	do_fifo_reading := true;
    			--end if;

                if(counters_reg(3 downto 0) = "0001" and counters_reg(11 downto 8) = "0001" and counters_reg(19 downto 16) = "0000" and fifo_empty = '0' and not newblocknext) then
    				do_fifo_reading := true;
    			end if;

    			if(counters_reg(3 downto 0) = "0001" and counters_reg(11 downto 8) = "0000") then
    			-- this is the last hit
    				if(fifo_empty = '1') then -- the fifo is empty, sit here and wait
    					command_enable <= '0';
    				elsif(newblocknext) then -- the next block is a new one
    					current_block <= block_from_fifo;
    					if(block_from_fifo = block_max) then
    						state			<= footer;
    					else
    						state 			<= subheader;
    						do_fifo_reading 	:= true;
                            --if((from_fifo(3 downto 0) = "0001" and from_fifo(11 downto 8) = "0000"  and fifo_empty = '0') -- only one hit in the next packet, move ahead
                            --or from_fifo(HASMEMBIT) = '0') then -- just a header, also move ahead
                            --    do_fifo_reading 	:= true;
                            --else
                            --    do_fifo_reading 	:= false;
                            --end if;
    					end if;
    				else -- we stay in block
                        if((from_fifo(3 downto 0) = "0001" and from_fifo(11 downto 8) = "0000") -- only one hit in the next packet, move ahead
                            or from_fifo(HASMEMBIT) = '0') then
                            do_fifo_reading 	:= true;
                        elsif((from_fifo(3 downto 0) > "0001") or (from_fifo(11 downto 8) > "0000")) then
                            do_fifo_reading 	:= false;
                        else
                            -- should not get here, read FIFO to prevent getting stuck
                            do_fifo_reading 	:= true;
                        end if;
    					subaddr				<= "0000";
    				end if;
    			elsif(counters_reg(3 downto 0) = "0001") then -- switch chip
    				counters_reg(counters_reg'left-8 downto 0)	 <= counters_reg(counters_reg'left downto 8);
    				counters_reg(counters_reg'left downto counters_reg'left-7)	 <= (others => '0');
    				subaddr					<= "0000";
    			else -- more hits from same chip
    				counters_reg <= counters_reg;
    				counters_reg(3 downto 0) <= counters_reg(3 downto 0) -'1';
    				subaddr					 <= subaddr + "1";
    			end if;
    		else --domem zero indicate a block skipped due to overflow
    			command_enable <= '0';
    			-- if we have skipped a block, set all overflows to 1
    			-- following condition should always be true in this case
    			if(fifo_reg(MEMOVERFLOWBIT) = '1') then
    				overflowts <= (others => '1');
    			end if;
    			if(fifo_empty = '1') then -- the fifo is empty, sit here and wait (unlikely as we are close to FIFO overflow)
    				command_enable <= '0';
    			elsif(newblocknext) then -- the next block is a new one
    				do_fifo_reading 	:= true;
    				current_block <= block_from_fifo;
    				if(block_from_fifo = block_max) then
    					state			<= footer;
    				else
    					state 			<= subheader;
    					do_fifo_reading 	:= true;
    				end if;
    			else
    				do_fifo_reading 	:= true;
    			end if;
    		end if;

    		-- And we should store the overflows
    		overflowts(conv_integer(fifo_reg(TSINBLOCKINFIFORANGE))) <= fifo_reg(MEMOVERFLOWBIT);
    	when footer =>
    		outcommand		<= COMMAND_FOOTER;
    		command_enable 	<= '1';
    		state			<= header1;
    		current_block	<= (others => '0');
        when others =>
            state <= idle;
    	end case;


        if(timesinceheader > 3000) then
            do_fifo_reading := true;

            if(from_fifo(TSBLOCKINFIFORANGE) = block_max and fifo_empty = '0') then
                state <= footer;
            end if;
        end if;


    	fifo_reading_last <= do_fifo_reading;

    	if(do_fifo_reading ) then --and fifo_empty='0') then
    		read_fifo 		<= '1';
        end if;
        if(fifo_reading_last and fifo_empty='0') then
    		fifo_reg		<= from_fifo;
    		counters_reg	<= from_fifo(MEMCOUNTERRANGE);
    		domem			<= from_fifo(HASMEMBIT);
    	end if;
    end if; -- clk/reset
    end process;

end architecture;

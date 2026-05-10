----------------------------------------------------------------------------
--
-- Slow Control Unit
-- Marius Koeppel, Mainz University
-- makoeppe@students.uni-mainz.de
--
-- May 2023: M.Mueller: Added MSTR bits in protocol to mask response packets in Broadcast transactions
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.feb_sc_registers.all;
use work.mudaq.all;

entity sc_rx is
generic (
    FIFO_ADDR_WIDTH_g : positive := 10--;
);
port (
    i_link_data     : in    std_logic_vector(31 downto 0);
    i_link_datak    : in    std_logic_vector(3 downto 0);
    i_fpga_type     : in    std_logic_vector(5 downto 0) := (others => '0');

    o_fifo_we       : out   std_logic;
    o_fifo_wdata    : out   std_logic_vector(35 downto 0) := (others => '0');

    o_ram_addr      : out   std_logic_vector(31 downto 0);
    o_ram_re        : out   std_logic;
    i_ram_rvalid    : in    std_logic;
    i_ram_rdata     : in    std_logic_vector(31 downto 0);
    o_ram_we        : out   std_logic;
    o_ram_wdata     : out   std_logic_vector(31 downto 0);

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic
);
end entity;

architecture arch of sc_rx is

    type state_t is (
        S_IDLE, S_ADDR, S_LENGTH, S_READ, S_WRITE,
        S_TIMEOUT, S_ERROR--,
    );
    signal state : state_t;

    signal ram_addr, ram_addr_reg, ram_addr_end : unsigned(31 downto 0);
    signal ram_read_nreq : unsigned(7 downto 0);
    
    signal r_w_non_inc : std_logic;

    signal idle_counter : unsigned(15 downto 0);
    signal sc_type : std_logic_vector(1 downto 0);
    signal MSTR_n : std_logic_vector(31 downto 0) := (others => '0');
    signal do_not_act_bit_pos : integer range 0 to 31 := 31;

begin

    do_not_act_bit_pos <= PACKET_M_BIT_POSITION when i_fpga_type = MUPIX_HEADER_ID else
                          PACKET_S_BIT_POSITION when i_fpga_type = SCIFI_HEADER_ID else
                          PACKET_T_BIT_POSITION when i_fpga_type = TILE_HEADER_ID else
                          31;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        state <= S_IDLE;

        o_fifo_we <= '0';
        o_ram_re <= '0';
        o_ram_we <= '0';
        r_w_non_inc <= '0';

        ram_read_nreq<= (others => '0');
        idle_counter <= (others => '0');
        o_fifo_wdata <= (others => '0');
        MSTR_n       <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        o_fifo_we <= '0';
        o_ram_re <= '0';
        o_ram_we <= '0';

        if ( i_link_data(7 downto 0) = x"BC" and i_link_datak = "0001"
            and i_link_data(31 downto 26) = "000111"
        ) then
            -- preamble
            sc_type <= i_link_data(25 downto 24);
--            fpga_id <= i_link_data(23 downto 8);
            state <= S_ADDR;
            --
        elsif ( state = S_ADDR and i_link_datak = "0000" ) then
            -- ack addr
            MSTR_n <= i_link_data(31 downto 24) & x"000000";
            if(i_link_data(PACKET_R_BIT_POSITION)='0') then -- we send a reply
                o_fifo_we <= '1';
                o_fifo_wdata <= sc_type & "10" & i_link_data;
            end if;

            if(i_link_data(do_not_act_bit_pos)='0') then -- we do not ignore the message
                ram_addr <= unsigned(i_link_data);
                ram_addr_reg <= unsigned(i_link_data);
                state <= S_LENGTH;
            else -- we do ignore the message
                state <= S_IDLE;
            end if;

            --
        elsif ( state = S_LENGTH and i_link_datak = "0000" ) then
            -- ack length
            if(MSTR_n(PACKET_R_BIT_POSITION)='0') then -- we send a reply
                o_fifo_we <= '1';
                o_fifo_wdata <= "0000" & X"0001" & i_link_data(15 downto 0);
            end if;

            ram_addr_end <= ram_addr + unsigned(i_link_data(15 downto 0));

            if (sc_type = PACKET_TYPE_SC_READ) then
                state <= S_READ;
                r_w_non_inc <= '0';
            elsif (sc_type = PACKET_TYPE_SC_WRITE) then
                state <= S_WRITE;
                r_w_non_inc <= '0';
            elsif (sc_type = PACKET_TYPE_SC_READ_NONINCREMENTING) then
                state <= S_READ;
                r_w_non_inc <= '1';
            elsif (sc_type = PACKET_TYPE_SC_WRITE_NONINCREMENTING) then
                state <= S_WRITE;
                r_w_non_inc <= '1';
            else
                state <= S_ERROR;
            end if;

        elsif ( state = S_WRITE and i_link_datak = "0000" ) then
            if ( ram_addr /= ram_addr_end ) then
                -- write to ram
                if ( r_w_non_inc = '0' ) then
                    o_ram_addr <= std_logic_vector(ram_addr);
                else
                    o_ram_addr <= std_logic_vector(ram_addr_reg);
                end if;
                o_ram_we <= '1';
                o_ram_wdata <= i_link_data;
                ram_addr <= ram_addr + 1;
            end if;

            if ( ram_addr = ram_addr_end ) then
                -- write end of packet
                if(MSTR_n(PACKET_R_BIT_POSITION)='0') then -- we send a reply
                    o_fifo_we <= '1';
                    o_fifo_wdata <= MERGER_FIFO_PAKET_END_MARKER & X"00000000";
                end if;
                state <= S_IDLE;
            end if;
            --
        elsif ( state = S_READ ) then
            if ( ram_addr /= ram_addr_end and ram_read_nreq /= (ram_read_nreq'range => '1') ) then
                -- read from ram
                if ( r_w_non_inc = '0' ) then
                    o_ram_addr <= std_logic_vector(ram_addr);
                else
                    o_ram_addr <= std_logic_vector(ram_addr_reg);
                end if;
                o_ram_re <= '1';
                ram_addr <= ram_addr + 1;
                ram_read_nreq <= ram_read_nreq + 1;
            end if;

            if ( ram_read_nreq /= 0 and i_ram_rvalid = '1' ) then
                -- write to fifo
                if(MSTR_n(PACKET_R_BIT_POSITION)='0') then -- we send a reply
                    o_fifo_we <= '1';
                    o_fifo_wdata <= "0000" & i_ram_rdata;
                end if;
                if ( ram_addr /= ram_addr_end and ram_read_nreq /= (ram_read_nreq'range => '1') ) then
                    ram_read_nreq <= ram_read_nreq;
                else
                    ram_read_nreq <= ram_read_nreq - 1;
                end if;
            end if;

            if ( ram_addr = ram_addr_end and ram_read_nreq = 0 ) then
                -- write end of packet
                if(MSTR_n(PACKET_R_BIT_POSITION)='0') then -- we send a reply
                    o_fifo_we <= '1';
                    o_fifo_wdata <= MERGER_FIFO_PAKET_END_MARKER & X"00000000";
                end if;
                state <= S_IDLE;
            end if;
            --
        elsif ( i_link_data = x"0000009C" and i_link_datak = "0001"
            and ( state /= S_IDLE )
        ) then
            -- trailer
            -- write end of packet
            
            if(MSTR_n(PACKET_R_BIT_POSITION)='0') then -- we send a reply
                o_fifo_we <= '1';
                o_fifo_wdata <= MERGER_FIFO_PAKET_END_MARKER & X"00000000";
            end if;
            state <= S_IDLE;
            --
        elsif ( state = S_TIMEOUT ) then
            state <= S_IDLE;
            --
        elsif ( state = S_ERROR ) then
            state <= S_IDLE;
            --
        elsif ( i_link_data = x"000000BC" and i_link_datak = "0001" ) then
            idle_counter <= idle_counter + 1;

            if ( state = S_IDLE ) then
                idle_counter <= (others => '0');
            end if;

            if ( idle_counter = (idle_counter'range => '1') ) then
                -- timeout
                state <= S_TIMEOUT;
            end if;
            --
        elsif ( state = S_IDLE ) then
            --
        else
            state <= S_ERROR;
            --
        end if;

        --
    end if;
    end process;

end architecture;

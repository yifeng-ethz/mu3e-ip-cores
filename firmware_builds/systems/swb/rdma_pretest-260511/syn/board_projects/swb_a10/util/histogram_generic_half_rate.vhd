-----------------------------------------------------------------------------
-- Generic histogram with a true dual port ram dual clock
-- Date: 08.03.2021
-- Sebastian Dittmeier, Heidelberg University
-- dittmeier@physi.uni-heidelberg.de
--
-- can take 2 consecutive data inputs, takes 4 cycles for these
-----------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity histogram_generic_half_rate is
generic (
    g_DATA_WIDTH : natural := 8;
    g_ADDR_WIDTH : natural := 6
);
port (
    -- address for readout
    i_raddr         : in    std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    -- data to be readout, appears 1 cycle after i_raddr is changed
    o_rdata         : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);
    i_rclk          : in    std_logic;   -- clock for read part

    -- further signals are in i_wclk domain
    i_ena           : in    std_logic;   -- if set to '1', and histogram is busy_n = '1', updates histogram
    i_can_overflow  : in    std_logic;   -- if set to '1', bins can overflow
    i_wdata         : in    std_logic_vector(g_ADDR_WIDTH-1 downto 0); -- data to be histogrammed, actually refers to a bin, hence addr_width
    i_valid        : in    std_logic;
    o_busy_n        : out   std_logic;  -- shows that it is ready to accept data
    i_wclk          : in    std_logic;   -- clock for write part

    -- clear memories, split this from the reset
    i_zeromem       : in    std_logic;
    -- async reset state machine
    i_reset_n       : in    std_logic--;
);
end entity;

architecture RTL of histogram_generic_half_rate is

    signal waddr, waddr_r, waddr_delay : std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    signal wdata, q, wdata_delay : std_logic_vector(g_DATA_WIDTH-1 downto 0);
    signal we, we_delay, valid_2, zero_done, add_1 : std_logic;

    type state_type is (
        zeroing, waiting, enabled, readwaiting, writing
    );
    signal state : state_type;

begin

    e_ram : entity work.ip_ram_2rw
    generic map (
        g_DATA0_WIDTH => wdata'length,
        g_ADDR0_WIDTH => waddr'length,
        g_DATA1_WIDTH => o_rdata'length,
        g_ADDR1_WIDTH => i_raddr'length--,
    )
    port map (
        i_addr0     => waddr_delay,
        i_wdata0    => wdata_delay,
        i_we0       => we_delay,
        o_rdata0    => q,
        i_clk0      => i_wclk,

        i_addr1     => i_raddr,
        o_rdata1    => o_rdata,
        i_clk1      => i_rclk--,
    );

    -- write state machine
    process(i_wclk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        o_busy_n <= '0'; -- we are busy after a reset
        state <= waiting; -- we go to a waiting state after reset
        we <= '0'; -- nothing gets written to the RAM
        valid_2 <= '0'; -- 2nd request during read wait
        zero_done <= '0';
        add_1 <= '0';
        we_delay  <= '0';
        wdata_delay <= (others => '0');
        waddr_delay <= (others => '0');
         --
    elsif rising_edge(i_wclk) then
        -- we delay to fix timing
        we_delay <= we;
        wdata_delay <= wdata;
        waddr_delay <= waddr;
        case state is
        when zeroing =>
            we      <= '1';
            wdata   <= (others => '0');
            -- coming from reset or waiting, we is '0', so we use this to write also address 0!
            if ( we = '0' ) then
                waddr   <= (others => '0'); -- reset waddr to 0
            else
                waddr   <= waddr + '1'; -- increment
            end if;

            -- coming from reset, we is '0', so we use this to write also address 0!
            if ( waddr = (waddr'range => '1') ) then  -- we will increment address to zero again
                state       <= waiting; -- we are done here
                we          <= '0'; -- don't need to write zeros again
                zero_done   <= '1';
            end if;

        when waiting =>
            o_busy_n  <= '1'; -- now we can accept data
            if ( i_ena = '1' ) then -- we are getting the signal to accept data
                state       <= enabled;
                zero_done   <= '0'; -- so once we re enter waiting from enabled, we can zero again
            end if;
            if ( i_zeromem = '1' and zero_done = '0' ) then -- zeromem has priority, can only be done from state waiting
                                                        -- and don't redo zeroing forever
                state   <= zeroing; -- once in enabled state, have to set to ena = '0'
                o_busy_n  <= '0'; -- now we cannot accept data
            end if;

        when enabled =>
            we  <= '0';
            if ( i_valid = '1' ) then   -- we get some valid data
                waddr   <= i_wdata;  -- we set the address, we want to read data!
                state   <= readwaiting;
                o_busy_n  <= '0';      -- next cycle we can still accept data, but the one after that not; account for pipe in histogram_generic
            end if;
            if ( i_ena = '0' ) then        -- go back to waiting mode, no more updates to the histogram
                state   <= waiting;
            end if;

        when readwaiting =>
            we      <= '0';
            state   <= writing;
            -- we can accept another request in the mean time
            if ( i_valid = '1' ) then   -- we get some valid data
                valid_2  <= '1';
                waddr    <= i_wdata; -- we set the address, we want to read data!
                if ( waddr = i_wdata ) then
                    add_1 <= '1';
                else
                    add_1 <= '0';
                end if;
            end if;
            waddr_r  <= waddr;   -- and have to store the address that was used in enabled for the next step!

        when writing =>     -- now q is ready for waddr set in enabled
            we     <= '1';
            if ( i_can_overflow = '0' and q = (q'range => '1') ) then
                wdata   <= q;
            elsif ( i_can_overflow = '0' and  (q+add_1) = (q'range => '1') ) then
                wdata   <= q + 1;
            else
                wdata   <= q + '1' + add_1;
            end if;
            waddr    <= waddr_r;     -- so we have to get the address back from state enabled in any case
            o_busy_n <= '1';         -- now we can accept data again

            if ( valid_2 = '1' and add_1 = '0' ) then   -- we had a second request during readwaiting
                waddr_r <= waddr;   -- and store the address from readwaiting
                valid_2 <= '0';     -- data will be valid next cycle
                state   <= writing; -- and we can write in the next one
            else        -- there was not a 2nd request, so the proper address is still valid
                state   <= enabled;
            end if;

        when others =>
            o_busy_n  <= '0';     -- sth went wrong, show busy
            we      <= '0';     -- don't write
            valid_2 <= '0';     -- clear 2nd request
            state   <= waiting; -- go back to a defined state
        end case;

    end if;
    end process;

end architecture;

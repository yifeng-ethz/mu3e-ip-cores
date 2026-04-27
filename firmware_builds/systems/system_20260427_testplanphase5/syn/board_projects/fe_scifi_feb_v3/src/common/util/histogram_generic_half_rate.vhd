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
    DATA_WIDTH : natural := 8;
    ADDR_WIDTH : natural := 6
);
port (
    rclk            : in    std_logic;   -- clock for read part
    wclk            : in    std_logic;   -- clock for write part
    rst_n           : in    std_logic;   -- async reset statemachine
    zeromem         : in    std_logic;   -- clear memories, split this from the reset
    ena             : in    std_logic;   -- if set to '1', and histogram is busy_n = '1', updates histogram
    can_overflow    : in    std_logic;   -- if set to '1', bins can overflow
    data_in         : in    std_logic_vector(ADDR_WIDTH-1 downto 0); -- data to be histogrammed, actually refers to a bin, hence addr_width
    valid_in        : in    std_logic;
    busy_n          : out   std_logic;  -- shows that it is ready to accept data

    raddr_in        : in    std_logic_vector(ADDR_WIDTH-1 downto 0); -- address for readout
    q_out           : out   std_logic_vector(DATA_WIDTH-1 downto 0) -- data to be readout, appears 1 cycle after readaddr_in is changed
);
end entity;

architecture RTL of histogram_generic_half_rate is

    signal waddr    : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal waddr_r  : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal wdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal we       : std_logic;
    signal q        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal valid_2  : std_logic;
    signal zero_done: std_logic;
    signal add_1    : std_logic;


    type   state_type is (zeroing, waiting, enabled, readwaiting, writing);
    signal state : state_type;

    constant addr_all_one : std_logic_vector(waddr'range) := (others => '1');
    constant data_all_one : std_logic_vector(q'range) := (others => '1');

begin

    e_ram : entity work.ip_ram_2rw
    generic map (
        g_DATA0_WIDTH => waddr'length,
        g_ADDR0_WIDTH => wdata'length,
        g_DATA1_WIDTH => raddr_in'length,
        g_ADDR1_WIDTH => q_out'length--,
    )
    port map (
        i_addr0     => waddr,
        i_wdata0    => wdata,
        i_we0       => we,
        o_rdata0    => q,
        i_clk0      => wclk,

        i_addr1     => raddr_in,
        o_rdata1    => q_out,
        i_clk1      => rclk--,
    );

    -- write state machine
    process(rst_n, wclk)
    begin
    if(rst_n = '0')then
        busy_n  <= '0';     -- we are busy after a reset
        state   <= waiting; -- we go to a waiting state after reset
        we      <= '0';     -- nothing gets written to the RAM
        valid_2 <= '0';     -- 2nd request during readwaiting
        zero_done<= '0';
        add_1   <= '0';

    elsif rising_edge(wclk) then
        case state is
        when zeroing =>
            we      <= '1';
            wdata   <= (others => '0');
            -- coming from reset or waiting, we is '0', so we use this to write also address 0!
            if(we = '0')then
                waddr   <= (others => '0'); -- reset waddr to 0
            else
                waddr   <= waddr + '1';   -- increment
            end if;

            -- coming from reset, we is '0', so we use this to write also address 0!
            if(waddr = addr_all_one) then  -- we will increment address to zero again
                state       <= waiting;           -- we are done here
                we          <= '0';               -- don't need to write zeros again
                zero_done   <= '1';
            end if;

        when waiting =>
            busy_n  <= '1';         -- now we can accept data
            if (ena = '1')then      -- we are getting the signal to accept data
                state       <= enabled;
                zero_done   <= '0'; -- so once we re enter waiting from enabled, we can zero again
            end if;
            if(zeromem = '1' and zero_done = '0')then   -- zeromem has priority, can only be done from state waiting
                                                        -- and don't redo zeroing forever
                state   <= zeroing; -- once in enabled state, have to set to ena = '0'
                busy_n  <= '0';     -- now we cannot accept data
            end if;

        when enabled =>
            we  <= '0';
            if(valid_in = '1')then   -- we get some valid data
                waddr   <= data_in;  -- we set the address, we want to read data!
                state   <= readwaiting;
                busy_n  <= '0';      -- next cycle we can still accept data, but the one after that not; account for pipe in histogram_generic
            end if;
            if(ena = '0')then        -- go back to waiting mode, no more updates to the histogram
                state   <= waiting;
            end if;

        when readwaiting =>
            we      <= '0';
            state   <= writing;
            -- we can accept another request in the mean time
            if(valid_in = '1')then   -- we get some valid data
                valid_2  <= '1';
                waddr    <= data_in; -- we set the address, we want to read data!
                if(waddr = data_in)then
                    add_1 <= '1';
                else
                    add_1 <= '0';
                end if;
            end if;
            waddr_r  <= waddr;   -- and have to store the address that was used in enabled for the next step!

        when writing =>     -- now q is ready for waddr set in enabled
            we     <= '1';
            if(can_overflow = '0' and (q = data_all_one))then
                wdata   <= q;
            elsif(can_overflow = '0' and (q+add_1 = data_all_one))then
                wdata   <= q + 1;
            else
                wdata   <= q + '1' + add_1;
            end if;
            waddr   <= waddr_r;     -- so we have to get the address back from state enabled in any case
            busy_n  <= '1';         -- now we can accept data again

            if(valid_2 = '1' and add_1 = '0')then   -- we had a second request during readwaiting
                waddr_r  <= waddr;   -- and store the address from readwaiting
                valid_2 <= '0';     -- data will be valid next cycle
                state   <= writing; -- and we can write in the next one
            else        -- there was not a 2nd request, so the proper address is still valid
                state   <= enabled;
            end if;

        when others =>
            busy_n  <= '0';     -- sth went wrong, show busy
            we      <= '0';     -- don't write
            valid_2 <= '0';     -- clear 2nd request
            state   <= waiting; -- go back to a defined state
        end case;

    end if;
    end process;

end architecture;

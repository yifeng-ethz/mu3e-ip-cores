-----------------------------------------------------------------------------
-- Generic histogram with a true dual port ram dual clock
-- Date: 08.03.2021
-- Sebastian Dittmeier, Heidelberg University
-- dittmeier@physi.uni-heidelberg.de
--
-- instantiates 2 histogram_generic_half_rate in order to provide
-- full rate histogramming at 100% wclk speed
-----------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity histogram_generic is
generic (
    DATA_WIDTH : natural := 8;
    ADDR_WIDTH : natural := 6
);
port (
    rclk            : in    std_logic;   -- clock for read part
    wclk            : in    std_logic;   -- clock for write part
    rst_n           : in    std_logic;   -- reset statemachine
    zeromem         : in    std_logic;   -- clear memories, split this from the reset
    ena             : in    std_logic;   -- if set to '1', and histogram is busy_n = '1', updates histogram
    can_overflow    : in    std_logic;   -- if set to '1', bins can overflow
    data_in         : in    std_logic_vector(ADDR_WIDTH-1 downto 0); -- data to be histogrammed, actually refers to a bin, hence addr_width
    valid_in        : in    std_logic;
    busy_n          : out   std_logic;  -- shows that it is ready to accept data

    raddr_in        : in    std_logic_vector(ADDR_WIDTH-1 downto 0); -- address for readout
    q_out           : out   std_logic_vector(DATA_WIDTH-1 downto 0) -- data to be readout, appears 1 cycle after raddr_in is set
);
end entity;

architecture RTL of histogram_generic is

    type histo_q_array is array (0 to 1) of std_logic_vector(DATA_WIDTH-2 downto 0);
    signal q            : histo_q_array;
    signal valid        : std_logic_vector(1 downto 0);
    signal busy_n_int   : std_logic_vector(1 downto 0);
    signal data         : std_logic_vector(ADDR_WIDTH-1 downto 0); -- one pipeline stage

begin

    gen_half_rate_histos:
    for I in 0 to 1 generate
        i_histo: entity work.histogram_generic_half_rate
        generic map (
          DATA_WIDTH => DATA_WIDTH-1,   -- only needs half the size, memory is split into two blocks
          ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            rclk          => rclk,
            wclk          => wclk,
            rst_n         => rst_n,
            zeromem       => zeromem,
            ena           => ena,
            can_overflow  => can_overflow,
            data_in       => data,    -- data can be presented to both
            valid_in      => valid(I),
            busy_n        => busy_n_int(I),

            raddr_in      => raddr_in,
            q_out         => q(I)
        );
    end generate;

    -- q_out is simply the sum of both outputs, we only do it combinatorial, so no more delay is added
    q_out   <= ('0'& q(1)) + ('0'& q(0));
    busy_n  <= busy_n_int(1) or busy_n_int(0); -- if either one of them is not busy we are fine

    -- write state machine
    process(wclk)
    begin
    if ( rst_n = '0' ) then
        valid   <= "00";    -- disable all writes
    elsif rising_edge(wclk) then
        data <= data_in;
        valid   <= "00";    -- default
        if(valid_in = '1')then  -- in principle we would do a round robin
                                -- but half rate histograms can accept to consecutive requests,
                                -- and are less efficient with 1 cycle pause
            if(busy_n_int(0) = '1')then -- so the default is the first histogram
                valid(0) <= '1';
            elsif(busy_n_int(1) = '1')then
                valid(1) <= '1';
            else
                -- error!
            end if;
        end if;
    end if;
    end process;

end architecture;

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
    g_DATA_WIDTH : natural := 8;
    g_ADDR_WIDTH : natural := 6--;
);
port (
    -- address for readout
    i_raddr         : in    std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    -- data to be readout, appears 1 cycle after i_raddr is set
    o_rdata         : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);
    i_rclk          : in    std_logic;

    -- further signals are in i_wclk domain
    -- [AK] TODO: use same read and write clocks
    i_ena           : in    std_logic; -- if set to '1', and histogram is i_busy_n = '1', updates histogram
    i_can_overflow  : in    std_logic; -- if set to '1', bins can overflow
    i_wdata         : in    std_logic_vector(g_ADDR_WIDTH-1 downto 0); -- data to be histogramed, actually refers to a bin, hence addr_width
    i_valid         : in    std_logic;
    o_busy_n        : out   std_logic; -- shows that it is ready to accept data
    i_wclk          : in    std_logic;

    -- clear memories, split this from the reset
    i_zeromem       : in    std_logic;
    -- reset state machine
    i_reset_n       : in    std_logic--;
);
end entity;

architecture RTL of histogram_generic is

    type histo_q_array is array (0 to 1) of std_logic_vector(g_DATA_WIDTH-2 downto 0);
    signal rdata : histo_q_array;
    signal valid        : std_logic_vector(1 downto 0);
    signal busy_n : std_logic_vector(1 downto 0);
    -- one pipeline stage
    signal wdata : std_logic_vector(g_ADDR_WIDTH-1 downto 0);

begin

    gen_half_rate_histos :
    for I in 0 to 1 generate
        i_histo: entity work.histogram_generic_half_rate
        generic map (
            -- only needs half the size, memory is split into two blocks
            g_DATA_WIDTH => g_DATA_WIDTH-1,
            g_ADDR_WIDTH => g_ADDR_WIDTH
        )
        port map (
            i_raddr         => i_raddr,
            o_rdata         => rdata(I),
            i_rclk          => i_rclk,

            i_ena           => i_ena,
            i_can_overflow  => i_can_overflow,
            i_wdata         => wdata, -- data can be presented to both
            i_valid         => valid(I),
            o_busy_n        => busy_n(I),
            i_wclk          => i_wclk,

            i_zeromem       => i_zeromem,
            i_reset_n       => i_reset_n--,
        );
    end generate;

    -- o_rdata is simply the sum of both outputs,
    -- we only do it combinatorial, so no more delay is added
    o_rdata   <= ('0' & rdata(1)) + ('0' & rdata(0));
    -- if either one of them is not busy we are fine
    o_busy_n  <= busy_n(1) or busy_n(0);

    -- write state machine
    process(i_wclk)
    begin
    if ( i_reset_n = '0' ) then
        valid   <= "00"; -- disable all writes
    elsif rising_edge(i_wclk) then
        wdata <= i_wdata;
        valid <= "00"; -- default
        -- in principle we would do a round robin
        -- but half rate histograms can accept to consecutive requests,
        -- and are less efficient with 1 cycle pause
        if ( i_valid = '1' ) then
            if ( busy_n(0) = '1' ) then -- so the default is the first histogram
                valid(0) <= '1';
            elsif ( busy_n(1) = '1' ) then
                valid(1) <= '1';
            else
                -- error!
            end if;
        end if;
    end if;
    end process;

end architecture;

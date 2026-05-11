-----------------------------------------------------------------------------
-- PCIe to memory application, pcie readable memory
--
-- Niklaus Berger, Heidelberg University
-- nberger@physi.uni-heidelberg.de
--
-- Only handles reads which are 128 bit aligned
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity pcie_readable_memory is
port (
    -- from IF
    i_rx_st         : in    work.util.avst256_t;
    o_rx_st_ready0  : out   std_logic;
    i_rx_bar        : in    std_logic;

    -- to response engine
    readaddr        : out   std_logic_vector(15 downto 0);
    readlength      : out   std_logic_vector(9 downto 0);
    header2         : out   std_logic_vector(31 downto 0);
    readen          : out   std_logic;

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture RTL of pcie_readable_memory is

    signal rx_st : work.util.avst256_t;
    signal rx_bar : std_logic;

    type receiver_state_type is (reset, waiting);
    signal state : receiver_state_type;

    signal inaddr32 : std_logic_vector(31 downto 0);
    signal memaddr  : std_logic_vector(13 downto 0);

    -- Decoding PCIe TLP headers
    signal fmt : std_logic_vector(1 downto 0);
    signal ptype : std_logic_vector(4 downto 0);
    signal tc : std_logic_vector(2 downto 0);
    signal td : std_logic;
    signal ep : std_logic;
    signal attr : std_logic_vector(1 downto 0);
    signal plength : std_logic_vector(9 downto 0);

begin

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        rx_st <= work.util.c_AVST256_ZERO;
        o_rx_st_ready0 <= '0';
        rx_bar <= '0';
    elsif rising_edge(i_clk) then
        if ( state = reset ) then
            o_rx_st_ready0 <= '0';
        else
            o_rx_st_ready0 <= '1';
        end if;
        rx_st <= i_rx_st;
        rx_bar <= i_rx_bar;
    end if;
    end process;

    -- Endian chasing for addresses
    inaddr32 <= rx_st.data(95 downto 66) & "00";
    memaddr <= inaddr32(17 downto 4);

    -- decode TLP
    fmt <= rx_st.data(30 downto 29);
    ptype <= rx_st.data(28 downto 24);
    tc <= rx_st.data(22 downto 20);
    td <= rx_st.data(15);
    ep <= rx_st.data(14);
    attr <= rx_st.data(13 downto 12);
    plength <= rx_st.data(9 downto 8) & rx_st.data(7 downto 0);

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        state <= reset;
        --
    elsif rising_edge(i_clk) then
        readen <= '0';
        case state is
        when reset =>
            state <= waiting;
            --
        when waiting =>
            if(rx_st.sop = '1' and rx_bar = '1') then
                if(fmt = "00" and ptype = "00000") then -- 32 bit memory read request
                    readaddr <= memaddr & inaddr32(3 downto 2);
                    readlength <= plength;
                    header2 <= rx_st.data(63 downto 32);
                    readen <= '1';
                    state <= waiting;
                end if; -- 32 bit write/read request
            end if; -- if Start of Packet
            --
        end case;

        --
    end if; -- if clk event
    end process;

end architecture;

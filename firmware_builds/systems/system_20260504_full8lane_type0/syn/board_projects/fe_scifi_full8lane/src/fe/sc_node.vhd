----------------------------------------------------------------------------
--
-- Slow Control Node
-- Oktober 2021, M.Mueller
--
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mudaq.all;

entity sc_node is
generic (
    -- todo: generic how many slaves, max.4 ; (an 4 nichts anschliessen etc.)
    ADD_SLAVE0_DELAY_g      : positive := 1; -- Delay to introduce for i_slave0_rdata
    ADD_SLAVE1_DELAY_g      : positive := 1; -- Delay to introduce for i_slave1_rdata
    ADD_SLAVE2_DELAY_g      : positive := 1; -- Delay to introduce for i_slave0_rdata
    ADD_SLAVE3_DELAY_g      : positive := 1; -- Delay to introduce for i_slave1_rdata
    N_REPLY_CYCLES_g        : positive := 2; -- cycles between i_master_re and arrival of o_master_rdata
    SLAVE1_ADDR_MATCH_g     : std_ulogic_vector(15 downto 0) := "1111111111111111";
    SLAVE2_ADDR_MATCH_g     : std_ulogic_vector(15 downto 0) := "1111111111111111";
    SLAVE3_ADDR_MATCH_g     : std_ulogic_vector(15 downto 0) := "1111111111111111"--;
    -- Pattern to match with i_master_addr in order to connect re/we to slave0 ("-" is don't care)
    -- connects to slave1 if no match
    -- Default "--------" connects to slave0
);
port (
    i_clk           : in    std_logic;
    i_reset_n       : in    std_logic;

    i_master_addr   : in    std_logic_vector(15 downto 0);
    i_master_re     : in    std_logic;
    o_master_rdata  : out   reg32;
    i_master_we     : in    std_logic;
    i_master_wdata  : in    reg32;

    o_slave0_addr   : out   std_logic_vector(15 downto 0);
    o_slave0_re     : out   std_logic;
    i_slave0_rdata  : in    reg32;
    o_slave0_we     : out   std_logic;
    o_slave0_wdata  : out   reg32;

    o_slave1_addr   : out   std_logic_vector(15 downto 0);
    o_slave1_re     : out   std_logic;
    i_slave1_rdata  : in    reg32 := x"CCCCCCCC";
    o_slave1_we     : out   std_logic;
    o_slave1_wdata  : out   reg32;

    o_slave2_addr   : out   std_logic_vector(15 downto 0);
    o_slave2_re     : out   std_logic;
    i_slave2_rdata  : in    reg32 := x"CCCCCCCC";
    o_slave2_we     : out   std_logic;
    o_slave2_wdata  : out   reg32;

    o_slave3_addr   : out   std_logic_vector(15 downto 0);
    o_slave3_re     : out   std_logic;
    i_slave3_rdata  : in    reg32 := x"CCCCCCCC";
    o_slave3_we     : out   std_logic;
    o_slave3_wdata  : out   reg32--;
);
end entity;

architecture arch of sc_node is

    signal s0_return_queue      : reg32array(ADD_SLAVE0_DELAY_g downto 0);
    signal s1_return_queue      : reg32array(ADD_SLAVE1_DELAY_g downto 0);
    signal s2_return_queue      : reg32array(ADD_SLAVE2_DELAY_g downto 0);
    signal s3_return_queue      : reg32array(ADD_SLAVE3_DELAY_g downto 0);
    signal slave0_re            : std_logic;
    signal slave1_re            : std_logic;
    signal slave2_re            : std_logic;
    signal slave3_re            : std_logic;

    type slave_type is ( slave0, slave1, slave2, slave3 );
    type return_queue_S0123_switch_type is array (natural range <>) of slave_type;
    signal return_queue_S0123_switch : return_queue_S0123_switch_type(N_REPLY_CYCLES_g downto 0);

begin
    assert ( ADD_SLAVE0_DELAY_g <= N_REPLY_CYCLES_g ) report "sc_node Delay mismatch, N_REPLY_CYCLES_g is not allowed to be smaller than ADD_SLAVE0_DELAY_g" severity error;
    assert ( ADD_SLAVE1_DELAY_g <= N_REPLY_CYCLES_g ) report "sc_node Delay mismatch, N_REPLY_CYCLES_g is not allowed to be smaller than ADD_SLAVE1_DELAY_g" severity error;
    assert ( ADD_SLAVE2_DELAY_g <= N_REPLY_CYCLES_g ) report "sc_node Delay mismatch, N_REPLY_CYCLES_g is not allowed to be smaller than ADD_SLAVE2_DELAY_g" severity error;
    assert ( ADD_SLAVE3_DELAY_g <= N_REPLY_CYCLES_g ) report "sc_node Delay mismatch, N_REPLY_CYCLES_g is not allowed to be smaller than ADD_SLAVE3_DELAY_g" severity error;

    -- return part ------------------------------------
    o_slave0_re <= slave0_re;
    o_slave1_re <= slave1_re;
    o_slave2_re <= slave2_re;
    o_slave3_re <= slave3_re;

    return_queue_S0123_switch(N_REPLY_CYCLES_g) <=
        slave3 when slave3_re = '1' else
        slave2 when slave2_re = '1' else
        slave1 when slave1_re = '1' else
        slave0;

    s0_return_queue(ADD_SLAVE0_DELAY_g) <= i_slave0_rdata; -- moving the delay to the request part and only delay the 16 bit addr instead of the 32 bit rdata does not save registers since one also has to deal with writes & wdata in this case
    s1_return_queue(ADD_SLAVE1_DELAY_g) <= i_slave1_rdata;
    s2_return_queue(ADD_SLAVE2_DELAY_g) <= i_slave2_rdata;
    s3_return_queue(ADD_SLAVE3_DELAY_g) <= i_slave3_rdata;

    with return_queue_S0123_switch(0) select o_master_rdata <=
        s3_return_queue(0) when slave3,
        s2_return_queue(0) when slave2,
        s1_return_queue(0) when slave1,
        s0_return_queue(0) when slave0;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        return_queue_S0123_switch(N_REPLY_CYCLES_g-1 downto 0) <= (others => slave0);
    elsif rising_edge(i_clk) then
        s0_return_queue(ADD_SLAVE0_DELAY_g-1 downto 0) <= s0_return_queue(ADD_SLAVE0_DELAY_g downto 1);
        s1_return_queue(ADD_SLAVE1_DELAY_g-1 downto 0) <= s1_return_queue(ADD_SLAVE1_DELAY_g downto 1);
        s2_return_queue(ADD_SLAVE2_DELAY_g-1 downto 0) <= s2_return_queue(ADD_SLAVE2_DELAY_g downto 1);
        s3_return_queue(ADD_SLAVE3_DELAY_g-1 downto 0) <= s3_return_queue(ADD_SLAVE3_DELAY_g downto 1);
        return_queue_S0123_switch(N_REPLY_CYCLES_g-1 downto 0) <= return_queue_S0123_switch(N_REPLY_CYCLES_g downto 1);
    end if;
    end process;

    -- request part -----------------------------------
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        slave0_re   <= '0';
        slave1_re   <= '0';
        slave2_re   <= '0';
        slave3_re   <= '0';
        o_slave0_we <= '0';
        o_slave1_we <= '0';
        o_slave2_we <= '0';
        o_slave3_we <= '0';

    elsif rising_edge(i_clk) then

        slave0_re   <= '0';
        slave1_re   <= '0';
        slave2_re   <= '0';
        slave3_re   <= '0';
        o_slave0_we <= '0';
        o_slave1_we <= '0';
        o_slave2_we <= '0';
        o_slave3_we <= '0';

        -- Quartus merges these into single registers and fails timing because the fanout is so large if one does this here
        --o_slave0_addr   <= i_master_addr;
        --o_slave1_addr   <= i_master_addr;
        --o_slave2_addr   <= i_master_addr;
        --o_slave3_addr   <= i_master_addr;

        --o_slave0_wdata  <= i_master_wdata;
        --o_slave1_wdata  <= i_master_wdata;
        --o_slave2_wdata  <= i_master_wdata;
        --o_slave3_wdata  <= i_master_wdata;

        if( to_stdulogicvector(i_master_addr) ?= SLAVE1_ADDR_MATCH_g) then
            slave1_re       <= i_master_re;
            o_slave1_we     <= i_master_we;
            o_slave1_addr   <= i_master_addr;
            o_slave1_wdata  <= i_master_wdata;
        elsif( to_stdulogicvector(i_master_addr) ?= SLAVE2_ADDR_MATCH_g) then
            slave2_re       <= i_master_re;
            o_slave2_we     <= i_master_we;
            o_slave2_addr   <= i_master_addr;
            o_slave2_wdata  <= i_master_wdata;
        elsif( to_stdulogicvector(i_master_addr) ?= SLAVE3_ADDR_MATCH_g) then
            slave3_re       <= i_master_re;
            o_slave3_we     <= i_master_we;
            o_slave3_addr   <= i_master_addr;
            o_slave3_wdata  <= i_master_wdata;
        else
            slave0_re       <= i_master_re;
            o_slave0_we     <= i_master_we;
            o_slave0_addr   <= i_master_addr;
            o_slave0_wdata  <= i_master_wdata;
        end if;
    end if;
    end process;

end architecture;

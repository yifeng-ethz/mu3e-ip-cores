--
-- SC rewrite
-- Oktober 2021, M.Mueller
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use work.mudaq.all;

entity sc_ram is
generic (
    READ_DELAY_g     : positive := 7--;
);
port (
    -- RAM port (slave of sx_rx)
    i_ram_addr          : in    std_logic_vector(15 downto 0) := (others => '0');
    i_ram_re            : in    std_logic := '0';
    o_ram_rvalid        : out   std_logic;
    o_ram_rdata         : out   std_logic_vector(31 downto 0);
    i_ram_we            : in    std_logic := '0';
    i_ram_wdata         : in    std_logic_vector(31 downto 0) := (others => '0');

    -- AVS port (avalon slave of nios)
    -- address units - words
    i_avs_address       : in    std_logic_vector(15 downto 0) := (others => '0');
    i_avs_read          : in    std_logic := '0';
    o_avs_readdata      : out   std_logic_vector(31 downto 0);
    i_avs_write         : in    std_logic := '0';
    i_avs_writedata     : in    std_logic_vector(31 downto 0) := (others => '0');
    o_avs_waitrequest   : out   std_logic;

    -- REG port (master)
    o_reg_addr          : out   std_logic_vector(15 downto 0);
    o_reg_re            : out   std_logic;
    i_reg_rdata         : in    std_logic_vector(31 downto 0) := (others => '0');
    o_reg_we            : out   std_logic;
    o_reg_wdata         : out   std_logic_vector(31 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture arch of sc_ram is

    signal read_delay_shift_reg         : std_logic_vector(READ_DELAY_g   downto 0) := (others => '0');
    signal read_delay_shift_reg_type    : std_logic_vector(READ_DELAY_g+1 downto 0) := (others => '0'); -- 0: Arria, 1: Nios
    signal avs_waitrequest_prev         : std_logic := '0';

    signal avs_waitrequest : std_logic;
    signal avs_cmd_buf     : std_logic := '0';
    signal avs_cmd_buf2    : std_logic := '0';
    signal avs_read_sent   : std_logic := '0';
    signal avs_write_sent  : std_logic := '0';

    -- signals to lvl0 sc_node
    signal addr          : std_logic_vector(15 downto 0) := (others => '0');
    signal re            : std_logic := '0';
    signal rdata         : std_logic_vector(31 downto 0) := (others => '0');
    signal we            : std_logic := '0';
    signal wdata         : std_logic_vector(31 downto 0) := (others => '0');

begin

    o_reg_addr          <= addr;
    o_reg_re            <= re;
    rdata               <= i_reg_rdata;
    o_reg_we            <= we;
    o_reg_wdata         <= wdata;

    -- request process
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        re                          <= '0';
        we                          <= '0';
        read_delay_shift_reg        <= (others => '0');
        read_delay_shift_reg_type   <= (others => '0');
        avs_read_sent               <= '0';
        avs_write_sent              <= '0';
        avs_waitrequest_prev        <= '0';

    elsif rising_edge(i_clk) then
        we     <= '0';
        re     <= '0';

        read_delay_shift_reg        <= read_delay_shift_reg(READ_DELAY_g-1 downto 0) & '0';
        read_delay_shift_reg_type   <= read_delay_shift_reg_type(READ_DELAY_g downto 0) & '0'; -- 0: sc_rx, 1: Nios
        avs_waitrequest_prev        <= avs_waitrequest;


        if(read_delay_shift_reg_type(READ_DELAY_g+1)='1') then -- reset avs_read_sent whenever we respond to nios
            avs_read_sent                   <= '0';
        end if;

        if(avs_waitrequest_prev = '0') then -- difference to avs_read_sent is that we do not need to wait for the reply here
            avs_write_sent                  <= '0';
        end if;

        if(i_ram_re='1') then -- read from Arria10
            read_delay_shift_reg(0) <= '1';
            re      <= '1';
            addr    <= i_ram_addr;
        elsif(i_ram_we='1') then -- write from Arria10
            we      <= '1';
            wdata   <= i_ram_wdata;
            addr    <= i_ram_addr;
        elsif(i_avs_read='1' and avs_read_sent='0') then -- read from nios
            read_delay_shift_reg(0)         <= '1';
            read_delay_shift_reg_type(0)    <= '1';
            re                              <= '1';
            addr                            <= i_avs_address;
            avs_read_sent                   <= '1'; -- nios will keep i_avs_read high until waitreq is deasserted, but we only want 1 read
        elsif(i_avs_write='1' and avs_write_sent='0') then -- write from nios
            we                              <= '1';
            wdata                           <= i_avs_writedata;
            addr                            <= i_avs_address;
            avs_write_sent                  <= '1';
        end if;
    end if;
    end process;


    -- response process
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        avs_cmd_buf     <= '0';
        avs_cmd_buf2    <= '0';
        o_avs_readdata  <= (others => '0');

    elsif rising_edge(i_clk) then
        -- defaults
        o_ram_rvalid    <= '0';
        avs_cmd_buf     <= i_avs_read or i_avs_write;
        avs_cmd_buf2    <= avs_cmd_buf;

        if(read_delay_shift_reg(READ_DELAY_g) = '1') then
            if(read_delay_shift_reg_type(READ_DELAY_g) = '0') then --respond to Arria10
                o_ram_rvalid    <= '1';
                o_ram_rdata     <= rdata;
            else -- respond to nios
                o_avs_readdata  <= rdata;
            end if;
        end if;
    end if;
    end process;

    o_avs_waitrequest <= avs_waitrequest;
    avs_waitrequest <=
        '1' when ( i_ram_re = '1' -- we don't have this cycle for the nios --(TODO: check if we can do (i_ram_re='1' and not read_delay_shift_reg_type(READ_DELAY_g) = '1') safely here)
                or i_ram_we = '1' -- same
                or re       = '1' -- at end of sc read reply & we have this cycle --> send nios req into pipeline but skip over this cycle with waitreq (or_reduce(...) will apply next cycle)
                or we       = '1' -- probably not needed, TODO: Simulate
                or (or_reduce(read_delay_shift_reg_type(READ_DELAY_g downto 0)) = '1') -- nios request in pipeline, waiting for reply
                or (avs_cmd_buf = '0' and (i_avs_read = '1' or i_avs_write = '1')) -- https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/manual/mnl_avalon_spec.pdf
                or (avs_cmd_buf = '1' and avs_cmd_buf2 = '0')) -- because i dont end up in read_delay_shift_reg_type quick enough
            else '0';

end architecture;

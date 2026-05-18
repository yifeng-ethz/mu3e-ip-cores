library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

--  A testbench has no ports.
entity tb_sc is
end entity;

architecture rtl of tb_sc is
  --  Declaration of the component that will be instantiated.

  --  Specifies which entity is bound with the component.

    constant NLINKS : integer := 2;

    signal clk : std_logic;
    signal reset_n : std_logic := '1';
    signal writememdata : std_logic_vector(31 downto 0);
    signal writememdata_out : std_logic_vector(31 downto 0);
    signal writememaddr : std_logic_vector(15 downto 0);
    signal memaddr : std_logic_vector(15 downto 0);
    signal mem_data_out : work.mu3e.link32_array_t(NLINKS-1 downto 0);
    signal mem_data_out_slv : slv32_array_t(NLINKS-1 downto 0);
    signal mem_data_out_slv_k : slv4_array_t(NLINKS-1 downto 0);
    signal mem_datak_out : slv4_array_t(NLINKS-1 downto 0);
    signal mem_data_out_slave : std_logic_vector(31 downto 0);
    signal mem_addr_out_slave, length : std_logic_vector(15 downto 0);
    signal mem_wren_slave : std_logic;
    signal link_enable : std_logic_vector(NLINKS-1 downto 0) := (others => '1');

    constant ckTime : time := 10 ns;

    signal writememwren, length_we, done, toggle_read, fifo_we : std_logic;

    signal fifo_wdata : std_logic_vector(35 downto 0);
    signal link_data : std_logic_vector(127 downto 0) := (others => '0');
    signal link_datak : std_logic_vector(15 downto 0) := (others => '0');
    signal link_data_ltype : work.mu3e.link32_array_t(NLINKS-1 downto 0) := (others => work.mu3e.LINK32_IDLE);

    type state_type is (idle, write_sc, wait_state, read_sc, probe_mem);
    signal state : state_type;
    signal testcounter : integer range 0 to 3 := 0;

    signal sc_ram, sc_reg, slave0_reg : work.util.rw_t;

    signal mem_data_probe : std_logic_vector(31 downto 0);
    signal mem_addr_probe : std_logic_vector(15 downto 0);
    signal probe_value    : std_logic_vector(31 downto 0);
    constant probe_array: slv32_array_t(0 to 10) := (x"1D000ABC",x"0000000A",x"00010001",x"0000009C",x"1E000ABC",x"0000000A",x"00010001",x"AFFEAFFE",x"0000009C",x"1D000ABC",x"0000000A");

begin

    gen_links : for i in 0 to NLINKS - 1 generate
        link_data_ltype(i) <= work.mu3e.to_link(link_data(32*i+31 downto 32*i), link_datak(4*i+3 downto 4*i));

        mem_data_out_slv(i)     <= mem_data_out(i).data;
        mem_data_out_slv_k(i)   <= mem_data_out(i).datak;
    end generate;


  --  Component instantiation.
    sc_main : entity work.swb_sc_main
    generic map (
        NLINKS => NLINKS
    )
    port map (
        i_length_we => length_we,
        i_length    => length,
        i_mem_data  => writememdata_out,
        o_mem_addr  => memaddr,
        o_mem_data  => mem_data_out,
        o_done      => done,
        o_state     => open,
        i_reset_n   => reset_n,
        i_clk       => clk--,
    );

    sc_rx : entity work.sc_rx
    port map (
        i_link_data     => mem_data_out_slv(0),
        i_link_datak    => mem_data_out_slv_k(0),

        o_fifo_we       => fifo_we,
        o_fifo_wdata    => fifo_wdata,

        o_ram_addr      => sc_ram.addr,
        o_ram_re        => sc_ram.re,

        i_ram_rvalid    => sc_ram.rvalid,
        i_ram_rdata     => sc_ram.rdata,

        o_ram_we        => sc_ram.we,
        o_ram_wdata     => sc_ram.wdata,

        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

    e_sc_ram : entity work.sc_ram
    generic map (
        g_READ_DELAY => 3--,
    )
    port map (
        i_ram_addr              => sc_ram.addr(15 downto 0),
        i_ram_re                => sc_ram.re,
        o_ram_rvalid            => sc_ram.rvalid,
        o_ram_rdata             => sc_ram.rdata,
        i_ram_we                => sc_ram.we,
        i_ram_wdata             => sc_ram.wdata,

        o_reg_addr              => sc_reg.addr(15 downto 0),
        o_reg_re                => sc_reg.re,
        i_reg_rdata             => sc_reg.rdata,
        o_reg_we                => sc_reg.we,
        o_reg_wdata             => sc_reg.wdata,

        i_reset_n               => reset_n,
        i_clk                   => clk--,
    );

    sc_node_inst: entity work.sc_node
    port map (
        i_master_addr  => sc_reg.addr(15 downto 0),
        i_master_re    => sc_reg.re,
        o_master_rdata => sc_reg.rdata,
        i_master_we    => sc_reg.we,
        i_master_wdata => sc_reg.wdata,

        o_slave0_addr  => slave0_reg.addr(15 downto 0),
        o_slave0_re    => slave0_reg.re,
        i_slave0_rdata => slave0_reg.rdata,
        o_slave0_we    => slave0_reg.we,
        o_slave0_wdata => slave0_reg.wdata,

        i_reset_n      => reset_n,
        i_clk          => clk--,
    );

    reg_mapping : process(clk, reset_n) -- dummy process for a reg mapping entity
    begin
    if ( reset_n = '0' ) then
        slave0_reg.rdata <= (others => '0');
    elsif rising_edge(clk) then
        if(slave0_reg.addr(15 downto 0) = x"000A" and slave0_reg.re = '1') then
            slave0_reg.rdata <= x"AFFEAFFE";
        else
            slave0_reg.rdata <= x"FFFFFFFF";
        end if;
    end if;
    end process;

    e_merger : entity work.data_merger
    generic map (
        feb_mapping => (3,2,1,0)--;
    )
    port map (
        i_fpga_ID               => x"000A",
        i_FEB_type              => "111000",

        i_run_state             => (0 => '1', others =>'0'),
        i_run_number            => (others => '0'),

        o_data                  => link_data,
        o_datak                 => link_datak,

        i_slowcontrol_write_req => fifo_we,
        i_data_slowcontrol      => fifo_wdata,

        i_data_write_req        => (others => '0'),
        i_data                  => (others => '0'),
        o_fifos_almost_full     => open,

        i_override_data         => (others => '0'),
        i_override_datak        => (others => '0'),
        i_override_req          => '0',
        o_override_granted      => open,

        i_can_terminate         => '0',
        o_terminated            => open,
        i_data_priority         => '0',
        o_rate_count            => open,

        i_reset_n               => reset_n,
        i_clk                   => clk--,
    );

    sc_secondary : entity work.swb_sc_secondary
    generic map (
        NLINKS => NLINKS,
        skip_init => '1'
    )
    port map (
        i_link_enable       => "01",
        i_link_data         => link_data_ltype,

        o_mem_addr          => mem_addr_out_slave,
        o_mem_data          => mem_data_out_slave,
        o_mem_we            => mem_wren_slave,

        i_reset_n           => reset_n,
        i_clk               => clk--,
    );

    wram : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => 8,
        g_ADDR1_WIDTH => 8,
        g_DATA0_WIDTH => 32,
        g_DATA1_WIDTH => 32--,
    )
    port map (
        i_addr0     => writememaddr(7 downto 0),
        i_addr1     => memaddr(7 downto 0),
        i_clk0      => clk,
        i_clk1      => clk,
        i_wdata0    => writememdata,
        i_wdata1    => (others => '0'),
        i_we0       => writememwren,
        i_we1       => '0',
        o_rdata0    => open,
        o_rdata1    => writememdata_out--,
    );

    rram : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => 8,
        g_ADDR1_WIDTH => 8,
        g_DATA0_WIDTH => 32,
        g_DATA1_WIDTH => 32--,
    )
    port map (
        i_addr0     => mem_addr_out_slave(7 downto 0),
        i_addr1     => mem_addr_probe(7 downto 0),
        i_clk0      => clk,
        i_clk1      => clk,
        i_wdata0    => mem_data_out_slave,
        i_wdata1    => (others => '0'),
        i_we0       => mem_wren_slave,
        i_we1       => '0',
        o_rdata0    => open,
        o_rdata1    => mem_data_probe--,
    );

    -- generate the clock
    ckProc: process
    begin
        clk <= '0';
        wait for ckTime/2;
        clk <= '1';
        wait for ckTime/2;
    end process;

    inita : process
    begin
        reset_n <= '0';
        wait for 8 ns;
        reset_n <= '1';

        wait for 10 us;
        reset_n  <= '0';

        wait for 8 ns;
        reset_n  <= '1';

        wait;
    end process;

    memory : process(clk, reset_n)
    begin
    if ( reset_n = '0' ) then
        writememdata <= (others => '0');
        writememaddr <= x"FFFF";
        writememwren <= '0';
        length_we    <= '0';
        toggle_read  <= '0';
        length       <= (others => '0');
        state        <= idle;
    elsif rising_edge(clk) then
        writememwren    <= '0';
        length_we       <= '0';

        case state is

        when idle =>
            if ( done = '1' ) then
                if ( toggle_read = '1' ) then
                    state <= read_sc;
                else
                    state <= write_sc;
                end if;
            end if;

        when write_sc =>
            if(writememaddr(3 downto 0) = x"F")then
                writememdata <= x"1d0000bc"; -- write to feb 0
                writememaddr <= writememaddr + 1;
                writememwren <= '1';
            elsif(writememaddr(3 downto 0)  = x"0")then
                writememdata <= x"0000000a";
                writememaddr <= writememaddr + 1;
                writememwren <= '1';
            elsif(writememaddr(3 downto 0)  = x"1")then
                writememdata <= x"00000001";
                writememaddr <= writememaddr + 1;
                writememwren <= '1';
            elsif(writememaddr(3 downto 0)  = x"2")then
                writememdata <= x"0000000b";
                writememaddr <= writememaddr + 1;
                writememwren <= '1';
            elsif(writememaddr(3 downto 0)  = x"3")then
                writememdata <= x"0000009c";
                writememaddr <= writememaddr + 1;
                writememwren <= '1';
                length <= x"0003";
            elsif(writememaddr(3 downto 0)  = x"4")then
                length_we <= '1';
                writememaddr <= (others => '1');
                state <= wait_state;
            end if;

        when read_sc =>
            mem_addr_probe <= (others => '0');
            if(writememaddr(3 downto 0) = x"F")then
                writememdata <= x"1E0000bc"; -- read from feb0
                writememaddr <= writememaddr + 1;
                writememwren <= '1';
            elsif(writememaddr(3 downto 0)  = x"0")then
                writememdata <= x"0000000a";
                writememaddr <= writememaddr + 1;
                writememwren <= '1';
            elsif(writememaddr(3 downto 0)  = x"1")then
                writememdata <= x"00000001";
                writememaddr <= writememaddr + 1;
                writememwren <= '1';
            elsif(writememaddr(3 downto 0)  = x"2")then
                writememdata <= x"0000009c";
                writememaddr <= writememaddr + 1;
                writememwren <= '1';
                length <= x"0002";
            elsif(writememaddr(3 downto 0)  = x"3")then
                length_we <= '1';
                writememaddr <= (others => '1');
                state <= wait_state;
            end if;

        when wait_state =>
            if ( done = '0' ) then
                if(testcounter = 3) then
                    testcounter <= 0;
                    state <= probe_mem;
                    mem_addr_probe <= mem_addr_probe + 1;
                    probe_value <= probe_array(to_integer(unsigned(mem_addr_probe))) when to_integer(unsigned(mem_addr_probe)) < 11 else (others => '0');
                else
                    toggle_read <= not toggle_read;
                    state <= idle;
                    testcounter <= testcounter + 1;
                end if;
            end if;
        when probe_mem =>
            mem_addr_probe <= mem_addr_probe + 1;
            probe_value <= probe_array(to_integer(unsigned(mem_addr_probe))) when to_integer(unsigned(mem_addr_probe)) < 11 else (others => '0');

            if(mem_data_probe /= probe_value) then
                    assert ( false ) report "sc mem content mismatch, sc path is broken or probe vector needs update"  severity failure;
            end if;

            if(mem_addr_probe = x"000A") then
                state <= idle;
            end if;
        when others =>
            writememaddr <= (others => '0');
            state <= idle;

        end case;
    end if;
    end process;

end architecture;

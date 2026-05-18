library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mudaq.all;
use work.util.all;

entity tb_pcie_completer_rreg_fifo_loss is
end entity;

architecture sim of tb_pcie_completer_rreg_fifo_loss is
    constant c_clk_period : time := 10 ns;
    constant c_requests   : natural := 40;
    constant c_timeout    : natural := 2000;

    signal clk     : std_logic := '0';
    signal reset_n : std_logic := '0';

    signal tx_st               : work.util.avst256_t := work.util.c_AVST256_ZERO;
    signal tx_st_ready0_next   : std_logic := '0';
    signal completer_id        : std_logic_vector(12 downto 0) := (others => '0');

    signal writeregs           : reg32array_pcie := (others => (others => '0'));
    signal readregs            : reg32array_pcie := (others => (others => '0'));

    signal rreg_readaddr       : std_logic_vector(5 downto 0) := (others => '0');
    signal rreg_readlength     : std_logic_vector(9 downto 0) := (others => '0');
    signal rreg_header2        : std_logic_vector(31 downto 0) := (others => '0');
    signal rreg_readen         : std_logic := '0';
    signal rreg_request_ready  : std_logic;

    signal wreg_readaddr       : std_logic_vector(5 downto 0) := (others => '0');
    signal wreg_readlength     : std_logic_vector(9 downto 0) := (others => '0');
    signal wreg_header2        : std_logic_vector(31 downto 0) := (others => '0');
    signal wreg_readen         : std_logic := '0';

    signal rmem_readaddr       : std_logic_vector(15 downto 0) := (others => '0');
    signal rmem_readlength     : std_logic_vector(9 downto 0) := (others => '0');
    signal rmem_header2        : std_logic_vector(31 downto 0) := (others => '0');
    signal rmem_readen         : std_logic := '0';

    signal wmem_readaddr       : std_logic_vector(15 downto 0) := (others => '0');
    signal wmem_readlength     : std_logic_vector(9 downto 0) := (others => '0');
    signal wmem_header2        : std_logic_vector(31 downto 0) := (others => '0');
    signal wmem_readen         : std_logic := '0';

    signal writemem_addr       : std_logic_vector(15 downto 0);
    signal writemem_data       : std_logic_vector(31 downto 0) := (others => '0');
    signal readmem_addr        : std_logic_vector(13 downto 0);
    signal readmem_data        : std_logic_vector(127 downto 0) := (others => '0');

    signal dma_request         : std_logic := '0';
    signal dma_granted         : std_logic;
    signal dma_done            : std_logic := '0';
    signal dma_tx_ready        : std_logic;
    signal dma_tx              : work.util.avst256_t := work.util.c_AVST256_ZERO;
    signal dma2_request        : std_logic := '0';
    signal dma2_granted        : std_logic;
    signal dma2_done           : std_logic := '0';
    signal dma2_tx_ready       : std_logic;
    signal dma2_tx             : work.util.avst256_t := work.util.c_AVST256_ZERO;
    signal testout             : std_logic_vector(127 downto 0);

    signal completion_count    : natural := 0;
begin
    clk <= not clk after c_clk_period / 2;

    dut : entity work.pcie_completer
    port map (
        o_tx_st             => tx_st,
        tx_st_ready0_next   => tx_st_ready0_next,
        completer_id        => completer_id,
        writeregs           => writeregs,
        i_readregs          => readregs,
        rreg_readaddr       => rreg_readaddr,
        rreg_readlength     => rreg_readlength,
        rreg_header2        => rreg_header2,
        rreg_readen         => rreg_readen,
        rreg_request_ready  => rreg_request_ready,
        wreg_readaddr       => wreg_readaddr,
        wreg_readlength     => wreg_readlength,
        wreg_header2        => wreg_header2,
        wreg_readen         => wreg_readen,
        wreg_request_ready  => open,
        rmem_readaddr       => rmem_readaddr,
        rmem_readlength     => rmem_readlength,
        rmem_header2        => rmem_header2,
        rmem_readen         => rmem_readen,
        rmem_request_ready  => open,
        wmem_readaddr       => wmem_readaddr,
        wmem_readlength     => wmem_readlength,
        wmem_header2        => wmem_header2,
        wmem_readen         => wmem_readen,
        wmem_request_ready  => open,
        writemem_addr       => writemem_addr,
        writemem_data       => writemem_data,
        readmem_addr        => readmem_addr,
        readmem_data        => readmem_data,
        dma_request         => dma_request,
        dma_granted         => dma_granted,
        dma_done            => dma_done,
        dma_tx_ready        => dma_tx_ready,
        i_dma_tx            => dma_tx,
        dma2_request        => dma2_request,
        dma2_granted        => dma2_granted,
        dma2_done           => dma2_done,
        dma2_tx_ready       => dma2_tx_ready,
        i_dma2_tx           => dma2_tx,
        testout             => testout,
        i_reset_n           => reset_n,
        i_clk               => clk
    );

    p_monitor : process
    begin
        wait until rising_edge(clk);
        wait for 1 ps;
        if reset_n = '1' and tx_st_ready0_next = '1' and
           tx_st.valid = '1' and tx_st.eop = '1' then
            completion_count <= completion_count + 1;
        end if;
    end process;

    p_stim : process
        variable header2_v : std_logic_vector(31 downto 0);
        variable accepted_v : natural := 0;
        variable stall_cycles_v : natural := 0;
    begin
        for i in readregs'range loop
            readregs(i) <= std_logic_vector(to_unsigned(16#1000# + i, 32));
        end loop;

        repeat_reset : for i in 0 to 7 loop
            wait until rising_edge(clk);
        end loop;
        reset_n <= '1';
        for i in 0 to 3 loop
            wait until rising_edge(clk);
        end loop;

        tx_st_ready0_next <= '0';
        while accepted_v < c_requests loop
            header2_v := (others => '0');
            header2_v(31 downto 16) := std_logic_vector(to_unsigned(16#CAFE#, 16));
            header2_v(15 downto 8)  := std_logic_vector(to_unsigned(accepted_v, 8));
            header2_v(7 downto 0)   := x"0F";
            if stall_cycles_v = 80 then
                tx_st_ready0_next <= '1';
            end if;
            if rreg_request_ready = '1' then
                rreg_readaddr <= std_logic_vector(to_unsigned(accepted_v mod 64, 6));
                rreg_readlength <= "0000000001";
                rreg_header2 <= header2_v;
                rreg_readen <= '1';
                accepted_v := accepted_v + 1;
            else
                rreg_readen <= '0';
            end if;
            stall_cycles_v := stall_cycles_v + 1;
            wait until rising_edge(clk);
        end loop;
        rreg_readen <= '0';

        tx_st_ready0_next <= '1';
        for i in 0 to c_timeout - 1 loop
            wait until rising_edge(clk);
        end loop;

        assert completion_count = c_requests
            report "PCIE_APP_ACCEPTED_PACKET_LOSS: rreg_readen accepted "
                & integer'image(c_requests) & " requests while HIP TX was stalled, but only "
                & integer'image(completion_count)
                & " completions reached tx_st. The completer FIFO full state is not backpressured to PCIe RX."
            severity failure;

        report "*** TEST PASSED ***";
        std.env.finish;
        wait;
    end process;
end architecture;

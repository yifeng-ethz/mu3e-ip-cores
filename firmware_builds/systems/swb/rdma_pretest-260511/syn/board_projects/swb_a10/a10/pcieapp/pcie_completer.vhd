-----------------------------------------------------------------------------
-- PCIe completer application, reads memory and registers and sends them off
--
-- Niklaus Berger, Heidelberg University
-- nberger@physi.uni-heidelberg.de
--
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.mudaq.all;

entity pcie_completer is
port (
    -- from IF
    o_tx_st             : out   work.util.avst256_t;
    tx_st_ready0_next   : in    std_logic;

    -- from Config
    completer_id        : in    std_logic_vector(12 downto 0);

    -- registers
    writeregs           : in    reg32array_pcie;
    i_readregs          : in    reg32array_pcie;

    -- from register read part
    rreg_readaddr       : in    std_logic_vector(5 downto 0);
    rreg_readlength     : in    std_logic_vector(9 downto 0);
    rreg_header2        : in    std_logic_vector(31 downto 0);
    rreg_readen         : in    std_logic;

    -- from register write part
    wreg_readaddr       : in    std_logic_vector(5 downto 0);
    wreg_readlength     : in    std_logic_vector(9 downto 0);
    wreg_header2        : in    std_logic_vector(31 downto 0);
    wreg_readen         : in    std_logic;

    -- from memory read part
    rmem_readaddr       : in    std_logic_vector(15 downto 0);
    rmem_readlength     : in    std_logic_vector(9 downto 0);
    rmem_header2        : in    std_logic_vector(31 downto 0);
    rmem_readen         : in    std_logic;

    -- from memory write part
    wmem_readaddr       : in    std_logic_vector(15 downto 0);
    wmem_readlength     : in    std_logic_vector(9 downto 0);
    wmem_header2        : in    std_logic_vector(31 downto 0);
    wmem_readen         : in    std_logic;

    -- to and from writeable memory
    writemem_addr       : out   std_logic_vector(15 downto 0);
    writemem_data       : in    std_logic_vector(31 downto 0);

    -- to and from readable memory
    readmem_addr        : out   std_logic_vector(13 downto 0);
    readmem_data        : in    std_logic_vector(127 downto 0);

    -- to and from dma engine
    dma_request         : in    std_logic;
    dma_granted         : out   std_logic;
    dma_done            : in    std_logic;
    dma_tx_ready        : out   std_logic;
    i_dma_tx            : in    work.util.avst256_t;

    -- to and from second dma engine
    dma2_request        : in    std_logic;
    dma2_granted        : out   std_logic;
    dma2_done           : in    std_logic;
    dma2_tx_ready       : out   std_logic;
    i_dma2_tx           : in    work.util.avst256_t;

    -- test ports
    testout             : out   std_logic_vector(127 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture RTL of pcie_completer is

    signal readregs : reg32array_pcie;

    type completer_state_type is (
        reset, waiting,
        readrreg, readrreg1,
        readwreg, readwreg1,
        readwmem, readwmempause, readwmempause2, readwmem1,
        readrmem, readrmempause, readrmempause2, readrmem1,
        dma, dma2
    );
    signal state : completer_state_type;

    signal read_rreg_fifo       : std_logic;
    signal empty_rreg_fifo      : std_logic;
    signal full_rreg_fifo       : std_logic;
    signal overflow_rreg_fifo   : std_logic;
    signal datain_rreg_fifo     : std_logic_vector(47 downto 0);
    signal data_rreg_fifo       : std_logic_vector(47 downto 0);
    signal rreg_bytecount       : std_logic_vector(11 downto 0);
    signal rreg_la              : std_logic_vector(1 downto 0);

    signal read_wreg_fifo       : std_logic;
    signal empty_wreg_fifo      : std_logic;
    signal full_wreg_fifo       : std_logic;
    signal overflow_wreg_fifo   : std_logic;
    signal datain_wreg_fifo     : std_logic_vector(47 downto 0);
    signal data_wreg_fifo       : std_logic_vector(47 downto 0);
    signal wreg_bytecount       : std_logic_vector(11 downto 0);
    signal wreg_la              : std_logic_vector(1 downto 0);

    signal read_rmem_fifo       : std_logic;
    signal empty_rmem_fifo      : std_logic;
    signal full_rmem_fifo       : std_logic;
    signal overflow_rmem_fifo   : std_logic;
    signal datain_rmem_fifo     : std_logic_vector(63 downto 0);
    signal data_rmem_fifo       : std_logic_vector(63 downto 0);
    signal rmem_bytecount       : std_logic_vector(11 downto 0);
    signal rmem_la              : std_logic_vector(1 downto 0);
    signal rmem_state           : std_logic;

    signal read_wmem_fifo       : std_logic;
    signal empty_wmem_fifo      : std_logic;
    signal full_wmem_fifo       : std_logic;
    signal overflow_wmem_fifo   : std_logic;
    signal datain_wmem_fifo     : std_logic_vector(63 downto 0);
    signal data_wmem_fifo       : std_logic_vector(63 downto 0);
    signal wmem_bytecount       : std_logic_vector(11 downto 0);
    signal wmem_la              : std_logic_vector(1 downto 0);

    signal regtoggle            : std_logic;
    signal memtoggle            : std_logic;
    signal overflow_mem_toggle  : std_logic;
    signal overflow_reg_toggle  : std_logic;

    signal header0_rr           : std_logic_vector(31 downto 0);
    signal header1_rr           : std_logic_vector(31 downto 0);
    signal header2_rr           : std_logic_vector(31 downto 0);

    signal header0_wr           : std_logic_vector(31 downto 0);
    signal header1_wr           : std_logic_vector(31 downto 0);
    signal header2_wr           : std_logic_vector(31 downto 0);

    signal header0_wm           : std_logic_vector(31 downto 0);
    signal header1_wm           : std_logic_vector(31 downto 0);
    signal header2_wm           : std_logic_vector(31 downto 0);

    signal header0_rm           : std_logic_vector(31 downto 0);
    signal header1_rm           : std_logic_vector(31 downto 0);
    signal header2_rm           : std_logic_vector(31 downto 0);

    signal data0_wr             : std_logic_vector(31 downto 0);
    signal data1_wr             : std_logic_vector(31 downto 0);
    signal data2_wr             : std_logic_vector(31 downto 0);
    signal data3_wr             : std_logic_vector(31 downto 0);
    signal data4_wr             : std_logic_vector(31 downto 0);
    signal data5_wr             : std_logic_vector(31 downto 0);
    signal data6_wr             : std_logic_vector(31 downto 0);
    signal data7_wr             : std_logic_vector(31 downto 0);

    signal data0_rr             : std_logic_vector(31 downto 0);
    signal data1_rr             : std_logic_vector(31 downto 0);
    signal data2_rr             : std_logic_vector(31 downto 0);
    signal data3_rr             : std_logic_vector(31 downto 0);
    signal data4_rr             : std_logic_vector(31 downto 0);
    signal data5_rr             : std_logic_vector(31 downto 0);
    signal data6_rr             : std_logic_vector(31 downto 0);
    signal data7_rr             : std_logic_vector(31 downto 0);

    signal dummydata            : std_logic_vector(31 downto 0);

    signal data0_wmem           : std_logic_vector(31 downto 0);
    signal data3_wmem           : std_logic_vector(31 downto 0);

    signal data0_rmem           : std_logic_vector(31 downto 0);
    signal data1_rmem           : std_logic_vector(31 downto 0);
    signal data2_rmem           : std_logic_vector(31 downto 0);
    signal data3_rmem           : std_logic_vector(31 downto 0);
    signal data4_rmem           : std_logic_vector(31 downto 0);
    signal data5_rmem           : std_logic_vector(31 downto 0);
    signal data6_rmem           : std_logic_vector(31 downto 0);
    signal data7_rmem           : std_logic_vector(31 downto 0);
    signal data_rmem_buffer     : std_logic_vector(127 downto 0);

    --signal regaddr_reg_w        : std_logic_vector(5 downto 0);
    --signal length_reg_w         : std_logic_vector(9 downto 0);

    --signal regaddr_reg_r        : std_logic_vector(5 downto 0);
    --signal length_reg_r         : std_logic_vector(9 downto 0);

    --signal writemem_addr_reg    : std_logic_vector(13 downto 0);
    --signal writemem_length_reg  : std_logic_vector(9 downto 0);
    --signal writemem_lowaddr_reg : std_logic_vector(1 downto 0);

    signal readmem_addr_reg     : std_logic_vector(13 downto 0);
    --signal readmem_length_reg   : std_logic_vector(9 downto 0);
    --signal readmem_lowaddr_reg  : std_logic_vector(1 downto 0);

    --signal done_next            : std_logic;
    --signal halfvalid            : std_logic;
    --signal throttle             : std_logic;

    --signal mem_done_next        : std_logic;
    --signal mem_done_after_next  : std_logic;

    signal writeregs_r          : reg32array_pcie;

    signal tx_st_ready0         : std_logic;
    signal readmemnext          : std_logic;


    signal testout_r            : std_logic_vector(127 downto 0);
    signal nreadycount          : std_logic_vector(7 downto 0);

    --signal memswap              : std_logic_vector(1 downto 0);
    signal read_length          : std_logic_vector(9 downto 0);

    signal dma_granted_r        : std_logic;
    signal dma2_granted_r       : std_logic;

    signal nsopcount            : std_logic_vector(7 downto 0);
    signal neopcount            : std_logic_vector(7 downto 0);

    signal ndmasopcount         : std_logic_vector(7 downto 0);
    signal ndmaeopcount         : std_logic_vector(7 downto 0);

    signal tx_st_valid0_r       : STD_LOGIC;
    signal tx_st_eop0_r         : STD_LOGIC;
    signal tx_st_sop0_r         : STD_LOGIC;
    signal tx_st_empty0_r       : STD_LOGIC_VECTOR(1 downto 0);

begin

    o_tx_st.valid <= tx_st_valid0_r;
    o_tx_st.eop <= tx_st_eop0_r;
    o_tx_st.sop <= tx_st_sop0_r;

    dummydata <= (others => '0');

    datain_rreg_fifo <= rreg_readaddr & rreg_readlength & rreg_header2;

    e_rreg_fifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 5,
        g_DATA_WIDTH => datain_rreg_fifo'length,
        g_RREG_N => 1--,
    )
    port map (
        i_we            => rreg_readen,
        i_wdata         => datain_rreg_fifo,
        o_wfull         => full_rreg_fifo,

        i_rack          => read_rreg_fifo,
        o_rdata         => data_rreg_fifo,
        o_rempty        => empty_rreg_fifo,

        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    e_rreg_bytecounter : entity work.pcie_completion_bytecount
    port map (
        fdw_be => data_rreg_fifo(3 downto 0),
        ldw_be => data_rreg_fifo(7 downto 4),
        plength => data_rreg_fifo(41 downto 32),
        bytecount => rreg_bytecount,
        lower_address => rreg_la
    );

    datain_wreg_fifo <= wreg_readaddr & wreg_readlength & wreg_header2;

    e_wreg_fifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 5,
        g_DATA_WIDTH => datain_wreg_fifo'length,
        g_RREG_N => 1--,
    )
    port map (
        i_we            => wreg_readen,
        i_wdata         => datain_wreg_fifo,
        o_wfull         => full_wreg_fifo,

        i_rack          => read_wreg_fifo,
        o_rdata         => data_wreg_fifo,
        o_rempty        => empty_wreg_fifo,

        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    e_wreg_bytecounter : entity work.pcie_completion_bytecount
    port map (
        fdw_be => data_wreg_fifo(3 downto 0),
        ldw_be => data_wreg_fifo(7 downto 4),
        plength => data_wreg_fifo(41 downto 32),
        bytecount => wreg_bytecount,
        lower_address => wreg_la
    );

    datain_rmem_fifo <= "000000" & rmem_readaddr & rmem_readlength & rmem_header2;

    e_rmem_fifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 5,
        g_DATA_WIDTH => datain_rmem_fifo'length--,
    )
    port map (
        i_we            => rmem_readen,
        i_wdata         => datain_rmem_fifo,
        o_wfull         => full_rmem_fifo,

        i_rack          => read_rmem_fifo,
        o_rdata         => data_rmem_fifo,
        o_rempty        => empty_rmem_fifo,

        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    e_rmem_bytecounter : entity work.pcie_completion_bytecount
    port map (
        fdw_be => data_rmem_fifo(3 downto 0),
        ldw_be => data_rmem_fifo(7 downto 4),
        plength => data_rmem_fifo(41 downto 32),
        bytecount => rmem_bytecount,
        lower_address => rmem_la
    );

    datain_wmem_fifo <=  "000000" & wmem_readaddr & wmem_readlength & wmem_header2;

    e_wmem_fifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 5,
        g_DATA_WIDTH => datain_wmem_fifo'length--,
    )
    port map (
        i_we        => wmem_readen,
        i_wdata     => datain_wmem_fifo,
        o_wfull     => full_wmem_fifo,

        i_rack      => read_wmem_fifo,
        o_rdata     => data_wmem_fifo,
        o_rempty    => empty_wmem_fifo,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    e_wmem_bytecounter : entity work.pcie_completion_bytecount
    port map (
        fdw_be => data_wmem_fifo(3 downto 0),
        ldw_be => data_wmem_fifo(7 downto 4),
        plength => data_wmem_fifo(41 downto 32),
        bytecount => wmem_bytecount,
        lower_address => wmem_la
    );



    process(i_clk, i_reset_n)
        variable regaddr_var : std_logic_vector(5 downto 0);
        variable length_var  : std_logic_vector(9 downto 0);
    begin
    if ( i_reset_n = '0' ) then
        state <= reset;

        --readregs <= (others => (others => '0'));

        tx_st_valid0_r <= '0';
        tx_st_sop0_r <= '0';
        tx_st_eop0_r <= '0';
        tx_st_empty0_r <= "00";

        regtoggle <= '0';
        memtoggle <= '0';
        read_rreg_fifo <= '0';
        read_wreg_fifo <= '0';
        read_rmem_fifo <= '0';
        read_wmem_fifo <= '0';


        tx_st_ready0 <= '0';
        nreadycount <= (others => '0');
        dma_granted_r <= '0';
        dma2_granted_r <= '0';
        nsopcount <= (others => '0');
        neopcount <= (others => '0');
        ndmasopcount <= (others => '0');
        ndmaeopcount <= (others => '0');
        overflow_wmem_fifo <= '0';
        overflow_wmem_fifo <= '0';
        overflow_rreg_fifo <= '0';
        overflow_wreg_fifo <= '0';
        overflow_reg_toggle <= '0';
        overflow_mem_toggle <= '0';
        testout_r <= (others => '0');
        rmem_state <= '0';
        readmemnext <= '0';

    elsif rising_edge(i_clk) then
        readregs <= i_readregs;

        dma_granted <= dma_granted_r;
        dma2_granted <= dma2_granted_r;
        readmemnext <= '0';

        o_tx_st.empty <= tx_st_empty0_r;

        -- check for full FIFOs -> set overflow signal
        if ( empty_wmem_fifo= '0' ) then
            overflow_wmem_fifo<= '1';
        end if;
        if ( empty_rmem_fifo = '0' ) then
            overflow_rmem_fifo<= '1';
        end if;
        if ( empty_rreg_fifo= '0' ) then
            overflow_rreg_fifo<= '1';
        end if;
        if ( empty_wreg_fifo= '0' ) then
            overflow_wreg_fifo<= '1';
        end if;
        if ( memtoggle = '1') then
            overflow_mem_toggle <= '1';
        end if;
        if ( regtoggle = '1') then
            overflow_reg_toggle <= '1';
        end if;

        testout_r(125) <= overflow_reg_toggle;
        testout_r(124) <= rmem_state;
        testout_r(123) <= overflow_rmem_fifo;
        testout_r(122) <= overflow_wmem_fifo;
        testout_r(121) <= overflow_rreg_fifo;
        testout_r(120) <= overflow_wreg_fifo;

        -- currently unused bits:
        testout_r(126) <= '0';
        testout_r(103 downto 96) <= (others => '0');
        testout_r( 63 downto 20) <= (others => '0');
        testout_r( 15 downto  8) <= (others => '0');

        -- forward ready status to dma engine with 1cc delay
        --dma_tx_ready <= tx_st_ready0_next;

        testout <= testout_r;
        if(tx_st_ready0_next = '0' and tx_st_ready0 = '1') then
            nreadycount <= nreadycount + '1';
            testout_r(119 downto 112) <= nreadycount;
            testout_r(111 downto 104) <= testout_r(7 downto 0);
        end if;


        if(tx_st_sop0_r ='1') then
            nsopcount <= nsopcount + '1';
        end if;

        if(tx_st_eop0_r ='1') then
            neopcount <= neopcount + '1';
        end if;

        if(i_dma_tx.sop = '1') then
            ndmasopcount <= ndmasopcount + '1';
        end if;

        if(i_dma_tx.eop = '1') then
            ndmaeopcount <= ndmaeopcount + '1';
        end if;

        testout_r(127) <= tx_st_ready0;

        testout_r(71 downto 64) <= neopcount;
        testout_r(79 downto 72) <= nsopcount;
        testout_r(87 downto 80) <= ndmaeopcount;
        testout_r(95 downto 88) <= ndmasopcount;

        testout_r(16) <= dma_request;
        testout_r(17) <= dma_granted_r;
        testout_r(18) <= dma_done;
        testout_r(19) <= i_dma_tx.valid;

        tx_st_ready0 <= tx_st_ready0_next;
        writeregs_r <= writeregs;
        writemem_addr <= data_wmem_fifo(57 downto 42);
        readmem_addr_reg <= data_rmem_fifo(57 downto 44);
        readmem_addr <= data_rmem_fifo(57 downto 44);
        data0_wmem <= writemem_data;
        data3_wmem <= writemem_data;

        --mem_done_next <= mem_done_after_next;
        --mem_done_after_next <= '0';
        case state is
        when reset =>
            testout_r(7 downto 0) <= "00000000";
            state <= waiting;
            tx_st_valid0_r <= '0';
            tx_st_sop0_r <= '0';
            tx_st_eop0_r <= '0';
            tx_st_empty0_r <= "00";
            regtoggle <= '0';
            memtoggle <= '0';
            read_rreg_fifo <= '0';
            read_wreg_fifo <= '0';
            read_rmem_fifo <= '0';
            read_wmem_fifo <= '0';
            rmem_state <= '0';

            dma_granted_r <= '0';
            dma2_granted_r <= '0';
            --
        when waiting =>
            testout_r(7 downto 0) <= "00000001";
            tx_st_valid0_r <= '0';
            tx_st_sop0_r <= '0';
            tx_st_eop0_r <= '0';
            tx_st_empty0_r <= "00";
            read_rreg_fifo <= '0';
            read_wreg_fifo <= '0';
            read_rmem_fifo <= '0';
            read_wmem_fifo <= '0';
            dma_granted_r <= '0';
            dma2_granted_r <= '0';
            -- priorities...
            if((empty_rreg_fifo = '0' and read_rreg_fifo = '0') and (empty_wreg_fifo = '0' and read_wreg_fifo = '0')) then -- both register sets
                if(regtoggle = '0') then
                    state <= readrreg;
                else
                    state <= readwreg;
                end if;
                regtoggle <= not regtoggle;
            elsif(empty_rreg_fifo = '0' and read_rreg_fifo = '0') then
                state <= readrreg;
                regtoggle <= '1';
            elsif(empty_wreg_fifo = '0' and read_wreg_fifo = '0') then
                state <= readwreg;
                regtoggle <= '0';
            elsif((empty_rmem_fifo = '0' and read_rmem_fifo = '0') and (empty_wmem_fifo = '0' and read_wmem_fifo = '0')) then
                if(memtoggle = '0') then
                    state <= readrmempause;
                else
                    state <= readwmempause;
                end if;
                memtoggle <= not memtoggle;
            elsif(empty_rmem_fifo = '0' and read_rmem_fifo ='0') then
                rmem_state <= '1';
                state <= readrmempause;
                memtoggle <= '1';
            elsif(empty_wmem_fifo = '0' and read_wmem_fifo = '0') then
                state <= readwmempause;
                memtoggle <= '0';
            elsif(dma_request = '1') then -- DMA has lowest priority
                state <= dma;
                dma_granted_r <= '1';
            elsif(dma2_request = '1') then -- DMA two has even lower priority
                state <= dma2;
                dma2_granted_r <= '1';
            else
                state <= waiting;
            end if;
            --
        when readrreg =>
            testout_r(7 downto 0) <= "00000010";
            tx_st_empty0_r <= "00";

            -- Build header1; note inverse byte ordering for Avalon interface
            header0_rr <= "0" & "10" & "01010" &-- byte0: R(1) FMT(2) TYPE(5)
                "0" & "000" & "0000" & --byte1: R(1) TC(3) R(4)
                "0" & "0" & "00" & "00" & data_rreg_fifo(41 downto 32);
                --bytes 2/3: TD(1) EP(1) Attr(2) R(2) Length(10)

            header1_rr <= completer_id & "000" & "000" & "0" & rreg_bytecount; -- CompleterID (16) Copl. Status(3) BCM(1) ByteCount(12)

            header2_rr <= data_rreg_fifo(31 downto 16) & data_rreg_fifo(15 downto 8) & "0" & data_rreg_fifo(46 downto 42) & rreg_la;
                -- RequesterID(16) Tag(8) R(1) Lower address (7)

            if(data_rreg_fifo(42) = '1') then --unaligned read, add one data word in first 128 bits
                data3_rr <=  readregs(TO_INTEGER(UNSIGNED(data_rreg_fifo(47 downto 42))));
                data4_rr <=  readregs(TO_INTEGER(UNSIGNED(data_rreg_fifo(47 downto 42)))+1);
                data5_rr <=  readregs(TO_INTEGER(UNSIGNED(data_rreg_fifo(47 downto 42)))+2);
                data6_rr <=  readregs(TO_INTEGER(UNSIGNED(data_rreg_fifo(47 downto 42)))+3);

                if(data_rreg_fifo(41 downto 32) = "0000000001") then
                    tx_st_empty0_r <= "10";
                elsif(data_rreg_fifo(41 downto 32) < "0000000100") then
                    tx_st_empty0_r <= "01";
                end if;

            else
                data4_rr <=  readregs(TO_INTEGER(UNSIGNED(data_rreg_fifo(47 downto 42))));
                data5_rr <=  readregs(TO_INTEGER(UNSIGNED(data_rreg_fifo(47 downto 42)))+1);
                data6_rr <=  readregs(TO_INTEGER(UNSIGNED(data_rreg_fifo(47 downto 42)))+2);
                data7_rr <=  readregs(TO_INTEGER(UNSIGNED(data_rreg_fifo(47 downto 42)))+3);

                if(data_rreg_fifo(41 downto 32) < "0000000011") then
                    tx_st_empty0_r <= "01";
                end if;
            end if;

            if(tx_st_ready0 = '1')then
                state <= readrreg1;
            else
                state <= readrreg;
            end if;
            --
        when readrreg1 =>
            testout_r(7 downto 0) <= "00000011";
            o_tx_st.data <= data7_rr & data6_rr & data5_rr & data4_rr & data3_rr & header2_rr & header1_rr & header0_rr;

            if(tx_st_ready0 = '1') then
                tx_st_sop0_r <= '1';
                tx_st_valid0_r <= '1';
                tx_st_eop0_r <= '1';
                read_rreg_fifo <= '1';
                state <= waiting;
                tx_st_empty0_r <= "00";
            else
                read_rreg_fifo <= '0';
                tx_st_sop0_r <= '0';
                tx_st_valid0_r <= '0';
                tx_st_eop0_r <= '0';
                tx_st_empty0_r <= tx_st_empty0_r;
                state <= readrreg1;
            end if;
            --
        when readwreg =>
            testout_r(7 downto 0) <= "00000100";
            tx_st_empty0_r <= "00";

            -- Build header1; note inverse byte ordering for Avalon interface
            header0_wr <= "0" & "10" & "01010" &-- byte0: R(1) FMT(2) TYPE(5)
                "0" & "000" & "0000" & --byte1: R(1) TC(3) R(4)
                "0" & "0" & "00" & "00" & data_wreg_fifo(41 downto 32);
                --bytes 2/3: TD(1) EP(1) Attr(2) R(2) Length(10)

            header1_wr <= completer_id & "000" & "000" & "0" & wreg_bytecount; -- CompleterID (16) Copl. Status(3) BCM(1) ByteCount(12)

            header2_wr <= data_wreg_fifo(31 downto 16) & data_wreg_fifo(15 downto 8) & "0" & data_wreg_fifo(46 downto 42) & wreg_la;
                -- RequesterID(16) Tag(8) R(1) Lower address (7)

            if(data_wreg_fifo(42) = '1') then --unaligned read, add one data word in first 128 bits
                data3_wr <= writeregs_r(TO_INTEGER(UNSIGNED(data_wreg_fifo(47 downto 42))));
                data4_wr <= writeregs_r(TO_INTEGER(UNSIGNED(data_wreg_fifo(47 downto 42)))+1);
                data5_wr <= writeregs_r(TO_INTEGER(UNSIGNED(data_wreg_fifo(47 downto 42)))+2);
                data6_wr <= writeregs_r(TO_INTEGER(UNSIGNED(data_wreg_fifo(47 downto 42)))+3);

                if(data_wreg_fifo(41 downto 32) = "0000000001") then
                    tx_st_empty0_r <= "10";
                elsif(data_wreg_fifo(41 downto 32) < "0000000100") then
                    tx_st_empty0_r <= "01";
                end if;

            else
                data4_wr <= writeregs_r(TO_INTEGER(UNSIGNED(data_wreg_fifo(47 downto 42))));
                data5_wr <= writeregs_r(TO_INTEGER(UNSIGNED(data_wreg_fifo(47 downto 42)))+1);
                data6_wr <= writeregs_r(TO_INTEGER(UNSIGNED(data_wreg_fifo(47 downto 42)))+2);
                data7_wr <= writeregs_r(TO_INTEGER(UNSIGNED(data_wreg_fifo(47 downto 42)))+3);

                if(data_wreg_fifo(41 downto 32) < "0000000011") then
                    tx_st_empty0_r <= "01";
                end if;
            end if;

            if(tx_st_ready0 = '1')then
                state <= readwreg1;
            else
                state <= readwreg;
            end if;
            --
        when readwreg1 =>
            testout_r(7 downto 0) <= "00000101";
            o_tx_st.data <= data7_wr & data6_wr & data5_wr & data4_wr & data3_wr & header2_wr & header1_wr & header0_wr;

            if(tx_st_ready0 = '1') then
                tx_st_sop0_r <= '1';
                tx_st_valid0_r <= '1';
                tx_st_eop0_r <= '1';
            read_wreg_fifo <= '1';
                state <= waiting;
                tx_st_empty0_r <= "00";
            else
                read_wreg_fifo <= '0';
                tx_st_sop0_r <= '0';
                tx_st_valid0_r <= '0';
                tx_st_eop0_r <= '0';
                tx_st_empty0_r <= tx_st_empty0_r;
                state <= readwreg1;
            end if;
            --
        when readwmempause =>
            testout_r(7 downto 0) <= "00000110";
            state <= readwmempause2;
            --
        when readwmempause2 =>
            testout_r(7 downto 0) <= "00000111";
            state <= readwmem;
            --
        when readwmem =>
            testout_r(7 downto 0) <= "00001000";

            -- Build header1; note inverse byte ordering for Avalon interface
            header0_wm <= "0" & "10" & "01010" &-- byte0: R(1) FMT(2) TYPE(5)
                "0" & "000" & "0000" & --byte1: R(1) TC(3) R(4)
                "0" & "0" & "00" & "00" & data_wmem_fifo(41 downto 32);
                --bytes 2/3: TD(1) EP(1) Attr(2) R(2) Length(10)

            header1_wm <= completer_id & "000" & "000" & "0" & wmem_bytecount; -- CompleterID (16) Copl. Status(3) BCM(1) ByteCount(12)

            header2_wm <= data_wmem_fifo(31 downto 16) & data_wmem_fifo(15 downto 8) & "0" & data_wmem_fifo(46 downto 42) & wmem_la;
                -- RequesterID(16) Tag(8) R(1) Lower address (7)

            if(data_wmem_fifo(42) = '1') then --unaligned read, add one data word in lower 128 bit
                tx_st_empty0_r <= "10";
            else -- or in the upper 128 bit - note that we only support 32 bit read here
                tx_st_empty0_r <= "01";
            end if;

            if(tx_st_ready0 = '1')then
                state <= readwmem1;
            else
                state <= readwmem;
            end if;
            --
        when readwmem1 =>
            testout_r(7 downto 0) <= "00001001";
            o_tx_st.data <=  dummydata & dummydata & dummydata & data0_wmem & data3_wmem & header2_wm & header1_wm & header0_wm;

            if(tx_st_ready0 = '1') then
                tx_st_sop0_r <= '1';
                tx_st_valid0_r <= '1';
                tx_st_eop0_r <= '1';
                read_wmem_fifo <= '1';
                state <= waiting;
                tx_st_empty0_r <= "00";
            else
                read_wmem_fifo <= '0';
                tx_st_sop0_r <= '0';
                tx_st_valid0_r <= '0';
                tx_st_eop0_r <= '0';
                tx_st_empty0_r <= tx_st_empty0_r;
                state <= readwmem1;
            end if;
            --
        when readrmempause =>
            testout_r(7 downto 0) <= "00001010";
            state <= readrmempause2;
            readmem_addr <= readmem_addr_reg + '1';
            --
        when readrmempause2 =>
            testout_r(7 downto 0) <= "00001011";
            readmemnext <= '1';
            state <= readrmem;
            --
        when readrmem =>
            testout_r(7 downto 0) <= "00001100";

            data_rmem_buffer <= readmem_data;

            -- Build header1; note inverse byte ordering for Avalon interface
            header0_rm <= "0" & "10" & "01010" &-- byte0: R(1) FMT(2) TYPE(5)
                "0" & "000" & "0000" & --byte1: R(1) TC(3) R(4)
                "0" & "0" & "00" & "00" & data_rmem_fifo(41 downto 32);
                --bytes 2/3: TD(1) EP(1) Attr(2) R(2) Length(10)

            if ( data_rmem_fifo(41 downto 32) = "0000000100" ) then -- four word read request,
                header1_rm <= completer_id & "000" & "000" & "0" & rmem_bytecount; -- CompleterID (16) Copl. Status(3) BCM(1) ByteCount(12)
            else -- one word read request
                header1_rm <= completer_id & "000" & "000" & "0" & rmem_bytecount; -- CompleterID (16) Copl. Status(3) BCM(1) ByteCount(12)
            end if;

            header2_rm <= data_rmem_fifo(31 downto 16) & data_rmem_fifo(15 downto 8) & "0" & data_rmem_fifo(46 downto 42) & rmem_la;
                -- RequesterID(16) Tag(8) R(1) Lower address (7)

            -- check one word read request for alignment
            if ( data_rmem_fifo(41 downto 32) = "0000000001" ) then -- one word read request
                if(data_rmem_fifo(42) = '1') then  -- unaligned
                    tx_st_empty0_r <= "10";
                else
                    tx_st_empty0_r <= "01";
                end if;
            elsif( data_rmem_fifo(41 downto 32) = "0000000100" ) then -- four word read request (others do not seem to happen)
                tx_st_empty0_r <= "00";
            end if;

            -- check read request for alignment
            if ( readmemnext = '1' ) then
                if(data_rmem_fifo(42) = '1') then  -- unaligned
                    if(data_rmem_fifo(43) = '0') then
                        data3_rmem <= readmem_data(63 downto 32);
                        data4_rmem <= readmem_data(95 downto 64);
                        data5_rmem <= readmem_data(127 downto 96);
                    else
                        data3_rmem <= readmem_data(127 downto 96);
                    end if;
                else   -- aligned
                    if(data_rmem_fifo(43) = '0') then
                        data4_rmem <= readmem_data(31 downto 0);
                        data5_rmem <= readmem_data(63 downto 32);
                        data6_rmem <= readmem_data(95 downto 64);
                        data7_rmem <= readmem_data(127 downto 96);
                    else
                        data4_rmem <= readmem_data(95 downto 64);
                        data5_rmem <= readmem_data(127 downto 96);
                    end if;
                end if;
            end if;

            if(tx_st_ready0 = '1')then
                state <= readrmem1;
            else
                state <= readrmem;
            end if;
            --
        when readrmem1 =>
            testout_r(7 downto 0) <= "00001101";
            o_tx_st.data(127 downto 0) <= data3_rmem & header2_rm & header1_rm & header0_rm;
            tx_st_eop0_r <= '0';
            tx_st_empty0_r <= "00";
            read_rmem_fifo <= '0';
            if(tx_st_ready0 = '1') then
                tx_st_sop0_r <= '1';
                tx_st_valid0_r <= '1';
                tx_st_eop0_r <= '1';
                read_rmem_fifo <= '1';
                state <= waiting;
                -- check four word read request for alignment
                if(data_rmem_fifo(42) = '1') then  -- unaligned
                    if(data_rmem_fifo(43) = '0') then
                        o_tx_st.data(191 downto 128) <=  data4_rmem & data5_rmem;
                        o_tx_st.data(223 downto 192) <=  readmem_data(31 downto 0);
                    else
                        o_tx_st.data(223 downto 128) <= readmem_data(95 downto 0);
                    end if;
                else   -- aligned
                    if(data_rmem_fifo(43) = '0') then
                        o_tx_st.data(255 downto 128) <= data7_rmem & data6_rmem & data5_rmem & data4_rmem;
                    else
                        o_tx_st.data(255 downto 192) <= readmem_data(63 downto 0);
                        o_tx_st.data(191 downto 128) <= data5_rmem & data4_rmem;
                    end if;
                end if;
            else
                tx_st_sop0_r <= '0';
                tx_st_eop0_r <= '0';
                tx_st_valid0_r <= '0';
                tx_st_empty0_r <=  tx_st_empty0_r;
                state <= readrmem1;
            end if;
            --
        when dma =>
            testout_r(7 downto 0) <= "00001111";
            o_tx_st.data <= i_dma_tx.data;
            tx_st_valid0_r <= i_dma_tx.valid;
            tx_st_sop0_r <= i_dma_tx.sop;
            tx_st_eop0_r <= i_dma_tx.eop;
            o_tx_st.empty <= i_dma_tx.empty; -- needs to be in the same cycle as the
                                                                -- others, so
                                                                -- it will not
                                                                -- go via the
                                                                -- _r signal

            dma_granted_r <= '0';
            if(dma_done = '1')then
                state <= waiting;
            end if;
            --
        when dma2 =>
            testout_r(7 downto 0) <= "00010000";
            o_tx_st.data <= i_dma2_tx.data;
            tx_st_valid0_r <= i_dma2_tx.valid;
            tx_st_sop0_r <= i_dma2_tx.sop;
            tx_st_eop0_r <= i_dma2_tx.eop;
            o_tx_st.empty <= i_dma2_tx.empty; -- needs to be in the same cycle as the
                                                                -- others, so
                                                                -- it will not
                                                                -- go via the
                                                                -- _r signal

            dma2_granted_r <= '0';
            if(dma2_done = '1')then
                state <= waiting;
            end if;
            --
        end case;
    end if;
    end process;

end architecture;

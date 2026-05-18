-----------------------------------------------------------------------------
-- DMA engine
--
-- Niklaus Berger, Heidelberg University
-- nberger@physi.uni-heidelberg.de
--
-- 2015 / 2016
-- modified and adapted to scatter / gather DMA by
-- Dorothea vom Bruch, Mainz University
-- vombruch@uni-mainz.de
--
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.a10_pcie_registers.all;

entity dma_engine is
generic (
    g_WADDR_WIDTH : positive := 13;
    g_RADDR_WIDTH : positive := 11;
    g_DATA_WIDTH : positive := 64;
    IRQNUM                      : std_logic_vector(4 downto 0) := "00000";
    ENABLE_BIT                  : integer := 0;
    NOW_BIT                     : integer := 0;
    ENABLE_INTERRUPT_BIT        : integer := 0
);
port (
    -- Stuff for DMA writing
    dataclk                     : in    std_logic;
    datain                      : in    std_logic_vector(g_DATA_WIDTH-1 downto 0);
    datawren                    : in    std_logic;
    endofevent                  : in    std_logic;
    memhalffull                 : out   std_logic;

    -- Bus and device number
    cfg_busdev                  : in    std_logic_vector(12 downto 0);

    -- Comunication with completer
    dma_request                 : out   std_logic;
    dma_granted                 : in    std_logic;
    dma_done                    : out   std_logic;

    o_tx                        : out   work.util.avst256_t;
    tx_ready                    : in    std_logic;

    -- Interrupt stuff
    app_msi_req                 : out   std_logic;
    app_msi_tc                  : out   std_logic_vector(2 downto 0);
    app_msi_num                 : out   std_logic_vector(4 downto 0);
    app_msi_ack                 : in    std_logic;

    -- Configuration register
    dma_control_address         : in    std_logic_vector(63 downto 0);
    dma_data_address            : in    std_logic_vector(63 downto 0);
    dma_data_address_out        : out   std_logic_vector(63 downto 0);
    dma_data_mem_addr           : in    std_logic_vector(11 downto 0);
    dma_addrmem_data_written    : in    std_logic;
    dma_register                : in    std_logic_vector(31 downto 0);
    dma_register_written        : in    std_logic;
    dma_data_pages              : in    std_logic_vector(19 downto 0);
    dma_data_pages_out          : out   std_logic_vector(19 downto 0);
    dma_data_n_addrs            : in    std_logic_vector(11 downto 0);

    dma_status_register         : out   std_logic_vector(31 downto 0);

    test_out                    : out   std_logic_vector(71 downto 0);

    i_reset_n                   : in    std_logic;
    i_clk                       : in    std_logic--;
);
end entity;

architecture RTL of dma_engine is

    type dma_state_type is (disabled, waiting, requested, pause_dma1, pause_dma2, header, running, controlinfoheader, interrupt);
    signal state : dma_state_type;

    signal memwriteaddr                 : std_logic_vector(g_WADDR_WIDTH-1 downto 0);
    signal memwriteaddr_long            : std_logic_vector(63 downto 0);
    signal memwriteaddr_last            : std_logic_vector(g_WADDR_WIDTH-1 downto 0);
    signal memdatawren                  : std_logic;

    signal enoughdata                   : std_logic_vector(31 downto 0);
    signal overflow                     : std_logic;
    signal memoryblock_dma              : std_logic_vector(3 downto 0);
    signal memoryblock_written          : std_logic_vector(3 downto 0);
    signal start_dma                    : std_logic;
    signal start_dma_last               : std_logic;
    signal start_dma_next               : std_logic;

    signal memwriteaddreoe              : std_logic_vector(g_WADDR_WIDTH-1 downto 0);
    signal memwriteaddreoedma           : std_logic_vector(g_WADDR_WIDTH-1 downto 0);
    signal memwriteaddreoe_long         : std_logic_vector(63 downto 0);
    signal memwriteaddreoedma_long      : std_logic_vector(63 downto 0);

    signal memaddr                      : std_logic_vector(g_RADDR_WIDTH-1 downto 0);
    signal memout                       : std_logic_vector(255 downto 0);
    signal memoutbuffer                 : std_logic_vector(127 downto 0);

    signal dma_enabled                  : std_logic;
    signal dma_now                      : std_logic;
    signal interrupt_enabled            : std_logic;
    signal timeoutcounter               : std_logic_vector(27 downto 0);

    signal tx_data_last                 : std_logic_vector(255 downto 0);
    signal tx_data_r                    : std_logic_vector(255 downto 0);

    signal memwraddr_last_dma           : std_logic_vector(g_RADDR_WIDTH-1 downto 0);
    signal memaddr_last_packet          : std_logic_vector(g_RADDR_WIDTH-1 downto 0);

    signal packet_length_l              : std_logic_vector(10 downto 0);
    signal packet_length                : std_logic_vector(9 downto 0);
    signal words_sent                   : std_logic_vector(9 downto 0);
    signal blocks                       : std_logic_vector(6 downto 0);
    signal last_dw_be                   : std_logic;

    signal remoteaddress_var            : std_logic_vector(31 downto 0); -- assume buffer is not larger than 4 GB
    signal remoteaddress_next           : std_logic_vector(63 downto 0);
    signal remoteaddress_interrupt      : std_logic_vector(31 downto 0);

    signal dma_status_register_reg      : std_logic_vector(31 downto 0);

    -- signals for RAM containing DMA addresses
    signal dma_data_mem_addr_fpga       : std_logic_vector(11 downto 0);
    signal dma_data_mem_addr_reg        : std_logic_vector(11 downto 0);
    signal dma_addrmem_data_written_reg : std_logic;
    signal dma_data_address_out_fpga    : std_logic_vector(63 downto 0);
    signal dma_data_address_out_reg     : std_logic_vector(63 downto 0);
    signal dma_data_address_reg         : std_logic_vector(63 downto 0);

    -- signals for RAM containing DMA pages
    signal dma_data_pages_out_fpga      : std_logic_vector(19 downto 0);
    signal dma_data_pages_out_reg       : std_logic_vector(19 downto 0);
    signal dma_data_pages_reg           : std_logic_vector(19 downto 0);
    signal count_pages                  : std_logic_vector(19 downto 0);
    signal dma_data_n_addrs_reg         : std_logic_vector(11 downto 0);

    -- signals for DMA fifo and memory writing
    signal aclr                         : std_logic;
    signal data_fifo                    : std_logic_vector(127 downto 0);
--    signal empty_fifo                   : std_logic;
--    signal empty_fifo_r                 : std_logic;
    signal full_fifo                    : std_logic;

    signal tx_ready_last                : std_logic;
    signal tx_valid_r                   : std_logic;

    signal interruptcounter             : std_logic_vector(5 downto 0);
    signal dma_block_counter            : std_logic_vector(3 downto 0);
    signal pause_counter                : std_logic_vector(9 downto 0);

    signal test_out_r                   : std_logic_vector(71 downto 0);

begin

    dma_status_register <= dma_status_register_reg;

    aclr <= not i_reset_n;

    o_tx.data <= tx_data_r when tx_valid_r = '1'
        else tx_data_last;
    o_tx.valid <= tx_valid_r;
    o_tx.err <= '0';

    -- handle register signals
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        dma_enabled <= '0';
        dma_now <= '0';
        interrupt_enabled <= '0';
        dma_addrmem_data_written_reg <= '0';
    elsif rising_edge(i_clk) then
        dma_enabled <= dma_register(ENABLE_BIT);
        -- for simulation
        -- synthesis translate_off
            dma_enabled <= '1';
        -- synthesis translate_on
        interrupt_enabled <= dma_register(ENABLE_INTERRUPT_BIT);
        if(dma_register(NOW_BIT) = '1' and dma_register_written = '1') then
            dma_now <= '1';
        else
            dma_now <= '0';
        end if;

        dma_data_mem_addr_reg <= dma_data_mem_addr;
        dma_data_address_out <= dma_data_address_out_reg;
        dma_addrmem_data_written_reg <= dma_addrmem_data_written;
        dma_data_address_reg <= dma_data_address;
        dma_data_pages_reg <= dma_data_pages;
        dma_data_pages_out <= dma_data_pages_out_reg;
        dma_data_n_addrs_reg <= dma_data_n_addrs;
    end if;
    end process;

    process(i_clk, i_reset_n)
        variable header0 : std_logic_vector(31 downto 0);
        variable header1 : std_logic_vector(31 downto 0);
        variable header2 : std_logic_vector(31 downto 0);
        variable header3 : std_logic_vector(31 downto 0);

        variable d0 : std_logic_vector(31 downto 0);
        variable d1 : std_logic_vector(31 downto 0);
        variable d2 : std_logic_vector(31 downto 0);
        variable d3 : std_logic_vector(31 downto 0);

        variable addrtemp : std_logic_vector(g_RADDR_WIDTH-1 downto 0);
    begin
    if ( i_reset_n = '0' ) then
        dma_request <= '0';
        dma_done <= '0';

        --tx_data_r <= (others => '0');
        tx_valid_r <= '0';
        o_tx.sop <= '0';
        o_tx.eop <= '0';
        o_tx.empty <= "00";

        tx_ready_last <= '0';

        app_msi_req <= '0';
        app_msi_tc <= (others => '0');
        app_msi_num <= (others => '0');

        timeoutcounter <= (others => '1');

        memwraddr_last_dma <= (others => '0');
        state <= disabled;

        memaddr <= (others => '1');

        dma_status_register_reg <= (others => '0');

        interruptcounter <= (others => '0');
        count_pages <= (others => '0');

        overflow <= '0';
        enoughdata <= (others => '0');
        memoryblock_dma <= (others => '0');
        start_dma_last <= '0';

        dma_data_mem_addr_fpga <= (others => '0');

        test_out_r <= (others => '0');
        --
    elsif rising_edge(i_clk) then

        test_out <= test_out_r;

        test_out_r(27 downto 12) <= datain(22 downto 7);
--        test_out_r(35 downto 28) <= data_fifo(11 downto 4);
        test_out_r(35 downto 28) <= (others => '0'); -- dma_fifo is commented out, thus data_fifo is not connected
        test_out_r(10 downto 0) <= memwriteaddr(10 downto 0);
        test_out_r(11) <= '0'; -- currently unused bits
        test_out_r(71 downto 70) <= (others => '0'); -- currently unused bits

        if(tx_valid_r = '1') then
            tx_data_last <= tx_data_r;
        else
            tx_data_last <= tx_data_last;
        end if;

        tx_ready_last <= tx_ready;

        -- if 4 kB written data were detected with data clock, then start DMA procedure for this block
        if( start_dma_next /= start_dma_last ) then -- make sure to detect start_dma_next signal only once
            enoughdata( to_integer( unsigned( memoryblock_written ) ) ) <= '1';
            if(enoughdata( to_integer( unsigned( memoryblock_written) ) ) = '1') then -- wrapped around DMA buffer once w/o having sent off the data
                overflow <= '1';
            end if;
        end if;
        start_dma_last <= start_dma_next;

        dma_status_register_reg(15 downto 0) <= (others => '0');
        dma_status_register_reg(31 downto 28) <= overflow & "000";
        dma_status_register_reg(27 downto 16) <= "00000000" & dma_block_counter;

        case state is
        when disabled =>
            dma_status_register_reg(0) <= '1';

            dma_request <= '0';
            dma_done <= '0';

            --tx_data_r <= (others => '0');
            tx_valid_r <= '0';
            o_tx.sop <= '0';
            o_tx.eop <= '0';
            o_tx.empty <= "00";

            app_msi_req <= '0';
            app_msi_tc <= (others => '0');
            app_msi_num <= (others => '0');

            timeoutcounter <= (others => '1');

            memwraddr_last_dma <= (others => '0');
            memaddr_last_packet <= (others => '0');
            memaddr <= (others => '1');
            memwriteaddreoedma <= (others => '0');
            memwriteaddreoedma_long <= (others => '0');
            words_sent <= (others => '0');

            remoteaddress_var <= (others => '0');
            remoteaddress_interrupt <= (others => '0');
            dma_data_mem_addr_fpga <= (others => '0');

            interruptcounter <= (others => '0');
            count_pages <= (others => '0');
            enoughdata <= (others => '0');
            memoryblock_dma <= (others => '0');
            overflow <= '0';
            start_dma_last <= '0';

            --test_out_r <= (others => '0');

            if(dma_enabled = '1') then
                state <= waiting;
            end if;

        when waiting =>

            if(dma_enabled = '0') then
                state <= disabled;
            end if;
            dma_block_counter <= (others => '0');
            pause_counter <= (others => '0');

            dma_status_register_reg(1) <= '1';

            dma_request <= '0';
            dma_done <= '0';

            --tx_data_r <= (others => '0');
            tx_valid_r <= '0';
            o_tx.sop <= '0';
            o_tx.eop <= '0';
            o_tx.empty <= "00";

            timeoutcounter <= timeoutcounter - '1';

            -- start the dma procedure either on command, after about a second or after 4 KB data have been written
            --if(((dma_now = '1' or timeoutcounter = 0) and memwraddr /= memwraddr_last_dma) or memwraddr(9) /= memwraddr_last(9)) then

            -- start the dma procedure after 4 KB of data have been written
            if( enoughdata /= 0 ) then
                enoughdata( to_integer( unsigned( memoryblock_dma ))) <= '0';
                memoryblock_dma <= memoryblock_dma + '1';
                state <= requested;
                dma_request <= '1';
                memwraddr_last_dma <= (memoryblock_dma + '1') & "0000000";
                packet_length_l <= "00001000000"; -- 64
                blocks <= "0010000"; --16
                memaddr <= memwraddr_last_dma;
                memaddr_last_packet <= memwraddr_last_dma;
                memwriteaddreoedma <= memwriteaddreoe;
                memwriteaddreoedma_long <= memwriteaddreoe_long;
                words_sent <= (others => '0');
            end if;

        when requested =>
            dma_status_register_reg(2) <= '1';

            dma_done <= '0';
            dma_block_counter <= (others => '0');

            --tx_data_r <= (others => '0');
            tx_valid_r <= '0';
            o_tx.sop <= '0';
            o_tx.eop <= '0';
            o_tx.empty <= "00";

            packet_length <= packet_length_l(9 downto 0);

            last_dw_be <= '1';

            if(dma_granted = '1') then
                state <= header;
                memaddr <= memaddr+'1';
            end if;

            remoteaddress_next <= dma_data_address_out_fpga + (count_pages & x"000"); -- one PCIe block has 0x100 bytes, one 4096B page per DMA block

        -- wait one cycle for dma_granted to be set to '0' in completer
        when pause_dma1 =>
            dma_status_register_reg(3) <= '1';
            state <= pause_dma2;
            dma_done <= '0';
            dma_request <= '1';

            --tx_data_r <= (others => '0');
            tx_valid_r <= '0';
            o_tx.sop <= '0';
            o_tx.eop <= '0';
            o_tx.empty <= "00";

        when pause_dma2 =>
            dma_status_register_reg(4) <= '1';
            --dma_request <= '1';

            --tx_data_r <= (others => '0');
            tx_valid_r <= '0';
            o_tx.sop <= '0';
            o_tx.eop <= '0';
            o_tx.empty <= "00";
            last_dw_be <= '1';

            pause_counter <= pause_counter + '1';

            if(dma_granted = '1') then
                state <= header;
                memaddr <= memaddr+'1';
                if ( pause_counter /= "0010") then -- stayed longer than minimum 3 cycles in pause2 state -> other stuff happening on bus
                    dma_block_counter <= (others => '0');
                else
                    dma_block_counter <= dma_block_counter + '1'; -- counts consecutive DMA blocks w/o other stuff happening
                end if;
            end if;

        when header =>
            dma_status_register_reg(5) <= '1';
            dma_request <= '0';
            dma_done <= '0';

            -- build header out of 4 32 bit words, different for addresses above and below 4GB!
            -- second word is the same for 32 bit addressing and 64 bit addressing
            header1 := cfg_busdev & "000" & -- bytes 0 and 1: Requester ID
                "00000000" & -- byte 2: tag
                last_dw_be & last_dw_be & last_dw_be & last_dw_be & "1111"; -- byte 3 last and first data word byte enables

            -- 32 bit addressing
            if ( remoteaddress_next(63 downto 32) = x"00000000" ) then
                header0 := "0" & "10" & "00000" &-- byte0: R(1) FMT(2) TYPE(5)
                    "0" & "000" & "0000" & --byte1: R(1) TC(3) R(4)
                    "0" & "0" & "00" & "00" & packet_length; -- packet length is in words
                    --bytes 2/3: TD(1) EP(1) Attr(2) R(2) Length(10)
                header2 := remoteaddress_next(31 downto 4) & "0000"; -- last four bits should always be 0!
                header3 := (others => '0');  -- reserved
            else
                -- 64 bit addressing

                header0 := "0" & "11" & "00000" &-- byte0: R(1) FMT(2) TYPE(5)
                    "0" & "000" & "0000" & --byte1: R(1) TC(3) R(4)
                    "0" & "0" & "00" & "00" & packet_length; -- packet length is in words
                    --bytes 2/3: TD(1) EP(1) Attr(2) R(2) Length(10)
                header2 := remoteaddress_next(63 downto 32);
                header3 := remoteaddress_next(31 downto 4) & "0000"; -- last four bits should always be 0!
            end if;

            if(dma_status_register_reg(2) = '1' or dma_status_register_reg(4) = '1') then -- we just had the state transition and are pointing to the right place in memory
                tx_data_r <= memout(127 downto 0) & header3 & header2 & header1 & header0;
                memoutbuffer <= memout(255 downto 128);
            end if;

            tx_valid_r <= '0';
            o_tx.sop <= '0';
            o_tx.eop <= '0';
            o_tx.empty <= "00";

            if(tx_ready_last = '1') then
                tx_valid_r <= '1';
                o_tx.sop <= '1';
                o_tx.eop <= '0';
                o_tx.empty <= "00";
                state <= running;

                remoteaddress_var <= remoteaddress_var  + (packet_length & "00"); -- in bytes
                words_sent <= words_sent + "0000000100";
            end if;
            if(tx_ready = '1' and tx_ready_last = '1') then
                memaddr <= memaddr+'1';
            end if;

        when running =>
            dma_status_register_reg(6) <= '1';

            tx_data_r <= memout(127 downto 0) & memoutbuffer;

            if(tx_ready_last = '1') then
                tx_valid_r <= '1';
                o_tx.sop <= '0';
                o_tx.eop <= '0';
                o_tx.empty <= "00";
                words_sent <= words_sent + "000001000";
                memoutbuffer <= memout(255 downto 128);
            else
                tx_valid_r <= '0';
                o_tx.sop <= '0';
                o_tx.eop <= '0';
                o_tx.empty <= "00";
                words_sent <= words_sent;
            end if;

            if(words_sent >= "0000111000" and tx_ready_last = '1')then -- check for PCIe-block boundary
                tx_valid_r <= '1';
                o_tx.sop <= '0';
                o_tx.eop <= '1';

                -- Upper half of the packet should be empty
                o_tx.empty <= "10";

                addrtemp := memaddr_last_packet + "1000";
                memaddr <= addrtemp(g_RADDR_WIDTH-1 downto 1) & "0";
                memaddr_last_packet <= memaddr_last_packet + "1000";

                if(blocks <= "0000001") then
                    state <= controlinfoheader;
                    count_pages <= count_pages + '1';
                    dma_block_counter <= (others => '0');
                    if ( interruptcounter = "111111" ) then
                        remoteaddress_interrupt <= remoteaddress_var;
                    end if;

                else -- pause DMA to check for other requests to happen on PCIe bus
                    state <= pause_dma1;
                    pause_counter <= (others => '0');
                    dma_done <= '1';
                    --state <= header;
                    blocks <= blocks - '1';
                    words_sent <= (others => '0');
                    remoteaddress_next <= remoteaddress_next + (packet_length & "00");
                end if;


            else
                if(tx_ready = '1' and words_sent < "0000111000") then
                    memaddr <= memaddr+'1';
                else
                    memaddr  <= memaddr;
                end if;
            end if;

        when controlinfoheader =>
            dma_status_register_reg(7) <= '1';

            test_out_r(47 downto 36) <= count_pages(11 downto 0);
            --test_out_r(11 downto 0) <= dma_data_pages_out_fpga(11 downto 0);

            -- build header out of 4 32 bit words, different for addresses above and below 4GB!
            -- second word is the same for 32 bit addressing and 64 bit addressing
            header1 := cfg_busdev & "000" & -- bytes 0 and 1: Requester ID
                "00000000" & -- byte 2: tag
                "1111" & "1111"; -- byte 3 last and first data word byte enables

            -- 32 bit addressing
            if ( dma_control_address(63 downto 32) = x"00000000" ) then
                header0 := "0" & "10" & "00000" &-- byte0: R(1) FMT(2) TYPE(5)
                    "0" & "000" & "0000" & --byte1: R(1) TC(3) R(4)
                    "0" & "0" & "00" & "00" & "0000000100";
                    --bytes 2/3: TD(1) EP(1) Attr(2) R(2) Length(10)
                header2 := dma_control_address(31 downto 0); -- last two bits should always be 0!
                header3 := (others => '0'); -- reserved
            else
                -- 64 bit addressing

                header0 := "0" & "11" & "00000" &-- byte0: R(1) FMT(2) TYPE(5)
                    "0" & "000" & "0000" & --byte1: R(1) TC(3) R(4)
                    "0" & "0" & "00" & "00" & "0000000100";
                --bytes 2/3: TD(1) EP(1) Attr(2) R(2) Length(10)
                header2 := dma_control_address(63 downto 32);
                header3 := dma_control_address(31 downto 0); -- last two bits should always be 0!
            end if;

--            d0 := remoteaddress_next(31 downto 0); -- address of next packet
--            d1 := remoteaddress_next(63 downto 32);

            d0 := memwriteaddreoedma_long(31 downto 0);
            d1 := memwriteaddreoedma_long(63 downto 32);

            d2 := (others => '0');
            d2(16+g_WADDR_WIDTH-1 downto 0) := memwriteaddreoedma & "0000" & packet_length & "00"; -- packet length and memaddr in words; convert to bytes

            d3 := remoteaddress_interrupt;



            tx_data_r <= d3 & d2 & d1 & d0 & header3 & header2 & header1 & header0;

            tx_valid_r <= '0';
            o_tx.sop <= '0';
            o_tx.eop <= '0';
            o_tx.empty <= "00";


            if(tx_ready_last = '1') then

                if ( count_pages >= dma_data_pages_out_fpga ) then
                    dma_data_mem_addr_fpga <= dma_data_mem_addr_fpga + '1';
                    count_pages <= (others => '0');

                    if ( dma_data_mem_addr_fpga + '1' >= dma_data_n_addrs_reg) then -- reached end of DMA buffer, start at beginning again
                        dma_data_mem_addr_fpga <= (others => '0');
                        remoteaddress_var <= (others => '0');
                    end if;

                end if;


                tx_valid_r <= '1';
                o_tx.sop <= '1';
                o_tx.eop <= '1';
                o_tx.empty <= "00";

                if(interruptcounter = "111111" and interrupt_enabled = '1') then  -- interrupt every 64 DMA blocks
                    state <= interrupt;
                else
                    state <= waiting;
                    dma_done <= '1';
                end if;
                interruptcounter <= interruptcounter + '1';
            end if;

            test_out_r(69 downto 60) <= dma_data_mem_addr_fpga(9 downto 0);
            test_out_r(59 downto 48) <= dma_data_n_addrs_reg;

        when interrupt =>
            dma_status_register_reg(9) <= '1';
            tx_valid_r <= '0';
            o_tx.sop <= '0';
            o_tx.eop <= '0';
            o_tx.empty <= "00";

            app_msi_req <= '1';
            app_msi_tc <= (others => '0'); -- stay with traffic class 0
            app_msi_num <= IRQNUM;

            if(app_msi_ack = '1') then
                dma_done <= '1';
                app_msi_req <= '0';
                state <= waiting;
            end if;

        when others =>
            state <= disabled;
        end case;
    end if;
    end process;

    -- increment memory address only if dma is enabled
    -- check for 4kB of written data using the dataclk
    process(dataclk, i_reset_n)
        variable diff : std_logic_vector(g_RADDR_WIDTH-1 downto 0);
    begin
    if ( i_reset_n = '0' ) then
        memwriteaddr <= (others => '0');
        memwriteaddr_long <= (others => '0');
        memwriteaddr_last <= (others => '0');
        memdatawren <= '0';
        memwriteaddreoe <= (others => '0');
        start_dma <= '0';
        start_dma_next <= '0';
        memoryblock_written <= (others => '0');

        memhalffull <= '0';

    elsif rising_edge(dataclk) then

--        empty_fifo_r <= empty_fifo;

        if(state = disabled) then
            memwriteaddr <= (others => '0');
            memwriteaddr_long <= (others => '0');
            memwriteaddr_last <= (others => '0');
            memwriteaddreoe <= (others => '0');
            start_dma <= '0';
            start_dma_next <= '0';
            memoryblock_written <= (others => '0');
            memhalffull <= '0';
        else
            if( datawren = '1') then
                memwriteaddr <= memwriteaddr + '1';
                memwriteaddr_long <= memwriteaddr_long + '1';
            end if;
            if(endofevent = '1') then
                memwriteaddreoe  <= memwriteaddr;
                memwriteaddreoe_long <= memwriteaddr_long;
            end if;

            -- check for 4kB written data
            if(memwriteaddr(g_WADDR_WIDTH-4) /= memwriteaddr_last(g_WADDR_WIDTH-4)) then -- 64 bit words input
                memoryblock_written <= memwriteaddr_last(g_WADDR_WIDTH-1 downto g_WADDR_WIDTH-4);
                start_dma <= not(start_dma);
            end if;
            memwriteaddr_last <= memwriteaddr;
            start_dma_next <= start_dma; -- wait one cycle until ref_clk sees transition

--            if(memwriteaddr_last(g_WADDR_WIDTH-1 downto 1) >= memaddr_last_packet) then
--                diff := (memwriteaddr_last(g_WADDR_WIDTH-1 downto 2) - memaddr_last_packet);
--            else
--                diff := (memaddr_last_packet- memwriteaddr_last(g_WADDR_WIDTH-1 downto 2));
--            end if;
--            if(memwriteaddr_last >= memaddr_last_packet) then
--                diff := (memwriteaddr_last - memaddr_last_packet);
--            else
--                diff := (memaddr_last_packet - memwriteaddr_last);
--            end if;

            if(memwriteaddr >= memaddr_last_packet) then
                diff := (memwriteaddr - memaddr_last_packet);
            else
                diff := (memaddr_last_packet - memwriteaddr);
            end if;
            memhalffull <= diff(g_RADDR_WIDTH-1);
        end if;
    end if;
    end process;

    e_dma_ram : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => memwriteaddr'length,
        g_DATA0_WIDTH => datain'length,
        g_ADDR1_WIDTH => memaddr'length,
        g_DATA1_WIDTH => memout'length--,
    )
    port map (
        i_addr0     => memwriteaddr,
        i_wdata0    => datain,
        i_we0       => datawren,
        i_clk0      => dataclk,

        i_addr1     => memaddr,
        o_rdata1    => memout,
        i_clk1      => i_clk--,
    );

    e_dma_data_mem_addrs : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => dma_data_mem_addr_reg'length,
        g_DATA0_WIDTH => dma_data_address_reg'length,
        g_ADDR1_WIDTH => dma_data_mem_addr_fpga'length,
        g_DATA1_WIDTH => dma_data_address_out_fpga'length,
        g_RDATA0_REG => 1,
        g_RDATA1_REG => 1--,
    )
    port map (
        -- remote interface
        i_addr0     => dma_data_mem_addr_reg,
        i_wdata0    => dma_data_address_reg,
        i_we0       => dma_addrmem_data_written_reg, -- write only when register with data address changes
        o_rdata0    => dma_data_address_out_reg,
        i_clk0      => i_clk,

        -- FPGA interface
        i_addr1     => dma_data_mem_addr_fpga,
        o_rdata1    => dma_data_address_out_fpga,
        i_clk1      => i_clk--,
    );

    e_dma_data_mem_pages : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => dma_data_mem_addr_reg'length,
        g_DATA0_WIDTH => dma_data_pages_reg'length,
        g_ADDR1_WIDTH => dma_data_mem_addr_fpga'length,
        g_DATA1_WIDTH => dma_data_pages_out_fpga'length,
        g_RDATA0_REG => 1,
        g_RDATA1_REG => 1--,
    )
    port map (
        -- remote interface
        i_addr0     => dma_data_mem_addr_reg, -- number of pages pointed to by address stored in data_addrs_ram
        i_wdata0    => dma_data_pages_reg,
        i_we0       => dma_addrmem_data_written_reg,
        o_rdata0    => dma_data_pages_out_reg,
        i_clk0      => i_clk,

        -- FPGA interface
        i_addr1     => dma_data_mem_addr_fpga,
        o_rdata1    => dma_data_pages_out_fpga,
        i_clk1      => i_clk--,
    );

end architecture;

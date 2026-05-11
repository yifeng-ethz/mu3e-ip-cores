----------------------------------------------------------------------------
-- Rewrite of Slow Control Main Unit for Switching Board without wait_cnt to improve sc speed
--
-- M.Mueller, FEB 2023
--
-- based on older version by M. Koeppel and S.Dittmeier
--
-- i_clk is running at the pcie clock speed
-- o_mem_data is the data that needs to be send to the FEB. since the link to the FEB is only running at 156 Mhz we cannot send a word every cycle there
-- there is no backpressure implemented from the FEB link and it is also not neccessary since it is impossible for the software to write at that speed
-- however the datapacket is already fully in memory when we get the start signal (i_length_we) and therefore we still need to be carefull how to write to the FEB
-- In additon the connection from the pcie writeable memory to 36 output fifo's is timing wise not easy at 250 MHz
-- the problems above where previously solved with a large wait_cnt between words, which became the limiting factor for the downwards bandwidth
-- this new implementation solves these issues without a large wait_cnt between words to remove this limitation.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.util_slv.all;

entity swb_sc_main is
generic (
    NLINKS : positive := 4
);
port (
    i_length_we     : in    std_logic;
    i_length        : in    std_logic_vector(15 downto 0);
    i_mem_data      : in    std_logic_vector(31 downto 0);
    o_mem_addr      : out   std_logic_vector(15 downto 0);
    o_mem_data      : out   work.mu3e.link32_array_t(NLINKS-1 downto 0);
    o_injection     : out   work.mu3e.link32_array_t(3 downto 0);
    o_done          : out   std_logic;
    o_state         : out   std_logic_vector(27 downto 0);

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture arch of swb_sc_main is

    signal fifo_we      : std_logic;
    signal fifo_wdata   : std_logic_vector(39 downto 0);
    signal fifo_rdata   : std_logic_vector(39 downto 0);
    signal fifo_full    : std_logic;
    signal fifo_empty   : std_logic;
    signal fifo_rack    : std_logic;
    signal clkdiv       : std_logic;
    signal wren_mask    : std_logic_vector(63 downto 0);
    signal wren_mask_wr : std_logic_vector(63 downto 0);
    signal mem_data     : work.mu3e.link32_array_t(NLINKS-1 downto 0);
    signal mem_addr     : std_logic_vector(15 downto 0);
    signal tx_word_idx  : std_logic_vector(15 downto 0);

    type state_type is (
        request_header, check_header, set_fpga_id1, set_fpga_id2, emit_header, request_word, latch_word, emit_word, idle
    );
    signal state : state_type;

    signal length_we_reg : std_logic;
    signal length        : std_logic_vector(15 downto 0);
    signal header_word   : std_logic_vector(31 downto 0);
    signal body_word     : std_logic_vector(31 downto 0);
    signal body_last     : std_logic;

begin

    o_mem_addr <= mem_addr;

    write_process: process(i_clk,i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        fifo_we         <= '0';
        o_state         <= (others => '0');
        state           <= idle;
        fifo_wdata      <= (others => '0');
        o_done          <= '0';
        length          <= (others => '0');
        wren_mask_wr    <= (others => '0');
        tx_word_idx     <= (others => '0');
        mem_addr        <= (others => '0');
        header_word     <= (others => '0');
        body_word       <= (others => '0');
        body_last       <= '0';
        length_we_reg   <= '0';
    elsif rising_edge(i_clk) then
        fifo_we <= '0';
        fifo_wdata <= (others => '0');
        length_we_reg <= i_length_we;

        case state is
        when idle =>
            o_state <= x"0000001";
            o_done          <= '1';
            mem_addr         <= (others => '0');
            if ( length_we_reg = '0' and i_length_we = '1' ) then
                state           <= request_header;
                o_done          <= '0';
                length          <= i_length;
                tx_word_idx     <= (others => '0');
                wren_mask_wr    <= (others => '0');
            end if;
        when request_header =>
            o_state         <= x"0000002";
            mem_addr        <= (others => '0');
            state           <= check_header;
        when check_header =>
            o_state         <= x"0000003";
            mem_addr        <= x"0001";
            header_word     <= i_mem_data;
            if ( i_mem_data(7 downto 0) = x"BC" ) then
                state       <= set_fpga_id1;
                tx_word_idx <= x"0001";
                if (or_reduce(i_mem_data(19 downto 16)) = '0') then -- no injection, set fpga ID
                    wren_mask_wr(to_integer(unsigned(i_mem_data(13 downto 8)))) <= '1';
                end if;
                if (i_mem_data(13 downto 8) = "111111") then -- broadcast
                    wren_mask_wr(35 downto 0)  <= (others => '1');
                    wren_mask_wr(51 downto 48) <= (others => '0');
                else
                    wren_mask_wr(51 downto 48) <= i_mem_data(19 downto 16); -- injections
                end if;
            else
                state       <= idle;
                wren_mask_wr <= (others => '0');
            end if;
        when set_fpga_id1 =>
            o_state         <= x"0000004";
            mem_addr        <= x"0001";
            if ( fifo_full = '0' ) then
                state       <= set_fpga_id2;
                fifo_wdata  <= "0000" & "0001" & wren_mask_wr(31 downto 0);
                fifo_we     <= '1';
            end if;
        when set_fpga_id2 =>
            o_state         <= x"0000005";
            mem_addr        <= x"0001";
            if ( fifo_full = '0' ) then
                state       <= emit_header;
                fifo_wdata  <= "0000" & "0010" & wren_mask_wr(63 downto 32);
                fifo_we     <= '1';
            end if;
        when emit_header =>
            o_state         <= x"0000006";
            mem_addr        <= x"0001";
            if ( fifo_full = '0' ) then
                state       <= latch_word;
                fifo_wdata  <= "0001" & "0000" & header_word;
                fifo_we     <= '1';
            end if;
        when request_word =>
            o_state         <= x"0000007";
            state           <= latch_word;
        when latch_word =>
            o_state         <= x"0000008";
            body_word       <= i_mem_data;
            if (tx_word_idx = length + 1) then
                body_last   <= '1';
                mem_addr    <= (others => '0');
            else
                body_last   <= '0';
                mem_addr    <= tx_word_idx + 1;
            end if;
            state           <= emit_word;
        when emit_word =>
            o_state         <= x"0000009";
            if ( fifo_full = '0' ) then
                fifo_we     <= '1';
                if ( body_last = '1' ) then
                    fifo_wdata  <= "0001" & "0000" & body_word;
                    mem_addr    <= (others => '0');
                    state       <= idle;
                    wren_mask_wr <= (others => '0');
                else
                    fifo_wdata  <= "0000" & "0000" & body_word;
                    tx_word_idx <= tx_word_idx + 1;
                    state       <= request_word;
                end if;
            end if;
        when others =>
            mem_addr        <= (others => '0');
            state           <= idle;
        end case;

    end if;
    end process;

    -- the process above can write into this FIFO at the Full 250 Mhz.
    -- Therefore the firmware can report "ready" to the software faster compared to writing to one of the 36 output links at 156.25 Mhz
    -- (placing one FIFO of this size at every link is a waste of memory so we have just 1 here)
    -- I was wondering if we could just ignore the "ready" signal in the software
    -- and hope that the firmware is done in time but this here is the safe way to do it, copy into a fifo at full speed, report ready
    -- backpressure to the ready signal in case the software shows up early with the next packet in the pcie mem
    ip_scfifo_v2_inst: entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH    => 11,
        g_DATA_WIDTH    => 40
    )
    port map (
        i_we           => fifo_we,
        i_wdata        => fifo_wdata,
        o_almost_full  => fifo_full,
        i_rack         => fifo_rack,
        o_rdata        => fifo_rdata,
        o_rempty       => fifo_empty,
        i_reset_n      => i_reset_n,
        i_clk          => i_clk
    );

    fifo_read_process: process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        fifo_rack <= '0';
        clkdiv    <= '0';
        wren_mask <= (others => '0');
    elsif rising_edge(i_clk) then
        clkdiv      <= not clkdiv;
        fifo_rack   <= '0';
        mem_data    <= (others => work.mu3e.LINK32_IDLE);
        o_mem_data  <= mem_data;
        o_injection <= (others => work.mu3e.LINK32_IDLE);

        if(fifo_empty = '0' and clkdiv = '0') then
            fifo_rack <= '1';
            if(fifo_rdata(35 downto 32) = "0000") then
                for I in 0 to NLINKS-1 loop
                    if ( wren_mask(I) = '1' ) then
                        mem_data(I)     <= work.mu3e.to_link(fifo_rdata(31 downto 0), fifo_rdata(39 downto 36));
                    end if;
                end loop;
                for I in 0 to 3 loop
                    if(wren_mask(48+I)='1') then
                        o_injection(I)   <= work.mu3e.to_link(fifo_rdata(31 downto 0), fifo_rdata(39 downto 36));
                    end if;
                end loop;
            end if;
            if(fifo_rdata(35 downto 32) = "0001") then
                wren_mask(31 downto 0) <= fifo_rdata(31 downto 0);
            end if;
            if(fifo_rdata(35 downto 32) = "0010") then
                wren_mask(63 downto 32) <= fifo_rdata(31 downto 0);
            end if;
        end if;
    end if;
    end process;

end architecture;

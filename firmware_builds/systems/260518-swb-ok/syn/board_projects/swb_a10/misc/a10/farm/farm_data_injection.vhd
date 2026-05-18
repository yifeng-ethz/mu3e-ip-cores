-------------------------------------------------------
--! @farm_data_injection.vhd
--! @brief the farm_data_injection can be used
--! to injection simulation data into the farm firmware
--! Author: mkoeppel@uni-mainz.de
-------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

use work.a10_pcie_registers.all;

entity farm_data_injection is
port (
    --! injection data from SC main
    i_injection         : in  work.mu3e.link32_array_t(3 downto 0);

    --! PCIe registers / memory
    i_writeregs         : in  slv32_array_t(63 downto 0);

    --! injection output
    o_injection         : out work.mu3e.link32_array_t(3 downto 0);

    --! 250 MHz clock pice / reset_n
    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

architecture arch of farm_data_injection is

    -- buffer / fifo input signals
    signal waiting : std_logic;
    signal wait_counter : std_logic_vector(31 downto 0);
    signal add_a, add_b, event_wrusedw, buffer_wrusedw : slv12_array_t(3 downto 0);
    signal data_a, q_b : slv32_array_t(3 downto 0);
    signal event_wen, buffer_wen, wen_reg, wen_a, buffer_written, write_buffer, write_next_buffer, event_almost_full, buffer_almost_full, merged_rempty, merged_ren : std_logic_vector(3 downto 0);
    signal injection_reg, event_injection, buffer_injection, merged_injection, injection : work.mu3e.link32_array_t(3 downto 0);

    -- fifo output / stream data
    signal rdata, stream_rdata : work.mu3e.link32_array_t(7 downto 0);
    signal ren, rempty, stream_rempty, stream_ren : std_logic_vector(7 downto 0);

    -- state machines
    type state_type is (idle, addr, length, dataStart, data, skip);
    type state_type_array_t is array ( natural range <> ) of state_type;
    type state_type_readout is (idle, waiting1, waiting2, data, lastword);
    type state_type_readout_array_t is array ( natural range <> ) of state_type_readout;
    signal state, state_event : state_type_array_t(3 downto 0);
    signal state_buffer : state_type_readout_array_t(3 downto 0);

begin

    --! slow down buffer readout
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        waiting <= '0';
        wait_counter <= (others => '0');
    elsif rising_edge(i_clk) then
        if ( wait_counter >= i_writeregs(INJECTION_WAIT_W) ) then
            wait_counter <= (others => '0');
            waiting <= '0';
        else
            wait_counter <= wait_counter + '1';
            waiting <= '1';
        end if;
    end if;
    end process;

    --! Write data to buffer RAM for re-reading
    gen_injection_buffer : FOR i in 0 to 3 GENERATE
        process(i_clk, i_reset_n)
        begin
        if ( i_reset_n = '0' ) then
            add_a(i)               <= (others => '1');
            data_a(i)              <= (others => '0');
            wen_a(i)               <= '0';
            write_buffer(i)        <= '0';
            buffer_written(i)      <= '0';
            write_next_buffer(i)   <= '0';
            state(i)               <= idle;
            --
        elsif rising_edge(i_clk) then
            -- register the injection
            injection(i) <= i_injection(i);

            wen_a(i)           <= '0';
            data_a(i)          <= (others => '0');
            -- NOTE: in software we first have to toggle this bit and than send the data
            write_buffer(i)    <= i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_WRITE_BUFFER_INJECTION);
            if ( write_buffer(i) = '0' and i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_WRITE_BUFFER_INJECTION) = '1' ) then
                write_next_buffer(i) <= '1';
            end if;

            if ( injection(i).idle = '0' ) then
                case state(i) is
                when idle =>
                    -- write new buffer package - we skip the start of the package
                    if ( injection(i).sop = '1' and write_next_buffer(i) = '1' ) then
                        state(i)           <= addr;
                        buffer_written(i)  <= '0';
                    end if;
                    --
                when addr =>
                    state(i) <= length;
                    --
                when length =>
                    state(i) <= dataStart;
                    --
                when dataStart =>
                    state(i) <= data;
                    wen_a(i) <= '1';
                    add_a(i) <= (others => '0');
                    data_a(i)<= injection(i).data;
                    --
                when data =>
                    -- we dont write the end of the package
                    if ( injection(i).eop = '1' ) then
                        state(i)               <= idle;
                        buffer_written(i)      <= '1';
                        write_next_buffer(i)   <= '0';
                    else
                        wen_a(i)   <= '1';
                        add_a(i)   <= add_a(i) + '1';
                        data_a(i)  <= injection(i).data;
                    end if;
                    --
                when others =>
                    state(i) <= idle;
                    --
                end case;
            end if;
        end if;
        end process;

        --! buffer ram
        e_buffer_ram : entity work.ip_ram_2rw
        generic map (
            g_ADDR0_WIDTH => 12,
            g_ADDR1_WIDTH => 12,
            g_DATA0_WIDTH => 32,
            g_DATA1_WIDTH => 32--,
        )
        port map (
            i_addr0     => add_a(i),
            i_addr1     => add_b(i),
            i_clk0      => i_clk,
            i_clk1      => i_clk,
            i_wdata0    => data_a(i),
            i_wdata1    => (others => '0'),
            i_we0       => wen_a(i),
            i_we1       => '0',
            o_rdata0    => open,
            o_rdata1    => q_b(i)--,
        );

        --! readout buffer ram
        process(i_clk, i_reset_n)
        begin
        if ( i_reset_n = '0' ) then
            add_b(i)               <= (others => '1');
            buffer_injection(i)    <= work.mu3e.LINK32_ZERO;
            buffer_wen(i)          <= '0';
            state_buffer(i)        <= idle;
        elsif rising_edge(i_clk) then
            buffer_injection(i).sop    <= '0';
            buffer_injection(i).eop    <= '0';
            buffer_wen(i)              <= '0';
            -- setting unused bits in buffer_injection to '0' to avoid inferred latches:
            buffer_injection(i).datak <= (others => '0');
            buffer_injection(i).idle <= '0';
            buffer_injection(i).dthdr <= '0';
            buffer_injection(i).sbhdr <= '0';
            buffer_injection(i).err <= '0';
            buffer_injection(i).t0 <= '0';
            buffer_injection(i).t1 <= '0';
            buffer_injection(i).d0 <= '0';
            buffer_injection(i).d1 <= '0';

            case state_buffer(i) is

            when idle =>
                -- NOTE: if we want to change the event in the buffer we first have to disable the readout in software
                if ( i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_INJECTION) = '1' and buffer_written(i) = '1' ) then
                    -- we than wait always a bit and check if the buffer hase space
                    if ( waiting = '0' and buffer_almost_full(i) = '0' ) then
                        add_b(i)           <= add_b(i) + '1';
                        state_buffer(i)    <= waiting1;
                    end if;
                end if;
                --
            when waiting1 =>
                add_b(i)                   <= add_b(i) + '1';
                state_buffer(i)            <= waiting2;
                --
            when waiting2 =>
                add_b(i)                   <= add_b(i) + '1';
                buffer_injection(i).sop    <= '1';
                buffer_injection(i).data   <= q_b(i);
                buffer_wen(i)              <= '1';
                state_buffer(i)            <= data;
                --
            when data =>
                if(add_b(i) = add_a(i)) then
                    add_b(i)                   <= (others => '1');
                    state_buffer(i)            <= lastword;
                else
                    add_b(i) <= add_b(i) + '1';
                end if;
                buffer_injection(i).data   <= q_b(i);
                buffer_wen(i)              <= '1';
                --
            when lastword =>
                buffer_injection(i).eop    <= '1';
                buffer_wen(i)              <= '1';
                buffer_injection(i).data   <= q_b(i);
                state_buffer(i)            <= idle;
                --
            when others =>
                state_buffer(i) <= idle;

            end case;

        end if;
        end process;

        --! buffer fifo
        e_buffer_fifo : entity work.link32_scfifo
        generic map (
            g_ADDR_WIDTH => 12,
            g_WREG_N => 1,
            g_RREG_N => 1--,
        )
        port map (
            i_wdata     => buffer_injection(i),
            i_we        => buffer_wen(i),
            o_usedw     => buffer_wrusedw(i),

            o_rdata     => rdata(i),
            i_rack      => ren(i),
            o_rempty    => rempty(i),

            i_reset_n   => i_reset_n,
            i_clk       => i_clk--,
        );

        --! Write data to event FIFO
        process(i_clk, i_reset_n)
        begin
        if ( i_reset_n = '0' ) then
            event_wen(i)           <= '0';
            event_injection(i)     <= work.mu3e.LINK32_ZERO;
            state_event(i)         <= idle;
        elsif rising_edge(i_clk) then
            event_wen(i) <= '0';

            -- we only write the injection events when they are enabled
            if ( injection(i).idle = '0' and i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_INJECTION) = '1' ) then
                case state_event(i) is
                when idle =>
                    if ( event_almost_full(i) = '1' ) then
                        state_event(i)     <= skip;
                    elsif ( injection(i).sop = '1' ) then
                        state_event(i)     <= addr;
                    end if;
                    --
                when addr =>
                    state_event(i) <= length;
                    --
                when length =>
                    state_event(i) <= dataStart;
                    --
                when dataStart =>
                    state_event(i) <= data;
                    injection_reg(i) <= injection(i);
                    wen_reg(i) <= '1';
                    -- we dont read the SC package start but we set SOP
                    injection_reg(i).sop <= '1';
                    --
                when data =>
                    injection_reg(i) <= injection(i);
                    wen_reg(i) <= '1';
                    event_wen(i) <= wen_reg(i);
                    event_injection(i) <= injection_reg(i);
                    if ( injection(i).eop = '1' ) then
                        state_event(i) <= idle;
                        -- we dont read the SC package end but we set EOP
                        event_injection(i).eop <= '1';
                    end if;
                    --
                when skip =>
                    if ( injection(i).eop = '1' ) then
                        state_event(i)         <= idle;
                    end if;
                    --
                when others =>
                    state_event(i) <= idle;
                    --
                end case;
            end if;
        end if;
        end process;

        --! event fifo
        e_event_fifo : entity work.link32_scfifo
        generic map (
            g_ADDR_WIDTH=> 12,
            g_WREG_N    => 1,
            g_RREG_N    => 1--,
        )
        port map (
            i_wdata     => event_injection(i),
            i_we        => event_wen(i),
            o_usedw     => event_wrusedw(i),

            o_rdata     => rdata(i+4),
            i_rack      => ren(i+4),
            o_rempty    => rempty(i+4),

            i_reset_n   => i_reset_n,
            i_clk       => i_clk--,
        );

        --! get almost full flag
        process(i_clk, i_reset_n)
        begin
        if ( i_reset_n = '0' ) then
            event_almost_full(i) <= '0';
            buffer_almost_full(i) <= '0';
        elsif rising_edge(i_clk) then
            if ( event_wrusedw(i)(11) = '1' ) then
                event_almost_full(i) <= '1';
            else
                event_almost_full(i) <= '0';
            end if;
            if ( buffer_wrusedw(i)(11) = '1' ) then
                buffer_almost_full(i) <= '1';
            else
                buffer_almost_full(i) <= '0';
            end if;
        end if;
        end process;

        --! assigne stream data
        stream_rdata(i*2) <= rdata(i);
        stream_rdata(i*2+1) <= rdata(i+4);
        stream_rempty(i*2) <= rempty(i);
        stream_rempty(i*2+1) <= rempty(i+4);
        ren(i) <= stream_ren(i*2);
        ren(i+4) <= stream_ren(i*2+1);

        --! merge data streams
        e_stream : entity work.swb_stream_merger32
        generic map (
            g_ADDR_WIDTH => 12,
            N => 2--,
        )
        port map (
            i_rdata     => stream_rdata((i+1)*2-1 downto i*2),
            i_rempty    => stream_rempty((i+1)*2-1 downto i*2),
            o_rack      => stream_ren((i+1)*2-1 downto i*2),

            -- merged data
            o_wdata     => open,--merged_injection(i),
            o_rempty    => merged_rempty(i),
            i_ren       => merged_ren(i),

            i_reset_n   => i_reset_n,
            i_clk       => i_clk--,
        );

        --! trigger readout of merged events
        merged_ren(i) <= not merged_rempty(i);
        o_injection(i) <= merged_injection(i) when merged_rempty(i) = '0' else work.mu3e.LINK32_IDLE;

    end generate;

end architecture;

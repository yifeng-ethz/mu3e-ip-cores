--
-- dual-clock fifo
--
-- author : Alexandr Kozlinskiy
-- date : 2021-06-09
--

library ieee;
use ieee.std_logic_1164.all;

--
-- Interface to FIFO Intel FPGA IP.
--
entity ip_dcfifo_v2 is
generic (
    g_ADDR_WIDTH : positive := 8;
    g_DATA_WIDTH : positive := 8;
    g_WADDR_WIDTH : natural := 0;
    g_WDATA_WIDTH : natural := 0;
    g_RADDR_WIDTH : natural := 0;
    g_RDATA_WIDTH : natural := 0;
    g_WREG_N : natural := 0;
    g_RREG_N : natural := 0;
    g_SHOWAHEAD : string := "ON";
    g_USE_EAB : string := "ON";
    g_RAM_OUTREG : string := "OFF";
    -- use "RAM_BLOCK_TYPE=MLAB" to implement FIFO with MLABs
    g_LPM_HINT : string := "UNUSED";
    g_DEVICE_FAMILY : string := "Arria 10"--;
);
port (
    i_we        : in    std_logic; -- write enable (request)
    i_wdata     : in    std_logic_vector(work.util.value_if(g_WDATA_WIDTH > 0, g_WDATA_WIDTH, g_DATA_WIDTH)-1 downto 0);
    o_wfull     : out   std_logic;
    o_wfull_n   : out   std_logic;
    o_wusedw    : out   std_logic_vector(work.util.value_if(g_WADDR_WIDTH > 0, g_WADDR_WIDTH, g_ADDR_WIDTH)-1 downto 0);
    i_wclk      : in    std_logic;

    i_rack      : in    std_logic; -- read enable (request, acknowledge)
    o_rdata     : out   std_logic_vector(work.util.value_if(g_RDATA_WIDTH > 0, g_RDATA_WIDTH, g_DATA_WIDTH)-1 downto 0);
    o_rempty    : out   std_logic;
    o_rempty_n  : out   std_logic;
    o_rusedw    : out   std_logic_vector(work.util.value_if(g_RADDR_WIDTH > 0, g_RADDR_WIDTH, g_ADDR_WIDTH)-1 downto 0);
    i_rclk      : in    std_logic;

    -- async clear
    i_reset_n   : in    std_logic--;
);
end entity;

library altera_mf;
use altera_mf.altera_mf_components.all;

architecture arch of ip_dcfifo_v2 is

    constant WADDR_WIDTH : positive := work.util.value_if(g_WADDR_WIDTH > 0, g_WADDR_WIDTH, g_ADDR_WIDTH);
    constant RADDR_WIDTH : positive := work.util.value_if(g_RADDR_WIDTH > 0, g_RADDR_WIDTH, g_ADDR_WIDTH);

    type rdata_t is array (natural range <>) of std_logic_vector(o_rdata'range);
    signal fifo_rdata : rdata_t(g_RREG_N downto 0);
    signal fifo_rack, fifo_rempty : std_logic_vector(g_RREG_N downto 0);
    signal rreset_n : std_logic;

    type wdata_t is array (natural range <>) of std_logic_vector(i_wdata'range);
    signal fifo_wdata : wdata_t(g_WREG_N downto 0);
    signal fifo_we, fifo_wfull : std_logic_vector(g_WREG_N downto 0);
    signal wreset_n : std_logic;

begin

    assert ( true
        and WADDR_WIDTH >= 2 and RADDR_WIDTH >= 2
        and 2**WADDR_WIDTH * i_wdata'length = 2**RADDR_WIDTH * o_rdata'length
        and ( g_SHOWAHEAD = "ON" or g_SHOWAHEAD = "OFF" )
        and not ( g_SHOWAHEAD = "OFF" and g_RREG_N > 0 )
    ) report "ip_dcfifo_v2"
        & ", WADDR_WIDTH = " & integer'image(WADDR_WIDTH)
        & ", WDATA_WIDTH = " & integer'image(i_wdata'length)
        & ", RADDR_WIDTH = " & integer'image(RADDR_WIDTH)
        & ", RDATA_WIDTH = " & integer'image(o_rdata'length)
        & ", g_WREG_N = " & integer'image(g_WREG_N)
        & ", g_RREG_N = " & integer'image(g_RREG_N)
        & ", g_SHOWAHEAD = " & g_SHOWAHEAD
    severity failure;

    fifo_we(0) <= i_we;
    fifo_wdata(0) <= i_wdata;
    o_wfull <= fifo_wfull(0);
    o_wfull_n <= not fifo_wfull(0);
    fifo_rack(0) <= i_rack;
    o_rdata <= fifo_rdata(0);
    o_rempty <= fifo_rempty(0);
    o_rempty_n <= not fifo_rempty(0);

    generate_dcfifo : if ( o_rdata'length = i_wdata'length ) generate
        -- <ug_fifo.pdf>
        dcfifo_component : dcfifo
        generic map (
            -- Identifies the library of parameterized modules (LPM) entity name.
            lpm_type => "dcfifo",
            -- Specifies if the FIFO should be implemented in MLABs or Memory blocks
            lpm_hint => g_LPM_HINT,
            -- Specifies ... the width of the rdusedw and wrusedw ports for the DCFIFO function.
            lpm_widthu => WADDR_WIDTH,
            -- Specifies the depths of the FIFO you require. The value must be at least 4.
            -- The value assigned must comply to the following equation: 2^LPM_WIDTHU.
            lpm_numwords => 2**WADDR_WIDTH,
            -- Specifies the width of the data and q ports for the SCFIFO function and DCFIFO function.
            lpm_width => i_wdata'length,
            -- Specifies whether the FIFO is in normal mode (OFF) or show-ahead mode (ON).
            lpm_showahead => g_SHOWAHEAD,
            -- Specifies whether to register the q output.
--            add_ram_output_register => "OFF",
            -- Specifies whether or not the FIFO Intel FPGA IP core
            -- is constructed using the RAM Embedded Array Blocks.
            use_eab => g_USE_EAB,
            -- Specifies whether or not to enable the protection circuitry
            -- for overflow/underflow checking that disables the wrreq/rdreq port
            -- when the FIFO Intel FPGA IP core is full
            overflow_checking => "ON",
            underflow_checking => "ON",
            -- Specifies whether or not to add a circuit that causes
            -- the aclr port to be internally synchronized by the wrclk/rdclk clocks.
            write_aclr_synch => "ON",
            read_aclr_synch => "ON",
            -- Specify the number of synchronization stages in the cross clock domain.
            -- The values of these parameters are internally reduced by two.
            wrsync_delaypipe => 4,
            rdsync_delaypipe => 4,
            add_ram_output_register => g_RAM_OUTREG,
            -- Specifies the intended device that matches the device set in your Intel Quartus Prime project.
            -- Use only this parameter for functional simulation.
            intended_device_family => g_DEVICE_FAMILY--,
        )
        port map (
            wrreq => fifo_we(g_WREG_N),
            data => fifo_wdata(g_WREG_N),
            wrfull => fifo_wfull(g_WREG_N),
            wrusedw => o_wusedw,
            wrclk => i_wclk,

            rdreq => fifo_rack(g_RREG_N),
            q => fifo_rdata(g_RREG_N),
            rdempty => fifo_rempty(g_RREG_N),
            rdusedw => o_rusedw,
            rdclk => i_rclk,

            -- Assert this signal to clear all the output status ports.
            -- There are no minimum number of clock cycles for aclr signals that must remain active.
            aclr => not i_reset_n--,
        );
    end generate;

    generate_dcfifo_mixed_widths : if ( o_rdata'length /= i_wdata'length ) generate
        dcfifo_component : dcfifo_mixed_widths
        generic map (
            lpm_type => "dcfifo_mixed_widths",
            lpm_hint => g_LPM_HINT,
            lpm_widthu => WADDR_WIDTH,
            lpm_numwords => 2**WADDR_WIDTH,
            lpm_widthu_r => RADDR_WIDTH,
            lpm_width => i_wdata'length,
            lpm_width_r => o_rdata'length,
            lpm_showahead => g_SHOWAHEAD,
            use_eab => g_USE_EAB,
            overflow_checking => "ON",
            underflow_checking => "ON",
            write_aclr_synch => "ON",
            read_aclr_synch => "ON",
            wrsync_delaypipe => 4,
            rdsync_delaypipe => 4,
            intended_device_family => g_DEVICE_FAMILY--,
        )
        port map (
            wrreq => fifo_we(g_WREG_N),
            data => fifo_wdata(g_WREG_N),
            wrfull => fifo_wfull(g_WREG_N),
            wrusedw => o_wusedw,
            wrclk => i_wclk,

            rdreq => fifo_rack(g_RREG_N),
            q => fifo_rdata(g_RREG_N),
            rdempty => fifo_rempty(g_RREG_N),
            rdusedw => o_rusedw,
            rdclk => i_rclk,

            aclr => not i_reset_n--,
        );
    end generate;

    generate_wreg : if ( g_WREG_N > 0 ) generate
        -- sync write clock reset
        e_wreset_n : entity work.reset_sync
        port map ( i_areset_n => i_reset_n, o_reset_n => wreset_n, i_clk => i_wclk );

        -- write through reg fifos
        generate_fifo_wreg : for i in g_WREG_N-1 downto 0 generate
            e_fifo_wreg : entity work.fifo_reg
            generic map (
                g_DATA_WIDTH => i_wdata'length--,
            )
            port map (
                i_we => fifo_we(i),
                i_wdata => fifo_wdata(i),
                o_wfull => fifo_wfull(i),

                i_rack => not fifo_wfull(i+1),
                o_rdata => fifo_wdata(i+1),
                o_rempty_n => fifo_we(i+1),

                i_reset_n => wreset_n,
                i_clk => i_wclk--,
            );
        end generate;
    end generate;

    generate_rreg : if ( g_RREG_N > 0 ) generate
        -- sync read clock reset
        e_rreset_n : entity work.reset_sync
        port map ( i_areset_n => i_reset_n, o_reset_n => rreset_n, i_clk => i_rclk );

        -- read through reg fifos
        generate_fifo_rreg : for i in g_RREG_N-1 downto 0 generate
            e_fifo_rreg : entity work.fifo_reg
            generic map (
                g_DATA_WIDTH => o_rdata'length--,
            )
            port map (
                i_we => not fifo_rempty(i+1),
                i_wdata => fifo_rdata(i+1),
                o_wfull_n => fifo_rack(i+1),

                i_rack => fifo_rack(i),
                o_rdata => fifo_rdata(i),
                o_rempty => fifo_rempty(i),

                i_reset_n => rreset_n,
                i_clk => i_rclk--,
            );
        end generate;
    end generate;

end architecture;

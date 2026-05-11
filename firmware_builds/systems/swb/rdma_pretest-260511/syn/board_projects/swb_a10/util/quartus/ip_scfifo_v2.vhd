--

library ieee;
use ieee.std_logic_1164.all;

entity ip_scfifo_v2 is
generic (
    g_ADDR_WIDTH : positive := 8;
    g_DATA_WIDTH : positive := 8;
    g_WREG_N : natural := 0;
    g_RREG_N : natural := 0;
    g_SHOWAHEAD : string := "ON";
    g_RAM_OUTREG : string := "OFF";
    g_DEVICE_FAMILY : string := "Arria 10";
    -- use "RAM_BLOCK_TYPE=MLAB" to implement FIFO with MLABs
    g_LPM_HINT : string := "UNUSED"--;
);
port (
    i_we            : in    std_logic; -- write enable (request)
    i_wdata         : in    std_logic_vector(g_DATA_WIDTH-1 downto 0);
    o_wfull         : out   std_logic;
    o_wfull_n       : out   std_logic;
    o_almost_full   : out   std_logic;

    i_rack          : in    std_logic; -- read enable (request, acknowledge)
    o_rdata         : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);
    o_rempty        : out   std_logic;
    o_rempty_n      : out   std_logic;
    o_almost_empty  : out   std_logic;

    o_usedw         : out   std_logic_vector(g_ADDR_WIDTH-1 downto 0);

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

library altera_mf;
use altera_mf.altera_mf_components.all;

architecture arch of ip_scfifo_v2 is

    type rdata_t is array (natural range <>) of std_logic_vector(o_rdata'range);
    signal fifo_rdata : rdata_t(g_RREG_N downto 0);
    signal fifo_rack, fifo_rempty : std_logic_vector(g_RREG_N downto 0);

    type wdata_t is array (natural range <>) of std_logic_vector(i_wdata'range);
    signal fifo_wdata : wdata_t(g_WREG_N downto 0);
    signal fifo_we, fifo_wfull : std_logic_vector(g_WREG_N downto 0);

begin

    assert ( true
        -- check that g_SHOWAHEAD is "ON" or "OFF"
        and ( g_SHOWAHEAD = "ON" or g_SHOWAHEAD = "OFF" )
        -- g_RREG_N > 0 only when g_SHOWAHEAD is ON
        and not ( g_SHOWAHEAD = "OFF" and g_RREG_N > 0 )
    ) report "ip_dcfifo_v2"
        & ", ADDR_WIDTH = " & integer'image(g_ADDR_WIDTH)
        & ", DATA_WIDTH = " & integer'image(o_rdata'length)
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

    scfifo_component : scfifo
    GENERIC MAP (
        lpm_type => "scfifo",
        lpm_widthu => g_ADDR_WIDTH,
        lpm_hint => g_LPM_HINT,
        lpm_numwords => 2**g_ADDR_WIDTH,
        almost_empty_value => 2**(g_ADDR_WIDTH/2),
        almost_full_value => 2**g_ADDR_WIDTH - 2**(g_ADDR_WIDTH/2),
        lpm_width => g_DATA_WIDTH,
        lpm_showahead => g_SHOWAHEAD,
        add_ram_output_register => g_RAM_OUTREG,
        use_eab => "ON",
        overflow_checking => "ON",
        underflow_checking => "ON",
        intended_device_family => g_DEVICE_FAMILY--,
    )
    PORT MAP (
        wrreq => fifo_we(g_WREG_N),
        data => fifo_wdata(g_WREG_N),
        full => fifo_wfull(g_WREG_N),
        almost_full => o_almost_full,

        rdreq => fifo_rack(g_RREG_N),
        q => fifo_rdata(g_RREG_N),
        empty => fifo_rempty(g_RREG_N),
        almost_empty => o_almost_empty,

        usedw => o_usedw,

        sclr => not i_reset_n,
        clock => i_clk--,
    );

    generate_wreg : if ( g_WREG_N > 0 ) generate
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

                i_reset_n => i_reset_n,
                i_clk => i_clk--,
            );
        end generate;
    end generate;

    generate_rreg : if ( g_RREG_N > 0 ) generate
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

                i_reset_n => i_reset_n,
                i_clk => i_clk--,
            );
        end generate;
    end generate;

end architecture;

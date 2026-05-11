--

library ieee;
use ieee.std_logic_1164.all;

entity ip_ram_2rw is
generic (
    g_ADDR0_WIDTH : positive := 8;
    g_DATA0_WIDTH : positive := 8;
    g_ADDR1_WIDTH : positive := 8;
    g_DATA1_WIDTH : positive := 8;
    g_RDATA0_REG : integer := 0;
    g_RDATA1_REG : integer := 0;
    g_INIT_FILE : string := "UNUSED";
    g_DEVICE_FAMILY : string := "Arria 10"--;
);
port (
    i_addr0     : in    std_logic_vector(g_ADDR0_WIDTH-1 downto 0);
    i_we0       : in    std_logic := '0';
    i_wdata0    : in    std_logic_vector(g_DATA0_WIDTH-1 downto 0) := (others => '0');
    i_re0       : in    std_logic := '1';
    o_rvalid0   : out   std_logic;
    o_rdata0    : out   std_logic_vector(g_DATA0_WIDTH-1 downto 0);
    i_clk0      : in    std_logic;

    i_addr1     : in    std_logic_vector(g_ADDR1_WIDTH-1 downto 0);
    i_we1       : in    std_logic := '0';
    i_wdata1    : in    std_logic_vector(g_DATA1_WIDTH-1 downto 0) := (others => '0');
    i_re1       : in    std_logic := '1';
    o_rvalid1   : out   std_logic;
    o_rdata1    : out   std_logic_vector(g_DATA1_WIDTH-1 downto 0);
    i_clk1      : in    std_logic--;
);
end entity;

library altera_mf;
use altera_mf.altera_mf_components.all;

architecture arch of ip_ram_2rw is

    signal rvalid0 : std_logic_vector(g_RDATA0_REG+1 downto 0) := (others => '0');
    signal rvalid1 : std_logic_vector(g_RDATA1_REG+1 downto 0) := (others => '0');

begin

    assert ( true
        and 2**i_addr0'length * i_wdata0'length = 2**i_addr1'length * i_wdata1'length
        and ( g_RDATA0_REG = 0 or g_RDATA0_REG = 1 )
        and ( g_RDATA1_REG = 0 or g_RDATA1_REG = 1 )
    ) report "ip_dcfifo_v2"
        & ", g_ADDR0_WIDTH = " & integer'image(i_addr0'length)
        & ", g_DATA0_WIDTH = " & integer'image(i_wdata0'length)
        & ", g_ADDR1_WIDTH = " & integer'image(i_addr1'length)
        & ", g_DATA1_WIDTH = " & integer'image(i_wdata1'length)
    severity failure;

    -- <https://www.intel.co.jp/content/dam/altera-www/global/ja_JP/pdfs/literature/ug/ug_ram_rom.pdf>
    -- <https://www.intel.com/content/www/us/en/programmable/quartushelp/17.0/hdl/mega/mega_file_altsynch_ram.htm>
    altsyncram_component : altsyncram
    generic map (
        lpm_type => "altsyncram",
        operation_mode => "BIDIR_DUAL_PORT",

        numwords_a => 2**i_addr0'length,
        widthad_a => i_addr0'length,
        width_a => i_wdata0'length,
        -- Optional parameters to specify the clock used for the output ports.
        -- The values are CLOCK0, CLOCK1 and UNREGISTERED.
        outdata_reg_a => work.util.value_if(g_RDATA0_REG = 0, "UNREGISTERED", "CLOCK0"),
        read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
        clock_enable_input_a => "BYPASS",
        clock_enable_output_a => "BYPASS",
        -- Default value of 1 is only allowed when byte-enable is not used.
        width_byteena_a => 1,

        numwords_b => 2**i_addr1'length,
        widthad_b => i_addr1'length,
        width_b => i_wdata1'length,
        outdata_reg_b => work.util.value_if(g_RDATA1_REG = 0, "UNREGISTERED", "CLOCK1"),
        read_during_write_mode_port_b => "NEW_DATA_NO_NBE_READ",
        clock_enable_input_b => "BYPASS",
        clock_enable_output_b => "BYPASS",
        width_byteena_b => 1,

        -- Optional parameter to specify whether to initialize memory content data to X on power-up simulation.
        power_up_uninitialized => "FALSE",
        -- Name of the .mif or .hexout file containing RAM initialization data or "UNUSED".
        -- In DUAL_PORT mode the compiler uses the WIDTH_B parameters to read the init_file.
        -- (Quartus searches for the init_file in the project directory,
        -- the project db directory, user libraries, and the current source file location)
        init_file => g_INIT_FILE,
        -- Optional parameter to specify the target device family.
        -- This parameter is used for modeling and behavioral simulation purposes.
        intended_device_family => g_DEVICE_FAMILY--,
    )
    port map (
        address_a => i_addr0,
        wren_a => i_we0,
        data_a => i_wdata0,
        rden_a => i_re0,
        q_a => o_rdata0,
        clock0 => i_clk0,

        address_b => i_addr1,
        wren_b => i_we1,
        data_b => i_wdata1,
        rden_b => i_re1,
        q_b => o_rdata1,
        clock1 => i_clk1--,
    );

    -- generate rvalid0
    o_rvalid0 <= rvalid0(0);
    rvalid0(g_RDATA0_REG+1) <= '1' when ( i_re0 = '1' ) else '0';
    process(i_clk0)
    begin
    if rising_edge(i_clk0) then
        rvalid0(g_RDATA0_REG downto 0) <= rvalid0(g_RDATA0_REG+1 downto 1);
    end if;
    end process;

    -- generate rvalid1
    o_rvalid1 <= rvalid1(0);
    rvalid1(g_RDATA1_REG+1) <= '1' when ( i_re1 = '1' ) else '0';
    process(i_clk1)
    begin
    if rising_edge(i_clk1) then
        rvalid1(g_RDATA1_REG downto 0) <= rvalid1(g_RDATA1_REG+1 downto 1);
    end if;
    end process;

end architecture;

--

library ieee;
use ieee.std_logic_1164.all;

entity ip_ram_1rw is
generic (
    g_ADDR_WIDTH : positive := 8;
    g_DATA_WIDTH : positive := 8;
    g_RDATA_REG : integer := 0;
    g_DEVICE_FAMILY : string := "Arria 10"--;
);
port (
    i_addr      : in    std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    i_we        : in    std_logic := '0';
    i_wdata     : in    std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others => '0');
    i_re        : in    std_logic := '1';
    o_rvalid    : out   std_logic;
    o_rdata     : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);
    i_clk       : in    std_logic--;
);
end entity;

library altera_mf;
use altera_mf.altera_mf_components.all;

architecture arch of ip_ram_1rw is

    signal rvalid : std_logic_vector(g_RDATA_REG+1 downto 0) := (others => '0');

begin

    altsyncram_component : altsyncram
    generic map (
        lpm_type => "altsyncram",
        operation_mode => "SINGLE_PORT",

        numwords_a => 2**i_addr'length,
        widthad_a => i_addr'length,
        width_a => i_wdata'length,
        -- Optional parameters to specify the clock used for the output ports.
        -- The values are CLOCK0, CLOCK1 and UNREGISTERED.
        outdata_reg_a => work.util.value_if(g_RDATA_REG = 0, "UNREGISTERED", "CLOCK0"),
        read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
        clock_enable_input_a => "BYPASS",
        clock_enable_output_a => "BYPASS",
        -- Default value of 1 is only allowed when byte-enable is not used.
        width_byteena_a => 1,

        -- Optional parameter to specify whether to initialize memory content data to X on power-up simulation.
        power_up_uninitialized => "FALSE",
        -- Optional parameter to specify the target device family.
        -- This parameter is used for modeling and behavioral simulation purposes.
        intended_device_family => g_DEVICE_FAMILY--,
    )
    port map (
        address_a => i_addr,
        wren_a => i_we,
        data_a => i_wdata,
        rden_a => i_re,
        q_a => o_rdata,
        clock0 => i_clk--,
    );

    -- generate rvalid
    o_rvalid <= rvalid(0);
    rvalid(g_RDATA_REG+1) <= i_re;
    process(i_clk)
    begin
    if rising_edge(i_clk) then
        rvalid(g_RDATA_REG downto 0) <= rvalid(g_RDATA_REG+1 downto 1);
    end if;
    end process;

end architecture;

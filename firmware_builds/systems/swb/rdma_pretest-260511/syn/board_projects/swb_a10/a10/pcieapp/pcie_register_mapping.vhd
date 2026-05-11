library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

use work.mudaq.all;
use work.a10_pcie_registers.all;

entity pcie_register_mapping is
generic (
    g_FARM : integer := 0--;
);
port (
    --! register inputs for pcie0
    i_pcie0_rregs_A         : in    slv32_array_t(63 downto 0) := (others => (others => '0'));

    --! register inputs for pcie0 from a10_block
    i_local_pcie0_rregs_A   : in    slv32_array_t(63 downto 0) := (others => (others => '0'));
    i_local_pcie0_rregs_B   : in    slv32_array_t(63 downto 0) := (others => (others => '0')); -- for 125 MHz for reset link

    --! register outputs for pcie0
    o_pcie0_rregs           : out   reg32array_pcie;

    -- reset_n
    i_reset_n               : in    std_logic;

    -- clk
    i_clk_A                 : in    std_logic;
    i_clk_B                 : in    std_logic--;

);
end entity;

--! sync 2 clock domains used in the A10 board
--! and output one set of registers which are used for the PCIe block
architecture arch of pcie_register_mapping is

    signal data_rregs_A, data_rregs_B, data_rregs_A_q : std_logic_vector(64*32-1 downto 0);
    signal rempty_A, wrfull_B : std_logic;

begin

    gen_sync : FOR i in 0 to 63 GENERATE
        generate_swb : if ( g_FARM = 0 ) generate
            data_rregs_B(i * 32 + 31 downto i * 32) <= i_local_pcie0_rregs_B(i);
        end generate;
    END GENERATE;

    --! sync FIFOs
    e_sync_fifo_B : entity work.ip_dcfifo_v2
    generic map (
        g_ADDR_WIDTH => 4,
        g_DATA_WIDTH => data_rregs_B'length--,
    )
    port map (
        i_we => not wrfull_B,
        i_wdata => data_rregs_B,
        o_wfull => wrfull_B,
        i_wclk => i_clk_B,

        i_rack => not rempty_A,
        o_rdata => data_rregs_A,
        o_rempty => rempty_A,
        i_rclk => i_clk_A,

        i_reset_n => i_reset_n--,
    );

    -- reg sync B
    process(i_clk_A, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        data_rregs_A_q <= (others => '0');
    elsif rising_edge(i_clk_A) then
        if ( rempty_A = '0' ) then
            data_rregs_A_q <= data_rregs_A;
        end if;
    end if;
    end process;

    --! map regs
    gen_map : FOR i in 0 to 63 GENERATE
        o_pcie0_rregs(i) <=
            i_local_pcie0_rregs_A(VERSION_REGISTER_R)           when i = VERSION_REGISTER_R else
            i_local_pcie0_rregs_A(DMA_STATUS_R)                 when i = DMA_STATUS_R else
            i_local_pcie0_rregs_A(DMA_HALFFUL_REGISTER_R)       when i = DMA_HALFFUL_REGISTER_R else
            i_local_pcie0_rregs_A(DMA_NOTHALFFUL_REGISTER_R)    when i = DMA_NOTHALFFUL_REGISTER_R else
            i_local_pcie0_rregs_A(DMA_ENDEVENT_REGISTER_R)      when i = DMA_ENDEVENT_REGISTER_R else
            i_local_pcie0_rregs_A(DMA_NOTENDEVENT_REGISTER_R)   when i = DMA_NOTENDEVENT_REGISTER_R else
            i_local_pcie0_rregs_A(CNT_PLL_156_REGISTER_R)       when i = CNT_PLL_156_REGISTER_R else
            i_local_pcie0_rregs_A(CNT_PLL_250_REGISTER_R)       when i = CNT_PLL_250_REGISTER_R else
            i_local_pcie0_rregs_A(LINK_LOCKED_LOW_REGISTER_R)   when i = LINK_LOCKED_LOW_REGISTER_R else
            i_local_pcie0_rregs_A(LINK_LOCKED_HIGH_REGISTER_R)  when i = LINK_LOCKED_HIGH_REGISTER_R else
            data_rregs_A_q((i+1)*32-1 downto i*32)              when i = RESET_LINK_STATUS_REGISTER_R else -- for SWB reset link, does not work for the farm
            i_pcie0_rregs_A(i);
    END GENERATE;

end architecture;

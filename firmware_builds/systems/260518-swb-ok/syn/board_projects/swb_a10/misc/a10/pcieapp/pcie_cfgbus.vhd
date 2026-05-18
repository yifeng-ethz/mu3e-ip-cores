-- Configuration bus decoder for PCIe IF

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcie_cfgbus is
port (
    tl_cfg_add      : in    std_logic_vector(3 downto 0);
    tl_cfg_ctl      : in    std_logic_vector(31 downto 0);

    cfg_busdev      : out   std_logic_vector(12 downto 0);
    cfg_dev_ctrl    : out   std_logic_vector(31 downto 0);
    cfg_slot_ctrl   : out   std_logic_vector(15 downto 0);
    cfg_link_ctrl   : out   std_logic_vector(31 downto 0);
    cfg_prm_cmd     : out   std_logic_vector(15 downto 0);
    cfg_msi_addr    : out   std_logic_vector(63 downto 0);
    cfg_pmcsr       : out   std_logic_vector(31 downto 0);
    cfg_msixcsr     : out   std_logic_vector(15 downto 0);
    cfg_msicsr      : out   std_logic_vector(15 downto 0);
    tx_ercgen       : out   std_logic;
    rx_errcheck     : out   std_logic;
    cfg_tcvcmap     : out   std_logic_vector(23 downto 0);
    cfg_msi_data    : out   std_logic_vector(15 downto 0);

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture RTL of pcie_cfgbus is

begin

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        cfg_busdev      <= (others => '0');
        cfg_dev_ctrl    <= (others => '0');
        cfg_slot_ctrl   <= (others => '0');
        cfg_link_ctrl   <= (others => '0');
        cfg_prm_cmd     <= (others => '0');
        cfg_msi_addr    <= (others => '0');
        cfg_pmcsr       <= (others => '0');
        cfg_msixcsr     <= (others => '0');
        cfg_msicsr      <= (others => '0');
        tx_ercgen       <= '0';
        rx_errcheck     <= '0';
        cfg_tcvcmap     <= (others => '0');
        cfg_msi_data    <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        case tl_cfg_add is
        when "0000" =>
            cfg_dev_ctrl <= tl_cfg_ctl;
        when "0001" =>
            cfg_slot_ctrl <= tl_cfg_ctl(15 downto 0);
        when "0010" =>
            cfg_link_ctrl <= tl_cfg_ctl;
        when "0011" =>
            cfg_prm_cmd <= tl_cfg_ctl(23 downto 8);
        when "0101" =>
            cfg_msi_addr(11 downto 0) <= tl_cfg_ctl(31 downto 20);
        when "0110" =>
            cfg_msi_addr(43 downto 32) <= tl_cfg_ctl(31 downto 20);
        when "1001" =>
            cfg_msi_addr(31 downto 12) <= tl_cfg_ctl(31 downto 12);
        when "1011" =>
            cfg_msi_addr(63 downto 44) <= tl_cfg_ctl(31 downto 12);
        when "1100" =>
            cfg_pmcsr <= tl_cfg_ctl;
        when "1101" =>
            cfg_msixcsr <= tl_cfg_ctl(31 downto 16);
            cfg_msicsr <= tl_cfg_ctl(15 downto 0);
        when "1110" =>
            tx_ercgen <= tl_cfg_ctl(25);
            rx_errcheck <= tl_cfg_ctl(24);
            cfg_tcvcmap <= tl_cfg_ctl(23 downto 0);
        when "1111" =>
            cfg_msi_data <= tl_cfg_ctl(31 downto 16);
            cfg_busdev <= tl_cfg_ctl(12 downto 0);
        when others =>
            --
        end case;
    end if;
    end process;

end architecture;

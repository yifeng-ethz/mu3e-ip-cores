-- -----------------------------------------------------------------------------
-- File      : ingress_egress_adaptor_native_sv_scifi.vhd
-- Purpose   : RN.BASIC SciFi-only adapter binding swb_block to the native-SV OPQ
--             module without the generated Qsys wrapper library.
-- -----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mudaq.all;
use work.mu3e.all;
use work.util_slv.all;

entity ingress_egress_adaptor is
port (
    enable        : in std_logic;
    rx_ingress    : in work.mu3e.link32_array_t(3 downto 0);
    rx_egress     : out work.mu3e.link32_array_t(3 downto 0);
    reset_n       : in std_logic;
    clk           : in std_logic
);
end entity;

architecture rtl of ingress_egress_adaptor is

    component ordered_priority_queue_dut_sv is
    port (
        asi_ingress_0_data          : in std_logic_vector(35 downto 0);
        asi_ingress_0_valid         : in std_logic_vector(0 downto 0);
        asi_ingress_0_channel       : in std_logic_vector(1 downto 0);
        asi_ingress_0_startofpacket : in std_logic_vector(0 downto 0);
        asi_ingress_0_endofpacket   : in std_logic_vector(0 downto 0);
        asi_ingress_0_error         : in std_logic_vector(2 downto 0);
        asi_ingress_1_data          : in std_logic_vector(35 downto 0);
        asi_ingress_1_valid         : in std_logic_vector(0 downto 0);
        asi_ingress_1_channel       : in std_logic_vector(1 downto 0);
        asi_ingress_1_startofpacket : in std_logic_vector(0 downto 0);
        asi_ingress_1_endofpacket   : in std_logic_vector(0 downto 0);
        asi_ingress_1_error         : in std_logic_vector(2 downto 0);
        asi_ingress_2_data          : in std_logic_vector(35 downto 0);
        asi_ingress_2_valid         : in std_logic_vector(0 downto 0);
        asi_ingress_2_channel       : in std_logic_vector(1 downto 0);
        asi_ingress_2_startofpacket : in std_logic_vector(0 downto 0);
        asi_ingress_2_endofpacket   : in std_logic_vector(0 downto 0);
        asi_ingress_2_error         : in std_logic_vector(2 downto 0);
        asi_ingress_3_data          : in std_logic_vector(35 downto 0);
        asi_ingress_3_valid         : in std_logic_vector(0 downto 0);
        asi_ingress_3_channel       : in std_logic_vector(1 downto 0);
        asi_ingress_3_startofpacket : in std_logic_vector(0 downto 0);
        asi_ingress_3_endofpacket   : in std_logic_vector(0 downto 0);
        asi_ingress_3_error         : in std_logic_vector(2 downto 0);
        aso_egress_data             : out std_logic_vector(35 downto 0);
        aso_egress_valid            : out std_logic;
        aso_egress_ready            : in std_logic;
        aso_egress_startofpacket    : out std_logic;
        aso_egress_endofpacket      : out std_logic;
        aso_egress_error            : out std_logic_vector(2 downto 0);
        avs_csr_address             : in std_logic_vector(8 downto 0);
        avs_csr_read                : in std_logic;
        avs_csr_write               : in std_logic;
        avs_csr_writedata           : in std_logic_vector(31 downto 0);
        avs_csr_readdata            : out std_logic_vector(31 downto 0);
        avs_csr_readdatavalid       : out std_logic;
        avs_csr_waitrequest         : out std_logic;
        avs_csr_burstcount          : in std_logic;
        d_clk                       : in std_logic;
        d_reset                     : in std_logic
    );
    end component;

    signal aso_egress_data           : std_logic_vector(35 downto 0);
    signal aso_egress_valid          : std_logic;
    signal aso_egress_startofpacket  : std_logic;
    signal aso_egress_endofpacket    : std_logic;
    signal ingress_startofpacket     : std_logic_vector(3 downto 0) := (others => '0');
    signal ingress_endofpacket       : std_logic_vector(3 downto 0) := (others => '0');
    signal ingress_error             : slv3_array_t(3 downto 0) := (others => (others => '0'));
    signal csr_readdata              : std_logic_vector(31 downto 0);
    signal csr_readdatavalid         : std_logic;
    signal csr_waitrequest           : std_logic;

begin

    gen_ingress_markers : for lane in 0 to 3 generate
    begin
        ingress_startofpacket(lane) <= enable and rx_ingress(lane).sop and not rx_ingress(lane).idle;
        ingress_endofpacket(lane)   <= enable and rx_ingress(lane).eop and not rx_ingress(lane).idle;
        ingress_error(lane)         <= (others => '0');
    end generate;

    e_opq_native_sv : component ordered_priority_queue_dut_sv
    port map (
        asi_ingress_0_data          => rx_ingress(0).datak & rx_ingress(0).data,
        asi_ingress_0_valid         => (0 => (not rx_ingress(0).idle) and enable),
        asi_ingress_0_channel       => "00",
        asi_ingress_0_startofpacket => (0 => ingress_startofpacket(0)),
        asi_ingress_0_endofpacket   => (0 => ingress_endofpacket(0)),
        asi_ingress_0_error         => ingress_error(0),
        asi_ingress_1_data          => rx_ingress(1).datak & rx_ingress(1).data,
        asi_ingress_1_valid         => (0 => (not rx_ingress(1).idle) and enable),
        asi_ingress_1_channel       => "01",
        asi_ingress_1_startofpacket => (0 => ingress_startofpacket(1)),
        asi_ingress_1_endofpacket   => (0 => ingress_endofpacket(1)),
        asi_ingress_1_error         => ingress_error(1),
        asi_ingress_2_data          => rx_ingress(2).datak & rx_ingress(2).data,
        asi_ingress_2_valid         => (0 => (not rx_ingress(2).idle) and enable),
        asi_ingress_2_channel       => "10",
        asi_ingress_2_startofpacket => (0 => ingress_startofpacket(2)),
        asi_ingress_2_endofpacket   => (0 => ingress_endofpacket(2)),
        asi_ingress_2_error         => ingress_error(2),
        asi_ingress_3_data          => rx_ingress(3).datak & rx_ingress(3).data,
        asi_ingress_3_valid         => (0 => (not rx_ingress(3).idle) and enable),
        asi_ingress_3_channel       => "11",
        asi_ingress_3_startofpacket => (0 => ingress_startofpacket(3)),
        asi_ingress_3_endofpacket   => (0 => ingress_endofpacket(3)),
        asi_ingress_3_error         => ingress_error(3),
        aso_egress_data             => aso_egress_data,
        aso_egress_valid            => aso_egress_valid,
        aso_egress_ready            => '1',
        aso_egress_startofpacket    => aso_egress_startofpacket,
        aso_egress_endofpacket      => aso_egress_endofpacket,
        aso_egress_error            => open,
        avs_csr_address             => (others => '0'),
        avs_csr_read                => '0',
        avs_csr_write               => '0',
        avs_csr_writedata           => (others => '0'),
        avs_csr_readdata            => csr_readdata,
        avs_csr_readdatavalid       => csr_readdatavalid,
        avs_csr_waitrequest         => csr_waitrequest,
        avs_csr_burstcount          => '1',
        d_clk                       => clk,
        d_reset                     => not reset_n
    );

    egress_mux : process(all)
        variable egress_link : work.mu3e.link32_t;
    begin
        rx_egress <= rx_ingress;

        if enable = '1' then
            rx_egress <= (others => work.mu3e.LINK32_IDLE);
            if aso_egress_valid = '1' then
                egress_link := work.mu3e.to_link(aso_egress_data(31 downto 0), aso_egress_data(35 downto 32));
                egress_link.idle := '0';
                if (aso_egress_data(35 downto 32) = "0001") and (aso_egress_data(7 downto 0) = x"BC") then
                    if (aso_egress_data(31 downto 26) = MUPIX_HEADER_ID) or
                       (aso_egress_data(31 downto 26) = TILE_HEADER_ID) or
                       (aso_egress_data(31 downto 26) = SCIFI_HEADER_ID) then
                        egress_link.data(31 downto 26) := aso_egress_data(31 downto 26);
                    else
                        egress_link.data(31 downto 26) := SCIFI_HEADER_ID;
                    end if;
                    egress_link.sop := '1';
                else
                    egress_link.sop := aso_egress_startofpacket;
                end if;
                if (aso_egress_data(35 downto 32) = "0001") and (aso_egress_data(7 downto 0) = x"9C") then
                    egress_link.eop := '1';
                else
                    egress_link.eop := aso_egress_endofpacket;
                end if;
                egress_link.err := '0';
                rx_egress(0) <= egress_link;
            end if;
        end if;
    end process;

end architecture;

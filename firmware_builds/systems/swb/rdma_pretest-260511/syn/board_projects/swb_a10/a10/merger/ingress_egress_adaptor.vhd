-- -----------------------------------------------------------------------------
-- File      : ingress_egress_adaptor.vhd
-- Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
-- Version   : 26.3.8
-- Date      : 20260430
-- Change    : Register the OPQ ingress boundary so MMIO masks and link
--             records do not feed OPQ control counters in the same cycle.
-- -----------------------------------------------------------------------------

library ieee;
library opq_upstream_4lane;
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
    type slv36_array_t is array (natural range <>) of std_logic_vector(35 downto 0);

    signal aso_egress_data           : std_logic_vector(35 downto 0);
    signal aso_egress_valid          : std_logic;
    signal aso_egress_startofpacket  : std_logic;
    signal aso_egress_endofpacket    : std_logic;
    signal ingress_startofpacket     : std_logic_vector(3 downto 0)    := (others    => '0');
    signal ingress_endofpacket       : std_logic_vector(3 downto 0)    := (others    => '0');
    signal ingress_valid             : std_logic_vector(3 downto 0)    := (others    => '0');
    signal ingress_data              : slv36_array_t(3 downto 0)       := (others    => (others => '0'));
    signal ingress_error             : slv3_array_t(3 downto 0)        := (others    => (others => '0'));

begin

    ingress_pipe : process(clk)
    begin
        if rising_edge(clk) then
            if reset_n /= '1' then
                ingress_startofpacket    <= (others    => '0');
                ingress_endofpacket      <= (others    => '0');
                ingress_valid            <= (others    => '0');
                ingress_data             <= (others    => (others => '0'));
                ingress_error            <= (others    => (others => '0'));
            else
                for lane in 0 to 3 loop
                    ingress_valid(lane)            <= enable and not rx_ingress(lane).idle;
                    ingress_startofpacket(lane)    <= enable and rx_ingress(lane).sop and not rx_ingress(lane).idle;
                    ingress_endofpacket(lane)      <= enable and rx_ingress(lane).eop and not rx_ingress(lane).idle;
                    ingress_data(lane)             <= rx_ingress(lane).datak & rx_ingress(lane).data;
                    ingress_error(lane)            <= (others    => '0');
                end loop;
            end if;
        end if;
    end process;

    e_opq_upstream_4lane : entity opq_upstream_4lane.opq_upstream_4lane
    port map (
        clk_clk                    => clk,
        egress_startofpacket       => aso_egress_startofpacket,
        egress_endofpacket         => aso_egress_endofpacket,
        egress_valid               => aso_egress_valid,
        egress_ready               => '1',
        egress_error               => open,
        egress_data                => aso_egress_data,
        ingress_0_channel          => "00",
        ingress_0_startofpacket    => ingress_startofpacket(0),
        ingress_0_endofpacket      => ingress_endofpacket(0),
        ingress_0_data             => ingress_data(0),
        ingress_0_valid            => ingress_valid(0),
        ingress_0_error            => ingress_error(0),
        ingress_1_channel          => "01",
        ingress_1_startofpacket    => ingress_startofpacket(1),
        ingress_1_endofpacket      => ingress_endofpacket(1),
        ingress_1_data             => ingress_data(1),
        ingress_1_valid            => ingress_valid(1),
        ingress_1_error            => ingress_error(1),
        ingress_2_channel          => "10",
        ingress_2_startofpacket    => ingress_startofpacket(2),
        ingress_2_endofpacket      => ingress_endofpacket(2),
        ingress_2_data             => ingress_data(2),
        ingress_2_valid            => ingress_valid(2),
        ingress_2_error            => ingress_error(2),
        ingress_3_channel          => "11",
        ingress_3_startofpacket    => ingress_startofpacket(3),
        ingress_3_endofpacket      => ingress_endofpacket(3),
        ingress_3_data             => ingress_data(3),
        ingress_3_valid            => ingress_valid(3),
        ingress_3_error            => ingress_error(3),
        reset_reset                => not reset_n
    );

    egress_mux : process(all)
        variable egress_link : work.mu3e.link32_t;
    begin
        rx_egress <= rx_ingress;

        if enable = '1' then
            rx_egress <= (others => work.mu3e.LINK32_IDLE);
            if aso_egress_valid = '1' then
                egress_link         := work.mu3e.to_link(aso_egress_data(31 downto 0), aso_egress_data(35 downto 32));
                egress_link.idle    := '0';
                if (aso_egress_data(35 downto 32) = "0001") and (aso_egress_data(7 downto 0) = x"BC") then
                    egress_link.data(31 downto 26)    := MUPIX_HEADER_ID;
                    egress_link.sop                   := '1';
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

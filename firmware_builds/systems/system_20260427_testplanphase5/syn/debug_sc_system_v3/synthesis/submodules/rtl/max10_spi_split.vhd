-- File name : max10_spi_split.vhd
-- Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision  : 0.1.0 (file created)
-- Date      : 20260313
-- =========
-- Description : [Split-port Arria-side MAX10 custom-link master]
--
-- Function
--   Split-port translation of the legacy Arria-side MAX10 custom-link master.
--   The transaction sequencing is intentionally kept as close as possible to
--   the proven `max10_spi.vhd` behavior while replacing internal `inout`
--   ports with explicit `*_in`, `*_out`, and `*_oe` signals.
--
-- ================ synthesizer configuration ==================
-- altera vhdl_input_version vhdl_2008
-- ============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity max10_spi_split is
    port (
        csi_clk               : in    std_logic;
        rsi_reset_n           : in    std_logic;

        strobe                : in    std_logic;
        addr                  : in    std_logic_vector(6 downto 0);
        rw                    : in    std_logic;
        data_to_max           : in    std_logic_vector(31 downto 0);
        numbytes              : in    std_logic_vector(8 downto 0);
        next_data             : out   std_logic;
        word_from_max         : out   std_logic_vector(31 downto 0);
        word_en               : out   std_logic;
        byte_from_max         : out   std_logic_vector(7 downto 0);
        byte_en               : out   std_logic;
        busy                  : out   std_logic;

        coe_spi_csn           : out   std_logic;
        coe_spi_clk           : out   std_logic;
        coe_spi_mosi_in       : in    std_logic;
        coe_spi_mosi_out      : out   std_logic;
        coe_spi_mosi_oe       : out   std_logic;
        coe_spi_miso_in       : in    std_logic;
        coe_spi_miso_out      : out   std_logic;
        coe_spi_miso_oe       : out   std_logic;
        coe_spi_d1_in         : in    std_logic;
        coe_spi_d1_out        : out   std_logic;
        coe_spi_d1_oe         : out   std_logic;
        coe_spi_d2_in         : in    std_logic;
        coe_spi_d2_out        : out   std_logic;
        coe_spi_d2_oe         : out   std_logic;
        coe_spi_d3_in         : in    std_logic;
        coe_spi_d3_out        : out   std_logic;
        coe_spi_d3_oe         : out   std_logic
    );
end entity max10_spi_split;

architecture rtl of max10_spi_split is

    type spi_state_t is (
        IDLING,
        ADDRESSING,
        WRITINGDATA,
        WAITINGTURN,
        READINGDATA
    );

    signal spi_state                  : spi_state_t := IDLING;
    signal addrshift                  : std_logic_vector(7 downto 0)  := (others => '0');
    signal datashift                  : std_logic_vector(31 downto 0) := (others => '0');
    signal datareadshift              : std_logic_vector(31 downto 0) := (others => '0');
    signal toggle                     : std_logic                     := '0';
    signal nibblecount                : integer                       := 0;
    signal strobe_last                : std_logic                     := '0';
    signal haveread                   : std_logic                     := '0';
    signal mosi_in_sampled            : std_logic                     := 'Z';
    signal miso_in_sampled            : std_logic                     := 'Z';
    signal d1_in_sampled              : std_logic                     := 'Z';
    signal d2_in_sampled              : std_logic                     := 'Z';
    signal d3_in_sampled              : std_logic                     := 'Z';

begin

    -- spi_reg owns the nibble-serial FEBSPI master that drives the downstream
    -- Arria-to-MAX10 link lanes. All serialized pin timing and byte/word
    -- extraction state stays inside this single link-clock process.
    spi_reg : process (csi_clk, rsi_reset_n)
    begin
        if rsi_reset_n = '0' then
            coe_spi_csn              <= '1';
            coe_spi_clk              <= '0';
            coe_spi_mosi_out         <= '0';
            coe_spi_mosi_oe          <= '0';
            coe_spi_miso_out         <= '0';
            coe_spi_miso_oe          <= '0';
            coe_spi_d1_out           <= '0';
            coe_spi_d1_oe            <= '0';
            coe_spi_d2_out           <= '0';
            coe_spi_d2_oe            <= '0';
            coe_spi_d3_out           <= '0';
            coe_spi_d3_oe            <= '0';
            spi_state                <= IDLING;
            word_en                  <= '0';
            byte_en                  <= '0';
            next_data                <= '0';
            strobe_last              <= '0';
            busy                     <= '0';
            toggle                   <= '0';
            nibblecount              <= 0;
            haveread                 <= '0';
        elsif rising_edge(csi_clk) then
            word_en                  <= '0';
            byte_en                  <= '0';
            next_data                <= '0';
            strobe_last              <= strobe;
            coe_spi_miso_out         <= '0';
            mosi_in_sampled          <= coe_spi_mosi_in;
            miso_in_sampled          <= coe_spi_miso_in;
            d1_in_sampled            <= coe_spi_d1_in;
            d2_in_sampled            <= coe_spi_d2_in;
            d3_in_sampled            <= coe_spi_d3_in;

            case spi_state is
                when IDLING =>
                    coe_spi_csn          <= '1';
                    coe_spi_clk          <= '0';
                    coe_spi_mosi_oe      <= '0';
                    coe_spi_miso_oe      <= '0';
                    coe_spi_d1_oe        <= '0';
                    coe_spi_d2_oe        <= '0';
                    coe_spi_d3_oe        <= '0';
                    busy                 <= '0';
                    if (strobe = '1') and (strobe_last = '0') then
                        spi_state        <= ADDRESSING;
                        busy             <= '1';
                        coe_spi_csn      <= '0';
                        addrshift        <= rw & addr;
                        toggle           <= '0';
                        nibblecount      <= 0;
                    end if;

                when ADDRESSING =>
                    toggle               <= not toggle;
                    coe_spi_mosi_oe      <= '1';
                    coe_spi_d1_oe        <= '1';
                    coe_spi_d2_oe        <= '1';
                    coe_spi_d3_oe        <= '1';
                    coe_spi_miso_oe      <= '0';
                    if toggle = '0' then
                        coe_spi_clk      <= '0';
                        coe_spi_mosi_out <= addrshift(0);
                        coe_spi_d1_out   <= addrshift(1);
                        coe_spi_d2_out   <= addrshift(2);
                        coe_spi_d3_out   <= addrshift(3);
                        addrshift(3 downto 0)
                                           <= addrshift(7 downto 4);
                        nibblecount      <= nibblecount + 1;
                    else
                        coe_spi_clk      <= '1';
                    end if;

                    if nibblecount = 2 then
                        if rw = '1' then
                            spi_state    <= WRITINGDATA;
                            datashift    <= data_to_max;
                            next_data    <= '1';
                            nibblecount  <= 0;
                        else
                            spi_state    <= WAITINGTURN;
                            nibblecount  <= 0;
                        end if;
                    end if;

                when WRITINGDATA =>
                    toggle               <= not toggle;
                    coe_spi_mosi_oe      <= '1';
                    coe_spi_d1_oe        <= '1';
                    coe_spi_d2_oe        <= '1';
                    coe_spi_d3_oe        <= '1';
                    coe_spi_miso_oe      <= '0';
                    if toggle = '0' then
                        coe_spi_clk      <= '0';
                        coe_spi_mosi_out <= datashift(0);
                        coe_spi_d1_out   <= datashift(1);
                        coe_spi_d2_out   <= datashift(2);
                        coe_spi_d3_out   <= datashift(3);
                        datashift(27 downto 0)
                                           <= datashift(31 downto 4);
                        nibblecount      <= nibblecount + 1;
                        if (nibblecount / 2) = to_integer(unsigned(numbytes)) then
                            spi_state    <= IDLING;
                        end if;
                    else
                        coe_spi_clk      <= '1';
                        if (nibblecount mod 8) = 0 then
                            datashift    <= data_to_max;
                            if (nibblecount / 2) < to_integer(unsigned(numbytes)) then
                                next_data <= '1';
                            end if;
                        end if;
                    end if;

                    if ((nibblecount / 2) = to_integer(unsigned(numbytes))) and (toggle = '0') then
                        spi_state        <= IDLING;
                    end if;

                when WAITINGTURN =>
                    toggle               <= not toggle;
                    coe_spi_mosi_oe      <= '0';
                    coe_spi_miso_oe      <= '0';
                    coe_spi_d1_oe        <= '0';
                    coe_spi_d2_oe        <= '0';
                    coe_spi_d3_oe        <= '0';
                    if toggle = '0' then
                        coe_spi_clk      <= '0';
                        nibblecount      <= nibblecount + 1;
                    else
                        coe_spi_clk      <= '1';
                        if nibblecount = 3 then
                            spi_state    <= READINGDATA;
                            nibblecount  <= 0;
                        end if;
                    end if;

                when READINGDATA =>
                    haveread             <= '0';
                    toggle               <= not toggle;
                    coe_spi_mosi_oe      <= '0';
                    coe_spi_miso_oe      <= '0';
                    coe_spi_d1_oe        <= '0';
                    coe_spi_d2_oe        <= '0';
                    coe_spi_d3_oe        <= '0';
                    if toggle = '0' then
                        coe_spi_clk      <= '0';
                        datareadshift(28) <= mosi_in_sampled;
                        datareadshift(29) <= d1_in_sampled;
                        datareadshift(30) <= d2_in_sampled;
                        datareadshift(31) <= d3_in_sampled;
                        datareadshift(27 downto 0)
                                           <= datareadshift(31 downto 4);
                        nibblecount      <= nibblecount + 1;
                        haveread         <= '1';
                    else
                        coe_spi_clk      <= '1';
                    end if;

                    if ((nibblecount mod 2) = 0) and (nibblecount > 0) and (haveread = '1') then
                        byte_from_max    <= datareadshift(31 downto 24);
                        byte_en          <= '1';
                    end if;

                    if ((nibblecount mod 8) = 0) and (nibblecount > 0) and (haveread = '1') then
                        word_from_max    <= datareadshift;
                        word_en          <= '1';
                    end if;

                    if (nibblecount / 2) = to_integer(unsigned(numbytes)) then
                        spi_state        <= IDLING;
                    end if;
            end case;
        end if;
    end process spi_reg;

end architecture rtl;

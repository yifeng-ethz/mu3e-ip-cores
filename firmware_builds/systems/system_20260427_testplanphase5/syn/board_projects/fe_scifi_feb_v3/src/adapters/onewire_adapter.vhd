library ieee;
use ieee.std_logic_1164.all;

entity onewire_adapter is
    port (
        i_sense_dq_out           : in    std_logic_vector(5 downto 0);
        i_sense_dq_oe            : in    std_logic_vector(5 downto 0);
        o_sense_dq_in            : out   std_logic_vector(5 downto 0);

        io_scifi_temp_mutrig     : inout std_logic_vector(1 downto 0);
        io_scifi_temp_sipm       : inout std_logic_vector(1 downto 0);
        io_scifi_temp_dab        : inout std_logic_vector(1 downto 0)
    );
end entity onewire_adapter;

architecture rtl of onewire_adapter is
begin
    o_sense_dq_in(0) <= io_scifi_temp_mutrig(0);
    o_sense_dq_in(1) <= io_scifi_temp_mutrig(1);
    o_sense_dq_in(2) <= io_scifi_temp_sipm(0);
    o_sense_dq_in(3) <= io_scifi_temp_sipm(1);
    o_sense_dq_in(4) <= io_scifi_temp_dab(0);
    o_sense_dq_in(5) <= io_scifi_temp_dab(1);

    io_scifi_temp_mutrig(0) <= i_sense_dq_out(0) when i_sense_dq_oe(0) = '1' else 'Z';
    io_scifi_temp_mutrig(1) <= i_sense_dq_out(1) when i_sense_dq_oe(1) = '1' else 'Z';
    io_scifi_temp_sipm(0)   <= i_sense_dq_out(2) when i_sense_dq_oe(2) = '1' else 'Z';
    io_scifi_temp_sipm(1)   <= i_sense_dq_out(3) when i_sense_dq_oe(3) = '1' else 'Z';
    io_scifi_temp_dab(0)    <= i_sense_dq_out(4) when i_sense_dq_oe(4) = '1' else 'Z';
    io_scifi_temp_dab(1)    <= i_sense_dq_out(5) when i_sense_dq_oe(5) = '1' else 'Z';
end architecture rtl;

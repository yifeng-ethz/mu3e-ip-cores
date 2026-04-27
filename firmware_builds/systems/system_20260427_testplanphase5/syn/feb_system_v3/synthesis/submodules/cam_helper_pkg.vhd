-- cam_helper_pkg.vhd
-- Local replacements for altera_standard_functions maximum/minimum
-- needed because ModelSim ASE 10.5b has issues with the altera library versions.
library ieee;
use ieee.std_logic_1164.all;

package cam_helper_pkg is
    function cam_max(a, b : natural) return natural;
    function cam_min(a, b : natural) return natural;
end package;

package body cam_helper_pkg is
    function cam_max(a, b : natural) return natural is
    begin
        if a > b then return a; else return b; end if;
    end function;
    function cam_min(a, b : natural) return natural is
    begin
        if a < b then return a; else return b; end if;
    end function;
end package body;

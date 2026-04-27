#!/bin/bash
set -euf

# header and start of package
cat << EOF
--

-- NOTE: this file is generated with \`util_slv.sh\`

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use std.textio.all;
use ieee.std_logic_textio.all;

package util_slv is

EOF

RANGE=(
    {2..128}
    256 512 1024
)

# generate `slv$W_array_t` types
# and `to_slv(slv$W_array_t)` functions
for W in ${RANGE[@]} ; do
cat << EOF
    type slv${W}_array_t is array ( natural range <> ) of std_logic_vector(${W}-1 downto 0);
    function to_slv( a : slv${W}_array_t ) return std_logic_vector;

EOF
done

# start of package body
cat << EOF
end package;

package body util_slv is

EOF

# generate implementations of `to_slv` functions
for W in ${RANGE[@]} ; do
cat << EOF
    function to_slv ( a : slv${W}_array_t ) return std_logic_vector is
        variable v : std_logic_vector(a'length*${W}-1 downto 0);
    begin
        for i in a'range loop
            v((i+1)*a(i)'length-1 downto i*a(i)'length) := a(i);
        end loop;
        return v;
    end function;

EOF
done

# end
cat << EOF
end package body;
EOF

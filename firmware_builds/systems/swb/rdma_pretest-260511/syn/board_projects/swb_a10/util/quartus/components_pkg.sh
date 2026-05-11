#!/bin/bash
set -euf

# find `*.cmp` files
# and generate `cmp` (components) package

if [ $# -ge 1 ] ; then
    cd -- "$1" || exit 1
fi

cat << EOF
library ieee;
use ieee.std_logic_1164.all;

package cmp is

    constant GIT_HEAD : std_logic_vector(16*4-1 downto 0) := X"$(git rev-parse --short=16 HEAD | rev)";

$(
while read -r fname ; do
    echo "-- $fname"
    cat -- "$fname"
done < <(find -L . -name '*.cmp' | sort)
)

end package;
EOF

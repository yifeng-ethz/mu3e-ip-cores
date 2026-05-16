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
use ieee.numeric_std.all;

package cmp is

    constant GIT_HEAD : std_logic_vector(16*4-1 downto 0) := X"$(git rev-parse --short=16 HEAD | rev)";

$(
while read -r fname ; do
    echo "-- $fname"
    cat -- "$fname"
done < <(find -L . -name '*.cmp' | sort)
)

$(
while read -r fname ; do
    entity="$(basename -- "$fname" .vhd)"
    entity_dir="$(dirname -- "$(dirname -- "$fname")")"
    parent="$(basename -- "$entity_dir")"
    [ "$entity" = "$parent" ] || continue
    [ -f "$entity_dir/$entity.cmp" ] && continue

    echo "-- $fname"
    awk -v entity="$entity" '
        BEGIN { in_entity = 0 }
        $1 == "entity" && $2 == entity && $3 == "is" {
            in_entity = 1
            print "    component " entity " is"
            next
        }
        in_entity {
            if ($1 == "end" && $2 == "entity") {
                print "    end component;"
                print ""
                exit
            }
            print
        }
    ' "$fname"
done < <(find -L . -path '*/synth/*.vhd' | sort)
)

end package;
EOF

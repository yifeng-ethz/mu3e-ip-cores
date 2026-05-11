#/usr/bin/awk -f

BEGIN {
    exit_code = 1
    cable_index = -1
}

# parse cable number
/^[0-9]+\)/ {
    cable_index = -1
    split($1, cable_array, ")")

    # match cable index
    if(match(cable, /^[0-9]+$/) && cable == cable_array[1]) {
        cable_index = cable_array[1]
    }
    # match cable name
    if(match($2, cable)) {
        cable_index = cable_array[1]
    }

    if(cable_index > 0) {
        printf("I ["FILENAME"] found cable '%s'\n", $2) > "/dev/stderr"
    }
    next
}

# match device name
cable_index > 0 && match($2, device) > 0 {
    printf("I ["FILENAME"] found device '%s' -> use cable %d\n", $2, cable_index) > "/dev/stderr"
    print cable_index
    exit_code = 0
    exit 0
}

END {
    if(exit_code == 0) exit
    printf("E ["FILENAME"] cable not found\n") > "/dev/stderr"
    exit 1
}

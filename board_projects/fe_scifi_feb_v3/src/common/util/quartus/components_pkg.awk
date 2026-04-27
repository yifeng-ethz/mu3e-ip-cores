#!/usr/bin/awk -f

$1 == "component" && $3 == "is" && n[$2]++ {
    print "ERROR ["FILENAME":"NR"] " $2 " is already declared"
    exit 1
}

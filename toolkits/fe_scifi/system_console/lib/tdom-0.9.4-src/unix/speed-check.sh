#!/bin/bash
#
# This script is used for performance monitoring of tDOM.
#
# Needs valgrind (cachegrind), so best use on linux.
#
if test "$1" = ""
then
  echo "Usage: $0 OUTPUTFILE [OPTIONS]"
  exit
fi
NAME=$1
CACHEGRIND_OPTS=""
TESTSCRIPT="../tests/all.tcl"
TESTRUN_OPTS=""
shift
while test "$1" != ""; do
    case $1 in
        --testscript)
            shift
            TESTSCRIPT=$1
            ;;
        --options)  
            shift
            TESTRUN_OPTS=$1
            ;;                        
    esac
    shift
done
        
echo "NAME           = $NAME" | tee summary-$NAME.txt
echo 'puts [string range [dom featureinfo versionhash] 0 12]' \
    | ./tcldomsh >> summary-$NAME.txt
echo "TESTSCRIPT     = $TESTSCRIPT" | tee -a summary-$NAME.txt
echo "TESTRUN_OPTS   = $TESTRUN_OPTS" | tee -a summary-$NAME.txt
rm -f cachegrind.out.* 
valgrind --tool=cachegrind $CACHEGRIND_OPTS ./tcldomsh $TESTSCRIPT \
         $TESTRUN_OPTS 2>&1 | tee -a summary-$NAME.txt

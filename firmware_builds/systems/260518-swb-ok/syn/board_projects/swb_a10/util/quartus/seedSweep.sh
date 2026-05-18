#!/bin/bash
set -euf

result_dir="output_files_sweep"
result_summaryfile="$result_dir/results.txt"

echo "runnig seed sweep with 20 iterations. "
for ((i=1; i<=20; i++))
do
    mkdir -p $result_dir
    SEEDS=$RANDOM
    echo "--------------------"
    date
    echo "seed $SEEDS, iteration $i"
    echo "--------------------" >> $result_summaryfile
    echo "seed $SEEDS" >> $result_summaryfile
    make clean > /dev/null
    make flow SEED=$SEEDS > /dev/null
    grep "setup slack is" output_files/top.sta.rpt >> $result_summaryfile
    grep "hold slack is" output_files/top.sta.rpt >> $result_summaryfile
    grep "recovery slack is" output_files/top.sta.rpt >> $result_summaryfile
    grep "removal slack is" output_files/top.sta.rpt >> $result_summaryfile
    grep "minimum pulse width slack is" output_files/top.sta.rpt >> $result_summaryfile
    if grep -E "slack is *[-]" output_files/top.sta.rpt; then
        echo "failed timing";
        quartus_sta -t util/print_critical_path.tcl > $result_dir/last_timing_result.txt
        grep "Path #1" $result_dir/last_timing_result.txt | tee -a $result_summaryfile
        grep "From Node" $result_dir/last_timing_result.txt | tee -a $result_summaryfile
        grep "To Node" $result_dir/last_timing_result.txt | tee -a $result_summaryfile
    else
        echo "." >> $result_summaryfile; echo "." >> $result_summaryfile; echo "." >> $result_summaryfile; # to make entries of working ones the same length in summary file
        echo "found working seed $SEEDS, replacing seed in Makefile";
        sed -i "s/SEED = [0-9]*/SEED = $SEEDS/" Makefile;
        exit 0
    fi
done
echo "Unable to close timing by seed variation"

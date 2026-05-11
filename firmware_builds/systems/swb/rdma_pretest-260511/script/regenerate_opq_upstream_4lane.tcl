package require -exact qsys 16.1

set repo_root [file normalize [file join [file dirname [info script]] "../../../../.."]]
set hub_dir [file join $repo_root "quartus_systems/swb"]

cd $hub_dir
source [file join $hub_dir "opq_upstream_4lane.tcl"]

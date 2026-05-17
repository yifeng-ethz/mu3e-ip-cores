package require -exact qsys 16.1

set old_pwd [pwd]
cd [file join [file dirname [info script]] ".."]
set system_root [pwd]
cd [file join $system_root "../../../.."]
set repo_root_from_script [pwd]
cd $old_pwd
if {[file exists [file join $repo_root_from_script "quartus_systems/swb/opq_upstream_4lane.tcl"]]} {
    set repo_root $repo_root_from_script
} elseif {[info exists env(REPO_ROOT)]} {
    set repo_root $env(REPO_ROOT)
} else {
    set repo_root "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores"
}
set hub_dir [file join $repo_root "quartus_systems/swb"]

cd $hub_dir
source [file join $hub_dir "opq_upstream_4lane.tcl"]

package require -exact qsys 16.1

if {[info exists env(REPO_ROOT)]} {
    set repo_root $env(REPO_ROOT)
} else {
    set repo_root "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores"
}
set hub_dir [file join $repo_root "quartus_systems/swb"]

cd $hub_dir
source [file join $hub_dir "opq_upstream_4lane.tcl"]

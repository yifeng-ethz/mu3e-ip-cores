# RC Domain

Currently implemented:
- management-side RC word injection into `runctl_mgmt_host_*`
- confirmation that one RC word reaches all 16 datapath consumers
- one upper-path FEB frame injected at the frame-assembly seam
- one lower-path FEB frame injected at the frame-assembly seam
- confirmation that upper and lower uploads emerge on distinct SWB links

Useful expansion buckets for future UVM:
- RC state-transition sweep across all legal run-control words
- repeated RC toggling while datapath traffic is active
- partial-ready / backpressured splitter-consumer masks
- RC delivery during simultaneous SC and datapath activity
- RC burst tolerance / spacing sensitivity on the management ingress seam

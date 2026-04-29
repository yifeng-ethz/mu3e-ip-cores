# hit_type3_stream_merge

Packet-atomic two-input Avalon-ST merger for the 36-bit `hit_type3` post-hit-stack stream.

The Phase-5 FEB datapath has two hit-stack subsystems. This utility lets the histogram tap observe both post-hit-stack outputs while preserving the existing upper/lower upload exports. Arbitration is packet atomic and round-robin at packet boundaries.

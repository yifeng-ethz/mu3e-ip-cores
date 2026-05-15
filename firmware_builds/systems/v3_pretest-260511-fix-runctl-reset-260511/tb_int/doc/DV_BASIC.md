# DV_BASIC.md - tb_int BASIC bucket

**Companion docs:** [DV_INT_PLAN.md](DV_INT_PLAN.md), [DV_EDGE.md](DV_EDGE.md), [DV_ERROR.md](DV_ERROR.md), [DV_PROF.md](DV_PROF.md), [TEST_PLAN.md](../../doc/TEST_PLAN.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** DV_INT_PLAN.md
**ID Range:** B001-B192
**Total:** 192 cases (5 implemented / 0 waived)

**Methodology key:**
- **D** directed - single deterministic stimulus with a golden expectation.
- **R** constrained-random - UVM sequence randomises the named axis and the scoreboard checks count parity.

This file is the BASIC bucket for happy-path verification of v3_pretest-260511 feb_system_v3. Nominal RC and SC stimulus uses the deployed firefly path, and FEB datapath egress observes the legacy upload_pkt_mux path in this FEB-only build.

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---:|---|---|---|
| RC | 32 | B001-B032 | runctl_mgmt_host readyless broadcast reaches every consumer IP across legal state transitions | 0/32 |
| SC | 32 | B033-B064 | sc_hub_v2 and mm_bridge can read identity headers and round-trip one word at every CSR slave | 0/32 |
| DT | 128 | B065-B192 | virtual or emulator MuTRiG hits reach the legacy FEB upload_pkt_mux egress contract with sidecar lineage preserved | 5/128 |

## 2. RC

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| B001 | D | IDLE to RUN_PREP transition broadcast reaches all consumers | 1 | runctl_phy_agent drives RUN_PREP after 1 ms idle | every consumer observes RUN_PREP within one cycle; readyless contract honored | TBD |
| B002 | D | RUN_PREP to SYNC transition | 1 | runctl_phy_agent drives SYNC | every consumer transitions with no backpressure | TBD |
| B003 | D | SYNC to RUNNING transition | 1 | runctl_phy_agent drives RUNNING | every consumer transitions and run_window_db opens the active window | TBD |
| B004 | D | RUNNING to TERMINATING transition | 1 | runctl_phy_agent drives TERMINATING | every consumer transitions and in-flight drain remains bounded | TBD |
| B005 | D | TERMINATING to IDLE transition | 1 | runctl_phy_agent drives IDLE | every consumer returns to IDLE | TBD |
| B006 | D | Full happy path IDLE to IDLE | 1 | drive five transitions with 1 ms software-scale gaps | run_window_db records all five states and stable window markers | TBD |
| B007 | D | RUN_NUMBER increment across one cycle | 1 | increment RUN_NUMBER between IDLE and RUN_PREP | runctl_mgmt_host CSR reads back the new RUN_NUMBER | TBD |
| B008 | R | Randomised state-pair traversal seed 1 | 16 | sequence draws random legal state pairs | all legal pairs sampled across the run and no illegal backpressure observed | TBD |
| B009 | R | Additional randomised RC sequence seed 1 | 1 | runctl sequence seed 1 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B010 | R | Additional randomised RC sequence seed 2 | 1 | runctl sequence seed 2 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B011 | R | Additional randomised RC sequence seed 3 | 1 | runctl sequence seed 3 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B012 | R | Additional randomised RC sequence seed 4 | 1 | runctl sequence seed 4 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B013 | R | Additional randomised RC sequence seed 5 | 1 | runctl sequence seed 5 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B014 | R | Additional randomised RC sequence seed 6 | 1 | runctl sequence seed 6 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B015 | R | Additional randomised RC sequence seed 7 | 1 | runctl sequence seed 7 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B016 | R | Additional randomised RC sequence seed 8 | 1 | runctl sequence seed 8 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B017 | R | Additional randomised RC sequence seed 9 | 1 | runctl sequence seed 9 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B018 | R | Additional randomised RC sequence seed 10 | 1 | runctl sequence seed 10 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B019 | R | Additional randomised RC sequence seed 11 | 1 | runctl sequence seed 11 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B020 | R | Additional randomised RC sequence seed 12 | 1 | runctl sequence seed 12 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B021 | R | Additional randomised RC sequence seed 13 | 1 | runctl sequence seed 13 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B022 | R | Additional randomised RC sequence seed 14 | 1 | runctl sequence seed 14 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B023 | R | Additional randomised RC sequence seed 15 | 1 | runctl sequence seed 15 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B024 | R | Additional randomised RC sequence seed 16 | 1 | runctl sequence seed 16 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B025 | R | Additional randomised RC sequence seed 17 | 1 | runctl sequence seed 17 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B026 | R | Additional randomised RC sequence seed 18 | 1 | runctl sequence seed 18 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B027 | R | Additional randomised RC sequence seed 19 | 1 | runctl sequence seed 19 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B028 | R | Additional randomised RC sequence seed 20 | 1 | runctl sequence seed 20 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B029 | R | Additional randomised RC sequence seed 21 | 1 | runctl sequence seed 21 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B030 | R | Additional randomised RC sequence seed 22 | 1 | runctl sequence seed 22 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B031 | R | Additional randomised RC sequence seed 23 | 1 | runctl sequence seed 23 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |
| B032 | R | Additional randomised RC sequence seed 24 | 1 | runctl sequence seed 24 covers state holds and legal transitions | run_window_db state ledger is monotonic and every observed transition is legal | TBD |

Dedicated RC debug-fallback IDs, outside the canonical numeric signoff bucket:

| ID | Method | Scenario | Stimulus | Pass Criteria |
|---|---|---|---|---|
| B-RC-CSR-001 | D | IDLE to RUN_PREP transition via CSR toggle alone | runctl_seq_csr writes RUN_PREP with the 1 ms command gap | runctl_mgmt_host_0.run_ctrl egress reaches RUN_PREP one-hot and matches the B001 firefly reference |
| B-RC-CSR-002 | D | Full IDLE to RUNNING to IDLE walk via CSR toggle | runctl_seq_csr writes the full state sequence with 1 ms gaps | run_window_db markers match the B006 firefly reference |

## 3. SC

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| B033 | D | UID read of scratch_pad_ram | 1 | SC bridge reads word 0x00000 | UID matches the IP constant | TBD |
| B034 | D | UID read of onewire_master_controller_0 | 1 | SC bridge reads word 0x04400 | UID matches the IP constant | TBD |
| B035 | D | UID read of max10_prog_avmm_0 | 1 | SC bridge reads word 0x04800 | UID matches the IP constant | TBD |
| B036 | D | UID read of charge_injection_pulser_0 | 1 | SC bridge reads word 0x04C00 | UID matches and WO access completes without protocol error | TBD |
| B037 | D | UID read of firefly_xcvr_ctrl_0 | 1 | SC bridge reads word 0x05000 | UID matches the IP constant | TBD |
| B038 | D | UID read of on_die_temp_sense_ctrl | 1 | SC bridge reads word 0x05400 | UID matches the IP constant | TBD |
| B039 | D | UID read through mm_bridge to data_path | 1 | SC bridge reads word 0x08000 | bridge access completes and UID matches | TBD |
| B040 | D | UID read of mutrig_cfg_ctrl_0 CSR | 1 | SC bridge reads word 0x0FC04 | UID matches the IP constant | TBD |
| B041 | D | UID read of runctl_mgmt_host | 1 | SC bridge reads through upload_avmm aperture | UID visible from local JTAG and SWB sc_hub paths | TBD |
| B042 | D | UID read of upload_subsystem runctl_mgmt_host aperture | 1 | SC bridge reads the upload_subsystem control aperture | UID matches the runctl_mgmt_host constant | TBD |
| B043 | D | Single-word RW round-trip on scratch_pad_ram | 1 | write 0xAABBCCDD then read it back | read returns the written value | TBD |
| B044 | R | Randomised SC single-word RW round-trip seed 1 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 1 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B045 | R | Randomised SC single-word RW round-trip seed 2 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 2 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B046 | R | Randomised SC single-word RW round-trip seed 3 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 3 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B047 | R | Randomised SC single-word RW round-trip seed 4 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 4 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B048 | R | Randomised SC single-word RW round-trip seed 5 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 5 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B049 | R | Randomised SC single-word RW round-trip seed 6 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 6 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B050 | R | Randomised SC single-word RW round-trip seed 7 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 7 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B051 | R | Randomised SC single-word RW round-trip seed 8 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 8 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B052 | R | Randomised SC single-word RW round-trip seed 9 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 9 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B053 | R | Randomised SC single-word RW round-trip seed 10 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 10 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B054 | R | Randomised SC single-word RW round-trip seed 11 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 11 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B055 | R | Randomised SC single-word RW round-trip seed 12 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 12 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B056 | R | Randomised SC single-word RW round-trip seed 13 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 13 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B057 | R | Randomised SC single-word RW round-trip seed 14 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 14 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B058 | R | Randomised SC single-word RW round-trip seed 15 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 15 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B059 | R | Randomised SC single-word RW round-trip seed 16 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 16 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B060 | R | Randomised SC single-word RW round-trip seed 17 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 17 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B061 | R | Randomised SC single-word RW round-trip seed 18 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 18 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B062 | R | Randomised SC single-word RW round-trip seed 19 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 19 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B063 | R | Randomised SC single-word RW round-trip seed 20 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 20 | selected RW field round-trips and no adjacent CSR aliases | TBD |
| B064 | R | Randomised SC single-word RW round-trip seed 21 | 1 | sc_phy_agent selects one RW slave and one RW field for seed 21 | selected RW field round-trips and no adjacent CSR aliases | TBD |

Dedicated SC debug-fallback IDs, outside the canonical numeric signoff bucket:

| ID | Method | Scenario | Stimulus | Pass Criteria |
|---|---|---|---|---|
| B-SC-JTG-001 | D | Read UID of scratch_pad_ram via JTAG master | sc_seq_jtag reads scratch_pad_ram UID | UID matches the path-A firefly reference captured in B033 |
| B-SC-JTG-002 | D | Single-word RW round-trip on scratch_pad_ram via JTAG master | sc_seq_jtag writes then reads one scratch word | read-back agrees with the path-A firefly reference |
| B-SC-JTG-003 | D | Read runctl_mgmt_host_0 UID via JTAG master and bridge | sc_seq_jtag reads through the cross-subsystem bridge | runctl_mgmt_host_0 UID is reachable from the debug fallback path |

## 4. DT

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| B065 | D | 16-hit virtual MuTRiG smoke, lane 0, phase 100 | 1 | mutrig_phy_agent emits 16 hits at 100 kHz per channel on channels 0 and 1 | scoreboard reconciles 16 at every stage and sidecar IDs are present at every level-2 tap | uvm/v3_pretest-260511/tests/tb_int_b065_test.sv |
| B066 | D | 16-hit emulator_mutrig direct smoke, lane 0 | 1 | emulator-style source injects 16 deterministic pulses at 100 kHz | scoreboard reconciles 16 at every stage with EMU source lineage | uvm/v3_pretest-260511/tests/tb_int_b066_test.sv |
| B067 | D | Sidecar lineage validation, lane 0 | 1 | inject 100 hits with known hit_id 0 through 99 | L2, pre-rbCAM, post-rbCAM, and FEB-egress taps carry the same hit_id with zero missing | uvm/v3_pretest-260511/tests/tb_int_b067_test.sv |
| B068 | D | Histogram cross-check at pre-rbCAM, lane 0 | 1 | drive 1024 hits at 1 MHz in the stable window | scoreboard reconstructs delay distribution and histogram-side count model matches within DV_COV.md threshold | uvm/v3_pretest-260511/tests/tb_int_b068_test.sv |
| B069 | D | Legacy upload_pkt_mux one-hit FEB-egress smoke | 1 | drive one hit to FEB-egress and capture the upload_pkt_mux egress model | FEB egress record closes with the expected sidecar and zero residual | uvm/v3_pretest-260511/tests/tb_int_b069_test.sv |
| B070 | D | Rate distribution sweep lane 0 at 10 kHz | 1 | virtual MuTRiG drives one channel at 10 kHz | scoreboard reports zero drops in stable window and histogram delta-shape matches expectation | TBD |
| B071 | D | Rate distribution sweep lane 0 at 100 kHz | 1 | virtual MuTRiG drives one channel at 100 kHz | scoreboard reports zero drops in stable window and histogram delta-shape matches expectation | TBD |
| B072 | D | Rate distribution sweep lane 0 at 500 kHz | 1 | virtual MuTRiG drives one channel at 500 kHz | scoreboard reports zero drops in stable window and histogram delta-shape matches expectation | TBD |
| B073 | D | Rate distribution sweep lane 0 at 1 MHz | 1 | virtual MuTRiG drives one channel at 1 MHz | scoreboard reports zero drops in stable window and histogram delta-shape matches expectation | TBD |
| B074 | D | Rate distribution sweep lane 0 at 2 MHz | 1 | virtual MuTRiG drives one channel at 2 MHz | scoreboard reports zero drops in stable window and histogram delta-shape matches expectation | TBD |
| B075 | D | Rate distribution sweep lane 0 at 4 MHz | 1 | virtual MuTRiG drives one channel at 4 MHz | scoreboard reports zero drops in stable window and histogram delta-shape matches expectation | TBD |
| B076 | D | Rate distribution sweep lane 0 at 8 MHz | 1 | virtual MuTRiG drives one channel at 8 MHz | scoreboard reports zero drops in stable window and histogram delta-shape matches expectation | TBD |
| B077 | D | Rate distribution sweep lane 0 at 16 MHz | 1 | virtual MuTRiG drives one channel at 16 MHz | scoreboard reports zero drops in stable window and histogram delta-shape matches expectation | TBD |
| B078 | D | Rate distribution sweep lane 0 at single-frame | 1 | virtual MuTRiG drives one channel at single-frame | scoreboard reports zero drops in stable window and histogram delta-shape matches expectation | TBD |
| B079 | D | Rate distribution sweep lane 0 at two-frame | 1 | virtual MuTRiG drives one channel at two-frame | scoreboard reports zero drops in stable window and histogram delta-shape matches expectation | TBD |
| B080 | D | Rate distribution sweep lane 0 at wire-cap | 1 | virtual MuTRiG drives one channel at wire-cap | scoreboard reports zero drops in stable window and histogram delta-shape matches expectation | TBD |
| B081 | R | Randomised multiplicity x rate x channel-mask seed 1 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 1 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B082 | R | Randomised multiplicity x rate x channel-mask seed 2 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 2 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B083 | R | Randomised multiplicity x rate x channel-mask seed 3 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 3 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B084 | R | Randomised multiplicity x rate x channel-mask seed 4 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 4 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B085 | R | Randomised multiplicity x rate x channel-mask seed 5 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 5 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B086 | R | Randomised multiplicity x rate x channel-mask seed 6 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 6 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B087 | R | Randomised multiplicity x rate x channel-mask seed 7 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 7 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B088 | R | Randomised multiplicity x rate x channel-mask seed 8 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 8 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B089 | R | Randomised multiplicity x rate x channel-mask seed 9 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 9 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B090 | R | Randomised multiplicity x rate x channel-mask seed 10 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 10 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B091 | R | Randomised multiplicity x rate x channel-mask seed 11 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 11 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B092 | R | Randomised multiplicity x rate x channel-mask seed 12 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 12 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B093 | R | Randomised multiplicity x rate x channel-mask seed 13 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 13 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B094 | R | Randomised multiplicity x rate x channel-mask seed 14 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 14 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B095 | R | Randomised multiplicity x rate x channel-mask seed 15 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 15 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B096 | R | Randomised multiplicity x rate x channel-mask seed 16 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 16 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B097 | R | Randomised multiplicity x rate x channel-mask seed 17 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 17 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B098 | R | Randomised multiplicity x rate x channel-mask seed 18 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 18 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B099 | R | Randomised multiplicity x rate x channel-mask seed 19 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 19 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B100 | R | Randomised multiplicity x rate x channel-mask seed 20 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 20 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B101 | R | Randomised multiplicity x rate x channel-mask seed 21 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 21 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B102 | R | Randomised multiplicity x rate x channel-mask seed 22 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 22 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B103 | R | Randomised multiplicity x rate x channel-mask seed 23 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 23 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B104 | R | Randomised multiplicity x rate x channel-mask seed 24 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 24 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B105 | R | Randomised multiplicity x rate x channel-mask seed 25 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 25 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B106 | R | Randomised multiplicity x rate x channel-mask seed 26 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 26 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B107 | R | Randomised multiplicity x rate x channel-mask seed 27 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 27 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B108 | R | Randomised multiplicity x rate x channel-mask seed 28 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 28 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B109 | R | Randomised multiplicity x rate x channel-mask seed 29 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 29 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B110 | R | Randomised multiplicity x rate x channel-mask seed 30 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 30 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B111 | R | Randomised multiplicity x rate x channel-mask seed 31 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 31 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B112 | R | Randomised multiplicity x rate x channel-mask seed 32 | 1 | UVM sequence randomises multiplicity, rate, and channel mask for seed 32 | count parity reconciles per lane and hit key within DV_COV.md threshold | TBD |
| B113 | R | Spatial pattern sweep seed 1 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 1 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B114 | R | Spatial pattern sweep seed 2 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 2 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B115 | R | Spatial pattern sweep seed 3 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 3 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B116 | R | Spatial pattern sweep seed 4 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 4 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B117 | R | Spatial pattern sweep seed 5 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 5 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B118 | R | Spatial pattern sweep seed 6 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 6 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B119 | R | Spatial pattern sweep seed 7 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 7 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B120 | R | Spatial pattern sweep seed 8 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 8 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B121 | R | Spatial pattern sweep seed 9 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 9 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B122 | R | Spatial pattern sweep seed 10 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 10 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B123 | R | Spatial pattern sweep seed 11 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 11 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B124 | R | Spatial pattern sweep seed 12 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 12 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B125 | R | Spatial pattern sweep seed 13 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 13 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B126 | R | Spatial pattern sweep seed 14 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 14 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B127 | R | Spatial pattern sweep seed 15 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 15 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B128 | R | Spatial pattern sweep seed 16 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 16 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B129 | R | Spatial pattern sweep seed 17 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 17 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B130 | R | Spatial pattern sweep seed 18 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 18 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B131 | R | Spatial pattern sweep seed 19 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 19 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B132 | R | Spatial pattern sweep seed 20 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 20 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B133 | R | Spatial pattern sweep seed 21 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 21 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B134 | R | Spatial pattern sweep seed 22 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 22 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B135 | R | Spatial pattern sweep seed 23 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 23 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B136 | R | Spatial pattern sweep seed 24 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 24 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B137 | R | Spatial pattern sweep seed 25 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 25 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B138 | R | Spatial pattern sweep seed 26 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 26 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B139 | R | Spatial pattern sweep seed 27 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 27 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B140 | R | Spatial pattern sweep seed 28 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 28 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B141 | R | Spatial pattern sweep seed 29 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 29 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B142 | R | Spatial pattern sweep seed 30 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 30 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B143 | R | Spatial pattern sweep seed 31 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 31 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B144 | R | Spatial pattern sweep seed 32 | 1 | select random, clustered, hot-spot, or uniform spatial pattern for seed 32 | all lanes reconcile and sidecar is visible at every level-2 IP tap | TBD |
| B145 | R | Source mix REAL, EMU, MIX_RR seed 1 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 1 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B146 | R | Source mix REAL, EMU, MIX_RR seed 2 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 2 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B147 | R | Source mix REAL, EMU, MIX_RR seed 3 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 3 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B148 | R | Source mix REAL, EMU, MIX_RR seed 4 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 4 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B149 | R | Source mix REAL, EMU, MIX_RR seed 5 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 5 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B150 | R | Source mix REAL, EMU, MIX_RR seed 6 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 6 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B151 | R | Source mix REAL, EMU, MIX_RR seed 7 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 7 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B152 | R | Source mix REAL, EMU, MIX_RR seed 8 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 8 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B153 | R | Source mix REAL, EMU, MIX_RR seed 9 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 9 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B154 | R | Source mix REAL, EMU, MIX_RR seed 10 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 10 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B155 | R | Source mix REAL, EMU, MIX_RR seed 11 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 11 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B156 | R | Source mix REAL, EMU, MIX_RR seed 12 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 12 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B157 | R | Source mix REAL, EMU, MIX_RR seed 13 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 13 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B158 | R | Source mix REAL, EMU, MIX_RR seed 14 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 14 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B159 | R | Source mix REAL, EMU, MIX_RR seed 15 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 15 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B160 | R | Source mix REAL, EMU, MIX_RR seed 16 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 16 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B161 | R | Source mix REAL, EMU, MIX_RR seed 17 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 17 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B162 | R | Source mix REAL, EMU, MIX_RR seed 18 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 18 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B163 | R | Source mix REAL, EMU, MIX_RR seed 19 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 19 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B164 | R | Source mix REAL, EMU, MIX_RR seed 20 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 20 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B165 | R | Source mix REAL, EMU, MIX_RR seed 21 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 21 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B166 | R | Source mix REAL, EMU, MIX_RR seed 22 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 22 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B167 | R | Source mix REAL, EMU, MIX_RR seed 23 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 23 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B168 | R | Source mix REAL, EMU, MIX_RR seed 24 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 24 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B169 | R | Source mix REAL, EMU, MIX_RR seed 25 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 25 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B170 | R | Source mix REAL, EMU, MIX_RR seed 26 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 26 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B171 | R | Source mix REAL, EMU, MIX_RR seed 27 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 27 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B172 | R | Source mix REAL, EMU, MIX_RR seed 28 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 28 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B173 | R | Source mix REAL, EMU, MIX_RR seed 29 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 29 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B174 | R | Source mix REAL, EMU, MIX_RR seed 30 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 30 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B175 | R | Source mix REAL, EMU, MIX_RR seed 31 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 31 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B176 | R | Source mix REAL, EMU, MIX_RR seed 32 | 1 | source-mode sequence selects REAL, EMU, or MIX_RR for seed 32 | arb_hit_type0 source-mode coverage and watchdog cross coverage are sampled | TBD |
| B177 | D | Run-state-gated datapath directed case 1 | 1 | drive state transition boundary and deterministic hit packet for case 1 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B178 | D | Run-state-gated datapath directed case 2 | 1 | drive state transition boundary and deterministic hit packet for case 2 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B179 | D | Run-state-gated datapath directed case 3 | 1 | drive state transition boundary and deterministic hit packet for case 3 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B180 | D | Run-state-gated datapath directed case 4 | 1 | drive state transition boundary and deterministic hit packet for case 4 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B181 | D | Run-state-gated datapath directed case 5 | 1 | drive state transition boundary and deterministic hit packet for case 5 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B182 | D | Run-state-gated datapath directed case 6 | 1 | drive state transition boundary and deterministic hit packet for case 6 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B183 | D | Run-state-gated datapath directed case 7 | 1 | drive state transition boundary and deterministic hit packet for case 7 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B184 | D | Run-state-gated datapath directed case 8 | 1 | drive state transition boundary and deterministic hit packet for case 8 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B185 | D | Run-state-gated datapath directed case 9 | 1 | drive state transition boundary and deterministic hit packet for case 9 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B186 | D | Run-state-gated datapath directed case 10 | 1 | drive state transition boundary and deterministic hit packet for case 10 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B187 | D | Run-state-gated datapath directed case 11 | 1 | drive state transition boundary and deterministic hit packet for case 11 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B188 | D | Run-state-gated datapath directed case 12 | 1 | drive state transition boundary and deterministic hit packet for case 12 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B189 | D | Run-state-gated datapath directed case 13 | 1 | drive state transition boundary and deterministic hit packet for case 13 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B190 | D | Run-state-gated datapath directed case 14 | 1 | drive state transition boundary and deterministic hit packet for case 14 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B191 | D | Run-state-gated datapath directed case 15 | 1 | drive state transition boundary and deterministic hit packet for case 15 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |
| B192 | D | Run-state-gated datapath directed case 16 | 1 | drive state transition boundary and deterministic hit packet for case 16 | hits before SYNC are excluded and in-flight hits after TERMINATING complete correctly | TBD |

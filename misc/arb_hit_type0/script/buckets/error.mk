ERROR_TESTS += R001_async_reset_clears_state_test R002_reset_during_packet_test R003_back_to_back_resets_test R004_illegal_mode_encoding_test R005_clear_sticky_w1p_test R006_csr_undefined_address_read_test R007_sop_without_eop_records_syndrome_test R008_protocol_violation_two_sops_records_syndrome_test R009_eor_without_sop_test R010_two_simultaneous_eors_test R011_error_counter_saturation_test R012_run_control_reset_clears_error_state_test R013_watchdog_synthesis_real_test R014_watchdog_disabled_then_stuck_test R015_run_control_run_prep_during_packet_test

ERROR_RUNS := $(addprefix run_,$(ERROR_TESTS))

.PHONY: comp_dut_error
$(ERROR_RUNS) regress_error: comp_dut_error

comp_dut_error:
	@rm -f "$(DUT_STAMP)"
	@$(MAKE) --no-print-directory comp_dut FORCE_ERROR_BUCKET=1

# R016 is a B002 silicon-repro test that runs under tb_top_b002 via the
# run_b002_% target.  It is listed here for documentation but is NOT added
# to ERROR_TESTS because it needs a different elaboration top.
# To run: make -C tb run_b002_R016_nested_splitter_runctl_propagation_test

ifneq (,$(filter regress_error run_R% run_b002_%,$(MAKECMDGOALS))$(FORCE_ERROR_BUCKET))
ERROR_REAL_VLOG := $(VLOG)
VLOG := $(SHELL) $(IP_ROOT)/script/buckets/error_vlog_wrapper.sh $(ERROR_REAL_VLOG) $(SIM_DIR) $(UVM_DIR)
endif

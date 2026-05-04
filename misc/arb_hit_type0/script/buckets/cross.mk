CROSS_TESTS += X001_bucket_frame_basic_test X002_bucket_frame_edge_test X003_bucket_frame_prof_test X004_bucket_frame_error_test X005_all_buckets_frame_test

CROSS_UVM_SRCS := $(shell find "$(UVM_DIR)/sequence/cross" "$(UVM_DIR)/test/cross" -name '*.sv' -print 2>/dev/null | sort)
CROSS_STAMP    := $(SIM_DIR)/.cross.stamp
CROSS_RUNS     := $(addprefix run_,$(CROSS_TESTS))

$(CROSS_RUNS): TB_TOP := tb_top" "X999_cross_factory_anchor
$(CROSS_RUNS): comp_cross
regress_cross: comp_cross

.PHONY: comp_cross
comp_cross: $(CROSS_STAMP)

$(CROSS_STAMP): $(DUT_STAMP) $(CROSS_UVM_SRCS)
	@echo "=== Compiling CROSS UVM bucket ==="
	@$(VLOG) -modelsimini "$(MODELSIM_INI)" -sv -mfcu -cuname arb_hit_type0_cross_cu -work work \
	  +incdir+"$(UVM_SRC)" +incdir+"$(UVM_DIR)" $(CROSS_UVM_SRCS)
	@touch "$@"

.PHONY: clean int_b014_lane8_bitreverse_decode scifi_v4_wrapper

clean:
	@mkdir -p REPORT
	@echo "clean: timestamped Questa run directories are retained; no destructive cleanup needed"

int_b014_lane8_bitreverse_decode:
	FORCE_QSYS_GEN=1 EXTRA_PLUSARGS="+B014_ONLY" ./run_scifi_v4_wrapper.sh

scifi_v4_wrapper:
	./run_scifi_v4_wrapper.sh

include ../../../../scripts/questa_one.mk

FORMAL_TOOL := $(firstword $(wildcard $(QUESTA_HOME)/bin/qverify $(QUESTA_HOME)/linux_x86_64/qverify $(QUESTA_HOME)/bin/znformal $(QUESTA_HOME)/linux_x86_64/znformal))

.PHONY: rc_runctl_prove rc_runctl_cover rc_splitter_prove rc_splitter_cover \
        rc_mux_prove rc_mux_cover sc_decode_prove sc_decode_cover clean

define require_questa_formal
	@if [ -z "$(FORMAL_TOOL)" ]; then \
	  echo "ERROR: Questa Formal is the only supported formal backend, but qverify/znformal is not installed under $(QUESTA_HOME) or PATH." >&2; \
	  exit 1; \
	fi
	@echo "ERROR: OSS formal has been retired for this integration tree; migrate the requested proof to a scripted Questa Formal flow before running it." >&2
	@exit 1
endef

rc_runctl_prove:
	$(require_questa_formal)

rc_runctl_cover:
	$(require_questa_formal)

rc_splitter_prove:
	$(require_questa_formal)

rc_splitter_cover:
	$(require_questa_formal)

rc_mux_prove:
	$(require_questa_formal)

rc_mux_cover:
	$(require_questa_formal)

sc_decode_prove:
	$(require_questa_formal)

sc_decode_cover:
	$(require_questa_formal)

clean:
	rm -rf rc/runctl_mgmt_host_rc_formal rc/run_control_splitter_formal rc/upload_pkt_mux_formal \
	       sc/sc_decode_formal

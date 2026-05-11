QUESTA_HOME ?= /data1/questaone_sim/questasim
ETH_LIC_SERVER := 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE := $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE := $(LM_LICENSE_FILE)
export SALT_LICENSE_SERVER := $(LM_LICENSE_FILE)
export QSIM_INI := $(QUESTA_HOME)/modelsim.ini

.PHONY: docs check smoke basic

docs:
	python3 script/generate_swb_dv_docs.py

check: docs
	python3 ~/.codex/skills/dv-workflow/scripts/dv_bucket_format_check.py doc
	python3 ~/.codex/skills/dv-workflow/scripts/bug_history_format_check.py doc/BUG_HISTORY.md

smoke:
	python3 script/run_basic_bucket_sweep.py

basic: smoke

# tb_int BASIC Bucket Coverage Fragment

Status: no PASS rows recorded yet.

The BASIC case wrappers and `script/buckets/basic.mk` have been generated, but the current checked-in `tb_int/Makefile` does not include `script/buckets/*.mk` or define `run_<test>` targets. Per-case PASS evidence must be appended only after the shared make/filelist hooks are present and the requested `make run_<case> SEED=1` commands execute.

| Case | Test | Seed | Result | Log | Scoreboard Residual | Notes |
|---|---|---:|---|---|---|---|

# Agent Notes

- Never modify generated RTL under any `functional/` output directory in-place. If a change is needed, create a copy and ask for approval before wiring it in.
- Semantics-preserving edits for tool/simulator compatibility are OK; functional/behavior changes require explicit approval.
- Shared System Console toolkit sources live under `system_console_toolkit/`.
- The FE SciFi toolkit source of truth is `system_console_toolkit/fe_scifi/`.
- `online_dpv2` consumes the FE SciFi toolkit through the compatibility path `/home/yifeng/packages/online_dpv2/online/mu3e-ip-cores/system_console_toolkit`, which must resolve back to this repo.
- `/home/yifeng/packages/online_dpv2/online/mu3e-ip-cores` is only a compatibility symlink into the deprecated snapshot area. Do not add or update toolkit sources under its `system_console_toolkits/` tree.
- `/home/yifeng/packages/musip_2604/external/mu3e-ip-cores` is a pull-only consumer snapshot. Do not implement fixes there in-place.
- If an `external/mu3e-ip-cores` consumer needs a fix, make the change in the source repo under `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores` or the relevant nested repo (for example `packet_scheduler`), prefer a separate guest worktree, make commits there, then sync or pull the result back into the consumer snapshot.

#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

from svd_inventory_lib import REPO_ROOT, SYN_DIR, collect_manifest


SCRIPT_DIR = Path(__file__).resolve().parent
BOARD_TEST_DIR = SCRIPT_DIR.parent

DEFAULT_JTAG_MASTER_PATTERN = "*#7-2*/phy_0/master"
DEFAULT_JTAG_FALLBACK_PATTERN = ",".join(
    [
        "*phy_0/master",
        "*#7-2*/control_path_subsystem_jtag_master.master",
        "*control_path_subsystem_jtag_master.master",
    ]
)


def _default_sc_tool() -> Path:
    local = BOARD_TEST_DIR / "bin" / "sc_tool"
    if local.is_file():
        return local
    return Path("/home/yifeng/packages/online_dpv2/online/install/bin/sc_tool")


def _default_system_console() -> Path:
    path = os.environ.get("BOARD_TEST_SYSCON")
    if path:
        return Path(path)
    return Path("/data1/intelFPGA/18.1/quartus/sopc_builder/bin/system-console")


def _default_jdi() -> Path:
    path = os.environ.get("BOARD_TEST_JDI")
    if path:
        return Path(path)
    pipe = REPO_ROOT / "board_projects" / "fe_scifi_feb_v3" / "output_files_pipe" / "top_nostp_pipe.jdi"
    if pipe.is_file():
        return pipe
    return REPO_ROOT / "board_projects" / "fe_scifi_feb_v3" / "output_files" / "top.jdi"


def _default_project_dir() -> Path:
    path = os.environ.get("BOARD_TEST_PROJECT_DIR")
    if path:
        return Path(path)
    return REPO_ROOT / "board_projects" / "fe_scifi_feb_v3"


def run_checked(cmd: list[str], env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=True, capture_output=True, text=True, env=env)


def parse_sc_payload(output: str) -> list[int]:
    if "rsp                 : OK" not in output and "rsp = OK" not in output:
        raise RuntimeError(f"sc_tool did not return OK:\n{output}")
    values = []
    for match in re.finditer(r"payload\[\d+\]\s*=\s*(0x[0-9A-Fa-f]+)", output):
        values.append(int(match.group(1), 16))
    return values


def _sc_enable_mask_args() -> list[str]:
    value = os.environ.get("BOARD_TEST_SC_ENABLE_MASK", "").strip()
    return ["--enable-mask", value] if value else []


def sc_read(sc_tool: Path, link: int, addr: int, count: int) -> list[int]:
    cmd = [str(sc_tool), str(link), "read", f"0x{addr:05X}", str(count), "--quiet"]
    cmd.extend(_sc_enable_mask_args())
    result = run_checked(cmd)
    values = parse_sc_payload(result.stdout)
    if len(values) != count:
        raise RuntimeError(f"expected {count} payload words, got {len(values)} from sc_tool")
    return values


def sc_write(sc_tool: Path, link: int, addr: int, words: list[int]) -> None:
    cmd = [str(sc_tool), str(link), "write", f"0x{addr:05X}"]
    cmd.extend(f"0x{word:08X}" for word in words)
    cmd.append("--quiet")
    cmd.extend(_sc_enable_mask_args())
    result = run_checked(cmd)
    if "rsp                 : OK" not in result.stdout and "rsp = OK" not in result.stdout:
        raise RuntimeError(f"sc_tool write did not return OK:\n{result.stdout}")


def parse_jtag_output(output: str) -> tuple[list[int], dict[str, str]]:
    words = []
    result_line: dict[str, str] = {}
    for line in output.splitlines():
        line = line.strip()
        if line.startswith("JTAG_RW_WORD "):
            match = re.search(r"value=(0x[0-9A-Fa-f]+)", line)
            if not match:
                raise RuntimeError(f"failed to parse JTAG word line: {line}")
            words.append(int(match.group(1), 16))
        elif line.startswith("JTAG_RW_RESULT "):
            for token in line.split()[1:]:
                if "=" not in token:
                    continue
                key, value = token.split("=", 1)
                result_line[key] = value
    if result_line.get("status") != "OK":
        raise RuntimeError(f"JTAG helper failed:\n{output}")
    return words, result_line


def split_jtag_patterns(*patterns: str) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()
    for pattern in patterns:
        for item in pattern.split(","):
            item = item.strip()
            if not item or item in seen:
                continue
            seen.add(item)
            result.append(item)
    return result


def jtag_rw(
    system_console: Path,
    jdi: Path,
    project_dir: Path,
    op: str,
    addr: int,
    count: int = 1,
    data: list[int] | None = None,
    master_pattern: str = DEFAULT_JTAG_MASTER_PATTERN,
    fallback_pattern: str = DEFAULT_JTAG_FALLBACK_PATTERN,
    uid_addr: int = 0x400,
    uid_expected: int = 0x53434842,
) -> list[int]:
    script = SCRIPT_DIR / "jtag_rw.tcl"
    env = os.environ.copy()
    if "BOARD_TEST_DISPLAY" in env:
        env["DISPLAY"] = env["BOARD_TEST_DISPLAY"]
    else:
        env.pop("DISPLAY", None)
    env.setdefault("BOARD_TEST_SCRIPT_DIR", str(SCRIPT_DIR))

    errors: list[str] = []
    for pattern in split_jtag_patterns(master_pattern, fallback_pattern):
        cmd = [
            str(system_console),
            "-cli",
            "-disable_readline",
            "-disable_timeout",
            f"--project_dir={project_dir}",
            f"--jdi={jdi}",
            f"--script={script}",
            "--op",
            op,
            "--addr",
            f"0x{addr:08X}",
            "--count",
            str(count),
            "--master-pattern",
            pattern,
            "--fallback-pattern",
            "",
            "--uid-addr",
            f"0x{uid_addr:08X}",
            "--uid-expected",
            f"0x{uid_expected:08X}",
            "--service-tag",
            "board_test_meta",
        ]
        if data:
            cmd.extend(["--data", ",".join(f"0x{word:08X}" for word in data)])
        try:
            result = run_checked(cmd, env=env)
            words, _ = parse_jtag_output(result.stdout)
            return words
        except subprocess.CalledProcessError as exc:
            errors.append((exc.stdout or "") + (exc.stderr or ""))
        except Exception as exc:
            errors.append(str(exc))

    raise RuntimeError(
        "JTAG helper failed for all master patterns: "
        + ", ".join(split_jtag_patterns(master_pattern, fallback_pattern))
        + "\n"
        + "\n---\n".join(errors)
    )


def read_version_or_meta_sc(entry: dict[str, Any], sc_tool: Path, link: int, which: str) -> int | None:
    svd = entry.get("svd")
    if not svd:
        return None

    mode = svd.get(f"{which}_mode")
    offset = svd.get(f"{which}_offset")
    if mode is None or offset is None:
        return None
    base = entry["transports"]["sc"]["base_word"]
    target = base + offset // 4

    if mode == "direct":
        return sc_read(sc_tool, link, target, 1)[0]
    if mode == "meta":
        page = int(svd[f"{which}_page"])
        sc_write(sc_tool, link, target, [page])
        value = sc_read(sc_tool, link, target, 1)[0]
        if page != 0:
            sc_write(sc_tool, link, target, [0])
        return value
    raise RuntimeError(f"unsupported SC metadata mode: {mode}")


def read_version_or_meta_jtag(
    entry: dict[str, Any],
    system_console: Path,
    jdi: Path,
    project_dir: Path,
    which: str,
    master_pattern: str = DEFAULT_JTAG_MASTER_PATTERN,
    fallback_pattern: str = DEFAULT_JTAG_FALLBACK_PATTERN,
) -> int | None:
    svd = entry.get("svd")
    if not svd:
        return None

    mode = svd.get(f"{which}_mode")
    offset = svd.get(f"{which}_offset")
    if mode is None or offset is None:
        return None
    base = entry["transports"]["jtag"]["base_byte"]
    target = base + offset

    if mode == "direct":
        return jtag_rw(
            system_console,
            jdi,
            project_dir,
            "read",
            target,
            count=1,
            master_pattern=master_pattern,
            fallback_pattern=fallback_pattern,
        )[0]
    if mode == "meta":
        page = int(svd[f"{which}_page"])
        jtag_rw(
            system_console,
            jdi,
            project_dir,
            "write",
            target,
            data=[page],
            master_pattern=master_pattern,
            fallback_pattern=fallback_pattern,
        )
        value = jtag_rw(
            system_console,
            jdi,
            project_dir,
            "read",
            target,
            count=1,
            master_pattern=master_pattern,
            fallback_pattern=fallback_pattern,
        )[0]
        if page != 0:
            jtag_rw(
                system_console,
                jdi,
                project_dir,
                "write",
                target,
                data=[0],
                master_pattern=master_pattern,
                fallback_pattern=fallback_pattern,
            )
        return value
    raise RuntimeError(f"unsupported JTAG metadata mode: {mode}")


def fmt_hex(value: int | None) -> str:
    return "n/a" if value is None else f"0x{value:08X}"


def main() -> int:
    parser = argparse.ArgumentParser(description="Check live VERSION/GIT metadata against Qsys and SVD metadata.")
    parser.add_argument(
        "--qsys",
        type=Path,
        default=SYN_DIR / "debug_sc_system_v3.qsys",
    )
    parser.add_argument("--link", type=int, default=int(os.environ.get("BOARD_TEST_LINK", "2")))
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument("--system-console", type=Path, default=_default_system_console())
    parser.add_argument("--jdi", type=Path, default=_default_jdi())
    parser.add_argument("--project-dir", type=Path, default=_default_project_dir())
    parser.add_argument("--inventory-out", type=Path, default=None)
    parser.add_argument("--instances", type=str, default="")
    parser.add_argument("--inventory-only", action="store_true")
    parser.add_argument("--skip-sc", action="store_true")
    parser.add_argument("--skip-jtag", action="store_true")
    parser.add_argument(
        "--jtag-master-pattern",
        default=os.environ.get("BOARD_TEST_JTAG_MASTER_PATTERN", DEFAULT_JTAG_MASTER_PATTERN),
        help="Primary System Console master-service glob for JTAG metadata reads.",
    )
    parser.add_argument(
        "--jtag-fallback-pattern",
        default=os.environ.get("BOARD_TEST_JTAG_FALLBACK_PATTERN", DEFAULT_JTAG_FALLBACK_PATTERN),
        help="Comma-separated fallback System Console master-service globs.",
    )
    args = parser.parse_args()

    manifest = collect_manifest(args.qsys.resolve())
    if args.inventory_out:
        args.inventory_out.parent.mkdir(parents=True, exist_ok=True)
        args.inventory_out.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    wanted = {item.strip() for item in args.instances.split(",") if item.strip()}
    instances = []
    for entry in manifest["instances"]:
        if wanted and entry["instance"] not in wanted:
            continue
        if not entry["has_live_version_check"] and not entry["has_live_git_check"]:
            continue
        if "sc" not in entry["transports"] and "jtag" not in entry["transports"]:
            continue
        instances.append(entry)

    if args.inventory_only:
        print(json.dumps({"instances": instances}, indent=2, sort_keys=True))
        return 0

    failures = 0
    for entry in instances:
        name = entry["instance"]
        svd = entry["svd"] or {}
        expected_version = svd.get("packed_device_version")
        expected_git = entry.get("qsys_expected_git")

        sc_version = None
        sc_git = None
        jtag_version = None
        jtag_git = None
        errors: list[str] = []

        try:
            if not args.skip_sc and "sc" in entry["transports"]:
                sc_version = read_version_or_meta_sc(entry, args.sc_tool, args.link, "version")
                sc_git = read_version_or_meta_sc(entry, args.sc_tool, args.link, "git")
        except Exception as exc:
            errors.append(f"SC={exc}")

        try:
            if not args.skip_jtag and "jtag" in entry["transports"]:
                jtag_version = read_version_or_meta_jtag(
                    entry,
                    args.system_console,
                    args.jdi,
                    args.project_dir,
                    "version",
                    args.jtag_master_pattern,
                    args.jtag_fallback_pattern,
                )
                jtag_git = read_version_or_meta_jtag(
                    entry,
                    args.system_console,
                    args.jdi,
                    args.project_dir,
                    "git",
                    args.jtag_master_pattern,
                    args.jtag_fallback_pattern,
                )
        except Exception as exc:
            errors.append(f"JTAG={exc}")

        mismatches: list[str] = []
        if entry.get("svd_qsys_version_match") is False:
            mismatches.append(
                f"SVD_vs_QSYS_VERSION {fmt_hex(expected_version)} != {fmt_hex(entry.get('qsys_expected_packed_version'))}"
            )
        if expected_version is not None:
            if sc_version is not None and sc_version != expected_version:
                mismatches.append(f"SC_VERSION {fmt_hex(sc_version)} != {fmt_hex(expected_version)}")
            if jtag_version is not None and jtag_version != expected_version:
                mismatches.append(f"JTAG_VERSION {fmt_hex(jtag_version)} != {fmt_hex(expected_version)}")
        if expected_git is not None:
            if sc_git is not None and sc_git != expected_git:
                mismatches.append(f"SC_GIT {fmt_hex(sc_git)} != {fmt_hex(expected_git)}")
            if jtag_git is not None and jtag_git != expected_git:
                mismatches.append(f"JTAG_GIT {fmt_hex(jtag_git)} != {fmt_hex(expected_git)}")
        if sc_version is not None and jtag_version is not None and sc_version != jtag_version:
            mismatches.append(f"SC_vs_JTAG_VERSION {fmt_hex(sc_version)} != {fmt_hex(jtag_version)}")
        if sc_git is not None and jtag_git is not None and sc_git != jtag_git:
            mismatches.append(f"SC_vs_JTAG_GIT {fmt_hex(sc_git)} != {fmt_hex(jtag_git)}")

        status = "PASS"
        if errors or mismatches:
            status = "FAIL"
            failures += 1

        print(
            f"{status} {name} "
            f"svd={svd.get('path', 'n/a')} "
            f"exp_ver={fmt_hex(expected_version)} "
            f"qsys_ver={fmt_hex(entry.get('qsys_expected_packed_version'))} "
            f"sc_ver={fmt_hex(sc_version)} "
            f"jtag_ver={fmt_hex(jtag_version)} "
            f"exp_git={fmt_hex(expected_git)} "
            f"sc_git={fmt_hex(sc_git)} "
            f"jtag_git={fmt_hex(jtag_git)}"
        )
        for detail in mismatches:
            print(f"  mismatch: {detail}")
        for detail in errors:
            print(f"  error: {detail}")

    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())

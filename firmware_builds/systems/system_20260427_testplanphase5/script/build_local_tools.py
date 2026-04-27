#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
BOARD_TEST_DIR = SCRIPT_DIR.parent
BIN_DIR = BOARD_TEST_DIR / "bin"
ONLINE_BUILD = Path(os.environ.get("ONLINE_DPV2_BUILD", "/home/yifeng/packages/online_dpv2/online/build")).resolve()


def load_target_reply(tool_name: str) -> dict:
    reply_dir = ONLINE_BUILD / ".cmake" / "api" / "v1" / "reply"
    matches = sorted(reply_dir.glob(f"target-{tool_name}-*.json"))
    if not matches:
        raise FileNotFoundError(f"missing CMake reply JSON for {tool_name} under {reply_dir}")
    return json.loads(matches[-1].read_text(encoding="utf-8"))


def expand_link_tokens(build_root: Path, fragment: str) -> list[str]:
    tokens = shlex.split(fragment)
    out: list[str] = []
    for token in tokens:
        if token.startswith("-") or token.startswith("/"):
            out.append(token)
            continue
        out.append(str((build_root / token).resolve()))
    return out


def build_tool(tool_name: str, verbose: bool) -> None:
    spec = load_target_reply(tool_name)
    compile_group = spec["compileGroups"][0]
    source = SCRIPT_DIR / f"{tool_name}.cpp"
    obj = BIN_DIR / f".{tool_name}.o"
    out = BIN_DIR / tool_name

    if not source.is_file():
        raise FileNotFoundError(f"missing local source: {source}")

    compile_cmd = ["/usr/bin/g++"]
    for define in compile_group.get("defines", []):
        compile_cmd.append(f"-D{define['define']}")
    for include in compile_group.get("includes", []):
        flag = "-isystem" if include.get("isSystem") else "-I"
        compile_cmd.extend([flag, include["path"]])
    for fragment in compile_group.get("compileCommandFragments", []):
        part = fragment.get("fragment", "")
        if not part:
            continue
        compile_cmd.extend(shlex.split(part))
    compile_cmd.extend(["-c", str(source), "-o", str(obj)])

    link_cmd = ["/usr/bin/g++", "-o", str(out), str(obj)]
    for fragment in spec.get("link", {}).get("commandFragments", []):
        part = fragment.get("fragment", "")
        if not part:
            continue
        link_cmd.extend(expand_link_tokens(ONLINE_BUILD, part))

    BIN_DIR.mkdir(parents=True, exist_ok=True)

    if verbose:
        print("compile:", shlex.join(compile_cmd))
    subprocess.run(compile_cmd, check=True)
    if verbose:
        print("link   :", shlex.join(link_cmd))
    subprocess.run(link_cmd, check=True, cwd=ONLINE_BUILD)


def main() -> int:
    parser = argparse.ArgumentParser(description="Build local board_test sc_tool/rc_tool from the sources in this repo.")
    parser.add_argument("tools", nargs="*", default=["sc_tool", "rc_tool"], help="Tool names to build.")
    parser.add_argument("--verbose", action="store_true", help="Print compile and link commands.")
    args = parser.parse_args()

    for tool in args.tools:
        build_tool(tool, args.verbose)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Audit Mu3e IP-library submodule pointers, versions, and README links."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path


REPORT_LINK_RE = re.compile(
    r"\[[^\]]+\]\(([^)]+(?:SIGNOFF|DV_REPORT|VERIFICATION_SIGNOFF|"
    r"SYNTHESIS_SIGNOFF|TEST_REPORT|TLM_REPORT|MATH_REPORT)[^)]*)\)",
    re.IGNORECASE,
)


@dataclass
class SubmoduleAudit:
    path: str
    url: str
    https_url: str
    gitlink: str | None = None
    checkout: str | None = None
    versions: list[str] = field(default_factory=list)
    dirty_count: int = 0
    remote_ok: bool | None = None
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


def run(
    args: list[str],
    cwd: Path,
    check: bool = False,
    timeout: int = 20,
) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(
        args,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
    )
    if check and proc.returncode:
        raise RuntimeError(
            f"{' '.join(args)} failed in {cwd}:\n{proc.stderr.strip()}"
        )
    return proc


def normalize_github_url(url: str) -> str:
    if url.startswith("git@github.com:"):
        return "https://github.com/" + url.split(":", 1)[1]
    return url


def submodule_paths(repo: Path) -> dict[str, str]:
    proc = run(
        ["git", "config", "-f", ".gitmodules", "--get-regexp", r"^submodule\..*\.path$"],
        repo,
        check=True,
    )
    paths: dict[str, str] = {}
    for line in proc.stdout.splitlines():
        key, path = line.split(None, 1)
        name = key[len("submodule.") : -len(".path")]
        url_proc = run(
            ["git", "config", "-f", ".gitmodules", "--get", f"submodule.{name}.url"],
            repo,
            check=True,
        )
        paths[path] = url_proc.stdout.strip()
    return dict(sorted(paths.items()))


def gitlink_sha(repo: Path, path: str) -> str | None:
    proc = run(["git", "ls-tree", "HEAD", "--", path], repo, check=True)
    if not proc.stdout.strip():
        return None
    fields = proc.stdout.split()
    if len(fields) < 3 or fields[0] != "160000":
        return None
    return fields[2]


def strip_tcl_value(value: str) -> str:
    value = value.strip()
    value = value.rstrip(";").strip()
    if value.startswith("{") and value.endswith("}"):
        value = value[1:-1]
    if value.startswith('"') and value.endswith('"'):
        value = value[1:-1]
    return value


def version_from_tcl(text: str) -> list[str]:
    literal_versions: list[str] = []
    constants: dict[str, str] = {}

    for line in text.splitlines():
        line = re.split(r";\s*#", line, 1)[0]
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        m = re.match(r"set\s+([A-Za-z0-9_]+)\s+(.+)$", line)
        if m:
            constants[m.group(1)] = strip_tcl_value(m.group(2))
        m = re.match(r"set_module_property\s+VERSION\s+(.+)$", line)
        if m:
            value = strip_tcl_value(m.group(1))
            if value and not value.startswith("$") and "[" not in value:
                literal_versions.append(value)

    if literal_versions:
        return literal_versions

    major = constants.get("VERSION_MAJOR_DEFAULT_CONST")
    minor = constants.get("VERSION_MINOR_DEFAULT_CONST")
    patch = constants.get("VERSION_PATCH_DEFAULT_CONST")
    build = constants.get("BUILD_DEFAULT_CONST")
    date = constants.get("VERSION_DATE_DEFAULT_CONST")
    if major and minor and patch and (build or date):
        suffix = build if build else date[-4:]
        if suffix.isdigit():
            suffix = f"{int(suffix):04d}"
        return [f"{major}.{minor}.{patch}.{suffix}"]

    return []


def is_active_hw_tcl(path: str) -> bool:
    parts = set(Path(path).parts)
    ignored = {
        "deprecated",
        "doc",
        "legacy",
        "model",
        "old",
        "reference",
        "syn",
        "tb",
        "tb_int",
        "tb_old_reference",
        "trash_bin",
    }
    return not (parts & ignored)


def extract_versions(repo: Path, path: str, sha: str) -> list[str]:
    subrepo = repo / path
    proc = run(["git", "ls-tree", "-r", "--name-only", sha], subrepo, check=True)
    candidates = [
        name
        for name in proc.stdout.splitlines()
        if (name.endswith("_hw.tcl") or name.endswith("hw.tcl")) and is_active_hw_tcl(name)
    ]
    versions: list[str] = []
    for name in candidates:
        show = run(["git", "show", f"{sha}:{name}"], subrepo)
        if show.returncode:
            continue
        versions.extend(version_from_tcl(show.stdout))

    seen: set[str] = set()
    result: list[str] = []
    for version in versions:
        if version not in seen and re.match(r"^[0-9][0-9A-Za-z_.-]*$", version):
            seen.add(version)
            result.append(version)
    if not result:
        return []
    return [max(result, key=version_key)]


def version_key(version: str) -> tuple[int, ...]:
    numbers = [int(part) for part in re.findall(r"\d+", version)]
    return tuple(numbers)


def check_remote_contains(repo: Path, path: str, url: str, sha: str) -> bool:
    subrepo = repo / path
    https_url = normalize_github_url(url)
    proc = run(
        ["git", "fetch", "--quiet", "--no-tags", https_url, sha],
        subrepo,
        timeout=30,
    )
    return proc.returncode == 0


def audit_submodules(repo: Path, check_remote: bool) -> list[SubmoduleAudit]:
    audits: list[SubmoduleAudit] = []
    for path, url in submodule_paths(repo).items():
        audit = SubmoduleAudit(path=path, url=url, https_url=normalize_github_url(url))
        audits.append(audit)

        audit.gitlink = gitlink_sha(repo, path)
        if not audit.gitlink:
            audit.errors.append("missing parent gitlink")
            continue

        subrepo = repo / path
        head = run(["git", "rev-parse", "HEAD"], subrepo)
        if head.returncode:
            audit.errors.append("submodule checkout is missing or not a git repo")
        else:
            audit.checkout = head.stdout.strip()
            if audit.checkout != audit.gitlink:
                audit.errors.append(
                    f"checkout HEAD {audit.checkout[:12]} != parent gitlink {audit.gitlink[:12]}"
                )

        dirty = run(["git", "status", "--porcelain"], subrepo)
        if dirty.returncode == 0:
            audit.dirty_count = len([line for line in dirty.stdout.splitlines() if line])
            if audit.dirty_count:
                audit.warnings.append(f"dirty submodule worktree: {audit.dirty_count} entries")

        audit.versions = extract_versions(repo, path, audit.gitlink)
        if not audit.versions:
            audit.warnings.append("no VERSION surface found")

        if check_remote:
            audit.remote_ok = check_remote_contains(repo, path, url, audit.gitlink)
            if not audit.remote_ok:
                audit.errors.append(
                    "parent gitlink is not fetchable from normalized GitHub HTTPS URL"
                )

    return audits


def check_readme(repo: Path, audits: list[SubmoduleAudit]) -> list[str]:
    errors: list[str] = []
    readme = repo / "README.md"
    text = readme.read_text(encoding="utf-8")

    for audit in audits:
        if not audit.gitlink:
            continue
        if audit.path not in text:
            errors.append(f"README.md does not mention submodule {audit.path}")
        if audit.gitlink[:7] not in text and audit.gitlink[:12] not in text:
            errors.append(
                f"README.md does not record gitlink {audit.gitlink[:12]} for {audit.path}"
            )
        for version in audit.versions:
            if version not in text:
                errors.append(
                    f"README.md does not record VERSION {version} for {audit.path}"
                )

    submodule_roots = {audit.path for audit in audits}
    for target in REPORT_LINK_RE.findall(text):
        if re.match(r"^[a-z]+://", target):
            continue
        clean = target.split("#", 1)[0]
        first = clean.split("/", 1)[0]
        if first in submodule_roots:
            errors.append(
                f"README.md report link crosses submodule gitlink; use GitHub blob URL: {target}"
            )
        elif not (repo / clean).exists():
            errors.append(f"README.md report link target is missing: {target}")

    return errors


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".", help="repository root")
    parser.add_argument(
        "--check-remote",
        action="store_true",
        help="verify each parent gitlink can be fetched from its GitHub HTTPS URL",
    )
    parser.add_argument("--json", action="store_true", help="emit JSON audit")
    args = parser.parse_args(argv)

    repo = Path(args.repo).resolve()
    audits = audit_submodules(repo, args.check_remote)
    readme_errors = check_readme(repo, audits)

    if args.json:
        print(
            json.dumps(
                {
                    "submodules": [audit.__dict__ for audit in audits],
                    "readme_errors": readme_errors,
                },
                indent=2,
                sort_keys=True,
            )
        )
    else:
        for audit in audits:
            version = ", ".join(audit.versions) if audit.versions else "Prototype/unknown"
            remote = ""
            if audit.remote_ok is not None:
                remote = f" remote={'ok' if audit.remote_ok else 'missing'}"
            print(
                f"{audit.path}: gitlink={audit.gitlink[:12] if audit.gitlink else 'missing'} "
                f"version={version}{remote}"
            )
            for warning in audit.warnings:
                print(f"  WARN: {warning}")
            for error in audit.errors:
                print(f"  ERROR: {error}")
        for error in readme_errors:
            print(f"README ERROR: {error}")

    failed = bool(readme_errors or any(audit.errors for audit in audits))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

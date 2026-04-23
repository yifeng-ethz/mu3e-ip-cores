#!/usr/bin/env python3
"""Compatibility wrapper for the packet analyzer generator.

The original source was lost from the working tree, but the latest compiled
bytecode artifact is still present in ``__pycache__``. This wrapper restores
CLI/functionality by loading that bytecode directly.
"""

from __future__ import annotations

import argparse
import json
import os
import re
from importlib.machinery import SourcelessFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path
import sys


def load_compiled_module():
    pyc_path = Path(__file__).with_name("__pycache__") / "generate_musip_packet_analyzer.cpython-310.pyc"
    if not pyc_path.exists() or pyc_path.stat().st_size < 10_000:
        raise RuntimeError(
            "Original compiled generator backend is unavailable in this workspace. "
            "Use the existing generated bundles or restore the original source before regenerating."
        )
    loader = SourcelessFileLoader("_packet_analyzer_generator_compiled", str(pyc_path))
    spec = spec_from_loader(loader.name, loader)
    if spec is None:
        raise ImportError(f"Unable to create import spec for {pyc_path}")
    module = module_from_spec(spec)
    sys.modules[loader.name] = module
    loader.exec_module(module)
    return module


_compiled = load_compiled_module()

for _name in dir(_compiled):
    if _name.startswith("__"):
        continue
    globals()[_name] = getattr(_compiled, _name)


def parse_out_dir(argv: list[str]) -> Path | None:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--out-dir", default="")
    args, _ = parser.parse_known_args(argv)
    return Path(args.out_dir).resolve() if args.out_dir else None


def find_wave_reports_root(path: Path) -> Path | None:
    resolved = path.resolve()
    for candidate in [resolved, *resolved.parents]:
        if candidate.name == "wave_reports" and (candidate / "README.md").exists():
            return candidate
    return None


def parse_wave_report_intents(readme_path: Path) -> dict[tuple[str, str], str]:
    if not readme_path.exists():
        return {}
    intents: dict[tuple[str, str], str] = {}
    in_table = False
    for raw_line in readme_path.read_text().splitlines():
        line = raw_line.strip()
        if line.startswith("| bucket | case | intent |"):
            in_table = True
            continue
        if not in_table:
            continue
        if not line.startswith("|"):
            if intents:
                break
            continue
        cols = [col.strip() for col in line.strip("|").split("|")]
        if len(cols) < 4:
            continue
        bucket = cols[0].strip("` ")
        case_id = cols[1].strip("` ")
        intent = cols[2].strip("` ")
        if bucket.lower() == "bucket" or set(bucket) == {"-"}:
            continue
        intents[(bucket, case_id)] = intent
    return intents


def parse_payload_words(case_line: str) -> int | None:
    match = re.search(r"expected_words=(\d+)", case_line or "")
    return int(match.group(1)) if match else None


def build_case_description(intent: str, bundle_meta: dict) -> str:
    parts: list[str] = []
    if intent:
        parts.append(intent)
    profile_name = str(bundle_meta.get("profile_name") or "").strip()
    if profile_name:
        parts.append(f"profile={profile_name}")
    payload_words = parse_payload_words(((bundle_meta.get("summary_lines") or {}).get("case") or ""))
    if payload_words is not None:
        parts.append(f"payload_words={payload_words}")
    mask = str(bundle_meta.get("feb_enable_mask") or "").strip()
    if mask and mask.lower() not in {"0xf", "0x0f"}:
        parts.append(f"mask={mask}")
    dma_half_full_pct = bundle_meta.get("dma_half_full_pct")
    if isinstance(dma_half_full_pct, int) and dma_half_full_pct > 0:
        parts.append(f"dma_half_full={dma_half_full_pct}%")
    seed = bundle_meta.get("seed")
    if isinstance(seed, int):
        parts.append(f"seed={seed}")
    return " | ".join(parts)


def build_case_catalog_entries(out_dir: Path) -> tuple[Path | None, list[dict]]:
    wave_reports_root = find_wave_reports_root(out_dir)
    if wave_reports_root is None:
        return (None, [])
    intent_map = parse_wave_report_intents(wave_reports_root / "README.md")
    entries: list[dict] = []
    for bundle_path in sorted(wave_reports_root.glob("*/*/bundle.json")):
        bundle_meta = json.loads(bundle_path.read_text())
        case_dir = bundle_path.parent
        bucket = str(bundle_meta.get("bucket") or case_dir.parent.name)
        case_id = str(bundle_meta.get("case_id") or case_dir.name)
        packet_analyzer_dir = case_dir / (((bundle_meta.get("artifacts") or {}).get("packet_analyzer")) or "packet_analyzer")
        if not packet_analyzer_dir.is_dir():
            continue
        entries.append(
            {
                "bucket": bucket,
                "caseId": case_id,
                "label": f"{bucket} / {case_id}",
                "profileName": str(bundle_meta.get("profile_name") or ""),
                "description": build_case_description(intent_map.get((bucket, case_id), ""), bundle_meta),
                "url": f"/cases/{bucket}/{case_id}/",
                "targetDir": str(packet_analyzer_dir.resolve()),
                "current": packet_analyzer_dir.resolve() == out_dir.resolve(),
            }
        )
    return (wave_reports_root, entries)


def write_case_catalog(out_dir: Path) -> None:
    _, entries = build_case_catalog_entries(out_dir)
    payload = [
        {key: value for key, value in entry.items() if key != "targetDir"}
        for entry in entries
    ]
    (out_dir / "case-catalog.js").write_text(
        "window.__PACKET_ANALYZER_CASE_CATALOG__ = "
        + json.dumps(payload, separators=(",", ":"))
        + ";\n"
    )


def refresh_case_aliases(out_dir: Path) -> None:
    _, entries = build_case_catalog_entries(out_dir)
    cases_root = out_dir / "cases"
    cases_root.mkdir(exist_ok=True)
    for entry in entries:
        alias_path = cases_root / entry["bucket"] / entry["caseId"]
        alias_path.parent.mkdir(parents=True, exist_ok=True)
        if alias_path.is_symlink() or alias_path.exists():
            if alias_path.is_symlink():
                alias_path.unlink()
            else:
                continue
        os.symlink(entry["targetDir"], alias_path, target_is_directory=True)


if __name__ == "__main__":
    out_dir = parse_out_dir(sys.argv[1:])
    result = _compiled.main()
    if out_dir is not None and out_dir.is_dir():
        write_case_catalog(out_dir)
        refresh_case_aliases(out_dir)
    raise SystemExit(result)

#!/usr/bin/env python3
"""Auto-extract per-submodule version + last-updated metadata and rewrite the
README IP table.

The script regenerates the markdown table between the markers
`<!-- IP-TABLE:BEGIN -->` and `<!-- IP-TABLE:END -->` in README.md.

For each submodule it captures:
    - Display name (from `display_name` in the per-IP override map below, else
      the submodule path titlecased)
    - Description (from the per-IP override map, falling back to first non-empty
      paragraph of the IP's README, falling back to `gh repo view --json
      description`).
    - Version (maj.minor.patch[.date_suffix]). Resolution order:
        1. `<version>` from any `*.svd` file at the IP root or under script/.
        2. `VERSION_MAJOR/MINOR/PATCH` parameters in the IP's SystemVerilog or
           VHDL sources.
        3. `Prototype` if neither yields a value (matches existing convention).
    - Last updated date: ISO 8601 date of the submodule's HEAD commit.
    - Signoff links: parsed from the existing README row if present
      (preserves the curated `[DV]` / `[Syn]` / `[Standalone]` link set) until
      a follow-up automates that too.

Usage:
    python3 scripts/update_ip_table.py [--check]

`--check` exits nonzero if the file would change; useful for CI.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
README_PATH = REPO_ROOT / "README.md"
BEGIN_MARK = "<!-- IP-TABLE:BEGIN -->"
END_MARK = "<!-- IP-TABLE:END -->"

# Per-IP display-name and description overrides keyed by submodule path.
# When an IP has no override, the script falls back to autodetect.
IP_OVERRIDES: dict[str, dict[str, str]] = {
    "slow-control_hub": {
        "display": "Slow-Control Hub",
        "description": (
            "Converts Mu3e slow-control packets into Avalon Memory-Mapped"
            " transactions and handles burst count, address and response"
            " timing."
        ),
    },
    "onewire_temp_sense": {
        "display": "Onewire Temperature Sensor Controller",
        "description": (
            "Periodically polls 1-Wire temperature sensors; implements reset,"
            " presence detect and bit-level timing."
        ),
    },
    "mutrig_frame_deassembly": {
        "display": "MuTRiG Frame Deassembly",
        "description": (
            "Parses MuTRiG frames into header and hit payloads and flags"
            " individual hit errors and frame CRC errors."
        ),
    },
    "CAM": {
        "display": "CAM (Content Addressable Memory)",
        "description": (
            "Primitive content-addressable memory core. Use as a building"
            " block for caches, correlators and address decoders."
        ),
    },
    "mutrig_timestamp_processor": {
        "display": "MuTRiG Timestamp Processor",
        "description": (
            "Tracks MuTRiG timestamp overflow and maps MuTRiG-local timestamps"
            " to global timestamps."
        ),
    },
    "histogram_statistics": {
        "display": "Histogram Statistics",
        "description": (
            "Builds histograms from a selected data stream using SAR bin"
            " calculation and DP-RAM counters."
        ),
    },
    "mutrig_controller": {
        "display": "MuTRiG Controller",
        "description": (
            "SPI master for configuring MuTRiG ASICs. Automatically scans"
            " T- and E-thresholds and stores results locally."
        ),
    },
    "charge_injection": {
        "display": "Charge Injection (MuTRiG Injector)",
        "description": (
            "Generates calibration pulses and digital/analog stimuli for"
            " MuTRiG injection tests."
        ),
    },
    "alt_temp_sense_controller": {
        "display": "Altera Temperature Sensor Controller",
        "description": (
            "Wraps the on-chip alt_temp_sense IP on 28 nm devices and stores"
            " the last temperature result."
        ),
    },
    "high_performance_counter_array": {
        "display": "High Performance Counter Array",
        "description": (
            "Parallel counters supporting concurrent inputs with Avalon-MM"
            " readout. Features synchronous clear and reset."
        ),
    },
    "mutrig_channel_counter_fabric": {
        "display": "MuTRiG Channel Counter Fabric",
        "description": (
            "Connects hit type 0 from the frame deassembly IP to the counter"
            " array. Decodes channel IDs into one-hot update signals."
        ),
    },
    "lvds_error_counter_fabric": {
        "display": "LVDS Error Counter Fabric",
        "description": (
            "Accumulates parity and decode error counts from the LVDS"
            " receiver sideband."
        ),
    },
    "firefly_xcvr_i2c_master": {
        "display": "Firefly Transceiver I2C Master",
        "description": (
            "Interfaces with the Samtec Firefly optical transceiver module"
            " via I2C. Periodically reads temperature and RX power and can"
            " be halted."
        ),
    },
    "ip_8b10b_decoder": {
        "display": "IP 8b/10b Decoder",
        "description": (
            "Standard 8b/10b decoder for parallel LVDS rxout data. Derives"
            " parity and decoding errors."
        ),
    },
    "mutrig_reset_controller": {
        "display": "MuTRiG Reset Controller",
        "description": (
            "Issues reset pulses for the MuTRiG based on run-state changes."
            " Provides programmable phase shift via alt_pll_reconfig."
        ),
    },
    "ring-buffer_cam": {
        "display": "Ring-buffer CAM",
        "description": (
            "Circular buffer variant of CAM with push-to-stack write"
            " semantics and cache-like read-through. Used to build the hit"
            " stack."
        ),
    },
    "feb_frame_assembly": {
        "display": "Frontend-Board Frame Assembly",
        "description": (
            "Assembles time-interleaved subframes from the ring-buffer CAM"
            " into Mu3e-standard data frames and schedules packet"
            " transmission."
        ),
    },
    "feb_max10_comm": {
        "display": "FEB MAX10 Communication Bridge",
        "description": (
            "FEB-side Arria V bridge that stages one flash page, crosses it"
            " into the MAX10 link domain, and preserves the downstream"
            " FEBSPI programming contract."
        ),
    },
    "mu3e_lvds_controller": {
        "display": "Mu3e LVDS Controller",
        "description": (
            "Provides high-speed LVDS links to the MuPix sensors using FPGA"
            " vendor IP. Includes 28 nm LVDS RX and Pro variants."
        ),
    },
    "mupix_inbound": {
        "display": "MuPix Inbound",
        "description": (
            "Deserializes data from MuPix chips, decodes and buffers hits."
        ),
    },
    "packet_scheduler": {
        "display": "Packet Scheduler",
        "description": (
            "Orders packets via an interface adapter and ordered-priority"
            " queues to achieve deterministic DAQ multiplexing."
        ),
    },
    "emulator_mutrig": {
        "display": "MuTRiG Emulator",
        "description": (
            "FPGA emulator of MuTRiG 3 ASIC digital output. Produces 8b/1k"
            " frames bit-compatible with real ASIC output for FPGA-internal"
            " verification."
        ),
    },
    "run-control_mgmt": {
        "display": "Run-Control Management",
        "description": (
            "Manages run-state transitions for Mu3e subsystems and issues"
            " control signals. v26 adds the CSR LOCAL_CMD command-injection"
            " window and a readyless 9-bit fanout."
        ),
    },
    "board_test_system": {
        "display": "Board Test System",
        "description": (
            "DAQ bring-up and management-plane test system for exercising"
            " FPGA registers, links, and board services during validation."
        ),
    },
}


@dataclass
class IpRow:
    path: str
    name: str
    description: str
    version: str
    last_updated: str
    signoff: str
    url: str
    head_sha: str = ""
    branch: str = ""
    tracked_branch: str = ""
    notes: list[str] = field(default_factory=list)


def run(cmd: list[str], cwd: Path) -> str:
    proc = subprocess.run(
        cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    if proc.returncode:
        return ""
    return proc.stdout.strip()


def list_submodules() -> list[tuple[str, str, str]]:
    """Return list of (path, url, tracked_branch) tuples from .gitmodules in
    repo order. `tracked_branch` is the canonical branch the parent expects
    each submodule to follow; defaults to 'master' if the .gitmodules entry
    omits it."""
    out = run(
        [
            "git",
            "config",
            "-f",
            ".gitmodules",
            "--get-regexp",
            r"^submodule\..*\.path$",
        ],
        REPO_ROOT,
    )
    rows: list[tuple[str, str, str]] = []
    for line in out.splitlines():
        key, path = line.split(None, 1)
        name = key[len("submodule.") : -len(".path")]
        url = run(
            [
                "git",
                "config",
                "-f",
                ".gitmodules",
                "--get",
                f"submodule.{name}.url",
            ],
            REPO_ROOT,
        )
        tracked = (
            run(
                [
                    "git",
                    "config",
                    "-f",
                    ".gitmodules",
                    "--get",
                    f"submodule.{name}.branch",
                ],
                REPO_ROOT,
            )
            or "master"
        )
        rows.append((path, url, tracked))
    return rows


def normalize_github_url(url: str) -> str:
    if url.startswith("git@github.com:"):
        return "https://github.com/" + url.split(":", 1)[1].removesuffix(".git")
    return url.removesuffix(".git")


def find_version_from_svd(ip_root: Path) -> str | None:
    """Return the first `<version>` element from any .svd file at the IP root
    or under script/."""
    candidates: list[Path] = []
    candidates.extend(ip_root.glob("*.svd"))
    if (ip_root / "script").is_dir():
        candidates.extend((ip_root / "script").glob("*.svd"))
    for svd in candidates:
        try:
            tree = ET.parse(svd)
        except ET.ParseError:
            continue
        ver_el = tree.find("version")
        if ver_el is not None and ver_el.text:
            return ver_el.text.strip()
    return None


VERSION_PARAM_RE = re.compile(
    r"VERSION_(MAJOR|MINOR|PATCH)\s*[:=]?\s*(?:[A-Za-z_]\w*\s*[:=]\s*)?(\d+)"
)


def find_version_from_rtl(ip_root: Path) -> str | None:
    """Return `MAJOR.MINOR.PATCH` extracted from RTL VERSION_* parameters."""
    rtl_dirs: list[Path] = []
    for d in (ip_root / "rtl", ip_root):
        if d.is_dir():
            rtl_dirs.append(d)
    parts: dict[str, str] = {}
    for d in rtl_dirs:
        for ext in ("*.sv", "*.svh", "*.v", "*.vhd"):
            for f in d.rglob(ext):
                try:
                    text = f.read_text(errors="replace")
                except OSError:
                    continue
                for match in VERSION_PARAM_RE.finditer(text):
                    key = match.group(1)
                    val = match.group(2)
                    parts.setdefault(key, val)
                    if len(parts) == 3:
                        break
                if len(parts) == 3:
                    break
            if len(parts) == 3:
                break
        if len(parts) == 3:
            break
    if "MAJOR" in parts:
        ma = parts.get("MAJOR", "0")
        mi = parts.get("MINOR", "0")
        pa = parts.get("PATCH", "0")
        return f"{ma}.{mi}.{pa}"
    return None


def submodule_last_updated(path: Path) -> str:
    """Return YYYY-MM-DD of the submodule HEAD commit, or '-' on failure."""
    return run(["git", "log", "-1", "--format=%cs", "HEAD"], path) or "-"


def submodule_head_sha(path: Path) -> str:
    return run(["git", "rev-parse", "HEAD"], path)[:8]


def submodule_branch(path: Path) -> str:
    return run(["git", "rev-parse", "--abbrev-ref", "HEAD"], path)


SIGNOFF_RE = re.compile(
    r"(?:\[(?:DV|Syn|Standalone|Signoff)[^\]]*\]\([^)]+\)(?:\s*/\s*\[(?:DV|Syn|Standalone|Signoff)[^\]]*\]\([^)]+\))*)"
)


def parse_existing_signoff(readme_text: str, ip_path: str) -> str:
    """Best-effort: pull the curated signoff cell from the existing README row
    that mentions the IP path. Returns '—' if not found."""
    needle = f"yifeng-ethz/{ip_path}"
    if needle not in readme_text:
        return "—"
    for line in readme_text.splitlines():
        if needle not in line:
            continue
        cols = [c.strip() for c in line.split("|")]
        if len(cols) < 5:
            continue
        last = cols[-2]
        match = SIGNOFF_RE.findall(last)
        if match:
            return " / ".join(match)
        if last and last != "":
            return last
    return "—"


def build_row(
    path: str, url: str, tracked_branch: str, readme_text: str
) -> IpRow:
    ip_root = REPO_ROOT / path
    if not ip_root.is_dir():
        return IpRow(
            path=path,
            name=path,
            description="(submodule not initialized)",
            version="—",
            last_updated="—",
            signoff="—",
            url=normalize_github_url(url),
            tracked_branch=tracked_branch,
        )
    override = IP_OVERRIDES.get(path, {})
    name = override.get("display") or path
    description = override.get("description") or ""
    if not description:
        readme_md = ip_root / "README.md"
        if readme_md.exists():
            txt = readme_md.read_text(errors="replace")
            for line in txt.splitlines():
                line = line.strip()
                if line and not line.startswith("#") and not line.startswith("<"):
                    description = line[:240]
                    break
    if not description:
        description = "(no description)"
    version = (
        find_version_from_svd(ip_root)
        or find_version_from_rtl(ip_root)
        or "Prototype"
    )
    last_updated = submodule_last_updated(ip_root)
    head_sha = submodule_head_sha(ip_root)
    branch = submodule_branch(ip_root)
    signoff = parse_existing_signoff(readme_text, path)
    return IpRow(
        path=path,
        name=name,
        description=description,
        version=version,
        last_updated=last_updated,
        signoff=signoff,
        url=normalize_github_url(url),
        head_sha=head_sha,
        branch=branch,
        tracked_branch=tracked_branch,
    )


def render_table(rows: list[IpRow]) -> str:
    lines = [
        "<!-- This table is regenerated by scripts/update_ip_table.py."
        " Do not edit by hand. -->",
        "",
        "| IP | Description | Version | Last Updated | Tracked Branch | "
        "Current Branch | Signoff | HEAD |",
        "|---|---|:---:|:---:|:---:|:---:|:---:|:---:|",
    ]
    for r in rows:
        desc = r.description.replace("|", "\\|").replace("\n", " ")
        if len(desc) > 240:
            desc = desc[:237] + "..."
        name_cell = f"[**{r.name}**]({r.url})" if r.url else f"**{r.name}**"
        # Highlight when the current branch deviates from the tracked branch
        # of the parent .gitmodules entry.
        tracked_cell = (
            f"`{r.tracked_branch}`" if r.tracked_branch else "`master`"
        )
        if r.branch and r.tracked_branch and r.branch != r.tracked_branch:
            current_cell = f"**`{r.branch}`** ⚠"
        else:
            current_cell = f"`{r.branch}`" if r.branch else "—"
        lines.append(
            f"| {name_cell} | {desc} | `{r.version}` | "
            f"{r.last_updated} | {tracked_cell} | {current_cell} | "
            f"{r.signoff} | `{r.head_sha}` |"
        )
    lines.append("")
    return "\n".join(lines)


def update_readme(table_md: str) -> bool:
    text = README_PATH.read_text()
    if BEGIN_MARK not in text or END_MARK not in text:
        return False
    before, _, rest = text.partition(BEGIN_MARK)
    _, _, after = rest.partition(END_MARK)
    new = f"{before}{BEGIN_MARK}\n{table_md}\n{END_MARK}{after}"
    if new == text:
        return False
    README_PATH.write_text(new)
    return True


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit non-zero if README.md would change",
    )
    parser.add_argument(
        "--print-json",
        action="store_true",
        help="dump per-row data as JSON to stdout (skip README write)",
    )
    args = parser.parse_args(argv)
    submods = list_submodules()
    readme_text = README_PATH.read_text() if README_PATH.exists() else ""
    rows: list[IpRow] = []
    for path, url, tracked in submods:
        rows.append(build_row(path, url, tracked, readme_text))
    rows.sort(key=lambda r: r.name.lower())
    if args.print_json:
        json.dump(
            [
                {
                    "path": r.path,
                    "name": r.name,
                    "version": r.version,
                    "last_updated": r.last_updated,
                    "head_sha": r.head_sha,
                    "branch": r.branch,
                    "tracked_branch": r.tracked_branch,
                    "branch_drift": (
                        bool(r.branch)
                        and bool(r.tracked_branch)
                        and r.branch != r.tracked_branch
                    ),
                    "url": r.url,
                }
                for r in rows
            ],
            sys.stdout,
            indent=2,
        )
        sys.stdout.write("\n")
        return 0
    table_md = render_table(rows)
    if BEGIN_MARK not in readme_text:
        print(
            f"error: README.md is missing the marker '{BEGIN_MARK}'."
            f" Insert a line\n  {BEGIN_MARK}\n  {END_MARK}\nwhere you want the"
            f" generated IP table to live, then re-run.",
            file=sys.stderr,
        )
        return 2
    changed = update_readme(table_md)
    if args.check:
        if changed:
            print(
                "README.md is out of date with submodule state."
                " Run scripts/update_ip_table.py.",
                file=sys.stderr,
            )
            return 1
        return 0
    if changed:
        print("README.md IP table refreshed.")
    else:
        print("README.md IP table already up to date.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

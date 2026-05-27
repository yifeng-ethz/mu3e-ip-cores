#!/usr/bin/env python3
import csv
import json
import re
import subprocess
import time
from collections import OrderedDict
from pathlib import Path

OUT = Path(__file__).resolve().parent
LOCK = "/home/yifeng/.local/bin/swb_ring_lock"

HIST_BIN_BASE = 0x06800
HIST_CSR_BASE = 0x06900
INJ_BASE = 0x06C80
RUNCTL_BASE = 0x0C000

LEFT_BOUND = -1000
LEFT_WORD = 0xFFFFFC18
RIGHT_WORD = 0x00000C18
BIN_WIDTH = 16
N_BINS = 256

CONTROL_TYPE1_UP_FILTERED = 0x00011015
CONTROL_TYPE1_DOWN_FILTERED = 0x00021019
CONTROL_TYPE1_DOWN_UNFILTERED = 0x00020019

HIST_NAMES = [
    "UID", "META", "CONTROL", "LEFT_BOUND", "RIGHT_BOUND", "BIN_WIDTH",
    "KEY_LOC", "KEY_VALUE", "UNDERFLOW", "OVERFLOW", "INTERVAL_CFG",
    "BANK_STATUS", "PORT_STATUS", "TOTAL_HITS", "DROPPED_HITS",
    "COAL_STATUS", "SCRATCH", "LAST_INTERVAL_TOTAL_HITS",
    "LAST_INTERVAL_DROPPED_HITS",
]


class Runner:
    def __init__(self, log_path):
        self.log = Path(log_path).open("w")

    def close(self):
        self.log.close()

    def run(self, argv, check=True):
        stamp = time.strftime("%Y-%m-%dT%H:%M:%S%z")
        self.log.write(f"[{stamp}] $ {' '.join(argv)}\n")
        self.log.flush()
        proc = subprocess.run(argv, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        self.log.write(proc.stdout)
        self.log.write(f"[exit {proc.returncode}]\n")
        self.log.flush()
        if check and proc.returncode != 0:
            raise RuntimeError(f"command failed rc={proc.returncode}: {' '.join(argv)}")
        return proc.stdout, proc.returncode

    def rc(self, *args, check=True):
        return self.run([LOCK, "rc_tool", *args], check=check)

    def sc_write(self, addr, value):
        return self.run([LOCK, "sc_tool", "2", "write", f"0x{addr:05X}", f"0x{value & 0xFFFFFFFF:08X}", "--quiet"])

    def sc_read(self, addr, count):
        out, _ = self.run([LOCK, "sc_tool", "2", "read", f"0x{addr:05X}", str(count), "--quiet"])
        vals = [int(x, 16) for x in re.findall(r"payload\[\d+\]\s*=\s*(0x[0-9A-Fa-f]+)", out)]
        if len(vals) != count:
            raise RuntimeError(f"read 0x{addr:05X} expected {count} payloads, got {len(vals)}")
        return vals


def readback_write(r, addr, value, expected=None, mask=0xFFFFFFFF, label="csr"):
    if expected is None:
        expected = value
    for attempt in range(2):
        r.sc_write(addr, value)
        got = r.sc_read(addr, 1)[0]
        if (got & mask) == (expected & mask):
            r.log.write(f"RB OK {label}: got=0x{got:08X} expected=0x{expected:08X} mask=0x{mask:08X}\n")
            r.log.flush()
            return got
        r.log.write(f"RB MISMATCH {label} attempt={attempt + 1}: got=0x{got:08X} expected=0x{expected:08X} mask=0x{mask:08X}\n")
        r.log.flush()
    raise RuntimeError(f"readback mismatch for {label}")


def hist_csr(r):
    vals = r.sc_read(HIST_CSR_BASE, len(HIST_NAMES))
    return OrderedDict((name, vals[i]) for i in range(len(HIST_NAMES)))


def runctl_csr(r):
    vals = r.sc_read(RUNCTL_BASE, 21)
    return {
        "LAST_CMD_WORD": vals[4],
        "LAST_CMD": vals[4] & 0xFF,
        "RUN_NUMBER": vals[6],
        "RX_CMD_COUNT": vals[15],
        "RX_ERR_COUNT": vals[16],
        "ACK_SYMBOLS": vals[20],
    }


def write_bins_csv(path, bins):
    with path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["bin", "cycle_start", "cycle_center", "count"])
        for idx, count in enumerate(bins):
            start = LEFT_BOUND + idx * BIN_WIDTH
            writer.writerow([idx, start, start + BIN_WIDTH / 2, count])


def analyze_bins(bins):
    total = sum(bins)
    centers = [LEFT_BOUND + i * BIN_WIDTH + BIN_WIDTH / 2 for i in range(len(bins))]
    if total == 0:
        return {
            "total_counts": 0,
            "nonzero_bins": 0,
            "peak_bin": None,
            "peak_cycle": None,
            "peak_count": 0,
            "weighted_center": None,
            "fwhm_cycles": None,
            "classification": "NO_HITS",
            "top10": [],
        }

    peak_count = max(bins)
    peak_bin = bins.index(peak_count)
    weighted_center = sum(c * n for c, n in zip(centers, bins)) / total
    half = peak_count / 2.0
    above = [idx for idx, n in enumerate(bins) if n >= half]
    fwhm = (above[-1] - above[0] + 1) * BIN_WIDTH if above else None
    local_peaks = []
    for idx in range(1, len(bins) - 1):
        if bins[idx] > 0 and bins[idx] >= bins[idx - 1] and bins[idx] >= bins[idx + 1] and bins[idx] >= peak_count * 0.5:
            local_peaks.append(idx)

    if fwhm is None:
        classification = "NO_HITS"
    elif len(local_peaks) >= 2 and fwhm > 400:
        classification = "BROAD_MULTI_PEAK"
    elif fwhm <= 200:
        classification = "SHARP_DELTA"
    elif fwhm <= 400:
        classification = "NARROW"
    elif fwhm <= 700:
        classification = "MEDIUM"
    else:
        classification = "BROAD_MULTI_PEAK"

    top10 = sorted(((idx, centers[idx], bins[idx]) for idx in range(len(bins))), key=lambda x: x[2], reverse=True)[:10]
    return {
        "total_counts": total,
        "nonzero_bins": sum(1 for n in bins if n),
        "peak_bin": peak_bin,
        "peak_cycle": centers[peak_bin],
        "peak_count": peak_count,
        "weighted_center": weighted_center,
        "fwhm_cycles": fwhm,
        "classification": classification,
        "local_peaks_ge_halfmax": local_peaks,
        "top10": top10,
    }


def configure_hist(r, control_word, key_value, label):
    r.sc_write(HIST_BIN_BASE, 0)
    readback_write(r, HIST_CSR_BASE + 3, LEFT_WORD, label=f"{label} LEFT_BOUND -1000")
    readback_write(r, HIST_CSR_BASE + 4, RIGHT_WORD, label=f"{label} RIGHT_BOUND 3096")
    readback_write(r, HIST_CSR_BASE + 5, BIN_WIDTH, label=f"{label} BIN_WIDTH 16")
    readback_write(r, HIST_CSR_BASE + 7, key_value, label=f"{label} KEY_VALUE")
    readback_write(r, HIST_CSR_BASE + 2, control_word, expected=control_word & ~1, label=f"{label} CONTROL")


def configure_injector(r):
    readback_write(r, INJ_BASE + 3, 100, label="injector HEADER_DELAY")
    readback_write(r, INJ_BASE + 4, 1, label="injector HEADER_INTERVAL")
    readback_write(r, INJ_BASE + 5, 1, label="injector MULTIPLICITY")
    readback_write(r, INJ_BASE + 6, 0, label="injector HEADER_CH")
    readback_write(r, INJ_BASE + 8, 5, label="injector PULSE_HIGH")
    readback_write(r, INJ_BASE + 2, 1, label="injector MODE headersync")


def measure(r, name, run_number, control_word, key_value, seconds=8):
    outdir = OUT / name
    outdir.mkdir(exist_ok=True)
    r.rc("send", "stop-sequence", "--quiet", check=False)
    configure_hist(r, control_word, key_value, name)
    configure_injector(r)
    before = runctl_csr(r)
    configured = hist_csr(r)
    r.rc("send", "start-sequence", "--run", str(run_number), "--quiet")
    time.sleep(1)
    after_start = runctl_csr(r)
    time.sleep(max(0, seconds - 1))
    active_hist = hist_csr(r)
    r.rc("send", "stop-sequence", "--quiet", check=False)
    time.sleep(0.5)
    after_stop = runctl_csr(r)
    post_hist = hist_csr(r)
    bins = r.sc_read(HIST_BIN_BASE, N_BINS)
    write_bins_csv(outdir / "bins.csv", bins)
    analysis = analyze_bins(bins)
    result = {
        "name": name,
        "run_number": run_number,
        "control_word": f"0x{control_word:08X}",
        "key_value": f"0x{key_value:08X}",
        "runctl_before": before,
        "runctl_after_start": after_start,
        "runctl_after_stop": after_stop,
        "hist_configured": dict(configured),
        "hist_active_after_8s": dict(active_hist),
        "hist_post_stop": dict(post_hist),
        "analysis": analysis,
        "bins_csv": str(outdir / "bins.csv"),
    }
    (outdir / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


def write_report(results, down_bank_smoke):
    lines = []
    lines.append("# Per-ASIC Histogram Verification After Freerun STP\n\n")
    lines.append("## Canonical Histogram Config\n")
    lines.append("- Range: `LEFT_BOUND=-1000`, `RIGHT_BOUND=3096`, `BIN_WIDTH=16`, `N_BINS=256`.\n")
    lines.append("- Injector: mode=1 header-sync, header_interval=1, multiplicity=1, header_delay=100, header_ch=0, pulse_high=5.\n")
    lines.append("- Filter: `KEY_VALUE = ASIC_INDEX << 16`, filter enabled.\n\n")
    lines.append("## Per-ASIC Results\n")
    lines.append("| ASIC | Bank | KEY_VALUE | Peak cycle | Weighted center | FWHM cycles | Total counts | Active TOTAL_HITS | Active LAST_INTERVAL_TOTAL_HITS | Classification |\n")
    lines.append("|---:|---|---:|---:|---:|---:|---:|---:|---:|---|\n")
    for item in results:
        a = item["analysis"]
        hist = item["hist_active_after_8s"]
        peak = "NA" if a["peak_cycle"] is None else f"{a['peak_cycle']:.1f}"
        center = "NA" if a["weighted_center"] is None else f"{a['weighted_center']:.1f}"
        fwhm = "NA" if a["fwhm_cycles"] is None else str(a["fwhm_cycles"])
        lines.append(
            f"| {item['asic']} | {item['bank']} | `{item['key_value']}` | {peak} | {center} | {fwhm} | "
            f"{a['total_counts']} | {hist['TOTAL_HITS']} | {hist['LAST_INTERVAL_TOTAL_HITS']} | {a['classification']} |\n"
        )
    lines.append("\n## Type1-Down No-Filter Smoke\n")
    if down_bank_smoke is None:
        lines.append("Not run; all Type1-down filtered measurements produced nonzero bins.\n")
    else:
        a = down_bank_smoke["analysis"]
        hist = down_bank_smoke["hist_active_after_8s"]
        verdict = "BANK_SILENT" if a["total_counts"] == 0 and hist["TOTAL_HITS"] == 0 else "BANK_HAS_TRAFFIC"
        lines.append(f"- Control: `{down_bank_smoke['control_word']}` with filter disabled (`KEY_VALUE={down_bank_smoke['key_value']}`).\n")
        lines.append(f"- TOTAL_HITS active: `{hist['TOTAL_HITS']}`, LAST_INTERVAL_TOTAL_HITS active: `{hist['LAST_INTERVAL_TOTAL_HITS']}`, bin total: `{a['total_counts']}`.\n")
        lines.append(f"- Verdict: `{verdict}`.\n")

    nonzero = [item for item in results if item["analysis"]["total_counts"] > 0]
    down_zero = [item for item in results if item["bank"] == "Type1-down" and item["analysis"]["total_counts"] == 0]
    if len(nonzero) == 8:
        overall = "ALL_8_FILTERS_WORK"
    elif len(nonzero) >= 4 and len(down_zero) == 4:
        overall = "TYPE1_UP_OK_TYPE1_DOWN_SILENT"
    else:
        overall = "PARTIAL"
    lines.append("\n## Overall Verdict\n")
    lines.append(f"`{overall}`\n")
    (OUT / "per_asic_hist_REPORT.md").write_text("".join(lines))


def main():
    r = Runner(OUT / "per_asic_hist_transcript.log")
    results = []
    down_bank_smoke = None
    try:
        for asic in range(8):
            if asic < 4:
                bank = "Type1-up"
                control = CONTROL_TYPE1_UP_FILTERED
            else:
                bank = "Type1-down"
                control = CONTROL_TYPE1_DOWN_FILTERED
            key_value = asic << 16
            result = measure(r, f"ASIC{asic}", 9100 + asic, control, key_value)
            result["asic"] = asic
            result["bank"] = bank
            result["key_value"] = f"0x{key_value:08X}"
            results.append(result)
            print(
                f"ASIC{asic} {bank} key=0x{key_value:08X} total={result['analysis']['total_counts']} "
                f"peak={result['analysis']['peak_cycle']} fwhm={result['analysis']['fwhm_cycles']} "
                f"class={result['analysis']['classification']}",
                flush=True,
            )

        if any(item["bank"] == "Type1-down" and item["analysis"]["total_counts"] == 0 for item in results):
            down_bank_smoke = measure(r, "TYPE1_DOWN_NOFILTER", 9199, CONTROL_TYPE1_DOWN_UNFILTERED, 0)
            print(
                f"TYPE1_DOWN_NOFILTER total={down_bank_smoke['analysis']['total_counts']} "
                f"active_TOTAL_HITS={down_bank_smoke['hist_active_after_8s']['TOTAL_HITS']}",
                flush=True,
            )
        write_report(results, down_bank_smoke)
        (OUT / "per_asic_hist_results.json").write_text(json.dumps({"results": results, "type1_down_nofilter": down_bank_smoke}, indent=2) + "\n")
    finally:
        try:
            r.rc("send", "stop-sequence", "--quiet", check=False)
        except Exception as exc:
            r.log.write(f"final stop-sequence failed: {exc}\n")
        r.close()


if __name__ == "__main__":
    main()

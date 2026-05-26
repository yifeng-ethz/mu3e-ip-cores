#!/usr/bin/env python3
import re
import subprocess
import time
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = Path("/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_main_20260518")
BUILD = ROOT / "firmware_builds/systems/260518-feb-ok/syn/board_projects/fe_scifi_feb_v3"
STP_FILE = BUILD / "mutrig_cfg_lvds.stp"
LOCK = "/home/yifeng/.local/bin/swb_ring_lock"
CONFIG_SCRIPT = Path("/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_phase6_closure_20260430/firmware_builds/systems/system_20260427_testplanphase5/script/configure_mutrig_from_xml_v4addr.py")
SMB3_XML = Path("/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/trash_bin/good_ribbon_0/config_smb3_tdc.txt")
SMB5_XML = Path("/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/trash_bin/good_ribbon_0/config_smb5_tdc.txt")

HIST_BIN_BASE = 0x06800
HIST_CSR_BASE = 0x06900
INJ_BASE = 0x06C80


class Runner:
    def __init__(self, log_path):
        self.log = Path(log_path).open("w")

    def close(self):
        self.log.close()

    def run(self, argv, check=True, cwd=ROOT):
        stamp = time.strftime("%Y-%m-%dT%H:%M:%S%z")
        self.log.write(f"[{stamp}] $ {' '.join(str(a) for a in argv)}\n")
        self.log.flush()
        proc = subprocess.run(
            [str(a) for a in argv],
            cwd=str(cwd),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        self.log.write(proc.stdout)
        self.log.write(f"[exit {proc.returncode}]\n")
        self.log.flush()
        if check and proc.returncode != 0:
            raise RuntimeError(f"command failed rc={proc.returncode}: {' '.join(str(a) for a in argv)}")
        return proc.stdout, proc.returncode

    def rc(self, *args, check=True):
        return self.run([LOCK, "rc_tool", *args], check=check)

    def sc_write(self, addr, value, check=True):
        return self.run([LOCK, "sc_tool", "2", "write", f"0x{addr:05X}", f"0x{value & 0xFFFFFFFF:08X}", "--quiet"], check=check)

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


def recover_pcie_if_needed(r):
    if Path("/dev/mudaq0").exists():
        r.log.write("/dev/mudaq0 present\n")
        r.log.flush()
        return
    r.run(["sudo", "-n", "/usr/local/sbin/mudaq_recover_pcie"])
    if not Path("/dev/mudaq0").exists():
        raise RuntimeError("/dev/mudaq0 still missing after one recover_pcie")


def configure_mutrig(r):
    cmd = [
        "python3", CONFIG_SCRIPT,
        "--smb3-xml", SMB3_XML,
        "--smb5-xml", SMB5_XML,
        "--asics", "0,1,2,3,4,5,6,7",
        "--channel-enable-mask", "0xFFFFFFFF",
        "--tdctest-channel-mask", "0xFFFFFFFF",
        "--cml-start-value", "0",
        "--cml-flush-value", "8",
        "--cml-final-value", "0",
        "--cml-flush-after-config",
        "--cml-flush-set-cml-sc-zero",
        "--set-channel", "recv_all=1",
        "--set-tdc", "0:vnhitlogic=40",
        "--set-tdc", "2:vncnt=40",
        "--set-tdc", "2:vnvcodelay=30",
        "--set-tdc", "2:vnhitlogic=30",
        "--set-tdc", "3:vncnt=35",
        "--set-tdc", "3:vnvcodelay=12",
        "--set-tdc", "3:vnhitlogic=25",
        "--set-tdc", "7:vncnt=30",
        "--set-tdc", "7:vnvcodelay=14",
        "--set-tdc", "7:vnhitlogic=40",
        "--allow-idle-after-config",
        "--bsp", "toolkits/fe_scifi/system_console/lib/mutrig_controller_bsp.tcl",
        "--timeout-s", "60",
    ]
    out, _ = r.run(cmd)
    (OUT / "configure_mutrig.log").write_text(out)
    if "SUMMARY pass=24 fail=0" not in out:
        raise RuntimeError("configure_mutrig did not report SUMMARY pass=24 fail=0")


def configure_injector(r):
    readback_write(r, INJ_BASE + 3, 100, label="injector HEADER_DELAY")
    readback_write(r, INJ_BASE + 4, 1, label="injector HEADER_INTERVAL")
    readback_write(r, INJ_BASE + 5, 1, label="injector MULTIPLICITY")
    readback_write(r, INJ_BASE + 6, 0, label="injector HEADER_CH")
    readback_write(r, INJ_BASE + 8, 5, label="injector PULSE_HIGH")
    readback_write(r, INJ_BASE + 2, 1, label="injector MODE headersync")


def configure_hist_asic0(r):
    r.sc_write(HIST_BIN_BASE, 0)
    readback_write(r, HIST_CSR_BASE + 3, 0xFFFFFC18, label="hist LEFT_BOUND -1000")
    readback_write(r, HIST_CSR_BASE + 4, 0x00000C18, label="hist RIGHT_BOUND 3096")
    readback_write(r, HIST_CSR_BASE + 5, 16, label="hist BIN_WIDTH 16")
    readback_write(r, HIST_CSR_BASE + 7, 0, label="hist KEY_VALUE ASIC0")
    readback_write(r, HIST_CSR_BASE + 2, 0x00011015, expected=0x00011014, label="hist CONTROL Type1-up filtered")


def run_stp_capture(r):
    out_csv = OUT / "mts_debug_freerun_capture.csv"
    cmd = [
        "quartus_stp", "-t", OUT / "stp_acquire_instance.tcl",
        "USB-BlasterII", "5AG", STP_FILE,
        "mts_debug", "mts_debug", "mts_debug_trig",
        out_csv, "mts_debug_freerun_log", "30",
    ]
    r.run(cmd, cwd=BUILD)
    return out_csv


def main():
    r = Runner(OUT / "setup_for_hist_capture_transcript.log")
    try:
        recover_pcie_if_needed(r)
        r.rc("send", "stop-sequence", "--quiet", check=False)
        r.rc("status", "--quiet", check=False)
        r.sc_write(0x04006, 0x00000100)
        time.sleep(0.1)
        configure_mutrig(r)
        dpalock = r.sc_read(0x0400E, 1)[0]
        if dpalock != 0x000001FF:
            raise RuntimeError(f"PHY_DPALOCK expected 0x000001FF, got 0x{dpalock:08X}")
        configure_injector(r)
        configure_hist_asic0(r)
        r.rc("send", "start-sequence", "--run", "9000", "--quiet")
        time.sleep(2)
        out_csv = run_stp_capture(r)
        r.log.write(f"STP CSV: {out_csv}\n")
        r.log.flush()
    finally:
        try:
            r.rc("send", "stop-sequence", "--quiet", check=False)
        except Exception as exc:
            r.log.write(f"final stop-sequence failed: {exc}\n")
        r.close()


if __name__ == "__main__":
    main()

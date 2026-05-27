#!/usr/bin/env python3
"""#63 real-MuTRiG path rewire for scifi_datapath_system_v4.qsys (source-of-truth edit).

All instances live on the single mu3e_lvds_controller_0.outclock domain -> no new CDC.

A) LVDS -> din direct (x8):
   repurpose  decodedK -> decoded_lane_mux_K.in0   ==>  decodedK -> mutrig_datapath_subsystem_K.decoded_din
   then delete the now-dead decoded_lane_mux_K + decoded_lane_fifo_K instances and their connections.
B) run_ctrl fanout (x8):
   add  run_control_splitter.out{2,3,4,5,8,9,10,11} -> mutrig_datapath_subsystem_{0..7}.run_ctrl
C) remove arb supercore:
   repurpose  arb.selected_out_K -> hist_type0_laneK_tap.in  ==>  merger_K.out -> hist_type0_laneK_tap.in
   delete  merger_K.out -> arb.emu_in_K  and the arb_hit_type0_supercore_0 instance + its connections.

Usage: python3 patch_scifi_datapath_v4_realpath_rewire.py <path-to.qsys>
Edits in place. Idempotent-ish: re-running detects already-applied edits and aborts.
"""
import re, sys

DEAD = re.compile(r'(decoded_lane_mux|decoded_lane_fifo|arb_hit_type0_supercore)_\d+')
RUNCTL_MAP = [(2,0),(3,1),(4,2),(5,3),(8,4),(9,5),(10,6),(11,7)]

def main(path):
    txt = open(path).read()
    orig = txt

    # ---- A: repurpose decodedK -> mux.in0  ==>  decodedK -> mutrig_K.decoded_din
    a = 0
    for k in range(8):
        old = f'end="decoded_lane_mux_{k}.in0"'
        new = f'end="mutrig_datapath_subsystem_{k}.decoded_din"'
        if old in txt:
            txt = txt.replace(old, new); a += 1
    # ---- C-repurpose: arb.selected_out_K -> hist tap  ==>  merger_K.out -> hist tap
    c = 0
    for k in range(8):
        old = f'start="arb_hit_type0_supercore_0.selected_out_{k}"'
        new = f'start="merger_{k}.out"'
        if old in txt:
            txt = txt.replace(old, new); c += 1

    # ---- delete connection blocks referencing any DEAD instance (post-repurpose)
    # [^>]*? bounds the start-tag scan so it cannot cross into inner <parameter/>
    # children (avalon connections carry baseAddress params with their own '/>').
    conn_re = re.compile(r'[ \t]*<connection\b[^>]*?(?:/>|>.*?</connection>)\s*\n', re.DOTALL)
    removed_conn = 0
    def drop_conn(m):
        nonlocal removed_conn
        if DEAD.search(m.group(0)):
            removed_conn += 1
            return ''
        return m.group(0)
    txt = conn_re.sub(drop_conn, txt)

    # ---- delete <module> blocks for DEAD instances
    mod_re = re.compile(r'[ \t]*<module\b.*?</module>\s*\n', re.DOTALL)
    removed_mod = 0
    def drop_mod(m):
        nonlocal removed_mod
        nm = re.search(r'name="([^"]*)"', m.group(0))
        if nm and DEAD.fullmatch(nm.group(1)):
            removed_mod += 1
            return ''
        return m.group(0)
    txt = mod_re.sub(drop_mod, txt)

    # ---- delete bonusData GUI-layout 'element <dead> { ... }' sub-blocks
    elem_re = re.compile(
        r'(?m)^([ \t]*)element (?:decoded_lane_mux|decoded_lane_fifo|arb_hit_type0_supercore)_\d+\s*\n'
        r'\1\{.*?\n\1\}\n', re.DOTALL)
    txt, removed_elem = elem_re.subn('', txt)

    # ---- B: add run_ctrl connections after the run_control_splitter.out0 block
    anchor = re.search(r'([ \t]*<connection\b[^<]*?start="run_control_splitter\.out0".*?/>\s*\n)', txt, re.DOTALL)
    if not anchor:
        sys.exit("ERROR: run_control_splitter.out0 anchor not found")
    blocks = ""
    for (n,k) in RUNCTL_MAP:
        if f'end="mutrig_datapath_subsystem_{k}.run_ctrl"' in txt:
            continue
        blocks += (' <connection\n   kind="avalon_streaming"\n   version="18.1"\n'
                   f'   start="run_control_splitter.out{n}"\n'
                   f'   end="mutrig_datapath_subsystem_{k}.run_ctrl" />\n')
    txt = txt[:anchor.end()] + blocks + txt[anchor.end():]

    # ---- sanity: no DEAD reference must survive
    leftover = sorted(set(DEAD.findall(txt)))
    rem = [m.group(0) for m in DEAD.finditer(txt)]
    if rem:
        sys.exit(f"ERROR: {len(rem)} dead references survive: {set(rem)}")

    if txt == orig:
        sys.exit("no changes (already applied?)")
    open(path,'w').write(txt)
    print(f"A repurpose decoded_din: {a}/8")
    print(f"C repurpose merger->hist: {c}/8")
    print(f"removed connections (dead): {removed_conn}")
    print(f"removed modules (dead):     {removed_mod}")
    print(f"added run_ctrl connections: {blocks.count('<connection')}")
    print(f"-> wrote {path}")

if __name__ == "__main__":
    main(sys.argv[1])

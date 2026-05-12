#!/usr/bin/env python3
"""
phase4_5_html_normalize.py -- inject hits-per-ms rate normalization into
PHASE4_5_SWEEP_REPORT.html files.

Usage:
  python3 phase4_5_html_normalize.py <html_file>

The script reads sim_counters.json and counters.json from the evidence
directories referenced in the HTML, computes normalized rates
(hits per millisecond), then rewrites the HTML in-place (moving the
original aside as .bak).

Hard rules:
  - Never use rm.
  - ASCII only in body text.
  - Do not touch phase4_5_sweep.py or phase4_5_longsoak.py.
  - Do not write new files other than the helper itself and the updated HTML.

Run window defaults (used if JSON is missing):
  sim_run_ms  : 10.0   (1,250,000 cycles @ 125 MHz = 10 ms)
  board_run_ms: 4000.0 (4 s interval_seconds)
"""

import json
import os
import re
import shutil
import sys

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

REPO_ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..")
)
SIM_EVIDENCE_REL = os.path.join(
    "firmware_builds", "systems",
    "system_20260504_emulator_type0",
    "tb_int", "feb_swb_corun", "sim_evidence"
)
BOARD_EVIDENCE_MAP = {
    # dualport cross-validation report
    "v3_pretest-260511-emulator-type0-260512":
        os.path.join(
            "firmware_builds", "systems",
            "v3_pretest-260511-emutype0-dualport-260512",
            "sweep_evidence"
        ),
    # standalone dualport report (no sim counters -- board-only)
    "v3_pretest-260511-emutype0-dualport-260512":
        os.path.join(
            "firmware_builds", "systems",
            "v3_pretest-260511-emutype0-dualport-260512",
            "sweep_evidence"
        ),
}

DEFAULT_SIM_MS   = 10.0    # 1,250,000 cycles @ 125 MHz
DEFAULT_BOARD_MS = 4000.0  # 4 s board interval


# ---------------------------------------------------------------------------
# Evidence loading helpers
# ---------------------------------------------------------------------------

def _load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return None


def load_row_data(row_id, sim_evdir, board_evdir):
    """Return (sim_total, sim_ms, board_total, board_ms) for a row."""
    sim_total  = 0
    sim_ms     = DEFAULT_SIM_MS
    board_total= 0
    board_ms   = DEFAULT_BOARD_MS

    # sim
    sim_f = os.path.join(sim_evdir, row_id, "sim_counters.json")
    sim_j = _load_json(sim_f)
    if sim_j:
        sim_total = sim_j.get("sim", {}).get("sim_total_hits", 0)
        cyc   = sim_j.get("sim", {}).get("run_cycles", 0)
        clkhz = sim_j.get("sim", {}).get("clock_hz", 125_000_000)
        if cyc and clkhz:
            sim_ms = cyc / clkhz * 1000.0

    # board
    board_f = os.path.join(board_evdir, row_id, "counters.json")
    board_j = _load_json(board_f)
    if board_j:
        board_total = board_j.get("verdict", {}).get("total_hits_csr13", 0) or 0
        iv_s = board_j.get("row", {}).get("interval_seconds")
        if iv_s:
            board_ms = float(iv_s) * 1000.0

    return sim_total, sim_ms, board_total, board_ms


def compute_rates(sim_total, sim_ms, board_total, board_ms):
    sim_rate   = sim_total   / sim_ms   if sim_ms   > 0 else 0.0
    board_rate = board_total / board_ms if board_ms > 0 else 0.0
    if sim_rate > 0:
        delta_pct = (board_rate - sim_rate) / sim_rate * 100.0
        delta_str = "{:+.1f}%".format(delta_pct)
    elif board_rate == 0:
        delta_str = "n/a"
    else:
        delta_str = "+inf"
    return sim_rate, board_rate, delta_str


def fmt_rate(r):
    """Format hits/ms to 2 decimal places."""
    return "{:.2f}".format(r)


def fmt_num(n):
    """Format integer with thousands separators."""
    return "{:,}".format(int(n))


# ---------------------------------------------------------------------------
# Run Window Normalization section (inserted after Executive Summary)
# ---------------------------------------------------------------------------

NORM_SECTION = """\
<section><h2 id="normalization">Run Window Normalization</h2>
<div class="prose">
<p>Sim and board run the same emulator configuration but with very different
RUN windows: sim defaults to <strong>10 ms</strong> (1,250,000 cycles at 125&nbsp;MHz)
while board defaults to <strong>4000 ms</strong> (4&nbsp;s). Absolute hit counts therefore
diverge by approximately 400x even when the per-channel rate is identical.</p>
<p>The <strong>&#916;% rate</strong> column normalizes to <strong>hits per millisecond</strong>:</p>
<pre><code>sim_hits_per_ms   = sim_total_hits / sim_run_ms
board_hits_per_ms = board_total_hits / board_run_ms
delta_pct_rate    = (board_rate - sim_rate) / sim_rate * 100</code></pre>
<p>A &#916;% rate near zero means sim and board agree on the per-channel hit rate.
Large &#916;% values indicate real behavioral divergence (FIFO saturation,
CSR-write race, lane-admit failure, etc.) and are the only actionable comparison
across mismatched run windows.</p>
<p>A new sim convention (RUNNING stage = 1&nbsp;ms sharp) is being adopted to make
direct comparisons even cleaner; once new sim evidence at 1&nbsp;ms RUNNING lands,
this report will refresh automatically. Long-soak runs (10&nbsp;s+) are flagged
explicitly in their row notes.</p>
</div>
</section>
"""


# ---------------------------------------------------------------------------
# Master table normalization (emulator-type0 cross-validation report)
# ---------------------------------------------------------------------------

MASTER_TABLE_OLD_HEADER = (
    '<th>sim_total</th><th>board_csr13</th><th>delta</th>'
)
MASTER_TABLE_NEW_HEADER = (
    '<th>sim_total <span style="color:#6b6b6b;font-weight:400;font-size:0.82em;">(raw)</span></th>'
    '<th>sim_ms</th>'
    '<th>sim hits/ms</th>'
    '<th>board_total <span style="color:#6b6b6b;font-weight:400;font-size:0.82em;">(raw)</span></th>'
    '<th>board_ms</th>'
    '<th>board hits/ms</th>'
    '<th>&#916;% rate</th>'
)


def _master_row_replacement(m, sim_total, sim_ms, board_total, board_ms,
                            sim_rate, board_rate, delta_str):
    """Build the replacement for one master table row."""
    # m is a re.Match on the original tr; we keep sim/board pill columns untouched
    # by reconstructing only the data cells we need to replace.
    # The original row ends with:
    #   <td ...>sim_total</td><td ...>board_csr13</td><td ...>delta pill</td>
    # We splice in the 7 new cells at those positions.
    # The match group(0) is used to determine cell positions.
    old = m.group(0)

    # Pill HTML - preserve from original (last two <span class="pill"> cells)
    sim_pill_m   = re.search(r'<span class="pill (pass|fail)"[^>]*>PASS|FAIL</span>', old)
    # We'll keep the sim and board pill tds as-is; just replace the 3 data tds.
    # Locate the three data-value tds we need to replace (sim_total, board_csr13, delta)
    # They appear after the axis/lane/channel/rate/mode columns.
    # Strategy: replace from the sim_total td up to (and including) the delta td.
    data_pat = re.compile(
        r'(<td[^>]*>(?:<span[^>]*>)?)'  # td opening (with optional span)
        r'[^<]*'                          # number text
        r'(?:</span>)?</td>'              # close
        r'(<td[^>]*>(?:<span[^>]*>)?)'
        r'[^<]*'
        r'(?:</span>)?</td>'
        r'(<td[^>]*>)'
        r'[^<]*(?:<[^/][^>]*>[^<]*</[^>]+>)*'  # delta text with pill
        r'</td>'
    )
    # Simpler: just find the three numeric tds by position after mode column
    # The row structure is:
    # <td>idx</td><td><a>row_id</a></td><td>axis</td><td>lane</td><td>channel</td><td>rate</td><td>mode</td>
    # <td>sim_total</td><td>board_csr13</td><td>delta</td>
    # <td>sim_hist_sum</td><td>board_hist_sum</td><td>sim_pill</td><td>board_pill</td><td>thumbs</td>
    # Split by closing </td> and count
    parts = old.split('</td>')
    # Find the sim_total td (index 7 in 0-based split)
    # Rebuild: replace indices 7,8,9 with new content
    # Count: 0=idx 1=row_id 2=axis 3=lane 4=channel 5=rate 6=mode 7=sim_total 8=board 9=delta
    num_leading = 7  # tds before sim_total

    tnums = '<td style="font-variant-numeric:tabular-nums;">'
    sep   = '</td>'

    new_cells = [
        '{}{}{}'.format(tnums, fmt_num(sim_total), sep),
        '{}{:.1f}{}'.format(tnums, sim_ms, sep),
        '{}{}{}'.format(tnums, fmt_rate(sim_rate), sep),
        '{}{}{}'.format(tnums, fmt_num(board_total), sep),
        '{}{:.1f}{}'.format(tnums, board_ms, sep),
        '{}{}{}'.format(tnums, fmt_rate(board_rate), sep),
        '{}{}{}'.format(tnums, delta_str, sep),
    ]

    rebuilt = sep.join(parts[:num_leading]) + sep
    rebuilt += ''.join(new_cells)
    # keep the rest: hist_sum columns + pills + thumbnails
    rebuilt += sep.join(parts[num_leading + 3:])  # skip old 3 cells (7,8,9)
    return rebuilt


def patch_master_table_row(html, row_id, sim_total, sim_ms,
                           board_total, board_ms, sim_rate, board_rate,
                           delta_str):
    """Replace the 3 old data columns in the master-table row for row_id."""
    # Match the full <tr>...</tr> that contains this row_id href anchor.
    # The rows are on single lines in the generated HTML.
    pattern = re.compile(
        r'(<tr><td>\d+</td><td><a href="[^"]*' + re.escape(row_id) + r'[^"]*">'
        r'<code>' + re.escape(row_id) + r'</code></a></td>)'  # group1: leading
        r'(<td[^>]*><code>[^<]*</code></td>)'                   # group2: axis
        r'(<td[^>]*><code>[^<]*</code></td>)'                   # group3: lane
        r'(<td[^>]*><code>[^<]*</code></td>)'                   # group4: channel
        r'(<td[^>]*><code>[^<]*</code></td>)'                   # group5: rate
        r'(<td[^>]*><code>[^<]*</code></td>)'                   # group6: mode
        r'<td[^>]*>[^<]*</td>'                                  # sim_total (old)
        r'<td[^>]*>[^<]*</td>'                                  # board_csr13 (old)
        r'<td[^>]*>[^<]*(?:<span[^>]*>[^<]*</span>)?</td>'     # delta (old)
        r'(.*?</tr>)',                                          # group7: remainder
        re.DOTALL
    )

    tnums = '<td style="font-variant-numeric:tabular-nums;">'
    new_cells = (
        '{}{}</td>'.format(tnums, fmt_num(sim_total)) +
        '{}{:.1f}</td>'.format(tnums, sim_ms) +
        '{}{}</td>'.format(tnums, fmt_rate(sim_rate)) +
        '{}{}</td>'.format(tnums, fmt_num(board_total)) +
        '{}{:.1f}</td>'.format(tnums, board_ms) +
        '{}{}</td>'.format(tnums, fmt_rate(board_rate)) +
        '{}{}</td>'.format(tnums, delta_str)
    )

    replacement = (r'\1\2\3\4\5\6' + new_cells + r'\7')
    html_new, n = pattern.subn(replacement, html)
    if n == 0:
        # Fallback: simpler pattern matching just the three value cells
        pattern2 = re.compile(
            r'(href="#row-' + re.escape(row_id) + r'">'
            r'<code>' + re.escape(row_id) + r'</code></a></td>'
            r'(?:<td[^>]*><code>[^<]*</code></td>){5})'   # 5 meta cols
            r'(<td[^>]*>[^<]*</td>)'    # sim_total old
            r'(<td[^>]*>[^<]*</td>)'    # board old
            r'(<td[^>]*>[^<]*(?:<span[^>]*>[^<]*</span>)?</td>)',  # delta old
            re.DOTALL
        )
        html_new, n2 = pattern2.subn(
            r'\1' + new_cells, html
        )
    return html_new


# ---------------------------------------------------------------------------
# Deep-dive counter comparison table patching
# ---------------------------------------------------------------------------

COUNTER_TABLE_OLD_HEADER = (
    '<thead><tr><th>Field</th><th>Sim</th><th>Board</th><th>Delta</th></tr></thead>'
)
COUNTER_TABLE_NEW_HEADER = (
    '<thead><tr>'
    '<th>Field</th>'
    '<th>Sim (raw)</th>'
    '<th>Sim hits/ms</th>'
    '<th>Sim ms</th>'
    '<th>Board (raw)</th>'
    '<th>Board hits/ms</th>'
    '<th>Board ms</th>'
    '<th>Delta (raw)</th>'
    '<th>&#916;% rate</th>'
    '</tr></thead>'
)


def _build_counter_cmp_row(field, sim_val, sim_rate_str, sim_ms_str,
                            board_val, board_rate_str, board_ms_str,
                            delta_raw, delta_rate_str):
    """Build one <tr> for the counter comparison table (9 columns)."""
    tn = ' style="font-variant-numeric:tabular-nums;"'
    return (
        '<tr>'
        '<th>{}</th>'
        '<td{}>{}</td>'
        '<td{}>{}</td>'
        '<td{}>{}</td>'
        '<td{}>{}</td>'
        '<td{}>{}</td>'
        '<td{}>{}</td>'
        '<td{}>{}</td>'
        '<td{}>{}</td>'
        '</tr>'
    ).format(
        field,
        tn, sim_val,
        tn, sim_rate_str,
        tn, sim_ms_str,
        tn, board_val,
        tn, board_rate_str,
        tn, board_ms_str,
        tn, delta_raw,
        tn, delta_rate_str,
    )


def patch_counter_table(section_html, sim_total, sim_ms,
                        board_total, board_ms, sim_rate, board_rate,
                        delta_str, sim_hist_sum, board_hist_sum,
                        sim_csr17, board_csr17):
    """
    Replace the counter comparison table inside one row-section fragment.
    Returns updated HTML.
    """
    # Replace header
    out = section_html.replace(
        COUNTER_TABLE_OLD_HEADER, COUNTER_TABLE_NEW_HEADER
    )

    # Now patch each tbody row. The rows are:
    # 1) total hits (sim_total / csr13)
    # 2) hist_bin sum (256 bins)
    # 3) last_interval_total (csr17)
    # 4) arb selected_count (sum of 8 lanes)  -- no rate normalization
    # 5) UNDERFLOW / OVERFLOW / DROPPED        -- no rate normalization

    # Row 1: total hits
    def _make_rate_cells(sim_v, brd_v, s_ms, b_ms):
        s_r = sim_v / s_ms if s_ms > 0 else 0.0
        b_r = brd_v / b_ms if b_ms > 0 else 0.0
        if s_r > 0:
            dp = (b_r - s_r) / s_r * 100
            dp_str = '{:+.1f}%'.format(dp)
        elif b_r == 0:
            dp_str = 'n/a'
        else:
            dp_str = '+inf'
        return fmt_rate(s_r), fmt_rate(b_r), dp_str

    # Patch row 1: total hits
    sr1, br1, dr1 = _make_rate_cells(sim_total, board_total, sim_ms, board_ms)
    raw_delta_hits = board_total - sim_total
    raw_pct = '{:+,} ({:+.1f}%)'.format(
        raw_delta_hits,
        (raw_delta_hits / sim_total * 100) if sim_total else float('inf')
    )
    row1_new = _build_counter_cmp_row(
        'total hits (sim_total / csr13)',
        fmt_num(sim_total), sr1, '{:.1f}'.format(sim_ms),
        fmt_num(board_total), br1, '{:.1f}'.format(board_ms),
        raw_pct, dr1
    )

    # Patch row 2: hist_bin sum
    sr2, br2, dr2 = _make_rate_cells(sim_hist_sum, board_hist_sum, sim_ms, board_ms)
    raw_delta_hist = board_hist_sum - sim_hist_sum
    raw_pct2 = '{:+,} ({:+.1f}%)'.format(
        raw_delta_hist,
        (raw_delta_hist / sim_hist_sum * 100) if sim_hist_sum else float('inf')
    )
    row2_new = _build_counter_cmp_row(
        'hist_bin sum (256 bins)',
        fmt_num(sim_hist_sum), sr2, '{:.1f}'.format(sim_ms),
        fmt_num(board_hist_sum), br2, '{:.1f}'.format(board_ms),
        raw_pct2, dr2
    )

    # Patch row 3: last_interval_total (csr17) -- no rate norm (snapshot timing)
    raw_delta_csr17 = board_csr17 - sim_csr17
    raw_pct3 = '{:+,} ({})'.format(
        raw_delta_csr17,
        '{:+.1f}%'.format(raw_delta_csr17 / sim_csr17 * 100) if sim_csr17 else '0%'
    )
    row3_new = _build_counter_cmp_row(
        'last_interval_total (csr17)',
        fmt_num(sim_csr17), '-', '-',
        fmt_num(board_csr17), '-', '-',
        raw_pct3, 'n/a (snapshot)'
    )

    # Replace the three rows in the tbody using regex
    # Match pattern for original 4-column rows (Field/Sim/Board/Delta)
    def _re_row(field_text_pat):
        return re.compile(
            r'<tr><th>' + field_text_pat + r'</th>'
            r'<td[^>]*>[^<]*</td>'   # sim
            r'<td[^>]*>[^<]*</td>'   # board
            r'<td[^>]*>.*?</td>'     # delta (may contain nested tags)
            r'</tr>',
            re.DOTALL
        )

    out = _re_row(r'total hits \(sim_total / csr13\)').sub(row1_new, out)
    out = _re_row(r'hist_bin sum \(256 bins\)').sub(row2_new, out)
    out = _re_row(r'last_interval_total \(csr17\)').sub(row3_new, out)

    # For the remaining rows (arb selected_count, UNDERFLOW/OVERFLOW/DROPPED)
    # expand the 4-column structure to 9 columns by adding empty placeholders
    def _expand_row_4to9(m):
        orig = m.group(0)
        # Extract the 4 cells: th, td, td, td
        cells = re.findall(r'<t[hd][^>]*>(.*?)</t[hd]>', orig, re.DOTALL)
        if len(cells) < 4:
            return orig
        tn = ' style="font-variant-numeric:tabular-nums;"'
        return (
            '<tr>'
            '<th>{}</th>'
            '<td{}>{}</td>'
            '<td{}>-</td>'
            '<td{}>-</td>'
            '<td{}>{}</td>'
            '<td{}>-</td>'
            '<td{}>-</td>'
            '<td{}>{}</td>'
            '<td{}>-</td>'
            '</tr>'
        ).format(
            cells[0],
            tn, cells[1],
            tn, tn,
            tn, cells[2],
            tn, tn,
            tn, cells[3],
            tn
        )

    # Rows that still have 4 columns (arb, UNDER/OVER/DROP)
    remaining_4col = re.compile(
        r'<tr><th>(arb selected_count|UNDERFLOW)[^<]*</th>'
        r'<td[^>]*>[^<]*</td>'
        r'<td[^>]*>[^<]*</td>'
        r'<td[^>]*>.*?</td>'
        r'</tr>',
        re.DOTALL
    )
    out = remaining_4col.sub(_expand_row_4to9, out)

    return out


# ---------------------------------------------------------------------------
# Main patching logic
# ---------------------------------------------------------------------------

def determine_build_key(html_path):
    """Return the key into BOARD_EVIDENCE_MAP based on the HTML path."""
    for key in BOARD_EVIDENCE_MAP:
        if key in html_path:
            return key
    # fallback: use dualport
    return "v3_pretest-260511-emutype0-dualport-260512"


def patch_html(html_path):
    build_key = determine_build_key(html_path)
    sim_evdir   = os.path.join(REPO_ROOT, SIM_EVIDENCE_REL)
    board_evdir = os.path.join(REPO_ROOT, BOARD_EVIDENCE_MAP[build_key])

    print("Patching: {}".format(html_path))
    print("  sim_evdir  : {}".format(sim_evdir))
    print("  board_evdir: {}".format(board_evdir))

    with open(html_path, encoding="utf-8") as f:
        html = f.read()

    # ------------------------------------------------------------------
    # 1. Insert Run Window Normalization section after Executive Summary
    # ------------------------------------------------------------------
    # The executive summary section ends just before the next <section> tag
    # that has id="xcompare" or id="matrix".
    # We look for the closing </section> of the Executive Summary block.
    # Strategy: find the first </section> after id="summary"
    summary_close = re.search(
        r'(<section[^>]*>.*?id="summary".*?</section>)',
        html, re.DOTALL
    )
    if summary_close:
        insert_at = summary_close.end()
        html = html[:insert_at] + '\n\n' + NORM_SECTION + html[insert_at:]
    else:
        # Fallback: insert before the first <section> after the header
        first_section = html.find('<section>')
        if first_section >= 0:
            html = html[:first_section] + NORM_SECTION + html[first_section:]

    # ------------------------------------------------------------------
    # 2. Update TOC to include new section
    # ------------------------------------------------------------------
    toc_normalization = (
        '<li><a href="#normalization">Run Window Normalization</a></li>\n'
    )
    # Insert after the first <li> in the TOC nav
    html = re.sub(
        r'(<nav class="toc">.*?<ul>)',
        r'\1\n' + toc_normalization,
        html, count=1, flags=re.DOTALL
    )

    # ------------------------------------------------------------------
    # 3. Patch master table header (cross-validation report only)
    # ------------------------------------------------------------------
    has_master_table = MASTER_TABLE_OLD_HEADER in html
    if has_master_table:
        html = html.replace(MASTER_TABLE_OLD_HEADER, MASTER_TABLE_NEW_HEADER, 1)

    # ------------------------------------------------------------------
    # 4. Update description paragraph for master table
    # ------------------------------------------------------------------
    # The existing description says "Delta is (board - sim) / sim in percent"
    old_master_desc = (
        r'<code>sim_total</code> is the compact harness <code>sim_total_hits</code>'
        r' with <code>run_cycles=1,250,000</code> at 125&nbsp;MHz\.'
        r' <code>board_csr13</code> is the post-end-run LIVE accumulator'
        r' at the on-board build\'s 4&nbsp;s window\.'
        r' Delta is <code>\(board - sim\) / sim</code> in percent\.'
        r' Click any <code>row_id</code> for the deep-dive panel\.'
    )
    new_master_desc = (
        '<code>sim_total</code> is the compact harness <code>sim_total_hits</code>'
        ' with <code>run_cycles=1,250,000</code> at 125&nbsp;MHz (sim_ms=10.0).'
        ' <code>board_total</code> is the post-end-run LIVE accumulator'
        ' at the on-board build\'s 4&nbsp;s window (board_ms=4000.0).'
        ' <strong>&#916;% rate</strong> is the rate-normalized comparison'
        ' (hits/ms on each side); raw counts are kept in grey for reference.'
        ' Click any <code>row_id</code> for the deep-dive panel.'
    )
    html = re.sub(old_master_desc, new_master_desc, html)

    # ------------------------------------------------------------------
    # 5. Build per-row data lookup
    # ------------------------------------------------------------------
    # Collect all row_ids from the HTML
    row_ids = re.findall(r'id="row-([^"]+)"', html)
    row_ids = list(dict.fromkeys(row_ids))  # deduplicate, preserve order

    row_data = {}
    for row_id in row_ids:
        sim_total, sim_ms, board_total, board_ms = load_row_data(
            row_id, sim_evdir, board_evdir
        )
        sim_rate, board_rate, delta_str = compute_rates(
            sim_total, sim_ms, board_total, board_ms
        )
        row_data[row_id] = dict(
            sim_total=sim_total, sim_ms=sim_ms,
            board_total=board_total, board_ms=board_ms,
            sim_rate=sim_rate, board_rate=board_rate,
            delta_str=delta_str
        )

    # ------------------------------------------------------------------
    # 6. Patch master table rows
    # ------------------------------------------------------------------
    if has_master_table:
        for row_id, d in row_data.items():
            html = patch_master_table_row(
                html, row_id,
                d['sim_total'], d['sim_ms'],
                d['board_total'], d['board_ms'],
                d['sim_rate'], d['board_rate'],
                d['delta_str']
            )

    # ------------------------------------------------------------------
    # 7. Patch per-row deep-dive counter comparison tables
    # ------------------------------------------------------------------
    def patch_row_section(m):
        sec = m.group(0)
        # Extract row_id from the section id
        rid_m = re.search(r'id="row-([^"]+)"', sec)
        if not rid_m:
            return sec
        rid = rid_m.group(1)
        d = row_data.get(rid)
        if d is None:
            return sec

        # Load additional counters (hist_sum, csr17) from JSON
        sim_f = os.path.join(sim_evdir, rid, 'sim_counters.json')
        board_f = os.path.join(board_evdir, rid, 'counters.json')
        sim_j   = _load_json(sim_f)
        board_j = _load_json(board_f)

        sim_hist_sum = 0
        sim_csr17    = 0
        board_hist_sum = 0
        board_csr17    = 0

        if sim_j:
            sim_hist_sum = sim_j.get('histogram_statistics_v2', {}).get('hist_bin_sum', 0) or 0
            sim_csr17    = sim_j.get('histogram_statistics_v2', {}).get('LAST_INTERVAL_TOTAL_HITS', 0) or 0

        if board_j:
            board_hist_sum = board_j.get('verdict', {}).get('hist_bin_sum', 0) or 0
            board_csr17    = board_j.get('verdict', {}).get('last_interval_total_hits_csr17', 0) or 0

        # Only patch if the counter comparison table is present
        if COUNTER_TABLE_OLD_HEADER not in sec:
            return sec

        return patch_counter_table(
            sec,
            d['sim_total'], d['sim_ms'],
            d['board_total'], d['board_ms'],
            d['sim_rate'], d['board_rate'],
            d['delta_str'],
            sim_hist_sum, board_hist_sum,
            sim_csr17, board_csr17
        )

    html = re.sub(
        r'<div class="row-section"[^>]*>.*?</div>\s*(?=\n\s*(?:<div class="row-section"|</section>))',
        patch_row_section,
        html,
        flags=re.DOTALL
    )

    # ------------------------------------------------------------------
    # 8. Write output (move original to .bak)
    # ------------------------------------------------------------------
    bak_path = html_path + '.bak'
    shutil.move(html_path, bak_path)
    print("  Backed up original -> {}".format(bak_path))

    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(html)

    print("  Written normalized HTML -> {}".format(html_path))
    return row_data


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 phase4_5_html_normalize.py <html_file> [<html_file2> ...]")
        sys.exit(1)

    for html_file in sys.argv[1:]:
        html_file = os.path.abspath(html_file)
        if not os.path.exists(html_file):
            print("ERROR: file not found: {}".format(html_file))
            sys.exit(1)
        row_data = patch_html(html_file)
        print("\n  Rate normalization summary ({} rows):".format(len(row_data)))
        for rid, d in list(row_data.items())[:5]:
            print("    {} | sim {:.1f} ms {:.2f} hits/ms | board {:.1f} ms {:.2f} hits/ms | {}".format(
                rid[:40], d['sim_ms'], d['sim_rate'],
                d['board_ms'], d['board_rate'], d['delta_str']
            ))
        print("    ... ({} total rows)".format(len(row_data)))

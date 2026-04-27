# Mu3e IP Cores — RTL Coding Style

The authoritative RTL coding style for this repository is the **`rtl-writing` Codex
skill**. It is the single source of truth for naming, ownership, reset discipline,
process labeling, FSM templates, identity/versioning, GUI conventions, and
formatting rules. Do not duplicate or paraphrase its content here — read it
directly and follow it.

**Location:** `~/.codex/skills/rtl-writing/SKILL.md`

**Quick-gate checker** (run before and after every nontrivial RTL edit):

```bash
python3 ~/.codex/skills/rtl-writing/scripts/rtl_style_check.py <file.vhd|file.sv>
```

## What the Codex skill covers

- Ownership and structure — single-writer discipline, process labeling.
- Naming — Platform Designer interface prefixes (`avs_/avm_/asi_/aso_/csi_/rsi_/coe_/ins_/inr_`),
  owner records, `_CONST` suffix, banned `i_/o_/io_/v_/_reg/C_` patterns, enum gerunds.
- Registers, combinational signals, and pipelines — owner-record pattern with `_d1/_d2` staging.
- FSMs and multi-cycle handshakes — enum states, explicit containment of every transition.
- Constants, parameters, and CSRs — compile-time sizing vs runtime clamping.
- **IP identity and versioning (required)** — 4-segment `MAJOR.MINOR.PATCH.BUILD`,
  CSR word 0 `UID`, CSR word 1 read-muxed metadata (`VERSION`/`DATE`/`GIT`/`INSTANCE_ID`),
  RTL header `Version`/`Date`/`Change` aligned with `_hw.tcl`.
- Platform Designer GUI convention — four-tab layout, `Configuration`/`Identity`/`Interfaces`/`Register Map`.
- Interface contracts and assertions — Avalon-MM/ST and AXI ready/valid stability rules.
- Spec-first bring-up workflow — contract → `OPEN:` questions → C-model → TB → signoff.
- DV plan / UVM testcase naming — `TYPE_MODULE_ID_description` format.
- Formatting — 4-space indent, no tabs, virtual tab-stop alignment for `<=`, `:=`, `=`, `=>`,
  trailing comments, declaration name columns, `Key : Value` log style, author line from
  `git config`.
- Presets — explicit complete parameter bundles, safe runtime update pattern.

## Lint enforcement

Style rules the Codex checker does not enforce are caught by the three-layer lint flow:

1. **Questa source lint** — `vlog/vcom -lint=full -pedanticerrors`
2. **Questa elaboration check** — `vopt -check_synthesis` / `vcom -check_synthesis`
3. **Quartus Design Assistant** — post-netlist structural rules (CDC, reset sync, clock tree)

Invoke via the `rtl-lint` Claude Code skill:

```
/rtl-lint <ip-directory>
```

See `~/.claude/skills/rtl-lint/SKILL.md` for the rule catalog and per-layer flags.

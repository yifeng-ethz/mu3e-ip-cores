# Assignments

Base assignments for different boards (a10, fe_s4, etc.).

## Usage

In `qsf` file add command

```
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE <path>/assignments/DE5a_Net.tcl
```

##

- `DE5a_Net.tcl`, `DE5a_Net_DDR4.tcl` - DDR3/DDR4 Arria 10 dev.board
- `fe_s4.tcl` - Stratix IV front-end board
- `fe_malib.tcl`, `fe_scifi.tcl` - additional fe board subsystem assignments
- `fe_max10.tcl` - Max 10 on fe board

##

NOTE: think 7 times before modifying these files

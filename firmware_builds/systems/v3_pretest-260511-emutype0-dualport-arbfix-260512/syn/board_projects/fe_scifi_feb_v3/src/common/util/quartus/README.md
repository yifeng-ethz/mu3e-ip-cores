#

## `makefile.mk`

This `mk` file contains helper tagets
that allow to process specific quartus build steps:

- generate `qsys` files
- generate `sopcinfo` files
- generate BSP from NIOS `sopcinfo` file
- build software for NIOS
- execute flow command on quartus project (compile firmware)

The `qsys` files can be created from quartus
either by creating new system in QSYS editor
or by generating specific IP.

The `sopcinfo` files are generated directly from `qsys` files.

## arch

- `libxcrypt-compat` provides `libcrypt.so.1`

## `top.srf` - suppressed messages

- "Warning (10036): Verilog HDL or VHDL warning at ...: object ... assigned a value but never read"
- "Info (12021): Found ... design units, including ... entities, in source file ..."
- "Info (12128): Elaborating entity ... for hierarchy ... File: ..."
- "Info (16260): Previously generated files were detected in the Platform Designer file generation directory (...)."
- "Info (16261): Skipped generation of the Platform Designer file ... based on the current IP regeneration policy. You can review your IP regeneration policy in the IP Settings page of the Settings dialog box."
- "Info (17048): Logic cell ... File: ..."
  (part of "Info (17016): Found the following redundant logic cells in design")
- "Info (19022): A default voltage has been automatically assigned to ... ..."
- "Warning (20013): Ignored ... assignments for entity ... -- entity does not exist in design"
- "Info (184026): differential I/O pin ... does not have a complementary pin. As a result, the Fitter automatically creates the complementary pin ... File: ..."
- "Info (284007): State machine ... will be implemented as a safe state machine. File: ..."
- "Info (332165): Entity ..." and "Info (332166): ..."
  (part of "Info (332164): Evaluating HDL-embedded SDC commands")
- "Info (332098): The following timing edges are non-unate. The Timing Analyzer will assume pos-unate behavior for these edges in the clock network"
- "Info (332115): Worst-case slack is ... for ..."

# Utils

Common (portable) vhdl components.

## Simulation

```
# compile altera libs
mkdir -p $XDG_DATA_HOME/ghdl/vendors/altera
/usr/lib/ghdl/vendors/compile-altera.sh \
    --src "$QUARTUS_ROOTDIR/eda/sim_lib" \
    --out "$XDG_DATA_HOME/ghdl/vendors/altera" \
    --vhdl2008 \
    --altera
# run simulation
./sim.sh <tb_entity> <sources>
```

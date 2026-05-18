#/bin/sh

cat set_PCIe_Assignments_bus1.tcl \
| perl -pe 's/A10_PCIE_TX_P_([0-9]+)/"o_pcie0_tx[".($1-0)."]"/ge' \
| perl -pe 's/A10_PCIE_RX_P_([0-9]+)/"i_pcie0_rx[".($1-0)."]"/ge' \
| perl -pe 's/LVT_A10_PERST_N/"i_pcie0_perst_n"/ge' \
| perl -pe 's/A10_CLK_PCIE_P_0/"i_pcie0_refclk"/ge' \
> pcie0.tcl

cat set_PCIe_Assignments_bus2.tcl \
| perl -pe 's/A10_PCIE_TX_P_([0-9]+)/"o_pcie1_tx[".($1-8)."]"/ge' \
| perl -pe 's/A10_PCIE_RX_P_([0-9]+)/"i_pcie1_rx[".($1-8)."]"/ge' \
| perl -pe 's/LVT_A10_PERST_2_N/"i_pcie1_perst_n"/ge' \
| perl -pe 's/A10_CLK_PCIE_P_1/"i_pcie1_refclk"/ge' \
> pcie1.tcl

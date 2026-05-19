# merger_hit_type0 standalone signoff SDC.
# Single clock at 1.1x of 125 MHz target (sign-off corner).
# 125 MHz / 1.1 -> 113.6 MHz nominal target, period 8.8 ns; 1.1x means we
# constrain at 137.5 MHz (period 7.27 ns) and check slack >= 0.

create_clock -name clk_125mhz_1p1x -period 7.27 [get_ports clk_125mhz]

derive_clock_uncertainty

# All inputs settle within half a cycle; all outputs leave with half-cycle slack.
set_input_delay  -clock clk_125mhz_1p1x -max 1.0 [remove_from_collection [all_inputs] [get_ports clk_125mhz]]
set_input_delay  -clock clk_125mhz_1p1x -min 0.0 [remove_from_collection [all_inputs] [get_ports clk_125mhz]]
set_output_delay -clock clk_125mhz_1p1x -max 1.0 [all_outputs]
set_output_delay -clock clk_125mhz_1p1x -min 0.0 [all_outputs]

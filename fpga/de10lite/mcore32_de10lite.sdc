# Timing constraints for mcore32_de10lite
#
# Tells the Timing Analyzer how fast each clock runs, so it can check that
# every path through the logic fits in time.

# 50 MHz board oscillator
create_clock -name MAX10_CLK1_50 -period 20.000 [get_ports {MAX10_CLK1_50}]

# PLL output clocks (the 25 MHz core clock) are derived automatically
derive_pll_clocks
derive_clock_uncertainty

# Buttons and switches are slow, asynchronous inputs that go through
# synchronisers, and the LEDs don't care about timing, so don't time them
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to   [get_ports {LEDR[*]}]

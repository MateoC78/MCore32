// Simulation stand-in for the Quartus ALTPLL "pll": passes the clock
// straight through. The testbench can drop "lock" to fake a PLL losing lock.
module pll (
    input  logic inclk0,
    output logic c0,
    output logic locked
);
    logic lock = 1'b1;
    assign c0     = inclk0;
    assign locked = lock;
endmodule

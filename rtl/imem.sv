// Instruction memory (ROM)
//
// Registers the address on posedge clk, which maps onto FPGA block RAM.
// Contents are loaded from a hex file with one 32-bit word per line.

module imem #(
    parameter int    DEPTH     = 4096,          // words (16 KB)
    parameter string INIT_FILE = "program.hex"
) (
    input  logic        clk,
    input  logic [31:0] addr,       // byte address
    output logic [31:0] rdata
);

    localparam int ADDR_BITS = $clog2(DEPTH);

    logic [31:0] mem [DEPTH];

    initial begin
        $readmemh(INIT_FILE, mem);
    end

    // Word address: drop the 2 byte-offset bits
    always_ff @(posedge clk) begin
        rdata <= mem[addr[ADDR_BITS+1:2]];
    end

endmodule

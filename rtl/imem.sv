// Instruction memory (ROM)
//
// Two read ports on one block RAM:
//   - Instruction port: registers addr on posedge clk (see core.sv)
//   - Data port: registers d_addr on negedge clk, so loads can read
//     constants (strings, tables) that the compiler puts in the program
// Contents are loaded from a hex file with one 32-bit word per line.

module imem #(
    parameter int    DEPTH     = 4096,          // words (16 KB)
    parameter string INIT_FILE = "program.hex"
) (
    input  logic        clk,

    // Instruction port
    input  logic [31:0] addr,       // byte address
    output logic [31:0] rdata,

    // Data port (read-only)
    input  logic [31:0] d_addr,     // byte address
    output logic [31:0] d_rdata
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

    always_ff @(negedge clk) begin
        d_rdata <= mem[d_addr[ADDR_BITS+1:2]];
    end

endmodule

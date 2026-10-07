// Data memory (RAM)
//
// Reads and writes on negedge clk, half a cycle after the core has
// computed the address. Byte enables allow sb/sh to change only part
// of a word.

module dmem #(
    parameter int DEPTH = 4096                  // words (16 KB)
) (
    input  logic        clk,
    input  logic [31:0] addr,       // byte address
    input  logic [31:0] wdata,
    input  logic [3:0]  be,         // byte enables
    input  logic        we,
    output logic [31:0] rdata
);

    localparam int ADDR_BITS = $clog2(DEPTH);

    // Stored as 4 bytes per word so each byte can be written separately
    logic [3:0][7:0] mem [DEPTH];
    logic [ADDR_BITS-1:0] word_addr;

    assign word_addr = addr[ADDR_BITS+1:2];

    always_ff @(negedge clk) begin
        if (we) begin
            for (int i = 0; i < 4; i++) begin
                if (be[i]) mem[word_addr][i] <= wdata[8*i +: 8];
            end
        end
        rdata <= mem[word_addr];
    end

endmodule

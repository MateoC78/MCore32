// GPIO peripheral
//
// One 32-bit port. Each pin has a direction bit and an output latch, and
// its level can always be read back through IN. The pins themselves
// (tristate buffers, LEDs, switches) are wired up in the FPGA top level
// from gpio_out / gpio_oe / gpio_in.
//
// Register map (byte offsets from the base address):
//   0x00  IN       R   pin levels, synchronised to clk (2 cycles of delay)
//   0x04  OUT      RW  output latch
//   0x08  DIR      RW  1 = output, 0 = input (all inputs after reset)
//   0x0C  OUT_SET  W   write 1s to set those OUT bits
//   0x10  OUT_CLR  W   write 1s to clear those OUT bits
//   0x14  OUT_TGL  W   write 1s to toggle those OUT bits
//   other offsets read as 0 and ignore writes
//
// Writes honour byte enables, so sb/sh only change the bytes they cover.
// Always ready: writes happen on negedge clk like the RAM, reads are
// combinational from the registers.

module gpio (
    input  logic        clk,
    input  logic        rst,

    // Bus
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic [3:0]  be,
    input  logic        we,
    output logic [31:0] rdata,
    output logic        ready,

    // Pins
    input  logic [31:0] gpio_in,
    output logic [31:0] gpio_out,
    output logic [31:0] gpio_oe
);

    localparam logic [7:0] REG_IN      = 8'h00;
    localparam logic [7:0] REG_OUT     = 8'h04;
    localparam logic [7:0] REG_DIR     = 8'h08;
    localparam logic [7:0] REG_OUT_SET = 8'h0C;
    localparam logic [7:0] REG_OUT_CLR = 8'h10;
    localparam logic [7:0] REG_OUT_TGL = 8'h14;

    logic [31:0] out_q, dir_q;
    logic [31:0] in_meta, in_sync;
    logic [31:0] mask;          // which bits this store covers
    logic [7:0]  offset;

    assign offset = {addr[7:2], 2'b00};
    assign mask   = {{8{be[3]}}, {8{be[2]}}, {8{be[1]}}, {8{be[0]}}};

    // Two flip-flops so a pin changing near a clock edge can't upset the
    // logic that reads it (metastability)
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            in_meta <= '0;
            in_sync <= '0;
        end else begin
            in_meta <= gpio_in;
            in_sync <= in_meta;
        end
    end

    // Register writes
    always_ff @(negedge clk or posedge rst) begin
        if (rst) begin
            out_q <= '0;
            dir_q <= '0;
        end else if (we) begin
            case (offset)
                REG_OUT:     out_q <= (out_q & ~mask) | (wdata & mask);
                REG_DIR:     dir_q <= (dir_q & ~mask) | (wdata & mask);
                REG_OUT_SET: out_q <= out_q |  (wdata & mask);
                REG_OUT_CLR: out_q <= out_q & ~(wdata & mask);
                REG_OUT_TGL: out_q <= out_q ^  (wdata & mask);
                default: ;
            endcase
        end
    end

    // Register reads
    always_comb begin
        case (offset)
            REG_IN:  rdata = in_sync;
            REG_OUT: rdata = out_q;
            REG_DIR: rdata = dir_q;
            default: rdata = 32'b0;
        endcase
    end

    assign ready    = 1'b1;
    assign gpio_out = out_q;
    assign gpio_oe  = dir_q;

endmodule

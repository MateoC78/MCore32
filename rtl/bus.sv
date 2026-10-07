// Data bus: address decoder and interconnect
//
// Connects the core's data port to N devices. Each device owns the
// addresses where (addr & MASK[i]) == BASE[i]. If two regions overlap,
// the lower-numbered device wins.
//
// Every device sees the same addr/wdata/be, but only the selected one
// gets we/re. The selected device's rdata and ready go back to the core.
//
// Device rules (same handshake as the core, see core.sv):
//   - Only perform a store in a cycle where you drive ready high.
//   - ready may be held low for as many cycles as needed; the core
//     keeps the request on the bus until it sees ready.
//
// An access to an address no device owns completes immediately: stores
// are dropped, loads return 0, and bus_err is high for that cycle.
//
// Purely combinational, so it adds no cycles.

module bus #(
    parameter int                   N    = 2,
    parameter logic [N-1:0][31:0]   BASE = '0,
    parameter logic [N-1:0][31:0]   MASK = '0
) (
    // From the core
    input  logic [31:0]          addr,
    input  logic [31:0]          wdata,
    input  logic [3:0]           be,
    input  logic                 we,
    input  logic                 re,
    output logic [31:0]          rdata,
    output logic                 ready,
    output logic                 bus_err,   // access to an unmapped address

    // To the devices (addr/wdata/be are shared)
    output logic [31:0]          dev_addr,
    output logic [31:0]          dev_wdata,
    output logic [3:0]           dev_be,
    output logic [N-1:0]         dev_we,
    output logic [N-1:0]         dev_re,
    input  logic [N-1:0][31:0]   dev_rdata,
    input  logic [N-1:0]         dev_ready
);

    logic [N-1:0] sel;      // one-hot: which device owns addr
    logic         hit;      // some device owns addr

    assign dev_addr  = addr;
    assign dev_wdata = wdata;
    assign dev_be    = be;

    // Decode: first matching region wins
    always_comb begin
        sel = '0;
        hit = 1'b0;
        for (int i = 0; i < N; i++) begin
            if (!hit && ((addr & MASK[i]) == BASE[i])) begin
                sel[i] = 1'b1;
                hit    = 1'b1;
            end
        end
    end

    // Only the selected device sees the request
    assign dev_we = sel & {N{we}};
    assign dev_re = sel & {N{re}};

    // Response from the selected device. Unmapped: ready, data 0.
    always_comb begin
        rdata = 32'b0;
        ready = 1'b1;
        for (int i = 0; i < N; i++) begin
            if (sel[i]) begin
                rdata = dev_rdata[i];
                ready = dev_ready[i];
            end
        end
    end

    assign bus_err = (we | re) & ~hit;

endmodule

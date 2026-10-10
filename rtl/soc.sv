// MCore32 SoC
//
// Core + data bus + memories + peripherals. The FPGA top level wraps
// this with the board's clock, reset and pins.
//
// Memory map:
//   0x0000_0000  ROM   program and constants (data port is read-only)
//   0x1000_0000  RAM   data, stack
//   0x2000_0000  GPIO  (4 KB slot)
//   0x2000_1000  UART  (later)
//   0x2000_2000  Timer (later)
//
// To add a peripheral: give it the next device index, add its BASE/MASK
// below, bump NUM_DEV, and connect it to the dev_* signals.

module soc #(
    parameter string ROM_INIT  = "program.hex",
    parameter int    ROM_WORDS = 4096,          // 16 KB
    parameter int    RAM_WORDS = 4096           // 16 KB
) (
    input  logic clk,
    input  logic rst,

    // GPIO pins: the FPGA top level wires these to LEDs, switches and
    // header pins (with tristate buffers where a pin can be both)
    input  logic [31:0] gpio_in,
    output logic [31:0] gpio_out,
    output logic [31:0] gpio_oe,    // 1 = pin driven by gpio_out

    // Debug
    output logic illegal,       // core is executing an invalid instruction
    output logic bus_err        // data access to an unmapped address
);

    // ------------------------------------------------------------------
    // Address map
    // ------------------------------------------------------------------
    localparam int DEV_ROM  = 0;
    localparam int DEV_RAM  = 1;
    localparam int DEV_GPIO = 2;
    localparam int NUM_DEV  = 3;

    //                                            GPIO          RAM           ROM
    localparam logic [NUM_DEV-1:0][31:0] BASE = {32'h2000_0000, 32'h1000_0000, 32'h0000_0000};
    localparam logic [NUM_DEV-1:0][31:0] MASK = {32'hFFFF_F000, 32'hF000_0000, 32'hF000_0000};

    // ------------------------------------------------------------------
    // Core
    // ------------------------------------------------------------------
    logic [31:0] imem_addr, imem_rdata;
    logic [31:0] d_addr, d_wdata, d_rdata;
    logic [3:0]  d_be;
    logic        d_we, d_re, d_ready;

    core u_core (
        .clk       (clk),
        .rst       (rst),
        .imem_addr (imem_addr),
        .imem_rdata(imem_rdata),
        .dmem_addr (d_addr),
        .dmem_wdata(d_wdata),
        .dmem_be   (d_be),
        .dmem_we   (d_we),
        .dmem_re   (d_re),
        .dmem_rdata(d_rdata),
        .dmem_ready(d_ready),
        .illegal   (illegal)
    );

    // ------------------------------------------------------------------
    // Bus
    // ------------------------------------------------------------------
    logic [31:0]              dev_addr, dev_wdata;
    logic [3:0]               dev_be;
    logic [NUM_DEV-1:0]       dev_we, dev_re, dev_ready;
    logic [NUM_DEV-1:0][31:0] dev_rdata;

    bus #(
        .N   (NUM_DEV),
        .BASE(BASE),
        .MASK(MASK)
    ) u_bus (
        .addr     (d_addr),
        .wdata    (d_wdata),
        .be       (d_be),
        .we       (d_we),
        .re       (d_re),
        .rdata    (d_rdata),
        .ready    (d_ready),
        .bus_err  (bus_err),
        .dev_addr (dev_addr),
        .dev_wdata(dev_wdata),
        .dev_be   (dev_be),
        .dev_we   (dev_we),
        .dev_re   (dev_re),
        .dev_rdata(dev_rdata),
        .dev_ready(dev_ready)
    );

    // ------------------------------------------------------------------
    // ROM: instruction port to the core, data port on the bus.
    // Stores to ROM are ignored.
    // ------------------------------------------------------------------
    imem #(
        .DEPTH    (ROM_WORDS),
        .INIT_FILE(ROM_INIT)
    ) u_rom (
        .clk    (clk),
        .addr   (imem_addr),
        .rdata  (imem_rdata),
        .d_addr (dev_addr),
        .d_rdata(dev_rdata[DEV_ROM])
    );

    assign dev_ready[DEV_ROM] = 1'b1;

    // ------------------------------------------------------------------
    // RAM: always answers in time
    // ------------------------------------------------------------------
    dmem #(
        .DEPTH(RAM_WORDS)
    ) u_ram (
        .clk  (clk),
        .addr (dev_addr),
        .wdata(dev_wdata),
        .be   (dev_be),
        .we   (dev_we[DEV_RAM]),
        .rdata(dev_rdata[DEV_RAM])
    );

    assign dev_ready[DEV_RAM] = 1'b1;

    // ------------------------------------------------------------------
    // GPIO
    // ------------------------------------------------------------------
    gpio u_gpio (
        .clk     (clk),
        .rst     (rst),
        .addr    (dev_addr),
        .wdata   (dev_wdata),
        .be      (dev_be),
        .we      (dev_we[DEV_GPIO]),
        .rdata   (dev_rdata[DEV_GPIO]),
        .ready   (dev_ready[DEV_GPIO]),
        .gpio_in (gpio_in),
        .gpio_out(gpio_out),
        .gpio_oe (gpio_oe)
    );

endmodule

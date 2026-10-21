// MCore32 top level for the Terasic DE10-Lite (MAX 10, 10M50DAF484C7G)
//
// Wraps soc.sv with the board's clock, reset and pins. Port names match
// the ones Terasic's DE10-Lite System Builder generates, so its pin
// assignments (.qsf) apply directly.
//
// Quartus setup:
//   1. Run DE10-Lite System Builder, tick CLOCK, LED, Button, Switch and
//      Arduino header, and generate a project. Use its .qsf for the pin
//      locations; set this module as the top-level entity.
//   2. Add every file in rtl/ plus this file and mcore32_de10lite.sdc.
//   3. IP Catalog > ALTPLL, name it "pll": input 50 MHz on inclk0,
//      output c0 = 25 MHz, keep the "locked" output, no other ports.
//   4. Assignments > Device > Device and Pin Options > Configuration:
//      set Configuration mode to one that says "with Memory
//      Initialization", otherwise the ROM starts empty.
//   5. Put the program hex file in the Quartus project folder (or give
//      a path relative to it in ROM_INIT below).
//
// GPIO pin map (bit n of the GPIO registers = pin n):
//   0-9    LEDR[0..9]          output only
//   10-15  ARDUINO_IO[2..7]    bidirectional (DIR decides)
//   16-25  SW[0..9]            input only
//   26-27  KEY[0..1]           input only, active low (0 = pressed)
//   28-31  unused, read as 0
// ARDUINO_IO[0..1] (D0/D1) are kept free for the UART later.
// KEY[0] is also the reset button.

module mcore32_de10lite #(
    parameter string ROM_INIT = "blink.hex"
) (
    input  logic        MAX10_CLK1_50,      // 50 MHz board oscillator

    input  logic [1:0]  KEY,                // push buttons, active low
    input  logic [9:0]  SW,                 // slide switches
    output logic [9:0]  LEDR,               // red LEDs, 1 = on

    inout  wire  [15:0] ARDUINO_IO          // Arduino header D0-D15
);

    // ------------------------------------------------------------------
    // Clock: 50 MHz in, 25 MHz to the core. Each half of a cycle has to
    // fit half the core's logic (see the timing figure in the block
    // diagram), so start slow and raise it once timing analysis passes.
    // ------------------------------------------------------------------
    logic clk;
    logic pll_locked;

    pll u_pll (
        .inclk0(MAX10_CLK1_50),
        .c0    (clk),
        .locked(pll_locked)
    );

    // ------------------------------------------------------------------
    // Reset
    // ------------------------------------------------------------------
    logic rst;

    // TODO: reset synchroniser
    //   - Hold the SoC in reset while KEY[0] is pressed (it reads 0 when
    //     pressed) or while the PLL isn't locked yet.
    //   - Assert asynchronously, release synchronously: a 2-3 flip-flop
    //     shift register clocked by clk, with an async preset from the
    //     raw reset condition. Shift 0s in; rst is the last flip-flop.
    //   - Why: if reset is released right at a clock edge, some flip-flops
    //     could leave reset a cycle before others and start in a mix of
    //     states. Releasing on a clock edge avoids that.
    //   - Shape (fill in the condition and the shift):
    //       logic [2:0] rst_sync;
    //       always_ff @(posedge clk or posedge <raw reset>) ...
    logic rst_raw;
    logic [2:0] rst_sync;
    assign rst_raw = ~KEY[0] | ~pll_locked;
    always_ff @(posedge clk or posedge rst_raw) begin
        if (rst_raw)
            rst_sync <= 3'b111; // Assert reset
        else
            rst_sync <= {rst_sync[1:0], 1'b0}; // Shift in 0s
    end

    // ------------------------------------------------------------------
    // SoC
    // ------------------------------------------------------------------
    logic [31:0] gpio_in, gpio_out, gpio_oe;
    logic        illegal, bus_err;

    soc #(
        .ROM_INIT (ROM_INIT),
        .ROM_WORDS(4096),           // 16 KB
        .RAM_WORDS(4096)            // 16 KB
    ) u_soc (
        .clk     (clk),
        .rst     (rst),
        .gpio_in (gpio_in),
        .gpio_out(gpio_out),
        .gpio_oe (gpio_oe),
        .illegal (illegal),
        .bus_err (bus_err)
    );

    // ------------------------------------------------------------------
    // GPIO wiring (see the pin map at the top)
    // ------------------------------------------------------------------

    // TODO: LEDs, pins 0-9
    //   - An LED should only light when its pin is an output AND driven
    //     high, like a real MCU pin set as input wouldn't drive anything.
    //   - Hint: combine gpio_out[9:0] and gpio_oe[9:0].
    assign LEDR = gpio_out[9:0] & gpio_oe[9:0];

    // TODO: Arduino header, pins 10-15 -> ARDUINO_IO[2..7]
    //   - These are real bidirectional pins, so use tristate buffers:
    //     drive the pin when its oe bit is 1, otherwise release it.
    //       assign ARDUINO_IO[k] = <oe bit> ? <out bit> : 1'bz;
    //   - A generate-for loop or a packed slice keeps this to a line or
    //     two. Leave ARDUINO_IO[0..1] and [8..15] released (1'bz) for now.
    assign ARDUINO_IO[2] = gpio_oe[10] ? gpio_out[10] : 1'bz;
    assign ARDUINO_IO[3] = gpio_oe[11] ? gpio_out[11] : 1'bz;
    assign ARDUINO_IO[4] = gpio_oe[12] ? gpio_out[12] : 1'bz;
    assign ARDUINO_IO[5] = gpio_oe[13] ? gpio_out[13] : 1'bz;
    assign ARDUINO_IO[6] = gpio_oe[14] ? gpio_out[14] : 1'bz;
    assign ARDUINO_IO[7] = gpio_oe[15] ? gpio_out[15] : 1'bz;
    assign ARDUINO_IO[0] = 1'bz;
    assign ARDUINO_IO[1] = 1'bz;
    assign ARDUINO_IO[8] = 1'bz;
    assign ARDUINO_IO[9] = 1'bz;
    assign ARDUINO_IO[10] = 1'bz;
    assign ARDUINO_IO[11] = 1'bz;
    assign ARDUINO_IO[12] = 1'bz;
    assign ARDUINO_IO[13] = 1'bz;
    assign ARDUINO_IO[14] = 1'bz;
    assign ARDUINO_IO[15] = 1'bz;

    // TODO: gpio_in, all 32 bits
    //   - Pins 0-9: no physical input, so read back what the LEDs show
    //     (the same expression as the LEDs).
    //   - Pins 10-15: read the actual ARDUINO_IO[2..7] pin levels; that
    //     also reads back your own output when a pin is driving.
    //   - Pins 16-25: SW. Pins 26-27: KEY. Pins 28-31: 0.
    //   - gpio.sv already synchronises these inputs, so connect them raw.

    assign gpio_in[9:0]   = gpio_out[9:0] & gpio_oe[9:0];
    assign gpio_in[15:10] = ARDUINO_IO[7:2];
    assign gpio_in[25:16] = SW;
    assign gpio_in[27:26] = KEY;
    assign gpio_in[31:28] = 4'b0;
    // Debug outputs: no spare LEDs, so illegal and bus_err are unused for
    // now. The 7-segment displays are a good place for them later.

endmodule

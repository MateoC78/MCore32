module de10lite_tb;

    // Board-level test: runs blink_fast.hex on mcore32_de10lite with
    // sim/pll_stub.sv in place of the real PLL. Checks the reset button,
    // PLL lock, switches -> LEDs, LED0 blinking and the Arduino pins.
    parameter string PROGRAM = "sim/programs/blink_fast.hex";

    logic        clk = 1'b0;
    logic [1:0]  KEY = 2'b10;               // KEY[0] pressed at power-up
    logic [9:0]  SW  = 10'b10_1010_1011;
    logic [9:0]  LEDR;
    wire  [15:0] ARDUINO_IO;

    integer errors  = 0;
    integer toggles = 0;
    logic   led0_prev;

    always #5 clk = ~clk;

    mcore32_de10lite #(.ROM_INIT(PROGRAM)) UUT (
        .MAX10_CLK1_50(clk),
        .KEY          (KEY),
        .SW           (SW),
        .LEDR         (LEDR),
        .ARDUINO_IO   (ARDUINO_IO)
    );

    `define CHECK(name, got, exp) \
        assert ((got) === (exp)) \
        else begin \
            $error("%s expected %h, got %h", name, exp, got); \
            errors++; \
        end

    always @(posedge clk) begin
        led0_prev <= LEDR[0];
        if (UUT.rst === 1'b0 && LEDR[0] !== led0_prev) toggles++;
        if (UUT.rst === 1'b0 && (UUT.illegal || UUT.bus_err)) begin
            $error("illegal instruction or bus error at pc=%h", UUT.u_soc.u_core.pc);
            errors++;
        end
    end

    // Count clock edges from releasing reset until rst actually drops
    task automatic check_release(input string tag);
        int n = 0;
        while (UUT.rst !== 1'b0 && n < 10) begin
            @(posedge clk); #1;
            n++;
        end
        assert (n == 3)
        else begin
            $error("%s: rst released after %0d clocks, expected 3", tag, n);
            errors++;
        end
    endtask

    initial begin

        // Held in reset by KEY[0]
        repeat (5) @(posedge clk); #1;
        `CHECK("rst while KEY[0] pressed", UUT.rst, 1'b1)
        `CHECK("LEDR in reset", LEDR, 10'h000)
        `CHECK("ARDUINO_IO in reset", ARDUINO_IO, 16'hzzzz)

        // Release KEY[0] between clock edges: rst drops on a clock edge,
        // after the 3-flop synchroniser
        @(negedge clk); #2;
        KEY[0] = 1'b1;
        check_release("KEY[0]");

        // Program running: LED1-9 follow SW1-9, LED0 blinks
        repeat (40) @(posedge clk); #1;
        `CHECK("LEDR[9:1] = SW[9:1]", LEDR[9:1], SW[9:1])
        SW = 10'b01_0101_0100;
        repeat (20) @(posedge clk); #1;
        `CHECK("LEDR[9:1] after SW change", LEDR[9:1], SW[9:1])
        repeat (400) @(posedge clk);
        assert (toggles >= 10)
        else begin
            $error("LED0 toggled %0d times, expected 10 or more", toggles);
            errors++;
        end
        `CHECK("ARDUINO_IO unused, released", ARDUINO_IO, 16'hzzzz)

        // Pressing KEY[0] resets immediately, without waiting for a clock
        @(negedge clk); #2;
        KEY[0] = 1'b0;
        #1;
        `CHECK("rst right after KEY[0] press", UUT.rst, 1'b1)
        @(posedge clk); #1;
        `CHECK("LEDR after KEY[0] press", LEDR, 10'h000)
        KEY[0] = 1'b1;
        check_release("KEY[0] again");

        // Losing PLL lock also resets
        repeat (20) @(posedge clk);
        UUT.u_pll.lock = 1'b0;
        #1;
        `CHECK("rst when PLL unlocked", UUT.rst, 1'b1)
        @(negedge clk); #2;
        UUT.u_pll.lock = 1'b1;
        check_release("PLL lock");

        if (errors == 0) $display("de10lite_tb PASSED (LED0 toggled %0d times)", toggles);
        else             $display("de10lite_tb FAILED with %0d errors", errors);
        $finish;

    end

endmodule

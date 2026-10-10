module gpio_tb;

    // Runs sim/programs/gpio_test.hex on the full SoC and checks the GPIO
    // registers through real loads and stores.
    parameter string PROGRAM = "sim/programs/gpio_test.hex";

    localparam int          MAX_CYCLES = 200;
    localparam logic [31:0] EXTERNAL   = 32'hABCD_1234;    // what's driving the input pins

    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic        illegal, bus_err;
    logic [31:0] gpio_in, gpio_out, gpio_oe;

    integer errors = 0;
    integer cycles = 0;

    always #5 clk = ~clk;

    // Pin model: an output pin reads back what it drives, an input pin
    // reads whatever is connected outside
    assign gpio_in = (gpio_out & gpio_oe) | (EXTERNAL & ~gpio_oe);

    // Instantiate DUT
    soc #(
        .ROM_INIT (PROGRAM),
        .ROM_WORDS(1024),
        .RAM_WORDS(1024)
    ) UUT (
        .clk     (clk),
        .rst     (rst),
        .gpio_in (gpio_in),
        .gpio_out(gpio_out),
        .gpio_oe (gpio_oe),
        .illegal (illegal),
        .bus_err (bus_err)
    );

    `define CHECK(name, got, exp) \
        assert ((got) === (exp)) \
        else begin \
            $error("%s expected %h, got %h", name, exp, got); \
            errors++; \
        end

    always @(posedge clk) begin
        if (!rst) begin
            cycles++;
            if (illegal) begin
                $error("illegal instruction %h at pc=%h", UUT.imem_rdata, UUT.u_core.pc);
                errors++;
            end
            if (bus_err) begin
                $error("bus error at pc=%h", UUT.u_core.pc);
                errors++;
            end
        end
    end

    initial begin

        // Reset state: every pin an input, outputs low
        repeat (2) @(posedge clk);
        `CHECK("gpio_oe after reset",  gpio_oe,  32'h0)
        `CHECK("gpio_out after reset", gpio_out, 32'h0)

        @(negedge clk);
        rst = 1'b0;

        wait (UUT.imem_rdata == 32'h0000006F || cycles >= MAX_CYCLES);
        repeat (2) @(posedge clk);

        if (cycles >= MAX_CYCLES) begin
            $error("timed out after %0d cycles", cycles);
            errors++;
        end

        // Expected results, see sim/programs/gpio_test.hex
        `CHECK("x7 (OUT after set/clr/tgl)", UUT.u_core.u_regfile.regs[7],  32'h0000_00E0)
        `CHECK("x8 (DIR)",                   UUT.u_core.u_regfile.regs[8],  32'h0000_00FF)
        `CHECK("x9 (IN)",                    UUT.u_core.u_regfile.regs[9],  32'hABCD_12E0)
        `CHECK("x10 (OUT after sb)",         UUT.u_core.u_regfile.regs[10], 32'h0000_FFE0)
        `CHECK("x11 (unused offset)",        UUT.u_core.u_regfile.regs[11], 32'h0000_0000)

        // Pins
        `CHECK("gpio_oe",  gpio_oe,  32'h0000_00FF)
        `CHECK("gpio_out", gpio_out, 32'h0000_FFE0)

        // IN follows an external pin change after the 2-flop synchroniser
        force UUT.gpio_in = 32'h5555_0000;
        repeat (1) @(posedge clk); #1;
        `CHECK("IN 1 cycle after pin change", UUT.u_gpio.in_sync, 32'hABCD_12E0)
        repeat (1) @(posedge clk); #1;
        `CHECK("IN 2 cycles after pin change", UUT.u_gpio.in_sync, 32'h5555_0000)
        release UUT.gpio_in;

        if (errors == 0) $display("gpio_tb PASSED (%0d cycles)", cycles);
        else             $display("gpio_tb FAILED with %0d errors", errors);
        $finish;

    end

endmodule

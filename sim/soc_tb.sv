module soc_tb;

    // Path is relative to the directory vsim is run from (the project root)
    parameter string PROGRAM = "sim/programs/soc_test.hex";

    localparam int MAX_CYCLES      = 200;
    localparam int EXPECTED_ERRORS = 2;     // one store, one load to 0x3000_0000

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic illegal, bus_err;
    logic [31:0] gpio_out, gpio_oe;

    integer errors = 0;
    integer cycles = 0;
    integer bus_errors = 0;

    always #5 clk = ~clk;

    // Instantiate DUT
    soc #(
        .ROM_INIT (PROGRAM),
        .ROM_WORDS(1024),
        .RAM_WORDS(1024)
    ) UUT (
        .clk     (clk),
        .rst     (rst),
        .gpio_in (32'h0),
        .gpio_out(gpio_out),
        .gpio_oe (gpio_oe),
        .illegal (illegal),
        .bus_err (bus_err)
    );

    task automatic check_reg(input int n, input logic [31:0] exp);
        logic [31:0] got;
        got = UUT.u_core.u_regfile.regs[n];
        assert (got === exp)
        else begin
            $error("x%0d expected %h, got %h", n, exp, got);
            errors++;
        end
    endtask

    // Trace every instruction as it executes
    always @(posedge clk) begin
        if (!rst) begin
            $display("%4d  pc=%h  instr=%h%s", cycles, UUT.u_core.pc, UUT.imem_rdata,
                     bus_err ? "  (bus error)" : "");
            cycles++;
            if (bus_err) bus_errors++;
            if (illegal) begin
                $error("illegal instruction %h at pc=%h", UUT.imem_rdata, UUT.u_core.pc);
                errors++;
            end
        end
    end

    initial begin

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // Run until the program reaches its final "jal x0, 0" loop
        wait (UUT.imem_rdata == 32'h0000006F || cycles >= MAX_CYCLES);
        repeat (2) @(posedge clk);

        if (cycles >= MAX_CYCLES) begin
            $error("timed out after %0d cycles, pc=%h", cycles, UUT.u_core.pc);
            errors++;
        end

        // Expected results, see sim/programs/soc_test.hex
        check_reg(1, 32'h10000000);
        check_reg(2, 32'hCAFEF00D);     // word load from ROM
        check_reg(3, 32'hFFFFFFF0);     // byte load from ROM
        check_reg(4, 32'h0000CAFE);     // halfword load from ROM
        check_reg(5, 32'hCAFEF00D);     // RAM round trip
        check_reg(6, 32'h12345678);     // ROM ignored the store
        check_reg(7, 32'h30000000);
        check_reg(8, 32'h00000000);     // unmapped load returns 0
        check_reg(9, 32'h00000001);     // core kept running

        assert (UUT.u_ram.mem[0] === 32'hCAFEF00D)
        else begin
            $error("RAM[0] expected CAFEF00D, got %h", UUT.u_ram.mem[0]);
            errors++;
        end

        assert (UUT.u_rom.mem[17] === 32'h12345678)
        else begin
            $error("ROM[0x44] was overwritten: %h", UUT.u_rom.mem[17]);
            errors++;
        end

        assert (bus_errors == EXPECTED_ERRORS)
        else begin
            $error("expected %0d bus errors, got %0d", EXPECTED_ERRORS, bus_errors);
            errors++;
        end

        if (errors == 0) $display("soc_tb PASSED (%0d cycles)", cycles);
        else             $display("soc_tb FAILED with %0d errors", errors);
        $finish;

    end

endmodule

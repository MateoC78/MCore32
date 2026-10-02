module regfile_tb;

    // Set to 0 if x0 is meant to be a normal writable register
    localparam bit X0_HARDWIRED = 1'b1;

    logic        clk = 1'b0;
    logic        rst = 1'b0;
    logic [4:0]  rs1 = '0;
    logic [4:0]  rs2 = '0;
    logic [4:0]  rd  = '0;
    logic [31:0] wd  = '0;
    logic        we  = 1'b0;
    logic [31:0] rd1;
    logic [31:0] rd2;

    // Reference model of what the register file should contain
    logic [31:0] model [31:0];
    integer errors = 0;
    integer i;

    // Instantiate DUT
    regfile UUT (
        .clk(clk),
        .rst(rst),
        .rs1(rs1),
        .rs2(rs2),
        .rd (rd),
        .wd (wd),
        .we (we),
        .rd1(rd1),
        .rd2(rd2)
    );

    always #5 clk = ~clk;

    // Drive a write on the negedge so it is captured cleanly on the next posedge
    task automatic write_reg(input logic [4:0] addr, input logic [31:0] data);
        @(negedge clk);
        rd = addr;
        wd = data;
        we = 1'b1;
        @(negedge clk);
        we = 1'b0;
        if (!(X0_HARDWIRED && addr == 5'd0))
            model[addr] = data;
    endtask

    // Read both ports and compare against the model
    task automatic check_read(input logic [4:0] a1, input logic [4:0] a2, input string tag);
        rs1 = a1;
        rs2 = a2;
        #1;
        assert (rd1 == model[a1])
        else begin
            $error("%s: rd1 (x%0d) expected %h, got %h", tag, a1, model[a1], rd1);
            errors++;
        end
        assert (rd2 == model[a2])
        else begin
            $error("%s: rd2 (x%0d) expected %h, got %h", tag, a2, model[a2], rd2);
            errors++;
        end
    endtask

    task automatic do_reset();
        @(negedge clk);
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;
        for (i = 0; i < 32; i++) model[i] = 32'h0;
    endtask

    initial begin

        // Test 1: reset clears every register
        do_reset();
        for (i = 0; i < 32; i++) check_read(i, 31 - i, "reset");

        // Test 2: write a unique value to every register, read back on both ports
        for (i = 0; i < 32; i++) write_reg(i, 32'hA5A50000 | i);
        for (i = 0; i < 32; i++) check_read(i, 31 - i, "write all");

        // Test 3: both ports reading the same register
        for (i = 0; i < 32; i++) check_read(i, i, "same addr");

        // Test 4: we = 0 must not modify anything
        @(negedge clk);
        rd = 5'd7;
        wd = 32'hDEADBEEF;
        we = 1'b0;
        @(negedge clk);
        check_read(7, 7, "we=0");

        // Test 5: overwrite a register
        write_reg(5'd12, 32'h12345678);
        write_reg(5'd12, 32'h87654321);
        check_read(12, 11, "overwrite");

        // Test 6: write takes effect on the clock edge, not before
        @(negedge clk);
        rs1 = 5'd3;
        rd  = 5'd3;
        wd  = 32'hCAFEF00D;
        we  = 1'b1;
        #1;
        assert (rd1 == model[3])
        else begin
            $error("pre-edge: x3 changed before posedge, got %h", rd1);
            errors++;
        end
        @(posedge clk);
        #1;
        we = 1'b0;
        model[3] = 32'hCAFEF00D;
        check_read(3, 0, "post-edge");

        // Test 7: x0 behaviour
        write_reg(5'd0, 32'hFFFFFFFF);
        check_read(0, 0, X0_HARDWIRED ? "x0 hardwired" : "x0 writable");

        // Test 8: asynchronous reset in the middle of a cycle
        write_reg(5'd20, 32'h0BADF00D);
        @(posedge clk);
        #2;
        rst = 1'b1;
        #1;
        for (i = 0; i < 32; i++) model[i] = 32'h0;
        check_read(20, 0, "async reset");
        rst = 1'b0;

        if (errors == 0) $display("regfile_tb PASSED");
        else             $display("regfile_tb FAILED with %0d errors", errors);
        $finish;

    end

endmodule

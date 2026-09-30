module alu_nwidth_tb;

    parameter WIDTH = 32;

    logic [WIDTH-1:0] input1 = '0;
    logic [WIDTH-1:0] input2 = '0;
    logic [      2:0] sel = '0;
    logic [WIDTH-1:0] out;
    logic             overflow;

    // Instantiate DUT
    alu_nwidth #(
        .WIDTH(WIDTH)
    ) UUT (
        .input1  (input1),
        .input2  (input2),
        .sel     (sel),
        .out     (out),
        .overflow(overflow)
    );

    initial begin

        // Test sel = 3'b000, ADD
        input1 = 32'h00000055;
        input2 = 32'h00000555;
        sel    = 3'b000;
        #40;
        assert (out == 32'h000005AA)
        else $error("sel=000 (ADD) failed: expected out=000005AA, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=000 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 3'b001, SUB
        input1 = 32'h00009BAA;
        input2 = 32'h00000067;
        sel    = 3'b001;
        #40;
        assert (out == 32'h00009B43)
        else $error("sel=001 (SUB) failed: expected out=00009B43, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=001 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 3'b010, AND
        input1 = 32'hCCCCCCCC;
        input2 = 32'hDECDABCF;
        sel    = 3'b010;
        #40;
        assert (out == 32'hCCCC88CC)
        else $error("sel=010 (AND) failed: expected out=CCCC88CC, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=010 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 3'b011, OR
        input1 = 32'h0000BBBB;
        input2 = 32'h00006789;
        sel    = 3'b011;
        #40;
        assert (out == 32'h0000FFBB)
        else $error("sel=011 (OR) failed: expected out=0000FFBB, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=011 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 3'b100, XOR
        input1 = 32'h0000FFFF;
        input2 = 32'h00000055;
        sel    = 3'b100;
        #40;
        assert (out == 32'h0000FFAA)
        else $error("sel=100 (XOR) failed: expected out=0000FFAA, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=100 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 3'b101, NOT
        input1 = 32'h0000BBBB;
        input2 = 32'h00000006;
        sel    = 3'b101;
        #40;
        assert (out == 32'hFFFF4444)
        else $error("sel=101 (NOT) failed: expected out=FFFF4444, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=101 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 3'b110, SLT
        input1 = 32'h00000005;
        input2 = 32'h000000A9;
        sel    = 3'b110;
        #40;
        assert (out == 32'h00000001)
        else $error("sel=110 failed: expected out=00000001, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=110 failed: expected overflow=0, got overflow=%b", overflow);

        $display("Simulation Finished!");
        $finish;

    end

endmodule
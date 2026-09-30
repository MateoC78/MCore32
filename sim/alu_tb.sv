module alu_nwidth_tb;

    parameter WIDTH = 8;

    logic [WIDTH-1:0] input1 = '0;
    logic [WIDTH-1:0] input2 = '0;
    logic [      3:0] sel = '0;
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

        // Test sel = 4'b0000
        input1 = 8'hAA;
        input2 = 8'h00;
        sel    = 4'b0000;
        #40;
        assert (out == 8'h55)
        else $error("sel=0000 failed: expected out=55, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=0000 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 4'b0001
        input1 = 8'h0C;
        input2 = 8'h0A;
        sel    = 4'b0001;
        #40;
        assert (out == 8'h08)
        else $error("sel=0001 failed: expected out=08, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=0001 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 4'b0010
        input1 = 8'h0C;
        input2 = 8'h0A;
        sel    = 4'b0010;
        #40;
        assert (out == 8'h0E)
        else $error("sel=0010 failed: expected out=0A, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=0010 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 4'b0011
        input1 = 8'h0C;
        input2 = 8'h0A;
        sel    = 4'b0011;
        #40;
        assert (out == 8'hF1)
        else $error("sel=0011 failed: expected out=F1, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=0011 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 4'b0100
        input1 = 8'h0C;
        input2 = 8'h0A;
        sel    = 4'b0100;
        #40;
        assert (out == 8'h06)
        else $error("sel=0100 failed: expected out=01, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=0100 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 4'b0101
        input1 = 8'd2;
        input2 = 8'd6;
        sel    = 4'b0101;
        #40;
        assert (out == 8'd8)
        else $error("sel=0101 failed: expected out=8, got out=%0d", out);
        assert (overflow == 1'b0)
        else $error("sel=0101 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 4'b0110
        input1 = 8'hB1;
        input2 = 8'h09;
        sel    = 4'b0110;
        #40;
        assert (out == 8'hA8)
        else $error("sel=0110 failed: expected out=A8, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=0110 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 4'b0111
        input1 = 8'h40;
        input2 = 8'h40;
        sel    = 4'b0111;
        #40;
        assert (out == 8'h00)
        else $error("sel=0111 failed: expected out=00, got out=%h", out);
        assert (overflow == 1'b1)
        else $error("sel=0111 failed: expected overflow=1, got overflow=%b", overflow);

        // Test sel = 4'b1000
        input1 = 8'h03;
        input2 = 8'h00;
        sel    = 4'b1000;
        #40;
        assert (out == 8'h01)
        else $error("sel=1000 failed: expected out=01, got out=%h", out);
        assert (overflow == 1'b1)
        else $error("sel=1000 failed: expected overflow=1, got overflow=%b", overflow);

        // Test sel = 4'b1001
        input1 = 8'hB1;
        input2 = 8'h00;
        sel    = 4'b1001;
        #40;
        assert (out == 8'h62)
        else $error("sel=1001 failed: expected out=62, got out=%h", out);
        assert (overflow == 1'b1)
        else $error("sel=1001 failed: expected overflow=1, got overflow=%b", overflow);

        // Test sel = 4'b1010
        input1 = 8'hB1;
        input2 = 8'h00;
        sel    = 4'b1010;
        #40;
        assert (out == 8'h1B)
        else $error("sel=1010 failed: expected out=1B, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=1010 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 4'b1011
        input1 = 8'hD0;
        input2 = 8'h00;
        sel    = 4'b1011;
        #40;
        assert (out == 8'h0B)
        else $error("sel=1011 failed: expected out=0B, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=1011 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 4'b1100
        input1 = 8'hD0;
        input2 = 8'h00;
        sel    = 4'b1100;
        #40;
        assert (out == 8'h00)
        else $error("sel=1100 failed: expected out=00, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=1100 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 4'b1101
        input1 = 8'hD0;
        input2 = 8'h00;
        sel    = 4'b1101;
        #40;
        assert (out == 8'h00)
        else $error("sel=1101 failed: expected out=00, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=1101 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 4'b1110
        input1 = 8'hD0;
        input2 = 8'h00;
        sel    = 4'b1110;
        #40;
        assert (out == 8'h00)
        else $error("sel=1110 failed: expected out=00, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=1110 failed: expected overflow=0, got overflow=%b", overflow);

        // Test sel = 4'b1111
        input1 = 8'hD0;
        input2 = 8'h00;
        sel    = 4'b1111;
        #40;
        assert (out == 8'h00)
        else $error("sel=1111 failed: expected out=00, got out=%h", out);
        assert (overflow == 1'b0)
        else $error("sel=1111 failed: expected overflow=0, got overflow=%b", overflow);



        $display("Simulation Finished!");
        $finish;

    end

endmodule
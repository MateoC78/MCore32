module alu_nwidth_tb;

    parameter WIDTH = 32;

    localparam logic [3:0] SEL_ADD      = 4'b0000;
    localparam logic [3:0] SEL_SUB      = 4'b1000;
    localparam logic [3:0] SEL_SLL      = 4'b0001;
    localparam logic [3:0] SEL_SLT      = 4'b0010;
    localparam logic [3:0] SEL_SLTU     = 4'b0011;
    localparam logic [3:0] SEL_XOR      = 4'b0100;
    localparam logic [3:0] SEL_SRL      = 4'b0101;
    localparam logic [3:0] SEL_SRA      = 4'b1101;
    localparam logic [3:0] SEL_OR       = 4'b0110;
    localparam logic [3:0] SEL_AND      = 4'b0111;

    logic [WIDTH-1:0] input1 = '0;
    logic [WIDTH-1:0] input2 = '0;
    logic [      3:0] sel = '0;
    logic [WIDTH-1:0] out;
    logic             overflow;

    integer errors = 0;

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

    // Apply inputs, wait, and compare both outputs
    task automatic check(input string            tag,
                         input logic [3:0]       s,
                         input logic [WIDTH-1:0] a,
                         input logic [WIDTH-1:0] b,
                         input logic [WIDTH-1:0] exp_out,
                         input logic             exp_ovf);
        input1 = a;
        input2 = b;
        sel    = s;
        #10;
        assert (out == exp_out)
        else begin
            $error("%s: %h, %h expected out=%h, got out=%h", tag, a, b, exp_out, out);
            errors++;
        end
        assert (overflow == exp_ovf)
        else begin
            $error("%s: %h, %h expected overflow=%b, got overflow=%b", tag, a, b, exp_ovf, overflow);
            errors++;
        end
    endtask

    initial begin

        // ADD
        check("ADD",          SEL_ADD,  32'h00000055, 32'h00000555, 32'h000005AA, 1'b0);
        check("ADD carry",    SEL_ADD,  32'hFFFFFFFF, 32'h00000001, 32'h00000000, 1'b1);

        // SUB
        check("SUB",          SEL_SUB,  32'h00009BAA, 32'h00000067, 32'h00009B43, 1'b0);
        check("SUB borrow",   SEL_SUB,  32'h00000001, 32'h00000002, 32'hFFFFFFFF, 1'b1);

        // SLL
        check("SLL",          SEL_SLL,  32'h0000000F, 32'h00000004, 32'h000000F0, 1'b0);
        check("SLL by 31",    SEL_SLL,  32'h00000001, 32'h0000001F, 32'h80000000, 1'b0);
        check("SLL low bits", SEL_SLL,  32'h00000001, 32'h00000021, 32'h00000002, 1'b0);

        // SLT (signed)
        check("SLT",          SEL_SLT,  32'h00000005, 32'h000000A9, 32'h00000001, 1'b0);
        check("SLT neg",      SEL_SLT,  32'hFFFFFFFF, 32'h00000005, 32'h00000001, 1'b0);
        check("SLT false",    SEL_SLT,  32'h00000005, 32'hFFFFFFFF, 32'h00000000, 1'b0);
        check("SLT equal",    SEL_SLT,  32'h00000007, 32'h00000007, 32'h00000000, 1'b0);

        // SLTU (unsigned)
        check("SLTU",         SEL_SLTU, 32'h00000005, 32'h000000A9, 32'h00000001, 1'b0);
        check("SLTU big",     SEL_SLTU, 32'hFFFFFFFF, 32'h00000005, 32'h00000000, 1'b0);
        check("SLTU vs big",  SEL_SLTU, 32'h00000005, 32'hFFFFFFFF, 32'h00000001, 1'b0);

        // XOR
        check("XOR",          SEL_XOR,  32'h0000FFFF, 32'h00000055, 32'h0000FFAA, 1'b0);
        check("XOR -1 (NOT)", SEL_XOR,  32'h0000BBBB, 32'hFFFFFFFF, 32'hFFFF4444, 1'b0);

        // SRL (logical, fills with 0)
        check("SRL",          SEL_SRL,  32'h000000F0, 32'h00000004, 32'h0000000F, 1'b0);
        check("SRL neg",      SEL_SRL,  32'h80000000, 32'h00000004, 32'h08000000, 1'b0);

        // SRA (arithmetic, fills with sign bit)
        check("SRA",          SEL_SRA,  32'h000000F0, 32'h00000004, 32'h0000000F, 1'b0);
        check("SRA neg",      SEL_SRA,  32'h80000000, 32'h00000004, 32'hF8000000, 1'b0);
        check("SRA by 31",    SEL_SRA,  32'h80000000, 32'h0000001F, 32'hFFFFFFFF, 1'b0);

        // OR
        check("OR",           SEL_OR,   32'h0000BBBB, 32'h00006789, 32'h0000FFBB, 1'b0);

        // AND
        check("AND",          SEL_AND,  32'hCCCCCCCC, 32'hDECDABCF, 32'hCCCC88CC, 1'b0);

        // Unused select code falls through to default
        check("unused sel",   4'b1111,  32'h12345678, 32'h87654321, 32'h00000000, 1'b0);

        if (errors == 0) $display("alu_tb PASSED");
        else             $display("alu_tb FAILED with %0d errors", errors);
        $finish;

    end

endmodule

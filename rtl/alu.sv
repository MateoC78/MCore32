module alu_nwidth #(
parameter WIDTH = 32)
(
input logic [WIDTH-1:0] input1,
input logic [WIDTH-1:0] input2,
input logic [2:0] sel,
output logic [WIDTH-1:0] out,
output logic overflow
);

    localparam logic [2:0] SEL_ADD      = 3'h0;
    localparam logic [2:0] SEL_SUB      = 3'h1;
    localparam logic [2:0] SEL_AND      = 3'h2;
    localparam logic [2:0] SEL_OR       = 3'h3;
    localparam logic [2:0] SEL_XOR      = 3'h4;
    localparam logic [2:0] SEL_NOT      = 3'h5;
    localparam logic [2:0] SEL_SLT      = 3'h6;

    logic [(2*WIDTH)-1:0] multiply_result;
    logic [WIDTH:0]       arithmetic_result;
    integer i;

    always_comb begin
        out               = '0;
        overflow          = 1'b0;
        multiply_result   = '0;
        arithmetic_result = '0;

        case (sel)
            SEL_OR: begin
                out = input1 | input2;
            end

            SEL_SUB: begin
                out = input1 - input2;
                overflow = (input1 < input2);
            end

            SEL_NOT: begin
                out = ~input1;
            end

            SEL_XOR: begin
                out = input1 ^ input2;
            end

            SEL_ADD: begin
                arithmetic_result = {1'b0, input1}
                                  + {1'b0, input2};
                out = arithmetic_result[WIDTH-1:0];
                overflow = arithmetic_result[WIDTH];
            end

            SEL_AND: begin
                out = input1 & input2;
            end

            SEL_SLT: begin
                out = ($signed(input1) < $signed(input2)) ? 1'b1 : 1'b0;
            end

            default: begin
                out = '0;
                overflow = 1'b0;
            end
        endcase
    end

endmodule
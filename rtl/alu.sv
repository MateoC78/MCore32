module alu_nwidth #(
parameter WIDTH = 32)
(
input logic [WIDTH-1:0] input1,
input logic [WIDTH-1:0] input2,
input logic [3:0] sel,
output logic [WIDTH-1:0] out,
output logic overflow
);

    localparam logic [3:0] SEL_MULTIPLY = 4'h0;
    localparam logic [3:0] SEL_OR       = 4'h1;
    localparam logic [3:0] SEL_REVERSE  = 4'h2;
    localparam logic [3:0] SEL_SUBTRACT = 4'h3;
    localparam logic [3:0] SEL_NOT      = 4'h4;
    localparam logic [3:0] SEL_SHIFT_L  = 4'h5;
    localparam logic [3:0] SEL_XOR      = 4'h6;
    localparam logic [3:0] SEL_SWAP     = 4'h7;
    localparam logic [3:0] SEL_ADD      = 4'h8;
    localparam logic [3:0] SEL_NOR      = 4'h9;
    localparam logic [3:0] SEL_SHIFT_R  = 4'hA;
    localparam logic [3:0] SEL_AND      = 4'hB;

    logic [(2*WIDTH)-1:0] multiply_result;
    logic [WIDTH:0]       arithmetic_result;
    integer i;

    always_comb begin
        out               = '0;
        overflow          = 1'b0;
        multiply_result   = '0;
        arithmetic_result = '0;

        case (sel)
            SEL_MULTIPLY: begin
                multiply_result = input1 * input2;
                out = multiply_result[WIDTH-1:0];
                overflow = |multiply_result[(2*WIDTH)-1:WIDTH];
            end

            SEL_OR: begin
                out = input1 | input2;
            end

            SEL_REVERSE: begin
                for (i = 0; i < WIDTH; i = i + 1)
                    out[i] = input1[WIDTH-1-i];
            end

            SEL_SUBTRACT: begin
                out = input1 - input2;
                overflow = (input1 < input2);
            end

            SEL_NOT: begin
                out = ~input1;
            end

            SEL_SHIFT_L: begin
                out = input1 << 1;
                overflow = input1[WIDTH-1];
            end

            SEL_XOR: begin
                out = input1 ^ input2;
            end

            SEL_SWAP: begin
                for (i = 0; i < WIDTH; i = i + 1)
                    out[i] = input1[(i + (WIDTH/2)) % WIDTH];
            end

            SEL_ADD: begin
                arithmetic_result = {1'b0, input1}
                                  + {1'b0, input2};
                out = arithmetic_result[WIDTH-1:0];
                overflow = arithmetic_result[WIDTH];
            end

            SEL_NOR: begin
                out = ~(input1 | input2);
            end

            SEL_SHIFT_R: begin
                out = input1 >> 1;
                overflow = input1[0];
            end

            SEL_AND: begin
                out = input1 & input2;
            end

            default: begin
                out = '0;
                overflow = 1'b0;
            end
        endcase
    end

endmodule
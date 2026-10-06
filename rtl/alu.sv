module alu #(
parameter WIDTH = 32)
(
input logic [WIDTH-1:0] input1,
input logic [WIDTH-1:0] input2,
input logic [3:0] sel,
output logic [WIDTH-1:0] out,
output logic overflow
);

    // sel = {funct7[5], funct3} from the RV32I encoding
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

    localparam SHAMT_WIDTH = $clog2(WIDTH);

    logic [WIDTH:0]           arithmetic_result;
    logic [SHAMT_WIDTH-1:0]   shamt;
    logic [(2*WIDTH)-1:0]     sra_result;

    // Shifts only use the low bits of input2
    assign shamt = input2[SHAMT_WIDTH-1:0];

    // SRA: sign-extend to double width, shift logically, keep the low half.
    // Avoids >>>, which ModelSim 10.5b gets wrong in parameterized modules.
    assign sra_result = {{WIDTH{input1[WIDTH-1]}}, input1} >> shamt;

    always_comb begin
        out               = '0;
        overflow          = 1'b0;
        arithmetic_result = '0;

        case (sel)
            SEL_ADD: begin
                arithmetic_result = {1'b0, input1}
                                  + {1'b0, input2};
                out = arithmetic_result[WIDTH-1:0];
                overflow = arithmetic_result[WIDTH];
            end

            SEL_SUB: begin
                out = input1 - input2;
                overflow = (input1 < input2);
            end

            SEL_SLL: begin
                out = input1 << shamt;
            end

            SEL_SLT: begin
                out = ($signed(input1) < $signed(input2)) ? 1'b1 : 1'b0;
            end

            SEL_SLTU: begin
                out = (input1 < input2) ? 1'b1 : 1'b0;
            end

            SEL_XOR: begin
                out = input1 ^ input2;
            end

            SEL_SRL: begin
                out = input1 >> shamt;
            end

            SEL_SRA: begin
                out = sra_result[WIDTH-1:0];
            end

            SEL_OR: begin
                out = input1 | input2;
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

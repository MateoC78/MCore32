module regfile (
    input  logic        clk,    //clock
    input  logic        rst,    //reset
    input  logic [4:0]  rs1,    //source register 1
    input  logic [4:0]  rs2,    //source register 2
    input  logic [4:0]  rd,     //destination register
    input  logic [31:0] wd,     //write data
    input  logic        we,     //write enable
    output logic [31:0] rd1,    //read data 1
    output logic [31:0] rd2     //read data 2
);

    logic [31:0] regs [31:0];

    // Read ports
    assign rd1 = (rs1 == 5'd0) ? 32'b0 : regs[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'b0 : regs[rs2];

    // Write port
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end else if (we) begin
            regs[rd] <= wd;
        end
    end

endmodule
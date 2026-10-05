// RV32I instruction decoder
//
// Purely combinational: takes one 32-bit instruction and produces the
// register addresses, the immediate, and the control signals for the
// register file, ALU, data memory and PC logic.
//
// Instruction formats (bit 31 on the left):
//
//          31        25 24    20 19    15 14  12 11       7 6       0
//   R-type | funct7    | rs2    | rs1    |funct3| rd        | opcode  |
//   I-type | imm[11:0]          | rs1    |funct3| rd        | opcode  |
//   S-type | imm[11:5] | rs2    | rs1    |funct3| imm[4:0]  | opcode  |
//   B-type |imm[12|10:5]| rs2   | rs1    |funct3|imm[4:1|11]| opcode  |
//   U-type | imm[31:12]                         | rd        | opcode  |
//   J-type | imm[20|10:1|11|19:12]              | rd        | opcode  |

module decoder (
    input  logic [31:0] instr,      // instruction to decode

    // Register file
    output logic [4:0]  rs1,        // source register 1
    output logic [4:0]  rs2,        // source register 2
    output logic [4:0]  rd,         // destination register
    output logic        reg_we,     // write rd at the end of this instruction

    // Immediate
    output logic [31:0] imm,        // sign-extended immediate for this format

    // ALU
    output logic [3:0]  alu_sel,    // {funct7[5], funct3}, see alu.sv
    output logic [1:0]  alu_a_sel,  // ALU input1: 0 = rs1, 1 = PC, 2 = zero
    output logic        alu_b_sel,  // ALU input2: 0 = rs2, 1 = imm

    // Data memory
    output logic        mem_re,     // load
    output logic        mem_we,     // store
    output logic [2:0]  mem_size,   // funct3: byte/half/word, signed/unsigned

    // Write-back
    output logic [1:0]  wb_sel,     // value written to rd: 0 = ALU, 1 = memory, 2 = PC+4

    // PC control
    output logic        branch,     // conditional branch (compare type is funct3)
    output logic        jal,        // jump to PC + imm
    output logic        jalr,       // jump to (rs1 + imm) with bit 0 cleared

    output logic        illegal     // opcode/funct not recognised
);

    // Opcodes (instr[6:0])
    localparam logic [6:0] OP_LUI    = 7'b0110111;
    localparam logic [6:0] OP_AUIPC  = 7'b0010111;
    localparam logic [6:0] OP_JAL    = 7'b1101111;
    localparam logic [6:0] OP_JALR   = 7'b1100111;
    localparam logic [6:0] OP_BRANCH = 7'b1100011;
    localparam logic [6:0] OP_LOAD   = 7'b0000011;
    localparam logic [6:0] OP_STORE  = 7'b0100011;
    localparam logic [6:0] OP_IMM    = 7'b0010011;
    localparam logic [6:0] OP_REG    = 7'b0110011;
    localparam logic [6:0] OP_FENCE  = 7'b0001111;
    localparam logic [6:0] OP_SYSTEM = 7'b1110011;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    // TODO: slice opcode, funct3 and funct7 out of instr

    // TODO: rs1, rs2 and rd are in the same place in every format,
    //       so they can be plain assigns

    // TODO: immediate generation
    //   - Pick the format from the opcode, then rebuild the immediate
    //     from the bit layout in the table at the top
    //   - Everything except U-type is sign-extended from instr[31]
    //   - B and J immediates have an implicit 0 as bit 0
    //   - U-type puts instr[31:12] in the top 20 bits, low 12 bits are 0
    //   - Consider a separate immgen module if this gets long

    always_comb begin
        // Safe defaults: a do-nothing instruction. Each case below
        // only needs to set the signals that differ from these.
        reg_we    = 1'b0;
        alu_sel   = 4'b0000;   // ADD
        alu_a_sel = 2'd0;      // rs1
        alu_b_sel = 1'b0;      // rs2
        mem_re    = 1'b0;
        mem_we    = 1'b0;
        mem_size  = 3'b000;
        wb_sel    = 2'd0;      // ALU
        branch    = 1'b0;
        jal       = 1'b0;
        jalr      = 1'b0;
        illegal   = 1'b0;

        case (opcode)
            // TODO OP_REG     (add, sub, sll, slt, sltu, xor, srl, sra, or, and)
            //   - rd = rs1 op rs2
            //   - alu_sel comes straight from {funct7[5], funct3}
            //   - illegal if funct7 isn't 0000000, or 0100000 for SUB/SRA

            // TODO OP_IMM     (addi, slti, sltiu, xori, ori, andi, slli, srli, srai)
            //   - rd = rs1 op imm
            //   - Careful: instr[30] is part of the immediate here, except
            //     for shifts. Only srai uses it as funct7[5]. addi must
            //     NOT turn into a subtract when the immediate is negative.

            // TODO OP_LOAD    (lb, lh, lw, lbu, lhu)
            //   - address = rs1 + imm, rd = memory data
            //   - mem_size = funct3

            // TODO OP_STORE   (sb, sh, sw)
            //   - address = rs1 + imm, memory = rs2
            //   - no register write

            // TODO OP_BRANCH  (beq, bne, blt, bge, bltu, bgeu)
            //   - target = PC + imm, taken depends on comparing rs1 and rs2
            //   - funct3 picks the comparison; decide whether the ALU
            //     or a separate comparator does it
            //   - no register write

            // TODO OP_JAL
            //   - rd = PC + 4, PC = PC + imm

            // TODO OP_JALR
            //   - rd = PC + 4, PC = (rs1 + imm) & ~1

            // TODO OP_LUI
            //   - rd = imm (U-type). Hint: zero + imm through the ALU

            // TODO OP_AUIPC
            //   - rd = PC + imm (U-type)

            // TODO OP_FENCE, OP_SYSTEM
            //   - Simple single-core option: treat FENCE as a no-op.
            //     ECALL/EBREAK can be no-ops or flagged until you add traps.

            default: begin
                illegal = 1'b1;
            end
        endcase
    end

endmodule

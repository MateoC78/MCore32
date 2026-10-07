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

    // PC control. For all three the ALU output is the target address.
    output logic        branch,     // conditional branch to PC + imm
    output logic [2:0]  branch_cond,// funct3: which rs1/rs2 comparison decides the branch
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
    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];
    // TODO: rs1, rs2 and rd are in the same place in every format,
    //       so they can be plain assigns
    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign rd  = instr[11:7];

    // Immediate generation
    //   - The format is picked from the opcode, then the immediate is
    //     rebuilt from the bit layout in the table at the top
    //   - Everything except U-type is sign-extended from instr[31]
    //   - B and J immediates have an implicit 0 as bit 0
    //   - U-type puts instr[31:12] in the top 20 bits, low 12 bits are 0
    always_comb begin
        case (opcode)
            // I-type
            OP_IMM, OP_LOAD, OP_JALR:
                imm = {{20{instr[31]}}, instr[31:20]};

            // S-type
            OP_STORE:
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // B-type
            OP_BRANCH:
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

            // U-type
            OP_LUI, OP_AUIPC:
                imm = {instr[31:12], 12'b0};

            // J-type
            OP_JAL:
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

            // R-type and anything else has no immediate
            default:
                imm = 32'b0;
        endcase
    end

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
        branch_cond = 3'b000;
        jal       = 1'b0;
        jalr      = 1'b0;
        illegal   = 1'b0;

        case (opcode)
            // TODO OP_REG     (add, sub, sll, slt, sltu, xor, srl, sra, or, and)
            //   - rd = rs1 op rs2
            //   - alu_sel comes straight from {funct7[5], funct3}
            //   - illegal if funct7 isn't 0000000, or 0100000 for SUB/SRA
            OP_REG: begin
                alu_sel   = {funct7[5], funct3};
                if (funct7 == 7'b0100000 && funct3 != 3'b000 && funct3 != 3'b101) begin
                    illegal = 1'b1;
                end else if (funct7 != 7'b0000000 && funct7 != 7'b0100000) begin
                    illegal = 1'b1;
                end else begin
                    reg_we    = 1'b1;
                    alu_a_sel = 2'd0;      // rs1
                    alu_b_sel = 1'b0;      // rs2
                end
            end

            // OP_IMM (addi, slti, sltiu, xori, ori, andi, slli, srli, srai)
            //   - rd = rs1 op imm
            //   - instr[30] is part of the immediate, except for shifts
            //     where only srai uses it as funct7[5]. Otherwise a
            //     negative addi would turn into a subtract.
            //   - Shift amount is imm[4:0], which the ALU already uses
            OP_IMM: begin
                if (funct3 == 3'b001 && funct7 != 7'b0000000) begin
                    illegal = 1'b1;    // slli
                end else if (funct3 == 3'b101 && funct7 != 7'b0000000 && funct7 != 7'b0100000) begin
                    illegal = 1'b1;    // srli / srai
                end else begin
                    alu_sel   = (funct3 == 3'b101) ? {funct7[5], funct3} : {1'b0, funct3};
                    reg_we    = 1'b1;
                    alu_a_sel = 2'd0;      // rs1
                    alu_b_sel = 1'b1;      // imm
                end
            end

            // OP_LOAD (lb, lh, lw, lbu, lhu)
            //   - address = rs1 + imm, rd = memory data
            //   - mem_size = funct3, the memory side does the byte select
            //     and sign/zero extension
            OP_LOAD: begin
                if (funct3 == 3'b011 || funct3 == 3'b110 || funct3 == 3'b111) begin
                    illegal = 1'b1;
                end else begin
                    alu_b_sel = 1'b1;      // rs1 + imm
                    mem_re    = 1'b1;
                    mem_size  = funct3;
                    wb_sel    = 2'd1;      // memory
                    reg_we    = 1'b1;
                end
            end

            // OP_STORE (sb, sh, sw)
            //   - address = rs1 + imm, memory = rs2
            //   - no register write
            OP_STORE: begin
                if (funct3 != 3'b000 && funct3 != 3'b001 && funct3 != 3'b010) begin
                    illegal = 1'b1;
                end else begin
                    alu_b_sel = 1'b1;      // rs1 + imm
                    mem_we    = 1'b1;
                    mem_size  = funct3;
                end
            end

            // OP_BRANCH (beq, bne, blt, bge, bltu, bgeu)
            //   - ALU computes the target PC + imm
            //   - A comparator outside the decoder compares rs1 and rs2
            //     using branch_cond and decides if the branch is taken
            //   - no register write
            OP_BRANCH: begin
                if (funct3 == 3'b010 || funct3 == 3'b011) begin
                    illegal = 1'b1;
                end else begin
                    alu_a_sel   = 2'd1;    // PC
                    alu_b_sel   = 1'b1;    // imm
                    branch      = 1'b1;
                    branch_cond = funct3;
                end
            end

            // OP_JAL
            //   - rd = PC + 4, PC = PC + imm (computed by the ALU)
            OP_JAL: begin
                alu_a_sel = 2'd1;      // PC
                alu_b_sel = 1'b1;      // imm
                jal       = 1'b1;
                wb_sel    = 2'd2;      // PC + 4
                reg_we    = 1'b1;
            end

            // OP_JALR
            //   - rd = PC + 4, PC = (rs1 + imm) & ~1
            //   - the PC logic clears bit 0 of the ALU result
            OP_JALR: begin
                if (funct3 != 3'b000) begin
                    illegal = 1'b1;
                end else begin
                    alu_b_sel = 1'b1;      // rs1 + imm
                    jalr      = 1'b1;
                    wb_sel    = 2'd2;      // PC + 4
                    reg_we    = 1'b1;
                end
            end

            // OP_LUI
            //   - rd = imm, done as zero + imm through the ALU
            OP_LUI: begin
                alu_a_sel = 2'd2;      // zero
                alu_b_sel = 1'b1;      // imm
                reg_we    = 1'b1;
            end

            // OP_AUIPC
            //   - rd = PC + imm
            OP_AUIPC: begin
                alu_a_sel = 2'd1;      // PC
                alu_b_sel = 1'b1;      // imm
                reg_we    = 1'b1;
            end

            // OP_FENCE
            //   - Orders memory accesses. With one core and no caches every
            //     access already happens in order, so it is a no-op.
            OP_FENCE: begin
                if (funct3 != 3'b000)
                    illegal = 1'b1;
            end

            // OP_SYSTEM
            //   - ECALL and EBREAK are no-ops until traps are added
            //   - CSR instructions (Zicsr) aren't supported yet, so illegal
            OP_SYSTEM: begin
                if (instr != 32'h00000073 && instr != 32'h00100073)
                    illegal = 1'b1;
            end

            default: begin
                illegal = 1'b1;
            end
        endcase
    end

endmodule

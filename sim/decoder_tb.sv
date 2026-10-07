module decoder_tb;

    // Opcodes
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

    // ALU select codes, same as alu.sv
    localparam logic [3:0] SEL_ADD  = 4'b0000;
    localparam logic [3:0] SEL_SUB  = 4'b1000;
    localparam logic [3:0] SEL_SLL  = 4'b0001;
    localparam logic [3:0] SEL_SLT  = 4'b0010;
    localparam logic [3:0] SEL_SLTU = 4'b0011;
    localparam logic [3:0] SEL_XOR  = 4'b0100;
    localparam logic [3:0] SEL_SRL  = 4'b0101;
    localparam logic [3:0] SEL_SRA  = 4'b1101;
    localparam logic [3:0] SEL_OR   = 4'b0110;
    localparam logic [3:0] SEL_AND  = 4'b0111;

    logic [31:0] instr = '0;
    logic [4:0]  rs1, rs2, rd;
    logic        reg_we;
    logic [31:0] imm;
    logic [3:0]  alu_sel;
    logic [1:0]  alu_a_sel;
    logic        alu_b_sel;
    logic        mem_re, mem_we;
    logic [2:0]  mem_size;
    logic [1:0]  wb_sel;
    logic        branch, jal, jalr;
    logic [2:0]  branch_cond;
    logic        illegal;

    integer errors = 0;
    integer i;

    // Instantiate DUT
    decoder UUT (
        .instr    (instr),
        .rs1      (rs1),
        .rs2      (rs2),
        .rd       (rd),
        .reg_we   (reg_we),
        .imm      (imm),
        .alu_sel  (alu_sel),
        .alu_a_sel(alu_a_sel),
        .alu_b_sel(alu_b_sel),
        .mem_re   (mem_re),
        .mem_we   (mem_we),
        .mem_size (mem_size),
        .wb_sel   (wb_sel),
        .branch   (branch),
        .branch_cond(branch_cond),
        .jal      (jal),
        .jalr     (jalr),
        .illegal  (illegal)
    );

    // Expected control outputs. Start from NOP and change only what the
    // instruction needs, the same way the decoder uses defaults.
    typedef struct packed {
        logic       reg_we;
        logic [3:0] alu_sel;
        logic [1:0] alu_a_sel;
        logic       alu_b_sel;
        logic       mem_re;
        logic       mem_we;
        logic [2:0] mem_size;
        logic [1:0] wb_sel;
        logic       branch;
        logic [2:0] branch_cond;
        logic       jal;
        logic       jalr;
        logic       illegal;
    } ctrl_t;

    localparam ctrl_t NOP = '{
        reg_we: 1'b0, alu_sel: SEL_ADD, alu_a_sel: 2'd0, alu_b_sel: 1'b0,
        mem_re: 1'b0, mem_we: 1'b0, mem_size: 3'b000, wb_sel: 2'd0,
        branch: 1'b0, branch_cond: 3'b000, jal: 1'b0, jalr: 1'b0, illegal: 1'b0
    };

    // Instruction encoders
    function automatic logic [31:0] r_type(input logic [6:0] funct7, input logic [4:0] rs2_i,
                                           input logic [4:0] rs1_i, input logic [2:0] funct3,
                                           input logic [4:0] rd_i);
        return {funct7, rs2_i, rs1_i, funct3, rd_i, OP_REG};
    endfunction

    function automatic logic [31:0] i_type(input logic [11:0] imm_i, input logic [4:0] rs1_i,
                                           input logic [2:0] funct3, input logic [4:0] rd_i,
                                           input logic [6:0] op);
        return {imm_i, rs1_i, funct3, rd_i, op};
    endfunction

    function automatic logic [31:0] s_type(input logic [11:0] imm_i, input logic [4:0] rs2_i,
                                           input logic [4:0] rs1_i, input logic [2:0] funct3);
        return {imm_i[11:5], rs2_i, rs1_i, funct3, imm_i[4:0], OP_STORE};
    endfunction

    function automatic logic [31:0] b_type(input logic [12:0] imm_i, input logic [4:0] rs2_i,
                                           input logic [4:0] rs1_i, input logic [2:0] funct3);
        return {imm_i[12], imm_i[10:5], rs2_i, rs1_i, funct3, imm_i[4:1], imm_i[11], OP_BRANCH};
    endfunction

    function automatic logic [31:0] u_type(input logic [19:0] imm_i, input logic [4:0] rd_i,
                                           input logic [6:0] op);
        return {imm_i, rd_i, op};
    endfunction

    function automatic logic [31:0] j_type(input logic [20:0] imm_i, input logic [4:0] rd_i);
        return {imm_i[20], imm_i[10:1], imm_i[11], imm_i[19:12], rd_i, OP_JAL};
    endfunction

    // Compare one output, report and count a mismatch
    `define CHECK(name, got, exp) \
        assert ((got) === (exp)) \
        else begin \
            $error("%s (%h): %s expected %h, got %h", tag, in, name, exp, got); \
            errors++; \
        end

    // Apply an instruction and compare every control output
    task automatic check_ctrl(input string tag, input logic [31:0] in, input ctrl_t exp);
        instr = in;
        #10;
        `CHECK("illegal",   illegal,   exp.illegal)
        `CHECK("reg_we",    reg_we,    exp.reg_we)
        `CHECK("alu_sel",   alu_sel,   exp.alu_sel)
        `CHECK("alu_a_sel", alu_a_sel, exp.alu_a_sel)
        `CHECK("alu_b_sel", alu_b_sel, exp.alu_b_sel)
        `CHECK("mem_re",    mem_re,    exp.mem_re)
        `CHECK("mem_we",    mem_we,    exp.mem_we)
        `CHECK("mem_size",  mem_size,  exp.mem_size)
        `CHECK("wb_sel",    wb_sel,    exp.wb_sel)
        `CHECK("branch",    branch,    exp.branch)
        `CHECK("branch_cond", branch_cond, exp.branch_cond)
        `CHECK("jal",       jal,       exp.jal)
        `CHECK("jalr",      jalr,      exp.jalr)
    endtask

    // Illegal instruction: flagged, and must not write a register or memory.
    // The other outputs don't matter.
    task automatic check_illegal(input string tag, input logic [31:0] in);
        instr = in;
        #10;
        `CHECK("illegal", illegal, 1'b1)
        `CHECK("reg_we",  reg_we,  1'b0)
        `CHECK("mem_we",  mem_we,  1'b0)
    endtask

    // Check the register fields (call after check_ctrl)
    task automatic check_regs(input string tag, input logic [31:0] in,
                              input logic [4:0] exp_rs1, input logic [4:0] exp_rs2,
                              input logic [4:0] exp_rd);
        `CHECK("rs1", rs1, exp_rs1)
        `CHECK("rs2", rs2, exp_rs2)
        `CHECK("rd",  rd,  exp_rd)
    endtask

    // Check only rd, for U/J-type where rs1/rs2 bits are part of the immediate
    task automatic check_rd(input string tag, input logic [31:0] in, input logic [4:0] exp_rd);
        `CHECK("rd", rd, exp_rd)
    endtask

    // Check the immediate (call after check_ctrl)
    task automatic check_imm(input string tag, input logic [31:0] in, input logic [31:0] exp_imm);
        `CHECK("imm", imm, exp_imm)
    endtask

    // ------------------------------------------------------------------
    // OP_REG: add, sub, sll, slt, sltu, xor, srl, sra, or, and
    // ------------------------------------------------------------------
    task automatic test_op_reg();
        ctrl_t exp;
        logic [3:0]  sels   [10] = '{SEL_ADD, SEL_SUB, SEL_SLL, SEL_SLT, SEL_SLTU,
                                     SEL_XOR, SEL_SRL, SEL_SRA, SEL_OR,  SEL_AND};
        string       names  [10] = '{"add", "sub", "sll", "slt", "sltu",
                                     "xor", "srl", "sra", "or",  "and"};
        logic [2:0]  f3_bad [6]  = '{3'b001, 3'b010, 3'b011, 3'b100, 3'b110, 3'b111};

        exp         = NOP;
        exp.reg_we  = 1'b1;

        // Hand-assembled encodings
        exp.alu_sel = SEL_ADD;
        check_ctrl("add x3, x1, x2",    32'h002081B3, exp);
        check_regs("add x3, x1, x2",    32'h002081B3, 5'd1, 5'd2, 5'd3);

        exp.alu_sel = SEL_SUB;
        check_ctrl("sub x5, x6, x7",    32'h407302B3, exp);
        check_regs("sub x5, x6, x7",    32'h407302B3, 5'd6, 5'd7, 5'd5);

        exp.alu_sel = SEL_SRA;
        check_ctrl("sra x10, x11, x12", 32'h40C5D533, exp);
        check_regs("sra x10, x11, x12", 32'h40C5D533, 5'd11, 5'd12, 5'd10);

        // Every operation, built with the encoder
        for (i = 0; i < 10; i++) begin
            exp.alu_sel = sels[i];
            check_ctrl(names[i], r_type({1'b0, sels[i][3], 5'b0}, 5'd9, 5'd8, sels[i][2:0], 5'd7), exp);
        end

        // Register fields at the edges (x0 and x31)
        exp.alu_sel = SEL_ADD;
        check_ctrl("add x31, x0, x31", r_type(7'b0000000, 5'd31, 5'd0, 3'b000, 5'd31), exp);
        check_regs("add x31, x0, x31", r_type(7'b0000000, 5'd31, 5'd0, 3'b000, 5'd31), 5'd0, 5'd31, 5'd31);
        check_ctrl("add x0, x31, x0",  r_type(7'b0000000, 5'd0, 5'd31, 3'b000, 5'd0), exp);
        check_regs("add x0, x31, x0",  r_type(7'b0000000, 5'd0, 5'd31, 3'b000, 5'd0), 5'd31, 5'd0, 5'd0);

        // Illegal: funct7 values RV32I doesn't define (0000001 is the M extension)
        check_illegal("mul (funct7=0000001)", r_type(7'b0000001, 5'd2, 5'd1, 3'b000, 5'd3));
        check_illegal("funct7=1111111",       r_type(7'b1111111, 5'd2, 5'd1, 3'b000, 5'd3));

        // Illegal: funct7=0100000 is only valid for sub (000) and sra (101)
        for (i = 0; i < 6; i++)
            check_illegal($sformatf("funct7=0100000 funct3=%b", f3_bad[i]),
                          r_type(7'b0100000, 5'd2, 5'd1, f3_bad[i], 5'd3));
    endtask

    // ------------------------------------------------------------------
    // OP_IMM: addi, slti, sltiu, xori, ori, andi, slli, srli, srai
    // ------------------------------------------------------------------
    task automatic test_op_imm();
        ctrl_t exp;
        logic [3:0]  sels  [6] = '{SEL_ADD, SEL_SLT, SEL_SLTU, SEL_XOR, SEL_OR, SEL_AND};
        string       names [6] = '{"addi", "slti", "sltiu", "xori", "ori", "andi"};
        logic [11:0] imms  [4] = '{12'h005, 12'hFF0, 12'h7FF, 12'h800};

        exp           = NOP;
        exp.reg_we    = 1'b1;
        exp.alu_b_sel = 1'b1;

        // Hand-assembled encodings
        exp.alu_sel = SEL_ADD;
        check_ctrl("addi x1, x0, 5",     32'h00500093, exp);
        check_regs("addi x1, x0, 5",     32'h00500093, 5'd0, 5'd5, 5'd1);
        check_imm ("addi x1, x0, 5",     32'h00500093, 32'h00000005);
        check_ctrl("addi x2, x2, -16",   32'hFF010113, exp);
        check_imm ("addi x2, x2, -16",   32'hFF010113, 32'hFFFFFFF0);

        // instr[30] is 1 here because of the immediate, must stay ADD
        check_ctrl("addi x5, x6, -1024", 32'hC0030293, exp);
        check_imm ("addi x5, x6, -1024", 32'hC0030293, 32'hFFFFFC00);

        exp.alu_sel = SEL_SRA;
        check_ctrl("srai x5, x6, 3",     32'h40335293, exp);
        check_imm ("srai x5, x6, 3",     32'h40335293, 32'h00000403);

        // Non-shift ops with a negative immediate (instr[30] = 1)
        for (i = 0; i < 6; i++) begin
            exp.alu_sel = sels[i];
            check_ctrl(names[i], i_type(12'hC00, 5'd8, sels[i][2:0], 5'd7, OP_IMM), exp);
        end

        // Shifts
        exp.alu_sel = SEL_SLL;
        check_ctrl("slli", i_type({7'b0000000, 5'd31}, 5'd8, 3'b001, 5'd7, OP_IMM), exp);
        exp.alu_sel = SEL_SRL;
        check_ctrl("srli", i_type({7'b0000000, 5'd31}, 5'd8, 3'b101, 5'd7, OP_IMM), exp);
        exp.alu_sel = SEL_SRA;
        check_ctrl("srai", i_type({7'b0100000, 5'd31}, 5'd8, 3'b101, 5'd7, OP_IMM), exp);

        // Immediate range: 5, -16, max 2047, min -2048
        exp.alu_sel = SEL_ADD;
        for (i = 0; i < 4; i++) begin
            check_ctrl("addi range", i_type(imms[i], 5'd1, 3'b000, 5'd1, OP_IMM), exp);
            check_imm ("addi range", i_type(imms[i], 5'd1, 3'b000, 5'd1, OP_IMM), {{20{imms[i][11]}}, imms[i]});
        end

        // Illegal shift encodings
        check_illegal("slli funct7=0100000", i_type({7'b0100000, 5'd1}, 5'd8, 3'b001, 5'd7, OP_IMM));
        check_illegal("srli funct7=0000001", i_type({7'b0000001, 5'd1}, 5'd8, 3'b101, 5'd7, OP_IMM));
    endtask

    // ------------------------------------------------------------------
    // OP_LOAD: lb, lh, lw, lbu, lhu
    // ------------------------------------------------------------------
    task automatic test_op_load();
        ctrl_t exp;
        logic [2:0] f3_ok  [5] = '{3'b000, 3'b001, 3'b010, 3'b100, 3'b101};
        string      names  [5] = '{"lb", "lh", "lw", "lbu", "lhu"};
        logic [2:0] f3_bad [3] = '{3'b011, 3'b110, 3'b111};

        exp           = NOP;
        exp.reg_we    = 1'b1;
        exp.alu_b_sel = 1'b1;
        exp.mem_re    = 1'b1;
        exp.wb_sel    = 2'd1;

        exp.mem_size = 3'b010;
        check_ctrl("lw x1, 28(x2)", 32'h01C12083, exp);
        check_regs("lw x1, 28(x2)", 32'h01C12083, 5'd2, 5'd28, 5'd1);
        check_imm ("lw x1, 28(x2)", 32'h01C12083, 32'd28);

        for (i = 0; i < 5; i++) begin
            exp.mem_size = f3_ok[i];
            check_ctrl(names[i], i_type(12'hFFC, 5'd2, f3_ok[i], 5'd5, OP_LOAD), exp);
            check_imm (names[i], i_type(12'hFFC, 5'd2, f3_ok[i], 5'd5, OP_LOAD), 32'hFFFFFFFC);
        end

        for (i = 0; i < 3; i++)
            check_illegal($sformatf("load funct3=%b", f3_bad[i]), i_type(12'h0, 5'd2, f3_bad[i], 5'd5, OP_LOAD));
    endtask

    // ------------------------------------------------------------------
    // OP_STORE: sb, sh, sw
    // ------------------------------------------------------------------
    task automatic test_op_store();
        ctrl_t exp;
        string      names [3] = '{"sb", "sh", "sw"};
        logic [11:0] imms [4] = '{12'h01C, 12'hFFC, 12'h7FF, 12'h800};

        exp           = NOP;
        exp.alu_b_sel = 1'b1;
        exp.mem_we    = 1'b1;

        exp.mem_size = 3'b010;
        check_ctrl("sw x1, 28(x2)", 32'h00112E23, exp);
        check_regs("sw x1, 28(x2)", 32'h00112E23, 5'd2, 5'd1, 5'd28);
        check_imm ("sw x1, 28(x2)", 32'h00112E23, 32'd28);

        for (i = 0; i < 3; i++) begin
            exp.mem_size = i;
            check_ctrl(names[i], s_type(12'h010, 5'd6, 5'd2, i), exp);
        end

        // Immediate range: 28, -4, max 2047, min -2048
        exp.mem_size = 3'b010;
        for (i = 0; i < 4; i++) begin
            check_ctrl("sw range", s_type(imms[i], 5'd6, 5'd2, 3'b010), exp);
            check_imm ("sw range", s_type(imms[i], 5'd6, 5'd2, 3'b010), {{20{imms[i][11]}}, imms[i]});
        end

        for (i = 3; i < 8; i++)
            check_illegal($sformatf("store funct3=%b", i[2:0]), s_type(12'h0, 5'd6, 5'd2, i));
    endtask

    // ------------------------------------------------------------------
    // OP_BRANCH: beq, bne, blt, bge, bltu, bgeu
    // ------------------------------------------------------------------
    task automatic test_op_branch();
        ctrl_t exp;
        logic [2:0]  f3_ok [6] = '{3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111};
        string       names [6] = '{"beq", "bne", "blt", "bge", "bltu", "bgeu"};
        logic [12:0] imms  [4] = '{13'h0008, 13'h1FFC, 13'h0FFE, 13'h1000};

        exp           = NOP;
        exp.alu_a_sel = 2'd1;
        exp.alu_b_sel = 1'b1;
        exp.branch    = 1'b1;

        exp.branch_cond = 3'b000;
        check_ctrl("beq x1, x2, +8", 32'h00208463, exp);
        check_regs("beq x1, x2, +8", 32'h00208463, 5'd1, 5'd2, 5'd8);
        check_imm ("beq x1, x2, +8", 32'h00208463, 32'd8);

        exp.branch_cond = 3'b001;
        check_ctrl("bne x5, x0, -4", 32'hFE029EE3, exp);
        check_imm ("bne x5, x0, -4", 32'hFE029EE3, 32'hFFFFFFFC);

        for (i = 0; i < 6; i++) begin
            exp.branch_cond = f3_ok[i];
            check_ctrl(names[i], b_type(13'h0010, 5'd2, 5'd1, f3_ok[i]), exp);
        end

        // Immediate range: 8, -4, max 4094, min -4096
        exp.branch_cond = 3'b000;
        for (i = 0; i < 4; i++) begin
            check_ctrl("beq range", b_type(imms[i], 5'd2, 5'd1, 3'b000), exp);
            check_imm ("beq range", b_type(imms[i], 5'd2, 5'd1, 3'b000), {{19{imms[i][12]}}, imms[i]});
        end

        check_illegal("branch funct3=010", b_type(13'h8, 5'd2, 5'd1, 3'b010));
        check_illegal("branch funct3=011", b_type(13'h8, 5'd2, 5'd1, 3'b011));
    endtask

    // ------------------------------------------------------------------
    // OP_JAL
    // ------------------------------------------------------------------
    task automatic test_op_jal();
        ctrl_t exp;
        logic [20:0] imms [4] = '{21'h000800, 21'h1FFFFC, 21'h0FFFFE, 21'h100000};

        exp           = NOP;
        exp.reg_we    = 1'b1;
        exp.alu_a_sel = 2'd1;
        exp.alu_b_sel = 1'b1;
        exp.jal       = 1'b1;
        exp.wb_sel    = 2'd2;

        check_ctrl("jal x1, +2048", 32'h001000EF, exp);
        check_imm ("jal x1, +2048", 32'h001000EF, 32'h00000800);
        check_rd  ("jal x1, +2048", 32'h001000EF, 5'd1);

        check_ctrl("j . (jal x0, 0)", 32'h0000006F, exp);
        check_imm ("j . (jal x0, 0)", 32'h0000006F, 32'h00000000);

        // Immediate range: 2048, -4, max 1048574, min -1048576
        for (i = 0; i < 4; i++) begin
            check_ctrl("jal range", j_type(imms[i], 5'd1), exp);
            check_imm ("jal range", j_type(imms[i], 5'd1), {{11{imms[i][20]}}, imms[i]});
        end
    endtask

    // ------------------------------------------------------------------
    // OP_JALR
    // ------------------------------------------------------------------
    task automatic test_op_jalr();
        ctrl_t exp;

        exp           = NOP;
        exp.reg_we    = 1'b1;
        exp.alu_b_sel = 1'b1;
        exp.jalr      = 1'b1;
        exp.wb_sel    = 2'd2;

        check_ctrl("ret (jalr x0, 0(x1))", 32'h00008067, exp);
        check_regs("ret (jalr x0, 0(x1))", 32'h00008067, 5'd1, 5'd0, 5'd0);
        check_imm ("ret (jalr x0, 0(x1))", 32'h00008067, 32'h0);

        check_ctrl("jalr x1, -8(x5)", i_type(12'hFF8, 5'd5, 3'b000, 5'd1, OP_JALR), exp);
        check_imm ("jalr x1, -8(x5)", i_type(12'hFF8, 5'd5, 3'b000, 5'd1, OP_JALR), 32'hFFFFFFF8);

        check_illegal("jalr funct3=001", i_type(12'h0, 5'd1, 3'b001, 5'd0, OP_JALR));
    endtask

    // ------------------------------------------------------------------
    // OP_LUI
    // ------------------------------------------------------------------
    task automatic test_op_lui();
        ctrl_t exp;

        exp           = NOP;
        exp.reg_we    = 1'b1;
        exp.alu_a_sel = 2'd2;
        exp.alu_b_sel = 1'b1;

        check_ctrl("lui x10, 0x12345", 32'h12345537, exp);
        check_imm ("lui x10, 0x12345", 32'h12345537, 32'h12345000);
        check_rd  ("lui x10, 0x12345", 32'h12345537, 5'd10);

        check_ctrl("lui x1, 0xFFFFF", u_type(20'hFFFFF, 5'd1, OP_LUI), exp);
        check_imm ("lui x1, 0xFFFFF", u_type(20'hFFFFF, 5'd1, OP_LUI), 32'hFFFFF000);
    endtask

    // ------------------------------------------------------------------
    // OP_AUIPC
    // ------------------------------------------------------------------
    task automatic test_op_auipc();
        ctrl_t exp;

        exp           = NOP;
        exp.reg_we    = 1'b1;
        exp.alu_a_sel = 2'd1;
        exp.alu_b_sel = 1'b1;

        check_ctrl("auipc x1, 0", 32'h00000097, exp);
        check_imm ("auipc x1, 0", 32'h00000097, 32'h0);

        check_ctrl("auipc x1, 0x80000", u_type(20'h80000, 5'd1, OP_AUIPC), exp);
        check_imm ("auipc x1, 0x80000", u_type(20'h80000, 5'd1, OP_AUIPC), 32'h80000000);
    endtask

    // ------------------------------------------------------------------
    // OP_FENCE, OP_SYSTEM, unknown opcodes
    // ------------------------------------------------------------------
    task automatic test_op_misc();
        check_ctrl("fence",          32'h0FF0000F, NOP);
        check_ctrl("ecall",          32'h00000073, NOP);
        check_ctrl("ebreak",         32'h00100073, NOP);
        check_illegal("fence.i",     32'h0000100F);
        check_illegal("csrrw",       32'h30001073);
        check_illegal("all zeros",   32'h00000000);
        check_illegal("all ones",    32'hFFFFFFFF);
        check_illegal("opcode 1111011", 32'h0000007B);
    endtask

    initial begin

        test_op_reg();
        test_op_imm();
        test_op_load();
        test_op_store();
        test_op_branch();
        test_op_jal();
        test_op_jalr();
        test_op_lui();
        test_op_auipc();
        test_op_misc();

        if (errors == 0) $display("decoder_tb PASSED");
        else             $display("decoder_tb FAILED with %0d errors", errors);
        $finish;

    end

endmodule

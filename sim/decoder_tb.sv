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
        logic       jal;
        logic       jalr;
        logic       illegal;
    } ctrl_t;

    localparam ctrl_t NOP = '{
        reg_we: 1'b0, alu_sel: SEL_ADD, alu_a_sel: 2'd0, alu_b_sel: 1'b0,
        mem_re: 1'b0, mem_we: 1'b0, mem_size: 3'b000, wb_sel: 2'd0,
        branch: 1'b0, jal: 1'b0, jalr: 1'b0, illegal: 1'b0
    };

    // Instruction encoders
    function automatic logic [31:0] r_type(input logic [6:0] funct7, input logic [4:0] rs2_i,
                                           input logic [4:0] rs1_i, input logic [2:0] funct3,
                                           input logic [4:0] rd_i);
        return {funct7, rs2_i, rs1_i, funct3, rd_i, OP_REG};
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

        // Hand-assembled encodings, checked against an assembler
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
    // TODO: add one task per opcode as you finish it, e.g.
    //   task automatic test_op_imm();    ...  endtask
    //   task automatic test_op_load();   ...  endtask
    // ------------------------------------------------------------------

    initial begin

        // Enable each opcode's tests once that part of the decoder is done
        test_op_reg();
        // test_op_imm();
        // test_op_load();
        // test_op_store();
        // test_op_branch();
        // test_op_jal();
        // test_op_jalr();
        // test_op_lui();
        // test_op_auipc();

        if (errors == 0) $display("decoder_tb PASSED");
        else             $display("decoder_tb FAILED with %0d errors", errors);
        $finish;

    end

endmodule

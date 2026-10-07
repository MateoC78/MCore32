// RV32I single-cycle core
//
// Every instruction finishes in one clock cycle. Memories live outside the
// core and connect through two ports, so they can be swapped for a bus with
// peripherals later without touching the core.
//
// Timing within one cycle:
//
//   posedge  PC updates. Instruction memory registers imem_addr (the next PC)
//            on the same edge, so the new instruction appears straight away.
//   ......   Decode, register read, ALU computes the data address.
//   negedge  Data memory reads/writes using dmem_addr.
//   ......   Load data is aligned and extended, next PC is computed.
//   posedge  Register file writes rd, PC updates, repeat.
//
// Because the data memory gets half a cycle on each side, the core runs at
// roughly half the speed a fully pipelined design would. That is the price
// of the simple single-cycle structure.
//
// Wait states: during a load or store the core checks dmem_ready at the
// next posedge. If it is low the core stalls (PC, register write and
// instruction fetch all hold) and keeps the request on the bus until a
// cycle where dmem_ready is high. A device must only perform a store in a
// cycle where it drives dmem_ready high, so each store happens once.
// Memory that always answers in time can tie dmem_ready to 1.

module core #(
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
) (
    input  logic        clk,
    input  logic        rst,

    // Instruction memory: must register imem_addr on posedge clk
    output logic [31:0] imem_addr,     // byte address of the NEXT instruction
    input  logic [31:0] imem_rdata,    // instruction at the current PC

    // Data memory: must read/write on negedge clk
    output logic [31:0] dmem_addr,     // byte address
    output logic [31:0] dmem_wdata,    // store data, already shifted into the right byte lane
    output logic [3:0]  dmem_be,       // byte enables for stores
    output logic        dmem_we,       // store
    output logic        dmem_re,       // load (not needed by plain RAM, useful for peripherals)
    input  logic [31:0] dmem_rdata,    // full word at dmem_addr
    input  logic        dmem_ready,    // access completes this cycle, low = stall

    output logic        illegal        // current instruction is not valid RV32I
);

    // ------------------------------------------------------------------
    // Program counter
    // ------------------------------------------------------------------
    logic [31:0] pc;
    logic [31:0] pc_plus4;
    logic [31:0] pc_next;
    logic        stall;

    always_ff @(posedge clk or posedge rst) begin
        if (rst)        pc <= RESET_VECTOR;
        else if (!stall) pc <= pc_next;
    end

    assign pc_plus4 = pc + 32'd4;

    // During reset, fetch the reset vector so the first instruction is
    // ready as soon as reset is released. While stalled, fetch the
    // current PC again so the same instruction stays on imem_rdata.
    always_comb begin
        if (rst)        imem_addr = RESET_VECTOR;
        else if (stall) imem_addr = pc;
        else            imem_addr = pc_next;
    end

    // ------------------------------------------------------------------
    // Decode
    // ------------------------------------------------------------------
    logic [31:0] instr;
    logic [4:0]  rs1, rs2, rd;
    logic [31:0] imm;
    logic        reg_we;
    logic [3:0]  alu_sel;
    logic [1:0]  alu_a_sel;
    logic        alu_b_sel;
    logic        mem_re, mem_we;
    logic [2:0]  mem_size;
    logic [1:0]  wb_sel;
    logic        branch;
    logic [2:0]  branch_cond;
    logic        jal, jalr;

    assign instr = imem_rdata;

    decoder u_decoder (
        .instr      (instr),
        .rs1        (rs1),
        .rs2        (rs2),
        .rd         (rd),
        .reg_we     (reg_we),
        .imm        (imm),
        .alu_sel    (alu_sel),
        .alu_a_sel  (alu_a_sel),
        .alu_b_sel  (alu_b_sel),
        .mem_re     (mem_re),
        .mem_we     (mem_we),
        .mem_size   (mem_size),
        .wb_sel     (wb_sel),
        .branch     (branch),
        .branch_cond(branch_cond),
        .jal        (jal),
        .jalr       (jalr),
        .illegal    (illegal)
    );

    // ------------------------------------------------------------------
    // Register file
    // ------------------------------------------------------------------
    logic [31:0] rs1_data, rs2_data;
    logic [31:0] wb_data;

    regfile u_regfile (
        .clk(clk),
        .rst(rst),
        .rs1(rs1),
        .rs2(rs2),
        .rd (rd),
        .wd (wb_data),
        .we (reg_we & ~stall),      // hold the write until a load has its data
        .rd1(rs1_data),
        .rd2(rs2_data)
    );

    // ------------------------------------------------------------------
    // ALU
    // ------------------------------------------------------------------
    logic [31:0] alu_a, alu_b, alu_out;
    logic        alu_overflow;     // unused by RV32I

    always_comb begin
        case (alu_a_sel)
            2'd0:    alu_a = rs1_data;
            2'd1:    alu_a = pc;
            default: alu_a = 32'b0;
        endcase
    end

    assign alu_b = alu_b_sel ? imm : rs2_data;

    alu #(
        .WIDTH(32)
    ) u_alu (
        .input1  (alu_a),
        .input2  (alu_b),
        .sel     (alu_sel),
        .out     (alu_out),
        .overflow(alu_overflow)
    );

    // ------------------------------------------------------------------
    // Branch comparator
    // ------------------------------------------------------------------
    logic branch_taken;

    always_comb begin
        case (branch_cond)
            3'b000:  branch_taken = (rs1_data == rs2_data);                     // beq
            3'b001:  branch_taken = (rs1_data != rs2_data);                     // bne
            3'b100:  branch_taken = ($signed(rs1_data) <  $signed(rs2_data));   // blt
            3'b101:  branch_taken = ($signed(rs1_data) >= $signed(rs2_data));   // bge
            3'b110:  branch_taken = (rs1_data <  rs2_data);                     // bltu
            3'b111:  branch_taken = (rs1_data >= rs2_data);                     // bgeu
            default: branch_taken = 1'b0;
        endcase
    end

    // ------------------------------------------------------------------
    // Next PC
    // For branches and jumps the ALU has already computed the target
    // ------------------------------------------------------------------
    always_comb begin
        if (jalr)
            pc_next = {alu_out[31:1], 1'b0};
        else if (jal || (branch && branch_taken))
            pc_next = alu_out;
        else
            pc_next = pc_plus4;
    end

    // ------------------------------------------------------------------
    // Load/store alignment
    // Memory is 32 bits wide. Stores place the byte/halfword in the right
    // lane and set byte enables, loads pick it back out and extend it.
    // Misaligned accesses aren't handled (spec allows trapping instead).
    // ------------------------------------------------------------------
    logic [1:0]  byte_off;
    logic [31:0] load_data;

    assign byte_off   = alu_out[1:0];
    assign dmem_addr  = alu_out;
    assign dmem_we    = mem_we & ~rst;
    assign dmem_re    = mem_re & ~rst;

    // Stall while a load/store is waiting for the memory/peripheral
    assign stall      = (dmem_re | dmem_we) & ~dmem_ready;

    // Store data and byte enables
    always_comb begin
        case (mem_size[1:0])
            2'b00: begin    // sb
                dmem_wdata = {4{rs2_data[7:0]}};
                dmem_be    = 4'b0001 << byte_off;
            end
            2'b01: begin    // sh
                dmem_wdata = {2{rs2_data[15:0]}};
                dmem_be    = byte_off[1] ? 4'b1100 : 4'b0011;
            end
            default: begin  // sw
                dmem_wdata = rs2_data;
                dmem_be    = 4'b1111;
            end
        endcase
    end

    // Load extraction and sign/zero extension
    logic [7:0]  load_byte;
    logic [15:0] load_half;

    always_comb begin
        case (byte_off)
            2'd0:    load_byte = dmem_rdata[7:0];
            2'd1:    load_byte = dmem_rdata[15:8];
            2'd2:    load_byte = dmem_rdata[23:16];
            default: load_byte = dmem_rdata[31:24];
        endcase

        load_half = byte_off[1] ? dmem_rdata[31:16] : dmem_rdata[15:0];

        case (mem_size)
            3'b000:  load_data = {{24{load_byte[7]}},  load_byte};   // lb
            3'b001:  load_data = {{16{load_half[15]}}, load_half};   // lh
            3'b100:  load_data = {24'b0, load_byte};                 // lbu
            3'b101:  load_data = {16'b0, load_half};                 // lhu
            default: load_data = dmem_rdata;                         // lw
        endcase
    end

    // ------------------------------------------------------------------
    // Write-back
    // ------------------------------------------------------------------
    always_comb begin
        case (wb_sel)
            2'd1:    wb_data = load_data;
            2'd2:    wb_data = pc_plus4;
            default: wb_data = alu_out;
        endcase
    end

endmodule

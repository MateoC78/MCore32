module core_tb;

    // Path is relative to the directory vsim is run from (the project root)
    parameter string PROGRAM = "sim/programs/core_test.hex";

    // Extra cycles the data memory takes per load/store (0 = no stalls).
    // Override from the command line: vsim -gWAIT_STATES=3 ...
    parameter int WAIT_STATES = 0;

    localparam int MAX_CYCLES = 500;
    localparam int NUM_MEM_OPS = 9;     // loads + stores in core_test.hex
    localparam int NUM_STORES  = 3;

    logic        clk = 1'b0;
    logic        rst = 1'b1;

    logic [31:0] imem_addr, imem_rdata;
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic [3:0]  dmem_be;
    logic        dmem_we, dmem_re;
    logic        dmem_ready;
    logic        illegal;

    integer errors = 0;
    integer cycles = 0;
    integer stall_cycles = 0;
    integer stores = 0;
    integer wait_cnt = 0;

    always #5 clk = ~clk;

    // Instantiate DUT
    core UUT (
        .clk       (clk),
        .rst       (rst),
        .imem_addr (imem_addr),
        .imem_rdata(imem_rdata),
        .dmem_addr (dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_be   (dmem_be),
        .dmem_we   (dmem_we),
        .dmem_re   (dmem_re),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),
        .illegal   (illegal)
    );

    imem #(
        .DEPTH    (1024),
        .INIT_FILE(PROGRAM)
    ) u_imem (
        .clk    (clk),
        .addr   (imem_addr),
        .rdata  (imem_rdata),
        .d_addr (32'h0),        // data port unused, soc_tb covers it
        .d_rdata()
    );

    // No address decoding here: the data RAM answers every data address.
    // soc_tb tests the core with the real bus.
    dmem #(
        .DEPTH(1024)
    ) u_dmem (
        .clk  (clk),
        .addr (dmem_addr),
        .wdata(dmem_wdata),
        .be   (dmem_be),
        .we   (dmem_we & dmem_ready),   // only store on the ready cycle
        .rdata(dmem_rdata)
    );

    // Slow memory model: each access waits WAIT_STATES cycles before ready
    assign dmem_ready = (wait_cnt == WAIT_STATES);

    always @(posedge clk) begin
        if (rst)
            wait_cnt <= 0;
        else if (dmem_re || dmem_we)
            wait_cnt <= dmem_ready ? 0 : wait_cnt + 1;
    end

    // Count stores actually performed by the memory
    always @(negedge clk) begin
        if (!rst && dmem_we && dmem_ready) stores++;
    end

    task automatic check_reg(input int n, input logic [31:0] exp);
        logic [31:0] got;
        got = UUT.u_regfile.regs[n];
        assert (got === exp)
        else begin
            $error("x%0d expected %h, got %h", n, exp, got);
            errors++;
        end
    endtask

    // Trace every instruction as it executes
    always @(posedge clk) begin
        if (!rst) begin
            $display("%4d  pc=%h  instr=%h%s", cycles, UUT.pc, imem_rdata, UUT.stall ? "  (stall)" : "");
            cycles++;
            if (UUT.stall) stall_cycles++;
            if (illegal) begin
                $error("illegal instruction %h at pc=%h", imem_rdata, UUT.pc);
                errors++;
            end
        end
    end

    initial begin

        // Hold reset for two cycles, release on a negedge
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // Run until the program reaches its final "jal x0, 0" loop
        wait (imem_rdata == 32'h0000006F || cycles >= MAX_CYCLES);
        repeat (2) @(posedge clk);

        if (cycles >= MAX_CYCLES) begin
            $error("timed out after %0d cycles, pc=%h", cycles, UUT.pc);
            errors++;
        end

        // Expected results, see sim/programs/core_test.hex
        check_reg( 1, 32'h00000005);
        check_reg( 2, 32'hFFFFFFFD);
        check_reg( 3, 32'h00000002);
        check_reg( 4, 32'h00000008);
        check_reg( 5, 32'h00000001);
        check_reg( 6, 32'h00000000);
        check_reg( 7, 32'h0005FFFD);
        check_reg( 8, 32'hFFFFFFFD);
        check_reg( 9, 32'h000000FF);
        check_reg(10, 32'hFF05FFFD);
        check_reg(11, 32'hFFFFFF05);
        check_reg(12, 32'h00000005);
        check_reg(13, 32'h0000000A);
        check_reg(14, 32'h00000000);
        check_reg(15, 32'h00000054);
        check_reg(16, 32'h00000001);
        check_reg(17, 32'h00000007);
        check_reg(18, 32'h00000064);
        check_reg(19, 32'hFFFFFFFE);
        check_reg(20, 32'h0000000F);
        check_reg(21, 32'h00000000);
        check_reg(22, 32'h0000002A);

        // x0 must read as zero through the read port. The final
        // "jal x0, 0" has rs1 = x0, so rd1 is reading x0 right now.
        // (regs[0] itself may hold 5 from "addi x0, x0, 5", which is fine.)
        assert (UUT.rs1 === 5'd0 && UUT.u_regfile.rd1 === 32'h0)
        else begin
            $error("x0 read as %h", UUT.u_regfile.rd1);
            errors++;
        end

        // Final data memory word after the sw/sb/sh sequence
        assert (u_dmem.mem[0] === 32'h0005FFFD)
        else begin
            $error("dmem[0] expected 0005FFFD, got %h", u_dmem.mem[0]);
            errors++;
        end

        // Each load/store should stall for exactly WAIT_STATES cycles
        assert (stall_cycles == NUM_MEM_OPS * WAIT_STATES)
        else begin
            $error("expected %0d stall cycles, got %0d", NUM_MEM_OPS * WAIT_STATES, stall_cycles);
            errors++;
        end

        // A stalled store must still only be written once
        assert (stores == NUM_STORES)
        else begin
            $error("expected %0d stores, got %0d", NUM_STORES, stores);
            errors++;
        end

        if (errors == 0) $display("core_tb PASSED (WAIT_STATES=%0d, %0d cycles, %0d stalled)", WAIT_STATES, cycles, stall_cycles);
        else             $display("core_tb FAILED with %0d errors", errors);
        $finish;

    end

endmodule

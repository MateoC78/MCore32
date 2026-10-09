module bus_tb;

    // Three test devices:
    //   0: 0x0000_0000 - 0x0FFF_FFFF
    //   1: 0x2000_0000 - 0x2000_0FFF  (4 KB peripheral slot)
    //   2: 0x2000_0000 - 0x2FFF_FFFF  (overlaps device 1, which must win)
    localparam int N = 3;
    localparam logic [N-1:0][31:0] BASE = {32'h2000_0000, 32'h2000_0000, 32'h0000_0000};
    localparam logic [N-1:0][31:0] MASK = {32'hF000_0000, 32'hFFFF_F000, 32'hF000_0000};

    logic [31:0]        addr = '0, wdata = '0;
    logic [3:0]         be = '0;
    logic               we = 1'b0, re = 1'b0;
    logic [31:0]        rdata;
    logic               ready, bus_err;
    logic [31:0]        dev_addr, dev_wdata;
    logic [3:0]         dev_be;
    logic [N-1:0]       dev_we, dev_re;
    logic [N-1:0][31:0] dev_rdata = {32'hCCCC_CCCC, 32'hBBBB_BBBB, 32'hAAAA_AAAA};
    logic [N-1:0]       dev_ready = '1;

    integer errors = 0;

    // Instantiate DUT
    bus #(
        .N   (N),
        .BASE(BASE),
        .MASK(MASK)
    ) UUT (
        .addr     (addr),
        .wdata    (wdata),
        .be       (be),
        .we       (we),
        .re       (re),
        .rdata    (rdata),
        .ready    (ready),
        .bus_err  (bus_err),
        .dev_addr (dev_addr),
        .dev_wdata(dev_wdata),
        .dev_be   (dev_be),
        .dev_we   (dev_we),
        .dev_re   (dev_re),
        .dev_rdata(dev_rdata),
        .dev_ready(dev_ready)
    );

    `define CHECK(name, got, exp) \
        assert ((got) === (exp)) \
        else begin \
            $error("%s (addr=%h): %s expected %h, got %h", tag, a, name, exp, got); \
            errors++; \
        end

    // Load from address a, expect it to reach device `dev` (-1 = unmapped)
    task automatic check_load(input string tag, input logic [31:0] a, input int dev);
        addr = a; we = 1'b0; re = 1'b1;
        #1;
        `CHECK("dev_re",  dev_re,  (dev < 0) ? 3'b000 : 3'b001 << dev)
        `CHECK("dev_we",  dev_we,  3'b000)
        `CHECK("rdata",   rdata,   (dev < 0) ? 32'h0 : dev_rdata[dev])
        `CHECK("ready",   ready,   1'b1)
        `CHECK("bus_err", bus_err, (dev < 0))
        re = 1'b0;
    endtask

    // Store to address a, expect it to reach device `dev` (-1 = unmapped)
    task automatic check_store(input string tag, input logic [31:0] a, input int dev);
        addr = a; wdata = 32'h1234_5678; be = 4'b0110; we = 1'b1; re = 1'b0;
        #1;
        `CHECK("dev_we",    dev_we,    (dev < 0) ? 3'b000 : 3'b001 << dev)
        `CHECK("dev_re",    dev_re,    3'b000)
        `CHECK("dev_addr",  dev_addr,  a)
        `CHECK("dev_wdata", dev_wdata, 32'h1234_5678)
        `CHECK("dev_be",    dev_be,    4'b0110)
        `CHECK("bus_err",   bus_err,   (dev < 0))
        we = 1'b0;
    endtask

    initial begin
        logic [31:0] a;
        string       tag;

        // Region edges
        check_load ("dev0 start",          32'h0000_0000, 0);
        check_load ("dev0 end",            32'h0FFF_FFFC, 0);
        check_load ("dev1 start",          32'h2000_0000, 1);
        check_load ("dev1 end",            32'h2000_0FFC, 1);

        // Just past device 1's 4 KB falls through to device 2
        check_load ("dev2 after dev1",     32'h2000_1000, 2);
        check_load ("dev2 end",            32'h2FFF_FFFC, 2);

        // Unmapped
        check_load ("unmapped 0x1",        32'h1000_0000, -1);
        check_load ("unmapped 0xF",        32'hFFFF_FFFC, -1);

        // Stores go only to the selected device
        check_store("store dev0",          32'h0000_0100, 0);
        check_store("store dev1",          32'h2000_0010, 1);
        check_store("store dev2",          32'h2100_0000, 2);
        check_store("store unmapped",      32'h3000_0000, -1);

        // ready comes from the selected device only
        a = 32'h2000_0000;
        addr = a; re = 1'b1;
        dev_ready = 3'b101;            // device 1 busy, others ready
        #1;
        begin
            tag = "dev1 busy";
            `CHECK("ready", ready, 1'b0)
        end
        a = 32'h0000_0000;
        addr = a;
        #1;
        begin
            tag = "dev0 while dev1 busy";
            `CHECK("ready", ready, 1'b1)
        end
        dev_ready = '1;
        re = 1'b0;

        // No access: no enables, no error
        a = 32'h3000_0000;
        addr = a;
        #1;
        begin
            tag = "idle";
            `CHECK("dev_we",  dev_we,  3'b000)
            `CHECK("dev_re",  dev_re,  3'b000)
            `CHECK("bus_err", bus_err, 1'b0)
        end

        if (errors == 0) $display("bus_tb PASSED");
        else             $display("bus_tb FAILED with %0d errors", errors);
        $finish;
    end

endmodule

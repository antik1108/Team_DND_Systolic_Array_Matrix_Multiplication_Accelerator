// ============================================================================
// tb_pe.v  --  Processing Element testbench
// Team DnD | Project 12
// Checks: (1) MAC behaviour gated by v_in, (2) 1-cycle registered forwarding
// of a, b and valid to the neighbours, (3) clear behaviour, (4) a dot product.
// ============================================================================
`timescale 1ns/1ps
module tb_pe;
    localparam DATA_W = 8, ACC_W = 32;
    reg clk = 0, rst = 1, clear = 0;
    reg  signed [DATA_W-1:0] a_in = 0, b_in = 0;
    reg  v_in = 0;
    wire signed [DATA_W-1:0] a_out, b_out;
    wire v_out;
    wire signed [ACC_W-1:0] acc;
    integer errors = 0, tests = 0, k;
    reg signed [ACC_W-1:0] model;
    reg signed [DATA_W-1:0] va [0:7];
    reg signed [DATA_W-1:0] vb [0:7];

    pe #(.DATA_W(DATA_W), .ACC_W(ACC_W)) dut (
        .clk(clk), .rst(rst), .clear(clear),
        .a_in(a_in), .b_in(b_in), .v_in(v_in),
        .a_out(a_out), .b_out(b_out), .v_out(v_out), .acc(acc));

    always #5 clk = ~clk;

    task check(input cond, input [8*48-1:0] name);
    begin
        tests = tests + 1;
        if (!cond) begin errors = errors + 1; $display("  FAIL %0s", name); end
        else        $display("  PASS %0s", name);
    end
    endtask

    initial begin
        $dumpfile("sim/waves/tb_pe.vcd");
        $dumpvars(0, tb_pe);
        $display("=== PE directed tests ===");
        repeat (2) @(posedge clk); #1 rst = 0;

        // T1: forwarding latency = 1 cycle
        a_in = 8'sd11; b_in = -8'sd22; v_in = 1;
        @(posedge clk); #1;
        check(a_out == 11 && b_out == -22 && v_out == 1, "operands/valid forwarded after 1 cycle");
        check(acc == -242, "MAC result 11 * -22 = -242");

        // T2: valid low -> forward data but do NOT accumulate
        a_in = 8'sd5; b_in = 8'sd5; v_in = 0;
        @(posedge clk); #1;
        check(acc == -242, "v_in=0 does not accumulate");
        check(a_out == 5 && b_out == 5 && v_out == 0, "data forwarded even when invalid");

        // T3: clear
        clear = 1; @(posedge clk); #1; clear = 0;
        check(acc == 0 && v_out == 0, "clear zeroes accumulator and valid");

        // T4: 8-term dot product streamed through the PE
        va[0]=1;  va[1]=-2; va[2]=3;  va[3]=-4; va[4]=127; va[5]=-128; va[6]=0;  va[7]=9;
        vb[0]=8;  vb[1]=7;  vb[2]=-6; vb[3]=5;  vb[4]=127; vb[5]=-128; vb[6]=50; vb[7]=-3;
        model = 0;
        for (k = 0; k < 8; k = k + 1) begin
            a_in = va[k]; b_in = vb[k]; v_in = 1;
            model = model + va[k]*vb[k];
            @(posedge clk); #1;
            check(a_out == va[k] && b_out == vb[k], "stream forwarding");
        end
        v_in = 0;
        check(acc == model, "8-term dot product matches model");
        $display("    dot product = %0d (expected %0d)", acc, model);

        $display("=== PE: %0d tests, %0d errors ===", tests, errors);
        if (errors == 0) $display("RESULT: PE PASSED");
        else             $display("RESULT: PE FAILED");
        $finish;
    end
endmodule

// ============================================================================
// tb_mac_unit.v  --  Directed self-checking testbench for mac_unit
// Team DnD | Project 12
// ============================================================================
`timescale 1ns/1ps
module tb_mac_unit;
    localparam DATA_W = 8, ACC_W = 32;
    reg clk = 0, rst = 1, clear = 0, en = 0;
    reg  signed [DATA_W-1:0] a = 0, b = 0;
    wire signed [ACC_W-1:0]  acc;
    integer errors = 0, tests = 0;
    reg signed [ACC_W-1:0] model = 0;

    mac_unit #(.DATA_W(DATA_W), .ACC_W(ACC_W)) dut (
        .clk(clk), .rst(rst), .clear(clear), .en(en), .a(a), .b(b), .acc(acc));

    always #5 clk = ~clk;

    task step(input signed [DATA_W-1:0] ta, input signed [DATA_W-1:0] tb_, input ten,
              input tclr, input [8*40-1:0] name);
    begin
        a = ta; b = tb_; en = ten; clear = tclr;
        @(posedge clk); #1;
        if (tclr)      model = 0;
        else if (ten)  model = model + ta * tb_;
        tests = tests + 1;
        if (acc !== model) begin
            errors = errors + 1;
            $display("  FAIL %-28s a=%4d b=%4d en=%0d clr=%0d acc=%0d exp=%0d",
                     name, ta, tb_, ten, tclr, acc, model);
        end else
            $display("  PASS %-28s a=%4d b=%4d en=%0d clr=%0d acc=%0d",
                     name, ta, tb_, ten, tclr, acc);
    end
    endtask

    initial begin
        $dumpfile("sim/waves/tb_mac_unit.vcd");
        $dumpvars(0, tb_mac_unit);
        $display("=== MAC unit directed tests ===");
        repeat (2) @(posedge clk);
        rst = 0;
        step(  3,   4, 1, 0, "pos x pos");
        step( -5,   6, 1, 0, "neg x pos");
        step( -7,  -8, 1, 0, "neg x neg");
        step(  0, 100, 1, 0, "zero operand");
        step( 10,  10, 0, 0, "enable low holds value");
        step(127, 127, 1, 0, "max positive");
        step(-128,-128, 1, 0, "most negative squared");
        step(-128, 127, 1, 0, "min x max");
        step(  1,   1, 1, 1, "clear has priority");
        step(  2,   3, 1, 0, "accumulate after clear");
        // long accumulation: 64 x (-128*-128) = 1,048,576 (no overflow)
        repeat (64) step(-128, -128, 1, 0, "long accumulation");
        $display("=== MAC: %0d tests, %0d errors ===", tests, errors);
        if (errors == 0) $display("RESULT: MAC_UNIT PASSED");
        else             $display("RESULT: MAC_UNIT FAILED");
        $finish;
    end
endmodule

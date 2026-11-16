// ============================================================================
// tb_compare.v  --  Systolic array vs. sequential single-MAC baseline
// Team DnD | Project 12
// ----------------------------------------------------------------------------
// Feeds identical random matrices to both designs, checks that both agree,
// and reports the measured latency of each (cycle_count) and the speed-up.
// Output line "PERF N=.. systolic=.. sequential=.." is parsed by the
// analysis script.
// ============================================================================
`timescale 1ns/1ps
module tb_compare;
    parameter N      = 4;
    parameter DATA_W = 8;
    parameter ACC_W  = 32;
    parameter PIPE   = 0;
    parameter NRAND  = 20;
    localparam IDX_W = (N <= 2) ? 1 : $clog2(N);

    reg clk = 0, rst = 1;
    reg wr_en = 0, wr_sel = 0, start = 0;
    reg [IDX_W-1:0] wr_row = 0, wr_col = 0, rd_row = 0, rd_col = 0;
    reg [DATA_W-1:0] wr_data = 0;
    wire busy_s, done_s, busy_q, done_q;
    wire [15:0] cyc_s, cyc_q;
    wire [ACC_W-1:0] rd_s, rd_q;

    systolic_top #(.N(N), .DATA_W(DATA_W), .ACC_W(ACC_W), .PIPE(PIPE)) u_sys (
        .clk(clk), .rst(rst), .wr_en(wr_en), .wr_sel(wr_sel), .wr_row(wr_row),
        .wr_col(wr_col), .wr_data(wr_data), .start(start), .busy(busy_s),
        .done(done_s), .cycle_count(cyc_s), .rd_row(rd_row), .rd_col(rd_col),
        .rd_data(rd_s));

    sequential_matmul #(.N(N), .DATA_W(DATA_W), .ACC_W(ACC_W)) u_seq (
        .clk(clk), .rst(rst), .wr_en(wr_en), .wr_sel(wr_sel), .wr_row(wr_row),
        .wr_col(wr_col), .wr_data(wr_data), .start(start), .busy(busy_q),
        .done(done_q), .cycle_count(cyc_q), .rd_row(rd_row), .rd_col(rd_col),
        .rd_data(rd_q));

    always #5 clk = ~clk;

    reg signed [DATA_W-1:0] A [0:N*N-1];
    reg signed [DATA_W-1:0] B [0:N*N-1];
    reg signed [ACC_W-1:0]  R;
    integer i, r, c, q, t, seed, errors = 0;
    reg got_s, got_q;

    initial begin
        seed = 32'h5EED + N;
        repeat (3) @(negedge clk); rst = 0;
        for (t = 0; t < NRAND; t = t + 1) begin
            for (i = 0; i < N*N; i = i + 1) begin A[i] = $random(seed); B[i] = $random(seed); end
            for (r = 0; r < N; r = r + 1) for (c = 0; c < N; c = c + 1) begin
                @(negedge clk); wr_en = 1; wr_sel = 0; wr_row = r; wr_col = c; wr_data = A[r*N+c];
                @(negedge clk);            wr_sel = 1;                          wr_data = B[r*N+c];
            end
            @(negedge clk) begin wr_en = 0; start = 1; end
            @(negedge clk) start = 0;
            got_s = 0; got_q = 0;
            while (!(got_s && got_q)) begin
                if (done_s) got_s = 1;
                if (done_q) got_q = 1;
                @(negedge clk);
            end
            for (r = 0; r < N; r = r + 1) for (c = 0; c < N; c = c + 1) begin
                rd_row = r; rd_col = c; #1;
                R = 0;
                for (q = 0; q < N; q = q + 1) R = R + A[r*N+q] * B[q*N+c];
                if ($signed(rd_s) !== R || $signed(rd_q) !== R) begin
                    errors = errors + 1;
                    $display("MISMATCH t=%0d C[%0d][%0d] sys=%0d seq=%0d ref=%0d",
                             t, r, c, $signed(rd_s), $signed(rd_q), R);
                end
            end
        end
        $display("PERF N=%0d systolic=%0d sequential=%0d macs=%0d pes=%0d errors=%0d",
                 N, cyc_s, cyc_q, N*N*N, N*N, errors);
        $display("RESULT: COMPARE N=%0d %s (speed-up %0.2fx)", N,
                 errors ? "FAILED" : "PASSED", cyc_q * 1.0 / cyc_s);
        $finish;
    end
endmodule

// ============================================================================
// tb_systolic_top.v  --  System-level self-checking testbench
// Team DnD | Project 12
// ----------------------------------------------------------------------------
// Loads A and B through the Matrix Data Interface, starts the accelerator,
// reads back C and compares every element with a behavioural reference model
// (triple-loop matmul inside the testbench). Every test case is also logged
// to sim/matmul_log_N<N>.txt so the Python/NumPy golden model can re-verify
// the results independently (scripts/verify_results.py).
//
// Directed tests: identity, zero, all-ones, worked example, negative values,
// extreme values (-128), diagonal, fixed-point Q3.4, back-to-back runs,
// plus NRAND random matrices.
// ============================================================================
`timescale 1ns/1ps
module tb_systolic_top;
    parameter N      = 4;
    parameter DATA_W = 8;
    parameter ACC_W  = 32;
    parameter PIPE   = 0;
    parameter NRAND  = 100;
    parameter DUMP   = 1;
    localparam IDX_W = (N <= 2) ? 1 : $clog2(N);

    reg clk = 0, rst = 1;
    reg wr_en = 0, wr_sel = 0, start = 0;
    reg [IDX_W-1:0] wr_row = 0, wr_col = 0, rd_row = 0, rd_col = 0;
    reg [DATA_W-1:0] wr_data = 0;
    wire busy, done;
    wire [15:0] cycle_count;
    wire [ACC_W-1:0] rd_data;

    systolic_top #(.N(N), .DATA_W(DATA_W), .ACC_W(ACC_W), .PIPE(PIPE)) dut (
        .clk(clk), .rst(rst),
        .wr_en(wr_en), .wr_sel(wr_sel), .wr_row(wr_row), .wr_col(wr_col), .wr_data(wr_data),
        .start(start), .busy(busy), .done(done), .cycle_count(cycle_count),
        .rd_row(rd_row), .rd_col(rd_col), .rd_data(rd_data));

    always #5 clk = ~clk;   // 100 MHz simulation clock

    reg signed [DATA_W-1:0] A   [0:N*N-1];
    reg signed [DATA_W-1:0] B   [0:N*N-1];
    reg signed [ACC_W-1:0]  REF [0:N*N-1];
    integer i, j, k, t, fd, seed;
    integer errors = 0, n_tests = 0, n_elems = 0, last_latency = 0;

    // ---------------- reference model ----------------
    task ref_model;
        integer r, c, q;
        begin
            for (r = 0; r < N; r = r + 1)
                for (c = 0; c < N; c = c + 1) begin
                    REF[r*N+c] = 0;
                    for (q = 0; q < N; q = q + 1)
                        REF[r*N+c] = REF[r*N+c] + A[r*N+q] * B[q*N+c];
                end
        end
    endtask

    // ---------------- host-side driver tasks ----------------
    task load_matrices;
        integer r, c;
        begin
            for (r = 0; r < N; r = r + 1)
                for (c = 0; c < N; c = c + 1) begin
                    @(negedge clk);
                    wr_en = 1; wr_sel = 0; wr_row = r; wr_col = c; wr_data = A[r*N+c];
                    @(negedge clk);
                    wr_sel = 1; wr_data = B[r*N+c];
                end
            @(negedge clk); wr_en = 0;
        end
    endtask

    task run_and_check(input [8*32-1:0] name);
        integer r, c, local_err, cyc;
        begin
            ref_model;
            load_matrices;
            @(negedge clk) start = 1;
            @(negedge clk) start = 0;
            cyc = 1;
            while (!done) begin @(negedge clk); cyc = cyc + 1; end
            last_latency = cycle_count;
            local_err = 0;
            $fwrite(fd, "TEST %0s\n", name);
            for (r = 0; r < N; r = r + 1) begin
                $fwrite(fd, "A");
                for (c = 0; c < N; c = c + 1) $fwrite(fd, " %0d", A[r*N+c]);
                $fwrite(fd, "\n");
            end
            for (r = 0; r < N; r = r + 1) begin
                $fwrite(fd, "B");
                for (c = 0; c < N; c = c + 1) $fwrite(fd, " %0d", B[r*N+c]);
                $fwrite(fd, "\n");
            end
            for (r = 0; r < N; r = r + 1) begin
                $fwrite(fd, "C");
                for (c = 0; c < N; c = c + 1) begin
                    rd_row = r; rd_col = c; #1;
                    $fwrite(fd, " %0d", $signed(rd_data));
                    n_elems = n_elems + 1;
                    if ($signed(rd_data) !== REF[r*N+c]) begin
                        local_err = local_err + 1;
                        $display("    mismatch C[%0d][%0d] = %0d, expected %0d",
                                 r, c, $signed(rd_data), REF[r*N+c]);
                    end
                end
                $fwrite(fd, "\n");
            end
            $fwrite(fd, "CYCLES %0d\n", cycle_count);
            n_tests = n_tests + 1;
            errors  = errors + local_err;
            $display("  %s %-26s latency = %0d cycles", (local_err==0) ? "PASS" : "FAIL",
                     name, cycle_count);
        end
    endtask

    task print_result;
        integer r, c;
        begin
            for (r = 0; r < N; r = r + 1) begin
                $write("      [");
                for (c = 0; c < N; c = c + 1) begin
                    rd_row = r; rd_col = c; #1;
                    $write(" %6d", $signed(rd_data));
                end
                $write(" ]\n");
            end
        end
    endtask

    initial begin
        if (DUMP) begin
            $dumpfile("sim/waves/tb_systolic_top.vcd");
            $dumpvars(0, tb_systolic_top);
        end
        fd = $fopen($sformatf("sim/matmul_log_N%0d.txt", N), "w");
        seed = 32'hD0D_2026;
        $display("=== Systolic array %0dx%0d, INT%0d operands, %0d-bit accumulators ===",
                 N, N, DATA_W, ACC_W);
        repeat (3) @(negedge clk);
        rst = 0;

        // 1. identity x M  = M
        for (i = 0; i < N; i = i + 1) for (j = 0; j < N; j = j + 1) begin
            A[i*N+j] = (i == j); B[i*N+j] = i*N + j + 1;
        end
        run_and_check("identity x M");

        // 2. zero matrix
        for (i = 0; i < N*N; i = i + 1) begin A[i] = 0; B[i] = i; end
        run_and_check("zero x M");

        // 3. all ones -> every element = N
        for (i = 0; i < N*N; i = i + 1) begin A[i] = 1; B[i] = 1; end
        run_and_check("ones x ones");

        // 4. worked example used in the report (A = 1..N^2, B = N^2..1)
        for (i = 0; i < N*N; i = i + 1) begin A[i] = i + 1; B[i] = N*N - i; end
        run_and_check("worked example");
        $display("    C = A x B (worked example):");
        print_result;

        // 5. signed values
        for (i = 0; i < N*N; i = i + 1) begin
            A[i] = (i % 2) ? -(i+1) : (i+1);
            B[i] = (i % 3) ? (i-7) : -(i+3);
        end
        run_and_check("mixed signs");

        // 6. extremes: -128 * -128 everywhere (largest magnitude product)
        for (i = 0; i < N*N; i = i + 1) begin A[i] = -128; B[i] = -128; end
        run_and_check("extreme -128 x -128");

        // 7. extremes: 127 x -128
        for (i = 0; i < N*N; i = i + 1) begin A[i] = 127; B[i] = -128; end
        run_and_check("extreme 127 x -128");

        // 8. diagonal scaling
        for (i = 0; i < N; i = i + 1) for (j = 0; j < N; j = j + 1) begin
            A[i*N+j] = (i == j) ? (i + 2) : 0; B[i*N+j] = j - i;
        end
        run_and_check("diagonal x M");

        // 9. fixed-point Q3.4 operands (value = int/16), e.g. 1.5, -0.75 ...
        //    The integer result is Q7.8 (value = int/256).
        for (i = 0; i < N*N; i = i + 1) begin
            A[i] = (i * 24) % 97 - 48;   // -3.0 .. +3.0 in Q3.4
            B[i] = (i * 13) % 61 - 30;   // -1.875 .. +1.875
        end
        run_and_check("fixed-point Q3.4");

        // 10. back-to-back operations (result registers updated each time)
        for (t = 0; t < 3; t = t + 1) begin
            for (i = 0; i < N*N; i = i + 1) begin A[i] = t + i; B[i] = t - i; end
            run_and_check("back-to-back run");
        end

        // 11. random regression
        for (t = 0; t < NRAND; t = t + 1) begin
            for (i = 0; i < N*N; i = i + 1) begin
                A[i] = $random(seed); B[i] = $random(seed);
            end
            run_and_check("random");
        end

        $display("=== %0d matrix tests, %0d elements checked, %0d errors ===",
                 n_tests, n_elems, errors);
        $display("LATENCY_SYSTOLIC N=%0d cycles=%0d", N, last_latency);
        if (errors == 0) $display("RESULT: SYSTOLIC_TOP N=%0d PASSED", N);
        else             $display("RESULT: SYSTOLIC_TOP N=%0d FAILED", N);
        $fclose(fd);
        $finish;
    end

    // watchdog
    initial begin #50_000_000; $display("TIMEOUT"); $finish; end
endmodule

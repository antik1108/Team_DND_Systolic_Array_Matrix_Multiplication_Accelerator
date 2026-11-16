// ============================================================================
// skew_buffer.v  --  Triangular delay line that "skews" operands
// Team DnD | Project 12
// ----------------------------------------------------------------------------
// Lane i is delayed by i clock cycles. This makes A[i][k] and B[k][j] meet in
// PE(i,j) at exactly the same clock edge:
//     t_arrive(i, j, k) = k + i + j     (for both operands)
// Each lane carries W bits (operand, optionally packed with a valid flag).
// Total registers = W * N(N-1)/2.
// ============================================================================
`timescale 1ns/1ps
module skew_buffer #(
    parameter N = 4,
    parameter W = 9
)(
    input  wire           clk,
    input  wire           rst,
    input  wire [N*W-1:0] din,
    output wire [N*W-1:0] dout
);
    // lane 0 : pass-through (zero delay)
    assign dout[0 +: W] = din[0 +: W];

    genvar l, s;
    generate
        for (l = 1; l < N; l = l + 1) begin : lane
            reg [W-1:0] sr [0:l-1];
            always @(posedge clk) begin
                if (rst) sr[0] <= {W{1'b0}};
                else     sr[0] <= din[l*W +: W];
            end
            for (s = 1; s < l; s = s + 1) begin : stg
                always @(posedge clk) begin
                    if (rst) sr[s] <= {W{1'b0}};
                    else     sr[s] <= sr[s-1];
                end
            end
            assign dout[l*W +: W] = sr[l-1];
        end
    endgenerate
endmodule

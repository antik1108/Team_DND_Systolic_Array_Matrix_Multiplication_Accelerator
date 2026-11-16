// ============================================================================
// systolic_array.v  --  N x N mesh of output-stationary PEs
// Team DnD | Project 12
// ----------------------------------------------------------------------------
// A operands enter on the west edge (row i -> a_west[i]) and flow east.
// B operands enter on the north edge (col j -> b_north[j]) and flow south.
// The valid flag travels with A. All N*N accumulators are exposed flattened:
// C[i][j] at bits [(i*N+j)*ACC_W +: ACC_W].
// ============================================================================
`timescale 1ns/1ps
module systolic_array #(
    parameter N      = 4,
    parameter DATA_W = 8,
    parameter ACC_W  = 32,
    parameter PIPE   = 0
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    clear,
    input  wire [N*DATA_W-1:0]     a_west,
    input  wire [N-1:0]            v_west,
    input  wire [N*DATA_W-1:0]     b_north,
    output wire [N*N*ACC_W-1:0]    c_flat,
    output wire [N-1:0]            v_east       // valid leaving the last column
);
    // Inter-PE nets, flattened. Horizontal net (i, j) feeds PE(i,j) from the
    // west; index j = N is the east boundary. Vertical net (i, j) feeds PE(i,j)
    // from the north; index i = N is the south boundary.
    wire [DATA_W-1:0] a_h [0:N*(N+1)-1];
    wire              v_h [0:N*(N+1)-1];
    wire [DATA_W-1:0] b_v [0:(N+1)*N-1];

    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : edge_w
            assign a_h[i*(N+1)]     = a_west[i*DATA_W +: DATA_W];
            assign v_h[i*(N+1)]     = v_west[i];
            assign v_east[i]        = v_h[i*(N+1) + N];
        end
        for (j = 0; j < N; j = j + 1) begin : edge_n
            assign b_v[j] = b_north[j*DATA_W +: DATA_W];
        end
        for (i = 0; i < N; i = i + 1) begin : row
            for (j = 0; j < N; j = j + 1) begin : col
                pe #(.DATA_W(DATA_W), .ACC_W(ACC_W), .PIPE(PIPE)) u_pe (
                    .clk  (clk),
                    .rst  (rst),
                    .clear(clear),
                    .a_in (a_h[i*(N+1) + j]),
                    .b_in (b_v[i*N + j]),
                    .v_in (v_h[i*(N+1) + j]),
                    .a_out(a_h[i*(N+1) + j + 1]),
                    .b_out(b_v[(i+1)*N + j]),
                    .v_out(v_h[i*(N+1) + j + 1]),
                    .acc  (c_flat[(i*N+j)*ACC_W +: ACC_W])
                );
            end
        end
    endgenerate
endmodule

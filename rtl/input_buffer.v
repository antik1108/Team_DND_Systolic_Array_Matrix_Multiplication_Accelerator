// ============================================================================
// input_buffer.v  --  Operand storage bank (N x N) for matrix A or B
// Team DnD | Project 12
// ----------------------------------------------------------------------------
// Write port : random access (row, col) from the Matrix Data Interface.
// Read port  : one whole "slice" per cycle, registered (1-cycle latency).
//   MODE = 0 (matrix A): slice k = column k -> A[0][k] .. A[N-1][k]
//   MODE = 1 (matrix B): slice k = row    k -> B[k][0] .. B[k][N-1]
// The slice is flattened: lane i occupies bits [i*DATA_W +: DATA_W].
// ============================================================================
`timescale 1ns/1ps
module input_buffer #(
    parameter N      = 4,
    parameter DATA_W = 8,
    parameter MODE   = 0,
    parameter IDX_W  = (N <= 2) ? 1 : $clog2(N)
)(
    input  wire                 clk,
    input  wire                 wr_en,
    input  wire [IDX_W-1:0]     wr_row,
    input  wire [IDX_W-1:0]     wr_col,
    input  wire [DATA_W-1:0]    wr_data,
    input  wire                 rd_en,
    input  wire [IDX_W-1:0]     rd_k,
    output reg  [N*DATA_W-1:0]  rd_slice
);
    // Address = {row, col}: power-of-two stride avoids a row*N multiplier
    // when N is not a power of two (e.g. N = 3).
    localparam PAD = 1 << IDX_W;
    reg [DATA_W-1:0] mem [0:PAD*PAD-1];
    integer i;

    always @(posedge clk) begin
        if (wr_en)
            mem[{wr_row, wr_col}] <= wr_data;
    end

    always @(posedge clk) begin
        if (rd_en) begin
            for (i = 0; i < N; i = i + 1) begin
                if (MODE == 0) rd_slice[i*DATA_W +: DATA_W] <= mem[{i[IDX_W-1:0], rd_k}];   // column of A
                else           rd_slice[i*DATA_W +: DATA_W] <= mem[{rd_k, i[IDX_W-1:0]}];   // row of B
            end
        end else begin
            rd_slice <= {N*DATA_W{1'b0}};
        end
    end
endmodule

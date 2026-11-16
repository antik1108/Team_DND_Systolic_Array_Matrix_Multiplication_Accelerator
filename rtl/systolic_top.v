// ============================================================================
// systolic_top.v  --  Systolic-array matrix-multiplication accelerator (top)
// Team DnD | Project 12
// ----------------------------------------------------------------------------
// Matrix Data Interface (host side):
//   wr_en, wr_sel (0=A,1=B), wr_row, wr_col, wr_data  -> load operands
//   start                                              -> launch C = A x B
//   busy / done                                        -> status
//   rd_row, rd_col -> rd_data                          -> read result C
//   cycle_count                                        -> latency counter
//
//   host --> [Input Buffer A] --> [Skew A] --> west edge  \
//                                                           [N x N PE mesh] --> [Output Regs] --> host
//   host --> [Input Buffer B] --> [Skew B] --> north edge /
//                   ^                                 ^
//                   +------ [Systolic Controller FSM] +
// ============================================================================
`timescale 1ns/1ps
module systolic_top #(
    parameter N      = 4,
    parameter DATA_W = 8,
    parameter ACC_W  = 32,
    parameter PIPE   = 0,      // 1 = pipelined MAC in every PE
    parameter IDX_W  = (N <= 2) ? 1 : $clog2(N)
)(
    input  wire              clk,
    input  wire              rst,
    // load interface
    input  wire              wr_en,
    input  wire              wr_sel,
    input  wire [IDX_W-1:0]  wr_row,
    input  wire [IDX_W-1:0]  wr_col,
    input  wire [DATA_W-1:0] wr_data,
    // control
    input  wire              start,
    output wire              busy,
    output wire              done,
    output wire [15:0]       cycle_count,
    // result read
    input  wire [IDX_W-1:0]  rd_row,
    input  wire [IDX_W-1:0]  rd_col,
    output wire [ACC_W-1:0]  rd_data
);
    wire             clear, rd_en, feed_valid, capture;
    wire [IDX_W-1:0] rd_k;
    wire [2:0]       state_dbg;

    systolic_controller #(.N(N), .PIPE(PIPE), .IDX_W(IDX_W)) u_ctrl (
        .clk(clk), .rst(rst), .start(start),
        .clear(clear), .rd_en(rd_en), .rd_k(rd_k), .feed_valid(feed_valid),
        .capture(capture), .busy(busy), .done(done),
        .cycle_count(cycle_count), .state_dbg(state_dbg)
    );

    wire [N*DATA_W-1:0] a_slice, b_slice;

    input_buffer #(.N(N), .DATA_W(DATA_W), .MODE(0), .IDX_W(IDX_W)) u_buf_a (
        .clk(clk), .wr_en(wr_en & ~wr_sel & ~busy), .wr_row(wr_row), .wr_col(wr_col),
        .wr_data(wr_data), .rd_en(rd_en), .rd_k(rd_k), .rd_slice(a_slice)
    );
    input_buffer #(.N(N), .DATA_W(DATA_W), .MODE(1), .IDX_W(IDX_W)) u_buf_b (
        .clk(clk), .wr_en(wr_en & wr_sel & ~busy), .wr_row(wr_row), .wr_col(wr_col),
        .wr_data(wr_data), .rd_en(rd_en), .rd_k(rd_k), .rd_slice(b_slice)
    );

    // Pack {valid, data} per lane for the A skew buffer
    localparam WA = DATA_W + 1;
    wire [N*WA-1:0]     a_pack, a_skewed;
    wire [N*DATA_W-1:0] b_skewed;
    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : pack
            assign a_pack[g*WA +: WA] = {feed_valid, a_slice[g*DATA_W +: DATA_W]};
        end
    endgenerate

    skew_buffer #(.N(N), .W(WA))     u_skew_a (.clk(clk), .rst(rst), .din(a_pack),  .dout(a_skewed));
    skew_buffer #(.N(N), .W(DATA_W)) u_skew_b (.clk(clk), .rst(rst), .din(b_slice), .dout(b_skewed));

    wire [N*DATA_W-1:0] a_west;
    wire [N-1:0]        v_west;
    generate
        for (g = 0; g < N; g = g + 1) begin : unpack
            assign a_west[g*DATA_W +: DATA_W] = a_skewed[g*WA +: DATA_W];
            assign v_west[g]                  = a_skewed[g*WA + DATA_W];
        end
    endgenerate

    wire [N*N*ACC_W-1:0] c_flat;
    wire [N-1:0]         v_east;

    systolic_array #(.N(N), .DATA_W(DATA_W), .ACC_W(ACC_W), .PIPE(PIPE)) u_array (
        .clk(clk), .rst(rst), .clear(clear),
        .a_west(a_west), .v_west(v_west), .b_north(b_skewed),
        .c_flat(c_flat), .v_east(v_east)
    );

    output_buffer #(.N(N), .ACC_W(ACC_W), .IDX_W(IDX_W)) u_out (
        .clk(clk), .rst(rst), .capture(capture), .c_flat(c_flat),
        .rd_row(rd_row), .rd_col(rd_col), .rd_data(rd_data)
    );
endmodule

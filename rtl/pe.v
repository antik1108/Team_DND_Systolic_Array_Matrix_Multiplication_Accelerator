// ============================================================================
// pe.v  --  Output-stationary Processing Element (PE)
// Team DnD | Project 12
// ----------------------------------------------------------------------------
//               b_in (from north)
//                  |
//   a_in, v_in --> [ MAC ] --> a_out, v_out (to east, registered)
//                  |
//               b_out (to south, registered)
//
// Every clock cycle the PE (1) multiplies the operands arriving from the west
// and north, (2) adds the product into its local accumulator when v_in = 1,
// and (3) forwards a, b and the valid flag to its east/south neighbours
// through pipeline registers. The partial sum C[i][j] never leaves the PE
// until the computation ends ("output-stationary" dataflow).
// ============================================================================
`timescale 1ns/1ps
module pe #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32,
    parameter PIPE   = 0
)(
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     clear,
    input  wire signed [DATA_W-1:0] a_in,
    input  wire signed [DATA_W-1:0] b_in,
    input  wire                     v_in,
    output reg  signed [DATA_W-1:0] a_out,
    output reg  signed [DATA_W-1:0] b_out,
    output reg                      v_out,
    output wire signed [ACC_W-1:0]  acc
);
    mac_unit #(.DATA_W(DATA_W), .ACC_W(ACC_W), .PIPE(PIPE)) u_mac (
        .clk(clk), .rst(rst), .clear(clear), .en(v_in),
        .a(a_in), .b(b_in), .acc(acc)
    );

    // Systolic forwarding registers
    always @(posedge clk) begin
        if (rst || clear) begin
            a_out <= {DATA_W{1'b0}};
            b_out <= {DATA_W{1'b0}};
            v_out <= 1'b0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            v_out <= v_in;
        end
    end
endmodule

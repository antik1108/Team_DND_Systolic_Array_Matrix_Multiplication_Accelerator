// ============================================================================
// mac_unit.v  --  Signed fixed-point Multiply-Accumulate unit
// Team DnD | Project 12: Systolic Array Matrix Multiplication Accelerator
// ----------------------------------------------------------------------------
// acc <= clear ? 0 : (en ? acc + a*b : acc)
// Operands are two's-complement fixed-point (default INT8, interpreted as
// Q3.4 in the fixed-point tests). The product of two Q3.4 numbers is Q7.8;
// ACC_W = 32 bits guarantees an N-term dot product can never overflow.
// ============================================================================
`timescale 1ns/1ps
module mac_unit #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32,
    parameter PIPE   = 0      // 1 = register the product (2-stage MAC, higher Fmax)
)(
    input  wire                     clk,
    input  wire                     rst,     // synchronous, active-high
    input  wire                     clear,   // zero the accumulator
    input  wire                     en,      // accumulate this cycle
    input  wire signed [DATA_W-1:0] a,
    input  wire signed [DATA_W-1:0] b,
    output reg  signed [ACC_W-1:0]  acc
);
    wire signed [2*DATA_W-1:0] product = a * b;
    wire signed [2*DATA_W-1:0] p_use;
    wire                       en_use;

    generate
        if (PIPE) begin : g_pipe
            // Stage 1: multiplier output register (maps into the DSP's MREG)
            reg signed [2*DATA_W-1:0] p_q;
            reg                       en_q;
            always @(posedge clk) begin
                if (rst || clear) begin p_q <= 0; en_q <= 1'b0; end
                else              begin p_q <= product; en_q <= en; end
            end
            assign p_use = p_q;  assign en_use = en_q;
        end else begin : g_comb
            assign p_use = product;  assign en_use = en;
        end
    endgenerate

    // Stage 2 (or only stage): accumulate
    always @(posedge clk) begin
        if (rst || clear)
            acc <= {ACC_W{1'b0}};
        else if (en_use)
            acc <= acc + {{(ACC_W-2*DATA_W){p_use[2*DATA_W-1]}}, p_use};
    end
endmodule

// ============================================================================
// systolic_controller.v  --  FSM sequencing one matrix multiplication
// Team DnD | Project 12
// ----------------------------------------------------------------------------
//  IDLE --start--> CLEAR --> FEED (N cycles) --> DRAIN (2N-1+PIPE cycles)
//        --> CAPTURE --> DONE --> IDLE
//
//  CLEAR  : zero all PE accumulators and pipeline registers.
//  FEED   : read slice k = 0..N-1 of A (column k) and B (row k).
//  DRAIN  : wait until the last operand pair has been accumulated in
//           PE(N-1,N-1). The slice read in the last FEED cycle reaches the
//           array 1 cycle later (buffer latency) and PE(N-1,N-1) after a
//           further 2(N-1) cycles (skew + mesh hops) -> 2N-1 cycles.
//  CAPTURE: copy accumulators into the output registers.
//  Total latency start -> done = 3N + 1 (+1 if PIPE) cycles.
//  DONE   : 'done' pulses for one cycle, 'busy' drops.
// cycle_count holds the start->done latency of the last operation.
// ============================================================================
`timescale 1ns/1ps
module systolic_controller #(
    parameter N     = 4,
    parameter PIPE  = 0,
    parameter IDX_W = (N <= 2) ? 1 : $clog2(N),
    parameter CNT_W = 8
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              start,
    output reg               clear,
    output reg               rd_en,
    output reg  [IDX_W-1:0]  rd_k,
    output reg               feed_valid,   // aligned with buffer read data
    output reg               capture,
    output reg               busy,
    output reg               done,
    output reg  [15:0]       cycle_count,
    output wire [2:0]        state_dbg
);
    localparam S_IDLE    = 3'd0,
               S_CLEAR   = 3'd1,
               S_FEED    = 3'd2,
               S_DRAIN   = 3'd3,
               S_CAPTURE = 3'd4,
               S_DONE    = 3'd5;

    // Exact number of cycles between the last buffer read and the cycle in
    // which PE(N-1,N-1) performs its final accumulation:
    //   1 (buffer register) + (N-1) (skew lane) + (N-1) (mesh hops) = 2N-1
    //   (+1 when the MAC product is pipelined, PIPE = 1)
    localparam DRAIN_CYCLES = 2*N - 1 + PIPE;

    reg [2:0]       state;
    reg [CNT_W-1:0] cnt;

    assign state_dbg = state;

    always @(posedge clk) begin
        if (rst) begin
            state       <= S_IDLE;
            cnt         <= 0;
            clear       <= 1'b0;
            rd_en       <= 1'b0;
            rd_k        <= 0;
            feed_valid  <= 1'b0;
            capture     <= 1'b0;
            busy        <= 1'b0;
            done        <= 1'b0;
            cycle_count <= 16'd0;
        end else begin
            // defaults
            clear      <= 1'b0;
            capture    <= 1'b0;
            done       <= 1'b0;
            feed_valid <= rd_en;           // buffer has 1-cycle read latency
            if (busy) cycle_count <= cycle_count + 16'd1;

            case (state)
            S_IDLE: begin
                rd_en <= 1'b0;
                if (start) begin
                    state       <= S_CLEAR;
                    clear       <= 1'b1;
                    busy        <= 1'b1;
                    cycle_count <= 16'd0;
                end
            end
            S_CLEAR: begin
                state <= S_FEED;
                rd_en <= 1'b1;
                rd_k  <= 0;
                cnt   <= 0;
            end
            S_FEED: begin
                if (rd_k == N-1) begin
                    rd_en <= 1'b0;
                    state <= S_DRAIN;
                    cnt   <= 1;
                end else begin
                    rd_k <= rd_k + 1'b1;
                end
            end
            S_DRAIN: begin
                if (cnt == DRAIN_CYCLES) begin
                    state   <= S_CAPTURE;
                    capture <= 1'b1;
                end else
                    cnt <= cnt + 1'b1;
            end
            S_CAPTURE: begin
                state <= S_DONE;
                done  <= 1'b1;
                busy  <= 1'b0;
            end
            S_DONE: begin
                state <= S_IDLE;
            end
            default: state <= S_IDLE;
            endcase
        end
    end
endmodule

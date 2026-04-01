module top#(parameter N = 2)(
    input clk,
    input rst_n,
    input start,
    input [15:0] w2 [0:N-1][0:N-1],
    input [15:0] w1 [0:N-1][0:N-1],
    input [15:0] b1 [0:N-1],
    input [15:0] b2 [0:N-1],
    input [15:0] x  [0:N-1],
    output logic [15:0] y [0:N-1],
    output logic done,

    // Debug observation ports (directly driven, no hierarchy needed)
    output logic [15:0] dbg_mac_out   [0:N-1],
    output logic [15:0] dbg_gelu_out  [0:N-1],
    output logic [15:0] dbg_mac_out_2 [0:N-1]
);
    logic [15:0] mac_out   [0:N-1];
    logic [15:0] gelu_out  [0:N-1];
    logic [15:0] mac_out_2 [0:N-1];
    logic ready_reg1 [0:N-1];
    logic ready_reg2 [0:N-1];
    logic done_reg1  [0:N-1];
    logic done_reg2  [0:N-1];
    logic start_d1, start_d2, start_d3, start_d4;
    logic done_all;
    logic done_all_d;

    // Layer 1: h[i] = W1[i][:] · x[:] + b1[i]
    genvar i;
    generate
        for (i = 0; i < N; i++) begin : gen_mac1
            mac8 #(N) mac1_inst (
                .clk       (clk),
                .rst_n     (rst_n),
                .start     (start),
                .data_in_a (w1[i]),       // full row i of W1
                .data_in_b (x),           // shared input vector x
                .data_in_c (b1[i]),       // scalar bias for neuron i
                .ready     (ready_reg1[i]),
                .done      (done_reg1[i]),
                .data_out  (mac_out[i])
            );
        end
    endgenerate

    // GELU applied element-wise to the hidden vector
    gelu_pwl #(N) gelu_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .data_in  (mac_out),
        .data_out (gelu_out)
    );

    // Layer 2: y[k] = W2[k][:] · gelu_out[:] + b2[k]
    genvar k;
    generate
        for (k = 0; k < N; k++) begin : gen_mac2
            mac8 #(N) mac2_inst (
                .clk       (clk),
                .rst_n     (rst_n),
                .start     (start_d2),
                .data_in_a (w2[k]),        // full row k of W2
                .data_in_b (gelu_out),     // full hidden vector
                .data_in_c (b2[k]),        // scalar bias for output neuron k
                .ready     (ready_reg2[k]),
                .done      (done_reg2[k]),
                .data_out  (mac_out_2[k])  // write to mac_out_2, not mac_out
            );
        end
    endgenerate

    // Register layer 2 output
    // Reduce across unpacked array elements (Questasim won't allow `&done_reg2` directly).
    always_comb begin
        done_all = 1'b1;
        for (int ii = 0; ii < N; ii++)
            done_all = done_all & done_reg2[ii];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int ii = 0; ii < N; ii++)
                y[ii] <= 16'h0000;
            done     <= 1'b0;
            start_d1 <= 1'b0;
            start_d2 <= 1'b0;
            start_d3 <= 1'b0;
            start_d4 <= 1'b0;
            done_all_d <= 1'b0;
        end else begin
            start_d1 <= start;
            start_d2 <= start_d1;
            start_d3 <= start_d2;
            start_d4 <= start_d3;
            for (int ii = 0; ii < N; ii++)
                y[ii] <= mac_out_2[ii];
            // mac8.done pulses the same cycle it updates data_out (nonblocking).
            // y <= mac_out_2 is captured one cycle later, so delay done by 1.
            done_all_d <= done_all;
            done <= done_all_d;
        end
    end

    assign dbg_mac_out   = mac_out;
    assign dbg_gelu_out  = gelu_out;
    assign dbg_mac_out_2 = mac_out_2;

endmodule
module top#(parameter N = 2)(
    input clk,
    input rst_n,
    input [15:0] w2 [0:N-1][0:N-1],
    input [15:0] w1 [0:N-1][0:N-1],
    input [15:0] b1 [0:N-1][0:N-1],
    input [15:0] b2 [0:N-1][0:N-1],
    input [15:0] x  [0:N-1][0:N-1],
    output logic [15:0] y [0:N-1][0:N-1]
);
    logic [15:0] mac_out  [0:N-1][0:N-1];
    logic [15:0] gelu_out [0:N-1][0:N-1];
    logic [15:0] mac_out_2 [0:N-1][0:N-1];
    logic ready_reg1 [0:N-1][0:N-1];
    logic ready_reg2 [0:N-1][0:N-1];

    // Layer 1: h[i] = W1[i][:] · x[:] + b1[i]
    genvar i;
    generate
        for (i = 0; i < N; i++) begin : gen_mac1
            mac8 #(N) mac1_inst (
                .clk       (clk),
                .rst_n     (rst_n),
                .data_in_a (w1[i]),       // full row i of W1
                .data_in_b (x[i]),        // full row i of x
                .data_in_c (b1[i]),       // full row i of b1
                .ready     (ready_reg1[i]),
                .data_out  (mac_out[i])
            );
        end
    endgenerate

    // GELU applied element-wise on mac_out
    // GELU — one instance per row, each handles N elements
    genvar j;
    generate
        for (j = 0; j < N; j++) begin : gen_gelu
            gelu_pwl #(N) gelu_inst (
                .clk      (clk),
                .rst_n    (rst_n),
                .data_in  (mac_out[j]),   // row j — N elements
                .data_out (gelu_out[j])   // row j output
            );
        end
    endgenerate

    // Layer 2: y[k] = W2[k][:] · gelu_out[:] + b2[k]
    genvar k;
    generate
        for (k = 0; k < N; k++) begin : gen_mac2
            mac8 #(N) mac2_inst (
                .clk       (clk),
                .rst_n     (rst_n),
                .data_in_a (w2[k]),        // full row k of W2
                .data_in_b (gelu_out[k]),  // full row k of gelu_out
                .data_in_c (b2[k]),        // full row k of b2
                .ready     (ready_reg2[k]),
                .data_out  (mac_out_2[k])  // write to mac_out_2, not mac_out
            );
        end
    endgenerate

    // Register layer 2 output
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int ii = 0; ii < N; ii++)
                for (int jj = 0; jj < N; jj++)
                    y[ii][jj] <= 16'h0000;
        end else begin
            for (int ii = 0; ii < N; ii++)
                for (int jj = 0; jj < N; jj++)
                    y[ii][jj] <= mac_out_2[ii][jj];  //  was mac_out
        end
    end

endmodule
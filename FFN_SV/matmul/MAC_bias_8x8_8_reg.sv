// =============================================================================
// MAC_bias_8x8_8_reg.sv
// Wraps MAC_8x8_8_reg with a bias adder stage.
//   1. MAC_8x8_8_reg:   computes the matrix partial product for one column
//   2. regnbit:          registers the bias input (b_col) for timing alignment
//   3. bias_sum_8_8:     adds registered bias to all 8 MAC outputs
//
// Replaces MAC_bias_8x8_8_reg.vhd
// =============================================================================

module MAC_bias_8x8_8_reg (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        en,

    input  logic [15:0] input_row [0:7],
    input  logic [15:0] input_col [0:7],

    input  logic [15:0] b_col,       // Single bias value broadcast to all rows
    input  logic [2:0]  sel_mux,

    output logic [15:0] output_row [0:7]
);

    // Internal wires from MAC array to bias adder
    logic [15:0] mac_base_out [0:7];
    logic signed [15:0] b_col_reg;

    // ---- Stage 1: 8x8 MAC array ----
    MAC_8x8_8_reg mac_base (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (en),
        .input_row (input_row),
        .input_col (input_col),
        .sel_mux   (sel_mux),
        .output_row(mac_base_out)
    );

    // ---- Stage 2: Register bias (align with MAC output latency) ----
    regnbit #(16) bias_reg (
        .clk  (clk),
        .rst_n(rst_n),
        .en   (1'b1),
        .d    (b_col),
        .q    (b_col_reg)
    );

    // ---- Stage 3: Bias addition ----
    // Cast mac_base_out to signed for the bias_sum_8_8 interface
    logic signed [15:0] mac_signed [0:7];
    logic signed [15:0] out_signed  [0:7];

    always_comb begin
        for (int i = 0; i < 8; i++)
            mac_signed[i] = signed'(mac_base_out[i]);
    end

    bias_sum_8_8 bias_sum (
        .input_row (mac_signed),
        .b_col     (b_col_reg),
        .output_row(out_signed)
    );

    always_comb begin
        for (int i = 0; i < 8; i++)
            output_row[i] = out_signed[i];
    end

endmodule : MAC_bias_8x8_8_reg

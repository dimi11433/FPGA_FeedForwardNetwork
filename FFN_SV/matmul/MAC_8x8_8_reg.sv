// =============================================================================
// MAC_8x8_8_reg.sv
// 8x8 grid of MAC units. Each row produces 8 partial products (one per column).
// A mux selects one column of results per row, then a register captures it.
//
// Data flow per row r:
//   reg_rows[r] x reg_cols[c]  ->  mac_outs[r][c]  (for c = 0..7)
//   mux_8to1 selects col via sel  ->  mux_out[r]
//   output register captures mux_out[r]
//
// SEL and ENABLE are pipelined one cycle to align with input registers.
// Replaces MAC_8x8_8_reg.vhd
// =============================================================================

module MAC_8x8_8_reg (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        en,
    input  logic [15:0] input_row [0:7],
    input  logic [15:0] input_col [0:7],
    input  logic [2:0]  sel_mux,
    output logic [15:0] output_row [0:7]
);

    // Registered inputs
    logic [15:0] reg_rows [0:7];
    logic [15:0] reg_cols [0:7];

    // MAC output grid [row][col]
    logic [15:0] mac_outs [0:7][0:7];

    // Mux and output register signals
    logic [15:0] mux_outs  [0:7];
    logic [15:0] reg_outs  [0:7];

    // Pipelined control
    logic [2:0]  reg_sel;
    logic        reg_en;

    // ---- Pipeline enable and sel by 1 cycle ----
    ff    ff_en  (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(en),           .q(reg_en));
    regnbit #(3) sel_reg (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(sel_mux), .q(reg_sel));

    // ---- Generate 8 rows ----
    genvar r, c;
    generate
        for (r = 0; r < 8; r++) begin : gen_rows

            // Register each input row and column element
            regnbit #(16) row_reg (.clk(clk), .rst_n(rst_n), .en(en), .d(input_row[r]), .q(reg_rows[r]));
            regnbit #(16) col_reg (.clk(clk), .rst_n(rst_n), .en(en), .d(input_col[r]), .q(reg_cols[r]));

            // Generate 8 MAC units across columns
            for (c = 0; c < 8; c++) begin : gen_cols
                MAC #(.DATA_SIZE(16), .ACC_SIZE(16)) mac_inst (
                    .clk       (clk),
                    .rst_n     (rst_n),
                    .en        (reg_en),
                    .data_in_a (reg_rows[r]),
                    .data_in_b (reg_cols[c]),
                    .data_out  (mac_outs[r][c])
                );
            end

            // 8-to-1 mux selects which column's accumulated result to read out
            mux_8to1_nbit #(16) mux_inst (
                .i0(mac_outs[r][0]), .i1(mac_outs[r][1]),
                .i2(mac_outs[r][2]), .i3(mac_outs[r][3]),
                .i4(mac_outs[r][4]), .i5(mac_outs[r][5]),
                .i6(mac_outs[r][6]), .i7(mac_outs[r][7]),
                .sel(reg_sel),
                .y  (mux_outs[r])
            );

            // Output register
            regnbit #(16) out_reg (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(mux_outs[r]), .q(reg_outs[r]));

            assign output_row[r] = reg_outs[r];
        end
    endgenerate

endmodule : MAC_8x8_8_reg

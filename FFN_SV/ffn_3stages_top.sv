// =============================================================================
// ffn_3stages_top.sv
// Top-level Feed-Forward Network (FFN) accelerator.
//
// Computes: Output = GeLU(A x B + bias1) x C + bias2
//
// Three pipeline stages:
//   Stage 1 — MAC (A x B) + bias1     : MAC_bias_8x8_8_reg (inst_mac1)
//   Stage 2 — GeLU activation          : gelu_parallel      (inst_gelu)
//   Stage 3 — MAC (D x C) + bias2     : MAC_bias_8x8_8_reg (inst_mac2)
//             where D = GeLU output
//
// An FSM sequences the data loading and output reading across both MAC stages,
// accounting for the 4-cycle GeLU pipeline latency between them.
//
// All data is Q8.8 signed fixed-point (16-bit).
// Matrices are 8x8; mat[row][col] indexing.
//
// Replaces FFN_3stages.vhd
// =============================================================================

module ffn_3stages_top
    import ffn_pkg::*;
(
    input  logic          clk,
    input  logic          rst_n,      // Active-low async reset

    input  mat_2d_8_8_t   mat_a,      // Input activation matrix
    input  mat_2d_8_8_t   mat_b,      // Weight matrix 1
    input  mat_2d_8_8_t   mat_c,      // Weight matrix 2
    input  logic [15:0]   b_col_1,    // Bias for stage 1
    input  logic [15:0]   b_col_2,    // Bias for stage 2

    output logic [15:0]   final_out [0:7]  // 8-element output vector
);

    // =========================================================================
    // FSM state encoding
    // =========================================================================
    typedef enum logic [2:0] {
        IDLE                   = 3'd0,
        LOAD_AB_COLS_ROWS      = 3'd1,
        READ_AB_COLS_INIT      = 3'd2,
        READ_AB_COLS           = 3'd3,
        READ_FINAL_COLS_INIT   = 3'd4,
        READ_FINAL_COLS        = 3'd5
    } state_t;

    state_t state_reg, state_next;

    // =========================================================================
    // Datapath signals
    // =========================================================================

    // Column of A and row of B being fed to MAC stage 1
    logic [15:0] col_in_a [0:7];
    logic [15:0] row_in_b [0:7];

    // MAC stage 1 outputs (pre-GeLU)
    logic [15:0] mac1_out [0:7];

    // GeLU in/out buses
    bus_array_t gelu_in_bus;
    bus_array_t gelu_out_bus;

    // Row of C fed to MAC stage 2 (GeLU output is the column input)
    logic [15:0] mat_c_col [0:7];

    // Control signals
    logic        enable_1, enable_2;
    logic [2:0]  sel_mux_1_reg, sel_mux_1_next;
    logic [2:0]  sel_mux_2_reg, sel_mux_2_next;

    // Loop indices (registered)
    logic [2:0]  ab_idx_reg,  ab_idx_next;   // column of A / row of B
    logic [2:0]  dc_idx_reg,  dc_idx_next;   // column of D / row of C

    // =========================================================================
    // Stage 1: First matrix multiply  A x B + bias1
    // =========================================================================
    MAC_bias_8x8_8_reg inst_mac1 (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (enable_1),
        .input_row (col_in_a),
        .input_col (row_in_b),
        .b_col     (b_col_1),
        .sel_mux   (sel_mux_1_reg),
        .output_row(mac1_out)
    );

    // Wire MAC1 output to GeLU input bus
    always_comb begin
        for (int i = 0; i < 8; i++)
            gelu_in_bus[i] = mac1_out[i];
    end

    // =========================================================================
    // Stage 2: GeLU activation (4-cycle pipeline latency)
    // =========================================================================
    gelu_parallel inst_gelu (
        .clk     (clk),
        .rst_n   (rst_n),
        .data_in (gelu_in_bus),
        .data_out(gelu_out_bus)
    );

    // =========================================================================
    // Stage 3: Second matrix multiply  GeLU(AB) x C + bias2
    // The GeLU output feeds directly as the column vector to MAC2.
    // =========================================================================
    logic [15:0] gelu_res [0:7];
    always_comb begin
        for (int i = 0; i < 8; i++)
            gelu_res[i] = gelu_out_bus[i];
    end

    MAC_bias_8x8_8_reg inst_mac2 (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (enable_2),
        .input_row (gelu_res),
        .input_col (mat_c_col),
        .b_col     (b_col_2),
        .sel_mux   (sel_mux_2_reg),
        .output_row(final_out)
    );

    // =========================================================================
    // Sequential: state and data registers
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg     <= IDLE;
            sel_mux_1_reg <= '0;
            sel_mux_2_reg <= '0;
            ab_idx_reg    <= '0;
            dc_idx_reg    <= '0;
        end else begin
            state_reg     <= state_next;
            sel_mux_1_reg <= sel_mux_1_next;
            sel_mux_2_reg <= sel_mux_2_next;
            ab_idx_reg    <= ab_idx_next;
            dc_idx_reg    <= dc_idx_next;
        end
    end

    // =========================================================================
    // Combinational: next-state and output logic
    // =========================================================================
    always_comb begin
        // Defaults (prevent latches)
        state_next     = state_reg;
        sel_mux_1_next = sel_mux_1_reg;
        sel_mux_2_next = sel_mux_2_reg;
        ab_idx_next    = ab_idx_reg;
        dc_idx_next    = dc_idx_reg;

        enable_1 = 1'b0;
        enable_2 = 1'b0;

        col_in_a  = '{default: '0};
        row_in_b  = '{default: '0};
        mat_c_col = '{default: '0};

        unique case (state_reg)

            // -----------------------------------------------------------------
            IDLE: begin
                enable_1    = 1'b1;
                ab_idx_next = '0;
                state_next  = LOAD_AB_COLS_ROWS;
            end

            // -----------------------------------------------------------------
            // Feed one column of A and corresponding row of B per cycle (x8)
            // -----------------------------------------------------------------
            LOAD_AB_COLS_ROWS: begin
                enable_1 = 1'b1;

                for (int r = 0; r < 8; r++)
                    col_in_a[r] = mat_a[r][ab_idx_reg];

                for (int c = 0; c < 8; c++)
                    row_in_b[c] = mat_b[ab_idx_reg][c];

                if (ab_idx_reg < 3'd7)
                    ab_idx_next = ab_idx_reg + 3'd1;
                else
                    state_next  = READ_AB_COLS_INIT;
            end

            // -----------------------------------------------------------------
            // Disable accumulator and initialise mux counter
            // -----------------------------------------------------------------
            READ_AB_COLS_INIT: begin
                enable_1       = 1'b0;
                sel_mux_1_next = '0;
                state_next     = READ_AB_COLS;
            end

            // -----------------------------------------------------------------
            // Advance mux to read each column of the A×B result.
            // After 6 cycles the first GeLU output is valid (4-cycle latency
            // plus the 2 cycles already consumed), so start MAC2 then.
            // -----------------------------------------------------------------
            READ_AB_COLS: begin
                if (sel_mux_1_reg < 3'd7)
                    sel_mux_1_next = sel_mux_1_reg + 3'd1;

                // GeLU output is valid from sel_mux_1 > 5 onward
                if (sel_mux_1_reg > 3'd5) begin
                    enable_2 = 1'b1;

                    for (int c = 0; c < 8; c++)
                        mat_c_col[c] = mat_c[dc_idx_reg][c];

                    if (dc_idx_reg < 3'd7)
                        dc_idx_next = dc_idx_reg + 3'd1;
                    else
                        state_next = READ_FINAL_COLS_INIT;
                end
            end

            // -----------------------------------------------------------------
            // Disable MAC2 accumulator and reset output mux
            // -----------------------------------------------------------------
            READ_FINAL_COLS_INIT: begin
                enable_2       = 1'b0;
                sel_mux_2_next = '0;
                state_next     = READ_FINAL_COLS;
            end

            // -----------------------------------------------------------------
            // Clock out each output column, then return to IDLE
            // -----------------------------------------------------------------
            READ_FINAL_COLS: begin
                if (sel_mux_2_reg < 3'd7)
                    sel_mux_2_next = sel_mux_2_reg + 3'd1;
                else
                    state_next = IDLE;
            end

            default: state_next = IDLE;

        endcase
    end

endmodule : ffn_3stages_top

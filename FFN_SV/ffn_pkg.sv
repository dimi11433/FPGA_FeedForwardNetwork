// =============================================================================
// ffn_pkg.sv
// Merges ffn_top_pkg.vhd and gelu_pkg.vhd into a single SystemVerilog package.
// All data is Q8.8 fixed-point, represented as signed 16-bit values.
// =============================================================================

package ffn_pkg;

    // -------------------------------------------------------------------------
    // Typedefs (replacing VHDL array types)
    // -------------------------------------------------------------------------
    typedef logic signed [15:0] q88_t;

    // 1D array: 8 x 16-bit (one row or column vector)
    typedef q88_t arr_t [0:7];

    // 2D array: 8x8 x 16-bit (full matrix)
    typedef q88_t mat_2d_8_8_t [0:7][0:7];

    // Array type used by the gelu parallel block
    typedef logic [15:0] bus_array_t [0:7];

    // -------------------------------------------------------------------------
    // GeLU Piecewise-Linear LUT constants
    // Indexed by bits [10:6] of the Q8.8 input (5-bit unsigned index, 0-31).
    // Values are Q8.8 signed.
    // -------------------------------------------------------------------------
    typedef logic signed [15:0] lut_t [0:31];

    // Slope (M) LUT
    localparam lut_t M_LUT = '{
        16'h0994, 16'h0C8C, 16'h0EFF, 16'h10BA,
        16'h11B4, 16'h120A, 16'h11ED, 16'h1193,
        16'h104C, 16'h104C, 16'h104C, 16'h104C,
        16'h104C, 16'h104C, 16'h104C, 16'h104C,
        16'hFFEB, 16'hFFEB, 16'hFFEB, 16'hFFEB,
        16'hFFEB, 16'hFF09, 16'hFF09, 16'hFF09,
        16'hFE6D, 16'hFE13, 16'hFDF6, 16'hFE4C,
        16'hFF46, 16'h0101, 16'h0374, 16'h066C
    };

    // Y-intercept (C) LUT
    localparam lut_t C_LUT = '{
        16'h0000, 16'hFF42, 16'hFE09, 16'hFCBD,
        16'hFBC3, 16'hFB57, 16'hFB81, 16'hFC20,
        16'hFEF5, 16'hFEF5, 16'hFEF5, 16'hFEF5,
        16'hFEF5, 16'hFEF5, 16'hFEF5, 16'hFEF5,
        16'hFFB1, 16'hFFB1, 16'hFFB1, 16'hFFB1,
        16'hFFB1, 16'hFD60, 16'hFD60, 16'hFD60,
        16'hFC20, 16'hFB81, 16'hFB57, 16'hFBC3,
        16'hFCBD, 16'hFE09, 16'hFF42, 16'h0000
    };

endpackage : ffn_pkg

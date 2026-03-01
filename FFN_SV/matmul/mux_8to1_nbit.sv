// =============================================================================
// mux_8to1_nbit.sv
// Parameterized 8-to-1 mux, built from two 4-to-1 muxes and one 2-to-1 mux.
// Replaces mux_8to1_nbit.vhd
// =============================================================================

module mux_8to1_nbit #(
    parameter int N = 16
) (
    input  logic [N-1:0] i0, i1, i2, i3,
    input  logic [N-1:0] i4, i5, i6, i7,
    input  logic [2:0]   sel,
    output logic [N-1:0] y
);

    logic [N-1:0] m0_out, m1_out;

    mux_4to1_nbit #(N) m0 (.i0(i0), .i1(i1), .i2(i2), .i3(i3), .sel(sel[1:0]), .y(m0_out));
    mux_4to1_nbit #(N) m1 (.i0(i4), .i1(i5), .i2(i6), .i3(i7), .sel(sel[1:0]), .y(m1_out));
    mux_2to1_nbit #(N) mout (.i0(m0_out), .i1(m1_out), .sel(sel[2]), .y(y));

endmodule : mux_8to1_nbit

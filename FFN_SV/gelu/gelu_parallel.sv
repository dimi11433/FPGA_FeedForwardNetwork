// =============================================================================
// gelu_parallel.sv
// Instantiates 8 independent gelu_pwl cores to process one full vector
// (one column of the intermediate matrix) in parallel.
// Replaces gelu_parallel.vhd
// =============================================================================

module gelu_parallel
    import ffn_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  bus_array_t  data_in,   // 8 x 16-bit Q8.8 inputs
    output bus_array_t  data_out   // 8 x 16-bit Q8.8 outputs (4-cycle latency)
);

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : gen_gelu_cores
            gelu_pwl core (
                .clk     (clk),
                .rst_n   (rst_n),
                .data_in (data_in[i]),
                .data_out(data_out[i])
            );
        end
    endgenerate

endmodule : gelu_parallel

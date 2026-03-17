module mac8 #(parameter N = 8)(
    input clk,
    input rst_n,
    input [15:0] data_in_a [0: N-1],
    input [15:0] data_in_b [0: N-1],
    input [15:0] data_in_c [0: N-1],
    output logic ready [0: N-1],
    output logic [15:0] data_out [0: N-1]
);


    genevar i;
    generate
        for (i = 0; i < N; i = i + 1)begin
            mac_8cyc accum_block(.clk(clk), .rst_n(rst_n), .data_in_a(data_in_a[i]), .data_in_b(data_in_b[i]), .data_in_c(data_in_c[i]), .data_out(data_out[i]), .ready(ready[i]));
        end 
    endgenerate

    
endmodule
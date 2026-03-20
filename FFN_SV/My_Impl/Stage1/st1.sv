`include "bf16-LUT.sv"
`include "gelu-LUT.sv"

module gelu_pwl #(parameter N = 2)(
    input clk,
    input rst_n,
    input logic [15:0] data_in [N-1:0],
    output logic [15:0] data_out [N-1:0]

);

    logic [4:0] bf16_index [N-1:0];
    logic [4:0] gelu_index [N-1:0];
    bf16_LUT bf16_index1(data_in[0], bf16_index[0]);
    bf16_LUT bf16_index2(data_in[1], bf16_index[1]);

    gelu_LUT gelu_index1(bf16_index[0], gelu_index[0]);
    gelu_LUT gelu_index2(bf16_index[1], gelu_index[1]);

    always_ff@(posedge clk) begin
        if(rst_n) begin
            bf16_index <= '0;
            gelu_index <= '0;
        end else begin
            data_out[0] <= gelu_index[0];
            data_out[1] <= gelu_index[1];
        end
    end 


//So the input is 8*8 matrix this module will specifically handle one value of the matrix
//We will also have a module for the entire column so each 8 values can be handled in parallel 

          

    




endmodule; 
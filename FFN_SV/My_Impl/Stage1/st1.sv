`include "design1.sv"
`include "fp32_mul.sv"

module gelu_pwl #(parameter N = 2)(
    input clk,
    input rst_n,
    input [15:0] data_in [0:N-1],
    output logic [15:0] out_intercept [0:N-1],
    output logic [15:0] out_slope [0:N-1]

);

    logic [4:0] bf16_index [0:N-1];
    logic [15:0] intercept [0:N-1];
    logic [15:0] slope [0:N-1];
    bf16_LUT bf16_index1(data_in[0], bf16_index[0]);
    bf16_LUT bf16_index2(data_in[1], bf16_index[1]);

    gelu_LUT gelu_index1(.index_in(bf16_index[0]), .slope_out(slope[0]), .intercept_out(intercept[0]));
    gelu_LUT gelu_index2(.index_in(bf16_index[1]), .slope_out(slope[1]), .intercept_out(intercept[1]));

    always_ff@(posedge clk) begin
      if(!rst_n) begin
          for(int i = 0; i < N; i ++ )begin
            bf16_index[i] <= '0;
            intercept[i] <= '0;
            slope[i] <= '0;
          end 
            
        end else begin
            out_intercept[0] <= intercept[0];
            out_intercept[1] <= intercept[1];
            out_slope[0] <= slope[0];
            out_slope[1] <= slope[1];
        end
    end 


//So the input is 8*8 matrix this module will specifically handle one value of the matrix
//We will also have a module for the entire column so each 8 values can be handled in parallel 

endmodule
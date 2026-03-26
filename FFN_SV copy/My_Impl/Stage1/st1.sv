
module gelu_pwl #(parameter N = 2)(
  input clk,
  input rst_n,
  input [15:0] data_in [0:N-1],
  output logic [15:0] data_out[0:N-1]    

);

  logic [4:0] bf16_index [0:N-1];
  logic [15:0] intercept [0:N-1];
  logic [15:0] slope [0:N-1];

  logic [31:0] reg_out1 [0:N-1];
  logic [31:0] reg_out2 [0:N-1];

  logic[31:0] slope_long [0:N-1];
  logic[31:0] intercept_long [0:N-1];

  logic[31:0] data_long [0:N-1];
  //logic[31:0] data2_long [0:N-1];

  
  bf16_LUT bf16_index1(data_in[0], bf16_index[0]);
  bf16_LUT bf16_index2(data_in[1], bf16_index[1]);

  gelu_LUT gelu_index1(.index_in(bf16_index[0]), .slope_out(slope[0]), .intercept_out(intercept[0]));
  gelu_LUT gelu_index2(.index_in(bf16_index[1]), .slope_out(slope[1]), .intercept_out(intercept[1]));

  // bf16 → fp32: pad lower 16 mantissa bits with zeros (bf16 has 7 mantissa, fp32 has 23)
  assign slope_long[0] = {slope[0], 16'h0000};
  assign slope_long[1] = {slope[1], 16'h0000};
  
  assign intercept_long[0] = {intercept[0], 16'h0000};
  assign intercept_long[1] = {intercept[1], 16'h0000};
      
  assign data_long[0] = {data_in[0], 16'h0000};
  assign data_long[1] = {data_in[1], 16'h0000};


  fp32_mul mul1(slope_long[0], data_long[0], reg_out1[0]);
  fp32_mul mul2(slope_long[1], data_long[1], reg_out1[1]);

  fp32_add add1(reg_out1[0], intercept_long[0], reg_out2[0]);
  fp32_add add2(reg_out1[1], intercept_long[1], reg_out2[1]);

  always_ff@(posedge clk) begin
    if(!rst_n) begin
        for(int i = 0; i < N; i ++ )begin
          data_out[i] <= '0;
          
        end 
        
      end else begin
          // fp32 → bf16 with round-to-nearest
          data_out[0] <= (reg_out2[0][15] && reg_out2[0][31:16] != 16'hFFFF)
              ? (reg_out2[0][31:16] + 16'd1) : reg_out2[0][31:16];
          data_out[1] <= (reg_out2[1][15] && reg_out2[1][31:16] != 16'hFFFF)
              ? (reg_out2[1][31:16] + 16'd1) : reg_out2[1][31:16];
      end
  end 


//So the input is 8*8 matrix this module will specifically handle one value of the matrix
//We will also have a module for the entire column so each 8 values can be handled in parallel 

endmodule
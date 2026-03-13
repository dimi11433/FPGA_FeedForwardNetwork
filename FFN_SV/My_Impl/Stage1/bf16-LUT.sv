module bf16_LUT(
    input [15:0] data_in,
    ouput [3:0] data_out

);

    always_comb begin
        if (data_in[15])begin
           data_out = 0;
           unique case(data_in)
            (data_in > 16'hC080) : data_out = 0;
            (data_in > 16'hC060) : data_out = 1;
            (data_in > 16'hC040) : data_out = 2;
            (data_in > 16'hC020) : data_out = 3;
            (data_in > 16'hC000) : data_out = 4;
            (data_in > 16'hBFC0) : data_out = 5;
            (data_in > 16'hBF80) : data_out = 6;
            default : data_out = 7;
           endcase 
        end 
        else begin
            data_out = 0;
            unique case(data_in)
            (data_in < 16'h3F00) : data_out = 8;
            (data_in < 16'h3F80) : data_out = 9;
            (data_in < 16'h3FC0) : data_out = 10;
            (data_in < 16'h4000) : data_out = 11;
            (data_in < 16'h4020) : data_out = 12;
            (data_in < 16'h4040) : data_out = 13;
            (data_in < 16'h4060) : data_out = 14;
            (data_in < 16'h4080) : data_out = 15;
            default : data_out = 16;
           endcase 
        end 
    
    end

endmodule; 
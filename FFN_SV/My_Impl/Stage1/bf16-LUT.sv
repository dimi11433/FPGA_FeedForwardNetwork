module bf16_LUT(
    input [15:0] data_in,
    output logic [5:0] data_out

);

    logic sign;
    logic [7:0] exponent;
    logic [6:0] mantissa;

    assign sign = data_in[15];
    assign exponent = data_in[14:7];
    assign mantissa = data_in[6:0];

    always_comb begin
        data_out = 0;
        if(sign) begin
            if      (data_in > 16'hC080) data_out = 0;   //smaller than -4
            else if (data_in > 16'hC070) data_out = 1;
            else if (data_in > 16'hC060) data_out = 2;
            else if (data_in > 16'hC050) data_out = 3;
            else if (data_in > 16'hC040) data_out = 4;
            else if (data_in > 16'hC030) data_out = 5;
            else if (data_in > 16'hC020) data_out = 6;
            else if (data_in > 16'hC010) data_out = 7;
            else if (data_in > 16'hC000) data_out = 8;
            else if (data_in > 16'hBFE0) data_out = 9;
            else if (data_in > 16'hBFC0) data_out = 10;
            else if (data_in > 16'hBFA0) data_out = 11;
            else if (data_in > 16'hBF80) data_out = 12;
            else if (data_in > 16'hBF40) data_out = 13;
            else if (data_in > 16'hBF00) data_out = 14;
            else if (data_in > 16'hBE80) data_out = 15;  //smaller than -0.25
            else                         data_out = 16;  //smaller than 0 but greater than -0.25
        end
        else begin
            if      (data_in > 16'h4080) data_out = 17;  //greater than +4
            else if (data_in > 16'h4070) data_out = 18;  // greater than +3.75
            else if (data_in > 16'h4060) data_out = 19;  // greater than +3.5
            else if (data_in > 16'h4050) data_out = 20;  // greater than +3.25
            else if (data_in > 16'h4040) data_out = 21;  // greater than +3.00
            else if (data_in > 16'h4030) data_out = 22;  //greater than +2.750
            else if (data_in > 16'h4020) data_out = 23;  //greater than +2.5
            else if (data_in > 16'h4010) data_out = 24;  //greater than +2.25
            else if (data_in > 16'h4000) data_out = 25;  //greater than +2.00
            else if (data_in > 16'h3FE0) data_out = 26;  //greater than +1.75
            else if (data_in > 16'h3FC0) data_out = 27;  //greater than +1.50
            else if (data_in > 16'h3FA0) data_out = 28;  //greater than +1.25
            else if (data_in > 16'h3F80) data_out = 29;  //greater than +1.00
            else if (data_in > 16'h3F40) data_out = 30;  //greater than +0.75
            else if (data_in > 16'h3F00) data_out = 31;  //greater than +0.50
            else if (data_in > 16'h3E80) data_out = 32;  //greater than +0.25
            else if (data_in > 16'h0000) data_out = 33;
            else                         data_out = 0;   // data_in == 0
        end
    end

endmodule 
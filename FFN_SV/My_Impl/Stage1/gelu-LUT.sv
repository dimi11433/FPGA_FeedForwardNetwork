module gelu_LUT(
    input [5:0] index_in,
    output logic [15:0] slope_out,
    output logic [15:0] intercept_out

);

    always_comb begin
        //slopes && intercepts
        case(index_in)
            0: begin
                slope_out = 16'h0000;
                intercept_out = 16'h0000;
            end 
            1: begin
                slope_out = 16'hba56;
                intercept_out = 16'hbb5f;
            end
            2: begin
                slope_out = 16'hbafd;
                intercept_out = 16'hbbf8;
            end
            3: begin
                slope_out = 16'hbb8b;
                intercept_out = 16'hbc80 ;
            end
            4: begin
                slope_out = 16'hbc0e;
                intercept_out = 16'hbcf6 ;
            end
            5: begin
                slope_out = 16'hbc87;
                intercept_out = 16'hbd5c ;
            end
            6: begin
                slope_out = 16'hbcf0;
                intercept_out = 16'hbdb5 ;
            end
            7: begin
                slope_out = 16'hbd44;
                intercept_out = 16'hbe0a ;
            end
            8: begin
                slope_out = 16'hbd93;
                intercept_out = 16'hbe42 ;
            end
            9: begin
                slope_out = 16'hbdc9;
                intercept_out = 16'hbe78  ;
            end
            10: begin
                slope_out = 16'hbdf6;
                intercept_out = 16'hbe8f ;
            end
            11: begin
                slope_out = 16'hbe02;
                intercept_out = 16'hbe95 ;
            end
            12: begin
                slope_out = 16'hbdd9;
                intercept_out = 16'hbe87;
            end
            13: begin
                slope_out = 16'hbd39;
                intercept_out = 16'hbe50  ;
            end
            14: begin
                slope_out = 16'h3d80;
                intercept_out = 16'hbdfb ;
            end
            15: begin
                slope_out = 16'h3e5c;
                intercept_out = 16'hbd3d ;
            end
            16: begin
                slope_out = 16'h3ecd;
                intercept_out = 16'h0000  ;
            end
            33: begin
                slope_out = 16'h3f19;
                intercept_out = 16'h0000 ;
            end
            32: begin
                slope_out = 16'h3f48;
                intercept_out = 16'hbd3d ;
            end
            31: begin
                slope_out = 16'h3f6f;
                intercept_out = 16'hbdfb ;
            end
            30: begin
                slope_out = 16'h3f85;
                intercept_out = 16'hbe50 ;
            end
            29: begin
                slope_out = 16'h3f8d;
                intercept_out = 16'hbe87 ;
            end
            28: begin
                slope_out = 16'h3f90;
                intercept_out = 16'hbe95 ;
            end
            27: begin
                slope_out = 16'h3f8f;
                intercept_out = 16'hbe8f ;
            end
            26: begin
                slope_out = 16'h3f8c;
                intercept_out = 16'hbe78 ;
            end
            25: begin
                slope_out = 16'h3f89;
                intercept_out = 16'hbe42 ;
            end
            24: begin
                slope_out = 16'h3f86;
                intercept_out = 16'hbe0a ;
            end
            23: begin
                slope_out = 16'h3f83;
                intercept_out = 16'hbdb5 ;
            end
            22: begin
                slope_out = 16'h3f82;
                intercept_out = 16'hbd5c ;
            end
            21: begin
                slope_out = 16'h3f81;
                intercept_out = 16'hbcf6;
            end
            20: begin
                slope_out = 16'h3f80;
                intercept_out = 16'hbc80;
            end
            19: begin
                slope_out = 16'h3f80;
                intercept_out = 16'hbbf8;
            end
            18: begin
                slope_out = 16'h3f80;
                intercept_out = 16'hbb5f;
            end
            17: begin
                slope_out = 16'h3f80;
                intercept_out = 16'hbb5f;
            end
            default: begin
                slope_out = 16'h0000;
                intercept_out = 16'h0000;
            end 
        endcase 

    end 





endmodule
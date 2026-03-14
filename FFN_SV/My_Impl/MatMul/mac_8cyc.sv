module mac_8cyc(
    input clk,
    input rst_n,
    input [15:0] data_in_a,
    input [15:0] data_in_b,
    input [15:0] data_in_c,
    output logic ready,
    output logic [15:0] data_out
);

    logic [31:0] intermediate_out;
    //logic [31:0] W1_fp32, x_fp32, b_fp32;
    logic [4:0] cycle_count;
    //logic [15:0] b_reg;
    
    // assign W1_fp32 = {data_in_a, 16'h0000};
    // assign x_fp32 = {data_in_b, 16'h0000};
    // assign b_fp32 = {data_in_c, 16'h0000};

    always_ff @(posedge clk) begin
        if(!rst_n)begin
            ready <= 1'b0;
            data_out <= 16'h0000;
            intermediate_out <= 32'h00000000;
            cycle_count <= 3'b000;
        end 
        else begin 
            if(cycle_count < 4'b1000)begin
                cycle_count <= cycle_count + 1;
                intermediate_out <=  intermediate_out + (data_in_a * data_in_b) ;
            end 
            else if(cycle_count == 4'b1000) begin
                cycle_count <= cycle_count + 1;
                intermediate_out <= intermediate_out + data_in_c;
            end 
            else begin
                ready <= 1'b1;
                cycle_count <= 3'b000;
                data_out <= intermediate_out[31:16];
            end 

        end 
    end 

endmodule

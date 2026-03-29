module clockdivider(
    input logic clk,
    input logic rst_n,
    output logic clk_div
);

    //we have 100Mhz clock and we want 10MHz
    //so we need to divide by 10
    //5 cycles low 5 cycles high 
    localparam [2:0]div_factor = 3'd4;
    logic [2:0] counter;

    always_ff @(posedge clk) begin
        if(!rst_n)begin
            counter <= 0;
            clk_div <= 0;
        end 
        else begin
            if(counter == div_factor)begin
                counter <= 0;
                clk_div <= ~clk_div;
            end
            else begin
                counter <= counter + 1;
            end
        end 
    end
endmodule
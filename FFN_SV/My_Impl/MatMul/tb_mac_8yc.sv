class mac_packet;

    rand bit [15:0] t_a;
    rand bit[15:0] t_b;
    rand bit[15:0] t_c;
    bit rest_n;
    bit [15:0] t_data_out;
    bit [31:0] intermediate_out;
    bit [31:0] w1;
    bit [31:0] x;
    bit [31:0] b;

    // function new(bit rst_n = 0);
    //     this.rest_n = rst_n;
    // endfunction
    
    function void mac();
        if(!rest_n) begin
            intermediate_out = 32'h00000000;
            t_data_out = 16'h0000;
        end 
        else begin
            intermediate_out = 0;
            for(int i = 0; i < 8; i++)begin

                assert(this.randomize());
                w1 = {t_a, 16'h0000};
                x = {t_b, 16'h0000};
                intermediate_out +=  (w1 * x);
            end
            b = {t_c, 16'h0000};
            t_data_out = intermediate_out + b;
        end 

    endfunction

    function void display();
        $display("Class @%0t: t_a = %0d, t_b = %0d, t_c = %0d, t_data_out = %0d", $time, t_a, t_b, t_c, t_data_out);
    endfunction
    function void display_all();
        $display("Class @%0t: w1 = %0d, x = %0d, b = %0d, t_data_out = %0d, intermediate_out = %0d", $time, w1, x, b, t_data_out, intermediate_out);
    endfunction

   
endclass 


module tb_mac_8yc;
    mac_packet packet;
    logic clk;
    logic rst_n;
    logic [15:0] data_in_a;
    logic [15:0] data_in_b;
    logic [15:0] data_in_c;
    logic [15:0] data_out;
    logic ready;

    mac_8cyc dut(.clk(clk), .rst_n(rst_n), .data_in_a(data_in_a), .data_in_b(data_in_b), .data_in_c(data_in_c), .data_out(data_out), .ready(ready));

    inital begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("tb_mac_8yc.vcd");
        $dumpvars(0, tb_mac_8yc);
        packet = new();
        rst_n = 0;
        packet.rest_n = rst_n;
        packet.mac();

        data_in_a = packet.t_a;
        data_in_b = packet.t_b;
        data_in_c = packet.t_c;
    
        rst_n = 1;
        packet.rest_n = rst_n;

        always@(posedge clk);
        packet.mac();
        #10;
        packet.display_all();
        if(packet.t_data_out == data_out)begin
            $display("Test passed");
        end 
        else begin
            $display("Test failed");
        end 
        $finish;
    end 
    





endmodule 
class mac_packet;
    rand bit [15:0] t_a;
    rand bit[15:0] t_b;
    rand bit[15:0] t_c;
endclass

class mac_model;


    bit [3:0] counter;
    bit [15:0] t_a;
    bit [15:0] t_b;
    bit [15:0] t_c;
    bit rest_n;
    bit [15:0] t_data_out;
    bit [31:0] intermediate_out = 0;
    // bit [31:0] w1 = 0;
    // bit [31:0] x = 0;
    // bit [31:0] b = 0;

    function void reset();
        counter = 0;
        intermediate_out = 0;
        t_data_out = 0;
    endfunction

    
    function void mac(bit [15:0] a_in, bit [15:0] b_in, bit [15:0] c_in);
        this.t_a = a_in;
        this.t_b = b_in;
        this.t_c = c_in;
        if(!rest_n) begin
            intermediate_out = 32'h00000000;
            t_data_out = 16'h0000;
            counter = 0;
        end 
        else begin
            if(counter < 8)begin
                counter = counter + 1;
                // w1 = {t_a, 16'h0000};
                // x = {t_b, 16'h0000};
                intermediate_out +=  (t_a * t_b);
            end 
            else if(counter == 8)begin
                counter = counter + 1;
                //b = {t_c, 16'h0000};
                intermediate_out = intermediate_out + t_c;
            end 
            else begin
                t_data_out = intermediate_out[31:16];
            end 

            
        end 

    endfunction

    function void display();
        $display("Class @%0t: t_a = %0d, t_b = %0d, t_c = %0d, t_data_out = %0d, intermediate_out = %0d", $time, t_a, t_b, t_c, t_data_out, intermediate_out);
    endfunction

   
endclass 


module tb_mac_8yc;
    mac_model packet;
    mac_packet driver;
    logic clk;
    logic rst_n;
    logic [15:0] data_in_a;
    logic [15:0] data_in_b;
    logic [15:0] data_in_c;
    logic [15:0] data_out;
    logic ready;

    mac_8cyc dut(.clk(clk), .rst_n(rst_n), .data_in_a(data_in_a), .data_in_b(data_in_b), .data_in_c(data_in_c), .data_out(data_out), .ready(ready));

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("tb_mac_8yc.vcd");
        $dumpvars(0, tb_mac_8yc);
        packet = new();
        driver = new();

        rst_n = 0;
        @(posedge clk);
        packet.rest_n = rst_n;
        packet.reset();
        #5;
        rst_n = 1;
        packet.rest_n = rst_n;

        repeat(10)begin
            assert(driver.randomize());
            
            data_in_a = driver.t_a;
            data_in_b = driver.t_b;
            data_in_c = driver.t_c;
            
            

            driver.t_c.rand_mode(0);
            @(posedge clk);
            packet.mac(driver.t_a, driver.t_b, driver.t_c);
            #10;
            packet.display();
            //packet.display_all();
            $display("Testbench @%0t: data_in_a = %0d, data_in_b = %0d, data_in_c = %0d, data_out = %0d", $time, data_in_a, data_in_b, data_in_c, data_out);
             
        end 
        if(packet.t_data_out == data_out)begin
            $display("Test passed");
        end 
        else begin
            $display("Test failed");
        end 
        $finish;

        
    end 
    

endmodule 
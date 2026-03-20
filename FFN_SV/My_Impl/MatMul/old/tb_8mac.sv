class mac_packet#(parameter N = 8);

    rand bit [15:0] pkt_a [0:N-1];
    rand bit [15:0] pkt_b [0:N-1];
    rand bit [15:0] pkt_c [0:N-1];
    
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
    parameter N = 8;
    mac_model packet[N];
    mac_packet driver;
    logic clk;
    logic rst_n;
    logic [15:0] data_in_a[0: N-1];
    logic [15:0] data_in_b[0: N-1];
    logic [15:0] data_in_c[0: N-1];
    logic [15:0] data_out[0: N-1];
    logic ready[0: N-1];

    mac8 dut(.clk(clk), .rst_n(rst_n), .data_in_a(data_in_a), .data_in_b(data_in_b), .data_in_c(data_in_c), .data_out(data_out), .ready(ready));

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        driver = new();
        for(int i = 0; i < N; i = i + 1)begin
            packet[i] = new();
            packet[i].reset();
        end 
        $dumpfile("tb_mac_8yc.vcd");
        $dumpvars(0, tb_mac_8yc);
        // packet = new();
        

        rst_n = 0;
        @(posedge clk);
        for(int i = 0; i < N; i = i + 1)begin
            packet[i].rest_n = rst_n;
        end 
        
        // packet.reset();
        #5;
        rst_n = 1;
        for(int i = 0; i < N; i = i + 1)begin
            packet[i].rest_n = rst_n;
        end 

        repeat(10)begin
            assert(driver.randomize());
            for(int i = 0; i < N; i = i + 1)begin
                data_in_a[i] = driver.pkt_a[i];
                data_in_b[i] = driver.pkt_b[i];
                data_in_c[i] = driver.pkt_c[i];
            end 
            
            
            driver.pkt_c.rand_mode(0);
            
            
            @(posedge clk);
            for(int i = 0; i < N; i = i + 1)begin
                packet[i].mac(driver.pkt_a[i], driver.pkt_b[i], driver.pkt_c[i]);
            end 
            #10;
            // packet.display();
            //packet.display_all();
            for(int i = 0; i < N; i = i + 1)begin
                packet[i].display();
                $display("Testbench @%0t: data_in_a = %0d, data_in_b = %0d, data_in_c = %0d, data_out = %0d", $time, data_in_a[i], data_in_b[i], data_in_c[i], data_out[i]);
            end 
            // $display("Testbench @%0t: data_in_a = %0d, data_in_b = %0d, data_in_c = %0d, data_out = %0d", $time, data_in_a, data_in_b, data_in_c, data_out);
             
        end 
        for(int i = 0; i < N; i = i + 1)begin
            if(packet[i].t_data_out == data_out[i])begin
                $display("Test passed");
            end 
            else begin
                $display("Test failed");
            end 
        end 
        $finish;

        
    end 
    

endmodule 

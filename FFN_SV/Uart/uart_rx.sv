module uart_rx #(parameter CLKS_PER_BIT = 57)(
     //The amount of clicks per bit i guess its given in the name this needs to be set
    input i_clock, //Internal Clock to keep track
    input i_Rx_serial,//Input bit 
    output o_Rx_DV,//Output bit that says whether the data is valid to be received or not
    output [7:0] o_Rx_byte//Output the byte 
);
    localparam s_IDLE = 3'b000; // Idle state 
    localparam s_RX_START_BIT = 3'b001; //Start bit state
    localparam s_RX_DATA_BITS = 3'b010; //Data bit state
    localparam s_RX_STOP_BIT = 3'b011; //Stop bit state
    localparam s_CLEAN_UP = 3'b100; //Clean up bit state 

    reg r_Rx_DATA_p = 1'b1; //internal register to get value being inputed 
    reg r_Rx_Data = 1'b1; //internal register that saves that value 

    reg [7:0] r_Clock_Count = 0; //This counts the number of clock cycles, when it equals clicks per bit we move on 
    reg [2:0] r_Bit_Index = 0; // Gives what index of the bit we are at
    reg [7:0] r_Rx_Byte = 0; //This is the internal register that stores the byte
    reg r_Rx_DV = 0; //The stores whether the value is okay to recieve or not
    reg [2:0] r_SM_Main = 0; //The is used to evaluate which state we are on 


    always@(posedge i_clock)begin  //Essentially a register that stores the value 
        r_Rx_DATA_p <= i_Rx_serial;
        r_Rx_Data <= r_Rx_DATA_p;
    end
    

    //FSM logic 
    always@(posedge i_clock)begin
        case(r_SM_Main)
            s_IDLE: 
                begin
                    r_Rx_DV <= 1'b0;
                    r_Clock_Count <= 0;
                    r_Bit_Index <= 0;
                
                if(r_Rx_Data == 1'b0)
                    r_SM_Main <= s_RX_START_BIT;
                else
                    r_SM_Main <= s_IDLE;
                end 
            s_RX_START_BIT:
                begin
                    if(r_Clock_Count == (CLKS_PER_BIT - 1)/2)begin
                        if(r_Rx_Data == 1'b0)begin
                            r_Clock_Count <= 0;
                            r_SM_Main <= s_RX_DATA_BITS;
                        end 
                        else begin 
                            r_SM_Main <= s_IDLE;
                        end 
                    end else begin
                        r_Clock_Count <= 1 + r_Clock_Count;
                        r_SM_Main <= s_RX_START_BIT;
                    end 
                end 
            s_RX_DATA_BITS:
                begin
                    if(r_Clock_Count < CLKS_PER_BIT)begin
                        r_SM_Main <= s_RX_DATA_BITS;
                        r_Clock_Count <= 1 + r_Clock_Count;
                    end 
                    else begin 
                        r_Clock_Count <= 0; //Because its the clock count per bit 
                        r_Rx_Byte[r_Bit_Index] <= r_Rx_Data; //If that cycle is done save the bit to the index in the byte listing
                        
                        if(r_Bit_Index < 7)begin
                            r_Bit_Index <= r_Bit_Index +1;
                            r_SM_Main <= s_RX_DATA_BITS;
                        end
                        else begin 
                            r_Bit_Index <= 0;
                            r_SM_Main <= s_RX_STOP_BIT;
                        end  
                    end
                end
            s_RX_STOP_BIT:
                begin
                    if(r_Clock_Count < CLKS_PER_BIT)begin 
                        r_Clock_Count <= r_Clock_Count + 1;
                        r_SM_Main <= s_RX_STOP_BIT;
                    end 
                    else begin 
                        r_Rx_DV <= 1'b1;
                        r_Clock_Count <= 0;
                        r_SM_Main <= s_CLEAN_UP;
                    end 
                end 
            s_CLEAN_UP:
                begin
                    r_SM_Main <= s_IDLE;
                    r_Rx_DV <= 1'b0;
                end 
            default:
                r_SM_Main <= s_IDLE;

        endcase 
    end 
    assign o_Rx_DV = r_Rx_DV;
    assign o_Rx_byte = r_Rx_Byte;
endmodule 
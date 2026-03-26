module uart_tx #(parameter CLKS_PER_BIT = 57)(
     //Sets the amount of r_Clocks you need before it counts as one clock cycle
    input i_Clock, //Internal clock can be calculated based on the device you're using
    input i_Tx_DV, //This says if the data recieved is valid or not
    input [7:0] i_Tx_Byte, //This is the 8 bit data received from the Rx
    output o_Tx_Active, //This outputs whether we are actively transmitting or not
    output reg o_Tx_Bit, //This outputs the bit back to Rx
    output o_Tx_Done //This says when were done transmitting
);

    localparam s_IDLE = 3'b000; //Idle state
    localparam s_TX_START_BIT = 3'b001; //Start bit state
    localparam s_TX_DATA_BITS = 3'b010; //Data bit state
    localparam s_TX_STOP_BIT = 3'b011; //Stop bit state
    localparam s_CLEAN_UP = 3'b100; //Clean up state

    reg [7:0]   r_Clock_Count = 0; //8 bit clock cycle counter
    reg [2:0]   r_Bit_Index = 0;//THis keeps track of the index
    reg [7:0]   r_Tx_Data = 0; //This register stores the data recived from input so incase we get new data we have this saved
    reg [2:0]   r_SM_Main = 0; //The state machine
    reg         r_Tx_Done = 0; //This says when were done transmitting register
    reg         r_Tx_Active = 0;//The says when we are actively transmitting

    always@(posedge i_Clock)begin
        case(r_SM_Main)
            s_IDLE:
                begin
                    o_Tx_Bit <= 1'b1;
                    r_Bit_Index <= 0;
                    r_Clock_Count <= 0;
                    r_Tx_Done <= 1'b0;
                    if(i_Tx_DV == 1'b1)begin
                        r_Tx_Data <= i_Tx_Byte;
                        r_Tx_Active <= 1;
                        r_SM_Main <= s_TX_START_BIT;
                    end 
                    else begin
                        r_SM_Main <= s_IDLE;
                    end 
                end 
            s_TX_START_BIT:
                begin
                    o_Tx_Bit <= 1'b0;

                    if(r_Clock_Count < CLKS_PER_BIT -1)begin
                        r_Clock_Count <= r_Clock_Count + 1;
                        r_SM_Main <= s_TX_START_BIT;
                    end 
                    else begin
                        r_SM_Main <= s_TX_DATA_BITS;  
                        r_Clock_Count <= 0;                  
                    end 
                end 
            s_TX_DATA_BITS:
                begin
                    o_Tx_Bit <= r_Tx_Data[r_Bit_Index];

                    if(r_Clock_Count < CLKS_PER_BIT - 1)begin
                        r_Clock_Count <= r_Clock_Count + 1;
                        r_SM_Main <= s_TX_DATA_BITS;
                    end 
                    else begin
                        r_Clock_Count <= 0;
                        if(r_Bit_Index < 7)begin
                            r_Bit_Index <= r_Bit_Index + 1;
                            r_SM_Main <= s_TX_DATA_BITS;
                        end
                        else begin
                            r_SM_Main <= s_TX_STOP_BIT;
                            r_Bit_Index <= 0;
                        end 
                    end          
                end 
            s_TX_STOP_BIT:
                begin
                    o_Tx_Bit <= 1'b0;
                    if(r_Clock_Count < CLKS_PER_BIT - 1)begin 
                        r_Clock_Count <= r_Clock_Count + 1;
                        r_SM_Main <= s_TX_STOP_BIT;
                    end 
                    else begin
                        r_Tx_Active <= 1'b0;
                        r_Tx_Done <= 1'b1;
                        r_Clock_Count <= 0;
                        r_SM_Main <= s_CLEAN_UP;
                    end 
                end 
            s_CLEAN_UP:
                begin
                    r_SM_Main <= s_IDLE;
                    r_Tx_Done <= 1'b1;
                end 
            default:
                r_SM_Main <= s_IDLE;
        endcase 
    end 
    assign o_Tx_Active = r_Tx_Active;
    assign o_Tx_Done = r_Tx_Done;
    
endmodule 
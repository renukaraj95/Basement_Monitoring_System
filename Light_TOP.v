`timescale 1ns / 1ps

module Light_Top(
      input      clk_12M,
      input      reset,
      inout      SDO,
      output     SCLK,
      output     CS,
      output[7:0]data
      
    );

//wire clk_12M;
wire clk_3M;
//wire[7:0] data;

//100kHz counter signals
parameter MAX_COUNT = 1;
wire counter_enable_1;
wire counter_enable_2;
wire counter_enable;
reg[4:0] counter_1M;
reg[4:0] counter_10Hz;
reg[3:0] counter_1;
reg[20:0] counter;
reg[4:0] counter_CS;
reg[3:0] counter_2;

//State Machine signals
parameter WAIT=1'b0, SHIFT= 1'b1;
reg current_state;// , next_state;
reg[15:0] shift = 16'b0000000000000000; //Shift register
reg[14:0] temp = 15'b000000000000000;

wire flag;



 assign SCLK = clk_3M; // Assigning 10MHz clock signal to SCLK
 
 
 
 always @( posedge clk_12M, posedge reset ) //Counter to get 3MHz clock signal from 12MHz clock
              if (reset)
                 counter_1M <= 0;
              else if (counter_1M == MAX_COUNT)
                 begin
                 counter_1M <= 0;
                 end
              else
                 counter_1M <= counter_1M + 1'b1;
                
    assign counter_enable_1 = counter_1M == 0; //3MHz clk enable signal
            
    always @ ( posedge clk_12M, posedge reset )
              if ( reset )
                 counter_1 <= 0;
              else if ( counter_enable_1 )
              if ( counter_1 == 1 )
                counter_1 <= 0;
              else 
                counter_1 <= counter_1 + 1'b1;
                 
 assign clk_3M = counter_1 == 1; //3MHz clock signal
     
 always @( posedge clk_3M, posedge reset ) //Counter to get 10Hz clock signal from 3MHz clock
                  if (reset)
                     begin
                     counter <= 0;
                     end
                  else if (counter == 29)
                     counter<=0;
                  else   
                     counter <= counter + 1'b1;
                     
        assign CS=(counter>0 & counter<17)? 1'b0 :1'b1;     
        assign counter_enable = counter == 0;   
        
//STATE MACHINE   
        always@ ( posedge SCLK, posedge reset )
            begin
             if ( reset )
               current_state <= WAIT;
             else         
                case ( current_state )      
                    WAIT:  
                         if(~CS)                   
                            current_state = SHIFT;                   
                         else                   
                             current_state = WAIT;                 
                    SHIFT: 
                         if (CS)
                              current_state = WAIT;
                         else
                              current_state = SHIFT;
                    default: 
                            current_state = WAIT;
                endcase
         end
        assign flag=(current_state==WAIT)? 1:0; 
        
//SHIFT REGISTER
always@ (posedge SCLK)
if(flag)
   temp <= shift;
else
   shift <= {shift[14:0],SDO};
   
assign data= temp[12:5];

endmodule

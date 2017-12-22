`timescale 1ns / 1ps

 module PWM_AUDIO(
    input  clk_fpga,
    input   reset,
  //  input wire  SW,
    output wire AUD_PWM,
    output  AUD_SD
    );
   
wire counter_enable;
reg[12:0] counter_400k;
parameter MAX_COUNT = 999;
reg[6:0] counter;
wire clk_400k;   
reg[20:0]frequency;
reg[3:0] note = 4'b0000;
reg aud;

always @( posedge clk_fpga, posedge reset ) //Counter to get 400k clock signal from 100MHz clock
                 if (reset)
                    counter_400k = 0;
                 else if (counter_400k == MAX_COUNT)
                    begin
                    counter_400k = 0;
                    end
                 else
                    counter_400k = counter_400k + 1'b1;
                   
 assign counter_enable = counter_400k == 0; //400k clk enable signal
       
 always @ ( posedge clk_fpga, posedge reset )
                     if ( reset )
                        counter = 0;
                     else if ( counter_enable )
                     if ( counter == 1 )
                       counter = 0;
                     else 
                       counter = counter + 1'b1;
                        
 assign clk_400k = counter == 1; //400k clock signal

  

always @(frequency, note)
begin
	case(note)
		1:  frequency = 381679;    //C1
        2:  frequency = 340136;    //D1
        3:  frequency = 303030;    //E1
        4:  frequency = 285714;    //F1
        5:  frequency = 255102;    //G1
        6:  frequency = 227272;    //A1
        7:  frequency = 202429;    //B1
        8:  frequency = 190839;    //C2
        9:  frequency = 170068;    //D2
        10: frequency = 151515;    //E2
        11: frequency = 143266;    //F2
        12: frequency = 127551;    //G2
	    13: frequency = 113636;    //A2
        14: frequency = 101214;    //B2
        15: frequency = 95602;     //C3
   default: frequency = 1;         //nothing 
    endcase
end

wire count_freq; 
reg [20:0]count = 1'b0;
assign  count_freq = (count == frequency)? 1'b1: 1'b0;
    
always@ (posedge clk_400k)
          begin
           if(count == frequency)
              count <= 0;
            else 
              count <= count + 1'b1;
          end
          
// Use the highest bit of the counter (MSB) to drive the speaker
always @(posedge clk_400k)
	if(reset)
        aud <= 0;
    else if(count_freq) //&& SW==1'b1) 
        aud <= aud ^ 1'b1;
        
assign AUD_PWM = aud;
        
assign AUD_SD = 1'b1;
	 
endmodule
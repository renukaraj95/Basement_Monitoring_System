`timescale 1ns / 1ps

module SS_Verilog(
     input           clk_fpga,
     input           reset,
     output[6:0]     OP,
     output[7:0]     AN,
     input [7:0]     data,
     input [7:0]     humidity,
     input [7:0]     temperature
        );
        
parameter MAX_COUNT = 99999;
wire counter_enable;
reg[16:0] counter_1k;
reg[3:0] counter;
reg[2:0] count;
wire clk_1k;
reg[3:0] num;
reg[7:0] seg;
reg[6:0] out;
 
always @( posedge clk_fpga, posedge reset )
    if (reset)
       counter_1k <= 0;
    else if (counter_1k == MAX_COUNT)
       counter_1k <= 0;
    else
       counter_1k <= counter_1k + 1'b1;
       
  assign counter_enable = counter_1k == 0;
  
always @ ( posedge clk_fpga, posedge reset )
    if ( reset )
       counter <= 0;
    else if ( counter_enable )
    if ( counter == 1 )
       counter <= 0;
    else 
       counter <= counter + 1'b1;
       
  assign clk_1k = counter == 1;
  
always @ ( posedge clk_1k, posedge reset )
     if ( reset )
        count <= 0;
     else if ( count == 4'h5 )
       count <= 0;
     else
       count <= count + 1;
       
always @ ( * )
   
      case ( count )
              0 : begin
                   num <= data[3:0];
                   seg = 8'b11111110;
                   end
              1 : begin
                   num <= data[7:4];
                   seg = 8'b11111101;
                   end
              2 : begin
                   num <= humidity[3:0];
                   seg = 8'b11111011;
                   end
              3 : begin
                   num <= humidity[7:4];
                   seg = 8'b11110111;
                   end     
              4 : begin
                   num <= temperature[3:0];
                   seg = 8'b11101111;
                   end
              5 : begin
                   num <= temperature[7:4];
                   seg = 8'b11011111;
                   end                                                   
           default : begin
                   num <= 4'b1100;
                   seg = 8'b11111110;
                   end
      endcase
   
   
 assign AN = seg;
 
 always @(num)
             case (num)
                4'b0000 : out = 7'b100_0000;
                4'b0001 : out = 7'b111_1001;
                4'b0010 : out = 7'b010_0100;
                4'b0011 : out = 7'b011_0000;
                4'b0100 : out = 7'b001_1001;
                4'b0101 : out = 7'b001_0010;
                4'b0110 : out = 7'b000_0010;
                4'b0111 : out = 7'b111_1000;
                4'b1000 : out = 7'b000_0000;
                4'b1001 : out = 7'b001_1000;
                4'b1010 : out = 7'b000_1000;
                4'b1011 : out = 7'b000_0011;
                4'b1100 : out = 7'b100_0110;
                4'b1101 : out = 7'b010_0001;
                4'b1110 : out = 7'b000_0110;
                4'b1111 : out = 7'b000_1110;
                default : out = 7'b000_0000;
             endcase         
             
  assign OP = out;
         
  endmodule  
 
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        

`timescale 1ns / 1ps

module i2c_test;
   
   //inputs
   reg clk_fpga;
   reg reset;
   
   //outputs
   wire sda;
   wire scl;
   //wire[5:0] state;
  // reg busy;
   wire[15:0] RH_out;
   //inout
//   wire[12:0] temp_out;
   
   Humidity_Top uut (
       .clk_fpga(clk_fpga),
       .reset(reset),
       .sda(sda),
       .scl(scl),
    //   .busy(busy),
       //.state(state),
       .RH_out(RH_out)
     //  .temp_out(temp_out)
       );
       
   initial begin
   clk_fpga = 0;
   forever begin
     clk_fpga = #10 ~clk_fpga;
     end
   end
   
   initial begin
   reset = 1;
   #10;
   reset = 0;
   #100;
   end
   
//            initial begin
//            $monitor("t=%3d, temp_out=%13b \n",$time,temp_out );
//            end
   
  endmodule

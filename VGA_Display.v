`timescale 1ns / 1ps

module VGA_Display(
     input       clk_fpga,
     input       reset,
     output       HS1,
     output       VS1,
     input [1:0]  SW,
    // input[10:0] hcount1,
    // input[10:0] vcount1,
    // input       blank1,
     output reg[11:0] VGA
    );
    
wire blank;
wire[10:0] hcount;
wire[10:0] vcount;
wire lock_led;
wire clk_25M;

clk_wiz_0 instance_name
   (
    // Clock out ports
    .clk_25M(clk_25M),     // output clk_25M
    // Status and control signals
    .reset(reset), // input reset
    .locked(lock_led),       // output locked
   // Clock in ports
    .clk_in1(clk_fpga));      // input clk_in1
    
vga_controller_640_60 ctrl(
   .rst(reset),
   .pixel_clk(clk_25M),
   .HS(HS1),
   .VS(VS1),
   .blank(blank),
   .hcount(hcount),
   .vcount(vcount)
   
   );
   
     
 // signal declaration
      wire [10:0] rom_addr;
      wire [6:0] char_addr;
      wire [3:0] row_addr;
      wire [2:0] bit_addr;
      wire [7:0] font_word;
      wire font_bit, text_bit_on;
      wire text_bit_on_1;
      wire text_bit_on_2;
      wire text_bit_on_3;
      wire line_on;
      wire block_on;
    
    // body
    // instantiate font ROM
    font_rom font_unit
    (.clk(clk_25M), .addr(rom_addr), .data(font_word));
    
    reg[11:0] black = 12'b000000000000;
    reg[11:0] red = 12'b000000001111;
    reg[11:0] green = 12'b000011110000;
    reg[11:0] blue = 12'b111100000000;
    reg[11:0] white = 12'b111111111111;
    reg[11:0] yellow = 12'b000011111111;
    reg[11:0] magenta = 12'b111100001111;
    
    
    wire[1:0] char_pos_x;
    wire[3:0] char_pos_y;
    wire char_pos_1;
    wire char_pos_2;
    wire char_pos_3;
    wire char_pos_4;
    wire char_pos_5;
 
    
    // font ROM interface
    // font ROM interface
       assign char_addr = {vcount[5:4], hcount[7:3]};
       assign row_addr = vcount[3:0];
       assign rom_addr = {char_addr, row_addr};
       assign bit_addr = hcount[2:0];
       assign font_bit = font_word[~bit_addr];
       // "on" region limited to top-left corner
       
//     assign char_pos_x = hcount[9:8];
//     assign char_pos_y = vcount[9:6];
     
//     assign char_pos_1 = (char_pos_x == 0) && (char_pos_y == 1) && rom_addr>=11'h0b0 && rom_addr<=11'h16f && SW== 2'b01 ; 
//     assign char_pos_2 = (char_pos_x == 0) && (char_pos_y == 1) && rom_addr>=11'h000 && rom_addr<=11'h0af && SW== 2'b00 ;
//     assign char_pos_3 = (char_pos_x == 1) && (char_pos_y == 1) && rom_addr>=11'h180 && rom_addr<=11'h2af && SW== 2'b10 ;
//     assign char_pos_4 = (char_pos_x == 0) && (char_pos_y == 2) && rom_addr>=11'h2b0 && rom_addr<=11'h3cf && SW== 2'b11 ;
//   //  assign char_pos_5 = (char_pos_x == 0) && (char_pos_y == 1) && rom_addr>=11'h3d0 && rom_addr<=11'h4bf && SW== 2'b11 ;
     
//     assign text_bit_on = (char_pos_1 | char_pos_2 | char_pos_3 | char_pos_4  ) & font_bit;

          
    assign text_bit_on = (hcount[9:8]==0 && vcount[9:6]==1 && rom_addr>=11'h0b0 && rom_addr<=11'h16f && SW== 2'b01 ) ?
                         font_bit : 1'b0;
                         
    assign text_bit_on_1 = (hcount[9:8]==0 && vcount[9:6]==1 && rom_addr>=11'h000 && rom_addr<=11'h0af && SW== 2'b00 ) ?
                                                  font_bit : 1'b0;

    assign text_bit_on_2 = (hcount[9:8]==1 && vcount[9:6]==1 && rom_addr>=11'h180 && rom_addr<=11'h2af && SW== 2'b10 ) ?
                         font_bit : 1'b0;

    assign text_bit_on_3 = (hcount[9:8]==0 && vcount[9:6]==2 && rom_addr>=11'h2b0 && rom_addr<=11'h3cf && SW== 2'b11 ) ?
                         font_bit : 1'b0;
                         
   assign line_on = (vcount == 15) && (hcount >= 120) && (hcount <= 520);
                         
   assign block_on = (hcount >= 0) && (hcount <= 240) &&
                     (vcount >= 0) && (vcount <= 180); 
    // rgb multiplexing circuit
    always @*
       if (blank)
          VGA = red; // blank
       else
          if (text_bit_on )
             VGA = green;  // green
       else
          if (text_bit_on_1)
             VGA = green;
       
       else
                 if (text_bit_on_2)
                    VGA = green;
              
              else
                        if (text_bit_on_3)
                           VGA = green;
                    
//          if (line_on)
//             VGA = white;
       else 
                 if (block_on)
             VGA = blue;
           else
             VGA = black;  // black

         
endmodule

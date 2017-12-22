`timescale 1ns / 1ps

module I2C_Top(
      input wire   clk_fpga,  //100MHz clock
      input wire   reset,     //reset signal
      inout wire   sda,       //serial data output 
      output wire  scl,       //serial clock input
      output wire  clk_100k,
      output[6:0]OP, //Seven segment
      output[7:0]AN, //Anodes
//      output reg[7:0] data_msb,
//      output reg[7:0] data_lsb
      output wire[15:0] temp_out //temperature output
//      output wire[8:0] temperature
      
         );
   
 reg[3:0] state; //state machine
 parameter STATE_IDLE = 0;
 parameter STATE_START = 1;
 parameter STATE_ADDR = 2;
 parameter STATE_SLAVE_ACK = 3;
 parameter STATE_READ_MSB = 6;
 parameter STATE_MASTER_ACK = 7;
 parameter STATE_READ_LSB = 8;
 parameter STATE_MASTER_ACK_2 = 9;
 parameter STATE_STOP = 10;
 
 reg[6:0] addr_ADT7420 = 7'h4B ; //address of slave device (ADT7420)

 reg[7:0] data_msb; //temperature MSB read from slave
 reg[7:0] data_lsb; //temperature LSB read from slave
 //reg[7:0] register_addr = 8'h00; //address of temperature register to read from
 reg[7:0] addr_wr;  //lateched in address and w/r bit
 
 reg scl_enable;//enables internal scl to output
 reg sda_out;       //serial data to the slave
 wire sda_in;       //sda from the slave
 reg sda_enable;
 reg sda_in_en;
 
wire [7:0] number;
reg [3:0] hundreds;
reg [3:0] tens;
reg [3:0] ones;
reg [19:0] shift;
integer i;
    
 

 reg[2:0] bitcount; //tracks number of bits

 reg[15:0] temp;
 wire[15:0] data;
 
 wire counter_enable;
 reg[8:0] counter_100k;
 parameter MAX_COUNT = 499; 
 reg[3:0] counter;
 wire[7:0] temperature;
 
 SS_Verilog SS(.clk_fpga(clk_fpga), .reset(reset), .AN(AN), .OP(OP), .temperature(temperature));   
 
 
always @( posedge clk_fpga, posedge reset ) //Counter to get 400k clock signal from 100MHz clock
              if (reset)
                 counter_100k <= 0;
              else if (counter_100k == MAX_COUNT)
                 begin
                 counter_100k <= 0;
                 end
              else
                 counter_100k <= counter_100k + 1'b1;
                
assign counter_enable = counter_100k == 0; //400k clk enable signal
    
    always @ ( posedge clk_fpga, posedge reset )
                  if ( reset )
                     counter <= 0;
                  else if ( counter_enable )
                  if ( counter == 1 )
                    counter <= 0;
                  else 
                    counter <= counter + 1'b1;
                     
 assign clk_100k = counter == 1; //400k clock signal
 
 always@ (posedge clk_100k)
    begin
      if(reset)
         scl_enable <= 0;
      else 
         if((state == STATE_IDLE) || (state == STATE_START) || (state == STATE_MASTER_ACK_2)) begin
         scl_enable <= 0;
         end
      else
         begin
         scl_enable <= 1;
         end
       end
 

    
//state machine and writing to sda during low scl      
always@ (posedge clk_100k, posedge reset)
    begin
      if(reset)
         begin
         state <= STATE_IDLE;         //idle state
         sda_out <= 0;                //sets sda high impedance
         bitcount <= 7;               //resets bit counter
         temp <= 16'b0000000000000000;
         addr_wr <= {addr_ADT7420,1'b1};
         data_msb <= 8'b00000000;
         data_lsb <= 8'b00000000;
         end
         
      else
            case(state)
              STATE_IDLE: begin
                          addr_wr <= {addr_ADT7420,1'b1};   //get slave address and set read/write bit to 0(write)
                          sda_out <= 0;                     //sets sda low impedance
                          state = STATE_START;              //proceed to start state
                          end
                        
                        
              STATE_START: begin                             //START STATE
                            sda_out <= addr_wr[bitcount];    //set first bit of address to bus
                            state = STATE_ADDR;              //go to the address transacion state
                           end
                            
              STATE_ADDR: begin
                          if(bitcount == 0) begin            //check if address and w/r byte transaction is over
                           sda_out <= 1'bz;                     //release sda for slave acknowledge
                           bitcount <= 7;                    //reset bitcount to max value
                           state = STATE_SLAVE_ACK;          //go to slave acknowledge state
                           end
                          else begin                        
                           bitcount <= bitcount - 1;         //decrement bitcount as transaction occurs
                           sda_out <= addr_wr[bitcount-1];   //write the address and w/r byte to bus
                           state = STATE_ADDR;               //remain in the address state till transaction is over
                           end
                          end
                          
              STATE_SLAVE_ACK: begin
                           data_msb[bitcount] <= sda_in;    //receive current slave data bit
                           state = STATE_READ_MSB;           //go to read state
                           end
                                                
                                              
             STATE_READ_MSB: begin
                          if(bitcount == 0) begin           //check if read is over
                            sda_out <= 0;                    //acknowledge that the byte has been received
                            bitcount <= 7;                   //reset bitcount to 7
                            state = STATE_MASTER_ACK;        //go to master acknowledge state
                            end
                           else begin
                            data_msb[bitcount] <= sda_in;    //receive current slave data bit
                            sda_out <= 1'bz;
                            bitcount <= bitcount - 1;        //decrement bitcount as data is read
                            state = STATE_READ_MSB;          //remain in read state
                            end
                           end
                           
             STATE_MASTER_ACK: begin 
                              sda_out <= 1'bz;                    //acknowledge that the byte has been received
                              state = STATE_READ_LSB;        //go to read lsb state state
                              data_lsb[bitcount] <= sda_in;
                              end            
                   
              
             STATE_READ_LSB: begin
                     
                           temp <= {data_msb,data_lsb};      //read data to output
                           if(bitcount == 0) begin           //check if read is over
                            sda_out <= 1;                    //send a no-acknowledge(before stop or repeated start)
                            bitcount <= 7;                   //reset bitcount to 7
                            state = STATE_MASTER_ACK_2;      //go to master acknowledge state
                            end
                           else begin
                            data_lsb[bitcount] <= sda_in;
                            bitcount <= bitcount - 1;        //decrement bitcount as data is read
                            sda_out <= 1'bz;                 //release sda from incoming data
                            state = STATE_READ_LSB;         //remain in read state
                             end
                            end
              
             STATE_MASTER_ACK_2: begin
                             sda_out <= 0;                   //send a no-acknowledge(before stop or repeated start)
                             state = STATE_START;            //repeated start
                             end 
     
              
             STATE_STOP: begin
                             sda_out <= 0;         
                             state = STATE_START;             //go to idle state
                            end
                
                                         
               default: begin
                        state = STATE_IDLE;
                        end                          
                            
            endcase
          end  


//set sda and scl outputs
assign sda_in = sda;
assign scl = (scl_enable == 0)? 1 : ~clk_100k ;
assign sda =  sda_out;
//assign sda = (sda_out)? 1'bz:1'b0;

 assign data = temp;
assign temp_out = data; //assign 13 bit temperature output
assign number = data[14:7];

 always @(number)
   begin
      // Clear previous number and store new number in shift register
      shift[19:8] = 0;
      shift[7:0] = number;
      
      // Loop eight times
      for (i=0; i<8; i=i+1) begin
         if (shift[11:8] >= 5)
            shift[11:8] = shift[11:8] + 3;
            
         if (shift[15:12] >= 5)
            shift[15:12] = shift[15:12] + 3;
            
         if (shift[19:16] >= 5)
            shift[19:16] = shift[19:16] + 3;
         
         // Shift entire register left once
         shift = shift << 1;
      end
      
      // Push decimal numbers to output
      hundreds = shift[19:16];
      tens     = shift[15:12];
      ones     = shift[11:8];
   end
   
   assign temperature =  {tens,ones};
          
endmodule                             
                 
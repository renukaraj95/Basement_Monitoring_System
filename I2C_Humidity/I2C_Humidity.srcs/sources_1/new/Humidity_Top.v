`timescale 1ns / 1ps

module Humidity_Top(
      input wire   clk_fpga,    //100MHz clock
      input wire   reset,       //reset signal
      inout wire   sda,         //serial data output 
      output wire  scl,         //serial clock input
      output wire  clk_100k,
      output wire[15:0]  RH_out  //temperature output
    );
    

    
reg[4:0] state; //state machine
parameter STATE_IDLE = 0;
parameter STATE_START = 1;
parameter STATE_ADDR = 2;
parameter STATE_SLAVE_ACK_1 = 3;
parameter STATE_WRITE_REG_ADDRESS = 4;
parameter STATE_SLAVE_ACK_2 = 5;
parameter STATE_CONFIG_MSB = 6;
parameter STATE_SLAVE_ACK_3 = 7;
parameter STATE_CONFIG_LSB = 8;
parameter STATE_SLAVE_ACK_4 = 9;
parameter STATE_IDLE_1 = 10;
parameter STATE_START_1 = 11;
parameter STATE_ADDR_1 = 12;
parameter STATE_SLAVE_ACK_5 = 13;
parameter STATE_WRITE_REG_ADDRESS_1 = 14;
parameter STATE_SLAVE_ACK_6 = 15;
parameter STATE_READ_MSB = 16;
parameter STATE_MASTER_ACK_1 = 17;
parameter STATE_READ_LSB = 18;
parameter STATE_MASTER_ACK_2 = 19;
parameter STATE_STOP = 20;
     
reg[6:0] addr_HDC1080 = 7'b1000000 ; //address of slave device (ADT7420)
  
//reg[7:0] data_rd; //data read from slave
reg[7:0] reg_addr = 8'b00000001; //data to write to slave, i.e address of humidity reg to read from
reg[7:0] addr_wr; //lateched in address and w/r bit
reg[7:0] config_reg_MSB = 8'b00000000; //bit [9:8] set to "00" for 14-bit resolution humidity measurement
reg[7:0] config_reg_LSB = 8'b00000010;
reg[7:0] data_msb;
reg[7:0] data_lsb;
wire sda_in;
     
//reg i2c_scl_enable;//enables internal scl to output
reg sda_out; //internal sda signal
//reg sda_ena; //enables internal sda to output

     
reg[2:0] bitcount; //tracks number of bits
   
reg[15:0] temp;
wire[15:0] data;
reg scl_enable;
     
wire counter_enable;
reg[8:0] counter_100k;
parameter MAX_COUNT = 499;
reg[3:0] counter;    
    
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
          if((state == STATE_IDLE) || (state == STATE_START) || (state == STATE_START_1 ) ) begin
          scl_enable <= 0;
          end
       else
          begin
          scl_enable <= 1;
          end 
        end
    
 always@ (posedge clk_100k, posedge reset)
       begin
         if(reset)
            begin
            state <= STATE_IDLE;      //idle state
            sda_out <= 1;             //sets sda high impedance
            bitcount <= 7;            //resets bit counter
            data_msb <= 8'b00000000;
            data_lsb <= 8'b00000000;
            temp <= 16'b0000000000000000;
            addr_wr <= {addr_HDC1080,1'b0}; 
            end
          else        
            case(state)    
             STATE_IDLE:begin
                         addr_wr <= {addr_HDC1080,1'b0};   //get slave address and w/r function ( 0 for write )
                         state = STATE_START;              //proceed to start state
                         sda_out <= 0;                     //start condition
                        end
               
            STATE_START: begin                             //START STATE
                          sda_out <= addr_wr[bitcount];    //set first bit of address to bus
                          state = STATE_ADDR;              //go to the address transacion state
                        end
                          
            STATE_ADDR: begin
                        if(bitcount == 0) begin            //check if address and w/r byte transaction is over
                         sda_out <= 1'bz;                     //release sda for slave acknowledge
                         bitcount <= 7;                    //reset bitcount to max value
                         state = STATE_SLAVE_ACK_1;        //go to slave acknowledge state
                         end
                        else begin                        
                         bitcount <= bitcount - 1;        //decrement bitcount as transaction occurs
                         sda_out <= addr_wr[bitcount-1];  //write the address and w/r byte to bus
                         state = STATE_ADDR;              //remain in the address state till transaction is over
                         end
                        end
                        
            STATE_SLAVE_ACK_1: begin
                           sda_out <= reg_addr[bitcount];      //write first bit if data
                           state =  STATE_WRITE_REG_ADDRESS;  //go to write register address state
                         end
                        
                           
                        
             STATE_WRITE_REG_ADDRESS: begin                             
                        if(bitcount == 0) begin          //check if byte transaction is over
                         sda_out <= 1'bz;                    //release  sda for slave acknowledge
                         bitcount <= 7;                   //reset bitcount to 7
                         state = STATE_SLAVE_ACK_2;       //go to slave akcnoeledge state
                         end
                        else begin
                         bitcount <= bitcount - 1;        //decrement bitcount as transaction occurs
                         sda_out <= reg_addr[bitcount-1];  //write data into the bus
                         state = STATE_WRITE_REG_ADDRESS; //remain in write state till transaction is over
                         end
                        end
                        
           STATE_SLAVE_ACK_2: begin
                          sda_out <= config_reg_MSB[bitcount];    //get the data to write to slave
                          state = STATE_CONFIG_MSB;          //remain in write config msb state
                         end
                        
                         
           STATE_CONFIG_MSB : begin
                          if(bitcount == 0) begin           //check if byte transaction is over
                           sda_out <= 1'bz;                    //release  sda for slave acknowledge
                           bitcount <= 7;                   //reset bitcount to 7
                           state = STATE_SLAVE_ACK_3;       //go to slave akcnoeledge state
                           end
                          else begin
                           bitcount <= bitcount - 1;        //decrement bitcount as transaction occurs
                           sda_out <= config_reg_MSB[bitcount-1];  //write data into the bus
                           state = STATE_CONFIG_MSB;        //remain in write state till transaction is over
                          end
                         end                        
                         
            STATE_SLAVE_ACK_3: begin
                           sda_out <= config_reg_LSB[bitcount];   
                           state = STATE_CONFIG_LSB;         //go to repeated start
                           end
                                                     
                           
            STATE_CONFIG_LSB : begin
                          if(bitcount == 0) begin            //check if byte transaction is over
                            sda_out <= 1'bz;                    //release  sda for slave acknowledge
                            bitcount <= 7;                   //reset bitcount to 7
                            state = STATE_SLAVE_ACK_4;       //go to slave akcnoeledge state
                            end
                          else begin
                            bitcount <= bitcount - 1;        //decrement bitcount as transaction occurs
                            sda_out <= config_reg_LSB[bitcount-1];  //write data into the bus
                            state = STATE_CONFIG_LSB; //remain in write state till transaction is over
                            end
                          end 
                          
             STATE_SLAVE_ACK_4: begin
                            sda_out <= 0;                     //stop condition
                            addr_wr <= {addr_HDC1080,1'b0};   //get slave address and w/r function
                            state = STATE_START_1;               //go to stop state

                            end       
                            
             STATE_IDLE_1: begin
                          //  addr_wr <= {addr_HDC1080,1'b0};   //get slave address and w/r function
                          // sda_out <= reg_addr;              //get the register address to write to slave
                            sda_out <= 0;                     //start condition
                            state = STATE_START_1;            //proceed to start state
                           end
                                  
                                                                 

              STATE_START_1: begin                           //START STATE
                            sda_out <= addr_wr[bitcount];    //set first bit of address to bus
                            state = STATE_ADDR_1;              //go to the address transacion state
                          end
                            
              STATE_ADDR_1: begin
                          if(bitcount == 0) begin            //check if address and w/r byte transaction is over
                           sda_out <= 1'bz;                     //release sda for slave acknowledge
                           bitcount <= 7;                    //reset bitcount to max value
                           state = STATE_SLAVE_ACK_5;        //go to slave acknowledge state
                           end
                          else begin                        
                           bitcount <= bitcount - 1;        //decrement bitcount as transaction occurs
                           sda_out <= addr_wr[bitcount-1];  //write the address and w/r byte to bus
                           state = STATE_ADDR_1;              //remain in the address state till transaction is over
                           end
                          end
                          
              STATE_SLAVE_ACK_5: begin
                          if(addr_wr[0] == 0) begin          //check if write command
                           sda_out <= reg_addr[bitcount];     //write first bit if data
                           state = STATE_WRITE_REG_ADDRESS_1;//go to write satte
                           end
                          else begin                         //else if read command
                           data_msb[bitcount] <= sda_in;
                           state = STATE_READ_MSB;           //go to read state
                           end
                          end
                          
              STATE_WRITE_REG_ADDRESS_1: begin                             
                          if(bitcount == 0) begin          //check if byte transaction is over
                           sda_out <= 1'bz;                    //release  sda for slave acknowledge
                           bitcount <= 7;                   //reset bitcount to 7
                           state = STATE_SLAVE_ACK_6;       //go to slave akcnoeledge state
                           end
                          else begin
                           bitcount <= bitcount - 1;          //decrement bitcount as transaction occurs
                           sda_out <= reg_addr[bitcount-1];    //write data into the bus
                           state = STATE_WRITE_REG_ADDRESS_1; //remain in write state till transaction is over
                           end
                          end
                          
              STATE_SLAVE_ACK_6: begin
                            addr_wr <= {addr_HDC1080,1'b1}; //get address and w/r function
                            sda_out <= 1'b0;
                            state = STATE_START_1;          //go to repeated start
                           end
                          
                                    

              STATE_READ_MSB: begin
                         if(bitcount == 0) begin           //check if read is over
                          sda_out <= 0;                  //acknowledge that the byte has been received
                          bitcount <= 7;                   //reset bitcount to 7
                          state = STATE_MASTER_ACK_1;          //go to master acknowledge state
                          end
                         else begin
                          bitcount <= bitcount - 1;        //decrement bitcount as data is read
                          data_msb[bitcount] <= sda_in;
                          state = STATE_READ_MSB;          //remain in read state
                          end
                         end
                         
             STATE_MASTER_ACK_1: begin
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
                           sda_out <= 0;               //send a no-acknowledge(before stop or repeated start)
                           addr_wr <= {addr_HDC1080,1'b0}; //get slave address and w/r function
                           state = STATE_START_1;        //repeated start
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
        
           
           
assign sda_in = sda;
assign scl = (scl_enable == 0)? 1 : ~clk_100k ;
assign sda =  sda_out;

assign data = temp;        
assign RH_out = temp; //assign 8 bit temperature output
                  
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/10/2017 01:33:14 PM
// Design Name: 
// Module Name: I2C_TempSens
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module I2C_Temp(
    input clk_fpga,
    input reset,
    output TMP_SCL,
    inout TMP_SDA,
//    output[6:0]OP, //Seven segment
//    output[7:0]AN, //Anodes
//    output wire twiMsg,
//    output wire twiStb,
//    output wire [7:0]twiAddr,
//    output wire [7:0]twiDi,
//    output [7:0]twiDo,
//    output twiDone,
//    output twiErr,
    output reg [15:0] tempReg,
    output wire[7:0] temperature
    );
    
   parameter IRD = 1'b1;  // init read
    parameter IWR = 1'b0;  // init write
    parameter [7:1] ADT7420_ADDR = 7'b100_1011;    //TWI Slave Address
    parameter [7:0] ADT7420_RRESET = 8'h2F;         //Software Reset Register
    parameter [7:0] ADT7420_RTEMP = 8'h00;          //Temperature Read MSB Address
    parameter NO_OF_INIT_VECTORS = 3;               //number of init vectors in TempSensInitMap
    
    wire [16:0] TempSensInitMap [2:0];
    assign TempSensInitMap[0] = {IRD, 8'h0B, 8'hcb};    //Read ID R[0x0B]=0xCB
    assign TempSensInitMap[1] = {IWR, 8'h2F, 8'h00};    //Reset R[0x2F]=don't care
    assign TempSensInitMap[2] = {IRD, 8'h0B, 8'hCB};    //Read ID R[0x0B]=0xCB
    
    wire [7:0] number;
    reg [3:0] hundreds;
    reg [3:0] tens;
    reg [3:0] ones;
    reg [19:0] shift;
    integer i;
    //wire [7:0] temperature;
    
    wire temp_high;
    wire temp_low;
    
    
    
    reg twiMsg, twiStb;
    reg [7:0] twiDi, twiAddr;
    reg initEn;
    wire twiDone,  twiErr;
    wire [7:0] twiDo;
    wire [16:0] initWord;
    reg [7:0] temp;
    reg [1:0] initA;
    
    reg [2:0] state, nstate;
    
   
    
    //assign TEMP_O = tempReg[15:3];
    assign initWord = TempSensInitMap[initA];


    localparam stIdle = 3'd0;
    localparam stInitReg = 3'd1;  // Send register address from the init vector
    localparam stInitData = 3'd2; // Send data byte from the init vector
    localparam stReadTempR = 3'd3;  // Send temperature register address
    localparam stReadTempD1 = 3'd4; // Read temperature MSB
    localparam stReadTempD2 = 3'd5;

    I2C Inst_temp_controller(
        .MSG_I(twiMsg),
        .STB_I(twiStb),
        .A_I(twiAddr),
        .D_I(twiDi),
        .D_O(twiDo),
        .DONE_O(twiDone),
        .ERR_O(twiErr),
        .CLK(clk_fpga),
        .SRST(reset),
        .SDA(TMP_SDA),
        .SCL(TMP_SCL)
         );
         
         
    always @ (posedge clk_fpga)
        if (state == stIdle || initA == 3)
            initA = 0;
        else if (initEn == 1)
            initA = initA + 1;
            
    always @ (posedge clk_fpga)
        if (state == stReadTempD1 && twiDone == 1 && twiErr == 0)
            temp = twiDo;
        else if (state == stReadTempD2 && twiDone == 1 && twiErr == 0)
            tempReg <= {temp, twiDo};

    always @ (posedge clk_fpga)
        if (reset == 1)
            state <= stIdle;
        else
            state <= nstate;
            
    always @ (state, initWord, twiDone, twiErr, twiDo, stInitReg, stInitData, stReadTempR, stReadTempD1, stReadTempD2)
    begin
        twiStb <= 1'b0;
        twiMsg <= 1'b0;
        twiDi <= "";
        twiAddr <= {ADT7420_ADDR, 1'b0};
        initEn <= 1'b0;
        
        case (state)
        
            stInitReg:
            begin
                twiStb <= 1;
                twiAddr[0] <= IWR;
                twiDi <= initWord [15:8];
            end
            
            stInitData:
            begin
                twiStb <= 1;
                twiAddr[0] <= initWord[16];
                twiDi <= initWord[7:0];
                if (twiDone == 1 && (twiErr == 0 || (initWord[16] == IWR && initWord[15:8] == ADT7420_RRESET)) && (initWord[16] == IWR || twiDo == initWord[7:0]))
                    initEn <= 1;
            end
            
            stReadTempR:
            begin
                twiStb <= 1;
                twiMsg <= 1;
                twiDi <= ADT7420_RTEMP;
                twiAddr[0] <= IWR;             
            end
            
            stReadTempD1:
            begin
                twiStb <= 1;
                twiAddr[0] <= IRD;
            end
            
            stReadTempD2:
            begin
                twiStb <= 1;
                twiAddr[0] <= IRD;
            end       
        endcase        
    end    

    always @ (state, twiDone, initA, stIdle, stInitReg, stInitData, stReadTempR, stReadTempD1, stReadTempD2)
    begin
            nstate <= state;
        
        case (state)
        
            stIdle:
                nstate <= stInitReg;
        
            stInitReg:
                if (twiDone == 1)
                    nstate <= stInitData;
            
            stInitData:
                if (twiDone == 1)
                    if (initA == NO_OF_INIT_VECTORS-1)
                        nstate <= stReadTempR;
                    else
                        nstate <= stInitReg;
            
            stReadTempR:
                if (twiDone == 1)
                    nstate <= stReadTempD1;
            
            stReadTempD1:
                if (twiDone == 1)
                    nstate <= stReadTempD2;
            
            stReadTempD2:
                if (twiDone == 1)
                    nstate <= stReadTempR;
            default :
                nstate <= stIdle;          
        endcase        
    end
    
assign number = tempReg[14:7];
    
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
       assign temp_high = ( temperature >= 8'd26 )? 1'b1:1'b0;
       assign temp_low = ( temperature <= 8'd25 )? 1'b1:1'b0;        

endmodule



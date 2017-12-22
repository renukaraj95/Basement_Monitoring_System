`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/10/2017 01:42:27 PM
// Design Name: 
// Module Name: I2C
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


module I2C(
    input MSG_I,
    input STB_I,
    input [7:0] A_I,
    input [7:0] D_I,
    output [7:0] D_O,
    output reg DONE_O,
    output reg ERR_O,
    input CLK,
    input SRST,
    inout SDA,
    output SCL
    );
    
    parameter TSCL_CYCLES = 250;
     
    
    reg [2:0] sync_sda, sync_scl;
    wire dSda, ddSda, dScl;
    reg [7:0] sclCnt = TSCL_CYCLES;
    wire [7:0] loadByte;
    reg [7:0] currAddr;
    reg [7:0] dataByte;
    reg rSda, rScl = 1;
    reg [1:0] subState = 2'b00;
    wire dataBitOut, rwBit;
    reg iDone, iErr, iSda, iScl, shiftBit, latchData, latchAddr;
    reg addrNData;
    reg [2:0] bitCount = 3'b111;
    reg int_Rst = 0;
    reg [3:0] state, nstate;
     
    localparam stIdle = 4'd0;
    localparam stStart = 4'd1;
    localparam stRead = 4'd2;
    localparam stWrite = 4'd3;
    localparam stError = 4'd4; 
    localparam stStop = 4'd5;
    localparam stSAck = 4'd6;
    localparam stMAck = 4'd7;
    localparam stMNAckStop = 4'd8;
    localparam stMNAckStart = 4'd9;
    localparam stStopError = 4'd10;
     
    always @ (posedge CLK)
    begin
         sync_sda[0] <= SDA;
         sync_sda[1] <= sync_sda[0];
         sync_sda[2] <= sync_sda[1];
    end
    
    assign dSda = sync_sda[1];
    assign ddSda = sync_sda[2];
    assign dScl = sync_scl[1];
    
    always @ (posedge CLK)
        if (state == stIdle && SRST == 0)
            int_Rst <= 0;
        else if (SRST == 1)
            int_Rst <= 1;
            
            
    always @ (posedge CLK)
        if (sclCnt == 0 || state == stIdle)
            sclCnt <= 62;    // TSCL_CYCLES/4 = 1000/4 = 250
        else
            sclCnt <= sclCnt - 1;
            
    always @ (posedge CLK)
        if ((latchData == 1 || latchAddr == 1) && sclCnt ==0)
        begin
            dataByte <= loadByte;
            bitCount <= 7;
            if (latchData == 1)
                addrNData <= 0;
            else
                addrNData <= 1;
        end
        else if (shiftBit == 1 && sclCnt == 0)
            begin
                dataByte <= {dataByte[6:0], dSda};
                bitCount <= bitCount -1;
            end
    
    assign loadByte = latchAddr ? A_I : D_I;
    assign dataBitOut = dataByte[7];
    assign D_O = dataByte;
    
    always @ (posedge CLK)
        if (latchAddr == 1)
            currAddr <= A_I;
    
    assign rwBit = currAddr[0];
            
    always @ (posedge CLK)
        if (state == stIdle)
            subState <= 2'b00;
        else if (sclCnt == 0)
            subState <= subState + 1;
            
    always @ (posedge CLK)
    begin
            state <= nstate;
            rSda <= iSda;
            rScl <= iScl;
            if (int_Rst == 1)
            begin
                DONE_O <= 0;
                ERR_O <= 0;
            end
            else
            begin
                DONE_O <= iDone;
                ERR_O <= iErr;                                           
            end
    end
        
    always @ (subState, state, dataByte[0], sclCnt, bitCount, rSda, rScl, dataBitOut, dSda, addrNData)
    begin
        iSda <= rSda;
        iScl <= rScl;
        iDone <= 0;
        iErr <= 0;
        shiftBit <= 0;
        latchAddr <= 0;
        latchData <= 0;
        
        if (state == stStart)
            case (subState)
                2'b00: iSda <= 1;
                2'b01:
                begin
                    iSda <= 1;
                    iScl <= 1;
                end
                2'b10:
                begin
                    iSda <= 0;
                    iScl <= 1;
                end
                2'b11:
                begin
                    iSda <= 0;
                    iScl <= 0;
                end        
            endcase
            
        if (state == stStop || state == stStopError)
            case (subState)
                2'b00: iSda <= 0;
                2'b01:
                begin
                    iSda <= 0;
                    iScl <= 1;
                end
                2'b10:
                begin
                    iSda <= 1;
                    iScl <= 1;
                end
                2'b11:
                    iScl <= 0;    
            endcase
            
            
        if (state == stRead || state == stSAck)
            case (subState)
                2'b00: iSda <= 1;
                2'b01: iScl <= 1;
                2'b10: iScl <= 1;
                2'b11: iScl <= 0;    
            endcase            
            
        if (state == stWrite)
            case (subState)
                2'b00: iSda <= dataBitOut;
                2'b01: iScl <= 1;
                2'b10: iScl <= 1;
                2'b11: iScl <= 0;    
            endcase                           

        if (state == stMAck)
            case (subState)
                2'b00: iSda <= 0;
                2'b01: iScl <= 1;
                2'b10: iScl <= 1;
                2'b11: iScl <= 0;    
            endcase
            
        if (state == stMNAckStop || state == stMNAckStart)
            case (subState)
                2'b00: iSda <= 1;
                2'b01: iScl <= 1;
                2'b10: iScl <= 1;
                2'b11: iScl <= 0;    
            endcase
            
        if (state == stSAck && sclCnt == 0 && subState == 2'b01)
            if (dSda == 1)
            begin
                iDone <= 1;
                iErr <= 1;
            end
            else if (addrNData == 0)
                iDone <= 1;
                
        if (state == stRead && subState == 2'b01 && sclCnt == 0 && bitCount == 0)        
            iDone <= 1;
            
        if (state == stWrite)
        begin
            iDone <= 1;
            iErr <= 1;
        end
        
        if ((state == stWrite && sclCnt == 0 && subState == 2'b11) || ((state == stSAck || state == stRead) && subState == 2'b01))                
            shiftBit <= 1;
            
        if (state == stStart)
            latchAddr <= 1;
        
        if (state == stSAck && subState == 2'b11)
            latchData <= 1;    
    
    end    
    
    always @ (state, STB_I, MSG_I, SRST, subState, bitCount, int_Rst, dataByte, A_I, currAddr, rwBit, sclCnt, addrNData)
    begin
        nstate <= state;
        
        case (state)
            stIdle:
                if (STB_I == 1 && SRST == 0)
                    nstate <= stStart;
                else
                    nstate <= stStop;
            
            stStart:
                if (sclCnt == 0)
                    if (int_Rst == 1)
                        nstate <= stStop;
                    else if (subState == 2'b11)
                        nstate <= stWrite;            
            
            stWrite:
                if (sclCnt == 0)
                    if (int_Rst == 1)
                        nstate <= stStop;
                    else if (subState == 2'b11 && bitCount == 0)
                        nstate <= stSAck;
            stSAck:
                if (sclCnt ==0)
                    if (int_Rst == 1 || (subState == 2'b11 && dataByte[0] == 1))
                        nstate <= stStop;
                    else if (subState == 2'b11)
                        if (addrNData == 1)
                            if (rwBit == 1)
                                nstate <= stRead;
                            else
                                nstate <= stWrite;
                        else if (STB_I == 1)
                        begin
                            if (MSG_I == 1 || currAddr != A_I)
                                nstate <= stStart;
                            else
                                if (rwBit == 1)
                                    nstate <= stRead;
                                else
                                    nstate <= stWrite;
                        end
                        else
                            nstate <= stStop;
                            
            stStop:
                if (subState == 2'b10 && sclCnt ==0)
                    nstate <= stIdle;
                    
            stRead:
                if (sclCnt == 0)
                    if (int_Rst == 1)
                        nstate <= stStop;
                    else if (subState == 2'b11 && bitCount ==7)
                        if (STB_I == 1)
                            if (MSG_I == 1 || currAddr != A_I)
                                nstate <= stMNAckStart;
                            else
                                nstate <= stMAck;
                        else
                            nstate <= stMNAckStop;                                                
                            
            stMAck:
                if (sclCnt == 0)
                    if (int_Rst == 1)
                        nstate <= stStop;
                    else if (subState == 2'b11)
                        nstate <= stRead;                                       
                
            stMNAckStart:
                if (sclCnt == 0)
                    if (int_Rst == 1)
                        nstate <= stStop;
                    else if (subState == 2'b11)
                        nstate <= stStart;
                        
            stMNAckStop:
                if (sclCnt == 0)
                    if (int_Rst == 1)
                        nstate <= stStop;
                    else if (subState == 2'b11)
                        nstate <= stStop;
                        
            default:
                nstate <= stIdle;                                                     
                
        endcase        
        
    end
    
    assign SDA = rSda ? 1'bZ : 0;
    assign SCL = rScl ? 1'bZ : 0;

endmodule    

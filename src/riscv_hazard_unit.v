module riscv_hazard_unit (
    input  wire [4:0] Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW,
    input  wire       RegWriteM, RegWriteW,
    input  wire       ResultSrcE0, // MemtoReg_E
    input  wire       PCSrcE,
    
    output reg        StallF, StallD, FlushD, FlushE,
    output reg  [1:0] ForwardAE, ForwardBE
);

    // [FIX] Calculate Stall Logic outside the always block
    wire lwStall;
    assign lwStall = ResultSrcE0 && ((Rs1D == RdE) || (Rs2D == RdE));

    always @(*) begin
        // Forwarding Logic
        if      ((Rs1E != 0) && (Rs1E == RdM) && RegWriteM) ForwardAE = 2'b10;
        else if ((Rs1E != 0) && (Rs1E == RdW) && RegWriteW) ForwardAE = 2'b01;
        else                                                ForwardAE = 2'b00;

        if      ((Rs2E != 0) && (Rs2E == RdM) && RegWriteM) ForwardBE = 2'b10;
        else if ((Rs2E != 0) && (Rs2E == RdW) && RegWriteW) ForwardBE = 2'b01;
        else                                                ForwardBE = 2'b00;

        // Stall Logic
        StallF = lwStall;
        StallD = lwStall;
        
        // Flush Logic
        FlushD = PCSrcE; 
        FlushE = lwStall || PCSrcE;
    end

endmodule
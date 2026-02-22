module riscv_alu4b (
    input  wire [31:0] SrcA,
    input  wire [31:0] SrcB,
    input  wire [3:0]  ALUControl,
    output reg  [31:0] ALUResult,
    output wire        Zero
);
	 wire [31:0] Product_Wallace;
    
    wallace_multiplier u_wallace (
        .a(SrcA), 
        .b(SrcB), 
        .prod(Product_Wallace)
    );
    always @(*) begin
        case (ALUControl)
            4'b0000: ALUResult = SrcA + SrcB;             // ADD
            4'b0001: ALUResult = SrcA - SrcB;             // SUB
            4'b0010: ALUResult = SrcA & SrcB;             // AND
            4'b0011: ALUResult = SrcA | SrcB;             // OR
            4'b0100: ALUResult = SrcA ^ SrcB;             // XOR
            4'b0101: ALUResult = ($signed(SrcA) < $signed(SrcB)) ? 32'd1 : 32'd0; // SLT
            4'b0110: ALUResult = (SrcA < SrcB) ? 32'd1 : 32'd0; // SLTU
            4'b0111: ALUResult = SrcA << SrcB[4:0];       // SLL
            4'b1000: ALUResult = SrcA >> SrcB[4:0];       // SRL
            4'b1001: ALUResult = $signed(SrcA) >>> SrcB[4:0]; // SRA
            4'b1010: ALUResult = SrcB;
				4'b1011: ALUResult = Product_Wallace;// LUI
            
                // MUL (Standard)
            // ------------------------------

            4'b1111: ALUResult = 32'b0;                   // CSR Mock
            default: ALUResult = 32'b0;
        endcase
    end
    assign Zero = (ALUResult == 0);
endmodule
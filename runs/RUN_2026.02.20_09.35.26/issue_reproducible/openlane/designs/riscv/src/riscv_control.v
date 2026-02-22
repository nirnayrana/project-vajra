module riscv_control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg       Branch, MemRead, MemtoReg, MemWrite, ALUSrc, RegWrite,
    output reg [1:0] ALUOp,
    output reg       Jump, PCToSrcA, IllegalInst, CSRWrite, IsMRET, ExtensionEnable
);
    always @(*) begin
        // Defaults
        Branch=0; MemRead=0; MemtoReg=0; MemWrite=0; ALUSrc=0; RegWrite=0; 
        ALUOp=0; Jump=0; PCToSrcA=0; IllegalInst=0; CSRWrite=0; IsMRET=0; ExtensionEnable=0;

        case (opcode)
            7'b0110011: begin RegWrite=1; ALUOp=2'b10; end // R-Type
            7'b0010011: begin ALUSrc=1; RegWrite=1; ALUOp=2'b10; end // I-Type
            7'b0000011: begin ALUSrc=1; MemtoReg=1; RegWrite=1; MemRead=1; end // LW
            7'b0100011: begin ALUSrc=1; MemWrite=1; end // SW
            7'b1100011: begin Branch=1; ALUOp=2'b01; end // Branch
            7'b0110111: begin RegWrite=1; ALUSrc=1; ALUOp=2'b11; end // LUI
            7'b0010111: begin RegWrite=1; ALUSrc=1; PCToSrcA=1; ALUOp=2'b00; end // AUIPC
            7'b1101111: begin Jump=1; RegWrite=1; ALUSrc=1; PCToSrcA=1; end // JAL
            7'b1100111: begin Jump=1; RegWrite=1; ALUSrc=1; end // JALR
            7'b1110011: begin RegWrite=1; if (funct3!=0) CSRWrite=1; end // System
            default: IllegalInst=1;
        endcase
    end
endmodule
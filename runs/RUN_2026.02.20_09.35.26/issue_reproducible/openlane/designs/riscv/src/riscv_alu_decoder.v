module riscv_alu_decoder(
    input wire [1:0] alu_op,
    input wire [2:0] funct3,
    input wire       funct7,
    input wire [6:0] op,
    output reg [3:0] alu_ctrl
);

    // ALU Commands
    parameter ALU_ADD = 4'b0000;
    parameter ALU_SUB = 4'b0001;
    parameter ALU_SLT = 4'b1000;
    // ... others implied ...

    always @(*) begin
        case(alu_op)
            2'b00: alu_ctrl = ALU_ADD; // LW/SW
            2'b01: alu_ctrl = 4'b0001; // BEQ (SUB)
            
            // R-Type and I-Type
            2'b10: begin
                case(funct3)
                    3'b000: begin
                        // Only SUB if it's R-Type (Opcode[5]=1) AND Funct7[5]=1
                        if (op[5] && funct7) 
                            alu_ctrl = 4'b0001; // SUB
                        else 
                            alu_ctrl = 4'b0000; // ADD (for ADD and ADDI)
                    end
                    3'b010: alu_ctrl = 4'b1000; // SLT
                    3'b011: alu_ctrl = 4'b1001; // SLTU
                    3'b100: alu_ctrl = 4'b0100; // XOR
                    3'b110: alu_ctrl = 4'b0011; // OR
                    3'b111: alu_ctrl = 4'b0010; // AND
                    3'b001: alu_ctrl = 4'b0101; // SLL
                    3'b101: alu_ctrl = (funct7) ? 4'b0111 : 4'b0110; // SRA or SRL
                    default: alu_ctrl = ALU_ADD;
                endcase
            end

            // --- THE FIX: LUI ---
            // Force ADD, ignore funct3 (because LUI has no funct3!)
            2'b11: alu_ctrl = ALU_ADD; 

            default: alu_ctrl = ALU_ADD;
        endcase
    end
endmodule
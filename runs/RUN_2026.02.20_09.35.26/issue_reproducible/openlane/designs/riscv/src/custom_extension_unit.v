module custom_extension_unit (
    input  wire [31:0] operand_a,    // From RS1
    input  wire [31:0] operand_b,    // From RS2
    input  wire [2:0]  funct3,       // To select specific custom function
    input  wire [6:0]  funct7,       // To select specific custom function
    input  wire        enable,       // High if opcode is "custom-0"
    output reg  [31:0] result        // The result of your custom math
);

    // This is your playground. 
    // Currently, let's just make it a "Bit Reverser" (Common in DSP/Defense)
    // or a specialized multiplier.
    
    always @(*) begin
        if (enable) begin
            case (funct3)
                // Example: A dedicated Defense Operation
                // Instruction: c.scramble x1, x2
                3'b000: result = operand_a ^ ~operand_b; // Simple Obfuscation
                
                // Example: Vector-like addition (Adding 2 16-bit numbers)
                // Instruction: c.vadd x1, x2
                3'b001: begin
                    result[15:0]  = operand_a[15:0] + operand_b[15:0];
                    result[31:16] = operand_a[31:16] + operand_b[31:16];
                end

                default: result = 32'h0;
            endcase
        end else begin
            result = 32'h0;
        end
    end

endmodule
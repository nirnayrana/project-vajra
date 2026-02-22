module riscv_imem (
    input  wire [31:0] a,
    output wire [31:0] rd
);

    // 1. Declare Memory AND Initialize it in one line
    // The (* ... *) attribute must go strictly BEFORE the reg declaration
    (* ram_init_file = "C:/Users/ranan/OneDrive/Desktop/mvp/RISCV_Pipelined_Processor2.0/instruction_mem.mif" *) reg [31:0] RAM [0:1023];

    // 2. Read Logic (Word Aligned)
    // a[31:2] divides by 4 (ignoring byte offset)
    assign rd = RAM[a[11:2]]; // Use [11:2] to prevent "Index out of range" warnings

endmodule
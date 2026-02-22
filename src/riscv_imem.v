`timescale 1ns/1ns
module riscv_imem (
    input  wire [31:0] a,
    output wire [31:0] rd
);

    reg [31:0] RAM [0:1023];

    initial begin
        // Relative path to the hex file we just created
        $readmemh("instruction_mem.hex", RAM);
    end

    // Word Aligned Read: a[11:2] 
    assign rd = RAM[a[11:2]]; 

endmodule
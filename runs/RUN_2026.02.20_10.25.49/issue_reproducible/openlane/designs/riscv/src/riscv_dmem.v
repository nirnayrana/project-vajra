module riscv_dmem (
    input  wire        clk,
    input  wire        we,
    input  wire [31:0] a,    // Address
    input  wire [31:0] wd,   // Write Data
    output wire [31:0] rd,   // Read Data
    
    // --- NEW IO PORTS ---
    output reg         io_valid, // Tells the testbench: "New Char Available!"
    output reg [7:0]   io_data   // The character to print
);

    reg [31:0] RAM [0:255]; // 1KB RAM

    assign rd = RAM[a[9:2]]; // Word Aligned Read

    always @(posedge clk) begin
        io_valid <= 0; // Default: No output
        
        if (we) begin
            // TRAFFIC COP LOGIC
            if (a == 32'h80000000) begin
                // It's a Print Command!
                io_valid <= 1;
                io_data  <= wd[7:0]; // Take bottom 8 bits (ASCII)
            end else begin
                // It's a Normal RAM Write
                RAM[a[9:2]] <= wd;
            end
        end
    end
endmodule
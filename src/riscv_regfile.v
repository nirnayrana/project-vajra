module riscv_regfile (
    input  wire        clk,
    input  wire        rst,
    input  wire        we3,       // Write Enable
    input  wire [4:0]  a1,        // Read Address 1
    input  wire [4:0]  a2,        // Read Address 2
    input  wire [4:0]  a3,        // Write Address
    input  wire [31:0] wd3,       // Write Data
    output wire [31:0] rd1,       // Read Data 1
    output wire [31:0] rd2        // Read Data 2
);

    reg [31:0] rf [31:0];
    
    // --- SIMULATION INITIALIZATION (Ignored by Synthesis) ---
    integer k;
    initial begin
        for (k = 0; k < 32; k = k + 1) rf[k] = 32'b0;
    end

    // --- WRITE LOGIC (Optimized) ---
    // Note: We REMOVED the synchronous reset loop. 
    // FPGAs don't like resetting entire RAM blocks at once.
    // Instead, we just rely on writing new data.
    always @(posedge clk) begin 
        if (we3 && a3 != 5'b0) begin 
            rf[a3] <= wd3;
        end
    end

    // --- READ LOGIC (Combinational) ---
    // Force x0 to be 0 hardwired.
    assign rd1 = (a1 == 5'b0) ? 32'b0 : rf[a1];
    assign rd2 = (a2 == 5'b0) ? 32'b0 : rf[a2];

endmodule
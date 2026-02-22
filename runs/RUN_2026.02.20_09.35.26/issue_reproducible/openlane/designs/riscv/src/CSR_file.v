module CSR_File (
    input wire clk,
    input wire rst_n,
    
    // Read Port (ID Stage)
    input wire [11:0] csr_addr,
    output reg [31:0] csr_rdata,

    // Write Port (WB Stage)
    input wire [11:0] wb_csr_addr,
    input wire [31:0] wb_csr_wdata,
    input wire wb_csr_write_en,
    
    // Direct Outputs to Control Unit (For Traps)
    output wire [31:0] mepc_out,
    output wire [31:0] mtvec_out,
    input wire trap_en,        // "Record this crash!"
    input wire [31:0] pc_in,   // "Where did we crash?"
    input wire [31:0] cause_in
);

    // --- 1. Define the Registers ---
    // Machine Exception Program Counter (Holds the address where code crashed)
    reg [31:0] mepc;      // Address: 0x341
    
    // Machine Cause (Why did it crash? e.g., Timer=7, Illegal Inst=2)
    reg [31:0] mcause;    // Address: 0x342
    
    // Machine Trap Vector (Where is the OS "Fix-it" code located?)
    reg [31:0] mtvec;     // Address: 0x305
    
    // Machine Status (Is the interrupt enabled globally?)
    reg [31:0] mstatus;   // Address: 0x300

    // --- 2. Read Logic (Combinational) ---
    always @(*) begin
        case (csr_addr)
            12'h300: csr_rdata = mstatus;
            12'h305: csr_rdata = mtvec;
            12'h341: csr_rdata = mepc;
            12'h342: csr_rdata = mcause;
            default: csr_rdata = 32'h00000000; // Return 0 for unknown CSRs
        endcase
    end

    // --- 3. Write Logic (Sequential) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset Values (Defined by RISC-V Spec)
            mepc    <= 32'h0;
            mcause  <= 32'h0;
            mtvec   <= 32'h0000_0000; // Usually set to boot address
            mstatus <= 32'h0;
        end else if (trap_en) begin
            // --- EXCEPTION HANDLER ---
            mepc   <= pc_in;    // Save the PC of the bad instruction
            mcause <= cause_in;
        end else if (wb_csr_write_en) begin
            case (wb_csr_addr)
                12'h300: mstatus <= wb_csr_wdata;
                12'h305: mtvec   <= wb_csr_wdata;
                12'h341: mepc    <= wb_csr_wdata;
                12'h342: mcause  <= wb_csr_wdata;
                // Add more cases here as you expand
            endcase
        end
    end

    // --- 4. Direct Outputs ---
    assign mepc_out = mepc;
    assign mtvec_out = mtvec;

endmodule
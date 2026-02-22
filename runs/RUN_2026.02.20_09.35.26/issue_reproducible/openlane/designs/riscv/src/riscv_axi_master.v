module riscv_axi_master (
    input wire clk, input wire rst,
    
    // CPU Interface
    input wire        mem_en,    // Enable
    input wire        mem_write, // 1=Write, 0=Read
    input wire [31:0] mem_addr,  // Address
    input wire [31:0] mem_wdata, // Write Data
    input wire [3:0]  mem_wstrb, // [NEW] Write Strobe (Byte Select)
    output reg [31:0] mem_rdata, // Read Data
    output reg        mem_busy,  // Stall Signal
    
    // AXI4-Lite Master Interface
    output reg [31:0] M_AXI_AWADDR, 
    output reg        M_AXI_AWVALID,
    input  wire       M_AXI_AWREADY,
    
    output reg [31:0] M_AXI_WDATA,
    output reg [3:0]  M_AXI_WSTRB, // Actual AXI Strobe
    output reg        M_AXI_WVALID,
    input  wire       M_AXI_WREADY,
    
    input  wire [1:0] M_AXI_BRESP,
    input  wire       M_AXI_BVALID,
    output reg        M_AXI_BREADY,
    
    output reg [31:0] M_AXI_ARADDR,
    output reg        M_AXI_ARVALID,
    input  wire       M_AXI_ARREADY,
    
    input  wire [31:0] M_AXI_RDATA,
    input  wire [1:0]  M_AXI_RRESP,
    input  wire       M_AXI_RVALID,
    output reg        M_AXI_RREADY
);

    // Simple FSM for AXI Transactions
    localparam IDLE = 0, WRITE_ADDR = 1, WRITE_DATA = 2, WRITE_RESP = 3, READ_ADDR = 4, READ_DATA = 5;
    reg [2:0] state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            mem_busy <= 1'b1; // Busy during reset
            M_AXI_AWVALID <= 0; M_AXI_WVALID <= 0; M_AXI_BREADY <= 0;
            M_AXI_ARVALID <= 0; M_AXI_RREADY <= 0;
        end else begin
            case (state)
                IDLE: begin
                    M_AXI_AWVALID <= 0; M_AXI_WVALID <= 0; M_AXI_ARVALID <= 0; M_AXI_RREADY <= 0; M_AXI_BREADY <= 0;
                    
                    if (mem_en) begin
                        mem_busy <= 1; // Stall CPU
                        if (mem_write) begin
                            state <= WRITE_ADDR;
                            M_AXI_AWADDR <= mem_addr;
                            M_AXI_AWVALID <= 1;
                        end else begin
                            state <= READ_ADDR;
                            M_AXI_ARADDR <= mem_addr;
                            M_AXI_ARVALID <= 1;
                        end
                    end else begin
                        mem_busy <= 0; // Ready for new request
                    end
                end

                // --- WRITE CHANNEL ---
                WRITE_ADDR: begin
                    if (M_AXI_AWREADY) begin
                        M_AXI_AWVALID <= 0;
                        state <= WRITE_DATA;
                        M_AXI_WDATA <= mem_wdata;
                        M_AXI_WSTRB <= mem_wstrb; // [NEW] Use input strobe
                        M_AXI_WVALID <= 1;
                    end
                end

                WRITE_DATA: begin
                    if (M_AXI_WREADY) begin
                        M_AXI_WVALID <= 0;
                        state <= WRITE_RESP;
                        M_AXI_BREADY <= 1;
                    end
                end

                WRITE_RESP: begin
                    if (M_AXI_BVALID) begin
                        M_AXI_BREADY <= 0;
                        mem_busy <= 0; // Operation Done
                        state <= IDLE;
                    end
                end

                // --- READ CHANNEL ---
                READ_ADDR: begin
                    if (M_AXI_ARREADY) begin
                        M_AXI_ARVALID <= 0;
                        state <= READ_DATA;
                        M_AXI_RREADY <= 1;
                    end
                end

                READ_DATA: begin
                    if (M_AXI_RVALID) begin
                        mem_rdata <= M_AXI_RDATA;
                        M_AXI_RREADY <= 0;
                        mem_busy <= 0; // Operation Done
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
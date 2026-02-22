`timescale 1ns/1ns

module riscv_axi_ram (
    input wire clk,
    input wire rst,

    // --- AXI4-LITE SLAVE INTERFACE ---
    // Write Address Channel
    input wire [31:0] S_AXI_AWADDR,
    input wire        S_AXI_AWVALID,
    output reg        S_AXI_AWREADY,

    // Write Data Channel
    input wire [31:0] S_AXI_WDATA,
    input wire        S_AXI_WVALID,
    input wire [3:0]  S_AXI_WSTRB,
    output reg        S_AXI_WREADY,

    // Write Response Channel
    output reg [1:0]  S_AXI_BRESP,
    output reg        S_AXI_BVALID,
    input wire        S_AXI_BREADY,

    // Read Address Channel
    input wire [31:0] S_AXI_ARADDR,
    input wire        S_AXI_ARVALID,
    output reg        S_AXI_ARREADY,

    // Read Data Channel
    output reg [31:0] S_AXI_RDATA,
    output reg [1:0]  S_AXI_RRESP,
    output reg        S_AXI_RVALID,
    input wire        S_AXI_RREADY
);

    // 1. MEMORY ARRAY (4KB)
    reg [31:0] RAM [0:1023];

    // 2. STATE MACHINE
    // We use a simple state to handle the handshake latency
    localparam IDLE = 0, WRITE_RESP = 1, READ_RESP = 2;
    reg [1:0] state;

    always @(posedge clk) begin
        if (rst) begin
            S_AXI_AWREADY <= 0; S_AXI_WREADY <= 0; S_AXI_BVALID <= 0;
            S_AXI_ARREADY <= 0; S_AXI_RVALID <= 0; S_AXI_RRESP <= 0; S_AXI_BRESP <= 0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    // --- WRITE HANDLING ---
                    // Ready to accept Address and Data immediately
                    S_AXI_AWREADY <= 1;
                    S_AXI_WREADY <= 1;
                    
                    if (S_AXI_AWVALID && S_AXI_WVALID) begin
                        S_AXI_AWREADY <= 0; // Close the gates
                        S_AXI_WREADY  <= 0;
                        
                        // MAGIC UART LOGIC 🎩
                        if (S_AXI_AWADDR == 32'h80000000) begin
                            $write("%c", S_AXI_WDATA[7:0]); // Print to Console
                        end else begin
                            // Normal RAM Write (Word Aligned)
                            RAM[S_AXI_AWADDR[11:2]] <= S_AXI_WDATA;
                        end
                        
                        S_AXI_BVALID <= 1; // "Done"
                        state <= WRITE_RESP;
                    end

                    // --- READ HANDLING ---
                    // Ready to accept Read Address
                    S_AXI_ARREADY <= 1;
                    
                    if (S_AXI_ARVALID) begin
                        S_AXI_ARREADY <= 0; // Close gate
                        
                        // Fetch Data
                        S_AXI_RDATA  <= RAM[S_AXI_ARADDR[11:2]];
                        S_AXI_RVALID <= 1; // Data Available
                        state <= READ_RESP;
                    end
                end

                WRITE_RESP: begin
                    if (S_AXI_BREADY) begin
                        S_AXI_BVALID <= 0;
                        state <= IDLE;
                    end
                end

                READ_RESP: begin
                    if (S_AXI_RREADY) begin
                        S_AXI_RVALID <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
module vajra_caravel_soc (
    `ifdef USE_POWER_PINS
    inout vdda1,
    inout vdda2,
    inout vssa1,
    inout vssa2,
    inout vccd1,
    inout vccd2,
    inout vssd1,
    inout vssd2,
    `endif

    input  wire        wb_clk_i,
    input  wire        wb_rst_i,

    input  wire [37:0] io_in,
    output wire [37:0] io_out,
    output wire [37:0] io_oeb
);

    // 1. AXI Master Interconnect Wires
    wire [31:0] axi_awaddr, axi_wdata, axi_araddr, axi_rdata;
    wire [3:0]  axi_wstrb;
    wire [1:0]  axi_bresp, axi_rresp;
    wire axi_awvalid, axi_wvalid, axi_bready, axi_arvalid, axi_rready;
    wire axi_awready, axi_wready, axi_bvalid, axi_arready, axi_rvalid;
    wire [9:0]  cpu_leds;

    // 2. Instantiate Your Pipelined AXI Core
    riscv_pipeline_top u_cpu (
        .clk            (wb_clk_i),
        .rst_n          (~wb_rst_i),
        .led            (cpu_leds),
        .M_AXI_AWADDR   (axi_awaddr),
        .M_AXI_WDATA    (axi_wdata),
        .M_AXI_ARADDR   (axi_araddr),
        .M_AXI_WSTRB    (axi_wstrb),
        .M_AXI_AWVALID  (axi_awvalid),
        .M_AXI_WVALID   (axi_wvalid),
        .M_AXI_BREADY   (axi_bready),
        .M_AXI_ARVALID  (axi_arvalid),
        .M_AXI_RREADY   (axi_rready),
        .M_AXI_RDATA    (axi_rdata),
        .M_AXI_BRESP    (axi_bresp),
        .M_AXI_RRESP    (axi_rresp),
        .M_AXI_AWREADY  (axi_awready),
        .M_AXI_WREADY   (axi_wready),
        .M_AXI_BVALID   (axi_bvalid),
        .M_AXI_ARREADY  (axi_arready),
        .M_AXI_RVALID   (axi_rvalid)
    );

    // 3. INTERNAL AXI SLAVE MEMORY
    reg [31:0] internal_ram [0:255]; 
    assign axi_awready = 1'b1;
    assign axi_wready  = 1'b1;
    assign axi_bvalid  = axi_wvalid;
    assign axi_bresp   = 2'b00;

    always @(posedge wb_clk_i) begin
        if (axi_wvalid && axi_wready) begin
            internal_ram[axi_awaddr[9:2]] <= axi_wdata;
        end
    end

    reg [31:0] rdata_reg;
    reg        rvalid_reg;
    always @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            rvalid_reg <= 1'b0;
            rdata_reg  <= 32'b0;
        end else begin
            if (axi_arvalid && axi_arready) begin
                rdata_reg  <= internal_ram[axi_araddr[9:2]];
                rvalid_reg <= 1'b1;
            end else if (axi_rready) begin
                rvalid_reg <= 1'b0;
            end
        end
    end

    assign axi_arready = 1'b1;
    assign axi_rdata   = rdata_reg;
    assign axi_rvalid  = rvalid_reg;
    assign axi_rresp   = 2'b00;

    // 4. THE ANTI-OPTIMIZATION SHIELD
    assign io_oeb = 38'h0000000000; 
    
    // We force Yosys to physically wire the AXI bus to the 38 output pins.
    // 16 bits of Address + 12 bits of Data + 10 bits of LEDs = 38 pins.
    assign io_out = {axi_awaddr[15:0], axi_wdata[11:0], cpu_leds};

endmodule

`timescale 1ns/1ns

module riscv_pipeline_top (
    input wire clk, 
    input wire rst_n,
    output wire [9:0]  led,
    
    // AXI4 Master Interface
    output wire [31:0] M_AXI_AWADDR, M_AXI_WDATA, M_AXI_ARADDR,
    output wire [3:0]  M_AXI_WSTRB,
    output wire        M_AXI_AWVALID, M_AXI_WVALID, M_AXI_BREADY, M_AXI_ARVALID, M_AXI_RREADY,
    input  wire [31:0] M_AXI_RDATA,
    input  wire [1:0]  M_AXI_BRESP, M_AXI_RRESP,
    input  wire        M_AXI_AWREADY, M_AXI_WREADY, M_AXI_BVALID, M_AXI_ARREADY, M_AXI_RVALID
);

    // Internal Signals
    wire rst = ~rst_n;
    wire stall_mem;
    wire [31:0] PC_Next_F, PC_Target_E, Instr_F;
    wire [31:0] ALUResult_E, ALUResult_M, ALUResult_W, WriteData_E, WriteData_M, ReadData_M, ReadData_W, Result_W;
    wire [31:0] PCPlus4_E, PCPlus4_M, PCPlus4_W;
    wire PCSrc_E, Stall_F, Stall_D, Flush_D, Flush_E;
    wire [1:0] ForwardAE, ForwardBE;

    // --- CLOCK ENABLE GENERATOR ---
    // Instead of a separate clock, we use an enable pulse to slow the pipeline
    reg [25:0] counter;
    always @(posedge clk or posedge rst) begin
        if (rst) counter <= 0;
        else     counter <= counter + 1;
    end
    wire ce = (counter == 26'h3FFFFFF); // Pipeline advances once every ~67M cycles

    // --- FETCH STAGE ---
    reg [31:0] PC_F;
    always @(posedge clk or posedge rst) begin
        if (rst) PC_F <= 0;
        else if (ce && !stall_mem && !Stall_F) PC_F <= PC_Next_F;
    end
    assign PC_Next_F = (PCSrc_E) ? PC_Target_E : PC_F + 4;
    
    riscv_imem IMEM ( .a(PC_F), .rd(Instr_F) );

    // --- DECODE STAGE ---
    reg [31:0] Instr_D, PC_D;
    always @(posedge clk or posedge rst) begin
        if (rst || (ce && Flush_D)) begin
            Instr_D <= 0; PC_D <= 0;
        end else if (ce && !stall_mem && !Stall_D) begin
            Instr_D <= Instr_F; PC_D <= PC_F;
        end
    end

    wire [4:0] Rs1_D = Instr_D[19:15];
    wire [4:0] Rs2_D = Instr_D[24:20];
    wire [4:0] Rd_D  = Instr_D[11:7];
    wire [2:0] Funct3_D = Instr_D[14:12];
    wire [31:0] RD1_D, RD2_D, Imm_D;
    wire RegWrite_D, MemtoReg_D, MemWrite_D, Jump_D, Branch_D, ALUSrc_D, PCToSrcA_D;
    wire [1:0] ALUOp_D;
    reg [3:0] ALUControl_D;

    riscv_regfile REG_FILE (
        .clk(clk), .rst(rst), .we3(RegWrite_W && ce), 
        .a1(Rs1_D), .a2(Rs2_D), .a3(Rd_W), .wd3(Result_W), 
        .rd1(RD1_D), .rd2(RD2_D)
    );

    riscv_control CONTROL (
        .opcode(Instr_D[6:0]), .funct3(Funct3_D), .funct7(Instr_D[31:25]),
        .RegWrite(RegWrite_D), .MemtoReg(MemtoReg_D), .MemWrite(MemWrite_D),
        .Branch(Branch_D), .ALUOp(ALUOp_D), .ALUSrc(ALUSrc_D), .Jump(Jump_D), .PCToSrcA(PCToSrcA_D)
    );

    // --- EXECUTE STAGE ---
    reg [31:0] RD1_E, RD2_E, PC_E, Imm_E;
    reg [4:0]  Rs1_E, Rs2_E, Rd_E;
    reg [3:0]  ALUControl_E;
    reg [2:0]  Funct3_E;
    reg        RegWrite_E, MemtoReg_E, MemWrite_E, Jump_E, Branch_E, ALUSrc_E, PCToSrcA_E;

    always @(posedge clk or posedge rst) begin
        if (rst || (ce && Flush_E)) begin
            {RegWrite_E, MemtoReg_E, MemWrite_E, Jump_E, Branch_E, ALUSrc_E, ALUControl_E, PCToSrcA_E} <= 0;
            {RD1_E, RD2_E, PC_E, Rs1_E, Rs2_E, Rd_E, Imm_E, Funct3_E} <= 0;
        end else if (ce && !stall_mem) begin
            RegWrite_E <= RegWrite_D; MemtoReg_E <= MemtoReg_D; MemWrite_E <= MemWrite_D;
            Jump_E <= Jump_D; Branch_E <= Branch_D; ALUSrc_E <= ALUSrc_D;
            ALUControl_E <= ALUControl_D; PCToSrcA_E <= PCToSrcA_D;
            RD1_E <= RD1_D; RD2_E <= RD2_D; PC_E <= PC_D;
            Rs1_E <= Rs1_D; Rs2_E <= Rs2_D; Rd_E <= Rd_D;
            Imm_E <= Imm_D; Funct3_E <= Funct3_D;
        end
    end

    wire [31:0] SrcA_Forwarded = (ForwardAE == 2'b10) ? ALUResult_M : (ForwardAE == 2'b01) ? Result_W : RD1_E;
    wire [31:0] SrcA_E = (PCToSrcA_E) ? PC_E : SrcA_Forwarded;
    wire [31:0] SrcB_E = (ALUSrc_E) ? Imm_E : ((ForwardBE==2'b10)?ALUResult_M:(ForwardBE==2'b01)?Result_W:RD2_E);
    
    riscv_alu4b ALU (.SrcA(SrcA_E), .SrcB(SrcB_E), .ALUControl(ALUControl_E), .ALUResult(ALUResult_E));

    // --- MEMORY STAGE ---
    reg [31:0] ALUResult_M_Reg, WriteData_M_Reg;
    reg [4:0]  Rd_M;
    reg        RegWrite_M, MemtoReg_M, MemWrite_M;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            RegWrite_M <= 0; MemtoReg_M <= 0; MemWrite_M <= 0;
            ALUResult_M_Reg <= 0; WriteData_M_Reg <= 0; Rd_M <= 0;
        end else if (ce && !stall_mem) begin
            RegWrite_M <= RegWrite_E; MemtoReg_M <= MemtoReg_E; MemWrite_M <= MemWrite_E;
            ALUResult_M_Reg <= ALUResult_E; WriteData_M_Reg <= WriteData_E; Rd_M <= Rd_E;
        end
    end

    assign ALUResult_M = ALUResult_M_Reg;
    assign WriteData_M = WriteData_M_Reg;

    // AXI Bridge
    riscv_axi_master AXI_BRIDGE (
        .clk(clk), .rst(rst), .mem_en((MemWrite_M || MemtoReg_M) && ce),
        .mem_write(MemWrite_M), .mem_addr(ALUResult_M), .mem_wdata(WriteData_M),
        .mem_rdata(ReadData_M), .mem_busy(stall_mem),
        .M_AXI_AWADDR(M_AXI_AWADDR), .M_AXI_AWVALID(M_AXI_AWVALID), .M_AXI_AWREADY(M_AXI_AWREADY),
        .M_AXI_WDATA(M_AXI_WDATA), .M_AXI_WVALID(M_AXI_WVALID), .M_AXI_WREADY(M_AXI_WREADY),
        .M_AXI_WSTRB(M_AXI_WSTRB), .M_AXI_BVALID(M_AXI_BVALID), .M_AXI_BREADY(M_AXI_BREADY),
        .M_AXI_ARADDR(M_AXI_ARADDR), .M_AXI_ARVALID(M_AXI_ARVALID), .M_AXI_ARREADY(M_AXI_ARREADY),
        .M_AXI_RDATA(M_AXI_RDATA), .M_AXI_RVALID(M_AXI_RVALID), .M_AXI_RREADY(M_AXI_RREADY)
    );

    // --- WRITEBACK STAGE ---
    reg [31:0] ALUResult_W_Reg, ReadData_W_Reg;
    reg [4:0]  Rd_W_Reg;
    reg        RegWrite_W_Reg, MemtoReg_W_Reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            RegWrite_W_Reg <= 0; MemtoReg_W_Reg <= 0;
            ALUResult_W_Reg <= 0; ReadData_W_Reg <= 0; Rd_W_Reg <= 0;
        end else if (ce && !stall_mem) begin
            RegWrite_W_Reg <= RegWrite_M; MemtoReg_W_Reg <= MemtoReg_M;
            ALUResult_W_Reg <= ALUResult_M; ReadData_W_Reg <= ReadData_M; Rd_W_Reg <= Rd_M;
        end
    end

    assign RegWrite_W = RegWrite_W_Reg;
    assign Rd_W = Rd_W_Reg;
    assign Result_W = (MemtoReg_W_Reg) ? ReadData_W_Reg : ALUResult_W_Reg;

    // --- FINAL OUTPUTS ---
    assign led = Result_W[9:0];

endmodule
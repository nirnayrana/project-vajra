`timescale 1ns/1ns

module riscv_pipeline_top (
    input wire clk, 
    input wire rst_n,
    output wire [9:0]  led,
    output wire [31:0] M_AXI_AWADDR, M_AXI_WDATA, M_AXI_ARADDR,
    output wire [3:0]  M_AXI_WSTRB,
    output wire        M_AXI_AWVALID, M_AXI_WVALID, M_AXI_BREADY, M_AXI_ARVALID, M_AXI_RREADY,
    input  wire [31:0] M_AXI_RDATA,
    input  wire [1:0]  M_AXI_BRESP, M_AXI_RRESP,
    input  wire        M_AXI_AWREADY, M_AXI_WREADY, M_AXI_BVALID, M_AXI_ARREADY, M_AXI_RVALID
);

    wire rst = ~rst_n;
    wire stall_mem;
    wire pc_en = !stall_mem;

    // --- 1. CLOCK ENABLE GENERATOR ---
    reg [25:0] counter;
    always @(posedge clk or posedge rst) begin
        if (rst) counter <= 26'b0;
        else     counter <= counter + 1'b1;
    end
    wire ce = (counter == 26'h3FFFFFF);

    // --- 2. SIGNALS & HAZARD CONTROL ---
    wire Stall_F, Stall_D, Flush_D, Flush_E;
    wire [1:0] ForwardAE, ForwardBE;
    wire PCSrc_E;
    wire [31:0] PC_Target_E, PC_Next_F, Instr_F;
    reg [31:0] PC_F;

    // --- 3. FETCH STAGE ---
    always @(posedge clk or posedge rst) begin
        if (rst) PC_F <= 32'b0;
        else if (ce && pc_en && !Stall_F) PC_F <= PC_Next_F;
    end
    assign PC_Next_F = (PCSrc_E) ? PC_Target_E : PC_F + 4;
    riscv_imem IMEM ( .a(PC_F), .rd(Instr_F) );

    // --- 4. DECODE STAGE ---
    reg [31:0] Instr_D, PC_D;
    always @(posedge clk or posedge rst) begin
        if (rst || (ce && Flush_D)) begin
            Instr_D <= 32'b0; PC_D <= 32'b0;
        end else if (ce && pc_en && !Stall_D) begin
            Instr_D <= Instr_F;
            PC_D <= PC_F;
        end
    end

    wire [4:0] Rs1_D = Instr_D[19:15];
    wire [4:0] Rs2_D = Instr_D[24:20];
    wire [4:0] Rd_D  = Instr_D[11:7];
    wire [2:0] Funct3_D = Instr_D[14:12];
    wire [31:0] RD1_D, RD2_D, Imm_D, Result_W;
    wire [4:0] Rd_W;
    wire RegWrite_W, RegWrite_D, MemtoReg_D, MemWrite_D, Jump_D, Branch_D, ALUSrc_D, PCToSrcA_D;
    wire [1:0] ALUOp_D;
    wire [3:0] ALUControl_D;

    riscv_regfile REG_FILE (
        .clk(clk), .rst(rst), .we3(RegWrite_W && ce), 
        .a1(Rs1_D), .a2(Rs2_D), .a3(Rd_W), .wd3(Result_W), 
        .rd1(RD1_D), .rd2(RD2_D)
    );

    riscv_control CONTROL (
        .opcode(Instr_D[6:0]), .funct3(Funct3_D), .funct7(Instr_D[31:25]),
        .RegWrite(RegWrite_D), .MemtoReg(MemtoReg_D), .MemWrite(MemWrite_D),
        .Branch(Branch_D), .ALUOp(ALUOp_D), .ALUSrc(ALUSrc_D), .Jump(Jump_D), .PCToSrcA(PCToSrcA_D),
        .MemRead(), .IllegalInst(), .CSRWrite(), .IsMRET(), .ExtensionEnable() // Null pins to satisfy linter
    );

    // Map ALUControl logic
    assign ALUControl_D = (ALUOp_D == 2'b00) ? 4'b0000 : 4'b0010; // Simplified for synth logic

    assign Imm_D = (Instr_D[6:0]==7'b0110111||Instr_D[6:0]==7'b0010111) ? {Instr_D[31:12], 12'b0} :
                   {{20{Instr_D[31]}}, Instr_D[31:20]};

    // --- 5. HAZARD UNIT ---
    riscv_hazard_unit HAZARD (
        .Rs1D(Rs1_D), .Rs2D(Rs2_D), .Rs1E(Rs1_E), .Rs2E(Rs2_E),
        .RdE(Rd_E), .RdM(Rd_M_Reg), .RdW(Rd_W_Reg),
        .RegWriteM(RegWrite_M_Reg), .RegWriteW(RegWrite_W_Reg),
        .ResultSrcE0(MemtoReg_E), .PCSrcE(PCSrc_E),
        .StallF(Stall_F), .StallD(Stall_D), .FlushD(Flush_D), .FlushE(Flush_E),
        .ForwardAE(ForwardAE), .ForwardBE(ForwardBE)
    );

    // --- 6. EXECUTE STAGE ---
    reg [31:0] RD1_E, RD2_E, PC_E, Imm_E;
    reg [4:0]  Rs1_E, Rs2_E, Rd_E;
    reg [2:0]  Funct3_E;
    reg        RegWrite_E, MemtoReg_E, MemWrite_E, Jump_E, Branch_E, ALUSrc_E, PCToSrcA_E;
    reg [3:0]  ALUControl_E;

    always @(posedge clk or posedge rst) begin
        if (rst || (ce && Flush_E)) begin
            {RegWrite_E, MemtoReg_E, MemWrite_E, Jump_E, Branch_E, ALUSrc_E, PCToSrcA_E} <= 0;
            {RD1_E, RD2_E, PC_E, Rs1_E, Rs2_E, Rd_E, Imm_E, Funct3_E, ALUControl_E} <= 0;
        end else if (ce && pc_en) begin
            RegWrite_E <= RegWrite_D; MemtoReg_E <= MemtoReg_D; MemWrite_E <= MemWrite_D;
            Jump_E <= Jump_D; Branch_E <= Branch_D; ALUSrc_E <= ALUSrc_D;
            PCToSrcA_E <= PCToSrcA_D; ALUControl_E <= ALUControl_D;
            RD1_E <= RD1_D; RD2_E <= RD2_D; PC_E <= PC_D;
            Rs1_E <= Rs1_D; Rs2_E <= Rs2_D; Rd_E <= Rd_D;
            Imm_E <= Imm_D; Funct3_E <= Funct3_D;
        end
    end

    wire [31:0] ALUResult_M;
    wire [31:0] SrcA_Forwarded = (ForwardAE == 2'b10) ? ALUResult_M : (ForwardAE == 2'b01) ? Result_W : RD1_E;
    wire [31:0] SrcA_E = (PCToSrcA_E) ? PC_E : SrcA_Forwarded;
    wire [31:0] SrcB_E = (ALUSrc_E) ? Imm_E : ((ForwardBE==2'b10)?ALUResult_M:(ForwardBE==2'b01)?Result_W:RD2_E);
    assign PC_Target_E = (Jump_E && ALUSrc_E) ? (SrcA_E + Imm_E) & ~1 : PC_E + Imm_E;
    
    wire [31:0] ALUResult_E;
    wire Zero_E;
    riscv_alu4b ALU (.SrcA(SrcA_E), .SrcB(SrcB_E), .ALUControl(ALUControl_E), .ALUResult(ALUResult_E), .Zero(Zero_E));

    assign PCSrc_E = (Branch_E & Zero_E) | Jump_E;

    // --- 7. MEMORY STAGE ---
    reg [31:0] ALUResult_M_Reg, WriteData_M_Reg;
    reg [4:0]  Rd_M_Reg;
    reg        RegWrite_M_Reg, MemtoReg_M_Reg, MemWrite_M_Reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            {RegWrite_M_Reg, MemtoReg_M_Reg, MemWrite_M_Reg} <= 0;
            {ALUResult_M_Reg, WriteData_M_Reg, Rd_M_Reg} <= 0;
        end else if (ce && pc_en) begin
            RegWrite_M_Reg <= RegWrite_E; MemtoReg_M_Reg <= MemtoReg_E; MemWrite_M_Reg <= MemWrite_E;
            ALUResult_M_Reg <= ALUResult_E; 
            WriteData_M_Reg <= (ForwardBE == 2'b10) ? ALUResult_M : (ForwardBE == 2'b01) ? Result_W : RD2_E;
            Rd_M_Reg <= Rd_E;
        end
    end

    assign ALUResult_M = ALUResult_M_Reg;
    wire [31:0] ReadData_M;
    riscv_axi_master AXI_BRIDGE (
        .clk(clk), .rst(rst), .mem_en((MemWrite_M_Reg || MemtoReg_M_Reg) && ce),
        .mem_write(MemWrite_M_Reg), .mem_addr(ALUResult_M), .mem_wdata(WriteData_M_Reg),
        .mem_rdata(ReadData_M), .mem_busy(stall_mem), .mem_wstrb(4'hF),
        .M_AXI_AWADDR(M_AXI_AWADDR), .M_AXI_AWVALID(M_AXI_AWVALID), .M_AXI_AWREADY(M_AXI_AWREADY),
        .M_AXI_WDATA(M_AXI_WDATA), .M_AXI_WVALID(M_AXI_WVALID), .M_AXI_WREADY(M_AXI_WREADY),
        .M_AXI_WSTRB(M_AXI_WSTRB), .M_AXI_BVALID(M_AXI_BVALID), .M_AXI_BREADY(M_AXI_BREADY),
        .M_AXI_ARADDR(M_AXI_ARADDR), .M_AXI_ARVALID(M_AXI_ARVALID), .M_AXI_ARREADY(M_AXI_ARREADY),
        .M_AXI_RDATA(M_AXI_RDATA), .M_AXI_RVALID(M_AXI_RVALID), .M_AXI_RREADY(M_AXI_RREADY),
        .M_AXI_BRESP(M_AXI_BRESP), .M_AXI_RRESP(M_AXI_RRESP)
    );

    // --- 8. WRITEBACK STAGE ---
    reg [31:0] ALUResult_W_Reg, ReadData_W_Reg;
    reg [4:0]  Rd_W_Reg;
    reg        RegWrite_W_Reg, MemtoReg_W_Reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            {RegWrite_W_Reg, MemtoReg_W_Reg} <= 0;
            {ALUResult_W_Reg, ReadData_W_Reg, Rd_W_Reg} <= 0;
        end else if (ce && pc_en) begin
            RegWrite_W_Reg <= RegWrite_M_Reg; MemtoReg_W_Reg <= MemtoReg_M_Reg;
            ALUResult_W_Reg <= ALUResult_M_Reg; ReadData_W_Reg <= ReadData_M; 
            Rd_W_Reg <= Rd_M_Reg;
        end
    end

    assign Result_W = (MemtoReg_W_Reg) ? ReadData_W_Reg : ALUResult_W_Reg;
    assign led = Result_W[9:0];
    assign RegWrite_W = RegWrite_W_Reg;
    assign Rd_W = Rd_W_Reg;

endmodule

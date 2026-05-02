module PC (clk, reset, stall, NextPc, PC);
    input clk;
    input reset;
    input stall;
    input [31:0] NextPc;
    output reg [31:0] PC;

    always @(posedge clk) begin
        if (reset) begin
            PC <= 32'd0;
        end
        else if (!stall) begin
            PC <= NextPc;
        end
        else begin
            PC <= PC;
        end
    end
endmodule

module ForwardingUnit (
    input  [4:0] Rs,
    input  [4:0] Rt,
    input  [4:0] Rp,
    input  [4:0] Rd_EX,
    input WE_EX,
    input  [4:0] Rd_MEM,
    input WE_MEM,
    input MemRead_MEM,
    input  [4:0] Rd_WB,
    input  WE_WB,
    output reg [1:0] FA,
    output reg [1:0] FB, 
    output reg [1:0] Fp
);

always @(*) begin
    FA = 2'b00;
    FB = 2'b00;	
    Fp = 2'b00;

    if (WE_EX && (Rd_EX != 0) && (Rd_EX == Rs))
        FA = 2'b01;
    else if (WE_MEM && !MemRead_MEM && (Rd_MEM != 0) && (Rd_MEM == Rs))
        FA = 2'b10;
    else if (WE_WB && (Rd_WB != 0) && (Rd_WB == Rs))
        FA = 2'b11;

    if (WE_EX && (Rd_EX != 0) && (Rd_EX == Rt))
        FB = 2'b01;
    else if (WE_MEM && !MemRead_MEM && (Rd_MEM != 0) && (Rd_MEM == Rt))
        FB = 2'b10;
    else if (WE_WB && (Rd_WB != 0) && (Rd_WB == Rt))
        FB = 2'b11;	 
		
    if (WE_EX && (Rd_EX != 0) && (Rd_EX == Rp))
        Fp = 2'b01;
    else if (WE_MEM && !MemRead_MEM && (Rd_MEM != 0) && (Rd_MEM == Rp))
        Fp = 2'b10;
    else if (WE_WB && (Rd_WB != 0) && (Rd_WB == Rp))
        Fp = 2'b11;	 
end
endmodule

module InstructionMemory (PC,Instruction);
    input [31:0] PC;        
    output wire [31:0] Instruction; 
    reg [31:0] memory [0:1048575];  
    assign Instruction = memory[PC[19:0]];
endmodule

module IF_ID (
    clk, reset, Instruction_in,
    PC1_in, Instruction_out, PC1_out
);
    input clk, reset;
    input  [31:0] Instruction_in;
    input  [31:0] PC1_in;
    output reg [31:0] Instruction_out;
    output reg [31:0] PC1_out;

    always @(posedge clk) begin
        if (reset) begin
            Instruction_out <= 32'b0;
            PC1_out         <= 32'b0;
        end
        else begin
            Instruction_out <= Instruction_in;
            PC1_out         <= PC1_in;
        end
    end
endmodule

module PC_Control_Unit (PC,Offset, Reg,PC_Selection,NextPC );
    input   [31:0] PC;
    input   [31:0] Offset;
    input   [31:0] Reg;
    input  [1:0]  PC_Selection;
    output reg  [31:0] NextPC;
    wire [31:0] PC_plus1;
    wire [31:0] JumpTarget;

    assign PC_plus1 = PC + 32'd1;
    assign JumpTarget = PC_plus1 + Offset;

    always @(*) begin
        case (PC_Selection)
            2'b00: NextPC = PC_plus1;
            2'b01: NextPC = JumpTarget;
            2'b10: NextPC = Reg;
            default: NextPC = PC_plus1;
        endcase
    end
endmodule

module ForwardingMUX (BusZ,BusY,BusP,ALU_RES_EX,DM_data,DWB,FA,FB,FP,A_F,B_F,P_F);
    input  [31:0] BusZ, BusY, BusP;
    input  [31:0] ALU_RES_EX, DM_data, DWB;
    input    [1:0]  FA, FB , FP;
    output reg [31:0] A_F, B_F,P_F;

    always @(*) begin
        case (FA)
            2'b00: A_F = BusZ;
            2'b01: A_F = ALU_RES_EX;
            2'b10: A_F = DM_data;
            2'b11: A_F = DWB;
            default: A_F = BusZ;
        endcase
    end

    always @(*) begin
        case (FB)
            2'b00: B_F = BusY;
            2'b01: B_F = ALU_RES_EX;
            2'b10: B_F = DM_data;
            2'b11: B_F = DWB;
            default: B_F = BusY;
        endcase
    end 

    always @(*) begin
        case (FP)
            2'b00: P_F = BusP;
            2'b01: P_F = ALU_RES_EX;
            2'b10: P_F = DM_data;
            2'b11: P_F = DWB;
            default: P_F = BusP;
        endcase
    end
endmodule

module ID_EX (
    clk, reset, flush,
    WB_ID, A_F_ID, B_F_ID, Imm_ID,
    MemRead_ID, MemWrite_ID, Rd_ID, AluOp_ID,
    AluSrc_ID, WE_ID,
    WB_EX, A_F_EX, B_F_EX, Imm_EX,
    MemRead_EX, MemWrite_EX, RdEX,
    AluOp_EX, AluSrc_EX, WE_EX,
    pc1, pc1_EX
);
    input clk;
    input reset;
    input flush;

    input [1:0]  WB_ID;
    input        MemRead_ID;
    input        MemWrite_ID;
    input        WE_ID;
    input [2:0]  AluOp_ID;
    input [31:0] A_F_ID;
    input [31:0] B_F_ID;
    input [31:0] Imm_ID;
    input [4:0]  Rd_ID;
    input        AluSrc_ID;
    input [31:0] pc1;

    output reg [1:0]  WB_EX;
    output reg        MemRead_EX;
    output reg        MemWrite_EX;
    output reg        WE_EX;
    output reg [2:0]  AluOp_EX;
    output reg [31:0] A_F_EX;
    output reg [31:0] B_F_EX;
    output reg [31:0] Imm_EX;
    output reg [4:0]  RdEX;
    output reg        AluSrc_EX;
    output reg [31:0] pc1_EX;

    always @(posedge clk) begin
        if (reset || flush) begin
            WB_EX        <= 0;
            MemRead_EX  <= 0;
            MemWrite_EX <= 0;
            WE_EX        <= 0;
            AluOp_EX    <= 0;
            A_F_EX      <= 0;
            B_F_EX      <= 0;
            Imm_EX      <= 0;
            RdEX        <= 0;
            AluSrc_EX   <= 0;
            pc1_EX      <= 0;
        end
        else begin
            WB_EX        <= WB_ID;
            MemRead_EX  <= MemRead_ID;
            MemWrite_EX <= MemWrite_ID;
            WE_EX        <= WE_ID;
            AluOp_EX    <= AluOp_ID;
            A_F_EX      <= A_F_ID;
            B_F_EX      <= B_F_ID;
            Imm_EX      <= Imm_ID;
            RdEX        <= Rd_ID;
            AluSrc_EX   <= AluSrc_ID;
            pc1_EX      <= pc1;
        end
    end
endmodule

module ALU (op1,op2,ALUOp,ALU_Result, Zero);
    input [31:0] op1;
    input [31:0] op2;
    input [2:0]  ALUOp;
    output reg [31:0] ALU_Result;
    output reg  Zero;

    always @(*) begin
        case (ALUOp)
            3'b000: ALU_Result = op1 + op2;        
            3'b001: ALU_Result = op1 - op2;        
            3'b010: ALU_Result = op1 | op2;        
            3'b011: ALU_Result = ~(op1|op2);        
            3'b100: ALU_Result = op1 & op2;     
            default: ALU_Result = 32'd0;
        endcase
        if (ALU_Result == 32'd0)
            Zero = 1'b1;
        else
            Zero = 1'b0;
    end
endmodule

module Data_Memory (clk,MemRead,MemWrite,address,write_data,read_data);
    input clk;
    input MemRead;
    input MemWrite;
    input [31:0] address;
    input [31:0] write_data;
    output reg [31:0] read_data;
    reg [31:0] memory [0:1048575];

    always @(posedge clk) begin
        if (MemWrite) begin
            memory[address] <= write_data;
        end
    end
    
    always @(*) begin
        if (MemRead)
            read_data = memory[address];
        else
            read_data = 32'd0;
    end
endmodule

module MEM_WB (
    clk,
    reset,
    ALU_RES_WB,
    DATA_MEM,
    PC1,
    WB,
    Rd,
    WE,
    BusX,
    Rd_WB,
    WE_WB
);
    input clk;
    input reset;
    input [31:0] ALU_RES_WB, DATA_MEM, PC1;
    input WE;
    input [1:0] WB;
    input [4:0] Rd;

    output reg [31:0] BusX;
    output reg [4:0]  Rd_WB;
    output reg        WE_WB;

    wire [31:0] DATA;

    assign DATA = (WB == 2'b00) ? ALU_RES_WB :
                  (WB == 2'b01) ? DATA_MEM   :
                  (WB == 2'b10) ? PC1        :
                                  32'b0;

    always @(posedge clk) begin
        if (reset) begin
            BusX <= 32'b0;
            Rd_WB <= 5'b0;
            WE_WB <= 1'b0;
        end
        else begin
            BusX <= DATA;
            Rd_WB <= Rd;
            WE_WB <= WE;
        end
    end
endmodule

module HazardUnit (MemRead_EX, Rd_EX, Rs, Rt, Rp, OpCode, Stall, Kill);
    input  MemRead_EX;
    input  [4:0] Rd_EX;
    input  [4:0] Rs, Rt, Rp;
    input  [4:0] OpCode;

    output reg Stall;
    output reg Kill;

    always @(*) begin
        Stall = 1'b0;
        Kill  = 1'b0;

        if (MemRead_EX && ((Rs != 0 && Rs == Rd_EX) || (Rt != 0 && Rt == Rd_EX) || (Rp != 0 && Rp == Rd_EX)))
            Stall = 1'b1;

        if ((OpCode == 5'd11) || (OpCode == 5'd12) || (OpCode == 5'd13))
            Kill = 1'b1;
    end
endmodule

module Extender (Imm, ExtenderSel, ImmExt);
    input  [21:0] Imm;
    input  ExtenderSel;
    output [31:0] ImmExt;

    assign ImmExt = (ExtenderSel) ? {{10{Imm[21]}}, Imm} : {10'b0, Imm};
endmodule

module MainControlUnit (
    Opcode,
    WB,
    MemRead,
    MemWrite,
    WE,
    ALUSrc,
    Extender,
    RegDes,
    PC_Selection,
    AluOP
);
    input  [4:0] Opcode;
    output reg       MemRead, MemWrite, WE, ALUSrc, Extender;
    output reg [1:0] PC_Selection, RegDes;
    output reg [2:0] AluOP;
    output reg [1:0] WB;

    always @(*) begin
        WB = 0;
        MemRead = 0;
        MemWrite = 0;
        WE = 0;
        ALUSrc = 0;
        RegDes = 0;
        PC_Selection = 0;
        AluOP = 0;
        Extender = 0;

        case (Opcode)
            0: begin
                WE = 1;
                WB = 2'b00;
                AluOP = 0;
            end

            1: begin
                WE = 1;
                WB = 2'b00;
                AluOP = 1;
            end

            2: begin
                WE = 1;
                WB = 2'b00;
                AluOP = 2;
            end

            3: begin
                WE = 1;
                WB = 2'b00;
                AluOP = 3;
            end

            4: begin
                WE = 1;
                WB = 2'b00;
                AluOP = 4;
            end

            5: begin
                WE = 1;
                WB = 2'b00;
                ALUSrc = 1;
                Extender = 1;
                AluOP = 0;
            end

            6: begin
                WE = 1;
                WB = 2'b00;
                ALUSrc = 1;
                Extender = 0;
                AluOP = 2;
            end

            7: begin
                WE = 1;
                WB = 2'b00;
                ALUSrc = 1;
                Extender = 0;
                AluOP = 3;
            end

            8: begin
                WE = 1;
                WB = 2'b00;
                ALUSrc = 1;
                Extender = 0;
                AluOP = 4;
            end

            9: begin
                WE = 1;
                WB = 2'b01;
                MemRead = 1;
                Extender = 1;
                ALUSrc = 1;
                AluOP = 0;
            end

            10: begin
                MemWrite = 1;
                Extender = 1;
                ALUSrc = 1;
                AluOP = 0;
            end

            11: begin
                PC_Selection = 1;
            end

            12: begin
                PC_Selection = 1;
                RegDes = 1;
                WE = 1;
                WB = 2'b10;
            end

            13: begin
                PC_Selection = 2;
            end
        endcase
    end
endmodule

module RegisterFile (
    clk,
    WriteEnable,
    Rs,
    Rt,
    Rp,
    Rd,
    BusX,
    PC,
    BusY,
    BusZ,
    BusP
);
    input clk;
    input WriteEnable;
    input [4:0] Rs,Rt,Rp,Rd;
    input [31:0] BusX;
    input [31:0] PC;
    output wire [31:0] BusY,BusZ,BusP;
    reg [31:0] regs [0:31];
    
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'b0;
    end

    assign BusY = (Rs == 0)  ? 32'b0 :
                  (Rs == 30) ? PC :

                  regs[Rs];

    assign BusZ = (Rt == 0)  ? 32'b0 :
                  (Rt == 30) ? PC :
          
                  regs[Rt];

    assign BusP = (Rp == 0)  ? 32'b0 :
                  (Rp == 30) ? PC :
                  regs[Rp];	

    always @(posedge clk) begin
        if (WriteEnable && (Rd != 0) && (Rd != 30)) begin
            regs[Rd] <= BusX;
        end
    end
endmodule	

module DecodeStage (clk,Instruction,opcode,Rs,Rt,Rd,Rp,imm12,offset);
    input clk;
    input  [31:0] Instruction;
    output wire [4:0]  opcode;
    output wire [4:0]  Rs, Rt, Rd, Rp;
    output wire [11:0] imm12;
    output wire [21:0] offset;
	
    assign opcode = Instruction[31:27];
    assign Rp  = Instruction[26:22];
    assign Rd  = Instruction[21:17];
    assign Rs  = Instruction[16:12];
    assign Rt  = Instruction[11:7];
    assign imm12 = Instruction[11:0];
    assign offset = Instruction[21:0];
endmodule

module EX_MEM (clk,reset,ALU_RES,B_F,Rd,MemWrite,MemRead,WE,WB,NPC,
               ALU_RES_EX,B_F_EX,Rd_EX, MemWrite_EX,MemRead_EX,WE_EX,WB_EX,NPC_EX);
    input clk,reset;
    input  [31:0] ALU_RES;
    input  [31:0] B_F;
    input  [4:0]  Rd;
    input MemWrite;
    input MemRead;
    input  WE;
    input [1:0]  WB;
    input [31:0] NPC;
    output reg [31:0] ALU_RES_EX;
    output reg [31:0] B_F_EX;
    output reg [4:0]  Rd_EX;
    output reg   MemWrite_EX;
    output reg  MemRead_EX;
    output reg  WE_EX;
    output reg [1:0] WB_EX;
    output reg [31:0] NPC_EX;

    always @(posedge clk) begin
        if (reset) begin
            ALU_RES_EX   <= 0;
            B_F_EX       <= 0;
            Rd_EX        <= 0;
            MemWrite_EX  <= 0;
            MemRead_EX   <= 0;
            WE_EX        <= 0;
            WB_EX        <= 0;
            NPC_EX       <= 0;
        end
        else begin
            ALU_RES_EX   <= ALU_RES;
            B_F_EX       <= B_F;
            Rd_EX        <= Rd;
            MemWrite_EX  <= MemWrite;
            MemRead_EX   <= MemRead;
            WE_EX        <= WE;
            WB_EX        <= WB;
            NPC_EX       <= NPC;
        end
    end
endmodule

module TopCPU (input clk,input reset);

wire [31:0] PC;
wire [31:0] NextPC;
wire [31:0] Instruction;

PC pc (.clk(clk),
  .reset(reset),
  .stall(Stall),
  .NextPc(NextPC),
  .PC(PC));

InstructionMemory IM (
    .PC(PC),
    .Instruction(Instruction)
);

wire [31:0] PC_plus1;
assign PC_plus1 = PC + 32'd1;
  								
wire [31:0] IFID_Instruction;
wire [31:0] IFID_PC1;

wire [31:0] IFID_Instr_in;
wire [31:0] IFID_PC1_in;
assign IFID_Instr_in = (Kill) ? 32'b0 : (Stall) ? IFID_Instruction : Instruction;
assign IFID_PC1_in = (Stall) ? IFID_PC1 : PC_plus1;

IF_ID IF_ID_U (
    .clk(clk),
    .reset(reset),
    .Instruction_in(IFID_Instr_in),
    .PC1_in(IFID_PC1_in),
    .Instruction_out(IFID_Instruction),
    .PC1_out(IFID_PC1)
);

wire [4:0] opcode;
wire [4:0] Rs, Rt, Rd, Rp;
wire [11:0] imm12;
wire [21:0] offset22;

DecodeStage DS (
    .clk(clk),
    .Instruction(IFID_Instruction),
    .opcode(opcode),
    .Rs(Rs),
    .Rt(Rt),
    .Rd(Rd),
    .Rp(Rp),
    .imm12(imm12),
    .offset(offset22)
);

wire [1:0] WB_ID;
wire MemRead_ID, MemWrite_ID, WE_ID, ALUSrc_ID, ExtenderSel_ID;
wire [1:0] PC_Selection_ID;
wire [2:0] ALUOp_ID;
wire [1:0] RegDes_ID;

MainControlUnit CU (
    .Opcode(opcode),
    .WB(WB_ID),
    .MemRead(MemRead_ID),
    .MemWrite(MemWrite_ID),
    .WE(WE_ID),
    .ALUSrc(ALUSrc_ID),
    .Extender(ExtenderSel_ID),
    .RegDes(RegDes_ID),
    .PC_Selection(PC_Selection_ID),
    .AluOP(ALUOp_ID)
);

wire [31:0] ImmExt_ID;
Extender EXT (
    .Imm({10'b0, imm12}),
    .ExtenderSel(ExtenderSel_ID),
    .ImmExt(ImmExt_ID)
);

wire [31:0] BusY, BusZ, BusP;
wire [31:0] BusX_WB;
wire [4:0]  Rd_WB;
wire WE_WB;

wire [4:0] Rd_ID_final;								   
assign Rd_ID_final = (RegDes_ID[0]) ? 5'd31 : Rd;

RegisterFile RF (					 
    .clk(clk),
    .WriteEnable(WE_WB),
    .Rs(Rs),
    .Rt(Rt),
    .Rp(Rp),
    .Rd(Rd_WB),
    .BusX(BusX_WB),
    .PC(PC),
    .BusY(BusY),
    .BusZ(BusZ),
    .BusP(BusP)
);

wire [1:0] FA, FB, FP;
wire Stall, Kill;

wire [31:0] ALU_RES_EX;
wire [4:0] RdEX;
wire WE_EX_ID;

wire [31:0] ALU_RES_MEM;
wire [4:0] Rd_MEM;
wire WE_MEM;

wire MemRead_MEM;

ForwardingUnit FU (
    .Rs(Rs),
    .Rt(Rt), 
    .Rp(Rp),
    .Rd_EX(RdEX),
    .Rd_MEM(Rd_MEM),
    .Rd_WB(Rd_WB),
    .WE_EX(WE_EX_ID),
    .WE_WB(WE_WB),
    .WE_MEM(WE_MEM),
    .MemRead_MEM(MemRead_MEM),
    .FA(FA),
    .FB(FB),
    .Fp(FP)
);

wire MemRead_EX;

HazardUnit HU (
    .MemRead_EX(MemRead_EX),
    .Rd_EX(RdEX),
    .Rs(Rs),
    .Rt(Rt),
    .Rp(Rp),
    .OpCode(opcode),
    .Stall(Stall),
    .Kill(Kill)
);

wire [31:0] A_F, B_F, P_F;
wire [31:0] DM_data;
wire [31:0] DWB_data;
assign DWB_data = BusX_WB;


ForwardingMUX FWR_U(
    .BusZ(BusZ),
    .BusY(BusY), 
    .BusP(BusP),
    .ALU_RES_EX(ALU_RES_EX),
    .DM_data(DM_data),
    .DWB(DWB_data),
    .FA(FA),
    .FB(FB),
    .FP(FP),
    .A_F(A_F),
    .B_F(B_F),
    .P_F(P_F)
);

wire Kill_Ins_D;	 
assign Kill_Ins_D = ((P_F == 32'b0) && (Rp != 5'b0));

wire [1:0] WB_ID_K;
wire MemRead_ID_K, MemWrite_ID_K, WE_ID_K, ALUSrc_ID_K;
wire [1:0] PC_Selection_ID_K;

assign WB_ID_K          = (Kill_Ins_D) ? 2'b00 : WB_ID;
assign MemRead_ID_K     = (Kill_Ins_D) ? 1'b0  : MemRead_ID;
assign MemWrite_ID_K    = (Kill_Ins_D) ? 1'b0  : MemWrite_ID;
assign WE_ID_K          = (Kill_Ins_D) ? 1'b0  : WE_ID;
assign ALUSrc_ID_K      = (Kill_Ins_D) ? 1'b0  : ALUSrc_ID;
assign PC_Selection_ID_K= (Kill_Ins_D) ? 2'b00 : PC_Selection_ID;

wire [31:0] OffsetExt;
Extender exOffset(
    .Imm(offset22),
    .ExtenderSel(1'b1),
    .ImmExt(OffsetExt)
);

PC_Control_Unit PCU (
    .PC(PC),
    .Offset(OffsetExt),
    .Reg(BusY),
    .PC_Selection(PC_Selection_ID_K),
    .NextPC(NextPC)
);

wire [1:0] WB_EX;
wire MemWrite_EX, ALUSrc_EX;
wire [2:0] ALUOp_EX;
wire [31:0] A_F_EX, B_F_EX, Imm_EX, PC1_EX;

ID_EX ID_EX_U (
    .clk(clk),
    .reset(reset),
    .flush(Stall),
    .WB_ID(WB_ID_K),
    .A_F_ID(A_F),
    .B_F_ID(B_F),
    .Imm_ID(ImmExt_ID),
    .MemRead_ID(MemRead_ID_K),
    .MemWrite_ID(MemWrite_ID_K),
    .Rd_ID(Rd_ID_final),
    .AluOp_ID(ALUOp_ID),
    .AluSrc_ID(ALUSrc_ID_K), 
    .WE_ID(WE_ID_K),
    .WB_EX(WB_EX),
    .A_F_EX(A_F_EX),
    .B_F_EX(B_F_EX),
    .Imm_EX(Imm_EX),
    .MemRead_EX(MemRead_EX),
    .MemWrite_EX(MemWrite_EX),
    .RdEX(RdEX),
    .AluOp_EX(ALUOp_EX),
    .AluSrc_EX(ALUSrc_EX),
    .WE_EX(WE_EX_ID),
    .pc1(IFID_PC1),
    .pc1_EX(PC1_EX)
);
							   
wire [31:0] ALU_op2;
assign ALU_op2 = (ALUSrc_EX) ? Imm_EX : B_F_EX;

wire Zero_F;
ALU ALU_U (
    .op1(A_F_EX),
    .op2(ALU_op2),
    .ALUOp(ALUOp_EX),
    .ALU_Result(ALU_RES_EX),
    .Zero(Zero_F)
);

wire [31:0] B_F_MEM, PC1_MEM;
wire [1:0]  WB_MEM;
wire MemWrite_MEM;

EX_MEM EX_MEM_U (
    .clk(clk),
    .reset(reset),
    .ALU_RES(ALU_RES_EX),
    .B_F(B_F_EX),
    .NPC(PC1_EX),
    .Rd(RdEX),
    .MemWrite(MemWrite_EX),
    .MemRead(MemRead_EX),
    .WE(WE_EX_ID),
    .WB(WB_EX),
    .ALU_RES_EX(ALU_RES_MEM),
    .B_F_EX(B_F_MEM),
    .NPC_EX(PC1_MEM),
    .Rd_EX(Rd_MEM),
    .MemWrite_EX(MemWrite_MEM),
    .MemRead_EX(MemRead_MEM),
    .WE_EX(WE_MEM),
    .WB_EX(WB_MEM)
);

Data_Memory DM (
    .clk(clk),
    .MemRead(MemRead_MEM),
    .MemWrite(MemWrite_MEM),
    .address(ALU_RES_MEM),
    .write_data(B_F_MEM),
    .read_data(DM_data)
);

MEM_WB MEM_WB_U (
    .clk(clk),
    .reset(reset),
    .ALU_RES_WB(ALU_RES_MEM),
    .DATA_MEM(DM_data),
    .PC1(PC1_MEM),
    .WB(WB_MEM),
    .Rd(Rd_MEM),
    .WE(WE_MEM),
    .BusX(BusX_WB),
    .Rd_WB(Rd_WB),
    .WE_WB(WE_WB)
);

endmodule 


module tb_TopCPU;

    reg clk;
    reg reset;

    TopCPU DUT (
        .clk(clk),
        .reset(reset)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset = 1;
        #15;
        reset = 0;
    end

    initial begin
        integer i;
        for (i = 0; i < 50; i = i + 1)
            DUT.IM.memory[i] = 32'b0;
        
        for (i = 0; i < 100; i = i + 1)
            DUT.DM.memory[i] = 32'b0;
		 
         //Test Program (1) 
        DUT.IM.memory[0] = {5'd5, 5'd0, 5'd1, 5'd0, 12'd5};
        DUT.IM.memory[1] = {5'd5, 5'd0, 5'd2, 5'd0, 12'd10};
        DUT.IM.memory[2] = {5'd0, 5'd0, 5'd3, 5'd1, 5'd2, 7'd0};
        DUT.IM.memory[3] = {5'd9, 5'd0, 5'd4, 5'd3, 12'd0};
        DUT.IM.memory[4] = {5'd0, 5'd0, 5'd5, 5'd4, 5'd1, 7'd0};
        DUT.IM.memory[5] = {5'd10, 5'd0, 5'd5, 5'd3, 12'd4};
        DUT.IM.memory[6] = {5'd11, 5'd3, 22'd2};
        DUT.IM.memory[7] = {5'd5, 5'd0, 5'd6, 5'd0, 12'd99};
        DUT.IM.memory[8] = {5'd12, 5'd1, 22'd2};
        DUT.IM.memory[9] = {5'd5, 5'd0, 5'd7, 5'd0, 12'd77};
        DUT.IM.memory[10] = {5'd13, 5'd0, 5'd0, 5'd31, 12'd0};
        DUT.IM.memory[11] = {5'd5, 5'd0, 5'd8, 5'd0, 12'd88};
		
		/*Test Program(2)Logical & Arthmatic Operation
		//Initialize registers using ADDI
		DUT.IM.memory[0]  = {5'd5, 5'd0, 5'd1, 5'd0, 12'd5};  // R1 = 0 + 5
         DUT.IM.memory[1]  = {5'd5, 5'd0, 5'd2, 5'd0, 12'd10}; // R2 = 0 + 10
         DUT.IM.memory[2]  = {5'd5, 5'd0, 5'd3, 5'd0, 12'd15}; // R3 = 0 + 15 
		// Compute: R7 = (R1 AND R2) OR (R3 NOR R1)
		DUT.IM.memory[3] = {5'd4, 5'd3, 5'd7, 5'd1,5'd2, 7'd0};    // AND R7 = R1 & R2
         DUT.IM.memory[4] = {5'd3, 5'd2, 5'd8, 5'd3,5'd1, 7'd0};    // NOR R8 = ~(R3 | R1)
         DUT.IM.memory[5] = {5'd2, 5'd7, 5'd9, 5'd7,5'd8, 7'd0};    // OR R9 = R7 | R8 
		// Compute: R23 = (R4 + R6) - (R2+(R3 - R1))
		DUT.IM.memory[6] = {5'd1, 5'd0, 5'd10, 5'd3 ,5'd1, 7'd0};    // SUB R10 = R3 - R1
         DUT.IM.memory[7] = {5'd0, 5'd6, 5'd14, 5'd2,5'd10, 7'd0};    // ADD R14 = R2 + R10
         DUT.IM.memory[8] = {5'd0, 5'd7, 5'd12, 5'd4,5'd6, 7'd0};    // ADD R12 = R4 + R6
		DUT.IM.memory[9] = {5'd1, 5'd2, 5'd23, 5'd12,5'd14, 7'd0};    // SUB R23 = R12 - R14
		  	 */
		 
		 /*Test Program(3):Find Maximum Number by using CALL prosedure from three Numbring fethed in memory	
		 //Store values in srveral memory location 
		 DUT.DM.memory[20] = 32'd15;
		 DUT.DM.memory[21] = 32'd35;
		 DUT.DM.memory[22] = 32'd8;
		// Load Values from memory location to registers(R1,R2,R3)
         DUT.IM.memory[0] = {5'd9, 5'd0, 5'd1, 5'd0, 12'd20};
         DUT.IM.memory[1] = {5'd9, 5'd0, 5'd2, 5'd0, 12'd21};
         DUT.IM.memory[2] = {5'd9, 5'd0, 5'd3, 5'd0, 12'd22};	  
		 //CALL MAX (R1,R2)
		 DUT.IM.memory[3] = {5'd12,5'd0,22'd5}; //Suppose Address for call instruction is start at 10
		 //CALL MAX (max,R3)
		 DUT.IM.memory[4] = {5'd12,5'd0,22'd5};
		 //store the max value into memory address 30
		 DUT.IM.memory[5] = {5'd10,5'd0, 5'd16,5'd0,12'd30};
		 
		 //CALL Function
		 DUT.IM.memory[10] = {5'd1,5'd0, 5'd8,5'd16,5'd2,7'd0}; //SUB R8 = R16 - R2
		 DUT.IM.memory[11] = {5'd3,5'd0, 5'd6,5'd8,5'd8,7'd0};	//sign = diff > 31 (by using NOR : NOR R6 = ~R8)
		 DUT.IM.memory[12] = {5'd4,5'd0, 5'd7,5'd16,5'd6,7'd0};	//mask1 = R16 & ~sign (AND R7)
		 DUT.IM.memory[13] = {5'd4,5'd0, 5'd5,5'd2,5'd6,7'd0};	//mask2 = R2 & sign	(AND R5)
		 DUT.IM.memory[14] = {5'd2,5'd0, 5'd16,5'd7,5'd5,7'd0};	//max = mask1 | mask2 (OR R16)
		 DUT.IM.memory[15] = {5'd13,5'd0, 5'd0,5'd31,5'd0,7'b0}; //return by using JR 31 
		 */
		  
		 /*Test Program(4):Test	check Sum b/w two stored value and store the result again
		 DUT.IM.memory[0] = {5'd5, 5'd0, 5'd1, 5'd0, 12'd5};   // R1 = 5
                 DUT.IM.memory[1] = {5'd5, 5'd0, 5'd2, 5'd0, 12'd10};  // R2 = 10
                 DUT.IM.memory[2] = {5'd5, 5'd0, 5'd3, 5'd0, 12'd15};  // R3 = 15
                 DUT.IM.memory[3] = {5'd0, 5'd0, 5'd4, 5'd2,5'd1, 7'd0};    // ADD R4 = R1 + R2
                 DUT.IM.memory[4] = {5'd0, 5'd0, 5'd5, 5'd4,5'd3 ,7'd0};    // ADD R5 = R4 + R3
                 DUT.IM.memory[5] = {5'd10, 5'd0, 5'd5, 5'd0,12'd20};       // SW R5 -> Mem[20]
                 DUT.IM.memory[6] = {5'd9, 5'd0, 5'd6, 5'd0,12'd20};        // LW R6 -> Mem[20]
		 */
        /*Test Program(5): Sign Inversion using CALL Procedure
       //Initialize data memory
       DUT.DM.memory[20] = 32'd25;    // Input value = +25
      //Load value from memory to R1
      DUT.IM.memory[0] = {5'd9, 5'd0, 5'd1, 5'd0, 12'd20};   // R1 = MEM[20] 
     //CALL Sign_Invert function
      DUT.IM.memory[1] = {5'd12, 5'd0, 22'd7}; //Store return address in R31
     // Store result back to memory
      DUT.IM.memory[2] = {5'd10, 5'd0, 5'd2, 5'd0, 12'd30}; // MEM[30] = R2
     // R2 = 0 - R1  (invert sign)
     DUT.IM.memory[10] = {5'd1, 5'd0, 5'd2, 5'd0, 5'd1, 7'd0}; 
	 DUT.IM.memory[11] = {5'd0, 5'd1, 5'd2, 5'd4, 7'd0};    // ADD R4 = R1 + R2
     DUT.IM.memory[12] = {5'd13, 5'd0, 5'd0, 5'd31,5'd0, 7'd0};// Return to caller
	*/	  
    end

    initial begin
        $monitor("Time=%4t | clk=%b | IF:PC=%2d IF:INS=%h | ID:op=%2d Rs=%2d Rt=%2d Rd=%2d Rp=%2d Imm=%h Off=%h | EX:ALU=%h | MEM:ALU=%h MR=%b MW=%b | WB:WE=%b Rd=%2d Data=%h | FA=%b FB=%b FP=%b | Stall=%b Killl=%b Kill_Inst_D = %b",
    $time,
    clk,
    DUT.PC,
    DUT.Instruction,
    DUT.opcode,
    DUT.Rs,
    DUT.Rt,
    DUT.Rd,
    DUT.Rp,
    DUT.ImmExt_ID,     // immediate after extend
    DUT.OffsetExt,     // offset after extend
    DUT.ALU_RES_EX,
    DUT.ALU_RES_MEM,
    DUT.MemRead_MEM,
    DUT.MemWrite_MEM,
    DUT.WE_WB,
    DUT.Rd_WB,
    DUT.BusX_WB,
    DUT.FA,
    DUT.FB,
    DUT.FP,
    DUT.Stall,
    DUT.Kill,
	DUT.Kill_Ins_D
);
    end

    always @(posedge clk) begin
        if (DUT.MemWrite_MEM)
            $display("MEM WRITE @%0t: Addr=%d Data=%d",
                     $time,
                     DUT.ALU_RES_MEM,
                     DUT.B_F_MEM);

        if (DUT.MemRead_MEM)
            $display("MEM READ  @%0t: Addr=%d Data=%d",
                     $time,
                     DUT.ALU_RES_MEM,
                     DUT.DM_data);
    end

    always @(posedge clk) begin
        if (DUT.WE_WB)
            $display("REG WRITE @%0t: R[%0d] = %d",
                     $time,
                     DUT.Rd_WB,
                     DUT.BusX_WB);
    end

    initial begin
        #400;
        $display("=== END OF SIMULATION ===");
        $finish;
    end

endmodule
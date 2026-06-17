`timescale 1ns / 1ps

module datapath (
    input  wire        clk,
    input  wire        reset,

    input  wire        memtoregD,
    input  wire        memwriteD,
    input  wire        alusrcD,
    input  wire        regdstD,
    input  wire        regwriteD,
    input  wire        jumpD,
    input  wire        branchD,
    input  wire [2:0]  alucontrolD,

    input  wire [31:0] instr,
    input  wire [31:0] readdataM,
    output wire [31:0] pcF,
    output wire        memwriteM,
    output wire [31:0] aluoutM,
    output wire [31:0] writedataM,

    output wire [5:0]  opD,
    output wire [5:0]  functD
);
    wire [1:0] forwardAE, forwardBE;
    wire       forwardAD, forwardBD;
    wire       stallF, stallD, flushE, flushD;

    wire [31:0] pcnext, pcnextbr, pcplus4F;
    wire [31:0] pcplus4D, instrD, pcbranchD;
    wire        pcsrcD;

    mux2  #(32) pcbrmux (pcplus4F, pcbranchD, pcsrcD, pcnextbr);
    mux2  #(32) pcmux   (pcnextbr, {pcplus4D[31:28], instrD[25:0], 2'b00}, jumpD, pcnext);
    flopenr #(32) pcreg (clk, reset, ~stallF, pcnext, pcF);
    adder        pcadd1 (pcF, 32'd4, pcplus4F);

    flopenr  #(32) r1D (clk, reset, ~stallD, pcplus4F, pcplus4D);
    flopenrc #(32) r2D (clk, reset, ~stallD, flushD, instr, instrD);

    wire [4:0]  rsD = instrD[25:21];
    wire [4:0]  rtD = instrD[20:16];
    wire [4:0]  rdD = instrD[15:11];
    wire [31:0] rd1D, rd2D, signimmD, signimmshD;

    assign opD    = instrD[31:26];
    assign functD = instrD[5:0];

    wire [31:0] resultW;
    wire [4:0]  writeregW;
    wire        regwriteW;

    regfile  rf      (clk, regwriteW, rsD, rtD, writeregW, resultW, rd1D, rd2D);
    signext  se      (instrD[15:0], signimmD);
    sl2      immsh   (signimmD, signimmshD);
    adder    pcadd2  (pcplus4D, signimmshD, pcbranchD);

    wire [31:0] cmpaD = forwardAD ? aluoutM : rd1D;
    wire [31:0] cmpbD = forwardBD ? aluoutM : rd2D;
    wire        equalD = (cmpaD == cmpbD);

    assign pcsrcD = branchD & equalD & ~stallD;
    assign flushD = pcsrcD | jumpD;

    wire        regwriteE, memtoregE, memwriteE, alusrcE, regdstE;
    wire [2:0]  alucontrolE;
    wire [31:0] rd1E, rd2E, signimmE;
    wire [4:0]  rsE, rtE, rdE;

    floprc #(8)  e_ctrl (clk, reset, flushE,
        {regwriteD, memtoregD, memwriteD, alusrcD, regdstD, alucontrolD},
        {regwriteE, memtoregE, memwriteE, alusrcE, regdstE, alucontrolE});
    floprc #(32) e_rd1  (clk, reset, flushE, rd1D, rd1E);
    floprc #(32) e_rd2  (clk, reset, flushE, rd2D, rd2E);
    floprc #(5)  e_rs   (clk, reset, flushE, rsD,  rsE);
    floprc #(5)  e_rt   (clk, reset, flushE, rtD,  rtE);
    floprc #(5)  e_rd   (clk, reset, flushE, rdD,  rdE);
    floprc #(32) e_imm  (clk, reset, flushE, signimmD, signimmE);

    wire [31:0] srcaE, srcbE, writedataE, aluoutE;
    wire [4:0]  writeregE;

    mux3 #(32) fwdamux (rd1E, resultW, aluoutM, forwardAE, srcaE);
    mux3 #(32) fwdbmux (rd2E, resultW, aluoutM, forwardBE, writedataE);
    mux2 #(32) srcbmux (writedataE, signimmE, alusrcE, srcbE);
    alu        alu_u   (.a(srcaE), .b(srcbE), .alucontrol(alucontrolE),
                        .result(aluoutE), .zero());
    mux2 #(5)  wrmux   (rtE, rdE, regdstE, writeregE);

    wire       regwriteM, memtoregM;
    wire [4:0] writeregM;

    flopr #(3)  m_ctrl (clk, reset, {regwriteE, memtoregE, memwriteE},
                                    {regwriteM, memtoregM, memwriteM});
    flopr #(32) m_alu  (clk, reset, aluoutE,    aluoutM);
    flopr #(32) m_wd   (clk, reset, writedataE, writedataM);
    flopr #(5)  m_wr   (clk, reset, writeregE,  writeregM);

    wire        memtoregW;
    wire [31:0] aluoutW, readdataW;

    flopr #(2)  w_ctrl (clk, reset, {regwriteM, memtoregM}, {regwriteW, memtoregW});
    flopr #(32) w_alu  (clk, reset, aluoutM,   aluoutW);
    flopr #(32) w_rd   (clk, reset, readdataM, readdataW);
    flopr #(5)  w_wr   (clk, reset, writeregM, writeregW);

    mux2 #(32) resmux (aluoutW, readdataW, memtoregW, resultW);

    hazard h (
        .rsD(rsD), .rtD(rtD), .rsE(rsE), .rtE(rtE),
        .writeregE(writeregE), .writeregM(writeregM), .writeregW(writeregW),
        .regwriteE(regwriteE), .regwriteM(regwriteM), .regwriteW(regwriteW),
        .memtoregE(memtoregE), .memtoregM(memtoregM),
        .branchD(branchD),
        .forwardAE(forwardAE), .forwardBE(forwardBE),
        .forwardAD(forwardAD), .forwardBD(forwardBD),
        .stallF(stallF), .stallD(stallD), .flushE(flushE)
    );
endmodule


module regfile (
    input  wire        clk,
    input  wire        we3,
    input  wire [4:0]  ra1, ra2, wa3,
    input  wire [31:0] wd3,
    output wire [31:0] rd1, rd2
);
    reg [31:0] rf [0:31];

    always @(negedge clk)
        if (we3) rf[wa3] <= wd3;

    assign rd1 = (ra1 != 5'b0) ? rf[ra1] : 32'b0;
    assign rd2 = (ra2 != 5'b0) ? rf[ra2] : 32'b0;
endmodule

module adder (input wire [31:0] a, b, output wire [31:0] y);
    assign y = a + b;
endmodule

module sl2 (input wire [31:0] a, output wire [31:0] y);
    assign y = {a[29:0], 2'b00};
endmodule

module signext (input wire [15:0] a, output wire [31:0] y);
    assign y = {{16{a[15]}}, a};
endmodule

module mux2 #(parameter WIDTH = 8) (
    input  wire [WIDTH-1:0] d0, d1,
    input  wire             s,
    output wire [WIDTH-1:0] y
);
    assign y = s ? d1 : d0;
endmodule

module mux3 #(parameter WIDTH = 8) (
    input  wire [WIDTH-1:0] d0, d1, d2,
    input  wire [1:0]       s,
    output reg  [WIDTH-1:0] y
);
    always @(*)
        case (s)
            2'b00:   y = d0;
            2'b01:   y = d1;
            2'b10:   y = d2;
            default: y = d0;
        endcase
endmodule

module flopr #(parameter WIDTH = 8) (
    input  wire             clk, reset,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);
    always @(posedge clk or posedge reset)
        if (reset) q <= 0; else q <= d;
endmodule

module flopenr #(parameter WIDTH = 8) (
    input  wire             clk, reset, en,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);
    always @(posedge clk or posedge reset)
        if (reset)   q <= 0;
        else if (en) q <= d;
endmodule

module floprc #(parameter WIDTH = 8) (
    input  wire             clk, reset, clear,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);
    always @(posedge clk or posedge reset)
        if (reset)      q <= 0;
        else if (clear) q <= 0;
        else            q <= d;
endmodule

module flopenrc #(parameter WIDTH = 8) (
    input  wire             clk, reset, en, clear,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);
    always @(posedge clk or posedge reset)
        if (reset)      q <= 0;
        else if (clear) q <= 0;
        else if (en)    q <= d;
endmodule

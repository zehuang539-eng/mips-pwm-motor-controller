`timescale 1ns / 1ps

module mips (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  switches,
    output wire        pwm_out
);
    wire reset = ~rst_n;

    wire        memtoregD, memwriteD, branchD, alusrcD, regdstD, regwriteD, jumpD;
    wire [2:0]  alucontrolD;
    wire [5:0]  opD, functD;

    wire [31:0] pc, instr;
    wire        memwriteM;
    wire [31:0] aluoutM, writedataM, readdataM;

    wire [7:0]  pwm_duty;
    wire        pwm_enable;

    controller ctl (
        .op(opD), .funct(functD),
        .memtoreg(memtoregD), .memwrite(memwriteD), .branch(branchD),
        .alusrc(alusrcD), .regdst(regdstD), .regwrite(regwriteD),
        .jump(jumpD), .alucontrol(alucontrolD)
    );

    datapath dp (
        .clk(clk), .reset(reset),
        .memtoregD(memtoregD), .memwriteD(memwriteD), .alusrcD(alusrcD),
        .regdstD(regdstD), .regwriteD(regwriteD), .jumpD(jumpD), .branchD(branchD),
        .alucontrolD(alucontrolD),
        .instr(instr), .readdataM(readdataM),
        .pcF(pc), .memwriteM(memwriteM), .aluoutM(aluoutM), .writedataM(writedataM),
        .opD(opD), .functD(functD)
    );

    imem im (.a(pc[7:2]), .rd(instr));

    data_memory dmem (
        .clk(clk), .rst_n(rst_n),
        .we(memwriteM), .a(aluoutM), .wd(writedataM),
        .switches(switches), .rd(readdataM),
        .pwm_duty(pwm_duty), .pwm_enable(pwm_enable)
    );

    pwm_controller pwm (
        .clk(clk), .rst_n(rst_n),
        .enable(pwm_enable), .duty_cycle(pwm_duty),
        .pwm_out(pwm_out)
    );
endmodule

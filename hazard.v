`timescale 1ns / 1ps

module hazard (
    input  wire [4:0] rsD, rtD,
    input  wire [4:0] rsE, rtE,
    input  wire [4:0] writeregE, writeregM, writeregW,
    input  wire       regwriteE, regwriteM, regwriteW,
    input  wire       memtoregE, memtoregM,
    input  wire       branchD,
    output reg  [1:0] forwardAE, forwardBE,
    output wire       forwardAD, forwardBD,
    output wire       stallF, stallD, flushE
);
    wire lwstallD, branchstallD;

    assign forwardAD = (rsD != 5'b0) & (rsD == writeregM) & regwriteM;
    assign forwardBD = (rtD != 5'b0) & (rtD == writeregM) & regwriteM;

    always @(*) begin
        if      ((rsE != 5'b0) & (rsE == writeregM) & regwriteM) forwardAE = 2'b10;
        else if ((rsE != 5'b0) & (rsE == writeregW) & regwriteW) forwardAE = 2'b01;
        else                                                     forwardAE = 2'b00;
        if      ((rtE != 5'b0) & (rtE == writeregM) & regwriteM) forwardBE = 2'b10;
        else if ((rtE != 5'b0) & (rtE == writeregW) & regwriteW) forwardBE = 2'b01;
        else                                                     forwardBE = 2'b00;
    end

    assign lwstallD = memtoregE & ((rtE == rsD) | (rtE == rtD));

    assign branchstallD = branchD &
        ( (regwriteE & ((writeregE == rsD) | (writeregE == rtD))) |
          (memtoregM & ((writeregM == rsD) | (writeregM == rtD))) );

    assign stallD = lwstallD | branchstallD;
    assign stallF = stallD;
    assign flushE = stallD;
endmodule

`timescale 1ns / 1ps

module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  alucontrol,
    output reg  [31:0] result,
    output wire        zero
);
    wire [31:0] condinvb = alucontrol[2] ? ~b : b;
    wire [31:0] sum      = a + condinvb + {31'b0, alucontrol[2]};

    always @(*) begin
        case (alucontrol[1:0])
            2'b00: result = a & b;
            2'b01: result = a | b;
            2'b10: result = sum;
            2'b11: result = {31'b0, sum[31]};
            default: result = 32'bx;
        endcase
    end

    assign zero = (result == 32'b0);
endmodule

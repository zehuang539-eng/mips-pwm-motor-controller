`timescale 1ns / 1ps

module controller (
    input  wire [5:0] op,
    input  wire [5:0] funct,
    output wire       memtoreg,
    output wire       memwrite,
    output wire       branch,
    output wire       alusrc,
    output wire       regdst,
    output wire       regwrite,
    output wire       jump,
    output wire [2:0] alucontrol
);
    wire [1:0] aluop;

    maindec md (
        .op(op),
        .memtoreg(memtoreg), .memwrite(memwrite), .branch(branch),
        .alusrc(alusrc), .regdst(regdst), .regwrite(regwrite),
        .jump(jump), .aluop(aluop)
    );

    aludec ad (.funct(funct), .aluop(aluop), .alucontrol(alucontrol));
endmodule


module maindec (
    input  wire [5:0] op,
    output wire       memtoreg,
    output wire       memwrite,
    output wire       branch,
    output wire       alusrc,
    output wire       regdst,
    output wire       regwrite,
    output wire       jump,
    output wire [1:0] aluop
);
    reg [8:0] controls;

    assign {regwrite, regdst, alusrc, branch, memwrite,
            memtoreg, jump, aluop} = controls;

    always @(*) begin
        case (op)
            6'b000000: controls = 9'b110000010;
            6'b100011: controls = 9'b101001000;
            6'b101011: controls = 9'b001010000;
            6'b000100: controls = 9'b000100001;
            6'b001000: controls = 9'b101000000;
            6'b000010: controls = 9'b000000100;
            default:   controls = 9'b000000000;
        endcase
    end
endmodule


module aludec (
    input  wire [5:0] funct,
    input  wire [1:0] aluop,
    output reg  [2:0] alucontrol
);
    always @(*) begin
        case (aluop)
            2'b00: alucontrol = 3'b010;
            2'b01: alucontrol = 3'b110;
            default: begin
                case (funct)
                    6'b100000: alucontrol = 3'b010;
                    6'b100010: alucontrol = 3'b110;
                    6'b100100: alucontrol = 3'b000;
                    6'b100101: alucontrol = 3'b001;
                    6'b101010: alucontrol = 3'b111;
                    default:   alucontrol = 3'bxxx;
                endcase
            end
        endcase
    end
endmodule

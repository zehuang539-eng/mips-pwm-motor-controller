`timescale 1ns / 1ps

module imem (
    input  wire [5:0]  a,
    output wire [31:0] rd
);
    reg [31:0] RAM [0:63];

    initial $readmemh("memfile.dat", RAM);

    assign rd = RAM[a];
endmodule

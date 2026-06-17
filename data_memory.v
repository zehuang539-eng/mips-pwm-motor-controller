`timescale 1ns / 1ps

module data_memory (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        we,
    input  wire [31:0] a,
    input  wire [31:0] wd,
    input  wire [7:0]  switches,
    output reg  [31:0] rd,
    output reg  [7:0]  pwm_duty,
    output reg         pwm_enable
);
    reg [31:0] RAM [0:63];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_duty   <= 8'd0;
            pwm_enable <= 1'b0;
        end else if (we) begin
            case (a)
                32'h00000098: pwm_duty    <= wd[7:0];
                32'h0000009C: pwm_enable  <= wd[0];
                default:      RAM[a[7:2]] <= wd;
            endcase
        end
    end

    always @(*) begin
        case (a)
            32'h00000090: rd = {24'b0, switches};
            32'h00000098: rd = {24'b0, pwm_duty};
            32'h0000009C: rd = {31'b0, pwm_enable};
            default:      rd = RAM[a[7:2]];
        endcase
    end
endmodule

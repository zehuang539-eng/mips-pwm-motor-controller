`timescale 1ns / 1ps

module pwm_controller (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire [7:0] duty_cycle,
    output reg        pwm_out
);
    reg [7:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)        counter <= 8'd0;
        else if (enable)   counter <= counter + 8'd1;
        else               counter <= 8'd0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)        pwm_out <= 1'b0;
        else if (enable)   pwm_out <= (counter < duty_cycle);
        else               pwm_out <= 1'b0;
    end
endmodule

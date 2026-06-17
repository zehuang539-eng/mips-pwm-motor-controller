`timescale 1ns/1ps

module mips_tb;
    reg        clk;
    reg        rst_n;
    reg  [7:0] switches;
    wire       pwm_out;

    mips dut (
        .clk(clk), .rst_n(rst_n),
        .switches(switches), .pwm_out(pwm_out)
    );

    wire [7:0] pwm_duty   = dut.pwm_duty;
    wire       pwm_enable = dut.pwm_enable;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, clk, rst_n, switches, pwm_out, pwm_duty, pwm_enable);

        rst_n    = 1'b0;
        switches = 8'h00;
        #20 rst_n = 1'b1;

        #4000000;
        $display("Simulation finished at %0t ns", $time);
        $finish;
    end

    initial begin
        $display("   time(ns)   enable  duty");
        forever begin
            @(pwm_duty or pwm_enable);
            $display("%10t     %b     %0d", $time, pwm_enable, pwm_duty);
        end
    end
endmodule

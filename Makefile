# Makefile for the MIPS PWM Motor Controller
#
#   make        compile + run the simulation (produces wave.vcd)
#   make wave   run the simulation, then open the waveform in GTKWave
#   make clean  remove build products
#
# Requires: Icarus Verilog (iverilog, vvp) and GTKWave.

IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave

# All Verilog sources. mips_tb.v must be last so its `timescale applies.
SRCS = pwm_controller.v imem.v alu.v controller.v hazard.v \
       data_memory.v datapath.v mips.v mips_tb.v

TOP  = mips_tb
OUT  = simv
VCD  = wave.vcd

all: run

$(OUT): $(SRCS) memfile.dat
	$(IVERILOG) -g2012 -o $(OUT) -s $(TOP) $(SRCS)

run: $(OUT)
	$(VVP) $(OUT)

wave: run
	$(GTKWAVE) $(VCD) &

clean:
	rm -f $(OUT) $(VCD)

.PHONY: all run wave clean

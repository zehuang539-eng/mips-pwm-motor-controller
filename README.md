# MIPS PWM Motor Controller

A 5-stage pipelined MIPS CPU that drives a **PWM** signal through **Memory-Mapped
I/O (MMIO)**, plus a MIPS assembly program that uses the PWM peripheral to produce
a motor speed profile (**Option A — ramp up / hold / ramp down / hold / repeat**).

```
            YOUR FINAL SYSTEM
  +---------+   +-----------+   +------------------+
  |  MIPS   |-->|  MMIO in  |-->|  PWM controller  |--> pwm_out
  |  CPU    |   | data mem  |   | (counter + cmp)  |
  +---------+   +-----------+   +------------------+
   software       address-        hardware peripheral
   (memfile.dat)  decode bridge   (8-bit duty cycle)
```

## MMIO address map

| Address  | Device      | Direction  | Notes                     |
|----------|-------------|------------|---------------------------|
| `0x0000+`| RAM         | read/write | normal data memory        |
| `0x0090` | switches    | read-only  | 8-bit external input      |
| `0x0098` | PWM duty    | write-only | 8-bit duty cycle          |
| `0x009C` | PWM enable  | write-only | 1-bit on/off              |

## How to build and run

Requires [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog`, `vvp`) and
[GTKWave](http://gtkwave.sourceforge.net/).

```sh
make          # compile all Verilog and run the simulation -> wave.vcd
make wave     # run the simulation, then open the waveform in GTKWave
gtkwave wave.vcd   # (or open the VCD manually)
make clean    # remove simv and wave.vcd
```

The program is loaded from `memfile.dat` (hex, one 32-bit instruction per line)
into instruction memory at simulation start.

## What you'll see

After reset the program first writes `1` to `0x9C` (PWM enable). It then repeats:

1. **Ramp up** — `pwm_duty` counts `0, 1, 2, ... , 64`, holding each value for a
   short delay loop.
2. **Hold at max** — `pwm_duty` stays at `64` for a longer delay.
3. **Ramp down** — `pwm_duty` counts `63, 62, ... , 0`.
4. **Hold at zero** — `pwm_duty` stays at `0` (motor off) for a longer delay,
   then the cycle repeats.

`pwm_out` is a square wave whose **high-time fraction equals `pwm_duty/256`**, so
as the duty ramps you can see the pulses get visibly wider, then narrower. With
the default constants the PWM period is `256 x 10 ns = 2.56 us`.

The peak duty, ramp speed, and hold time are tunable constants in the program —
see `docs/design_report.md` §5.

## File layout

```
mips-pwm-motor-controller/
├── README.md            # this file (Document 1)
├── Makefile             # `make` builds & runs; `make wave` opens GTKWave
├── memfile.dat          # motor-control program in hex (Option A)
├── mips.v               # top-level: CPU + imem + dmem + PWM (switches, pwm_out)
├── mips_tb.v            # testbench (clock/reset, drives switches, dumps VCD)
├── datapath.v           # 5-stage pipelined datapath + library modules
├── controller.v         # control unit (main decoder + ALU decoder)
├── hazard.v             # hazard unit (forwarding + stalls)
├── alu.v                # ALU
├── data_memory.v        # data memory with MMIO address decode
├── pwm_controller.v     # PWM peripheral (counter + comparator)
├── imem.v               # instruction memory (loads memfile.dat)
└── docs/
    ├── design_report.md      # Document 2
    ├── test_report.md        # Document 3
    └── waveform_profile.png  # captured motor-profile waveform
```

## Supported instruction set

`add`, `sub`, `and`, `or`, `slt`, `addi`, `lw`, `sw`, `beq`, `j`
(the standard Harris & Harris pipelined-MIPS subset). The motor-control program
uses only `addi`, `add`, `sub`, `sw`, `beq`, and `j`.

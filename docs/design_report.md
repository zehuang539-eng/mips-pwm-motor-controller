# Design Report — MIPS PWM Motor Controller

## 1. Introduction

This project integrates three things built during the semester into one working
embedded system: a **5-stage pipelined MIPS CPU**, a **Memory-Mapped I/O (MMIO)**
bridge, and a **PWM controller**. Software running on the CPU writes an 8-bit duty
value through MMIO; the PWM hardware turns that value into a square wave whose
average power tracks the duty cycle — exactly how a real motor's speed is
controlled. It matters because it is a complete, end-to-end software→hardware
path: an ordinary `sw` instruction reaches out of the core and changes a physical
output.

## 2. System architecture

```
        FETCH        DECODE          EXECUTE        MEMORY         WRITEBACK
      +-------+    +----------+    +-----------+   +----------+   +-----------+
 pc ->| imem  |--->| regfile  |--->| forward + |-->|  data    |-->| result    |
      | +PC   |    | sign-ext |    |   ALU     |   |  memory  |   |  mux ->rf |
      +-------+    | branch=? |    +-----------+   |  (MMIO)  |   +-----------+
                   +----------+                    +----+-----+
                        ^   early branch                |  pwm_duty / pwm_enable
                        |   resolution                  v
                   hazard unit  <----------------  +------------------+
                   (stall/forward)                 |  PWM controller  |--> pwm_out
                                                   +------------------+
```

| Module             | Job (one sentence)                                                        |
|--------------------|---------------------------------------------------------------------------|
| `mips.v`           | Top level: wires the CPU core to instruction memory, data memory, and PWM. |
| `datapath.v`       | The 5-stage pipeline (registers, regfile, ALU muxes, forwarding paths).    |
| `controller.v`     | Decodes opcode/funct into datapath control signals.                       |
| `hazard.v`         | Computes forwarding selects and stall/flush signals.                       |
| `alu.v`            | Performs add/sub/and/or/slt.                                              |
| `data_memory.v`    | RAM plus MMIO address decode for switches / PWM duty / PWM enable.        |
| `pwm_controller.v` | 8-bit counter + comparator producing `pwm_out`.                           |
| `imem.v`           | Instruction memory, initialized from `memfile.dat`.                       |

The pipeline keeps itself correct under dependencies with three mechanisms:
**early branch resolution** (the branch decision is made in DECODE, giving a
1-cycle penalty instead of 3), **data forwarding** (MEM/WB results are routed back
into the ALU inputs), and a **hazard unit** that inserts a one-cycle stall for
load-use dependencies and for branches whose operands are not yet available.

## 3. MMIO design

Address map (same as the README):

| Address  | Device      | Direction  |
|----------|-------------|------------|
| `0x0090` | switches    | read-only  |
| `0x0098` | PWM duty    | write-only |
| `0x009C` | PWM enable  | write-only |
| other    | RAM         | read/write |

`data_memory.v` decodes the address with a `case` statement. On a store
(`we = 1`) the address selects which register or RAM word is updated; on a load
the address selects which value is returned.

**Why writes are synchronous and reads are combinational.** A store result is
produced by the pipeline in the MEM stage; latching it on the clock edge gives the
peripheral registers (`pwm_duty`, `pwm_enable`) a clean, glitch-free update that is
naturally aligned with the rest of the pipeline. A load, however, must deliver its
data *within* the same MEM cycle so the value can flow into WB on the next edge —
making the read path combinational avoids inserting an extra stall on every load.

## 4. PWM controller design

The controller is a textbook **counter + comparator**:

- An 8-bit counter free-runs `0 → 255` (and wraps) while `enable = 1`.
- The comparator drives `pwm_out = (counter < duty_cycle)`.

So within each 256-tick period the output is high for `duty_cycle` ticks, i.e. the
**high-time fraction = `duty_cycle / 256`**. Writing a larger duty widens the
pulse and raises the average power delivered to the motor.

**Frequency.** One full period is 256 counter ticks, so

```
T_pwm = 256 × T_clk
```

With the testbench's 10 ns clock, `T_pwm = 256 × 10 ns = 2.56 µs` (≈ 390 kHz).
On a 50 MHz board (`T_clk = 20 ns`) it would be `5.12 µs` (≈ 195 kHz).

When `enable = 0` the counter is held at 0 and `pwm_out` is forced low, so the
motor is off regardless of the last duty value.

## 5. Software algorithm

**Profile chosen: Option A — ramp up → hold at max → ramp down → hold at zero →
repeat.** It is the most direct way to *demonstrably* exercise the duty register
across its whole range, so the waveform clearly proves the software→hardware path
works.

Register usage:

| Reg  | Meaning                    |
|------|----------------------------|
| `$t0`| current duty value         |
| `$t1`| MMIO duty address `0x98`   |
| `$t2`| MMIO enable address `0x9C` |
| `$t3`| `PEAK` (max duty = 64)     |
| `$t4`| step (= 1)                 |
| `$t5`| delay / hold counter       |
| `$t6`| constant 1                 |

Pseudocode:

```
enable PWM (sw 1 -> 0x9C)
PEAK = 64 ; STEP = 1
loop forever:
    duty = 0
    while duty != PEAK:        # ramp up
        write duty -> 0x98
        delay(DELAY)
        duty = duty + STEP
    write PEAK -> 0x98         # hold at max
    delay(HOLD)
    while duty != 0:           # ramp down
        duty = duty - STEP
        write duty -> 0x98
        delay(DELAY)
    delay(HOLD)                # hold at zero
```

Annotated assembly (this is what `memfile.dat` encodes; addresses are byte
addresses):

```
0x00  addi $t2,$zero,0x9C     # $t2 = enable address
0x04  addi $t6,$zero,1        # $t6 = 1
0x08  sw   $t6,0($t2)         # PWM enable = 1
0x0C  addi $t1,$zero,0x98     # $t1 = duty address
0x10  addi $t3,$zero,64       # $t3 = PEAK
0x14  addi $t4,$zero,1        # $t4 = STEP
0x18  addi $t0,$zero,0        # duty = 0                (cycle start)
# ---- ramp up ----
0x1C  sw   $t0,0($t1)         # write duty
0x20  addi $t5,$zero,100      # DELAY
0x24  addi $t5,$t5,-1         #   delay loop
0x28  beq  $t5,$zero,0x30
0x2C  j    0x24
0x30  add  $t0,$t0,$t4        # duty++
0x34  beq  $t0,$t3,0x3C       # duty == PEAK ? -> hold at max
0x38  j    0x1C               # else keep ramping up
# ---- hold at max ----
0x3C  sw   $t0,0($t1)         # write PEAK
0x40  addi $t5,$zero,400      # HOLD
0x44  addi $t5,$t5,-1
0x48  beq  $t5,$zero,0x50
0x4C  j    0x44
# ---- ramp down ----
0x50  sub  $t0,$t0,$t4        # duty--
0x54  sw   $t0,0($t1)         # write duty
0x58  addi $t5,$zero,100      # DELAY
0x5C  addi $t5,$t5,-1
0x60  beq  $t5,$zero,0x68
0x64  j    0x5C
0x68  beq  $t0,$zero,0x70     # duty == 0 ? -> hold at zero
0x6C  j    0x50               # else keep ramping down
# ---- hold at zero ----
0x70  sw   $t0,0($t1)         # write 0 (motor off)
0x74  addi $t5,$zero,400      # HOLD
0x78  addi $t5,$t5,-1
0x7C  beq  $t5,$zero,0x84
0x80  j    0x78
0x84  j    0x18               # repeat whole cycle
```

**Tunable constants:**
- **Peak duty** — `0x10 addi $t3,$zero,64`: change `64` (e.g. `255` for full range).
- **Ramp speed** — the two `addi $t5,$zero,100` delays: larger = slower ramp.
- **Hold time** — the two `addi $t5,$zero,400` delays: larger = longer holds.

**Why the delay loop produces the rate it wants.** Each delay iteration executes
`addi; beq; j` (the `beq` falls through, the `j` repeats) ≈ 3–4 clock cycles, so a
count of `N` holds each duty value for roughly `4N` cycles. With `N = 100` that is
~400 cycles, i.e. more than one full `256`-cycle PWM period, so every duty value is
held long enough for at least one complete PWM period to be visible before the next
step.

## 6. Reflection

**Harder than expected.** Getting the *branch* right in a pipeline was the subtle
part. Because the branch is resolved early (in DECODE), a `beq` that depends on the
immediately preceding `addi` (e.g. `addi $t5,-1` then `beq $t5,$zero,...`) needs its
operand *before* the ALU result exists. The hazard unit handles this by stalling
one cycle and then forwarding the result from the MEM stage into the DECODE
comparator (`forwardAD`/`forwardBD`). Tracing exactly which cycle the value becomes
available — and convincing myself the single stall was both necessary and
sufficient — took the most thought.

**With more time.** I would add `bne` to the instruction set (the loops would read
more naturally as `bne $t5,$zero,delay` than the `beq`+`j` pair used here), and I
would implement Option C (a sine lookup table) for a smoother "breathing" profile.

# Deterministic Dual-Channel RC Servo Controller

This repository contains a TinyTapeout-ready digital ASIC design for a deterministic dual-channel RC servo command controller. It targets logic-level control of external RC servos and is intended to be used with an off-chip servo power supply and the servo's native motor-control loop.

Project title:
Deterministic Dual-Channel RC Servo Controller

## What it does

- Generates two logic-level PWM-like servo command outputs
- Uses frame-synchronous updates so both channels change together
- Enforces configurable minimum and maximum pulse width limits
- Implements an explicit enable sequence
- Monitors host activity with a watchdog
- Exposes readable fault status bits for debugging and validation

## Intended use

- Servo power, mechanical assembly, and feedback remain external
- The ASIC produces only digital control pulses for an external RC servo driver stage
- The design is suitable for TinyTapeout prototyping and verification in a small FPGA or ASIC test flow

## Repository structure

- `src/servo_dual_controller.v` - core RTL for the deterministic dual-channel controller
- `src/tt_um_dual_servo_controller.v` - TinyTapeout wrapper module
- `test/tb_servo_dual_controller.v` - Verilog testbench for pulse generation and watchdog behavior
- `docs/design_spec.md` - design specification and register map
- `info.yaml` - TinyTapeout metadata

## Core timing assumptions

- 20 ms frame cadence per standard RC servo timing
- Pulse width range is configurable in microseconds
- Default nominal pulse range is 500 us to 2500 us
- Frame updates are atomic at the 20 ms boundary

## Quick start

To run the RTL simulation with Icarus Verilog:

```bash
iverilog -g2012 -Wall -o sim.out test/tb_servo_dual_controller.v src/servo_dual_controller.v
vvp sim.out
```

## Design notes

This project is intentionally deterministic and easy to reason about:

- Pulse generation is based on a microsecond tick counter
- Position commands are latched in a shadow register and applied at the next frame boundary
- Faults are sticky until reset or explicit host re-enable
- The watchdog prevents indefinite stale command states during host stalls

## License

This project is released under the MIT license.

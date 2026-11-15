# Deterministic Dual-Channel RC Servo Controller

## 1. Objective

The goal is a compact digital controller that emits two RC servo command waveforms with deterministic timing and a clear host interface. The controller creates logic-level pulse trains only; power delivery, motor control, and servo feedback remain external to the ASIC.

## 2. Functional requirements

### 2.1 Pulse generation

- Channel 0 output: `servo0_pulse`
- Channel 1 output: `servo1_pulse`
- Output period: 20 ms nominal frame period
- Pulse widths are configurable in microseconds
- Default legal pulse range: 500 us to 2500 us
- Pulse widths are clamped to configured min/max bounds

### 2.2 Frame-synchronous updates

- The host provides a desired pulse width for each channel
- Updates are loaded into a shadow register
- The active pulse widths are applied atomically at the next frame boundary
- This guarantees both servo channels change at the same time

### 2.3 Enable sequence

The controller requires an explicit enable path to avoid accidental motion:

- `enable_req` bit requests enable
- `enable` becomes active only after host acknowledgement and a valid command state
- `fault_status` disables the output and requires reset or re-arming before motion resumes

### 2.4 Watchdog behavior

- Host bus activity resets a watchdog counter
- If no valid host activity is observed for a configurable timeout, the controller enters a fault state
- In watchdog fault mode, both outputs are forced low
- The host may clear the fault by re-enabling after a clean reset or re-arming sequence

### 2.5 Fault status

Read-only status bits include:

- `fault_watchdog`
- `fault_overrange`
- `fault_disabled`
- `fault_active`

## 3. Register map

The controller exposes a simple byte-addressed register map.

| Address | Name | Description |
| --- | --- | --- |
| 0x00 | CTRL | `enable`, `apply`, `reset_fault` |
| 0x01 | STATUS | Read back output state and fault flags |
| 0x02 | CH0_CMD_L | Lower byte of channel 0 target pulse width |
| 0x03 | CH0_CMD_H | Upper byte of channel 0 target pulse width |
| 0x04 | CH1_CMD_L | Lower byte of channel 1 target pulse width |
| 0x05 | CH1_CMD_H | Upper byte of channel 1 target pulse width |
| 0x06 | MIN_PULSE_L | Lower byte of minimum pulse width |
| 0x07 | MIN_PULSE_H | Upper byte of minimum pulse width |
| 0x08 | MAX_PULSE_L | Lower byte of maximum pulse width |
| 0x09 | MAX_PULSE_H | Upper byte of maximum pulse width |
| 0x0A | WATCHDOG_L | Lower byte of watchdog timeout |
| 0x0B | WATCHDOG_H | Upper byte of watchdog timeout |
| 0x0C | FAULTS | Latched fault register |

## 4. Timing model

- Reference clock: 100 MHz in the example RTL
- One microsecond tick is derived from a 100-cycle counter
- Frame: 20,000 us (20 ms)
- Command pulse widths are in microseconds and are applied over the next full frame period
- Atomic update time: the final microsecond in the current frame

## 5. Safety logic

- Values are clamped before application: `min <= width <= max`
- If the host writes out-of-range values, they are clipped to the configured range
- Watchdog faults and invalid command values latch until reset
- When disabled, both pulse outputs remain low

## 6. Verification strategy

The included testbench checks:

- start-up disabled state
- channel pulses appear at expected widths
- both channels are updated synchronously
- watchdog timeout drives `fault_watchdog`
- re-enable clears the fault state after a host re-arming sequence

## 7. TinyTapeout considerations

This design is suitable for TinyTapeout because it uses a small, register-driven control interface and a narrow output footprint. The wrapper exposes:

- two servo outputs
- a compact control bus
- fixed-status outputs for debug and validation

The project is intentionally hardware-focused, simple to synthesize, and deterministic under repeated timing runs.

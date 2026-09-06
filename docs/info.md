<!---
This documentation is used on the Tiny Tapeout website.
-->

## How it works

This chip is a 4-Core 1.58-Bit (Ternary) Neural Processing Unit (NPU) accelerator inspired by the BitNet b1.58 architecture.

Instead of heavy floating-point multipliers, it processes ternary weights {-1, 0, +1} using pure hardware addition and subtraction:
- Weight +1: Adds the input activation.
- Weight -1: Subtracts the input activation.
- Weight  0: Skips computation (zero dynamic switching power).

The design includes:
1. 8-bit bit-packing (4 trits per byte).
2. Autonomous FSM controller with START/DONE handshaking.
3. Hardware ReLU activation units.

## How to test

1. Apply clock to `clk` and release reset `rst_n` (set to 1).
2. Set `ui_in[0] = 1` to pulse START.
3. Wait for `uio_out[0]` (DONE flag) to go high.
4. Select which neuron output to view on `uo_out[7:0]` using `ui_in[2:1]`:
   - `00`: Neuron 0 (Outputs 0)
   - `01`: Neuron 1 (Outputs 69 - PyTorch match)
   - `10`: Neuron 2 (Outputs 54)
   - `11`: Neuron 3 (Outputs 0)

## External hardware

No external hardware needed. Built-in inputs stream internally.

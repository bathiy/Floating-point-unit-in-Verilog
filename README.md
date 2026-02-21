# Floating Point Unit (FPU) – Combinational Logic Design

## Project Overview

This project implements a Floating Point Unit (FPU) using pure combinational logic.  
The design performs IEEE 754 single-precision (32-bit) floating-point operations without using sequential elements such as registers or clocked logic.

The implementation focuses on understanding floating-point arithmetic at the hardware level, including exponent alignment, mantissa operations, normalization, and rounding.

---

## Design Specifications

- Standard: IEEE 754 Single Precision (32-bit)
- Architecture: Pure Combinational Logic
- Clock: Not required (fully combinational)
- Input Width: 32 bits per operand
- Output Width: 32 bits

### IEEE 754 Single Precision Format

| Field | Bits | Description |
|-------|------|-------------|
| Sign | 1 bit | Determines positive or negative number |
| Exponent | 8 bits | Biased exponent (Bias = 127) |
| Mantissa | 23 bits | Fractional part (with implicit leading 1) |

---

## Supported Operation

### Floating Point Addition

The FPU performs floating-point addition using the following steps:

1. Extract sign, exponent, and mantissa
2. Compare exponents
3. Align mantissas (shift smaller exponent)
4. Perform mantissa addition/subtraction
5. Normalize the result
6. Adjust exponent
7. Produce final IEEE 754 formatted output

---

## Architectural Blocks

The FPU is divided into the following combinational blocks:

- Sign Extraction Unit
- Exponent Comparator
- Mantissa Alignment Shifter
- Mantissa Adder/Subtractor
- Normalization Unit
- Exponent Adjustment Logic
- Output Packing Unit

Each block is implemented using combinational operators and logic structures only.

---

## Design Characteristics

- Fully combinational (no clock dependency)
- Deterministic propagation delay
- Educational implementation for understanding FPU internals
- Suitable for integration into a processor datapath

---

## Limitations

- No pipelining
- No sequential optimization
- Does not handle:
  - NaN
  - Infinity
  - Denormalized numbers
  - Rounding modes (if not implemented)

This implementation is primarily intended for learning and architectural exploration.

---

## Possible Extensions

- Add multiplication and division
- Implement IEEE 754 rounding modes
- Add support for special cases (NaN, Infinity)
- Convert to pipelined architecture
- Parameterize for double precision (64-bit)

---

## Learning Outcomes

This project demonstrates:

- Hardware-level floating point arithmetic
- IEEE 754 representation
- Mantissa normalization techniques
- Combinational digital design methodology
- Datapath design principles

---

## Author

Designed as part of digital design and computer architecture studies.

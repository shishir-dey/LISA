<div align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/LISA-logo-dark.png" width="640">
  <source media="(prefers-color-scheme: light)" srcset="assets/LISA-logo-light.png" width="640">
  <img alt="LISA logo" src="assets/LISA-logo-light.png" width="640">
</picture>
</div>

LISA (inspired by LLVM ISA) is a small synthesizable processor whose architectural instruction stream is a simplified LLVM-like bytecode format.

## Directory Layout

- `run.sh`: command-line runner for local checks/build/simulation and CI
- `synth/synth.ys`: Yosys synthesis script for the top module
- `synth/reports/`: synthesis netlist and logs
- `rtl/lisa_defs.vh`: shared opcode/uop constants
- `rtl/lisa_imem.v`: byte-addressable instruction memory with fetch window
- `rtl/lisa_fetch_unit.v`: variable-length instruction fetch helper
- `rtl/lisa_decoder.v`: decodes opcodes, operands, immediate fields, branch targets, PHI tags
- `rtl/lisa_ssa_regfile.v`: fixed-size SSA ID -> register storage
- `rtl/lisa_int_alu.v`: integer `add/sub/mul`
- `rtl/lisa_lsu.v`: load/store unit glue
- `rtl/lisa_data_mem.v`: byte-addressable little-endian data memory
- `rtl/lisa_control_flow_unit.v`: branch/jump/return next-PC logic
- `rtl/lisa_bytecode_core.v`: top-level FSM (`fetch -> decode -> execute -> writeback`)
- `tb/tb_lisa_bytecode_core.v`: self-checking example testbench

## Simplified Bytecode Encoding

All instructions start with:

- byte 0: opcode
- byte 1: instruction length (bytes)

Supported instructions:

- `iconst`: `[01][07][dest][imm0][imm1][imm2][imm3]`
- `add`: `[02][05][dest][srcA][srcB]`
- `sub`: `[03][05][dest][srcA][srcB]`
- `mul`: `[04][05][dest][srcA][srcB]`
- `load`: `[05][04][dest][addrSSA]`
- `store`: `[06][04][dataSSA][addrSSA]`
- `br`: `[07][09][condSSA][tLo][tHi][fLo][fHi][tagT][tagF]`
- `jmp`: `[08][05][targetLo][targetHi][tag]`
- `ret`: `[09][03][srcSSA]`
- `phi`: `[0A][07][dest][srcA][srcB][tagA][tagB]`
- `halt`: `[FF][02]`

## LLVM Concept Mapping

- LLVM SSA value IDs map directly to entries in the SSA register file (`rtl/lisa_ssa_regfile.v`).
- `phi` uses a predecessor-edge tag (`pred_tag`) updated by branch/jump instructions.
- Control flow is modeled with explicit bytecode targets and tags.
- Memory operations use a byte-addressable data memory and 32-bit little-endian loads/stores.

## Running from the Command Line

```bash
chmod +x run.sh
./run.sh check
./run.sh sim
./run.sh synth
```

Expected test result:

- return value = `100`
- data memory at address `0x0010` = `12`

Useful commands:

- `./run.sh lint`: Verilator lint
- `./run.sh check`: Yosys structural RTL check
- `./run.sh build`: build simulation binary
- `./run.sh sim`: build + run testbench
- `./run.sh synth`: run Yosys synthesis (`synth/synth.ys`)
- `./run.sh ci`: CI entrypoint (`lint` + `check` + `sim` + `synth`)
- `./run.sh clean`: remove simulation artifact

Synthesis artifacts:

- Netlist: `synth/reports/lisa_bytecode_core_synth.v`
- Log: `synth/reports/synthesis.log`

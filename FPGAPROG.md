

## 🟢 Open Source Toolchain (Recommended for macOS)

---

This is the fully open-source path, currently recommended by the [F4PGA (Chip's Alliance) Inniciative](https://f4pga.org/), and it works well on macOS.

### Synthesis: **Yosys**
The de facto open-source synthesis tool. Takes Verilog (or VHDL via the GHDL plugin) and produces a netlist. Install via Homebrew: `brew install yosys`.

### Place & Route: **nextpnr-xilinx** (via openXC7)
The openXC7 project provides a free and open-source FPGA toolchain for AMD/Xilinx Series 7 chips, supporting Spartan-7, Artix-7, Zynq-7, and Kintex-7. It uses `nextpnr` as the place-and-route engine.

### Bitstream: **Project X-Ray / prjxray**
Handles the bitstream generation for Xilinx 7-series. It's included as part of the openXC7 toolchain.

### Installing on macOS:
For macOS, the recommended approach is the Nix-based toolchain installer at `github.com/openXC7/toolchain-nix`, which also includes the GHDL plugin for VHDL support.

### Programming (flashing): **openFPGALoader**
openFPGALoader is a universal utility for programming FPGAs, compatible with many boards and cables from major manufacturers including Xilinx. It works on Linux, Windows, and macOS. It has explicit Arty board support:

```bash
openFPGALoader -b arty arty_bitstream.bit       # SRAM (volatile)
openFPGALoader -b arty -f arty_bitstream.bit    # Flash (persistent)
```

Install via Homebrew: `brew install openfpgaloader`.

### Full open-source flow summary:
```
Verilog/VHDL → Yosys (synth) → nextpnr-xilinx (P&R) → prjxray (bitstream) → openFPGALoader (program)
```

---
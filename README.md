# Project Vajra: 32-bit Custom RISC-V Core (Sky130)

![Build Status](https://img.shields.io/badge/Status-Silicon_Ready-success)
![PDK](https://img.shields.io/badge/PDK-SkyWater_130nm-blue)
![Flow](https://img.shields.io/badge/Physical_Design-OpenLane%20%7C%20OpenROAD-orange)

Project Vajra is a custom-designed, 32-bit, 5-stage pipelined RISC-V microprocessor architecture. It has been successfully synthesized, floorplanned, and routed down to the physical GDSII layout using the open-source OpenLane/OpenROAD ASIC flow and the SkyWater 130nm High-Density (HD) Process Design Kit.



## 🧠 Architectural Overview

At its core, Vajra implements the RV32I base integer instruction set. It is built for deterministic edge-compute and hardware extensibility.

* **Pipeline:** 5-Stage (Fetch, Decode, Execute, Memory, Writeback)
* **Hazard Management:** Full data forwarding and stalling hazard unit to prevent data corruption during deep pipeline execution.
* **System Bus:** Integrated **AXI4-Lite Master Interface** for seamless drop-in compatibility with System-on-Chip (SoC) wrappers like the Efabless Caravel harness.
* **Math Unit:** Optimized Wallace Tree Multiplier for fast partial product compression.



## 🏭 Physical Design & Silicon Specs

The RTL was pushed through the complete OpenLane RTL-to-GDSII flow, resolving complex synthesis pruning issues to achieve a fully routed, manufacturable layout.

* **Technology Node:** SkyWater 130nm (`sky130_fd_sc_hd` library)
* **Standard Cell Count:** 15,018 active logic cells
* **Target Clock Frequency:** 50 MHz (20ns period)
* **Routing:** TritonRoute (Step 17) fully completed with 0 DRC violations.
* **Current Status:** FPGA Prototyping (Intel Cyclone V / DE1-SoC)

<img width="1920" height="1080" alt="Screenshot (79)" src="https://github.com/user-attachments/assets/67bbf626-9b56-45b2-9b79-ff6f655e2593" />
<img width="1920" height="1080" alt="Screenshot (81)" src="https://github.com/user-attachments/assets/21dd2545-4915-4ae2-bd97-e61e16e4a5e0" />

##🚀 Future Roadmap: Sim2Real AI Robotics
Project Vajra is currently being evolved to serve as the bare-metal processing brain for an open-source, AI-driven robotic system. Future commits will include:

Hardware AI Accelerator: A custom INT8 Systolic Array MAC unit attached to the AXI bus for edge neural network inference.

Deterministic Motor Control: Hardware-level PWM generation for zero-jitter multi-axis joint manipulation.

👨‍💻 Author
Nirnay Rana 2nd-Year Electronics & Telecommunications Engineering Student | SGSITS www.linkedin.com/in/nirnay-rana-35a663204 | nirnay.rana1646@gmail.com


## 📂 Repository Structure

```text
├── /
│   └── src/                  # All Core Verilog files (riscv_pipeline_top.v, etc.)
│__    config.json           # OpenLane physical design constraints & die area
├── gds/
│   └── vajra_caravel_soc.gds # Final routed microscopic silicon layout
├── docs/                     # KLayout screenshots, STA timing reports, and waveforms
└── README.md



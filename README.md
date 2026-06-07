## 🛠️ Getting Started & Simulation Runbook

To ensure reproducibility and ease of verification, follow the instructions below to compile and run the timing simulation in **Model Technology ModelSim**.

### Step 1: Clone the Repository
Clone the project to your local machine using Git:
```bash
git https://github.com/mkokoszk/8x8_Arrow_Recognition.git
```
*(Ensure the directory structure is maintained: core design files in the `src/` directory and the testbench in the `sim/` directory).*

### Step 2: Navigate to the Workspace
1. Launch the **ModelSim** software.
2. In the bottom **Transcript** console, navigate to the root directory of the cloned repository using the `cd` command:
```tcl
cd C:/path/to/your/cloned/repository
```

### Step 3: Compile Source Files
Create the working library and compile the VHDL design files in a strict architectural sequence (the weights package must be compiled first). Run the following commands in the Transcript console:
```tcl
vlib work
vcom src/wagi_mlp_pkg.vhd
vcom src/rozpoznawanie_strzalek.vhd
vcom sim/tb_strzalki.vhd
```
*A successful compilation will yield an `Errors: 0` message for each module.*

### Step 4: Run the Simulation
Initialize the simulator with full signal visibility enabled (`+acc` flag):
```tcl
vsim -voptargs="+acc" work.tb_strzalki
```
Next, load all signals into the Wave window and run the simulation for a predefined time (e.g., 2000 ns):
```tcl
add wave -r /*
run 12000 ns
wave zoom full
```

### Expected Output
Once the simulation completed. The Wave window will display the timing waveforms, demonstrating the `cmd_valid` flag asserting and the correct output command being locked on the bus (`cmd_out`).

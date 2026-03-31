# Makefile for RISC-V CPU Project
# Supports Verilog simulation and synthesis

# Project settings
PROJECT = riscv_cpu
TOP_MODULE = cpu
SRC_DIR = src
BUILD_DIR = build
TEST_DIR = test

# Source files
VERILOG_SOURCES = $(SRC_DIR)/cpu.v

# Tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave
VERILATOR = verilator
YOSYS = yosys

# Flags
IVERILOG_FLAGS = -g2012 -Wall
VERILATOR_FLAGS = --cc --exe --build -Wall -Wno-fatal
YOSYS_FLAGS = -q

# Default target
.PHONY: all
all: help

# Help target
.PHONY: help
help:
	@echo "RISC-V CPU Makefile"
	@echo "==================="
	@echo ""
	@echo "Available targets:"
	@echo "  clean       - Remove build artifacts"
	@echo "  check       - Check Verilog syntax"
	@echo "  lint        - Run linter on Verilog sources"
	@echo "  sim         - Run simulation (requires testbench)"
	@echo "  synth       - Synthesize design with Yosys"
	@echo "  verilate    - Generate C++ model with Verilator"
	@echo "  help        - Show this help message"
	@echo ""

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Check Verilog syntax
.PHONY: check
check: $(VERILOG_SOURCES)
	@echo "Checking Verilog syntax..."
	@$(IVERILOG) $(IVERILOG_FLAGS) -tnull -o /dev/null $(VERILOG_SOURCES)
	@echo "Syntax check passed!"

# Lint with Verilator
.PHONY: lint
lint: $(VERILOG_SOURCES)
	@echo "Running Verilator lint..."
	@$(VERILATOR) --lint-only -Wall $(VERILOG_SOURCES)
	@echo "Lint check passed!"

# Simulation (requires testbench)
.PHONY: sim
sim: $(BUILD_DIR)
	@if [ -f $(TEST_DIR)/testbench.v ]; then \
		echo "Running simulation..."; \
		$(IVERILOG) $(IVERILOG_FLAGS) -o $(BUILD_DIR)/$(PROJECT).vvp \
			$(VERILOG_SOURCES) $(TEST_DIR)/testbench.v; \
		$(VVP) $(BUILD_DIR)/$(PROJECT).vvp; \
	else \
		echo "Error: Testbench not found at $(TEST_DIR)/testbench.v"; \
		exit 1; \
	fi

# View waveform (requires .vcd file)
.PHONY: wave
wave:
	@if [ -f $(BUILD_DIR)/$(PROJECT).vcd ]; then \
		$(GTKWAVE) $(BUILD_DIR)/$(PROJECT).vcd; \
	else \
		echo "Error: Waveform file not found at $(BUILD_DIR)/$(PROJECT).vcd"; \
		echo "Run 'make sim' first to generate waveform"; \
		exit 1; \
	fi

# Synthesize with Yosys
.PHONY: synth
synth: $(BUILD_DIR)
	@echo "Synthesizing design..."
	@echo "read_verilog $(VERILOG_SOURCES)" > $(BUILD_DIR)/synth.ys
	@echo "hierarchy -check -top $(TOP_MODULE)" >> $(BUILD_DIR)/synth.ys
	@echo "proc; opt; fsm; opt; memory; opt" >> $(BUILD_DIR)/synth.ys
	@echo "techmap; opt" >> $(BUILD_DIR)/synth.ys
	@echo "stat" >> $(BUILD_DIR)/synth.ys
	@echo "write_verilog $(BUILD_DIR)/$(PROJECT)_synth.v" >> $(BUILD_DIR)/synth.ys
	@$(YOSYS) $(YOSYS_FLAGS) -s $(BUILD_DIR)/synth.ys
	@echo "Synthesis complete! Output: $(BUILD_DIR)/$(PROJECT)_synth.v"

# Verilate (generate C++ model)
.PHONY: verilate
verilate: $(BUILD_DIR)
	@echo "Running Verilator..."
	@$(VERILATOR) --cc $(VERILOG_SOURCES) --top-module $(TOP_MODULE) -Mdir $(BUILD_DIR)/verilator
	@echo "Verilator model generated in $(BUILD_DIR)/verilator/"

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -f *.vcd *.vvp *.out
	@echo "Clean complete!"

# Info target
.PHONY: info
info:
	@echo "Project Information"
	@echo "==================="
	@echo "Project name: $(PROJECT)"
	@echo "Top module:   $(TOP_MODULE)"
	@echo "Source dir:   $(SRC_DIR)"
	@echo "Build dir:    $(BUILD_DIR)"
	@echo ""
	@echo "Source files:"
	@for file in $(VERILOG_SOURCES); do \
		echo "  - $$file"; \
	done

.PHONY: stats
stats:
	@echo "Code Statistics"
	@echo "==============="
	@echo "Lines of code:"
	@wc -l $(VERILOG_SOURCES)
	@echo ""
	@echo "Module summary:"
	@grep -h "^module" $(VERILOG_SOURCES) || true

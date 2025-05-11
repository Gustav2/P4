#!/bin/bash
# Clean up previous compilation files
rm -f work-obj93.cf
rm -f work-obj08.cf
rm -f *.vcd

# First, compile all the necessary files in the correct order
echo "Compiling VHDL files..."

# Constants package must be compiled first
ghdl -a constants.vhd

# Other modules in dependency order
ghdl -a pll_200mhz.vhd
ghdl -a circular_buffer.vhd
ghdl -a serial_transmit.vhd
ghdl -a spi.vhd
ghdl -a top.vhd

# Testbench files
ghdl -a spi_tb.vhd

# Elaborate the testbench
echo "Elaborating testbench..."
ghdl -e spi_tb

# Run the simulation
echo "Running simulation..."
ghdl -r spi_tb --vcd=spi_simulation.vcd --stop-time=10us

# Open the waveform viewer if display is available
if [ -n "$DISPLAY" ]; then
    echo "Opening GTKWave..."
    gtkwave setup.gtkw > /dev/null 2>&1 &
fi

echo "Simulation completed."

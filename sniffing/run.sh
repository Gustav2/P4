#!/bin/bash
rm -f work-obj93.cf
rm -f work-obj08.cf
rm -f *.vcd

ghdl -a spi.vhd
ghdl -a spi_tb.vhd

ghdl -e spi_tb

# Run
ghdl -r spi_tb --vcd=spi_simulation.vcd 

if [ -n "$DISPLAY" ]; then
    gtkwave setup.gtkw > /dev/null 2>&1 &
fi

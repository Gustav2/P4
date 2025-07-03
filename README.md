

# FPGA-Based SPI Sniffer

This project implements an **FPGA-based SPI Sniffer** using the **CYC1000 development board** (Intel Cyclone 10 FPGA). The board captures SPI traffic and streams it over UART to the host computer. A custom **Wireshark external capture plugin (C++)** allows protocol inspection directly within Wireshark.

The `wireshark/` folder includes a `Makefile` to build the extcap plugin and install it into Wireshark and adding a custom SPI_Config profile to sort and visualise the daga.


## Overview

* **FPGA Platform:** CYC1000 (Intel Cyclone 10 FPGA)
* **Interface:** SPI input, UART output
* **Host Integration:** Wireshark via C++ extcap

## Requirements

### FPGA Side (CYC1000 Board)

* Intel Quartus Prime Lite (for compiling `top.vhd`)
* USB-Blaster or compatible programmer
* SPI input pins connected to target system
* UART output from CYC1000 (default 12000000 baud (already defined by the custom wireshark extcap))

### Host Side (Linux)

* Wireshark with extcap support
* `make`, `g++` (for building extcap)
* Access to `/dev/ttyUSBx` (CYC1000 UART output)

## Building the FPGA Bitstream

Use **Intel Quartus** to open the VHDL project based on `sniffing/top.vhd`, assign appropriate pins for:

* `MISO`, `MOSI`, `SCK`, `CS`
* `UART_TX`
* `RESET_BUTTON`
* `FPGA_INTERNAL_CLOCK`
* `DEBUG_LEDS (Optional)`

Then compile and flash the bitstream to the CYC1000 board.


## Building and Installing the Wireshark Extcap

1. Go to the `wireshark/` directory:

   ```
   cd wireshark
   ```
2. Build and install the extcap plugin:

   ```
   make install
   ```

```

```

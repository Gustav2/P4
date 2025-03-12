
# Wireshark External Capture Interface for Serial Communication

This **Wireshark External Capture Interface (extcap)** plugin enables you to capture and analyze serial communication in **Wireshark**.

## Installation (Linux Only)

### Build and install the extcap

```bash
cd wireshark_extcap
make all # This will at some point ask for sudo access
```

This will:

    Create a virtual environment.
    Install dependencies from requirements.txt.
    Build the executable with PyInstaller.
    Copy the executable to Wireshark's extcap directory.


## Usage

### 1. Open Wireshark

After installation, open Wireshark.

### 2. Locate the "USB Serial Capture: usb_serial" interface

Scroll through the list of interfaces until you see "USB Serial Capture: usb_serial".

### 3. Configure the settings

To change the settings (like USB device or baud rate), tap the gear icon next to the extcap name. Here, you can select:

    USB Port: Choose the USB device to capture from.
    Baud Rate: Set the baud rate for your serial communication.

### 4. Start capturing serial data

Double click the interface to begin capturing serial data!
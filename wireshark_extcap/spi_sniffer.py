import sys
import time
import glob
import struct
import serial
import argparse

BAUD_RATE = 115200

def list_interfaces():
    """List available extcap interfaces."""
    print("extcap {version=1.0}{help=https://github.com/Gustav2/P4}{display=USB Serial Capture}")
    print("interface {value=usb_serial}{display=USB Serial Capture}")

def list_dlts():
    """List DLTs for the interface."""
    print("dlt {number=147}{name=USER0}{display=User 0}")

def list_arguments():
    """List arguments for extcap."""
    print("arg {number=0}{call=--baud}{display=Baud Rate}{type=integer}{default=115200}")
    print("arg {number=1}{call=--port}{display=USB Port}{type=selector}")

    for i in range(len(get_serial_ports())):
        print("value {arg=1}{value=%s}{display=%s}" % (get_serial_ports()[i], get_serial_ports()[i]))

def get_serial_ports():
    """Detect available USB serial interfaces (e.g., ttyUSB*, ttyACM*)."""

    usb_ports = glob.glob("/dev/ttyUSB*") + glob.glob("/dev/ttyACM*")
    return usb_ports if usb_ports else ["No USB detected"]

def write_pcap_header(output_file):
    """Write the pcap global header to the output file."""
    # Magic number, version major, version minor, timezone, timestamp accuracy, snapshot length, link layer type
    header = struct.pack('<IHHiIII', 
                         0xa1b2c3d4,  # Magic number
                         2, 4,         # Version major, minor
                         0,            # Timezone = GMT
                         0,            # Timestamp accuracy
                         65535,        # Snapshot length
                         147)          # USER0 link layer type
    output_file.write(header)
    output_file.flush()

def capture_data(port, baud, output_file):
    """Capture USB serial data and stream to output_file."""
    try:
        # Write pcap global header first
        write_pcap_header(output_file)
        
        ser = serial.Serial(port, baud, timeout=0.1)
        
        while True:
            data = ser.read(64)  # Read up to 64 bytes
            if data:
                ts_sec = int(time.time())
                ts_usec = int((time.time() - ts_sec) * 1000000)
                
                # Write packet header (timestamp seconds, microseconds, captured length, original length)
                packet_header = struct.pack('<IIII', 
                                           ts_sec,
                                           ts_usec,
                                           len(data),
                                           len(data))
                
                # Write packet header and data
                output_file.write(packet_header)
                output_file.write(data)
                output_file.flush()
    except KeyboardInterrupt:
        pass
    except Exception as e:
        sys.stderr.write(f"Error: {str(e)}\n")
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="USB Serial Extcap")
    
    # Standard extcap options
    parser.add_argument("--extcap-interfaces", action="store_true", help="List available interfaces")
    parser.add_argument("--extcap-dlts", action="store_true", help="List DLTs")
    parser.add_argument("--extcap-interface", help="Interface to use")
    parser.add_argument("--extcap-config", action="store_true", help="List configuration options")
    parser.add_argument("--capture", action="store_true", help="Start capture")
    parser.add_argument("--fifo", help="Pipe for sending data to Wireshark")
    parser.add_argument("--extcap-capture-filter", help="Capture filter")
    
    # Custom options
    parser.add_argument("--port", help="Serial port to use")
    parser.add_argument("--baud", type=int, default=BAUD_RATE, help="Baud rate for serial port")
    
    args = parser.parse_args()
    
    if args.extcap_interfaces:
        list_interfaces()
        sys.exit(0)
        
    if args.extcap_dlts:
        list_dlts()
        sys.exit(0)
        
    if args.extcap_config:
        list_arguments()
        sys.exit(0)
    
    if args.capture:
        if args.fifo:
            try:
                with open(args.fifo, 'wb') as fifo:
                    capture_data(args.port, args.baud, fifo)
            except OSError as e:
                sys.stderr.write(f"Failed to open FIFO: {str(e)}\n")
                sys.exit(1)
        else:
            capture_data(args.port, args.baud, sys.stdout.buffer)
    else:
        # Default behavior if no control option specified
        capture_data(args.port, args.baud, sys.stdout.buffer)
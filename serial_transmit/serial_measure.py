import serial
import time
import matplotlib.pyplot as plt
import glob

def measure_usb_speed(port='/dev/ttyUSB1', baud_rate=12000000, expected_bytes=100000000):
    """
    Measure the speed of USB data transfer from the FPGA.
    
    Args:
        port (str): Serial port ('/dev/ttyUSB1' on Linux)
        baud_rate (int): Baud rate (must match FPGA design)
        expected_bytes (int): Number of bytes expected (must match FPGA design)
    """
    print(f"Opening port {port} at {baud_rate} baud...")
    
    try:
        # Open serial port with a large timeout
        ser = serial.Serial(
            port=port,
            baudrate=baud_rate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.1  # Short timeout for responsive reading
        )
        
        # Clear any existing data
        ser.reset_input_buffer()
        
        # Variables for speed measurement
        bytes_received = 0
        start_time = time.time()
        last_update_time = start_time
        chunk_sizes = []
        timestamps = []
        speeds = []
        errors = 0
        expected_pattern = 0
        
        print(f"Receiving {expected_bytes} bytes of test data...")
        print("Progress: 0%")
        
        # Receive data until we have all expected bytes or timeout
        while bytes_received < expected_bytes:
            # Read a chunk of available data
            data = ser.read(min(ser.in_waiting + 1024, expected_bytes - bytes_received))
            
            if data:
                now = time.time()
                chunk_size = len(data)
                bytes_received += chunk_size
                
                # Check data pattern for errors
                for byte in data:
                    if byte != expected_pattern & 0xFF:
                        errors += 1
                    expected_pattern = (expected_pattern + 1) & 0xFF
                
                # Calculate current speed
                elapsed = now - start_time
                if elapsed > 0:
                    current_speed = bytes_received / elapsed / 1024  # KB/s
                    chunk_sizes.append(chunk_size)
                    timestamps.append(elapsed)
                    speeds.append(current_speed)
                
                # Print progress update every 10% or 1 second
                if bytes_received >= expected_bytes // 10 * (len(speeds) % 10 + 1) or now - last_update_time >= 1:
                    progress = bytes_received / expected_bytes * 100
                    print(f"Progress: {progress:.1f}% ({current_speed:.2f} KB/s)")
                    last_update_time = now
            
            # Small delay to prevent CPU hogging
            time.sleep(0.01)
        
        end_time = time.time()
        total_time = end_time - start_time
        
        # Close the serial port
        ser.close()
        
        # Calculate final statistics
        avg_speed_kbps = bytes_received / total_time / 1024
        avg_speed_bps = bytes_received * 8 / total_time
        
        # Print results
        print("\n--- Results ---")
        print(f"Bytes received: {bytes_received} of {expected_bytes}")
        print(f"Transfer time: {total_time:.2f} seconds")
        print(f"Average speed: {avg_speed_kbps:.2f} KB/s ({avg_speed_bps/1000:.2f} Kbps)")
        print(f"Errors detected: {errors}")
        
        # Plot speed over time
        if len(timestamps) > 1:
            plt.figure(figsize=(10, 6))
            plt.plot(timestamps, speeds, '-b')
            plt.title("USB Transfer Speed over Time")
            plt.xlabel("Time (seconds)")
            plt.ylabel("Speed (KB/s)")
            plt.grid(True)
            plt.tight_layout()
            plt.show()
            
        return bytes_received, total_time, avg_speed_kbps, errors
    
    except serial.SerialException as e:
        print(f"Error: {e}")
        return 0, 0, 0, 0

if __name__ == "__main__":
    import argparse
    usb_ports = glob.glob("/dev/ttyUSB*") + glob.glob("/dev/ttyACM*")
    print(usb_ports)
    
    parser = argparse.ArgumentParser(description='Measure USB data transfer speed from FPGA')
    parser.add_argument('--port', type=str, default='/dev/ttyUSB1', help='Serial port')
    parser.add_argument('--baud', type=int, default=12000000, help='Baud rate')
    parser.add_argument('--bytes', type=int, default=100000000, help='Expected number of bytes')
    
    args = parser.parse_args()
    
    measure_usb_speed(args.port, args.baud, args.bytes)
import serial
import time
import statistics  # For calculating median

# Configuration
PORT = '/dev/ttyUSB2'       # Using ttyUSB3 as requested
BAUD_RATE = 12000000        # 12 Mbps as defined in constants.vhd
PACKET_SIZE = 6             # 48 bits = 6 bytes per packet
RESET_AFTER_PACKETS = 96    # Reset and decode after this many packets

def main():
    try:
        # Open serial port
        ser = serial.Serial(
            port=PORT,
            baudrate=BAUD_RATE,
            timeout=0.1,
            write_timeout=0,
            inter_byte_timeout=None,
            rtscts=False,
            dsrdtr=False,
        )

        print(f"Connected to {PORT} at {BAUD_RATE} baud")

        # Buffers for collecting data
        mosi_bits = []
        packets_received = 0
        cycle_count = 0

        # Variables for frequency calculations
        freq_values = []     # For median calculation
        freq_sum = 0         # For average calculation
        freq_max = 0         # For maximum frequency
        freq_min = float('inf')  # For minimum frequency

        print("Monitoring high-speed SPI traffic... Press Ctrl+C to exit")
        print(f"Will decode after every {RESET_AFTER_PACKETS} packets")

        # Flush any existing data
        ser.reset_input_buffer()

        # Continuously collect packets
        while True:
            # Fast read - grab all available data at once
            available = ser.in_waiting
            if available >= PACKET_SIZE:
                # Read as many complete packets as are available
                packets_to_read = available // PACKET_SIZE
                data = ser.read(packets_to_read * PACKET_SIZE)

                # Process each packet
                for i in range(0, len(data), PACKET_SIZE):
                    if i + PACKET_SIZE <= len(data):
                        packet = data[i:i+PACKET_SIZE]
                        packets_received += 1

                        # Convert to integer (big-endian, MSB first)
                        value = int.from_bytes(packet, byteorder='big')

                        # Extract signals
                        miso = (value >> 47) & 0x1
                        mosi = (value >> 46) & 0x1
                        cs = (value >> 45) & 0x1

                        # Extract frequency (bits 44-32, 13 bits)
                        freq_hz_val = (value >> 32) & 0x1FFF  # 13 bits

                        # Each count equals 2^17 (131,072) Hz as per FPGA design
                        actual_freq_hz = freq_hz_val * 131072
                        freq_mhz = actual_freq_hz / 1000000

                        # Add to frequency list and update statistics
                        freq_values.append(freq_mhz)
                        freq_sum += freq_mhz

                        # Update max and min
                        if freq_mhz > freq_max:
                            freq_max = freq_mhz
                        if freq_mhz < freq_min:
                            freq_min = freq_mhz

                        # Store the MOSI bit
                        mosi_bits.append(mosi)

                        # Calculate current average and median
                        current_avg = freq_sum / len(freq_values)
                        current_median = statistics.median(freq_values) if freq_values else 0

                        # Show hex representation of the packet with all frequency stats
                        hex_data = ' '.join([f"{b:02X}" for b in packet])
                        status = (f"MISO={miso} MOSI={mosi} CS={cs} "
                                 f"Freq={freq_mhz:.2f}MHz "
                                 f"Avg={current_avg:.2f}MHz "
                                 f"Med={current_median:.2f}MHz "
                                 f"Min={freq_min:.2f}MHz "
                                 f"Max={freq_max:.2f}MHz")
                        print(f"Packet #{packets_received}: {hex_data} | {status}")

                        # Check if we've reached 96 packets
                        if packets_received >= RESET_AFTER_PACKETS:
                            # Decode collected MOSI bits to ASCII
                            ascii_message = bits_to_ascii(mosi_bits)

                            # Calculate final statistics
                            avg_freq = freq_sum / len(freq_values) if freq_values else 0
                            median_freq = statistics.median(freq_values) if freq_values else 0

                            cycle_count += 1
                            print(f"\n--- Cycle {cycle_count} Complete ---")
                            print(f"ASCII: {ascii_message}")
                            print(f"Average frequency: {avg_freq:.2f} MHz")
                            print(f"Median frequency: {median_freq:.2f} MHz")
                            print(f"Minimum frequency: {freq_min:.2f} MHz")
                            print(f"Maximum frequency: {freq_max:.2f} MHz")
                            print("--------------------------------")

                            # Reset for next cycle
                            packets_received = 0
                            mosi_bits = []
                            freq_values = []
                            freq_sum = 0
                            freq_max = 0
                            freq_min = float('inf')

    except serial.SerialException as e:
        print(f"Serial port error: {e}")
    except KeyboardInterrupt:
        print("\nExiting program")

        # If we have any bits collected when exiting, show them
        if mosi_bits:
            ascii_message = bits_to_ascii(mosi_bits)
            avg_freq = freq_sum / len(freq_values) if freq_values else 0
            median_freq = statistics.median(freq_values) if freq_values else 0

            print(f"\n--- Partial Data on Exit ---")
            print(f"ASCII: {ascii_message}")
            print(f"Average frequency: {avg_freq:.2f} MHz")
            print(f"Median frequency: {median_freq:.2f} MHz")
            print(f"Minimum frequency: {freq_min:.2f} MHz")
            print(f"Maximum frequency: {freq_max:.2f} MHz")
            print("--------------------------------")

    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print(f"Closed connection to {PORT}")

def bits_to_ascii(bits):
    """Convert a list of bits to ASCII characters"""
    # Ensure we have complete bytes (multiple of 8 bits)
    padded_bits = bits + [0] * (8 - len(bits) % 8 if len(bits) % 8 else 0)

    # Convert bits to bytes - optimized for speed
    bytes_list = []
    for i in range(0, len(padded_bits), 8):
        byte = 0
        for j in range(8):
            if i + j < len(padded_bits):
                byte = (byte << 1) | padded_bits[i + j]
        bytes_list.append(byte)

    # Convert bytes to ASCII
    ascii_chars = []
    for byte in bytes_list:
        # Only include printable ASCII
        if 32 <= byte <= 126:
            ascii_chars.append(chr(byte))
        else:
            ascii_chars.append('.')  # Replace non-printable chars with dot

    return ''.join(ascii_chars)

if __name__ == "__main__":
    main()

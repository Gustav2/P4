import serial
import time

# Configuration
PORT = '/dev/ttyUSB2'       # Serial port
BAUD_RATE = 12000000        # 12 Mbps
PACKET_SIZE = 6             # 48 bits = 6 bytes per packet
TARGET = "SPI TEST1234"     # The message to count
COUNT_GOAL = 1000           # Target count
TIMEOUT = 4.0               # Message timeout in seconds (slightly longer than Arduino's 5s delay)

def main():
    try:
        # Connect to serial port
        print(f"Opening {PORT} at {BAUD_RATE} baud...")
        ser = serial.Serial(PORT, BAUD_RATE, timeout=0.1)
        ser.reset_input_buffer()

        # Statistics
        correct_count = 0
        incorrect_count = 0
        all_bits = []
        message_start_time = None

        print(f"Listening for '{TARGET}' messages...")

        # Main loop
        while correct_count + incorrect_count < COUNT_GOAL:
            # Check for timeout on current message
            if message_start_time and time.time() - message_start_time > TIMEOUT:
                if hasattr(main, 'buffer') and main.buffer:
                    incorrect_count += 1
                    print(f"✗ Message timeout! Received partial: '{main.buffer}'")
                    main.buffer = ''
                message_start_time = None
                all_bits = []

            # Read data if available
            if ser.in_waiting >= PACKET_SIZE:
                # Read a packet
                packet = ser.read(PACKET_SIZE)

                # Start timing when we get the first packet for a message
                if message_start_time is None:
                    message_start_time = time.time()

                # Extract MOSI bit (bit 46)
                for i in range(len(packet) // PACKET_SIZE):
                    offset = i * PACKET_SIZE
                    if offset + PACKET_SIZE <= len(packet):
                        value = int.from_bytes(packet[offset:offset+PACKET_SIZE], byteorder='big')
                        mosi_bit = (value >> 46) & 0x1
                        all_bits.append(mosi_bit)

            # Process bits when we have enough
            while len(all_bits) >= 8:
                # Take 8 bits and convert to a character
                byte_value = 0
                for i in range(8):
                    byte_value = (byte_value << 1) | all_bits[i]

                # Remove the processed bits
                all_bits = all_bits[8:]

                # Convert to ASCII
                char = chr(byte_value) if 32 <= byte_value <= 126 else '.'

                # Add to the current message buffer
                current_buffer = getattr(main, 'buffer', '')
                current_buffer += char
                main.buffer = current_buffer

                # Check if we have our target message
                if TARGET in current_buffer:
                    correct_count += 1
                    print(f"✓ Message {correct_count}: '{current_buffer}'")

                    # Reset buffer and timer after finding a message
                    main.buffer = ''
                    message_start_time = None

                    # Print progress periodically
                    if correct_count % 10 == 0:
                        total = correct_count + incorrect_count
                        print(f"Progress: {correct_count}/{COUNT_GOAL} correct, "
                              f"{incorrect_count} incorrect ({correct_count/total*100:.1f}% success)")

                # Check if buffer is too large without finding our target
                if len(current_buffer) > len(TARGET) * 2:
                    incorrect_count += 1
                    print(f"✗ Invalid message: '{current_buffer}'")
                    main.buffer = ''
                    message_start_time = None

            # Small delay to prevent CPU hogging
            time.sleep(0.01)

        # Final statistics
        total = correct_count + incorrect_count
        success_rate = (correct_count / total * 100) if total > 0 else 0

        print("\n--- Final Results ---")
        print(f"Correct messages: {correct_count}")
        print(f"Incorrect messages: {incorrect_count}")
        print(f"Success rate: {success_rate:.1f}%")

    except serial.SerialException as e:
        print(f"Serial port error: {e}")
    except KeyboardInterrupt:
        # Final statistics if interrupted
        total = correct_count + incorrect_count
        success_rate = (correct_count / total * 100) if total > 0 else 0

        print("\n--- Interrupted Results ---")
        print(f"Correct messages: {correct_count}")
        print(f"Incorrect messages: {incorrect_count}")
        if total > 0:
            print(f"Success rate: {success_rate:.1f}%")
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print(f"Closed connection to {PORT}")

# Initialize the buffer
main.buffer = ''

if __name__ == "__main__":
    main()

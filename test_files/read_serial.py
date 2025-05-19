import serial

port = "/dev/ttyUSB1"
baud = 12000000
buffer_size = 6  # or whatever you're sending

ser = serial.Serial(port, baud, timeout=1)

print(f"Listening on {port} at {baud} baud...")

while True:
    data = ser.read(buffer_size)
    if data:
        print(" ".join(f"{b:02X}" for b in data))
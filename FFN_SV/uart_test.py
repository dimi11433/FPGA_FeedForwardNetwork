import serial
import struct

# Open serial port
ser = serial.Serial('COM3', baudrate=115200, timeout=2)

# BF16 constants
BF16_ONE  = 0x3F80  # 1.0
BF16_ZERO = 0x0000  # 0.0

# Frame: W1 (4 values), W2 (4 values), x (2), b1 (2), b2 (2) = 14 BF16 values = 28 bytes
values = [
    BF16_ONE, BF16_ZERO, BF16_ZERO, BF16_ONE,  # W1 (identity)
    BF16_ONE, BF16_ZERO, BF16_ZERO, BF16_ONE,  # W2 (identity)
    BF16_ONE, BF16_ONE,                          # x
    BF16_ZERO, BF16_ZERO,                        # b1
    BF16_ZERO, BF16_ZERO,                        # b2
]

# Pack as big-endian bytes
frame = b''.join(struct.pack('>H', v) for v in values)
print(f"Sending {len(frame)} bytes: {frame.hex()}")

ser.write(frame)

# Read back result — 2 BF16 output values = 4 bytes
response = ser.read(4)
print(f"Received {len(response)} bytes: {response.hex()}")

if len(response) == 4:
    out0 = struct.unpack('>H', response[0:2])[0]
    out1 = struct.unpack('>H', response[2:4])[0]
    print(f"Output[0] = 0x{out0:04X}")
    print(f"Output[1] = 0x{out1:04X}")
else:
    print("No response — check UART RX/TX or baud rate")

ser.close()
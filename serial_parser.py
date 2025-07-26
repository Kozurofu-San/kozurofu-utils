import serial
import sys
from datetime import datetime
import find_com_port

baudrate = sys.argv[1]

def read_from_serial(port='COM3', baudrate=115200):
    try:
        # Инициализация последовательного порта
        ser = serial.Serial(
            port=port,
            baudrate=baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1  # Таймаут для операций чтения
        )
    except serial.SerialException as e:
        print(f"Read error {port}: {e}")
        sys.exit(1)

    print("\033[95m {}\033[00m" .format("Logger started"))

    try:
        while True:
            # Чтение данных из порта
            try:
                line = ser.readline().decode('utf-8').strip()
                if line:
                    now = datetime.now()
                    current_time = now.strftime("%m/%d/%Y %H:%M:%S:%f")
                    if line.startswith("I:"):
                        print("\033[92m {}\033[00m" .format(current_time + " -- Info:  " + line[2:]))
                    elif line.startswith("W:"):
                        print("\033[93m {}\033[00m" .format(current_time + " -- Warn:  " + line[2:]))
                    elif line.startswith("E:"):
                        print("\033[91m {}\033[00m" .format(current_time + " -- Error: " + line[2:]))
                    else:
                        print(current_time + " --- " + line)
            except UnicodeDecodeError:
                print("Decoding error")
            except serial.SerialException as e:
                print(f"Read error: {e}")
                break

    except KeyboardInterrupt:
        print("\n Closed.")
    finally:
        ser.close()
        print("Port closed")

if __name__ == "__main__":

    com_port, dev, vid, pid = find_com_port.find_com_port()

    if com_port:
        print(f"Serial device {dev} (VID: {hex(vid)} PID: {hex(pid)}) found on port: {com_port}")
    else:
        print(f"Serial device not found.")

    read_from_serial(com_port, baudrate)
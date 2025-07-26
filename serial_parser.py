import serial
import sys
from datetime import datetime
import serial.tools.list_ports
import numpy as np

baudrate = sys.argv[1]

def find_com_port_by_vid_pid(target_vid, target_pid):
    """
    Finds the COM port of a device given its Vendor ID (VID) and Product ID (PID).

    Args:
        target_vid (int): The Vendor ID of the target device.
        target_pid (int): The Product ID of the target device.

    Returns:
        str or None: The COM port name (e.g., 'COM3', '/dev/ttyUSB0') if found,
                     otherwise None.
    """
    ports = serial.tools.list_ports.comports()
    for port in ports:
        for i in range(0, target_vid.size):
            if port.vid == target_vid[i] and port.pid == target_pid[i]:
                return port.device, i
    return None

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

    dev = np.array(["ESP32 JTAG" , "CH340" ])
    vid = np.array([0x303A       , 0x1A86  ], dtype=int)
    pid = np.array([0x1001       , 0x55D3  ], dtype=int)

    com_port, n = find_com_port_by_vid_pid(vid, pid)

    if com_port:
        print(f"Serial device {dev[n]} (VID: {hex(vid[n])} PID: {hex(pid[n])}) found on port: {com_port}")
    else:
        print(f"Serial device not found.")

    read_from_serial(com_port, baudrate)
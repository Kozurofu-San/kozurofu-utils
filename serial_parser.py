import serial
import sys
from datetime import datetime
import find_com_port
import threading

baudrate = sys.argv[1]
io = sys.argv[2]

def read_from_serial(ser, port='COM3', baudrate=115200):
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

def write_to_serial(ser, port='COM3', baudrate=115200):
    while True:
        try:
            cmd = input()
            ser.write((cmd + '\n').encode('utf-8'))
        except Exception as e:
            print(f"Write error: {e}")
            break

if __name__ == "__main__":

    com_port, dev, vid, pid = find_com_port.find_com_port()
    
    try:
        ser = serial.Serial(
            port=com_port,
            baudrate=baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1
        )
    except serial.SerialException as e:
        print(f"Read error {com_port}: {e}")
        sys.exit(1)

    print("\033[95m {}\033[00m" .format("Logger started"))


    if com_port:
        print(f"Serial device {dev} (VID: {hex(vid)} PID: {hex(pid)}) found on port: {com_port}")
    else:
        print(f"Serial device not found.")

    readThread  = threading.Thread(target=read_from_serial, args=(ser, com_port, baudrate))
    writeThread = threading.Thread(target=write_to_serial , args=(ser, com_port, baudrate))

    readThread.start()
    writeThread.start()

    
    readThread.join()
    writeThread.join()
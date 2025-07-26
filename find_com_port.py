import serial.tools.list_ports
import numpy as np

dev = np.array(["ESP32 JTAG" , "CH340" ])
vid = np.array([0x303A       , 0x1A86  ], dtype=int)
pid = np.array([0x1001       , 0x55D3  ], dtype=int)

def find_com_port():
    """
    Finds the COM port of a device given its Vendor ID (VID) and Product ID (PID).

    Returns:
        str or None: The COM port name (e.g., 'COM3', '/dev/ttyUSB0') if found,

                     otherwise None.
    """
    ports = serial.tools.list_ports.comports()
    for port in ports:
        for i in range(0, vid.size):
            if port.vid == vid[i] and port.pid == pid[i]:
                return port.device, dev[i], vid[i], pid[i]
    return None

if __name__ == "__main__":
    com_port, dev, vid, pid = find_com_port()
    print(f"{com_port}")
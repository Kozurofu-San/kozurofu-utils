#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ECG Monitor for AD8232 sensor via COM port (Windows).
"""

import os
import sys
import time
import struct
import threading
import winreg
from collections import deque

import serial
import serial.tools.list_ports
import tkinter as tk
from tkinter import messagebox
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
from matplotlib.lines import Line2D

# ======================== Configuration ========================
VID = 0x1234
PID = 0x5678
BAUD_RATE = 115200
TIMEOUT = 1.0                    # seconds
SAMPLING_RATE = 250              # Hz (typical for AD8232 ECG)
WINDOW_SECONDS = 10
BUFFER_SIZE = SAMPLING_RATE * WINDOW_SECONDS
CMD_CHECK = bytes([0x5A])
CMD_SAMPLE = bytes([0x4B])
RESP_CONNECTED = 0x67
RESP_DISCONNECTED = 0x68

# ======================== Theme detection ========================
def is_dark_theme() -> bool:
    """Detect Windows system theme (AppsUseLightTheme registry key)."""
    try:
        key = winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        )
        value, _ = winreg.QueryValueEx(key, "AppsUseLightTheme")
        winreg.CloseKey(key)
        return value == 0  # 0 = dark, 1 = light
    except Exception:
        return True  # fallback to dark


def get_theme_colors():
    """Return color palette similar to VS Code Dark+ / Light+."""
    if is_dark_theme():
        return {
            "bg": "#1e1e1e",
            "fg": "#d4d4d4",
            "button_bg": "#3c3c3c",
            "button_fg": "#ffffff",
            "button_active": "#505050",
            "plot_bg": "#1e1e1e",
            "plot_face": "#252526",
            "line": "#4ec9b0",       # light teal-green (VS Code accent-like)
            "grid": "#3c3c3c",
            "spine": "#6e6e6e",
            "label": "#cccccc",
        }
    else:
        return {
            "bg": "#ffffff",
            "fg": "#333333",
            "button_bg": "#e1e1e1",
            "button_fg": "#333333",
            "button_active": "#d0d0d0",
            "plot_bg": "#ffffff",
            "plot_face": "#f3f3f3",
            "line": "#16825d",       # dark green
            "grid": "#d4d4d4",
            "spine": "#a0a0a0",
            "label": "#333333",
        }


# ======================== Main Application ========================
class ECGMonitor:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.colors = get_theme_colors()
        self.root.title("ECG Monitor (AD8232)")
        self.root.configure(bg=self.colors["bg"])
        self.root.geometry("900x550")
        self.root.minsize(700, 400)

        self.ser = None
        self.running = False
        self.thread = None
        self.data = deque([0.0] * BUFFER_SIZE, maxlen=BUFFER_SIZE)
        self.time_axis = [i / SAMPLING_RATE for i in range(BUFFER_SIZE)]

        self._build_ui()
        self._init_plot()

    def _build_ui(self):
        """Create buttons and matplotlib canvas."""
        # Button frame
        btn_frame = tk.Frame(self.root, bg=self.colors["bg"])
        btn_frame.pack(side=tk.TOP, fill=tk.X, padx=10, pady=8)

        self.btn_start = tk.Button(
            btn_frame,
            text="Start",
            width=12,
            command=self.toggle_start_stop,
            bg=self.colors["button_bg"],
            fg=self.colors["button_fg"],
            activebackground=self.colors["button_active"],
            activeforeground=self.colors["button_fg"],
            relief=tk.FLAT,
            font=("Segoe UI", 10),
        )
        self.btn_start.pack(side=tk.LEFT, padx=(0, 8))

        self.btn_save = tk.Button(
            btn_frame,
            text="Save",
            width=12,
            command=self.save_svg,
            bg=self.colors["button_bg"],
            fg=self.colors["button_fg"],
            activebackground=self.colors["button_active"],
            activeforeground=self.colors["button_fg"],
            relief=tk.FLAT,
            font=("Segoe UI", 10),
        )
        self.btn_save.pack(side=tk.LEFT)

        # Status label
        self.status_var = tk.StringVar(value="Ready")
        self.status_label = tk.Label(
            btn_frame,
            textvariable=self.status_var,
            bg=self.colors["bg"],
            fg=self.colors["fg"],
            font=("Segoe UI", 9),
        )
        self.status_label.pack(side=tk.RIGHT, padx=10)

        # Matplotlib figure
        self.fig = Figure(figsize=(9, 4.5), dpi=100, facecolor=self.colors["plot_bg"])
        self.ax = self.fig.add_subplot(111)
        self.canvas = FigureCanvasTkAgg(self.fig, master=self.root)
        self.canvas.get_tk_widget().pack(side=tk.TOP, fill=tk.BOTH, expand=True, padx=10, pady=(0, 10))

    def _init_plot(self):
        """Configure axes appearance."""
        self.ax.set_facecolor(self.colors["plot_face"])
        self.ax.set_xlim(0, WINDOW_SECONDS)
        self.ax.set_ylim(-2048, 2048)  # typical 12-bit range; adjust if needed
        self.ax.set_xlabel("Time (s)", color=self.colors["label"])
        self.ax.set_ylabel("Amplitude", color=self.colors["label"])
        self.ax.tick_params(colors=self.colors["label"])
        for spine in self.ax.spines.values():
            spine.set_color(self.colors["spine"])
        self.ax.grid(True, color=self.colors["grid"], linestyle="--", alpha=0.6)

        self.line = Line2D(
            self.time_axis,
            list(self.data),
            color=self.colors["line"],
            linewidth=1.2,
            antialiased=True,
        )
        self.ax.add_line(self.line)
        self.fig.tight_layout()
        self.canvas.draw()

    def find_com_port(self) -> str | None:
        """Find COM port with given VID/PID."""
        for port in serial.tools.list_ports.comports():
            if port.vid == VID and port.pid == PID:
                return port.device
        return None

    def toggle_start_stop(self):
        """Start or stop acquisition."""
        if not self.running:
            self.start_acquisition()
        else:
            self.stop_acquisition()

    def start_acquisition(self):
        """Connect, check electrodes, start sampling thread."""
        port = self.find_com_port()
        if port is None:
            messagebox.showerror("Device not found", "ECG device (VID 0x1234 PID 0x5678) not found.")
            return

        try:
            self.ser = serial.Serial(
                port=port,
                baudrate=BAUD_RATE,
                timeout=TIMEOUT,
                write_timeout=TIMEOUT,
            )
        except serial.SerialException as e:
            messagebox.showerror("Connection error", f"Cannot open {port}:\n{e}")
            return

        # Check electrode connection
        try:
            self.ser.reset_input_buffer()
            self.ser.write(CMD_CHECK)
            resp = self.ser.read(1)
            if not resp:
                messagebox.showerror("Timeout", "No response from device within 1 second.")
                self.ser.close()
                self.ser = None
                return

            code = resp[0]
            if code == RESP_CONNECTED:
                self.status_var.set("Electrodes connected")
            elif code == RESP_DISCONNECTED:
                self.status_var.set("Electrodes disconnected!")
                messagebox.showwarning("Warning", "Electrodes are disconnected.")
            else:
                self.status_var.set(f"Unknown response: 0x{code:02X}")
                messagebox.showwarning("Warning", f"Unexpected response: 0x{code:02X}")
        except serial.SerialException as e:
            messagebox.showerror("Serial error", str(e))
            self.ser.close()
            self.ser = None
            return

        # Start sampling
        self.running = True
        self.btn_start.config(text="Stop")
        self.status_var.set(f"Streaming @ {SAMPLING_RATE} Hz")
        self.thread = threading.Thread(target=self._sampling_loop, daemon=True)
        self.thread.start()
        self._update_plot()

    def stop_acquisition(self):
        """Stop sampling and close port."""
        self.running = False
        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=2.0)
        if self.ser and self.ser.is_open:
            try:
                self.ser.close()
            except Exception:
                pass
        self.ser = None
        self.btn_start.config(text="Start")
        self.status_var.set("Stopped")

    def _sampling_loop(self):
        """Continuously request and receive ECG samples."""
        interval = 1.0 / SAMPLING_RATE
        next_time = time.perf_counter()

        while self.running and self.ser and self.ser.is_open:
            try:
                self.ser.write(CMD_SAMPLE)
                raw = self.ser.read(2)
                if len(raw) == 2:
                    # Assume little-endian signed 16-bit
                    value = struct.unpack("<h", raw)[0]
                    self.data.append(float(value))
                else:
                    # Timeout or incomplete data – skip
                    pass
            except serial.SerialException:
                break

            # Maintain sampling rate
            next_time += interval
            sleep_time = next_time - time.perf_counter()
            if sleep_time > 0:
                time.sleep(sleep_time)
            else:
                # Behind schedule – catch up
                next_time = time.perf_counter()

    def _update_plot(self):
        """Refresh the plot (called from main thread)."""
        if not self.running:
            return
        self.line.set_ydata(list(self.data))
        self.canvas.draw_idle()
        self.root.after(40, self._update_plot)  # ~25 FPS GUI update

    def save_svg(self):
        """Save current plot window as SVG next to the script."""
        script_dir = os.path.dirname(os.path.abspath(__file__))
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        filename = os.path.join(script_dir, f"ecg_{timestamp}.svg")
        try:
            self.fig.savefig(filename, format="svg", facecolor=self.fig.get_facecolor())
            self.status_var.set(f"Saved: {os.path.basename(filename)}")
            messagebox.showinfo("Saved", f"Graph saved to:\n{filename}")
        except Exception as e:
            messagebox.showerror("Save error", str(e))

    def on_closing(self):
        """Clean shutdown."""
        self.stop_acquisition()
        self.root.destroy()


def main():
    root = tk.Tk()
    app = ECGMonitor(root)
    root.protocol("WM_DELETE_WINDOW", app.on_closing)
    root.mainloop()


if __name__ == "__main__":
    main()
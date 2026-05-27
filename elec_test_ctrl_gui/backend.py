"""
backend.py — FPGA UART Serial Backend
======================================
Handles all communication with the FPGA over USB-Serial (UART).

Protocol:
  Every transaction is exactly 2 bytes:
    BYTE 0 : address / instruction
    BYTE 1 : data payload

Address map (mirrors FPGA toplevel localparam):
  0x01  RUN_EXPERIMENT      data=0x00 → start, nonzero → stop
  0x02  PRBS_CROSS          data = 8-bit LFSR seed
  0x03  PRBS_ENABLE         data = 8-bit LFSR seed
  0x04  WATCHDOG_PROGRAM    data = watchdog_max (number of PGA cycles)
  0x05  EXPERIMENT_PROG     data = experiment duration in µs (8-bit)
  0x06  TOGGLE_PROG         data = toggle period in µs (8-bit)
"""

from __future__ import annotations

import time
import threading
from dataclasses import dataclass, field
from typing import Optional

import serial
import serial.tools.list_ports


# ---------------------------------------------------------------------------
# Address constants (must match FPGA toplevel localparam)
# ---------------------------------------------------------------------------

ADDR_RUN_EXPERIMENT   = 0x01
ADDR_PRBS_CROSS       = 0x02
ADDR_PRBS_ENABLE      = 0x03
ADDR_WATCHDOG_PROGRAM = 0x04
ADDR_EXPERIMENT_PROG  = 0x05
ADDR_TOGGLE_PROG      = 0x06


# ---------------------------------------------------------------------------
# Data-classes
# ---------------------------------------------------------------------------

@dataclass
class FPGABackendLinkConfig:
    """Mirrors the writable state of the FPGA registers."""
    prbs_cross_seed:       int = 0xA5   # 8-bit LFSR seed for prbs_cross
    prbs_enable_seed:      int = 0x5A   # 8-bit LFSR seed for prbs_enable
    watchdog_max:          int = 0xFF   # watchdog / PGA cycle count
    experiment_duration_us: int = 100  # experiment duration in µs  (0–255)
    toggle_period_us:      int = 10    # RX/TX toggle period in µs  (0–255)


@dataclass
class ConnectionState:
    port:      str  = ""
    baud:      int  = 115200
    connected: bool = False
    error:     str  = ""

    # Running log of sent packets  [(addr, data, timestamp_str), …]
    tx_log: list = field(default_factory=list)


# ---------------------------------------------------------------------------
# Backend class
# ---------------------------------------------------------------------------

class FPGABackendLink:
    """
    Thread-safe serial backend.
    All public methods are safe to call from any thread.
    """

    BAUD_RATES = [9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600]

    def __init__(self) -> None:
        self._ser:  Optional[serial.Serial] = None
        self._lock  = threading.Lock()
        self.state  = ConnectionState()
        self.config = FPGABackendLinkConfig()

    # ------------------------------------------------------------------
    # Port discovery
    # ------------------------------------------------------------------

    @staticmethod
    def list_ports() -> list[dict]:
        """Return a list of dicts describing available serial ports."""
        ports = []
        for p in serial.tools.list_ports.comports():
            ports.append({
                "device":      p.device,
                "description": p.description,
                "hwid":        p.hwid,
                "vid":         f"{p.vid:04X}" if p.vid else "—",
                "pid":         f"{p.pid:04X}" if p.pid else "—",
            })
        return ports

    # ------------------------------------------------------------------
    # Connection management
    # ------------------------------------------------------------------

    def connect(self, port: str, baud: int = 115200) -> bool:
        """Open the serial port. Returns True on success."""
        with self._lock:
            if self._ser and self._ser.is_open:
                self._ser.close()
            try:
                self._ser = serial.Serial(
                    port=port,
                    baudrate=baud,
                    bytesize=serial.EIGHTBITS,
                    parity=serial.PARITY_NONE,
                    stopbits=serial.STOPBITS_ONE,
                    timeout=1.0,
                )
                self.state.port      = port
                self.state.baud      = baud
                self.state.connected = True
                self.state.error     = ""
                return True
            except serial.SerialException as exc:
                self.state.connected = False
                self.state.error     = str(exc)
                return False

    def disconnect(self) -> None:
        """Close the serial port."""
        with self._lock:
            if self._ser and self._ser.is_open:
                self._ser.close()
            self.state.connected = False

    @property
    def is_connected(self) -> bool:
        return self.state.connected and bool(self._ser and self._ser.is_open)

    # ------------------------------------------------------------------
    # Low-level send
    # ------------------------------------------------------------------

    def _send_packet(self, addr: int, data: int) -> bool:
        """
        Send a 2-byte packet (addr, data).
        Caller must NOT hold self._lock.
        Returns True on success.
        """
        if not self.is_connected:
            self.state.error = "Not connected."
            return False

        packet = bytes([addr & 0xFF, data & 0xFF])
        try:
            with self._lock:
                self._ser.write(packet)  # type: ignore[union-attr]
            ts = time.strftime("%H:%M:%S")
            self.state.tx_log.append({
                "addr": addr,
                "data": data,
                "ts":   ts,
                "label": _addr_label(addr),
            })
            return True
        except serial.SerialException as exc:
            self.state.connected = False
            self.state.error     = str(exc)
            return False

    # ------------------------------------------------------------------
    # High-level commands
    # ------------------------------------------------------------------

    def run_experiment(self) -> bool:
        """Send RUN_EXPERIMENT with data=0x00 (start)."""
        return self._send_packet(ADDR_RUN_EXPERIMENT, 0x00)

    def stop_experiment(self) -> bool:
        """Send RUN_EXPERIMENT with data=0x01 (stop)."""
        return self._send_packet(ADDR_RUN_EXPERIMENT, 0x01)

    def program_prbs_cross(self, seed: Optional[int] = None) -> bool:
        """Write PRBS cross seed. Uses config value if seed is None."""
        if seed is not None:
            self.config.prbs_cross_seed = seed & 0xFF
        return self._send_packet(ADDR_PRBS_CROSS, self.config.prbs_cross_seed)

    def program_prbs_enable(self, seed: Optional[int] = None) -> bool:
        """Write PRBS enable seed. Uses config value if seed is None."""
        if seed is not None:
            self.config.prbs_enable_seed = seed & 0xFF
        return self._send_packet(ADDR_PRBS_ENABLE, self.config.prbs_enable_seed)

    def program_watchdog(self, watchdog_max: Optional[int] = None) -> bool:
        """Write watchdog_max to the PGA controller."""
        if watchdog_max is not None:
            self.config.watchdog_max = watchdog_max & 0xFF
        return self._send_packet(ADDR_WATCHDOG_PROGRAM, self.config.watchdog_max)

    def program_experiment_duration(self, duration_us: Optional[int] = None) -> bool:
        """Write experiment duration (µs) to the RX/TX controller."""
        if duration_us is not None:
            self.config.experiment_duration_us = duration_us & 0xFF
        return self._send_packet(ADDR_EXPERIMENT_PROG, self.config.experiment_duration_us)

    def program_toggle_period(self, period_us: Optional[int] = None) -> bool:
        """Write RX/TX toggle period (µs)."""
        if period_us is not None:
            self.config.toggle_period_us = period_us & 0xFF
        return self._send_packet(ADDR_TOGGLE_PROG, self.config.toggle_period_us)

    def program_all(self) -> dict[str, bool]:
        """
        Push the entire FPGABackendLinkConfig to the device in one shot.
        Returns a dict of {register_name: success}.
        """
        results = {}
        results["prbs_cross"]           = self.program_prbs_cross()
        results["prbs_enable"]          = self.program_prbs_enable()
        results["watchdog"]             = self.program_watchdog()
        results["experiment_duration"]  = self.program_experiment_duration()
        results["toggle_period"]        = self.program_toggle_period()
        return results

    # ------------------------------------------------------------------
    # TX log helpers
    # ------------------------------------------------------------------

    def clear_log(self) -> None:
        self.state.tx_log.clear()

    def get_log(self) -> list[dict]:
        return list(self.state.tx_log)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _addr_label(addr: int) -> str:
    return {
        ADDR_RUN_EXPERIMENT:   "RUN_EXPERIMENT",
        ADDR_PRBS_CROSS:       "PRBS_CROSS",
        ADDR_PRBS_ENABLE:      "PRBS_ENABLE",
        ADDR_WATCHDOG_PROGRAM: "WATCHDOG_PROGRAM",
        ADDR_EXPERIMENT_PROG:  "EXPERIMENT_PROG",
        ADDR_TOGGLE_PROG:      "TOGGLE_PROG",
    }.get(addr, f"UNKNOWN(0x{addr:02X})")
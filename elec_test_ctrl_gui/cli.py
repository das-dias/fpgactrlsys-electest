"""
frontend.py — FPGA UART CLI Frontend
======================================
A professional terminal UI built with Rich + prompt_toolkit.

Usage:
    python frontend.py [--port COM3] [--baud 115200]

Dependencies:
    pip install rich prompt_toolkit pyserial
"""

from __future__ import annotations

import argparse
import sys
import time
import threading
from typing import Optional

# Rich
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.text import Text
from rich.columns import Columns
from rich.style import Style
from rich.live import Live
from rich.layout import Layout
from rich.align import Align
from rich import box

# prompt_toolkit
from prompt_toolkit import PromptSession
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.styles import Style as PtStyle
from prompt_toolkit.formatted_text import HTML

from backend import FPGABackendLink, FPGABackendLinkConfig


# ---------------------------------------------------------------------------
# Colour palette (dark terminal-native theme)
# ---------------------------------------------------------------------------
#   accent   = bright amber  (#FFB800) — like a hardware scope
#   ok       = green         (#00FF99)
#   err      = red-orange    (#FF4444)
#   dim      = grey          (#555555)
#   panel_bg = near-black    (#0D0D0D)

ACCENT  = "#FFB800"
OK      = "#00FF99"
ERR     = "#FF4444"
WARN    = "#FF8C00"
DIM     = "#666666"
TITLE   = "#FFB800 bold"
HEADER  = "#AAAAAA"


# ---------------------------------------------------------------------------
# Console
# ---------------------------------------------------------------------------

console = Console(highlight=False)


# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------

BANNER = r"""
 ███████╗██████╗  ██████╗  █████╗      ██╗     ██╗███╗   ██╗██╗  ██╗
 ██╔════╝██╔══██╗██╔════╝ ██╔══██╗     ██║     ██║████╗  ██║██║ ██╔╝
 █████╗  ██████╔╝██║  ███╗███████║     ██║     ██║██╔██╗ ██║█████╔╝ 
 ██╔══╝  ██╔═══╝ ██║   ██║██╔══██║     ██║     ██║██║╚██╗██║██╔═██╗ 
 ██║     ██║     ╚██████╔╝██║  ██║     ███████╗██║██║ ╚████║██║  ██╗
 ╚═╝     ╚═╝      ╚═════╝ ╚═╝  ╚═╝     ╚══════╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝
"""


# ---------------------------------------------------------------------------
# Help text
# ---------------------------------------------------------------------------

HELP_TEXT = """
[bold {a}]COMMANDS[/bold {a}]

  [bold]connect[/bold] [<port>] [<baud>]    — Open serial port  (e.g. connect /dev/ttyUSB0 115200)
  [bold]disconnect[/bold]                   — Close serial port
  [bold]ports[/bold]                        — List available serial ports

  [bold]set prbs_cross[/bold]    <hex>      — Set PRBS cross LFSR seed     (0x00–0xFF)
  [bold]set prbs_enable[/bold]   <hex>      — Set PRBS enable LFSR seed    (0x00–0xFF)
  [bold]set watchdog[/bold]      <dec>      — Set watchdog max              (0–255)
  [bold]set duration[/bold]      <dec>      — Set experiment duration (µs)  (0–255)
  [bold]set toggle[/bold]        <dec>      — Set RX/TX toggle period (µs)  (0–255)

  [bold]program[/bold]                      — Push ALL registers to FPGA
  [bold]program[/bold] <reg>                — Push a single register (prbs_cross | prbs_enable |
                                            watchdog | duration | toggle)

  [bold]run[/bold]                          — Start experiment  (RUN_EXPERIMENT 0x00)
  [bold]stop[/bold]                         — Stop  experiment  (RUN_EXPERIMENT 0x01)

  [bold]status[/bold]                       — Show connection & config summary
  [bold]log[/bold]                          — Print TX packet log
  [bold]log clear[/bold]                    — Clear TX packet log

  [bold]help[/bold]                         — Show this message
  [bold]exit[/bold] / [bold]quit[/bold]     — Exit

[bold {a}]TIPS[/bold {a}]
  • All hex values accept 0x prefix or bare hex (e.g. A5 or 0xA5).
  • Tab-completion is available on all commands.
""".format(a=ACCENT)


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

def _parse_int(value: str) -> Optional[int]:
    """Parse decimal or 0x-prefixed hex string to int, return None on error."""
    try:
        return int(value, 0)
    except (ValueError, TypeError):
        return None


def _ok(msg: str) -> None:
    console.print(f"  [bold {OK}]✔[/bold {OK}]  {msg}")


def _err(msg: str) -> None:
    console.print(f"  [bold {ERR}]✘[/bold {ERR}]  {msg}")


def _warn(msg: str) -> None:
    console.print(f"  [bold {WARN}]![/bold {WARN}]  {msg}")


def _info(msg: str) -> None:
    console.print(f"  [bold {ACCENT}]→[/bold {ACCENT}]  {msg}")


def _rule(title: str = "") -> None:
    console.rule(f"[{DIM}]{title}[/{DIM}]", style=DIM)


# ---------------------------------------------------------------------------
# Status panel
# ---------------------------------------------------------------------------

def _build_status_panel(backend: FPGABackendLink) -> Panel:
    cfg  = backend.config
    st   = backend.state

    conn_text = (
        f"[bold {OK}]CONNECTED[/bold {OK}]  {st.port}  @  {st.baud} baud"
        if backend.is_connected
        else f"[bold {ERR}]DISCONNECTED[/bold {ERR}]"
    )

    reg_table = Table(box=box.SIMPLE, show_header=True, header_style=f"bold {ACCENT}",
                      pad_edge=False, expand=False)
    reg_table.add_column("Register",  style="bold", min_width=22)
    reg_table.add_column("Value",     justify="right", min_width=8)
    reg_table.add_column("Addr",      justify="right", style=DIM, min_width=6)

    reg_table.add_row("PRBS Cross Seed",          f"0x{cfg.prbs_cross_seed:02X}",       "0x02")
    reg_table.add_row("PRBS Enable Seed",         f"0x{cfg.prbs_enable_seed:02X}",      "0x03")
    reg_table.add_row("Watchdog Max",             f"{cfg.watchdog_max} (0x{cfg.watchdog_max:02X})", "0x04")
    reg_table.add_row("Experiment Duration (µs)", f"{cfg.experiment_duration_us}",      "0x05")
    reg_table.add_row("Toggle Period (µs)",       f"{cfg.toggle_period_us}",            "0x06")

    content = Text.assemble(
        (conn_text + "\n\n", ""),
    )

    # Combine into a renderable group
    from rich.console import Group
    group = Group(
        Text.from_markup(conn_text),
        Text(""),
        reg_table,
    )

    return Panel(
        group,
        title=f"[bold {ACCENT}]◈  FPGA STATUS[/bold {ACCENT}]",
        border_style=ACCENT,
        expand=False,
        padding=(0, 2),
    )


# ---------------------------------------------------------------------------
# Port listing
# ---------------------------------------------------------------------------

def _show_ports(backend: FPGABackendLink) -> None:
    ports = backend.list_ports()
    if not ports:
        _warn("No serial ports found.")
        return

    t = Table(box=box.SIMPLE_HEAD, header_style=f"bold {ACCENT}", show_edge=False)
    t.add_column("Device",      style="bold")
    t.add_column("Description")
    t.add_column("VID",  justify="center", style=DIM)
    t.add_column("PID",  justify="center", style=DIM)

    for p in ports:
        t.add_row(p["device"], p["description"], p["vid"], p["pid"])

    console.print()
    console.print(t)
    console.print()


# ---------------------------------------------------------------------------
# TX log display
# ---------------------------------------------------------------------------

def _show_log(backend: FPGABackendLink) -> None:
    log = backend.get_log()
    if not log:
        _warn("TX log is empty.")
        return

    t = Table(box=box.SIMPLE_HEAD, header_style=f"bold {ACCENT}", show_edge=False)
    t.add_column("#",      justify="right",  style=DIM, min_width=4)
    t.add_column("Time",   justify="center", min_width=10)
    t.add_column("Addr",   justify="center", min_width=6)
    t.add_column("Label",  min_width=22)
    t.add_column("Data",   justify="center", min_width=6)

    for i, entry in enumerate(log, 1):
        t.add_row(
            str(i),
            entry["ts"],
            f"0x{entry['addr']:02X}",
            entry["label"],
            f"0x{entry['data']:02X}",
        )

    console.print()
    console.print(Panel(t, title=f"[bold {ACCENT}]TX Log  ({len(log)} packets)[/bold {ACCENT}]",
                        border_style=DIM))
    console.print()


# ---------------------------------------------------------------------------
# Command handlers
# ---------------------------------------------------------------------------

def handle_connect(args: list[str], backend: FPGABackendLink) -> None:
    port = args[0] if args else None
    baud = 115200

    if len(args) >= 2:
        b = _parse_int(args[1])
        if b is None:
            _err(f"Invalid baud rate: {args[1]}")
            return
        baud = b

    if port is None:
        ports = backend.list_ports()
        if not ports:
            _err("No serial ports found. Specify a port manually.")
            return
        port = ports[0]["device"]
        _info(f"No port specified — using first available: {port}")

    _info(f"Connecting to {port} @ {baud} baud …")
    ok = backend.connect(port, baud)
    if ok:
        _ok(f"Connected to [bold]{port}[/bold] at {baud} baud.")
    else:
        _err(f"Connection failed: {backend.state.error}")


def handle_set(args: list[str], backend: FPGABackendLink) -> None:
    if len(args) < 2:
        _err("Usage: set <register> <value>")
        return

    reg, raw = args[0].lower(), args[1]
    val = _parse_int(raw)
    if val is None:
        _err(f"Cannot parse value: {raw!r}")
        return
    if not (0 <= val <= 255):
        _err("Value must be in range 0–255.")
        return

    MAP = {
        "prbs_cross":  ("prbs_cross_seed",        "PRBS Cross Seed"),
        "prbs_enable": ("prbs_enable_seed",        "PRBS Enable Seed"),
        "watchdog":    ("watchdog_max",            "Watchdog Max"),
        "duration":    ("experiment_duration_us",  "Experiment Duration (µs)"),
        "toggle":      ("toggle_period_us",        "Toggle Period (µs)"),
    }
    if reg not in MAP:
        _err(f"Unknown register: {reg!r}. Valid: {', '.join(MAP)}")
        return

    attr, label = MAP[reg]
    setattr(backend.config, attr, val)
    _ok(f"{label} ← {val} (0x{val:02X})  [not yet sent — use 'program' to push]")


def handle_program(args: list[str], backend: FPGABackendLink) -> None:
    if not backend.is_connected:
        _err("Not connected. Use 'connect' first.")
        return

    SINGLE_MAP = {
        "prbs_cross":  backend.program_prbs_cross,
        "prbs_enable": backend.program_prbs_enable,
        "watchdog":    backend.program_watchdog,
        "duration":    backend.program_experiment_duration,
        "toggle":      backend.program_toggle_period,
    }

    if args:
        reg = args[0].lower()
        if reg not in SINGLE_MAP:
            _err(f"Unknown register: {reg!r}. Valid: {', '.join(SINGLE_MAP)}")
            return
        ok = SINGLE_MAP[reg]()
        if ok:
            _ok(f"Programmed [{reg}].")
        else:
            _err(f"Send failed: {backend.state.error}")
        return

    # Program all
    results = backend.program_all()
    for reg_name, success in results.items():
        if success:
            _ok(f"Programmed {reg_name}")
        else:
            _err(f"Failed     {reg_name}: {backend.state.error}")


def handle_run(backend: FPGABackendLink) -> None:
    if not backend.is_connected:
        _err("Not connected.")
        return
    ok = backend.run_experiment()
    if ok:
        _ok("Experiment [bold]STARTED[/bold].")
    else:
        _err(f"Failed: {backend.state.error}")


def handle_stop(backend: FPGABackendLink) -> None:
    if not backend.is_connected:
        _err("Not connected.")
        return
    ok = backend.stop_experiment()
    if ok:
        _ok("Experiment [bold]STOPPED[/bold].")
    else:
        _err(f"Failed: {backend.state.error}")


# ---------------------------------------------------------------------------
# Main REPL
# ---------------------------------------------------------------------------

ALL_COMMANDS = [
    "connect", "disconnect", "ports",
    "set", "program", "run", "stop",
    "status", "log", "help", "exit", "quit",
]

SET_ARGS   = ["prbs_cross", "prbs_enable", "watchdog", "duration", "toggle"]
PROG_ARGS  = ["prbs_cross", "prbs_enable", "watchdog", "duration", "toggle"]

COMPLETER = WordCompleter(
    ALL_COMMANDS + SET_ARGS + PROG_ARGS,
    ignore_case=True,
    sentence=False,
)

PT_STYLE = PtStyle.from_dict({
    "prompt":        f"bold {ACCENT}",
    "rprompt":       DIM,
})


def _rprompt(backend: FPGABackendLink) -> str:
    if backend.is_connected:
        return f"<ansiyellow>{backend.state.port}</ansiyellow>"
    return "<ansired>disconnected</ansired>"


def run_cli(initial_port: Optional[str] = None, initial_baud: int = 115200) -> None:
    backend = FPGABackendLink()

    # Print banner
    console.print(f"[bold {ACCENT}]{BANNER}[/bold {ACCENT}]")
    console.print(
        Align.center(
            Text("FPGA UART Serial Controller  •  type 'help' to begin", style=DIM)
        )
    )
    console.print()

    # Auto-connect if port supplied via CLI args
    if initial_port:
        handle_connect([initial_port, str(initial_baud)], backend)
        console.print()

    session: PromptSession = PromptSession(
        completer=COMPLETER,
        style=PT_STYLE,
        complete_while_typing=True,
    )

    while True:
        try:
            conn_indicator = (
                f"[{OK}]●[/{OK}]" if backend.is_connected else f"[{ERR}]○[/{ERR}]"
            )
            raw = session.prompt(
                HTML(f'<ansibrightblack>[</ansibrightblack>'
                     f'<b><ansiyellow>FPGA</ansiyellow></b>'
                     f'<ansibrightblack>]</ansibrightblack> '
                     f'<b><ansiyellow>›</ansiyellow></b> '),
                rprompt=_rprompt(backend),
            )
        except (KeyboardInterrupt, EOFError):
            console.print(f"\n[{DIM}]Bye.[/{DIM}]")
            backend.disconnect()
            sys.exit(0)

        line = raw.strip()
        if not line:
            continue

        parts = line.split()
        cmd   = parts[0].lower()
        args  = parts[1:]

        # ---------------------------------------------------------------
        if cmd in ("exit", "quit"):
            console.print(f"[{DIM}]Disconnecting and exiting.[/{DIM}]")
            backend.disconnect()
            sys.exit(0)

        elif cmd == "help":
            console.print(HELP_TEXT)

        elif cmd == "ports":
            _show_ports(backend)

        elif cmd == "connect":
            handle_connect(args, backend)

        elif cmd == "disconnect":
            backend.disconnect()
            _ok("Disconnected.")

        elif cmd == "set":
            handle_set(args, backend)

        elif cmd == "program":
            handle_program(args, backend)

        elif cmd == "run":
            handle_run(backend)

        elif cmd == "stop":
            handle_stop(backend)

        elif cmd == "status":
            console.print()
            console.print(_build_status_panel(backend))
            console.print()

        elif cmd == "log":
            if args and args[0].lower() == "clear":
                backend.clear_log()
                _ok("Log cleared.")
            else:
                _show_log(backend)

        else:
            _err(f"Unknown command: {cmd!r}  — type 'help' for a list.")

        console.print()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="FPGA UART Serial Controller CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Example:\n  python frontend.py --port /dev/ttyUSB0 --baud 115200",
    )
    parser.add_argument("--port", "-p", default=None,
                        help="Serial port to connect to on startup")
    parser.add_argument("--baud", "-b", type=int, default=115200,
                        help="Baud rate (default: 115200)")
    return parser.parse_args()


if __name__ == "__main__":
    ns = _parse_args()
    run_cli(initial_port=ns.port, initial_baud=ns.baud)
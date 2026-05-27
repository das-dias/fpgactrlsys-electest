"""
fpga_uart_cli
=============
FPGA UART Serial Controller — package initialisation.

Exposes the public API surface so the package can be used both as a
standalone CLI application and as an importable library.

Typical library usage
---------------------
    from fpga_uart_cli import FPGABackend, FPGAConfig

    backend = FPGABackend()
    backend.connect("/dev/ttyUSB0", baud=115200)
    backend.program_prbs_cross(seed=0xA5)
    backend.run_experiment()

Typical CLI usage
-----------------
    python -m fpga_uart_cli            # launches the interactive REPL
    python frontend.py --port COM3     # run the frontend script directly
"""

from importlib.metadata import version, PackageNotFoundError

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------

try:
    __version__ = version("fpga-uart-cli")
except PackageNotFoundError:
    __version__ = "0.1.0-dev"

__author__  = ""
__license__ = "MIT"

# ---------------------------------------------------------------------------
# Public re-exports from backend
# ---------------------------------------------------------------------------

from .backend import (
    # Core classes
    FPGABackendLink,
    FPGABackendLinkConfig,
    ConnectionState,

    # Address constants (mirror FPGA toplevel localparam)
    ADDR_RUN_EXPERIMENT,
    ADDR_PRBS_CROSS,
    ADDR_PRBS_ENABLE,
    ADDR_WATCHDOG_PROGRAM,
    ADDR_EXPERIMENT_PROG,
    ADDR_TOGGLE_PROG,
)

# ---------------------------------------------------------------------------
# Public re-exports from frontend
# ---------------------------------------------------------------------------

from .cli import run_cli

# ---------------------------------------------------------------------------
# __all__ — controls `from fpga_uart_cli import *`
# ---------------------------------------------------------------------------

__all__ = [
    # Backend
    "FPGABackendLink",
    "FPGABackendLinkConfig",
    "ConnectionState",
    "ADDR_RUN_EXPERIMENT",
    "ADDR_PRBS_CROSS",
    "ADDR_PRBS_ENABLE",
    "ADDR_WATCHDOG_PROGRAM",
    "ADDR_EXPERIMENT_PROG",
    "ADDR_TOGGLE_PROG",
    # Frontend
    "run_cli",
    # Meta
    "__version__",
]
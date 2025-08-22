"""MiniSim (Python) package scaffold.

Exports:
- run: core simulation entrypoint (signature parity with Elixir).
- sweep: run multiple sizes and print wall ms per run.
"""

from .sim import run, sweep  # noqa: F401

__all__ = ["run", "sweep"]

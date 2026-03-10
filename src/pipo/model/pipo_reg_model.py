from __future__ import annotations

def pipo_reg_model(din: int, rst_n: int) -> int:
    if not rst_n: 
        return 0
    return din
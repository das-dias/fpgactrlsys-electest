from __future__ import annotations

def bin2dec(bin: list[int], signed: int = 0) -> int:
    lbin = len(bin)-1
    res = sum([b * 2**(lbin-k) for k,b in enumerate(bin)])
    return -res if signed else res

def dec2bin(x: int, width: int = 8) -> list[int]:
    res = [int(bit) for bit in bin(abs(x))[2:]]
    lres = len(res)
    if  lres < width:
        res = [0]*(width-lres) + res
    return res

def piso_reg_model(prev_state: int, cntr: int, rst_n: int, write: int, d_in: int = 0, width: int = 8) -> tuple[int, int, int]:
    if not rst_n:
        prev_state = 0
        return 0, prev_state, 0
    if write:
        cntr = width-1
        return dec2bin(d_in, width=width)[0], d_in, cntr
    curr_state = dec2bin(prev_state, width=width)
    if cntr>0:
        curr_state = curr_state[1:] + [0]
    return curr_state[0], bin2dec(curr_state), cntr-1 # MSB first
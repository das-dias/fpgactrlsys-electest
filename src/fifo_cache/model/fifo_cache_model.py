from __future__ import annotations

from numpy import ndarray, zeros

def fifo_cache_model(
    din: int, prev_out_reg:int, prev_state: ndarray, prev_size: int,
    prev_write_ptr:int, prev_read_ptr: int, 
    rst_n: int, we:int, re_n:int, depth: int = 256
    ) -> tuple[int, int, ndarray, int, int, int]:
    curr_state = prev_state
    size = prev_size
    write_ptr = prev_write_ptr
    read_ptr = prev_read_ptr
    out_reg = prev_out_reg
    ret_state = out_reg 
    if not rst_n:
        #curr_state = zeros(depth)
        size        = 0
        write_ptr   = 0
        read_ptr    = 0
        ret_state   = 0
    else:
        if we and (size < depth):
            curr_state[write_ptr] = din
            size += 1
            write_ptr = 0 if (write_ptr == depth) else write_ptr + 1
        if not(re_n) and (size>0):
            out_reg     = curr_state[read_ptr]
            read_ptr    = 0 if (read_ptr == depth) else read_ptr + 1
            size       -= 1
    return ret_state, out_reg, curr_state, size, write_ptr, read_ptr
from __future__ import annotations

from numpy import ndarray, zeros

import pdb
from copy import copy

class AnyVal(int):
    def __eq__(self, value: object) -> bool:
        return True
    def __ne__(self, value: object) -> bool:
        return True

def fifo_cache_model(
    din: int, prev_out:int, prev_state: ndarray,
    prev_write_ptr:int, prev_read_ptr: int, 
    rst_n: int, we:int, re_n:int
    ) -> tuple[int, ndarray, int, int]:
    curr_state = prev_state
    write_ptr = prev_write_ptr
    read_ptr = prev_read_ptr
    ret_state = AnyVal(-1) if re_n else prev_out
    full = write_ptr+1 == read_ptr
    empty = write_ptr == read_ptr
    if not rst_n:
        #curr_state = zeros(depth)
        #ret_state   = 0
        write_ptr   = 0
        read_ptr    = 0
    else:
        #if we and not(re_n): pdb.set_trace()
        if we and not(full):
            curr_state[write_ptr] = din
            write_ptr += 1
        if not(re_n or empty):
            ret_state  = curr_state[read_ptr]
            read_ptr   += 1
      
    return ret_state, curr_state, write_ptr, read_ptr

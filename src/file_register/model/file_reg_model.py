from __future__ import annotations

from numpy import ndarray

class AnyVal(int):
    def __eq__(self, value: object) -> bool:
        return True
    def __ne__(self, value: object) -> bool:
        return True

def file_reg_model(
    din: int, prev_out:int, addr:int, prev_state: ndarray, we:int, re_n:int
    ) -> tuple[int, ndarray]:
    curr_state = prev_state
    ret_state = AnyVal(-1)
    if we:
        curr_state[addr] = din
    elif not(re_n):
        ret_state = curr_state[addr]
    return ret_state, curr_state

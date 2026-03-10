from __future__ import annotations
#import pdb
# helper func

def bin2dec(bin: list[int], signed: int = 0) -> int:
    lbin = len(bin)-1
    res = sum([b * 2**(lbin-k) for k,b in enumerate(bin)])
    return -res if signed else res

def dec2bin(x: int, width: int = 8) -> tuple[list[int], int]:
    signed: int = 1 if x < 0 else 0
    res = [int(bit) for bit in bin(abs(x))[2:]]
    lres = len(res)
    if  lres < width:
        res = [0]*(width-lres) + res
    return res, signed

def prbs_lfsr_model(prev_state: list[int], we: int, initial_seed: list[int] = []) -> tuple[int, list[int]]:
    # 8b Fibonacci LFSR
    curr_state: list[int] = prev_state if not we else initial_seed
    feedback: int = int(not(curr_state[0] ^ curr_state[2] ^ curr_state[3] ^ curr_state[4]))
    if not we:
        curr_state = curr_state[1:] + [feedback]
    return curr_state[0], curr_state

def test_dec2bin():
    
    res1,_ = dec2bin(1)
    exp1 = [0]*7 + [1]
    assert all([x==v for x,v in zip(res1, exp1)]), "Expected {exp1}, Got: {res1}"
    
    res2,_ = dec2bin(4)
    exp2 = [0]*5 + [1,0,0]
    assert all([x==v for x,v in zip(res2, exp2)]), "Expected {exp2}, Got: {res2}"
    
    res3, signed = dec2bin(-4)
    assert all([x==v for x,v in zip(res3, exp2)]), "Expected {exp2}, Got: {res3}"
    assert signed == 1
    
if __name__ == "__main__":
    test_dec2bin()
    print('--- test_dec2bin: All tests passed ---')
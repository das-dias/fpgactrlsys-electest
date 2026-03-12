# type: ignore
from __future__ import annotations

import pdb

import random
from typing import Optional, Any
import numpy as np

import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_hello_world(dut: Any):
    N = 2**15
    
    dut.clk.value = 0
    dut.rst_n.value = 1
    dut.sw.value = 0
    
    for i in range(N):
        if i > 20: dut.sw.value = 1
        
        await Timer(100, units='ns')
        dut.clk.value = 1
        
        await Timer(100, units='ns')
        dut.clk.value = 0
        
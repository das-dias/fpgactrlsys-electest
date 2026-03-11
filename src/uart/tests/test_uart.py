# type: ignore
from __future__ import annotations

import pdb

import random
from typing import Optional, Any
import numpy as np

import cocotb
from cocotb.triggers import Timer

if cocotb.simulator.is_running():
  from uart_model import uart_tx_model, uart_rx_model, dec2bin, bin2dec

@cocotb.test()
async def test_uart_tx_random(dut: Any):
  
    dut.clk.value = 0
    dut.rst_n.value = 1
    
    random.seed(7)
    N = 2**15
    inputs = np.random.randint(0, 255, size=N, dtype=int)
    reset_events = np.ones(N, dtype=int)
    write_events = np.zeros(N, dtype=int)
    write_events[0] = 1
    num_resets = N // 20
    num_writes = N // 4
    indices_to_reset = random.sample(range(N), num_resets)
    indices_to_write = random.sample(range(N), num_writes)
    reset_events[indices_to_reset] = 0
    write_events[indices_to_write] = 1
    
    out, curr_state, cntr = uart_tx_model(
        0, 0, reset_events[0], write_events[0], d_in=int(inputs[0]))
    expected_states = [curr_state]
    expected_outputs = [out]
    
    for i, input in enumerate(inputs[1:], start=1):
        out, curr_state, cntr = uart_tx_model(
            curr_state, cntr, reset_events[i], write_events[i], d_in=int(input))
        expected_outputs.append(out)
        expected_states.append(curr_state)
    
    #await Timer(100, unit='ps')
    dut.tx_valid.value = 1
    for i, test_input in enumerate(inputs):
        dut.d_in.value = int(test_input)
        dut.rst_n.value = int(reset_events[i])
        #dut.tx_valid.value = int(write_events[i])
        await Timer(100, unit='ns')
        dut.clk.value = 1
        
        await Timer(100, unit='ns')
        dut.clk.value = 0
        #pdb.set_trace()
        #assert dut.uart_tx_inst.data_r.value == expected_states[i], f"Test failed for input {test_input}. Expected {dec2bin(expected_states[i])} but got {dut.uart_tx_inst.data_r.value}"
        #assert dut.s_out.value == expected_outputs[i], f"Test failed for input {test_input}. Expected {expected_outputs[i]} but got {dut.s_out.value}"
"""
@cocotb.test()
async def test_uart_rx_random(dut: Any):
  
    dut.clk.value = 0
    dut.rst_n.value = 1
    
    random.seed(7)
    N = 2**15
    inputs = np.random.randint(0, 255, size=N, dtype=int)
    reset_events = np.ones(N, dtype=int)
    write_events = np.zeros(N, dtype=int)
    write_events[0] = 1
    num_resets = N // 20
    num_writes = N // 4
    indices_to_reset = random.sample(range(N), num_resets)
    indices_to_write = random.sample(range(N), num_writes)
    reset_events[indices_to_reset] = 0
    write_events[indices_to_write] = 1
    
    out, curr_state, cntr = i2cmaster_model(
        0, 0, reset_events[0], write_events[0], d_in=int(inputs[0]))
    expected_states = [curr_state]
    expected_outputs = [out]
    for i, input in enumerate(inputs[1:], start=1):
        out, curr_state, cntr = i2cmaster_model(
            curr_state, cntr, reset_events[i], write_events[i], d_in=int(input))
        expected_outputs.append(out)
        expected_states.append(curr_state)
  
    #await Timer(100, unit='ps')
    for i, test_input in enumerate(inputs):
        dut.d_in.value = int(test_input)
        dut.rst_n.value = int(reset_events[i])
        dut.write.value = int(write_events[i])
        await Timer(100, unit='ps')
        dut.clk.value = 1
        
        await Timer(100, unit='ps')
        dut.clk.value = 0
        #pdb.set_trace()
        assert dut.shift_reg.value == expected_states[i], f"Test failed for input {test_input}. Expected {dec2bin(expected_states[i])} but got {dut.shift_reg.value}"
        assert dut.i2c_sda.value == expected_outputs[i], f"Test failed for input {test_input}. Expected {expected_outputs[i]} but got {dut.i2c_sda.value}"

"""
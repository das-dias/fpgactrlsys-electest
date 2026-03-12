# type: ignore
from __future__ import annotations

import random
from typing import Optional, Any

import cocotb
from cocotb.triggers import Timer

import pdb
import numpy as np

if cocotb.simulator.is_running():
    from file_reg_model import file_reg_model

@cocotb.test()
async def test_file_reg_random(dut: Any):
    
    dut.we.value = 0
    dut.re_n.value = 1
    
    DEPTH = 256
    WIDTH = 8
    
    N = 2**15
    random.seed(7)
    np.random.seed(7)
    inputs = np.random.randint(0, 2**WIDTH-1, size=N, dtype=int)
    addresses = np.random.randint(0, 2**np.log2(DEPTH)-1, size=N, dtype=int)
    #reset_events = np.ones(N, dtype=int)
    write_events = np.zeros(N, dtype=int)
    read_events  = np.ones(N, dtype=int)
    #num_resets = N // 20
    num_writes = N // 2
    num_reads  = N // 4
    #indices_to_reset = random.sample(range(N), num_resets)
    indices_to_write = random.sample(range(N), num_writes)
    indices_to_read	 = random.sample(range(N), num_reads)
    #reset_events[indices_to_reset] = 0
    write_events[indices_to_write] = 1
    read_events [indices_to_read]  = 0
    output, curr_state = file_reg_model(
        inputs[0], 0, addresses[0], np.zeros(DEPTH, dtype=int), write_events[0], read_events[0])
    
    expected_outputs = [output]
    #expected_states = [curr_state] # too much RAM use - don't really need it
    mem_states = [curr_state.copy()]
    for i, input_val in enumerate(inputs[1:], 1):
        output, curr_state = file_reg_model(
            input_val, output, addresses[i], curr_state,
            write_events[i], read_events[i])
        #pdb.set_trace()
        expected_outputs.append(output)
        mem_states.append(curr_state.copy())
        
    for i, test_input in enumerate(inputs):
        await Timer(100, unit='ps')
        dut.d_in.value = int(test_input)
        dut.addr.value = int(addresses[i])
        await Timer(10, unit='ps')
        dut.we.value = int(write_events[i])
        dut.re_n.value = int(read_events[i])
        #dut.clk.value = 1
        
        await Timer(100, unit='ps')
        #dut.clk.value = 0
        dut.we.value = 0
        dut.re_n.value = 1
        
        debug_mem = [int(v) for v in dut.mem.value]
        if not np.array_equal(mem_states[i], debug_mem):
            pdb.set_trace()
        assert np.array_equal(mem_states[i], debug_mem)
        
        #if int(dut.d_out.value) != expected_outputs[i]:
        #    pdb.set_trace()
        assert int(dut.d_out.value) == expected_outputs[i], \
            f"Test failed for input {test_input}. Expected {int(expected_outputs[i])} but got {int(dut.d_out.value)}"
        
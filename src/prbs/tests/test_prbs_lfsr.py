from __future__ import annotations

import random
from typing import Optional, Any

import cocotb
from cocotb.triggers import Timer

import logging

if cocotb.simulator.is_running():
  from prbs_lfsr_model import prbs_lfsr_model

@cocotb.test()
async def test_prbs_lfsr_simple(dut: Any):
  dut.we.value = 0
  dut.rst_n.value = 1
  inputs = list(range(8))
  reset_events = [1]*8
  reset_events[3] = 0
  reset_events[7] = 0
  expected_outputs = [prbs_lfsr_model(input, rstn) for input, rstn in zip(inputs, reset_events)]
  await Timer(100, unit='ps')
  for i, test_input in enumerate(inputs):
    dut.d_in.value = test_input
    dut.rst_n.value = reset_events[i]
    await Timer(100, unit='ps')
    dut.we.value = 1
    
    await Timer(100, unit='ps')
    dut.we.value = 0
    
    assert dut.d_out.value == expected_outputs[i], f"Test failed for input {test_input}. Expected {expected_outputs[i]} but got {dut.d_out.value}"

@cocotb.test()
async def test_prbs_lfsr_random(dut: Any):
  
  dut.we.value = 0
  dut.rst_n.value = 1
  
  random.seed(7)
  N = 2**8
  inputs = [random.randint(0, 7) for _ in range(N)]
  reset_events = [1]*N
  num_resets = N // 4
  indices_to_reset = random.sample(range(N), num_resets)
  for k in indices_to_reset:
    reset_events[k] = 0
  expected_outputs = [prbs_lfsr_model(input, rstn) for input, rstn in zip(inputs, reset_events)]
  await Timer(100, unit='ps')
  for i, test_input in enumerate(inputs):
    dut.d_in.value = test_input
    dut.rst_n.value = reset_events[i]
    await Timer(100, unit='ps')
    dut.we.value = 1
    
    await Timer(100, unit='ps')
    dut.we.value = 0
    
    assert dut.d_out.value == expected_outputs[i], f"Test failed for input {test_input}. Expected {expected_outputs[i]} but got {dut.d_out.value}"

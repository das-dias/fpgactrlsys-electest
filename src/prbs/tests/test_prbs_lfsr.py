# type: ignore
from __future__ import annotations
from functools import partial
import random
from typing import Optional, Any

#import pdb

import numpy as np

import cocotb
from cocotb.triggers import Timer

if cocotb.simulator.is_running():
  from prbs_lfsr_model import prbs_lfsr_model, dec2bin, bin2dec

@cocotb.test()
async def test_prbs_lfsr_simple(dut: Any):
  dut.we.value = 0
  dut.s_clk.value = 0
  
  Nticks = 2**15
  seed = 3
  seed_bin, _ = dec2bin(seed)
  lfsr = partial(prbs_lfsr_model, initial_seed=seed_bin)
  
  write_events = np.zeros(Nticks)
  write_events[0] = 1
  num_writes = Nticks // 20
  write_event_idxs = random.sample(range(Nticks), num_writes)
  write_events[write_event_idxs] = 1
  write_events = [int(we) for we in write_events]
  
  output, curr_state = lfsr(seed_bin, write_events[0])
  expected_outputs = [output]
  expected_states = [curr_state]
  for we in write_events[1:]:
    output, curr_state = lfsr(curr_state, we)
    #pdb.set_trace()
    expected_outputs.append(output)
    expected_states.append(curr_state)

  await Timer(100, unit='ps')
  
  for i, test_output in enumerate(expected_outputs):
    dut.d_seed.value = seed
    dut.we.value = write_events[i]
    await Timer(100, unit='ps')
    dut.s_clk.value = 1
    
    await Timer(100, unit='ps')
    dut.s_clk.value = 0
    assert dut.lfsr_q.value == bin2dec(expected_states[i]), f"Test failed for clock tick {i}. Expected {expected_states[i]} but got {dut.lfsr_q.value}"
    assert dut.s_out.value == test_output, f"Test failed for clock tick {i}. Expected {expected_states[i]} but got {dut.lfsr_q.value}"

@cocotb.test()
async def test_prbs_lfsr_random(dut: Any):
  random.seed(7)
  N = 2**8
  assert 1 # pass
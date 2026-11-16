#!/bin/sh
set -eu

vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
  counter.sv counter_tb.sv -o simv

./simv

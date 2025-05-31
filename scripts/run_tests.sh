#!/bin/bash
PROJECT_ROOT=$(pwd)
NVIM_EXECUTABLE="nvim"

$NVIM_EXECUTABLE --headless \
  -u "$PROJECT_ROOT/tests/minimal_init.lua" \
  -c "lua require('plenary.busted').run_and_exit('$PROJECT_ROOT/tests/')"


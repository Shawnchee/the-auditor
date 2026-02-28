#!/usr/bin/env bash

# function: runs Aderyn static analysis on Solidity

run_aderyn() {
  local workspace="$1"
  local extra_args="$2"
  local output_file="$3"

  cd "$workspace"

  # Build the Aderyn command
  local aderyn_cmd="aderyn --output $output_file"

  # Add extra args if provided
  if [[ -n "$extra_args" ]]; then
    aderyn_cmd+=" $extra_args"
  fi

  # Add the workspace root
  aderyn_cmd+=" ."

  log "  Executing: $aderyn_cmd"
  if eval "$aderyn_cmd" 2>/tmp/aderyn_stderr.log; then
    return 0
  else
    local exit_code=$?
    # If findings file was produced, treat as success
    if [[ -f "$output_file" ]]; then
      return 0
    fi
    if [[ -f /tmp/aderyn_stderr.log ]]; then
      cat /tmp/aderyn_stderr.log >&2
    fi
    return $exit_code
  fi
}

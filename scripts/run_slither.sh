#!/usr/bin/env bash

# function: runs Slither static analysis on Solidity

run_slither() {
  local workspace="$1"
  local extra_args="$2"
  local output_file="$3"

  cd "$workspace"

  # Install dependencies if package.json exists (for Hardhat/Foundry projects)
  if [[ -f "package.json" ]]; then
    log "  Installing npm dependencies for Slither..."
    npm install --silent 2>/dev/null || warn "  npm install failed, continuing anyway..."
  fi

  # If foundry.toml exists, it's a Foundry project
  if [[ -f "foundry.toml" ]]; then
    log "  Foundry project detected. Installing forge dependencies..."
    forge install --no-commit 2>/dev/null || true
  fi

  # Run Slither with JSON output
  local slither_cmd="slither . --json $output_file"

  # Add extra args if provided
  if [[ -n "$extra_args" ]]; then
    slither_cmd+=" $extra_args"
  fi

  # Run and capture exit code (Slither returns non-zero when findings exist)
  log "  Executing: $slither_cmd"
  if eval "$slither_cmd" 2>/tmp/slither_stderr.log; then
    return 0
  else
    local exit_code=$?
    # Exit code 1 = findings found (this is expected)
    if [[ $exit_code -eq 1 && -f "$output_file" ]]; then
      return 0
    fi
    # Other exit codes = actual errors
    if [[ -f /tmp/slither_stderr.log ]]; then
      cat /tmp/slither_stderr.log >&2
    fi
    return $exit_code
  fi
}

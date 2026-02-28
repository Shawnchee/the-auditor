#!/usr/bin/env bash

# function: runs Slither static analysis on Solidity

run_slither() {
  local workspace="$1"
  local extra_args="$2"
  local output_file="$3"

  cd "$workspace"

  # Determine if this is a framework project or standalone .sol files
  local is_project=false

  # Install dependencies if package.json exists (for Hardhat/Foundry projects)
  if [[ -f "package.json" ]]; then
    log "  Installing npm dependencies for Slither..."
    npm install --silent 2>/dev/null || warn "  npm install failed, continuing anyway..."
    is_project=true
  fi

  # If foundry.toml exists, it's a Foundry project
  if [[ -f "foundry.toml" ]]; then
    log "  Foundry project detected. Installing forge dependencies..."
    forge install --no-commit 2>/dev/null || true
    is_project=true
  fi

  # Build the Slither target
  local slither_target="."
  if [[ "$is_project" == "false" ]]; then
    # No framework detected — find .sol files and scan them individually
    local sol_files
    sol_files=$(find "$workspace" -name "*.sol" \
      -not -path "*/node_modules/*" \
      -not -path "*/.git/*" \
      -not -path "*/build/*" \
      2>/dev/null | head -50)

    if [[ -z "$sol_files" ]]; then
      warn "  No .sol files found for Slither."
      return 1
    fi

    # For standalone files, pass the first .sol file directly
    slither_target=$(echo "$sol_files" | head -1)
    log "  No project framework detected. Scanning standalone file: $slither_target"
  fi

  local slither_cmd="slither $slither_target --json $output_file"

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
    # If findings file was produced, treat as success (exit 1 = findings found)
    if [[ -f "$output_file" ]]; then
      return 0
    fi
    # Other exit codes = actual errors
    if [[ -f /tmp/slither_stderr.log ]]; then
      cat /tmp/slither_stderr.log >&2
    fi
    return $exit_code
  fi
}

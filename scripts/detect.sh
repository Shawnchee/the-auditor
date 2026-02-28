#!/usr/bin/env bash

# function: smart contract detection
# Sets HAS_SOLIDITY, HAS_RUST, HAS_MOVE flags

detect_contracts() {
  local workspace="$1"
  local include_paths="$2"
  local exclude_paths="$3"

  HAS_SOLIDITY="false"
  HAS_RUST="false"
  HAS_MOVE="false"

  # Build find command with includes/excludes
  local find_cmd="find $workspace -type f"

  # Exclude common non-source directories
  find_cmd+=" -not -path '*/node_modules/*'"
  find_cmd+=" -not -path '*/.git/*'"
  find_cmd+=" -not -path '*/target/*'"
  find_cmd+=" -not -path '*/build/*'"
  find_cmd+=" -not -path '*/artifacts/*'"
  find_cmd+=" -not -path '*/cache/*'"

  # Apply user-defined exclusions
  if [[ -n "$exclude_paths" ]]; then
    IFS=',' read -ra EXCLUDES <<< "$exclude_paths"
    for pattern in "${EXCLUDES[@]}"; do
      pattern=$(echo "$pattern" | xargs)  # trim whitespace
      find_cmd+=" -not -path '*/$pattern'"
    done
  fi

  # Detect Solidity files (.sol)
  local sol_files
  sol_files=$(eval "$find_cmd -name '*.sol'" 2>/dev/null || true)
  if [[ -n "$sol_files" ]]; then
    HAS_SOLIDITY="true"
    SOL_FILE_COUNT=$(echo "$sol_files" | wc -l)
    log "  Found $SOL_FILE_COUNT Solidity file(s)"
  fi

  # Detect Rust files (.rs) — indicates Solana or general Rust contracts
  local rs_files
  rs_files=$(eval "$find_cmd -name '*.rs'" 2>/dev/null || true)
  if [[ -n "$rs_files" ]]; then
    # Check if there's a Cargo.toml (confirms it's a Rust project)
    if [[ -f "$workspace/Cargo.toml" ]]; then
      HAS_RUST="true"
      RS_FILE_COUNT=$(echo "$rs_files" | wc -l)
      log "  Found $RS_FILE_COUNT Rust file(s) with Cargo.toml"
    fi
  fi

  # Detect Move files (.move)
  local move_files
  move_files=$(eval "$find_cmd -name '*.move'" 2>/dev/null || true)
  if [[ -n "$move_files" ]]; then
    HAS_MOVE="true"
    MOVE_FILE_COUNT=$(echo "$move_files" | wc -l)
    log "  Found $MOVE_FILE_COUNT Move file(s)"
  fi

  export HAS_SOLIDITY HAS_RUST HAS_MOVE
}

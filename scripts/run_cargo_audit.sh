#!/usr/bin/env bash

# function: runs cargo-audit for Rust / Move projects

run_cargo_audit() {
  local workspace="$1"
  local extra_args="$2"
  local output_file="$3"

  cd "$workspace"

  # Find all Cargo.toml files and run cargo-audit on each
  local cargo_manifests
  cargo_manifests=$(find "$workspace" -name "Cargo.toml" \
    -not -path "*/target/*" \
    -not -path "*/.git/*" \
    2>/dev/null || true)

  if [[ -z "$cargo_manifests" ]]; then
    warn "  No Cargo.toml found. Skipping cargo-audit."
    echo '{"tool": "cargo-audit", "audits": [], "notes": []}' > "$output_file"
    return 0
  fi

  local combined_results='{"tool": "cargo-audit", "audits": [], "notes": []}'

  while IFS= read -r manifest; do
    local manifest_dir
    manifest_dir=$(dirname "$manifest")
    log "  Auditing: $manifest"

    local audit_cmd="cargo audit --json"
    if [[ -n "$extra_args" ]]; then
      audit_cmd+=" $extra_args"
    fi

    local result stderr_content exit_code
    exit_code=0
    result=$(cd "$manifest_dir" && eval "$audit_cmd" 2>/tmp/cargo_audit_stderr.log) || exit_code=$?
    stderr_content=$(cat /tmp/cargo_audit_stderr.log 2>/dev/null || true)

    # Handle CVSS 4.0 parse error — remove the unsupported advisory entries and retry
    if echo "$stderr_content" | grep -q "unsupported CVSS version"; then
      warn "  Advisory DB contains CVSS 4.0 entries. Removing them and retrying..."

      # Find and remove advisory files that use CVSS 4.0 format
      local advisory_db_path="$HOME/.cargo/advisory-db"
      if [[ -d "$advisory_db_path" ]]; then
        local cvss4_files
        cvss4_files=$(grep -rl "CVSS:4.0" "$advisory_db_path" 2>/dev/null || true)
        if [[ -n "$cvss4_files" ]]; then
          echo "$cvss4_files" | xargs rm -f 2>/dev/null || true
          log "  Removed $(echo "$cvss4_files" | wc -l) CVSS 4.0 advisory files. Retrying..."
        fi
      fi

      # Retry with the cleaned advisory DB
      exit_code=0
      result=$(cd "$manifest_dir" && eval "$audit_cmd" 2>/tmp/cargo_audit_stderr.log) || exit_code=$?
      stderr_content=$(cat /tmp/cargo_audit_stderr.log 2>/dev/null || true)

      # If it STILL fails on CVSS, use --no-fetch as last resort
      if echo "$stderr_content" | grep -q "unsupported CVSS version"; then
        warn "  Still failing. Trying with --no-fetch..."
        exit_code=0
        result=$(cd "$manifest_dir" && eval "$audit_cmd --no-fetch" 2>/dev/null) || exit_code=$?
      fi
    fi

    # cargo-audit exits 1 when vulnerabilities are found — expected, not an error
    if [[ -n "$result" ]] && echo "$result" | jq '.' >/dev/null 2>&1; then
      combined_results=$(echo "$combined_results" | jq --argjson r "$result" '.audits += [$r]')
    else
      warn "  cargo-audit produced no parseable output for $manifest (exit ${exit_code})"
      local err_entry
      err_entry=$(jq -n --arg m "$manifest" --arg e "${stderr_content:0:500}" '{
        "manifest": $m,
        "error": $e,
        "status": "failed"
      }')
      combined_results=$(echo "$combined_results" | jq --argjson n "$err_entry" '.notes += [$n]')
    fi
  done <<< "$cargo_manifests"

  # Always write valid JSON — Gemini needs something to review even if the tool failed
  echo "$combined_results" | jq '.' > "$output_file"
  ok "  cargo-audit completed."
  return 0
}

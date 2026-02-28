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

    # Handle CVSS 4.0 parse error — the advisory DB has newer format entries
    # that cargo-audit v0.21 can't parse. Produce a helpful note for Gemini.
    if echo "$stderr_content" | grep -q "unsupported CVSS version"; then
      warn "  Advisory DB contains CVSS 4.0 entries unsupported by this cargo-audit version. Recording note."
      local note_entry
      note_entry=$(jq -n --arg m "$manifest" '{
        "manifest": $m,
        "note": "cargo-audit advisory DB parse failed (CVSS 4.0 unsupported by v0.21). Manual review of dependencies recommended.",
        "status": "skipped"
      }')
      combined_results=$(echo "$combined_results" | jq --argjson n "$note_entry" '.notes += [$n]')
      continue
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

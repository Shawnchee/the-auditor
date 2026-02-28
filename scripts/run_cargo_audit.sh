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
    echo '{"vulnerabilities": [], "warnings": []}' > "$output_file"
    return 0
  fi

  local combined_results='{"tool": "cargo-audit", "audits": []}'
  local has_error=false

  while IFS= read -r manifest; do
    local manifest_dir
    manifest_dir=$(dirname "$manifest")
    log "  Auditing: $manifest"

    local audit_cmd="cargo audit --json"
    if [[ -n "$extra_args" ]]; then
      audit_cmd+=" $extra_args"
    fi

    local result
    if result=$(cd "$manifest_dir" && eval "$audit_cmd" 2>/tmp/cargo_audit_stderr.log); then
      combined_results=$(echo "$combined_results" | jq --argjson r "$result" '.audits += [$r]')
    else
      local exit_code=$?
      # cargo-audit returns non-zero when vulnerabilities are found
      if [[ -n "$result" ]]; then
        combined_results=$(echo "$combined_results" | jq --argjson r "$result" '.audits += [$r]')
      else
        warn "  cargo-audit failed for $manifest (exit $exit_code)"
        has_error=true
      fi
    fi
  done <<< "$cargo_manifests"

  echo "$combined_results" | jq '.' > "$output_file"

  if [[ "$has_error" == "true" && ! -s "$output_file" ]]; then
    return 1
  fi
  return 0
}

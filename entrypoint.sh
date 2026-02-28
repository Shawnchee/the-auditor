#!/usr/bin/env bash

# entrypoint for pr auditor workflow
# Orchestrates detection → analysis → Gemini review → PR comment (upon PRs only, able to be configured in your .yml file)
set -euo pipefail

# ── Colours & helpers ────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

log()  { echo -e "${BLUE}[PR Auditor]${NC} $*"; }
warn() { echo -e "${YELLOW}[PR Auditor ⚠]${NC} $*"; }
err()  { echo -e "${RED}[PR Auditor ✗]${NC} $*"; }
ok()   { echo -e "${GREEN}[PR Auditor ✔]${NC} $*"; }

# ── Input environment variables (set by GitHub Actions) ──────
GEMINI_API_KEY="${INPUT_GEMINI_API_KEY:-}"
GITHUB_TOKEN="${INPUT_GITHUB_TOKEN:-${GITHUB_TOKEN:-}}"
SLITHER_ARGS="${INPUT_SLITHER_ARGS:-}"
ADERYN_ARGS="${INPUT_ADERYN_ARGS:-}"
CARGO_AUDIT_ARGS="${INPUT_CARGO_AUDIT_ARGS:-}"
SEVERITY_THRESHOLD="${INPUT_SEVERITY_THRESHOLD:-low}"
FAIL_ON_FINDINGS="${INPUT_FAIL_ON_FINDINGS:-false}"
CUSTOM_PROMPT="${INPUT_CUSTOM_PROMPT:-}"
INCLUDE_PATHS="${INPUT_INCLUDE_PATHS:-}"
EXCLUDE_PATHS="${INPUT_EXCLUDE_PATHS:-}"
GEMINI_MODEL="${INPUT_GEMINI_MODEL:-gemini-2.5-flash}"

# ── Workspace ────────────────────────────────────────────────
WORKSPACE="${GITHUB_WORKSPACE:-$(pwd)}"
REPORT_DIR="/tmp/auditor-reports"
mkdir -p "$REPORT_DIR"

# ── Validate required inputs ─────────────────────────────────
if [[ -z "$GEMINI_API_KEY" ]]; then
  err "GEMINI_API_KEY is required. Set it as a secret in your workflow."
  exit 1
fi

# ── Step 1: Detect contract languages ────────────────────────
log "🔍 Detecting smart contract files..."
source /scripts/detect.sh
detect_contracts "$WORKSPACE" "$INCLUDE_PATHS" "$EXCLUDE_PATHS"

if [[ "$HAS_SOLIDITY" == "false" && "$HAS_RUST" == "false" && "$HAS_MOVE" == "false" ]]; then
  ok "No smart contract files found in this PR. Nothing to audit."
  echo "vulnerability_count=0" >> "$GITHUB_OUTPUT"
  echo "critical_count=0"      >> "$GITHUB_OUTPUT"
  echo "high_count=0"          >> "$GITHUB_OUTPUT"
  echo "medium_count=0"        >> "$GITHUB_OUTPUT"
  echo "low_count=0"           >> "$GITHUB_OUTPUT"
  echo "security_score=100"    >> "$GITHUB_OUTPUT"
  exit 0
fi

log "Detected: Solidity=$HAS_SOLIDITY | Rust=$HAS_RUST | Move=$HAS_MOVE"

# ── Step 2: Read project context (README) ────────────────────
PROJECT_CONTEXT=""
if [[ -f "$WORKSPACE/README.md" ]]; then
  log "📖 Reading project README for context..."
  PROJECT_CONTEXT=$(head -c 4000 "$WORKSPACE/README.md")
fi

# ── Step 3: Run static analysis tools ────────────────────────
COMBINED_REPORT=""

# --- Solidity: Slither ---
if [[ "$HAS_SOLIDITY" == "true" ]]; then
  log "🐍 Running Slither (Solidity static analysis)..."
  source /scripts/run_slither.sh
  if run_slither "$WORKSPACE" "$SLITHER_ARGS" "$REPORT_DIR/slither.json"; then
    ok "Slither completed."
    COMBINED_REPORT+="$(cat "$REPORT_DIR/slither.json")"
    COMBINED_REPORT+=$'\n---TOOL_SEPARATOR---\n'
  else
    warn "Slither encountered errors (see logs above). Continuing..."
  fi

  # --- Solidity: Aderyn ---
  log "🦅 Running Aderyn (Solidity static analysis)..."
  source /scripts/run_aderyn.sh
  if run_aderyn "$WORKSPACE" "$ADERYN_ARGS" "$REPORT_DIR/aderyn.json"; then
    ok "Aderyn completed."
    COMBINED_REPORT+="$(cat "$REPORT_DIR/aderyn.json")"
    COMBINED_REPORT+=$'\n---TOOL_SEPARATOR---\n'
  else
    warn "Aderyn encountered errors (see logs above). Continuing..."
  fi
fi

# --- Rust / Move: cargo-audit ---
if [[ "$HAS_RUST" == "true" || "$HAS_MOVE" == "true" ]]; then
  log "🦀 Running cargo-audit (Rust/Move dependency audit)..."
  source /scripts/run_cargo_audit.sh
  if run_cargo_audit "$WORKSPACE" "$CARGO_AUDIT_ARGS" "$REPORT_DIR/cargo_audit.json"; then
    ok "cargo-audit completed."
    COMBINED_REPORT+="$(cat "$REPORT_DIR/cargo_audit.json")"
    COMBINED_REPORT+=$'\n---TOOL_SEPARATOR---\n'
  else
    warn "cargo-audit encountered errors (see logs above). Continuing..."
  fi
fi

# ── Step 4: Check if we have anything to review ──────────────
if [[ -z "$COMBINED_REPORT" ]]; then
  warn "No tool output was produced. Skipping Gemini review."
  echo "vulnerability_count=0" >> "$GITHUB_OUTPUT"
  echo "critical_count=0"      >> "$GITHUB_OUTPUT"
  echo "high_count=0"          >> "$GITHUB_OUTPUT"
  echo "medium_count=0"        >> "$GITHUB_OUTPUT"
  echo "low_count=0"           >> "$GITHUB_OUTPUT"
  echo "security_score=100"    >> "$GITHUB_OUTPUT"
  exit 0
fi

# ── Step 5: Send to Gemini for AI review ─────────────────────
log "🤖 Sending reports to Gemini ($GEMINI_MODEL) for AI-powered review..."
source /scripts/gemini_review.sh
gemini_review \
  "$GEMINI_API_KEY" \
  "$GEMINI_MODEL" \
  "$COMBINED_REPORT" \
  "$PROJECT_CONTEXT" \
  "$CUSTOM_PROMPT" \
  "$SEVERITY_THRESHOLD" \
  "$REPORT_DIR/gemini_review.json"

# ── Step 6: Parse results & post PR comment ──────────────────
log "📝 Posting review to PR..."
source /scripts/post_review.sh
post_review \
  "$GITHUB_TOKEN" \
  "$REPORT_DIR/gemini_review.json" \
  "$FAIL_ON_FINDINGS"

ok "Audit complete. 🛡️"

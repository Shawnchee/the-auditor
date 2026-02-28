#!/usr/bin/env bash

# function: sends combined tool output (whole analyzer payload from slither, aderyn + cargo_audit) to Gemini AI
# returns a structured JSON review

gemini_review() {
  local api_key="$1"
  local model="$2"
  local combined_report="$3"
  local project_context="$4"
  local custom_prompt="$5"
  local severity_threshold="$6"
  local output_file="$7"

  # ── Build the system prompt ──────────────────────────────
  local system_prompt
  system_prompt=$(cat <<'SYSTEM_PROMPT'
You are "PR Auditor", an expert smart contract security reviewer. You have been given the raw output from multiple static analysis tools (Slither, Aderyn, cargo-audit). Your job is to:

1. **De-duplicate findings** — Many tools flag the same issue. Merge them.
2. **Classify severity** — Assign each finding one of: CRITICAL, HIGH, MEDIUM, LOW, INFORMATIONAL.
3. **Provide context** — Explain WHY each finding matters, referencing the project's business logic when possible.
4. **Suggest fixes** — Give actionable, code-level remediation for each finding.
5. **Remove false positives** — Use the project context to filter out findings that are clearly intentional or benign.

6. **Calculate a Security Score using this STRICT formula:**
   Start at 100 and subtract penalties:
   - Each CRITICAL finding:      -25 points
   - Each HIGH finding:          -15 points
   - Each MEDIUM finding:         -5 points
   - Each LOW finding:            -2 points
   - Each INFORMATIONAL finding:  -1 point
   The minimum score is 0. Never give a score above 100.
   
   Examples:
   - 0 findings = 100
   - 1 CRITICAL + 2 HIGH = 100 - 25 - 30 = 45
   - 3 HIGH + 2 MEDIUM = 100 - 45 - 10 = 45
   - 1 LOW + 2 INFO = 100 - 2 - 2 = 96

   IMPORTANT: Do NOT override this formula. Apply it mechanically.

Respond ONLY with valid JSON in this exact schema:
{
  "security_score": <number 0-100>,
  "summary": "<one-paragraph executive summary>",
  "findings": [
    {
      "id": "<unique id like F-001>",
      "title": "<short title>",
      "severity": "<CRITICAL|HIGH|MEDIUM|LOW|INFORMATIONAL>",
      "category": "<e.g. Reentrancy, Access Control, Integer Overflow, Dependency Vulnerability>",
      "description": "<detailed description of the vulnerability>",
      "location": "<file:line if available, otherwise 'N/A'>",
      "impact": "<what could go wrong>",
      "recommendation": "<specific fix with code snippet if applicable>",
      "tools": ["<which tools flagged this>"],
      "confidence": "<HIGH|MEDIUM|LOW>"
    }
  ],
  "statistics": {
    "total": <number>,
    "critical": <number>,
    "high": <number>,
    "medium": <number>,
    "low": <number>,
    "informational": <number>,
    "false_positives_removed": <number>
  },
  "gas_optimizations": [
    {
      "title": "<short title>",
      "description": "<explanation>",
      "location": "<file:line>",
      "estimated_savings": "<gas estimate if possible>"
    }
  ]
}
SYSTEM_PROMPT
)

  # ── Build the user prompt ────────────────────────────────
  local user_prompt="## Static Analysis Tool Output\n\n$combined_report"

  if [[ -n "$project_context" ]]; then
    user_prompt+="\n\n## Project Context (from README)\n\n$project_context"
  fi

  if [[ -n "$custom_prompt" ]]; then
    user_prompt+="\n\n## Additional Instructions\n\n$custom_prompt"
  fi

  user_prompt+="\n\n## Configuration\n- Minimum severity threshold: $severity_threshold\n- Only include findings at or above this severity level."

  # ── Call Gemini API ──────────────────────────────────────
  local api_url="https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${api_key}"

  # Build the request payload
  local payload
  payload=$(jq -n \
    --arg system "$system_prompt" \
    --arg user "$user_prompt" \
    '{
      "system_instruction": {
        "parts": [{"text": $system}]
      },
      "contents": [
        {
          "role": "user",
          "parts": [{"text": $user}]
        }
      ],
      "generationConfig": {
        "temperature": 0.1,
        "responseMimeType": "application/json"
      }
    }')

  log "  Calling Gemini API ($model)..."

  local response
  local http_code
  local max_retries=3
  local retry_count=0

  while [[ $retry_count -lt $max_retries ]]; do
    response=$(curl -s -w "\n%{http_code}" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "$api_url" 2>/dev/null)

    http_code=$(echo "$response" | tail -n 1)
    response=$(echo "$response" | sed '$d')

    if [[ "$http_code" == "200" ]]; then
      break
    fi

    retry_count=$((retry_count + 1))
    if [[ $retry_count -lt $max_retries ]]; then
      warn "  Gemini API returned HTTP $http_code. Retrying ($retry_count/$max_retries)..."
      sleep $((retry_count * 2))
    fi
  done

  if [[ "$http_code" != "200" ]]; then
    err "  Gemini API failed after $max_retries retries (HTTP $http_code)."
    err "  Response: $response"

    # Create a fallback report from raw tool output
    log "  Generating fallback report without AI analysis..."
    cat > "$output_file" <<EOF
{
  "security_score": -1,
  "summary": "⚠️ Gemini AI analysis unavailable (API returned HTTP $http_code). Raw tool output is included below for manual review.",
  "findings": [],
  "statistics": {"total": 0, "critical": 0, "high": 0, "medium": 0, "low": 0, "informational": 0, "false_positives_removed": 0},
  "gas_optimizations": [],
  "raw_tool_output": true,
  "error": "Gemini API unavailable"
}
EOF
    return 0  # Don't fail the action, let the user see the raw output
  fi

  # Extract the JSON from Gemini's response
  local gemini_text
  gemini_text=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty')

  if [[ -z "$gemini_text" ]]; then
    err "  Could not extract text from Gemini response."
    echo "$response" | jq '.' > "$output_file" 2>/dev/null || echo "$response" > "$output_file"
    return 1
  fi

  # Write the parsed review
  echo "$gemini_text" | jq '.' > "$output_file" 2>/dev/null || echo "$gemini_text" > "$output_file"
  ok "  Gemini review saved to $output_file"
  return 0
}

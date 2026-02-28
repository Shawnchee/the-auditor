#!/usr/bin/env bash

# function: posts the Gemini review as a PR comment

post_review() {
  local github_token="$1"
  local review_file="$2"
  local fail_on_findings="$3"

  # ── Parse the review JSON ──────────────────────────────────
  local review
  review=$(cat "$review_file")

  local security_score
  security_score=$(echo "$review" | jq -r '.security_score // -1')

  local summary
  summary=$(echo "$review" | jq -r '.summary // "No summary available."')

  local total
  total=$(echo "$review" | jq -r '.statistics.total // 0')

  local critical
  critical=$(echo "$review" | jq -r '.statistics.critical // 0')

  local high
  high=$(echo "$review" | jq -r '.statistics.high // 0')

  local medium
  medium=$(echo "$review" | jq -r '.statistics.medium // 0')

  local low
  low=$(echo "$review" | jq -r '.statistics.low // 0')

  local informational
  informational=$(echo "$review" | jq -r '.statistics.informational // 0')

  # ── Set GitHub Action outputs ──────────────────────────────
  echo "vulnerability_count=$total"   >> "$GITHUB_OUTPUT"
  echo "critical_count=$critical"     >> "$GITHUB_OUTPUT"
  echo "high_count=$high"             >> "$GITHUB_OUTPUT"
  echo "medium_count=$medium"         >> "$GITHUB_OUTPUT"
  echo "low_count=$low"               >> "$GITHUB_OUTPUT"
  echo "security_score=$security_score" >> "$GITHUB_OUTPUT"

  # ── Build the PR comment body ──────────────────────────────
  local score_emoji="🟢"
  local score_bar=""
  if [[ "$security_score" -ge 80 ]]; then
    score_emoji="🟢"
  elif [[ "$security_score" -ge 60 ]]; then
    score_emoji="🟡"
  elif [[ "$security_score" -ge 40 ]]; then
    score_emoji="🟠"
  else
    score_emoji="🔴"
  fi

  # Build severity badges
  local severity_badges=""
  [[ "$critical" -gt 0 ]] && severity_badges+="![Critical](https://img.shields.io/badge/Critical-${critical}-red) "
  [[ "$high" -gt 0 ]]     && severity_badges+="![High](https://img.shields.io/badge/High-${high}-orange) "
  [[ "$medium" -gt 0 ]]   && severity_badges+="![Medium](https://img.shields.io/badge/Medium-${medium}-yellow) "
  [[ "$low" -gt 0 ]]      && severity_badges+="![Low](https://img.shields.io/badge/Low-${low}-blue) "

  local comment_body
  comment_body="## 🛡️ PR Auditor – Security Report\n\n"
  comment_body+="### ${score_emoji} Security Score: **${security_score}/100**\n\n"
  comment_body+="${severity_badges}\n\n"
  comment_body+="---\n\n"
  comment_body+="### 📋 Summary\n\n${summary}\n\n"

  # ── Add findings table ─────────────────────────────────────
  if [[ "$total" -gt 0 ]]; then
    comment_body+="### 🔍 Findings (${total} total)\n\n"
    comment_body+="| # | Severity | Category | Title | Confidence |\n"
    comment_body+="|---|----------|----------|-------|------------|\n"

    local findings_table
    findings_table=$(echo "$review" | jq -r '.findings[] | "| \(.id) | \(.severity) | \(.category) | \(.title) | \(.confidence) |"')
    comment_body+="${findings_table}\n\n"

    # ── Add detailed findings ──────────────────────────────
    comment_body+="<details>\n<summary>📖 Detailed Findings</summary>\n\n"

    local findings_count
    findings_count=$(echo "$review" | jq '.findings | length')

    for i in $(seq 0 $((findings_count - 1))); do
      local finding
      finding=$(echo "$review" | jq ".findings[$i]")

      local f_id f_title f_severity f_category f_description f_location f_impact f_recommendation f_tools
      f_id=$(echo "$finding" | jq -r '.id')
      f_title=$(echo "$finding" | jq -r '.title')
      f_severity=$(echo "$finding" | jq -r '.severity')
      f_category=$(echo "$finding" | jq -r '.category')
      f_description=$(echo "$finding" | jq -r '.description')
      f_location=$(echo "$finding" | jq -r '.location')
      f_impact=$(echo "$finding" | jq -r '.impact')
      f_recommendation=$(echo "$finding" | jq -r '.recommendation')
      f_tools=$(echo "$finding" | jq -r '.tools | join(", ")')

      local sev_icon="ℹ️"
      case "$f_severity" in
        CRITICAL) sev_icon="🔴" ;;
        HIGH)     sev_icon="🟠" ;;
        MEDIUM)   sev_icon="🟡" ;;
        LOW)      sev_icon="🔵" ;;
      esac

      comment_body+="\n#### ${sev_icon} ${f_id}: ${f_title}\n\n"
      comment_body+="- **Severity:** ${f_severity}\n"
      comment_body+="- **Category:** ${f_category}\n"
      comment_body+="- **Location:** \`${f_location}\`\n"
      comment_body+="- **Detected by:** ${f_tools}\n\n"
      comment_body+="**Description:**\n${f_description}\n\n"
      comment_body+="**Impact:**\n${f_impact}\n\n"
      comment_body+="**Recommendation:**\n${f_recommendation}\n\n"
      comment_body+="---\n"
    done

    comment_body+="\n</details>\n\n"
  fi

  # ── Add gas optimizations if any ───────────────────────────
  local gas_count
  gas_count=$(echo "$review" | jq '.gas_optimizations | length // 0')

  if [[ "$gas_count" -gt 0 ]]; then
    comment_body+="<details>\n<summary>⛽ Gas Optimizations (${gas_count})</summary>\n\n"

    for i in $(seq 0 $((gas_count - 1))); do
      local gas
      gas=$(echo "$review" | jq ".gas_optimizations[$i]")
      local g_title g_description g_location g_savings
      g_title=$(echo "$gas" | jq -r '.title')
      g_description=$(echo "$gas" | jq -r '.description')
      g_location=$(echo "$gas" | jq -r '.location')
      g_savings=$(echo "$gas" | jq -r '.estimated_savings // "N/A"')

      comment_body+="#### ⛽ ${g_title}\n\n"
      comment_body+="- **Location:** \`${g_location}\`\n"
      comment_body+="- **Estimated Savings:** ${g_savings}\n\n"
      comment_body+="${g_description}\n\n---\n"
    done

    comment_body+="\n</details>\n\n"
  fi

  comment_body+="---\n"
  comment_body+="*Generated by [PR Auditor](https://github.com/Shawnchee/the-auditor) 🛡️ — Universal Smart Contract Guardian*\n"

  # ── Post the comment to the PR ─────────────────────────────
  if [[ -n "${GITHUB_EVENT_PATH:-}" ]]; then
    local pr_number
    pr_number=$(jq -r '.pull_request.number // .number // empty' "$GITHUB_EVENT_PATH" 2>/dev/null || true)

    if [[ -n "$pr_number" ]]; then
      local repo="${GITHUB_REPOSITORY}"
      local api_url="https://api.github.com/repos/${repo}/issues/${pr_number}/comments"

      local comment_payload
      comment_payload=$(jq -n --arg body "$(echo -e "$comment_body")" '{"body": $body}')

      local post_response
      post_response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "$comment_payload" \
        "$api_url")

      local post_code
      post_code=$(echo "$post_response" | tail -n 1)

      if [[ "$post_code" == "201" ]]; then
        local comment_url
        comment_url=$(echo "$post_response" | sed '$d' | jq -r '.html_url // empty')
        ok "  Review posted to PR #${pr_number}"
        echo "report_url=$comment_url" >> "$GITHUB_OUTPUT"
      else
        warn "  Failed to post PR comment (HTTP $post_code). Comment body saved to $review_file."
      fi
    else
      warn "  Could not determine PR number. Printing review to stdout."
      echo -e "$comment_body"
    fi
  else
    # Not running in GitHub Actions — print to stdout
    echo -e "$comment_body"
  fi

  # ── Fail the action if configured and findings exist ───────
  if [[ "$fail_on_findings" == "true" && "$total" -gt 0 ]]; then
    err "Failing action: $total vulnerabilities found (fail_on_findings=true)."
    exit 1
  fi
}

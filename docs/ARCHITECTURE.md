# Architecture & Developer Docs

Technical documentation for PR Auditor contributors and advanced users.

---

## How It Works

```
PR Opened/Updated
       │
       ▼
┌──────────────────┐
│  1. DETECT       │  Scan for .sol, .rs, .move files
│     Files        │  Read README.md for project context
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  2. ANALYZE      │  Run Slither + Aderyn (Solidity)
│     Static Tools │  Run cargo-audit (Rust/Move)
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  3. AI REVIEW    │  Send combined tool output to Gemini
│     Gemini AI    │  De-duplicate, classify, contextualize
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  4. REPORT       │  Post rich PR comment with:
│     PR Comment   │  • Security Score (0-100)
│                  │  • Severity-categorized findings
│                  │  • Actionable fix suggestions
│                  │  • Gas optimizations
└──────────────────┘
```

### The AI Advantage

PR Auditor doesn't just dump raw tool output. Gemini AI:

1. **De-duplicates** findings across Slither and Aderyn
2. **Removes false positives** by reading the project's README to understand business intent
3. **Explains impact** in plain English
4. **Suggests specific code fixes** for each finding
5. **Calculates a Security Score** using a strict formula:
   - Start at 100
   - Each CRITICAL: -25
   - Each HIGH: -15
   - Each MEDIUM: -5
   - Each LOW: -2
   - Each INFORMATIONAL: -1
   - Floor at 0

---

## Project Structure

```
the-auditor/
├── action.yml                     # Composite GitHub Action definition
├── entrypoint.sh                  # Main orchestration script
├── scripts/
│   ├── detect.sh                  # Smart contract file detection
│   ├── run_slither.sh             # Slither runner (Solidity)
│   ├── run_aderyn.sh              # Aderyn runner (Solidity)
│   ├── run_cargo_audit.sh         # cargo-audit runner (Rust/Move)
│   ├── gemini_review.sh           # Gemini API integration
│   ├── post_review.sh             # PR comment builder & poster
│   └── post_raw_summary.sh        # Raw tool summary comment
├── tests/                         # Test contracts (safe examples)
├── docs/
│   └── ARCHITECTURE.md            # This file
├── .github/workflows/
│   └── test.yml                   # Self-test CI workflow
├── CONTRIBUTING.md
├── README.md
├── LICENSE
└── .gitignore
```

---

## Outputs

Use these in subsequent workflow steps:

| Output | Type | Description |
|--------|------|-------------|
| `vulnerability_count` | `number` | Total findings across all tools |
| `critical_count` | `number` | Critical-severity findings |
| `high_count` | `number` | High-severity findings |
| `medium_count` | `number` | Medium-severity findings |
| `low_count` | `number` | Low/informational findings |
| `security_score` | `number` | Overall score (0–100) |
| `report_url` | `string` | URL of the posted PR comment |

### Example: Gate Deployments on Score

```yaml
jobs:
  audit:
    runs-on: ubuntu-latest
    outputs:
      score: ${{ steps.audit.outputs.security_score }}
    steps:
      - uses: actions/checkout@v4
      - id: audit
        uses: Shawnchee/the-auditor@v1
        with:
          gemini_api_key: ${{ secrets.GEMINI_API_KEY }}

  deploy:
    needs: audit
    if: needs.audit.outputs.score >= 80
    runs-on: ubuntu-latest
    steps:
      - run: echo "Security score passed! Deploying..."
```

### Example: Block on Critical Findings

```yaml
- name: Run PR Auditor
  id: audit
  uses: Shawnchee/the-auditor@v1
  with:
    gemini_api_key: ${{ secrets.GEMINI_API_KEY }}

- name: Block if critical
  if: steps.audit.outputs.critical_count > 0
  run: |
    echo "❌ Found ${{ steps.audit.outputs.critical_count }} critical vulnerabilities!"
    exit 1
```

---

## Error Handling

PR Auditor is designed to be resilient. No single tool failure will crash the action.

| Scenario | Behaviour |
|----------|-----------|
| **Gemini API is down** | Falls back to raw tool output (still posts results) |
| **Slither fails** | Logs warning, continues with other tools |
| **Aderyn fails** | Logs warning, continues with other tools |
| **cargo-audit fails** | Logs warning, continues with other tools |
| **No contract files found** | Exits cleanly with security score 100 |
| **No Cargo.toml for Rust** | Skips cargo-audit gracefully |
| **cargo-audit CVSS 4.0 error** | Removes incompatible advisories and retries with `--no-fetch` |
| **Large tool output (>2MB)** | Payloads written to temp files to bypass shell ARG_MAX |
| **PR comment > 65KB** | Truncated with a notice appended |

---

## Advanced Configuration Examples

### DeFi Protocol (Solidity)

```yaml
- uses: Shawnchee/the-auditor@v1
  with:
    gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
    gemini_model: "gemini-2.5-pro"
    severity_threshold: "medium"
    slither_args: "--exclude naming-convention --exclude-informational"
    exclude_paths: "test/**,mocks/**,scripts/**"
    custom_prompt: "This is a DeFi lending protocol. Focus on reentrancy, flash loan attacks, and oracle manipulation."
```

### Solana / Anchor (Rust)

```yaml
- uses: Shawnchee/the-auditor@v1
  with:
    gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
    include_paths: "programs/**"
    custom_prompt: "This is a Solana program using Anchor. Focus on account validation and PDA security."
```

### Multi-Chain Monorepo

```yaml
- uses: Shawnchee/the-auditor@v1
  with:
    gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
    severity_threshold: "low"
    exclude_paths: "test/**,deploy/**"
    custom_prompt: "Monorepo with Solidity (EVM) and Move (Aptos) contracts. Audit each chain independently."
```

---

## Environment Variables

These are set automatically by `action.yml` and passed to `entrypoint.sh`:

| Variable | Source |
|----------|--------|
| `INPUT_GEMINI_API_KEY` | `inputs.gemini_api_key` |
| `INPUT_GEMINI_MODEL` | `inputs.gemini_model` |
| `INPUT_GITHUB_TOKEN` | `inputs.github_token` |
| `INPUT_FAIL_ON_FINDINGS` | `inputs.fail_on_findings` |
| `INPUT_SEVERITY_THRESHOLD` | `inputs.severity_threshold` |
| `INPUT_CUSTOM_PROMPT` | `inputs.custom_prompt` |
| `SCRIPTS_DIR` | `github.action_path/scripts` |
| `GITHUB_WORKSPACE` | Set by GitHub Actions |
| `GITHUB_REPOSITORY` | Set by GitHub Actions |
| `GITHUB_EVENT_PATH` | Set by GitHub Actions |

---

## Dependencies

Installed at runtime by `action.yml`:

| Tool | Version | Purpose |
|------|---------|---------|
| Python 3.12 | `actions/setup-python@v5` | Required by Slither |
| Slither | Latest | Solidity static analysis |
| solc | 0.8.28 | Solidity compiler |
| Aderyn | v0.6.8 | Solidity static analysis |
| cargo-audit | 0.21.1 | Rust dependency auditing |
| jq | System | JSON processing |
| curl | System | API calls |

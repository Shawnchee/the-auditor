<div align="center">

# PR Auditor

### Smart Contract PR Review (Solidity, Move, Rust)

**Automatically audit Solidity, Rust, and Move smart contracts on every Pull Request — powered by static analysis + Gemini**

[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

---

[Quick Start](#-quick-start) · [Configuration](#%EF%B8%8F-configuration) · [How It Works](#-how-it-works) · [Outputs](#-outputs) · [Examples](#-examples) · [FAQ](#-faq)

</div>

---

## 🚀 What is PR Auditor?

**PR Auditor** is a GitHub Action that acts as your **automated security reviewer** for smart contracts. It combines the precision of battle-tested static analysis tools with the reasoning power of **Google Gemini AI** to provide:

- 🔍 **Deep vulnerability detection** across Solidity, Rust (Solana), and Move (Aptos) contracts
- 🤖 **AI-powered context-aware analysis** that understands your project's business logic
- 📊 **Security Score** (0–100) at a glance
- 💬 **Rich PR comments** with categorized findings, severity badges, and actionable fixes
- 🔄 **De-duplicated results** from multiple tools — no duplicate noise

### Supported Chains & Tools

| Chain | File Extension | Static Analysis Tools |
|-------|---------------|----------------------|
| **Ethereum / EVM** | `.sol` | [Slither](https://github.com/crytic/slither), [Aderyn](https://github.com/Cyfrin/aderyn) |
| **Solana** | `.rs` | [cargo-audit](https://github.com/RustSec/rustsec) |
| **Aptos / Move** | `.move` | [cargo-audit](https://github.com/RustSec/rustsec) |

---

## ⚡ Quick Start

### 1. Get a Gemini API Key

1. Go to [Google AI Studio](https://aistudio.google.com/apikey)
2. Create a new API key
3. Copy the key — you'll need it in the next step

### 2. Add the Secret to Your Repository

1. Go to your repository → **Settings** → **Secrets and variables** → **Actions**
2. Click **"New repository secret"**
3. Name: `GEMINI_API_KEY`
4. Value: *(paste your API key)*
5. Click **"Add secret"**

### 3. Create the Workflow File

Create `.github/workflows/audit.yml` in your project:

```yaml
name: "Smart Contract Audit"

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write

jobs:
  audit:
    name: "Security Audit"
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run PR Auditor
        uses: Shawnchee/the-auditor@v1
        with:
          gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
```

**That's it!** PR Auditor will now run on every PR that touches your smart contracts.

---

## ⚙️ Configuration

### Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `gemini_api_key` | **Yes** | — | Your Google Gemini API key |
| `gemini_model` | No | `gemini-2.5-flash` | Gemini model to use (e.g., `gemini-2.5-pro`) |
| `github_token` | No | `${{ github.token }}` | GitHub token for posting PR comments |
| `slither_args` | No | `""` | Extra arguments for Slither |
| `aderyn_args` | No | `""` | Extra arguments for Aderyn |
| `cargo_audit_args` | No | `""` | Extra arguments for cargo-audit |
| `severity_threshold` | No | `low` | Minimum severity to report: `low`, `medium`, `high`, `critical` |
| `fail_on_findings` | No | `false` | Set to `true` to fail the action when vulnerabilities are found |
| `custom_prompt` | No | `""` | Additional instructions for the Gemini reviewer |
| `include_paths` | No | `""` | Comma-separated globs of paths to include |
| `exclude_paths` | No | `""` | Comma-separated globs of paths to exclude |

### Secrets Setup

You need **one** secret to get started:

| Secret | Required | How to Get It |
|--------|----------|---------------|
| `GEMINI_API_KEY` | **Yes** | [Google AI Studio](https://aistudio.google.com/apikey) |

> **Note:** `GITHUB_TOKEN` is automatically provided by GitHub Actions — you don't need to create it.

---

## 🔬 How It Works

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
2. **Removes false positives** by reading your project's `README.md` to understand business intent
3. **Explains impact** in plain English
4. **Suggests specific code fixes** for each finding
5. **Calculates a Security Score** based on severity and count of findings

---

## 📤 Outputs

Use these outputs in subsequent workflow steps to build custom logic:

| Output | Type | Description |
|--------|------|-------------|
| `vulnerability_count` | `number` | Total findings across all tools |
| `critical_count` | `number` | Critical-severity findings |
| `high_count` | `number` | High-severity findings |
| `medium_count` | `number` | Medium-severity findings |
| `low_count` | `number` | Low/informational findings |
| `security_score` | `number` | Overall score from 0–100 |
| `report_url` | `string` | URL of the posted PR comment |

### Using Outputs to Block Merges

```yaml
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run PR Auditor
        id: audit
        uses: Shawnchee/the-auditor@v1
        with:
          gemini_api_key: ${{ secrets.GEMINI_API_KEY }}

      - name: Block merge if critical findings
        if: steps.audit.outputs.critical_count > 0
        run: |
          echo "❌ Found ${{ steps.audit.outputs.critical_count }} critical vulnerabilities!"
          echo "Security Score: ${{ steps.audit.outputs.security_score }}/100"
          exit 1
```

---

## 📖 Examples

### Basic Usage (Solidity Project)

```yaml
- uses: Shawnchee/the-auditor@v1
  with:
    gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
```

### Advanced Configuration

```yaml
- uses: Shawnchee/the-auditor@v1
  with:
    gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
    gemini_model: "gemini-2.5-pro"
    severity_threshold: "medium"
    fail_on_findings: "true"
    slither_args: "--exclude naming-convention --exclude-informational"
    exclude_paths: "test/**,mocks/**,scripts/**"
    custom_prompt: "This is a DeFi lending protocol. Pay special attention to reentrancy, flash loan attacks, and oracle manipulation."
```

### Solana / Rust Project

```yaml
- uses: Shawnchee/the-auditor@v1
  with:
    gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
    include_paths: "programs/**"
    custom_prompt: "This is a Solana program using Anchor framework. Focus on account validation and PDA security."
```

### Multi-Chain Monorepo

```yaml
- uses: Shawnchee/the-auditor@v1
  with:
    gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
    severity_threshold: "low"
    exclude_paths: "test/**,deploy/**"
    custom_prompt: "This monorepo contains both Solidity (EVM) and Move (Aptos) contracts. Audit each chain independently."
```

### Gate Deployments on Security Score

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

---

## 📸 Example PR Comment

When PR Auditor runs, it posts a comment like this on your PR:

> ## 🛡️ PR Auditor – Security Report
>
> ### 🟡 Security Score: **65/100**
>
> ![Critical](https://img.shields.io/badge/Critical-1-red) ![High](https://img.shields.io/badge/High-2-orange) ![Medium](https://img.shields.io/badge/Medium-3-yellow)
>
> ---
>
> ### 📋 Summary
>
> The contracts contain 1 critical reentrancy vulnerability in the `withdraw()` function, 2 high-severity access control issues, and 3 medium informational findings...
>
> | # | Severity | Category | Title | Confidence |
> |---|----------|----------|-------|------------|
> | F-001 | CRITICAL | Reentrancy | Unprotected external call in withdraw() | HIGH |
> | F-002 | HIGH | Access Control | Missing onlyOwner modifier on setFee() | HIGH |
> | ... | ... | ... | ... | ... |

---

## 🛠️ Error Handling

PR Auditor is designed to be resilient:

| Scenario | Behavior |
|----------|----------|
| **Gemini API is down** | Falls back to raw tool output (still posts results) |
| **Slither fails** | Logs warning, continues with other tools |
| **Aderyn fails** | Logs warning, continues with other tools |
| **cargo-audit fails** | Logs warning, continues with other tools |
| **No contract files found** | Exits cleanly with security score 100 |
| **No Cargo.toml for Rust** | Skips cargo-audit gracefully |

---

## 🏗️ Project Structure

```
the-auditor/
├── action.yml              # GitHub Action metadata & branding
├── Dockerfile              # Multi-stage build (Slither + Aderyn + cargo-audit)
├── entrypoint.sh           # Main orchestration script
├── scripts/
│   ├── detect.sh           # Smart contract file detection
│   ├── run_slither.sh      # Slither runner (Solidity)
│   ├── run_aderyn.sh       # Aderyn runner (Solidity)
│   ├── run_cargo_audit.sh  # cargo-audit runner (Rust/Move)
│   ├── gemini_review.sh    # Gemini AI review integration
│   └── post_review.sh      # PR comment builder & poster
├── .github/
│   └── workflows/
│       └── test.yml        # Self-test CI workflow
├── README.md
├── LICENSE
└── .gitignore
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Built with ❤️ for the Web3 security community**

🛡️ *Stay safe. Audit everything.* 🛡️

</div>

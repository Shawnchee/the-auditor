<div align="center">

# PR Auditor

### Smart Contract Security for Pull Requests

**Automatically audit Solidity, Rust, and Move smart contracts on every PR — powered by static analysis + Gemini AI**

[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

</div>

---

## What is PR Auditor?

PR Auditor is a GitHub Action that reviews your smart contracts for security vulnerabilities every time you open a Pull Request. It runs static analysis tools, sends the results to Google Gemini AI for context-aware review, and posts a detailed report as a PR comment.

| Chain | Extensions | Tools Used |
|-------|-----------|------------|
| **Ethereum / EVM** | `.sol` | [Slither](https://github.com/crytic/slither), [Aderyn](https://github.com/Cyfrin/aderyn) |
| **Solana** | `.rs` | [cargo-audit](https://github.com/RustSec/rustsec) |
| **Aptos / Move** | `.move` | Gemini AI code review |

---

## Quick Start

### 1. Get a Gemini API Key

Go to [Google AI Studio](https://aistudio.google.com/apikey) and create an API key.

### 2. Add the Secret

Go to your repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

- **Name:** `GEMINI_API_KEY`
- **Value:** your API key

### 3. Create the Workflow

Create `.github/workflows/audit.yml`:

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
      - uses: actions/checkout@v4
      - uses: Shawnchee/the-auditor@v1
        with:
          gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
```

That's it. PR Auditor will now run on every PR.

---

## Configuration

| Input | Default | Description |
|-------|---------|-------------|
| `gemini_api_key` | — | **(Required)** Google Gemini API key |
| `gemini_model` | `gemini-2.5-flash` | Gemini model to use |
| `fail_on_findings` | `true` | Fail the check on HIGH or CRITICAL findings |
| `severity_threshold` | `low` | Minimum severity to report |
| `include_raw_output` | `false` | Post a second comment with raw tool output |
| `exclude_paths` | `""` | Comma-separated paths to skip (e.g. `test/**,mocks/**`) |
| `custom_prompt` | `""` | Extra instructions for the AI reviewer |

<details>
<summary>All inputs</summary>

| Input | Default | Description |
|-------|---------|-------------|
| `github_token` | `${{ github.token }}` | Token for posting PR comments |
| `slither_args` | `""` | Extra arguments for Slither |
| `aderyn_args` | `""` | Extra arguments for Aderyn |
| `cargo_audit_args` | `""` | Extra arguments for cargo-audit |
| `include_paths` | `""` | Comma-separated paths to include |

</details>

### Configuration Examples

Add these to the `with:` section of your workflow step.

#### 1. DeFi Protocol (Solidity)
Focus on deep security auditing and skip non-critical findings.

```yaml
      - uses: Shawnchee/the-auditor@v1
        with:
          gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
          severity_threshold: "medium"
          slither_args: "--exclude naming-convention" # Pass extra args to Slither
          exclude_paths: "test/**,mocks/**,scripts/**"
          custom_prompt: "This is a DeFi lending protocol. Focus on reentrancy, flash loan attacks, and oracle manipulation."
```

#### 2. Solana / Anchor (Rust)
Audit programs in specific directories.

```yaml
      - uses: Shawnchee/the-auditor@v1
        with:
          gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
          include_paths: "programs/**"
          custom_prompt: "This is a Solana program using Anchor. Focus on account validation and PDA security."
```

#### 3. Report Only (No Job Failure)
Ideal for adding to existing repos without blocking CI initially.

```yaml
      - uses: Shawnchee/the-auditor@v1
        with:
          gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
          fail_on_findings: "false"
          include_raw_output: "true" # Post extra tool details
```

### Merge Behaviour

| Mode | Config | Effect |
|:---|:---|:---|
| **Warn** (default) | `fail_on_findings: "true"` | ❌ Red X on HIGH/CRITICAL, but devs can still merge |
| **Report only** | `fail_on_findings: "false"` | ✅ Always passes, report is informational |
| **Hard block** | `fail_on_findings: "true"` + Required check | ❌ Cannot merge until resolved |

> To hard-block: Settings → Branches → Branch Protection → **Require status checks** → add `Security Audit`.

---

## Example Output

When PR Auditor runs, it posts a comment like this:

> ### 🛡️ PR Auditor – Security Report
>
> **🟡 Security Score: 65/100**
>
> ![Critical](https://img.shields.io/badge/Critical-1-red) ![High](https://img.shields.io/badge/High-2-orange)
>
> | # | Severity | Title |
> |---|----------|-------|
> | F-001 | CRITICAL | Reentrancy in withdraw() |
> | F-002 | HIGH | Missing access control on setFee() |

---

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

1. Fork the repo
2. Create your branch (`git checkout -b feature/my-feature`)
3. Commit and push
4. Open a Pull Request

For technical docs (architecture, tagging/versioning, project structure), see **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** and **[docs/TAGGING_GUIDE.md](docs/TAGGING_GUIDE.md)**.

---

## License

MIT — see [LICENSE](LICENSE).

<div align="center">

**Built with ❤️ for the Web3 security community**

🛡️ *Stay safe. Audit everything.* 🛡️

</div>

# Contributing to PR Auditor 🛡️

First off, thank you for considering contributing to **PR Auditor**! It's people like you that make the Web3 security ecosystem better for everyone.

Below are the guidelines and steps to help you get started with contributing.

---

## 🚀 Getting Started

### Prerequisites

To work on PR Auditor locally, you will need:
- **Docker Desktop** (to build and test the action container)
- **Git**
- **A Google Gemini API Key** (for testing the AI review logic)

### Local Development Setup

1. **Fork the repository** on GitHub.
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/shawnchee/the-auditor.git
   cd the-auditor
   ```
3. **Build the Docker image**:
   ```bash
   docker build -t pr-auditor:test .
   ```
4. **Run a local test audit**:
   Place some smart contracts in a folder (e.g., the existing `tests/` directory) and run:
   ```bash
   docker run --rm \
     -v $(pwd):/github/workspace \
     -e INPUT_GEMINI_API_KEY="YOUR_API_KEY" \
     -e GITHUB_OUTPUT="/dev/null" \
     pr-auditor:test
   ```

---

## 🛠️ How to Contribute

### Reporting Bugs
- Use the **GitHub Issues** tab.
- Provide a clear title and description.
- Include steps to reproduce the bug.
- Mention which tool (Slither, Aderyn, cargo-audit) or part of the script failed.

### Suggesting Features/Improvements
- Open an Issue to discuss the idea before starting work.
- We are always looking for:
  - Better Gemini prompts for specific DeFi attack vectors.
  - Support for more chains/tools.
  - Performance optimizations in the Bash orchestration.

### Pull Request Process
1. Create a new branch for your feature or fix: `git checkout -b feat/my-cool-feature`.
2. Commit your changes with clear, descriptive messages.
3. Ensure your `Dockerfile` still builds correctly.
4. Update the `README.md` if you changed any inputs or outputs in `action.yml`.
5. Open a Pull Request against the `main` branch.
6. Once merged, follow the [Tagging Guide](docs/TAGGING_GUIDE.md) to update the release tags.

---

## 📂 Project Structure Reminder

- `action.yml`: The entry point for GitHub. Defines inputs/outputs/branding.
- `Dockerfile`: The environment containing Slither, Aderyn, and cargo-audit.
- `entrypoint.sh`: The main script that orchestrates the detection and analysis.
- `scripts/`: Modular bash scripts for specific tasks (detection, tool runners, AI logic).
- `tests/`: Sample vulnerable contracts used for CI and manual verification.

---

## ⚖️ Code of Conduct
Please be respectful and professional in all interactions within this project. We are all here to learn and build better security tools together.

---

**Happy auditing!** 🛡️

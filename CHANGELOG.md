# Changelog

All notable changes to this project will be documented in this file.

## [1.0.1] - 2026-02-28

### Documentation
- **Configuration Guides:** Added detailed examples for Solidity and Rust workflows in the README.
- **Versioning:** Published a new `TAGGING_GUIDE.md` to manage stable and floating release tags.
- **Contributor Docs:** Linked specialized guides in `CONTRIBUTING.md`.

## [1.0.0] - 2026-02-28

Initial release of **PR Auditor**.

### Added
- **AI-Powered Review:** Context-aware security auditing using Google Gemini.
- **Multi-Chain Support:** Native support for Solidity (EVM), Rust (Solana), and Move (Aptos).
- **Tool Suite:** Integrated Slither, Aderyn, and cargo-audit for comprehensive static analysis.
- **Security Scoring:** Consolidated security score (0-100) based on finding severity.
- **Raw Tool Summaries:** Optional concise summaries of raw tool outputs via `include_raw_output`.
- **Recursive Detection:** Automatically finds smart contract projects in subdirectories.
- **Fail behavior:** Customizable `fail_on_findings` that triggers red-X on HIGH/CRITICAL vulnerabilities.

### Fixed
- **Large Report Handling:** Switched to temporary files for JSON payloads to bypass Linux shell `ARG_MAX` limits.
- **Comment Limit Fix:** Implemented 65KB truncation for PR comments to ensure reliability on large audits.
- **cargo-audit Resilience:** Added automated workaround for "unsupported CVSS version: 4.0" errors in the Rust advisory database.
- **Framework Detection:** Fixed Slither analysis for standalone `.sol` files where no framework (Foundry/Hardhat) is present.
- **Aderyn Integration:** Resolved installation and path issues for the Aderyn scanner in Ubuntu environments.
- **AI Accuracy:** Refined system prompts to reduce reentrancy false positives by requiring CEI order verification.

### Documentation
- **Quick Start:** Streamlined the main `README.md` for better developer experience.
- **Architecture:** Added comprehensive technical documentation in `docs/ARCHITECTURE.md`.
- **Project Governance:** Added `CONTRIBUTING.md` and `LICENSE`.
- **Safety Examples:** Replaced vulnerable test contracts with production-grade secure equivalents.

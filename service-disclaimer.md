# Service Disclaimer

By using AI Coding Installer, you acknowledge and agree to the following terms.

## 1. About This Tool

AI Coding Installer is an open-source environment setup helper script. It automates detection of OS environment and installation of:

- Git (open source)
- Node.js (open source)
- pnpm (open source)
- Claude Code (Anthropic commercial product)
- OpenClaw (third-party commercial product)

This tool only executes install commands. It is not a substitute for and is not affiliated with any of the above products.

## 2. Privacy and Data Security

This script strictly observes the following:

| Constraint | Detail |
|------------|--------|
| Does not read passwords | No password acquisition logic |
| Does not save passwords | No password persistence |
| Does not upload passwords | No network upload (except official install sources) |
| Does not read API Keys | Does not read env vars or files containing API Keys |
| Does not save API Keys | Does not write API Keys to any file |
| Does not upload API Keys | No API Key exfiltration path |
| Does not read Tokens | Does not access system keychain or token storage |
| Does not read browser cookies | Does not access browser data |
| Does not read SSH keys | Does not access ~/.ssh |
| Does not read user files | Only writes install report, reads nothing else |

Network requests are limited to official install sources:
- `https://claude.ai/install.sh` — Claude Code official
- `https://claude.ai/install.ps1` — Claude Code official
- `https://openclaw.ai/install.sh` — OpenClaw official
- `https://openclaw.ai/install.ps1` — OpenClaw official
- `https://deb.nodesource.com/setup_lts.x` — NodeSource official
- `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh` — Homebrew official

The install report (`ai-coding-install-report.txt`) is saved locally only and is never uploaded.

## 3. Accounts and API Keys

After Claude Code and OpenClaw are installed, the user must personally complete:
- Anthropic account login
- API Key application, entry, and safekeeping
- OpenClaw account login and configuration

These steps are outside the scope of this script's automation.

## 4. Disclaimer

- This tool is provided "as is" without warranty of any kind.
- The author is not liable for any direct or indirect damages arising from use of this tool.
- Installation may fail due to network issues, system differences, or unavailable software sources.
- This tool does not modify firewall, antivirus, or security policy.
- In remote assistance scenarios, login, verification codes, passwords, and API Keys are entered by the user personally. Service personnel do not ask for, view, or record these.

## 5. Third-Party Software Licenses

Third-party software installed by this tool is subject to their respective licenses:
- Git: GNU General Public License v2
- Node.js: MIT License
- pnpm: MIT License
- Claude Code: Anthropic Terms of Service
- OpenClaw: respective commercial license

*Last updated: 2026-05-12*

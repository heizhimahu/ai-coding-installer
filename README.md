# AI Coding Installer v2.0.0

Claude Code + OpenClaw automated install tool for remote coding environment setup.

## Project Structure

```
ai-coding-installer/
├── install-mac-linux.sh     # macOS / Linux / WSL install script
├── install-windows.ps1      # Windows 10/11 install script
├── README.md
└── service-disclaimer.md    # Service disclaimer
```

## What It Does

- Detects OS type, version, CPU architecture
- Checks for existing tools: Git / Node.js / npm / pnpm / Claude Code / OpenClaw
- Node.js version check: warns if below 22.16 (OpenClaw recommends 24 or 22.16+)
- Installs missing dependencies in dependency order
- Skips already-installed tools
- Shows full install plan before making any changes
- dry-run mode: preview only, no install
- check-only mode: environment check only, no install
- Writes local report: `~/ai-coding-install-report.txt`
- Login, passwords, API Keys must be entered by the user — script never touches them

## Quick Start

### Windows 10/11

```powershell
cd D:\ai-coding-installer
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

.\install-windows.ps1 -DryRun
.\install-windows.ps1 -CheckOnly
.\install-windows.ps1
```

### macOS / Linux / WSL

```bash
chmod +x install-mac-linux.sh

./install-mac-linux.sh --dry-run
./install-mac-linux.sh --check-only
./install-mac-linux.sh
```

## Local Syntax Test

### Bash

```bash
wc -l install-mac-linux.sh
bash -n install-mac-linux.sh
./install-mac-linux.sh --help
./install-mac-linux.sh --check-only
./install-mac-linux.sh --dry-run
```

### PowerShell

```powershell
Get-Content .\install-windows.ps1 | Measure-Object -Line
.\install-windows.ps1 -Help
.\install-windows.ps1 -CheckOnly
.\install-windows.ps1 -DryRun
```

## Install Coverage

| Tool | macOS | Linux | WSL | Windows |
|------|-------|-------|-----|---------|
| Git | brew | pkg manager | pkg manager | winget |
| Node.js LTS | brew | NodeSource/pkg | NodeSource | winget |
| pnpm | npm -g | npm -g | npm -g | npm -g |
| Claude Code | install.sh | install.sh | install.sh | winget/install.ps1 |
| OpenClaw | install.sh | install.sh | install.sh | install.ps1 |

## Security

- Does NOT read, save, or upload passwords / API Keys / Tokens / Cookies
- Does NOT read SSH private keys or user files
- Does NOT auto-login to any account
- Does NOT disable firewall or antivirus
- Does NOT create background services or hidden processes
- Does NOT upload logs
- OpenClaw uses no-onboard mode
- Report saved locally only

See [service-disclaimer.md](./service-disclaimer.md).

## Known Limitations

- Some Linux distros (Alpine, Gentoo) not fully tested
- winget unavailable on older Windows 10 (< 1809)
- No proxy/VPN support
- No offline install support
- No GUI

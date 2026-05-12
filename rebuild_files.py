#!/usr/bin/env python3
"""Rebuild all ai-coding-installer files with proper LF line endings."""

import os
import stat

BASE = os.path.dirname(os.path.abspath(__file__))

def write_file(filename, content):
    path = os.path.join(BASE, filename)
    with open(path, "w", newline="\n", encoding="utf-8") as f:
        f.write(content)
    print(f"  {filename}: {content.count(chr(10))} lines written")
    # chmod +x for shell scripts
    if filename.endswith(".sh"):
        st = os.stat(path)
        os.chmod(path, st.st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
        print(f"    chmod +x applied")

# =====================================================================
# install-mac-linux.sh
# =====================================================================

INSTALL_MAC_LINUX = r'''#!/usr/bin/env bash
# ============================================================
# AI Coding Installer — macOS / Linux / WSL
# Version: 2.0.0
# ============================================================
# Security:
#   - Does NOT read/save/upload passwords / API Keys / Tokens / Cookies
#   - Does NOT modify system security policy
#   - All install steps require user confirmation
#   - Report saved locally only
# ============================================================

set -euo pipefail

DRY_RUN=false
CHECK_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --dry-run|-d)    DRY_RUN=true ;;
        --check-only|-c) CHECK_ONLY=true ;;
        --help|-h)
            echo "Usage: ./install-mac-linux.sh [options]"
            echo ""
            echo "Options:"
            echo "  --dry-run, -d     Check env, show plan, do NOT install"
            echo "  --check-only, -c  Check env, generate report, do NOT install"
            echo "  --help, -h        Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

if [ "$DRY_RUN" = true ] && [ "$CHECK_ONLY" = true ]; then
    echo "Error: --dry-run and --check-only cannot be used together"
    exit 1
fi

# ---- config ----
CLAUDE_INSTALL_URL="https://claude.ai/install.sh"
OPENCLAW_INSTALL_URL="https://openclaw.ai/install.sh"
NODE_NODESOURCE_URL="https://deb.nodesource.com/setup_lts.x"

# ---- state ----
REPORT_FILE="$HOME/ai-coding-install-report.txt"
SUCCESS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0
MISSING_COUNT=0
INSTALL_QUEUE=()
FAIL_LIST=()
OS_TYPE=""
OS_NAME=""
PKG_MANAGER=""
HAS_CURL=false
HAS_GIT=false
HAS_NODE=false
HAS_NPM=false
HAS_PNPM=false
HAS_CLAUDE=false
HAS_OPENCLAW=false
HAS_HOMEBREW=false
NODE_VERSION_LOW=false
NODE_VERSION=""

# ---- helpers ----

init_report() {
    local title="Install Report"
    if [ "$CHECK_ONLY" = true ]; then
        title="[CHECK-ONLY] Environment Check Report"
    elif [ "$DRY_RUN" = true ]; then
        title="[DRY-RUN] Install Preview Report"
    fi
    cat > "$REPORT_FILE" << EOF
==========================================
  AI Coding Installer — ${title}
==========================================
Time: $(date '+%Y-%m-%d %H:%M:%S')
User: $(whoami)
Host: $(hostname)

EOF
}

append_report() { echo "$1" >> "$REPORT_FILE"; }

log_step() {
    local status="$1" message="$2"
    local time_str prefix
    time_str=$(date '+%H:%M:%S')
    case "$status" in
        OK)      prefix="[${time_str}] OK";      SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) ;;
        SKIP)    prefix="[${time_str}] SKIP";     SKIP_COUNT=$((SKIP_COUNT + 1)) ;;
        FAIL)    prefix="[${time_str}] FAIL";     FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
        INFO)    prefix="[${time_str}] INFO" ;;
        MISSING) prefix="[${time_str}] MISSING";  MISSING_COUNT=$((MISSING_COUNT + 1)) ;;
        WARN)    prefix="[${time_str}] WARN" ;;
    esac
    local line="${prefix} ${message}"
    echo "$line"
    append_report "$line"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

get_version() {
    local cmd="$1"
    if command_exists "$cmd"; then
        case "$cmd" in
            git)      git --version 2>&1 | head -1 ;;
            node)     node --version 2>&1 ;;
            npm)      npm --version 2>&1 ;;
            pnpm)     pnpm --version 2>&1 ;;
            claude)   claude --version 2>&1 | head -1 || echo "installed" ;;
            openclaw) openclaw --version 2>&1 | head -1 || echo "installed" ;;
            brew)     brew --version 2>&1 | head -1 ;;
            *)        $cmd --version 2>&1 | head -1 || echo "installed" ;;
        esac
    else
        echo "not installed"
    fi
}

check_node_version() {
    local node_ver
    node_ver=$(node --version 2>/dev/null | sed 's/^v//')
    if [ -z "$node_ver" ]; then return 1; fi
    NODE_VERSION="v${node_ver}"
    local major minor
    major=$(echo "$node_ver" | cut -d. -f1)
    minor=$(echo "$node_ver" | cut -d. -f2)
    if [ "$major" -lt 22 ] 2>/dev/null; then
        NODE_VERSION_LOW=true
        log_step "WARN" "Node.js ${NODE_VERSION} below recommendation. OpenClaw recommends Node 24 or Node 22.16+"
    elif [ "$major" -eq 22 ] && [ "$minor" -lt 16 ] 2>/dev/null; then
        NODE_VERSION_LOW=true
        log_step "WARN" "Node.js ${NODE_VERSION} below recommendation. OpenClaw recommends Node 24 or Node 22.16+"
    fi
}

get_install_command() {
    case "$1" in
        "curl")        echo "install curl via $PKG_MANAGER" ;;
        "Git")
            case "$PKG_MANAGER" in
                brew)   echo "brew install git" ;;
                apt)    echo "sudo apt-get install -y git" ;;
                yum)    echo "sudo yum install -y git" ;;
                dnf)    echo "sudo dnf install -y git" ;;
                pacman) echo "sudo pacman -S --noconfirm git" ;;
                zypper) echo "sudo zypper install -y git" ;;
                *)      echo "install git via $PKG_MANAGER" ;;
            esac ;;
        "Node.js LTS")
            case "$PKG_MANAGER" in
                brew)   echo "brew install node" ;;
                apt)    echo "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs" ;;
                yum)    echo "sudo yum install -y nodejs" ;;
                dnf)    echo "sudo dnf install -y nodejs" ;;
                pacman) echo "sudo pacman -S --noconfirm nodejs npm" ;;
                zypper) echo "sudo zypper install -y nodejs npm" ;;
                *)      echo "install node via $PKG_MANAGER" ;;
            esac ;;
        "pnpm")        echo "npm install -g pnpm (fallback: corepack)" ;;
        "Claude Code") echo "curl -fsSL https://claude.ai/install.sh | bash" ;;
        "OpenClaw")    echo "curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard" ;;
    esac
}

# ---- OS detection ----

detect_os() {
    local kernel arch
    kernel=$(uname -s)
    case "$kernel" in
        Darwin)
            OS_TYPE="macOS"
            OS_NAME="macOS $(sw_vers -productVersion 2>/dev/null || echo 'Unknown')"
            PKG_MANAGER="brew" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                OS_TYPE="WSL"; OS_NAME="WSL"
            else
                OS_TYPE="Linux"
            fi
            if [ -f /etc/os-release ]; then
                local distro version
                distro=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
                version=$(grep "^VERSION_ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
                OS_NAME="${distro} ${version}"
            fi
            detect_pkg_manager ;;
        *)
            echo "Error: unsupported OS: $kernel"
            exit 1 ;;
    esac
    arch=$(uname -m)
    OS_NAME="${OS_NAME} (${arch})"
    echo "OS: ${OS_NAME}"
    append_report "OS: ${OS_NAME}"
}

detect_pkg_manager() {
    if command_exists apt-get; then      PKG_MANAGER="apt"
    elif command_exists dnf; then        PKG_MANAGER="dnf"
    elif command_exists yum; then        PKG_MANAGER="yum"
    elif command_exists pacman; then     PKG_MANAGER="pacman"
    elif command_exists zypper; then     PKG_MANAGER="zypper"
    elif command_exists brew; then       PKG_MANAGER="brew"
    else                                 PKG_MANAGER="unknown"
    fi
}

# ---- environment check (detection only, NEVER installs) ----

detect_tools() {
    echo ""
    echo "--- Environment Check ---"
    append_report ""
    append_report "--- Environment Check ---"

    if command_exists curl; then
        HAS_CURL=true
        log_step "SKIP" "curl: $(get_version curl)"
    else
        HAS_CURL=false
        log_step "MISSING" "curl: not installed"
    fi

    if command_exists git; then
        HAS_GIT=true
        log_step "SKIP" "Git: $(get_version git)"
    else
        HAS_GIT=false
        log_step "MISSING" "Git: not installed"
    fi

    if command_exists node; then
        HAS_NODE=true
        log_step "SKIP" "Node.js: $(get_version node)"
        check_node_version
    else
        HAS_NODE=false
        log_step "MISSING" "Node.js: not installed"
    fi

    if command_exists npm; then
        HAS_NPM=true
        log_step "SKIP" "npm: $(get_version npm)"
    else
        HAS_NPM=false
        log_step "MISSING" "npm: not installed"
    fi

    if command_exists pnpm; then
        HAS_PNPM=true
        log_step "SKIP" "pnpm: $(get_version pnpm)"
    else
        HAS_PNPM=false
        log_step "MISSING" "pnpm: not installed"
    fi

    if command_exists claude; then
        HAS_CLAUDE=true
        log_step "SKIP" "Claude Code: $(get_version claude)"
    else
        HAS_CLAUDE=false
        log_step "MISSING" "Claude Code: not installed"
    fi

    if command_exists openclaw; then
        HAS_OPENCLAW=true
        log_step "SKIP" "OpenClaw: $(get_version openclaw)"
    else
        HAS_OPENCLAW=false
        log_step "MISSING" "OpenClaw: not installed"
    fi

    if [ "$OS_TYPE" = "macOS" ] || [ "$PKG_MANAGER" = "brew" ]; then
        if command_exists brew; then
            HAS_HOMEBREW=true
            log_step "SKIP" "Homebrew: $(get_version brew)"
        else
            HAS_HOMEBREW=false
            log_step "MISSING" "Homebrew: not installed"
        fi
    fi
}

# ---- build install queue ----

build_install_queue() {
    INSTALL_QUEUE=()
    [ "$HAS_CURL" = false ]    && INSTALL_QUEUE+=("curl")
    [ "$HAS_GIT" = false ]     && INSTALL_QUEUE+=("Git")
    [ "$HAS_NODE" = false ]    && INSTALL_QUEUE+=("Node.js LTS")
    [ "$HAS_PNPM" = false ]    && INSTALL_QUEUE+=("pnpm")
    [ "$HAS_CLAUDE" = false ]  && INSTALL_QUEUE+=("Claude Code")
    [ "$HAS_OPENCLAW" = false ] && INSTALL_QUEUE+=("OpenClaw")
}

# ---- show plan and confirm ----

show_plan_and_confirm() {
    echo ""
    if [ "$DRY_RUN" = true ]; then
        echo "=========================================="
        echo "  [DRY-RUN] Install Preview"
        echo "=========================================="
        append_report ""
        append_report "--- [DRY-RUN] Install Preview ---"
    else
        echo "=========================================="
        echo "  Install Plan"
        echo "=========================================="
        append_report ""
        append_report "--- Install Plan ---"
    fi

    if [ ${#INSTALL_QUEUE[@]} -eq 0 ]; then
        echo "All components already installed."
        append_report "All components already installed."
        return 0
    fi

    echo "Will install ${#INSTALL_QUEUE[@]} components:"
    append_report "Will install ${#INSTALL_QUEUE[@]} components:"
    local i=1
    for step in "${INSTALL_QUEUE[@]}"; do
        echo "  ${i}. ${step}"
        append_report "  ${i}. ${step}"
        if [ "$DRY_RUN" = true ]; then
            local cmd
            cmd=$(get_install_command "$step")
            echo "      -> ${cmd}"
            append_report "      -> ${cmd}"
        fi
        i=$((i + 1))
    done

    if [ "$NODE_VERSION_LOW" = true ]; then
        echo ""
        echo "  WARN: Node.js ${NODE_VERSION} below OpenClaw recommendation (24 or 22.16+)."
        echo "  Node will NOT be auto-upgraded."
    fi

    if [ "$DRY_RUN" = true ]; then
        echo ""
        echo "[DRY-RUN] Preview only. No install actions performed."
        echo "Report saved to: ${REPORT_FILE}"
        append_report "[DRY-RUN] Preview only."
        return 1
    fi

    echo ""
    echo "Report will be saved to: ${REPORT_FILE}"
    echo ""
    read -r -p "Confirm installation? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "Cancelled."
        append_report "User cancelled"
        exit 0
    fi
}

# ---- install functions (pipe commands are functions, not string vars) ----

install_claude_official() {
    curl -fsSL "$CLAUDE_INSTALL_URL" | bash
}

install_openclaw_official() {
    curl -fsSL "$OPENCLAW_INSTALL_URL" | bash -s -- --no-onboard
}

install_nodejs_nodesource() {
    curl -fsSL "$NODE_NODESOURCE_URL" | sudo -E bash - && sudo apt-get install -y nodejs
}

install_curl_step() {
    if [ "$HAS_CURL" = true ]; then
        log_step "SKIP" "curl: already installed, skipping"
        return
    fi
    log_step "INFO" "Installing curl..."
    case "$PKG_MANAGER" in
        apt) sudo apt-get install -y curl ;;
        yum) sudo yum install -y curl ;;
        dnf) sudo dnf install -y curl ;;
        *)
            log_step "FAIL" "curl: unknown package manager"
            FAIL_LIST+=("curl")
            return 1 ;;
    esac
    if command_exists curl; then
        HAS_CURL=true
        log_step "OK" "curl: installed ($(get_version curl))"
    else
        log_step "FAIL" "curl: install failed"
        FAIL_LIST+=("curl")
    fi
}

install_homebrew() {
    if [ "$HAS_HOMEBREW" = true ]; then
        log_step "SKIP" "Homebrew: already installed, skipping"
        return
    fi
    log_step "INFO" "Installing Homebrew..."
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        if [ "$(uname -m)" = "arm64" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
        fi
        HAS_HOMEBREW=true
        log_step "OK" "Homebrew: installed ($(get_version brew))"
    else
        log_step "FAIL" "Homebrew: install failed"
        FAIL_LIST+=("Homebrew")
        return 1
    fi
}

install_git() {
    if [ "$HAS_GIT" = true ]; then
        log_step "SKIP" "Git: already installed, skipping"
        return
    fi
    log_step "INFO" "Installing Git..."
    local result=1
    case "$PKG_MANAGER" in
        brew)
            if ! $HAS_HOMEBREW; then install_homebrew; fi
            brew install git && result=0 ;;
        apt)    sudo apt-get update -qq && sudo apt-get install -y git && result=0 ;;
        yum)    sudo yum install -y git && result=0 ;;
        dnf)    sudo dnf install -y git && result=0 ;;
        pacman) sudo pacman -S --noconfirm git && result=0 ;;
        zypper) sudo zypper install -y git && result=0 ;;
        *)
            log_step "FAIL" "Git: unknown package manager"
            FAIL_LIST+=("Git")
            return 1 ;;
    esac
    if [ $result -eq 0 ] && command_exists git; then
        HAS_GIT=true
        log_step "OK" "Git: installed ($(get_version git))"
    else
        log_step "FAIL" "Git: install failed"
        FAIL_LIST+=("Git")
    fi
}

install_nodejs() {
    if [ "$HAS_NODE" = true ]; then
        log_step "SKIP" "Node.js: already installed, skipping"
        return
    fi
    log_step "INFO" "Installing Node.js LTS..."
    local result=1
    case "$PKG_MANAGER" in
        brew)
            if ! $HAS_HOMEBREW; then install_homebrew; fi
            brew install node && result=0 ;;
        apt)    install_nodejs_nodesource && result=0 ;;
        yum|dnf)
            if [ "$PKG_MANAGER" = "dnf" ]; then
                sudo dnf install -y nodejs 2>/dev/null && result=0
            else
                sudo yum install -y nodejs 2>/dev/null && result=0
            fi ;;
        pacman) sudo pacman -S --noconfirm nodejs npm && result=0 ;;
        zypper) sudo zypper install -y nodejs npm && result=0 ;;
        *)
            log_step "FAIL" "Node.js: unknown package manager"
            FAIL_LIST+=("Node.js")
            return 1 ;;
    esac
    if [ $result -eq 0 ] && command_exists node; then
        HAS_NODE=true
        HAS_NPM=true
        log_step "OK" "Node.js: installed ($(get_version node))"
        log_step "OK" "npm: bundled ($(get_version npm))"
    else
        log_step "FAIL" "Node.js: install failed"
        FAIL_LIST+=("Node.js")
    fi
}

install_pnpm() {
    if [ "$HAS_PNPM" = true ]; then
        log_step "SKIP" "pnpm: already installed, skipping"
        return
    fi
    if ! command_exists npm; then
        log_step "FAIL" "pnpm: npm required first"
        FAIL_LIST+=("pnpm")
        return
    fi
    log_step "INFO" "Installing pnpm..."
    if npm install -g pnpm; then
        HAS_PNPM=true
        log_step "OK" "pnpm: installed ($(get_version pnpm))"
    else
        if corepack enable 2>/dev/null && corepack prepare pnpm@latest --activate 2>/dev/null; then
            HAS_PNPM=true
            log_step "OK" "pnpm: installed via corepack ($(get_version pnpm))"
        else
            log_step "FAIL" "pnpm: install failed"
            FAIL_LIST+=("pnpm")
        fi
    fi
}

install_claude() {
    if [ "$HAS_CLAUDE" = true ]; then
        log_step "SKIP" "Claude Code: already installed, skipping"
        return
    fi
    if ! command_exists curl; then
        log_step "FAIL" "Claude Code: curl required but not found"
        FAIL_LIST+=("Claude Code")
        return
    fi
    log_step "INFO" "Installing Claude Code (official script)..."
    if install_claude_official; then
        if command_exists claude; then
            HAS_CLAUDE=true
            log_step "OK" "Claude Code: installed ($(get_version claude))"
        else
            HAS_CLAUDE=true
            log_step "OK" "Claude Code: install done (may need terminal restart)"
        fi
        echo ""
        echo "  NOTE: Run 'claude' to complete first-time setup."
        echo "  Login and API Key must be entered by you personally."
        echo "  Service provider does not ask for or record these."
    else
        log_step "FAIL" "Claude Code: install failed"
        FAIL_LIST+=("Claude Code")
    fi
}

install_openclaw() {
    if [ "$HAS_OPENCLAW" = true ]; then
        log_step "SKIP" "OpenClaw: already installed, skipping"
        return
    fi
    if ! command_exists curl; then
        log_step "FAIL" "OpenClaw: curl required but not found"
        FAIL_LIST+=("OpenClaw")
        return
    fi
    log_step "INFO" "Installing OpenClaw (official script, no-onboard)..."
    if install_openclaw_official; then
        if command_exists openclaw; then
            HAS_OPENCLAW=true
            log_step "OK" "OpenClaw: installed ($(get_version openclaw))"
        else
            HAS_OPENCLAW=true
            log_step "OK" "OpenClaw: install done (may need terminal restart)"
        fi
        echo ""
        echo "  NOTE: Run 'openclaw' to complete onboarding."
        echo "  Onboarding, login, API Key must be done by you personally."
        echo "  Service provider does not ask for or record these."
    else
        log_step "FAIL" "OpenClaw: install failed"
        FAIL_LIST+=("OpenClaw")
    fi
}

# ---- execute ----

execute_install() {
    echo ""
    echo "=========================================="
    echo "  Installing"
    echo "=========================================="
    append_report ""
    append_report "--- Install Process ---"
    for step in "${INSTALL_QUEUE[@]}"; do
        echo ""
        case "$step" in
            "curl")        install_curl_step ;;
            "Git")         install_git ;;
            "Node.js LTS") install_nodejs ;;
            "pnpm")        install_pnpm ;;
            "Claude Code") install_claude ;;
            "OpenClaw")    install_openclaw ;;
        esac
    done
}

# ---- summary ----

show_summary() {
    echo ""
    if [ "$CHECK_ONLY" = true ]; then
        echo "=========================================="
        echo "  Environment Check Summary"
        echo "=========================================="
        append_report ""
        append_report "--- Environment Check Summary ---"
        echo "Ready: ${SKIP_COUNT}, Missing: ${MISSING_COUNT}"
        append_report "Ready: ${SKIP_COUNT}, Missing: ${MISSING_COUNT}"
    elif [ "$DRY_RUN" = true ]; then
        echo "=========================================="
        echo "  Preview Summary"
        echo "=========================================="
        append_report ""
        append_report "--- Preview Summary ---"
        echo "To install: ${#INSTALL_QUEUE[@]}, Ready: ${SKIP_COUNT}, Missing: ${MISSING_COUNT}"
        append_report "To install: ${#INSTALL_QUEUE[@]}, Ready: ${SKIP_COUNT}, Missing: ${MISSING_COUNT}"
        echo ""
        echo "[DRY-RUN] No install actions performed."
        append_report "[DRY-RUN] No install actions performed."
    else
        echo "=========================================="
        echo "  Install Summary"
        echo "=========================================="
        append_report ""
        append_report "--- Install Summary ---"
        echo "OK: ${SUCCESS_COUNT}, Skip: ${SKIP_COUNT}, Missing: ${MISSING_COUNT}, Fail: ${FAIL_COUNT}"
        append_report "OK: ${SUCCESS_COUNT}, Skip: ${SKIP_COUNT}, Missing: ${MISSING_COUNT}, Fail: ${FAIL_COUNT}"
        if [ ${#FAIL_LIST[@]} -gt 0 ]; then
            echo ""
            echo "Failed components:"
            append_report "Failed:"
            for item in "${FAIL_LIST[@]}"; do
                echo "  - ${item}"
                append_report "  - ${item}"
            done
            echo ""
            echo "Please install failed components manually and re-run."
        fi
    fi
    echo ""
    echo "Full report saved to: ${REPORT_FILE}"
    append_report ""
    append_report "=========================================="
    append_report "End of report"
}

show_next_steps() {
    if [ "$CHECK_ONLY" = true ] || [ "$DRY_RUN" = true ]; then return; fi
    echo ""
    echo "=========================================="
    echo "  Next Steps"
    echo "=========================================="
    echo ""
    echo "  The following must be done by the user personally:"
    echo ""
    echo "  1. Claude Code first-time setup:"
    echo "      Run: claude"
    echo "      - Login to Anthropic account"
    echo "      - Enter API Key"
    echo ""
    echo "  2. OpenClaw onboarding:"
    echo "      Run: openclaw"
    echo "      - Complete onboarding"
    echo "      - Login and configure API Key"
    echo ""
    echo "  3. Verify installation:"
    echo "      git --version; node --version; npm --version"
    echo "      pnpm --version; claude --version; openclaw --version"
    echo ""
    echo "  Login, passwords, API Keys must be entered by the user."
    echo "  Service provider does not ask for or record these."
    echo ""
    append_report ""
    append_report "--- Next Steps ---"
    append_report "User must complete first-time login setup manually"
}

# ---- main ----

main() {
    clear 2>/dev/null || true
    echo "=========================================="
    echo "  AI Coding Installer v2.0.0"
    echo "  macOS / Linux / WSL"
    if [ "$DRY_RUN" = true ]; then
        echo "  Mode: DRY-RUN (preview only)"
    elif [ "$CHECK_ONLY" = true ]; then
        echo "  Mode: CHECK-ONLY (environment only)"
    fi
    echo "=========================================="
    echo ""
    init_report
    detect_os
    detect_tools
    if [ "$CHECK_ONLY" = true ]; then
        show_summary
        exit 0
    fi
    build_install_queue
    if show_plan_and_confirm; then
        execute_install
    fi
    show_summary
    show_next_steps
}

main "$@"
'''

# =====================================================================
# install-windows.ps1
# =====================================================================

INSTALL_WINDOWS = r'''# ============================================================
# AI Coding Installer — Windows 10/11
# Version: 2.0.0
# ============================================================
# Security:
#   - Does NOT read/save/upload passwords / API Keys / Tokens / Cookies
#   - Does NOT modify system security policy
#   - All install steps require user confirmation
#   - Report saved locally only
# ============================================================

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$CheckOnly,
    [switch]$Help
)

if ($Help) {
    Write-Host "Usage: .\install-windows.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -DryRun       Check env, show plan, do NOT install"
    Write-Host "  -CheckOnly    Check env, generate report, do NOT install"
    Write-Host "  -Help         Show this help"
    exit 0
}

if ($DryRun -and $CheckOnly) {
    Write-Host "Error: -DryRun and -CheckOnly cannot be used together"
    exit 1
}

# ---- config ----
$ClaudeInstallUrl = "https://claude.ai/install.ps1"
$ClaudeInstallWinget = "winget install --id Anthropic.ClaudeCode -e --source winget --accept-source-agreements"
$OpenClawInstallUrl = "https://openclaw.ai/install.ps1"
$GitInstallWinget = "winget install --id Git.Git -e --source winget --accept-source-agreements"
$NodeInstallWinget = "winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements"
$PnpmInstallNpm = "npm install -g pnpm"

# ---- state ----
$ReportFile = Join-Path $env:USERPROFILE "ai-coding-install-report.txt"
$Script:SuccessCount = 0
$Script:SkipCount = 0
$Script:FailCount = 0
$Script:MissingCount = 0
$Script:FailList = @()
$Script:InstallQueue = @()
$Script:HasWinget = $false
$Script:HasGit = $false
$Script:HasNode = $false
$Script:HasNpm = $false
$Script:HasPnpm = $false
$Script:HasClaude = $false
$Script:HasOpenClaw = $false
$Script:IsAdmin = $false
$Script:NodeVersionLow = $false
$Script:NodeVersion = ""

# ---- helpers ----

function Init-Report {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $osInfo = Get-CimInstance Win32_OperatingSystem
    if ($CheckOnly) {
        $title = "[CHECK-ONLY] Environment Check Report"
    } elseif ($DryRun) {
        $title = "[DRY-RUN] Install Preview Report"
    } else {
        $title = "Install Report"
    }
    $content = @"
==========================================
  AI Coding Installer — ${title}
==========================================
Time: $timestamp
User: $env:USERNAME
Host: $env:COMPUTERNAME
System: $($osInfo.Caption)

"@
    $content | Out-File -FilePath $ReportFile -Encoding utf8
}

function Append-Report {
    param([string]$Message)
    Add-Content -Path $ReportFile -Value $Message -Encoding utf8
}

function Write-Log {
    param(
        [ValidateSet("OK", "SKIP", "FAIL", "INFO", "MISSING", "WARN")]
        [string]$Status,
        [string]$Message
    )
    $timeStr = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($Status) {
        "OK"      { $Script:SuccessCount++; "[$timeStr] OK" }
        "SKIP"    { $Script:SkipCount++;    "[$timeStr] SKIP" }
        "FAIL"    { $Script:FailCount++;    "[$timeStr] FAIL" }
        "INFO"    {                        "[$timeStr] INFO" }
        "MISSING" { $Script:MissingCount++; "[$timeStr] MISSING" }
        "WARN"    {                        "[$timeStr] WARN" }
    }
    $line = "$prefix $Message"
    Write-Host $line
    Append-Report $line
}

function Test-Command {
    param([string]$CommandName)
    return (Get-Command $CommandName -ErrorAction SilentlyContinue) -ne $null
}

function Get-ToolVersion {
    param([string]$CommandName)
    if (-not (Test-Command $CommandName)) { return "not installed" }
    try {
        $output = & $CommandName --version 2>&1 | Select-Object -First 1
        return $output.ToString().Trim()
    } catch {
        return "installed (version unknown)"
    }
}

function Get-InstallCommand {
    param([string]$StepName)
    switch ($StepName) {
        "Git"          { return $GitInstallWinget }
        "Node.js LTS"  { return $NodeInstallWinget }
        "pnpm"         { return $PnpmInstallNpm + " (fallback: corepack)" }
        "Claude Code"  { return "prefer: $ClaudeInstallWinget ; fallback: iwr -useb $ClaudeInstallUrl | iex" }
        "OpenClaw"     { return "& ([scriptblock]::Create((iwr -useb $OpenClawInstallUrl))) -NoOnboard" }
    }
}

# ---- OS detection ----

function Detect-OS {
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $build = $osInfo.BuildNumber
    $version = $osInfo.Version
    $arch = if ([System.Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    Write-Host "OS: $($osInfo.Caption) ($arch)"
    Write-Host "Version: $version (Build $build)"
    Append-Report "OS: $($osInfo.Caption) ($arch)"
    Append-Report "Version: $version (Build $build)"
    if ([int]$build -lt 10240) {
        Write-Host "Warning: older Windows version detected"
    }
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    $Script:IsAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($Script:IsAdmin) {
        Write-Host "Mode: Administrator"
    } else {
        Write-Host "Mode: User (some installs may need admin)"
    }
}

# ---- Node version check ----

function Test-NodeVersion {
    param([string]$VersionString)
    if ($VersionString -eq "not installed" -or $VersionString -match "unknown") { return }
    $ver = $VersionString -replace '^v', ''
    $parts = $ver -split '\.'
    if ($parts.Count -lt 2) { return }
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $Script:NodeVersion = $VersionString
    if ($major -gt 22 -or ($major -eq 22 -and $minor -ge 16)) { return }
    $Script:NodeVersionLow = $true
    Write-Log "WARN" "Node.js $VersionString below recommendation. OpenClaw recommends Node 24 or Node 22.16+"
}

# ---- environment check (detection only, NEVER installs) ----

function Detect-Tools {
    Write-Host ""
    Write-Host "--- Environment Check ---"
    Append-Report ""
    Append-Report "--- Environment Check ---"

    if (Test-Command winget) {
        $Script:HasWinget = $true
        Write-Log "SKIP" "WinGet: $(Get-ToolVersion winget)"
    } else {
        $Script:HasWinget = $false
        Write-Log "MISSING" "WinGet: not installed (install App Installer for winget)"
    }

    if (Test-Command git) {
        $Script:HasGit = $true
        Write-Log "SKIP" "Git: $(Get-ToolVersion git)"
    } else {
        $Script:HasGit = $false
        Write-Log "MISSING" "Git: not installed"
    }

    if (Test-Command node) {
        $Script:HasNode = $true
        $nodeVersion = Get-ToolVersion node
        Write-Log "SKIP" "Node.js: $nodeVersion"
        Test-NodeVersion $nodeVersion
    } else {
        $Script:HasNode = $false
        Write-Log "MISSING" "Node.js: not installed"
    }

    if (Test-Command npm) {
        $Script:HasNpm = $true
        Write-Log "SKIP" "npm: $(Get-ToolVersion npm)"
    } else {
        $Script:HasNpm = $false
        Write-Log "MISSING" "npm: not installed"
    }

    if (Test-Command pnpm) {
        $Script:HasPnpm = $true
        Write-Log "SKIP" "pnpm: $(Get-ToolVersion pnpm)"
    } else {
        $Script:HasPnpm = $false
        Write-Log "MISSING" "pnpm: not installed"
    }

    if (Test-Command claude) {
        $Script:HasClaude = $true
        Write-Log "SKIP" "Claude Code: $(Get-ToolVersion claude)"
    } else {
        $Script:HasClaude = $false
        Write-Log "MISSING" "Claude Code: not installed"
    }

    if (Test-Command openclaw) {
        $Script:HasOpenClaw = $true
        Write-Log "SKIP" "OpenClaw: $(Get-ToolVersion openclaw)"
    } else {
        $Script:HasOpenClaw = $false
        Write-Log "MISSING" "OpenClaw: not installed"
    }
}

# ---- build install queue ----

function Build-InstallQueue {
    $Script:InstallQueue = @()
    if (-not $Script:HasGit)      { $Script:InstallQueue += "Git" }
    if (-not $Script:HasNode)     { $Script:InstallQueue += "Node.js LTS" }
    if (-not $Script:HasPnpm)     { $Script:InstallQueue += "pnpm" }
    if (-not $Script:HasClaude)   { $Script:InstallQueue += "Claude Code" }
    if (-not $Script:HasOpenClaw) { $Script:InstallQueue += "OpenClaw" }
}

# ---- show plan and confirm ----

function Show-PlanAndConfirm {
    Write-Host ""
    if ($DryRun) {
        Write-Host "=========================================="
        Write-Host "  [DRY-RUN] Install Preview"
        Write-Host "=========================================="
        Append-Report ""
        Append-Report "--- [DRY-RUN] Install Preview ---"
    } else {
        Write-Host "=========================================="
        Write-Host "  Install Plan"
        Write-Host "=========================================="
        Append-Report ""
        Append-Report "--- Install Plan ---"
    }
    if ($Script:InstallQueue.Count -eq 0) {
        Write-Host "All components already installed."
        Append-Report "All components already installed."
        return $true
    }
    Write-Host "Will install $($Script:InstallQueue.Count) components:"
    Append-Report "Will install $($Script:InstallQueue.Count) components:"
    for ($i = 0; $i -lt $Script:InstallQueue.Count; $i++) {
        $num = $i + 1
        $step = $Script:InstallQueue[$i]
        Write-Host "  ${num}. $step"
        Append-Report "  ${num}. $step"
        if ($DryRun) {
            $cmd = Get-InstallCommand $step
            Write-Host "      -> $cmd"
            Append-Report "      -> $cmd"
        }
    }
    if ($Script:NodeVersionLow) {
        Write-Host ""
        Write-Host "  WARN: Node.js $Script:NodeVersion below OpenClaw recommendation (24 or 22.16+)."
        Write-Host "  Node will NOT be auto-upgraded."
    }
    if ($DryRun) {
        Write-Host ""
        Write-Host "[DRY-RUN] Preview only. No install actions performed."
        Write-Host "Report saved to: $ReportFile"
        Append-Report "[DRY-RUN] Preview only."
        return $false
    }
    Write-Host ""
    Write-Host "Report will be saved to: $ReportFile"
    Write-Host ""
    $confirm = Read-Host "Confirm installation? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Cancelled."
        Append-Report "User cancelled"
        return $false
    }
    return $true
}

# ---- install functions ----

function Install-Git {
    if ($Script:HasGit) {
        Write-Log "SKIP" "Git: already installed, skipping"
        return
    }
    Write-Log "INFO" "Installing Git..."
    if (-not $Script:HasWinget) {
        Write-Log "FAIL" "Git: WinGet required but not found"
        Write-Host "        Manual install: https://git-scm.com/download/win"
        $Script:FailList += "Git"
        return
    }
    try {
        $result = Invoke-Expression $GitInstallWinget 2>&1
        if ($LASTEXITCODE -eq 0 -and (Test-Command git)) {
            $Script:HasGit = $true
            Write-Log "OK" "Git: installed ($(Get-ToolVersion git))"
        } else {
            throw "install failed"
        }
    } catch {
        Write-Log "FAIL" "Git: install failed"
        $Script:FailList += "Git"
    }
}

function Install-NodeJS {
    if ($Script:HasNode) {
        Write-Log "SKIP" "Node.js: already installed, skipping"
        return
    }
    Write-Log "INFO" "Installing Node.js LTS..."
    if (-not $Script:HasWinget) {
        Write-Log "FAIL" "Node.js: WinGet required but not found"
        Write-Host "        Manual install: https://nodejs.org/"
        $Script:FailList += "Node.js"
        return
    }
    try {
        $result = Invoke-Expression $NodeInstallWinget 2>&1
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path", "User")
        if ((Test-Command node)) {
            $Script:HasNode = $true
            $Script:HasNpm = $true
            Write-Log "OK" "Node.js: installed ($(Get-ToolVersion node))"
            Write-Log "OK" "npm: bundled ($(Get-ToolVersion npm))"
        } else {
            throw "node command not found after install"
        }
    } catch {
        Write-Log "FAIL" "Node.js: install failed"
        $Script:FailList += "Node.js"
    }
}

function Install-Pnpm {
    if ($Script:HasPnpm) {
        Write-Log "SKIP" "pnpm: already installed, skipping"
        return
    }
    if (-not (Test-Command npm)) {
        Write-Log "FAIL" "pnpm: npm required first"
        $Script:FailList += "pnpm"
        return
    }
    Write-Log "INFO" "Installing pnpm..."
    try {
        $result = Invoke-Expression $PnpmInstallNpm 2>&1
        if ($LASTEXITCODE -eq 0 -and (Test-Command pnpm)) {
            $Script:HasPnpm = $true
            Write-Log "OK" "pnpm: installed ($(Get-ToolVersion pnpm))"
        } else {
            Write-Host "        npm install failed, trying corepack..."
            corepack enable 2>$null
            corepack prepare pnpm@latest --activate 2>$null
            if (Test-Command pnpm) {
                $Script:HasPnpm = $true
                Write-Log "OK" "pnpm: installed via corepack ($(Get-ToolVersion pnpm))"
            } else {
                throw "install failed"
            }
        }
    } catch {
        Write-Log "FAIL" "pnpm: install failed"
        $Script:FailList += "pnpm"
    }
}

function Install-Claude {
    if ($Script:HasClaude) {
        Write-Log "SKIP" "Claude Code: already installed, skipping"
        return
    }
    if ($Script:HasWinget) {
        Write-Log "INFO" "Installing Claude Code via WinGet..."
        try {
            $result = Invoke-Expression $ClaudeInstallWinget 2>&1
            if ($LASTEXITCODE -eq 0) {
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                            [System.Environment]::GetEnvironmentVariable("Path", "User")
                if (Test-Command claude) {
                    $Script:HasClaude = $true
                    Write-Log "OK" "Claude Code: installed ($(Get-ToolVersion claude))"
                } else {
                    $Script:HasClaude = $true
                    Write-Log "OK" "Claude Code: install done (may need terminal restart)"
                }
                Show-ClaudePostInstall
                return
            }
        } catch {
            Write-Host "        WinGet failed, trying official script..."
        }
    }
    Write-Log "INFO" "Installing Claude Code via official script..."
    try {
        $scriptContent = Invoke-RestMethod -Uri $ClaudeInstallUrl
        Invoke-Expression $scriptContent
        if ($LASTEXITCODE -eq 0 -or $?) {
            if (Test-Command claude) {
                $Script:HasClaude = $true
                Write-Log "OK" "Claude Code: installed ($(Get-ToolVersion claude))"
            } else {
                $Script:HasClaude = $true
                Write-Log "OK" "Claude Code: install done (may need terminal restart)"
            }
            Show-ClaudePostInstall
        } else {
            throw "script returned non-zero"
        }
    } catch {
        Write-Log "FAIL" "Claude Code: install failed"
        $Script:FailList += "Claude Code"
    }
}

function Show-ClaudePostInstall {
    Write-Host ""
    Write-Host "  NOTE: Run 'claude' to complete first-time setup."
    Write-Host "  Login and API Key must be entered by you personally."
    Write-Host "  Service provider does not ask for or record these."
}

function Install-OpenClaw {
    if ($Script:HasOpenClaw) {
        Write-Log "SKIP" "OpenClaw: already installed, skipping"
        return
    }
    Write-Log "INFO" "Installing OpenClaw via official script (no-onboard)..."
    try {
        $scriptContent = Invoke-RestMethod -Uri $OpenClawInstallUrl
        & ([scriptblock]::Create($scriptContent)) -NoOnboard
        if ($LASTEXITCODE -eq 0 -or $?) {
            if (Test-Command openclaw) {
                $Script:HasOpenClaw = $true
                Write-Log "OK" "OpenClaw: installed ($(Get-ToolVersion openclaw))"
            } else {
                $Script:HasOpenClaw = $true
                Write-Log "OK" "OpenClaw: install done (may need terminal restart)"
            }
            Show-OpenClawPostInstall
        } else {
            throw "script returned non-zero"
        }
    } catch {
        Write-Log "FAIL" "OpenClaw: install failed"
        $Script:FailList += "OpenClaw"
    }
}

function Show-OpenClawPostInstall {
    Write-Host ""
    Write-Host "  NOTE: Run 'openclaw' to complete onboarding."
    Write-Host "  Onboarding, login, API Key must be done by you personally."
    Write-Host "  Service provider does not ask for or record these."
}

# ---- execute ----

function Execute-Install {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  Installing"
    Write-Host "=========================================="
    Append-Report ""
    Append-Report "--- Install Process ---"
    foreach ($step in $Script:InstallQueue) {
        Write-Host ""
        switch ($step) {
            "Git"          { Install-Git }
            "Node.js LTS"  { Install-NodeJS }
            "pnpm"         { Install-Pnpm }
            "Claude Code"  { Install-Claude }
            "OpenClaw"     { Install-OpenClaw }
        }
    }
}

# ---- summary and next steps ----

function Show-Summary {
    Write-Host ""
    if ($CheckOnly) {
        Write-Host "=========================================="
        Write-Host "  Environment Check Summary"
        Write-Host "=========================================="
        Append-Report ""
        Append-Report "--- Environment Check Summary ---"
        Write-Host "Ready: $SkipCount, Missing: $MissingCount"
        Append-Report "Ready: $SkipCount, Missing: $MissingCount"
    } elseif ($DryRun) {
        Write-Host "=========================================="
        Write-Host "  Preview Summary"
        Write-Host "=========================================="
        Append-Report ""
        Append-Report "--- Preview Summary ---"
        Write-Host "To install: $($Script:InstallQueue.Count), Ready: $SkipCount, Missing: $MissingCount"
        Append-Report "To install: $($Script:InstallQueue.Count), Ready: $SkipCount, Missing: $MissingCount"
        Write-Host ""
        Write-Host "[DRY-RUN] No install actions performed."
        Append-Report "[DRY-RUN] No install actions performed."
    } else {
        Write-Host "=========================================="
        Write-Host "  Install Summary"
        Write-Host "=========================================="
        Append-Report ""
        Append-Report "--- Install Summary ---"
        Write-Host "OK: $SuccessCount, Skip: $SkipCount, Missing: $MissingCount, Fail: $FailCount"
        Append-Report "OK: $SuccessCount, Skip: $SkipCount, Missing: $MissingCount, Fail: $FailCount"
        if ($Script:FailList.Count -gt 0) {
            Write-Host ""
            Write-Host "Failed components:"
            Append-Report "Failed:"
            foreach ($item in $Script:FailList) {
                Write-Host "  - $item"
                Append-Report "  - $item"
            }
            Write-Host ""
            Write-Host "Please install failed components manually and re-run."
        }
    }
    Write-Host ""
    Write-Host "Full report saved to: $ReportFile"
    Append-Report ""
    Append-Report "=========================================="
    Append-Report "End of report"
}

function Show-NextSteps {
    if ($CheckOnly -or $DryRun) { return }
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  Next Steps"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "  The following must be done by the user personally:"
    Write-Host ""
    Write-Host "  1. Claude Code first-time setup:"
    Write-Host "      Run: claude"
    Write-Host "      - Login to Anthropic account"
    Write-Host "      - Enter API Key"
    Write-Host ""
    Write-Host "  2. OpenClaw onboarding:"
    Write-Host "      Run: openclaw"
    Write-Host "      - Complete onboarding"
    Write-Host "      - Login and configure API Key"
    Write-Host ""
    Write-Host "  3. Verify installation:"
    Write-Host "      git --version; node --version; npm --version"
    Write-Host "      pnpm --version; claude --version; openclaw --version"
    Write-Host ""
    Write-Host "  Login, passwords, API Keys must be entered by the user."
    Write-Host "  Service provider does not ask for or record these."
    Write-Host ""
    Append-Report ""
    Append-Report "--- Next Steps ---"
    Append-Report "User must complete first-time login setup manually"
}

# ---- main ----

function Main {
    Clear-Host
    Write-Host "=========================================="
    Write-Host "  AI Coding Installer v2.0.0"
    Write-Host "  Windows 10/11"
    if ($DryRun) {
        Write-Host "  Mode: DRY-RUN (preview only)"
    } elseif ($CheckOnly) {
        Write-Host "  Mode: CHECK-ONLY (environment only)"
    }
    Write-Host "=========================================="
    Write-Host ""
    Init-Report
    Detect-OS
    Detect-Tools
    if ($CheckOnly) {
        Show-Summary
        return
    }
    Build-InstallQueue
    $confirmed = Show-PlanAndConfirm
    if ($confirmed) {
        Execute-Install
    }
    Show-Summary
    Show-NextSteps
}

Main
'''

# =====================================================================
# README.md
# =====================================================================

README = r'''# AI Coding Installer v2.0.0

Claude Code + OpenClaw automated install tool for remote coding environment setup.

## Project Structure

```
ai-coding-installer/
├── rebuild_files.py         # Python rebuild script (this generates all files)
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
- Login, passwords, API Keys must be entered by the user

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

## Rebuild Files

All files are generated by `rebuild_files.py`. To rebuild:

```bash
python3 rebuild_files.py
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
'''

# =====================================================================
# service-disclaimer.md
# =====================================================================

SERVICE_DISCLAIMER = r'''# Service Disclaimer

By using AI Coding Installer, you acknowledge and agree to the following terms.

---

## 1. About This Tool

AI Coding Installer is an open-source environment setup helper script. It automates detection of your OS environment and installation of:

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

Network requests are limited to the following official sources:

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

These steps are outside the scope of this script's automation. The script only provides terminal reminders after installation. The user is responsible for:

- API Key confidentiality
- API usage billing management
- Account security

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

Users should read and agree to these terms before use.

---

*Last updated: 2026-05-12*
'''

# =====================================================================
# Main
# =====================================================================

if __name__ == "__main__":
    print("Rebuilding files with LF line endings...")
    write_file("install-mac-linux.sh", INSTALL_MAC_LINUX)
    write_file("install-windows.ps1", INSTALL_WINDOWS)
    write_file("README.md", README)
    write_file("service-disclaimer.md", SERVICE_DISCLAIMER)
    print("Done.")

# ============================================================
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

# ============================================================
# AI Coding Installer — Windows 10/11 安装脚本
# 版本: 1.3.0
# 用途: 三档服务套餐安装 Claude Code + OpenClaw 所需依赖
# ============================================================
# 安全声明:
#   - 本脚本不读取、不保存、不上传任何密码/API Key/Token/Cookie
#   - 本脚本不修改系统安全策略（防火墙/杀毒软件/注册表）
#   - 所有安装步骤均在用户确认后执行
#   - 安装报告仅保存在本地用户目录
# ============================================================

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$CheckOnly
)

if ($DryRun -and $CheckOnly) {
    Write-Host "错误: -DryRun 和 -CheckOnly 不能同时使用"
    exit 1
}

# ============================================================
# 安装命令配置区
# ============================================================

$ClaudeInstallUrl = "https://claude.ai/install.ps1"
$ClaudeInstallWinget = "winget install --id Anthropic.ClaudeCode -e --source winget --accept-source-agreements"

$OpenClawInstallUrl = "https://openclaw.ai/install.ps1"

$GitInstallWinget = "winget install --id Git.Git -e --source winget --accept-source-agreements"

$NodeInstallWinget = "winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements"

$PnpmInstallNpm = "npm install -g pnpm"

# ============================================================
# 全局变量
# ============================================================
$ReportFile = Join-Path $env:USERPROFILE "ai-coding-install-report.txt"
$Script:SuccessCount = 0
$Script:SkipCount = 0
$Script:FailCount = 0
$Script:MissingCount = 0
$Script:FailList = @()
$Script:InstallQueue = @()

# 环境检测结果
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
$Script:NeedNodeUpgrade = $false

# 套餐选择
$Script:PlanChoice = 0
$Script:PlanName = ""
$Script:PlanPrice = ""
$Script:PlanSupport = ""
$Script:PlanTutorial = $true
$Script:PlanWorkflowCount = 0
$Script:InstallClaude = $false
$Script:InstallOpenClaw = $false
$Script:ToolChoiceName = ""

# ============================================================
# 工具函数
# ============================================================

function Init-Report {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $osInfo = Get-CimInstance Win32_OperatingSystem

    if ($CheckOnly) {
        $title = "[CHECK-ONLY] 环境检测报告"
    } elseif ($DryRun) {
        $title = "[DRY-RUN] 安装预览报告"
    } else {
        $title = "安装报告"
    }

    $content = @"
==========================================
  AI Coding Installer — ${title}
==========================================
生成时间: $timestamp
用户: $env:USERNAME
主机: $env:COMPUTERNAME
系统: $($osInfo.Caption)

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
        "Node.js LTS"  { if ($Script:NeedNodeUpgrade) { return $NodeInstallWinget + " (upgrade)" } else { return $NodeInstallWinget } }
        "pnpm"         { return $PnpmInstallNpm + " (fallback: corepack)" }
        "Claude Code"  { return "prefer: $ClaudeInstallWinget ; fallback: iwr -useb $ClaudeInstallUrl | iex" }
        "OpenClaw"     { return "& ([scriptblock]::Create((iwr -useb $OpenClawInstallUrl))) -NoOnboard" }
    }
}

# ============================================================
# 系统检测
# ============================================================

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
        Write-Host "Warning: older Windows version detected, some features may not work"
    }

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $Script:IsAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($Script:IsAdmin) {
        Write-Host "Mode: Administrator"
    } else {
        Write-Host "Mode: User (some installs may need admin)"
    }
}

# ============================================================
# Node version check
# ============================================================

function Test-NodeVersion {
    param([string]$VersionString)
    if ($VersionString -eq "not installed" -or $VersionString -match "unknown") {
        return
    }
    $ver = $VersionString -replace '^v', ''
    $parts = $ver -split '\.'
    if ($parts.Count -lt 2) { return }
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $Script:NodeVersion = $VersionString
    if ($major -gt 22 -or ($major -eq 22 -and $minor -ge 16)) {
        return
    }
    $Script:NodeVersionLow = $true
    Write-Log "WARN" "Node.js $VersionString below recommended. OpenClaw recommends Node 24 or Node 22.16+"
}

# ============================================================
# 环境检测
# ============================================================

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

# ============================================================
# 套餐菜单
# ============================================================

function Show-PlanMenu {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  Select Service Plan"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "  1. Basic (58 yuan)"
    Write-Host "     Install: Claude Code OR OpenClaw (pick one)"
    Write-Host "     Deliver: beginner tutorial"
    Write-Host "     Support: 7 days"
    Write-Host ""
    Write-Host "  2. Pro (98 yuan)"
    Write-Host "     Install: Claude Code OR OpenClaw (pick one)"
    Write-Host "     Deliver: beginner tutorial + 5 workflow tutorials"
    Write-Host "     Support: 14 days"
    Write-Host ""
    Write-Host "  3. Full Suite (158/198 yuan)"
    Write-Host "     Install: Claude Code AND OpenClaw (both)"
    Write-Host "     Deliver: beginner tutorial + 10 workflow tutorials"
    Write-Host "     Support: 14 days"
    Write-Host ""
    Write-Host "  4. Check environment only (no install)"
    Write-Host ""
    Write-Host "  5. Exit"
    Write-Host ""
    Write-Host "=========================================="

    if ($DryRun) {
        Write-Host "  [DRY-RUN: preview only, no actual install]"
        Write-Host ""
    }

    while ($true) {
        $choice = Read-Host "Enter option (1/2/3/4/5)"
        switch ($choice) {
            "1" {
                $Script:PlanChoice = 1
                $Script:PlanName = "Basic"
                $Script:PlanPrice = "58 yuan"
                $Script:PlanSupport = "7 days"
                $Script:PlanTutorial = $true
                $Script:PlanWorkflowCount = 0
                Select-Tool
                return
            }
            "2" {
                $Script:PlanChoice = 2
                $Script:PlanName = "Pro"
                $Script:PlanPrice = "98 yuan"
                $Script:PlanSupport = "14 days"
                $Script:PlanTutorial = $true
                $Script:PlanWorkflowCount = 5
                Select-Tool
                return
            }
            "3" {
                $Script:PlanChoice = 3
                $Script:PlanName = "Full Suite"
                $Script:PlanPrice = "158/198 yuan"
                $Script:PlanSupport = "14 days"
                $Script:PlanTutorial = $true
                $Script:PlanWorkflowCount = 10
                $Script:InstallClaude = $true
                $Script:InstallOpenClaw = $true
                $Script:ToolChoiceName = "Claude Code + OpenClaw"
                return
            }
            "4" {
                $Script:PlanChoice = 4
                $Script:PlanName = "Check Only"
                $Script:PlanPrice = "-"
                $Script:PlanSupport = "-"
                $Script:PlanTutorial = $false
                $Script:PlanWorkflowCount = 0
                return
            }
            "5" {
                Write-Host "Exited."
                Append-Report "User exited"
                exit 0
            }
            default {
                Write-Host "Invalid option, enter 1-5"
            }
        }
    }
}

function Select-Tool {
    Write-Host ""
    Write-Host "  Select tool to install:"
    Write-Host "  A. Claude Code"
    Write-Host "  B. OpenClaw"
    Write-Host ""

    while ($true) {
        $tool = Read-Host "Enter (A/B)"
        switch ($tool.ToUpper()) {
            "A" {
                $Script:InstallClaude = $true
                $Script:InstallOpenClaw = $false
                $Script:ToolChoiceName = "Claude Code"
                return
            }
            "B" {
                $Script:InstallClaude = $false
                $Script:InstallOpenClaw = $true
                $Script:ToolChoiceName = "OpenClaw"
                return
            }
            default {
                Write-Host "Invalid, enter A or B"
            }
        }
    }
}

function Log-PlanInfo {
    Append-Report ""
    Append-Report "--- Plan Info ---"
    Append-Report "Plan: $Script:PlanName"
    Append-Report "Price: $Script:PlanPrice"
    Append-Report "Support: $Script:PlanSupport"
    Append-Report "Install: $Script:ToolChoiceName"
    Append-Report "Tutorial: $(if ($Script:PlanTutorial) { 'Yes' } else { 'No' })"
    Append-Report "Workflows: $Script:PlanWorkflowCount"
}

# ============================================================
# Build install queue
# ============================================================

function Build-InstallQueue {
    $Script:InstallQueue = @()

    if (-not $Script:HasGit)  { $Script:InstallQueue += "Git" }
    if ((-not $Script:HasNode) -or $Script:NeedNodeUpgrade) { $Script:InstallQueue += "Node.js LTS" }
    if (-not $Script:HasPnpm) { $Script:InstallQueue += "pnpm" }

    if ($Script:InstallClaude -and -not $Script:HasClaude) {
        $Script:InstallQueue += "Claude Code"
    }
    if ($Script:InstallOpenClaw -and -not $Script:HasOpenClaw) {
        $Script:InstallQueue += "OpenClaw"
    }
}

# ============================================================
# Show plan and confirm
# ============================================================

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

    Write-Host "Plan: $Script:PlanName ($Script:PlanPrice)"
    Write-Host "Support: $Script:PlanSupport"
    Write-Host "Install: $Script:ToolChoiceName"
    Write-Host "Tutorial: $(if ($Script:PlanTutorial) { 'Yes' } else { 'No' })"
    Write-Host "Workflows: $Script:PlanWorkflowCount"
    Append-Report "Plan: $Script:PlanName ($Script:PlanPrice)"
    Append-Report "Support: $Script:PlanSupport"
    Append-Report "Install: $Script:ToolChoiceName"
    Append-Report "Tutorial: $(if ($Script:PlanTutorial) { 'Yes' } else { 'No' })"
    Append-Report "Workflows: $Script:PlanWorkflowCount"

    Write-Host ""

    if ($Script:InstallQueue.Count -eq 0) {
        Write-Host "All components installed, nothing to do."
        Append-Report "All components installed."
        return $true
    }

    Write-Host "Will install $($Script:InstallQueue.Count) components in order:"
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

    if ($Script:InstallOpenClaw -and $Script:NodeVersionLow -and $Script:HasNode) {
        Write-Host ""
        Write-Host "  WARNING: Node.js $Script:NodeVersion below OpenClaw recommendation (24 or 22.16+)."
        if ($DryRun) {
            Write-Host "    Node will NOT be auto-upgraded in dry-run."
            Append-Report "WARN: Node $Script:NodeVersion below recommendation"
        } else {
            $upgrade = Read-Host "  Upgrade Node.js? (y/N)"
            if ($upgrade -eq "y" -or $upgrade -eq "Y") {
                $Script:NeedNodeUpgrade = $true
                Build-InstallQueue
                Write-Host "  Node upgrade confirmed."
                Append-Report "User confirmed Node upgrade ($Script:NodeVersion -> LTS)"
            } else {
                Write-Host "  Continuing without upgrade. Risk noted in report."
                Append-Report "WARN: User declined Node upgrade ($Script:NodeVersion), OpenClaw may be unstable"
            }
        }
    }

    if ($DryRun) {
        Write-Host ""
        Write-Host "[DRY-RUN] Preview only, no install actions performed."
        Write-Host "Report saved to: $ReportFile"
        Append-Report "[DRY-RUN] Preview only."
        return $false
    }

    Write-Host ""
    Write-Host "Report will be saved to: $ReportFile"
    Write-Host ""

    $confirm = Read-Host "Confirm installation? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Install cancelled."
        Append-Report "User cancelled"
        return $false
    }
    return $true
}

# ============================================================
# 安装函数
# ============================================================

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
    if ($Script:HasNode -and -not $Script:NeedNodeUpgrade) {
        Write-Log "SKIP" "Node.js: already installed, skipping"
        return
    }
    if ($Script:NeedNodeUpgrade) {
        Write-Log "INFO" "Upgrading Node.js (current: $(Get-ToolVersion node))..."
    } else {
        Write-Log "INFO" "Installing Node.js LTS..."
    }
    if (-not $Script:HasWinget) {
        Write-Log "FAIL" "Node.js: WinGet required but not found"
        Write-Host "        Manual install: https://nodejs.org/"
        $Script:FailList += "Node.js"
        return
    }
    try {
        $result = Invoke-Expression $NodeInstallWinget 2>&1
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        if ((Test-Command node)) {
            $Script:HasNode = $true
            $Script:HasNpm = $true
            $Script:NeedNodeUpgrade = $false
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
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                if (Test-Command claude) {
                    $Script:HasClaude = $true
                    Write-Log "OK" "Claude Code: installed ($(Get-ToolVersion claude))"
                } else {
                    Write-Log "OK" "Claude Code: install done (may need terminal restart)"
                    $Script:HasClaude = $true
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
    Write-Host "  NOTE: Run 'claude' to complete setup."
    Write-Host "    Login, verification, API Key must be entered by you."
    Write-Host "    Service provider does not ask for or record these."
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
    Write-Host "    Onboarding, login, API Key must be done by you."
    Write-Host "    Service provider does not ask for or record these."
}

# ============================================================
# 执行安装
# ============================================================

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

# ============================================================
# Summary and next steps
# ============================================================

function Show-Summary {
    Write-Host ""

    if ($Script:PlanChoice -eq 4) {
        Write-Host "=========================================="
        Write-Host "  Environment Check Summary"
        Write-Host "=========================================="
        Append-Report ""
        Append-Report "--- Environment Check Summary ---"
        $summary = "Ready: $SkipCount, Missing: $MissingCount"
        Write-Host $summary
        Append-Report $summary
    } elseif ($DryRun) {
        Write-Host "=========================================="
        Write-Host "  Preview Summary"
        Write-Host "=========================================="
        Append-Report ""
        Append-Report "--- Preview Summary ---"
        $summary = "Plan: $Script:PlanName, To install: $($Script:InstallQueue.Count), Ready: $SkipCount, Missing: $MissingCount"
        Write-Host $summary
        Append-Report $summary
        Write-Host ""
        Write-Host "[DRY-RUN] No install actions performed."
        Append-Report "[DRY-RUN] No install actions performed."
    } else {
        Write-Host "=========================================="
        Write-Host "  Install Summary"
        Write-Host "=========================================="
        Append-Report ""
        Append-Report "--- Install Summary ---"
        $summary = "OK: $SuccessCount, Skip: $SkipCount, Missing: $MissingCount, Fail: $FailCount"
        Write-Host $summary
        Append-Report $summary

        if ($Script:FailList.Count -gt 0) {
            Write-Host ""
            Write-Host "Failed components:"
            Append-Report "Failed:"
            foreach ($item in $Script:FailList) {
                Write-Host "  - $item"
                Append-Report "  - $item"
            }
            Write-Host ""
            Write-Host "Please manually install failed components."
        }

        Write-Host ""
        Write-Host "Plan: $Script:PlanName ($Script:PlanPrice) | Support: $Script:PlanSupport"
        Write-Host "Tutorial: $(if ($Script:PlanTutorial) { 'Yes' } else { 'No' }) | Workflows: $Script:PlanWorkflowCount"
        Append-Report "Plan: $Script:PlanName ($Script:PlanPrice) | Support: $Script:PlanSupport"
        Append-Report "Tutorial: $(if ($Script:PlanTutorial) { 'Yes' } else { 'No' }) | Workflows: $Script:PlanWorkflowCount"
    }

    Write-Host ""
    Write-Host "Full report saved to: $ReportFile"
    Append-Report ""
    Append-Report "=========================================="
    Append-Report "End of report"
}

function Show-NextSteps {
    if ($Script:PlanChoice -eq 4 -or $DryRun) { return }

    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  Next Steps"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "  The following must be done by the user:"
    Write-Host ""

    if ($Script:InstallClaude) {
        Write-Host "  Claude Code setup:"
        Write-Host "    Run: claude"
        Write-Host "    - Login to Anthropic"
        Write-Host "    - Enter API Key"
        Write-Host ""
    }

    if ($Script:InstallOpenClaw) {
        Write-Host "  OpenClaw setup:"
        Write-Host "    Run: openclaw"
        Write-Host "    - Complete onboarding"
        Write-Host "    - Login and configure API Key"
        Write-Host ""
    }

    Write-Host "  Delivery reminder:"
    if ($Script:PlanTutorial) { Write-Host "    - Beginner tutorial" }
    if ($Script:PlanWorkflowCount -gt 0) { Write-Host "    - $Script:PlanWorkflowCount workflow tutorials" }
    Write-Host "    Deliver to user after install completes."
    Write-Host ""

    Write-Host "  Verify:"
    Write-Host "    git --version; node --version; npm --version; pnpm --version"
    if ($Script:InstallClaude) { Write-Host "    claude --version" }
    if ($Script:InstallOpenClaw) { Write-Host "    openclaw --version" }
    Write-Host ""
    Write-Host "  Login, codes, passwords, API Keys must be entered by the user."
    Write-Host "  Service provider does not ask for or record these."
    Write-Host ""

    Append-Report ""
    Append-Report "--- Next Steps ---"
    Append-Report "Tutorial: $(if ($Script:PlanTutorial) { 'Yes' } else { 'No' })"
    Append-Report "Workflows: $Script:PlanWorkflowCount"
    Append-Report "User must complete login setup manually"
}

# ============================================================
# 主流程
# ============================================================

function Main {
    Clear-Host
    Write-Host "=========================================="
    Write-Host "  AI Coding Installer v1.3.0"
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
        $Script:PlanChoice = 4
        Show-Summary
        return
    }

    Show-PlanMenu

    if ($Script:PlanChoice -eq 4) {
        Log-PlanInfo
        Show-Summary
        return
    }

    Log-PlanInfo
    Build-InstallQueue
    $confirmed = Show-PlanAndConfirm
    if ($confirmed) {
        Execute-Install
    }
    Show-Summary
    Show-NextSteps
}

Main

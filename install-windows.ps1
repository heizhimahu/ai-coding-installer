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
        "OK"      { $Script:SuccessCount++; "[$timeStr] ✓" }
        "SKIP"    { $Script:SkipCount++;    "[$timeStr] ○" }
        "FAIL"    { $Script:FailCount++;    "[$timeStr] ✗" }
        "INFO"    {                        "[$timeStr] ▶" }
        "MISSING" { $Script:MissingCount++; "[$timeStr] ◇" }
        "WARN"    {                        "[$timeStr] ⚠" }
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
    if (-not (Test-Command $CommandName)) { return "未安装" }
    try {
        $output = & $CommandName --version 2>&1 | Select-Object -First 1
        return $output.ToString().Trim()
    } catch {
        return "已安装（无法获取版本）"
    }
}

function Get-InstallCommand {
    param([string]$StepName)
    switch ($StepName) {
        "Git"          { return $GitInstallWinget }
        "Node.js LTS"  { if ($Script:NeedNodeUpgrade) { return $NodeInstallWinget + " (升级)" } else { return $NodeInstallWinget } }
        "pnpm"         { return $PnpmInstallNpm + " (备选: corepack)" }
        "Claude Code"  { return "优先: $ClaudeInstallWinget ; 回退: iwr -useb $ClaudeInstallUrl | iex" }
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

    Write-Host "操作系统: $($osInfo.Caption) ($arch)"
    Write-Host "版本号: $version (Build $build)"
    Append-Report "操作系统: $($osInfo.Caption) ($arch)"
    Append-Report "版本号: $version (Build $build)"

    if ([int]$build -lt 10240) {
        Write-Host "警告: 检测到较旧的 Windows 版本，部分功能可能不兼容"
    }

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $Script:IsAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($Script:IsAdmin) {
        Write-Host "运行模式: 管理员"
    } else {
        Write-Host "运行模式: 普通用户（部分安装可能需要管理员权限）"
    }
}

# ============================================================
# Node 版本检测辅助
# ============================================================

function Test-NodeVersion {
    param([string]$VersionString)
    if ($VersionString -eq "未安装" -or $VersionString -match "无法获取") {
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
    Write-Log "WARN" "Node.js 版本 ${VersionString} 低于推荐版本。OpenClaw 推荐 Node 24 或 Node 22.16+"
}

# ============================================================
# 环境检测（只检测，不安装任何东西）
# ============================================================

function Detect-Tools {
    Write-Host ""
    Write-Host "--- 环境检测 ---"
    Append-Report ""
    Append-Report "--- 环境检测 ---"

    if (Test-Command winget) {
        $Script:HasWinget = $true
        Write-Log "SKIP" "WinGet: $(Get-ToolVersion winget)"
    } else {
        $Script:HasWinget = $false
        Write-Log "MISSING" "WinGet: 未安装（建议安装 App Installer 以获得 winget）"
        Write-Host "        提示: WinGet 是 Windows 10 1809+/Windows 11 自带的包管理器"
    }

    if (Test-Command git) {
        $Script:HasGit = $true
        Write-Log "SKIP" "Git: $(Get-ToolVersion git)"
    } else {
        $Script:HasGit = $false
        Write-Log "MISSING" "Git: 未安装"
    }

    if (Test-Command node) {
        $Script:HasNode = $true
        $nodeVersion = Get-ToolVersion node
        Write-Log "SKIP" "Node.js: $nodeVersion"
        Test-NodeVersion $nodeVersion
    } else {
        $Script:HasNode = $false
        Write-Log "MISSING" "Node.js: 未安装"
    }

    if (Test-Command npm) {
        $Script:HasNpm = $true
        Write-Log "SKIP" "npm: $(Get-ToolVersion npm)"
    } else {
        $Script:HasNpm = $false
        Write-Log "MISSING" "npm: 未安装"
    }

    if (Test-Command pnpm) {
        $Script:HasPnpm = $true
        Write-Log "SKIP" "pnpm: $(Get-ToolVersion pnpm)"
    } else {
        $Script:HasPnpm = $false
        Write-Log "MISSING" "pnpm: 未安装"
    }

    if (Test-Command claude) {
        $Script:HasClaude = $true
        Write-Log "SKIP" "Claude Code: $(Get-ToolVersion claude)"
    } else {
        $Script:HasClaude = $false
        Write-Log "MISSING" "Claude Code: 未安装"
    }

    if (Test-Command openclaw) {
        $Script:HasOpenClaw = $true
        Write-Log "SKIP" "OpenClaw: $(Get-ToolVersion openclaw)"
    } else {
        $Script:HasOpenClaw = $false
        Write-Log "MISSING" "OpenClaw: 未安装"
    }
}

# ============================================================
# 套餐菜单
# ============================================================

function Show-PlanMenu {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  选择服务套餐"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "  1. 基础上手包  ¥58"
    Write-Host "     ▸ 安装: Claude Code 或 OpenClaw (二选一)"
    Write-Host "     ▸ 交付: 新手教程"
    Write-Host "     ▸ 售后: 7 天"
    Write-Host ""
    Write-Host "  2. 进阶工作流包  ¥98"
    Write-Host "     ▸ 安装: Claude Code 或 OpenClaw (二选一)"
    Write-Host "     ▸ 交付: 新手教程 + 5 套指定工作流教程"
    Write-Host "     ▸ 售后: 14 天"
    Write-Host ""
    Write-Host "  3. 全套效率包  ¥158/¥198"
    Write-Host "     ▸ 安装: Claude Code + OpenClaw (两个都装)"
    Write-Host "     ▸ 交付: 新手教程 + 10 套指定工作流教程"
    Write-Host "     ▸ 售后: 14 天"
    Write-Host ""
    Write-Host "  4. 只检测环境 (不安装任何软件)"
    Write-Host ""
    Write-Host "  5. 退出"
    Write-Host ""
    Write-Host "=========================================="

    if ($DryRun) {
        Write-Host "  [DRY-RUN 模式: 仅预览，不真正安装]"
        Write-Host ""
    }

    while ($true) {
        $choice = Read-Host "请输入选项 (1/2/3/4/5)"
        switch ($choice) {
            "1" {
                $Script:PlanChoice = 1
                $Script:PlanName = "基础上手包"
                $Script:PlanPrice = "¥58"
                $Script:PlanSupport = "7 天"
                $Script:PlanTutorial = $true
                $Script:PlanWorkflowCount = 0
                Select-Tool
                return
            }
            "2" {
                $Script:PlanChoice = 2
                $Script:PlanName = "进阶工作流包"
                $Script:PlanPrice = "¥98"
                $Script:PlanSupport = "14 天"
                $Script:PlanTutorial = $true
                $Script:PlanWorkflowCount = 5
                Select-Tool
                return
            }
            "3" {
                $Script:PlanChoice = 3
                $Script:PlanName = "全套效率包"
                $Script:PlanPrice = "¥158/¥198"
                $Script:PlanSupport = "14 天"
                $Script:PlanTutorial = $true
                $Script:PlanWorkflowCount = 10
                $Script:InstallClaude = $true
                $Script:InstallOpenClaw = $true
                $Script:ToolChoiceName = "Claude Code + OpenClaw"
                return
            }
            "4" {
                $Script:PlanChoice = 4
                $Script:PlanName = "仅环境检测"
                $Script:PlanPrice = "-"
                $Script:PlanSupport = "-"
                $Script:PlanTutorial = $false
                $Script:PlanWorkflowCount = 0
                return
            }
            "5" {
                Write-Host "已退出。"
                Append-Report "用户退出"
                exit 0
            }
            default {
                Write-Host "无效选项，请输入 1-5"
            }
        }
    }
}

function Select-Tool {
    Write-Host ""
    Write-Host "  请选择要安装的工具:"
    Write-Host "  A. Claude Code"
    Write-Host "  B. OpenClaw"
    Write-Host ""

    while ($true) {
        $tool = Read-Host "请输入 (A/B)"
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
                Write-Host "无效选项，请输入 A 或 B"
            }
        }
    }
}

function Log-PlanInfo {
    Append-Report ""
    Append-Report "--- 套餐信息 ---"
    Append-Report "套餐名称: $Script:PlanName"
    Append-Report "价格: $Script:PlanPrice"
    Append-Report "售后: $Script:PlanSupport"
    Append-Report "选择安装: $Script:ToolChoiceName"
    Append-Report "新手教程: $(if ($Script:PlanTutorial) { '是' } else { '否' })"
    Append-Report "指定工作流数量: $Script:PlanWorkflowCount"
}

# ============================================================
# 安装队列
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
# 安装计划展示
# ============================================================

function Show-PlanAndConfirm {
    Write-Host ""

    if ($DryRun) {
        Write-Host "=========================================="
        Write-Host "  [DRY-RUN] 安装预览"
        Write-Host "=========================================="
        Append-Report ""
        Append-Report "--- [DRY-RUN] 安装预览 ---"
    } else {
        Write-Host "=========================================="
        Write-Host "  安装计划"
        Write-Host "=========================================="
        Append-Report ""
        Append-Report "--- 安装计划 ---"
    }

    Write-Host "套餐: $Script:PlanName ($Script:PlanPrice)"
    Write-Host "售后: $Script:PlanSupport"
    Write-Host "安装工具: $Script:ToolChoiceName"
    Write-Host "新手教程: $(if ($Script:PlanTutorial) { '是' } else { '否' })"
    Write-Host "指定工作流: $Script:PlanWorkflowCount 套"
    Append-Report "套餐: $Script:PlanName ($Script:PlanPrice)"
    Append-Report "售后: $Script:PlanSupport"
    Append-Report "安装工具: $Script:ToolChoiceName"
    Append-Report "新手教程: $(if ($Script:PlanTutorial) { '是' } else { '否' })"
    Append-Report "指定工作流数量: $Script:PlanWorkflowCount"

    Write-Host ""

    if ($Script:InstallQueue.Count -eq 0) {
        Write-Host "所有组件已安装，无需操作。"
        Append-Report "所有组件已安装，无需操作。"
        return $true
    }

    Write-Host "将按以下顺序安装 $($Script:InstallQueue.Count) 个组件:"
    Append-Report "将安装 $($Script:InstallQueue.Count) 个组件:"
    for ($i = 0; $i -lt $Script:InstallQueue.Count; $i++) {
        $num = $i + 1
        $step = $Script:InstallQueue[$i]
        Write-Host "  ${num}. $step"
        Append-Report "  ${num}. $step"
        if ($DryRun) {
            $cmd = Get-InstallCommand $step
            Write-Host "      → $cmd"
            Append-Report "      → $cmd"
        }
    }

    # Node 版本警告 + 升级询问：选了 OpenClaw 且 Node 已安装但版本过低
    if ($Script:InstallOpenClaw -and $Script:NodeVersionLow -and $Script:HasNode) {
        Write-Host ""
        Write-Host "  ⚠ Node.js 版本 $Script:NodeVersion 低于 OpenClaw 推荐版本 (24 或 22.16+)。"
        if ($DryRun) {
            Write-Host "    安装计划中不会自动升级 Node。如需升级请手动操作。"
            Append-Report "⚠ Node 版本过低 ($Script:NodeVersion)，OpenClaw 推荐 24 或 22.16+"
        } else {
            $upgrade = Read-Host "  是否升级 Node.js? (y/N)"
            if ($upgrade -eq "y" -or $upgrade -eq "Y") {
                $Script:NeedNodeUpgrade = $true
                Build-InstallQueue
                Write-Host "  已确认升级 Node.js。"
                Append-Report "用户确认升级 Node.js ($Script:NodeVersion → LTS)"
            } else {
                Write-Host "  将继续安装 OpenClaw，但报告已记录版本风险。"
                Append-Report "⚠ 用户选择不升级 Node ($Script:NodeVersion)，OpenClaw 可能在低版本下不稳定"
            }
        }
    }

    if ($DryRun) {
        Write-Host ""
        Write-Host "[DRY-RUN] 以上为预览，未执行任何安装操作。"
        Write-Host "安装报告已保存到: $ReportFile"
        Append-Report "[DRY-RUN] 以上为预览，未执行任何安装操作。"
        return $false
    }

    Write-Host ""
    Write-Host "安装报告将保存到: $ReportFile"
    Write-Host ""

    $confirm = Read-Host "确认开始安装? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "已取消安装。"
        Append-Report "用户取消安装"
        return $false
    }
    return $true
}

# ============================================================
# 安装函数
# ============================================================

function Install-Git {
    if ($Script:HasGit) {
        Write-Log "SKIP" "Git: 已安装，跳过"
        return
    }
    Write-Log "INFO" "正在安装 Git..."
    if (-not $Script:HasWinget) {
        Write-Log "FAIL" "Git: 需要 WinGet，但系统中未找到"
        Write-Host "        请手动安装 Git: https://git-scm.com/download/win"
        $Script:FailList += "Git"
        return
    }
    try {
        $result = Invoke-Expression $GitInstallWinget 2>&1
        if ($LASTEXITCODE -eq 0 -and (Test-Command git)) {
            $Script:HasGit = $true
            Write-Log "OK" "Git: 安装成功 ($(Get-ToolVersion git))"
        } else {
            throw "安装失败"
        }
    } catch {
        Write-Log "FAIL" "Git: 安装失败"
        $Script:FailList += "Git"
    }
}

function Install-NodeJS {
    if ($Script:HasNode -and -not $Script:NeedNodeUpgrade) {
        Write-Log "SKIP" "Node.js: 已安装，跳过"
        return
    }
    if ($Script:NeedNodeUpgrade) {
        Write-Log "INFO" "正在升级 Node.js (当前: $(Get-ToolVersion node))..."
    } else {
        Write-Log "INFO" "正在安装 Node.js LTS..."
    }
    if (-not $Script:HasWinget) {
        Write-Log "FAIL" "Node.js: 需要 WinGet，但系统中未找到"
        Write-Host "        请手动安装 Node.js: https://nodejs.org/"
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
            Write-Log "OK" "Node.js: 安装成功 ($(Get-ToolVersion node))"
            Write-Log "OK" "npm: 附带安装 ($(Get-ToolVersion npm))"
        } else {
            throw "安装后未找到 node 命令"
        }
    } catch {
        Write-Log "FAIL" "Node.js: 安装失败"
        $Script:FailList += "Node.js"
    }
}

function Install-Pnpm {
    if ($Script:HasPnpm) {
        Write-Log "SKIP" "pnpm: 已安装，跳过"
        return
    }
    if (-not (Test-Command npm)) {
        Write-Log "FAIL" "pnpm: 需要先安装 Node.js/npm"
        $Script:FailList += "pnpm"
        return
    }
    Write-Log "INFO" "正在安装 pnpm..."
    try {
        $result = Invoke-Expression $PnpmInstallNpm 2>&1
        if ($LASTEXITCODE -eq 0 -and (Test-Command pnpm)) {
            $Script:HasPnpm = $true
            Write-Log "OK" "pnpm: 安装成功 ($(Get-ToolVersion pnpm))"
        } else {
            Write-Host "        npm 全局安装失败，尝试 corepack..."
            corepack enable 2>$null
            corepack prepare pnpm@latest --activate 2>$null
            if (Test-Command pnpm) {
                $Script:HasPnpm = $true
                Write-Log "OK" "pnpm: 通过 corepack 安装成功 ($(Get-ToolVersion pnpm))"
            } else {
                throw "安装失败"
            }
        }
    } catch {
        Write-Log "FAIL" "pnpm: 安装失败"
        $Script:FailList += "pnpm"
    }
}

function Install-Claude {
    if ($Script:HasClaude) {
        Write-Log "SKIP" "Claude Code: 已安装，跳过"
        return
    }
    if ($Script:HasWinget) {
        Write-Log "INFO" "正在通过 WinGet 安装 Claude Code..."
        try {
            $result = Invoke-Expression $ClaudeInstallWinget 2>&1
            if ($LASTEXITCODE -eq 0) {
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                if (Test-Command claude) {
                    $Script:HasClaude = $true
                    Write-Log "OK" "Claude Code: 安装成功 ($(Get-ToolVersion claude))"
                } else {
                    Write-Log "OK" "Claude Code: 安装完成（可能需要重新打开终端）"
                    $Script:HasClaude = $true
                }
                Show-ClaudePostInstall
                return
            }
        } catch {
            Write-Host "        WinGet 安装失败，尝试官方脚本..."
        }
    }

    Write-Log "INFO" "正在通过官方脚本安装 Claude Code..."
    try {
        $scriptContent = Invoke-RestMethod -Uri $ClaudeInstallUrl
        Invoke-Expression $scriptContent
        if ($LASTEXITCODE -eq 0 -or $?) {
            if (Test-Command claude) {
                $Script:HasClaude = $true
                Write-Log "OK" "Claude Code: 安装成功 ($(Get-ToolVersion claude))"
            } else {
                $Script:HasClaude = $true
                Write-Log "OK" "Claude Code: 安装脚本执行完成（可能需要重新打开终端）"
            }
            Show-ClaudePostInstall
        } else {
            throw "安装脚本返回非零退出码"
        }
    } catch {
        Write-Log "FAIL" "Claude Code: 安装失败"
        $Script:FailList += "Claude Code"
    }
}

function Show-ClaudePostInstall {
    Write-Host ""
    Write-Host "  ⚠ Claude Code 安装完成后需要你本人运行 'claude' 完成首次设置。"
    Write-Host "    登录、验证码、API Key 均由你本人输入。"
    Write-Host "    服务人员不索要、不查看、不记录这些信息。"
}

function Install-OpenClaw {
    if ($Script:HasOpenClaw) {
        Write-Log "SKIP" "OpenClaw: 已安装，跳过"
        return
    }
    Write-Log "INFO" "正在通过官方脚本安装 OpenClaw (no-onboard 模式)..."
    try {
        $scriptContent = Invoke-RestMethod -Uri $OpenClawInstallUrl
        & ([scriptblock]::Create($scriptContent)) -NoOnboard
        if ($LASTEXITCODE -eq 0 -or $?) {
            if (Test-Command openclaw) {
                $Script:HasOpenClaw = $true
                Write-Log "OK" "OpenClaw: 安装成功 ($(Get-ToolVersion openclaw))"
            } else {
                $Script:HasOpenClaw = $true
                Write-Log "OK" "OpenClaw: 安装脚本执行完成（可能需要重新打开终端）"
            }
            Show-OpenClawPostInstall
        } else {
            throw "安装脚本返回非零退出码"
        }
    } catch {
        Write-Log "FAIL" "OpenClaw: 安装失败"
        $Script:FailList += "OpenClaw"
    }
}

function Show-OpenClawPostInstall {
    Write-Host ""
    Write-Host "  ⚠ OpenClaw 安装完成后需要你本人运行 'openclaw' 完成首次配置。"
    Write-Host "    该过程涉及: onboarding 引导、登录账号、配置 API Key。"
    Write-Host "    登录、验证码、密码、API Key 均由你本人输入。"
    Write-Host "    服务人员不索要、不查看、不记录这些信息。"
}

# ============================================================
# 执行安装
# ============================================================

function Execute-Install {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  开始安装"
    Write-Host "=========================================="
    Append-Report ""
    Append-Report "--- 安装过程 ---"

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
# 安装摘要
# ============================================================

function Show-Summary {
    Write-Host ""

    if ($Script:PlanChoice -eq 4) {
        Write-Host "=========================================="
        Write-Host "  环境检测摘要"
        Write-Host "=========================================="
        Append-Report ""
        Append-Report "--- 环境检测摘要 ---"
        $summary = "已就绪: $SkipCount, 缺失: $MissingCount"
        Write-Host $summary
        Append-Report $summary
    } elseif ($DryRun) {
        Write-Host "=========================================="
        Write-Host "  安装预览摘要"
        Write-Host "=========================================="
        Append-Report ""
        Append-Report "--- 安装预览摘要 ---"
        $summary = "套餐: $Script:PlanName, 待安装: $($Script:InstallQueue.Count), 已就绪: $SkipCount, 缺失: $MissingCount"
        Write-Host $summary
        Append-Report $summary
        Write-Host ""
        Write-Host "[DRY-RUN] 未执行任何安装操作。"
        Append-Report "[DRY-RUN] 未执行任何安装操作。"
    } else {
        Write-Host "=========================================="
        Write-Host "  安装摘要"
        Write-Host "=========================================="
        Append-Report ""
        Append-Report "--- 安装摘要 ---"
        $summary = "成功: $SuccessCount, 跳过: $SkipCount, 缺失: $MissingCount, 失败: $FailCount"
        Write-Host $summary
        Append-Report $summary

        if ($Script:FailList.Count -gt 0) {
            Write-Host ""
            Write-Host "以下组件安装失败:"
            Append-Report "失败组件:"
            foreach ($item in $Script:FailList) {
                Write-Host "  - $item"
                Append-Report "  - $item"
            }
            Write-Host ""
            Write-Host "请手动安装失败的组件后重新运行本脚本。"
        }

        Write-Host ""
        Write-Host "套餐: $Script:PlanName ($Script:PlanPrice) | 售后: $Script:PlanSupport"
        Write-Host "新手教程: $(if ($Script:PlanTutorial) { '是' } else { '否' }) | 指定工作流: $Script:PlanWorkflowCount 套"
        Append-Report "套餐: $Script:PlanName ($Script:PlanPrice) | 售后: $Script:PlanSupport"
        Append-Report "新手教程: $(if ($Script:PlanTutorial) { '是' } else { '否' }) | 指定工作流: $Script:PlanWorkflowCount 套"
    }

    Write-Host ""
    Write-Host "完整报告已保存到: $ReportFile"
    Append-Report ""
    Append-Report "=========================================="
    Append-Report "报告结束"
}

# ============================================================
# 后续步骤
# ============================================================

function Show-NextSteps {
    if ($Script:PlanChoice -eq 4 -or $DryRun) { return }

    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  后续步骤"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "  安装完成。以下步骤需要用户亲自操作:"
    Write-Host ""

    if ($Script:InstallClaude) {
        Write-Host "  ▸ Claude Code 首次设置:"
        Write-Host "    运行: claude"
        Write-Host "    - 登录 Anthropic 账号"
        Write-Host "    - 输入 API Key"
        Write-Host ""
    }

    if ($Script:InstallOpenClaw) {
        Write-Host "  ▸ OpenClaw 首次配置:"
        Write-Host "    运行: openclaw"
        Write-Host "    - 完成 onboarding 引导"
        Write-Host "    - 登录账号并配置 API Key"
        Write-Host ""
    }

    Write-Host "  ▸ 交付提醒:"
    if ($Script:PlanTutorial) {
        Write-Host "    - 新手教程"
    }
    if ($Script:PlanWorkflowCount -gt 0) {
        Write-Host "    - $Script:PlanWorkflowCount 套指定工作流教程"
    }
    Write-Host "    请在安装完成后向用户交付对应内容。"
    Write-Host ""

    Write-Host "  ▸ 验证安装:"
    Write-Host "     git --version; node --version; npm --version; pnpm --version"
    if ($Script:InstallClaude) { Write-Host "     claude --version" }
    if ($Script:InstallOpenClaw) { Write-Host "     openclaw --version" }
    Write-Host ""
    Write-Host "  登录、验证码、密码、API Key 均由用户本人输入。"
    Write-Host "  服务人员不索要、不查看、不记录这些信息。"
    Write-Host ""

    Append-Report ""
    Append-Report "--- 后续步骤 ---"
    Append-Report "新手教程: $(if ($Script:PlanTutorial) { '是' } else { '否' })"
    Append-Report "指定工作流: $Script:PlanWorkflowCount 套"
    Append-Report "用户需手动完成首次登录配置"
}

# ============================================================
# 主流程
# ============================================================

function Main {
    Clear-Host
    Write-Host "=========================================="
    Write-Host "  AI Coding Installer v1.3.0"
    Write-Host "  Windows 10/11 安装脚本"
    if ($DryRun) {
        Write-Host "  模式: DRY-RUN (仅预览，不安装)"
    } elseif ($CheckOnly) {
        Write-Host "  模式: CHECK-ONLY (仅检测环境)"
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

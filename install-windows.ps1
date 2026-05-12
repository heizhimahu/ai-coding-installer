# ============================================================
# AI Coding Installer — Windows 10/11 安装脚本
# 版本: 1.0.0 (MVP)
# 用途: 自动检测环境并安装 Claude Code + OpenClaw 所需依赖
# ============================================================
# 安全声明:
#   - 本脚本不读取、不保存、不上传任何密码/API Key/Token/Cookie
#   - 本脚本不修改系统安全策略（防火墙/杀毒软件/注册表）
#   - 所有安装步骤均在用户确认后执行
#   - 安装报告仅保存在本地用户目录
# ============================================================

# ============================================================
# 安装命令配置区
# 以下所有安装命令集中在此，方便后续更新版本号或切换安装源
# ============================================================

# --- Claude Code (官方安装方式) ---
$ClaudeInstallUrl = "https://claude.ai/install.ps1"
$ClaudeInstallWinget = "winget install --id Anthropic.ClaudeCode -e --source winget --accept-source-agreements"

# --- OpenClaw (官方安装方式) ---
$OpenClawInstallUrl = "https://openclaw.ai/install.ps1"

# --- Git ---
$GitInstallWinget = "winget install --id Git.Git -e --source winget --accept-source-agreements"

# --- Node.js LTS ---
$NodeInstallWinget = "winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements"

# --- pnpm ---
$PnpmInstallNpm = "npm install -g pnpm"

# ============================================================
# 全局变量
# ============================================================
$ReportFile = Join-Path $env:USERPROFILE "ai-coding-install-report.txt"
$Script:SuccessCount = 0
$Script:SkipCount = 0
$Script:FailCount = 0
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

# ============================================================
# 工具函数
# ============================================================

function Init-Report {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $content = @"
==========================================
  AI Coding Installer — 安装报告
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
        [ValidateSet("OK", "SKIP", "FAIL", "INFO")]
        [string]$Status,
        [string]$Message
    )
    $timeStr = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($Status) {
        "OK"   { $global:SuccessCount++; "[$timeStr] ✓" }
        "SKIP" { $global:SkipCount++;    "[$timeStr] ○" }
        "FAIL" { $global:FailCount++;    "[$timeStr] ✗" }
        "INFO" {                        "[$timeStr] ▶" }
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
    if (-not (Test-Command $CommandName)) {
        return "未安装"
    }
    try {
        $output = & $CommandName --version 2>&1 | Select-Object -First 1
        return $output.ToString().Trim()
    } catch {
        return "已安装（无法获取版本）"
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

    # 检查是否为 Windows 10 或更高版本
    if ([int]$build -lt 10240) {
        Write-Host "警告: 检测到较旧的 Windows 版本，部分功能可能不兼容"
    }

    # 检查管理员权限
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $Script:IsAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($Script:IsAdmin) {
        Write-Host "运行模式: 管理员"
    } else {
        Write-Host "运行模式: 普通用户（部分安装可能需要管理员权限）"
    }
}

# ============================================================
# 环境检测
# ============================================================

function Detect-Tools {
    Write-Host ""
    Write-Host "--- 环境检测 ---"
    Append-Report ""
    Append-Report "--- 环境检测 ---"

    # winget
    if (Test-Command winget) {
        $Script:HasWinget = $true
        $wingetVersion = Get-ToolVersion winget
        Write-Log "SKIP" "WinGet: $wingetVersion"
    } else {
        $Script:HasWinget = $false
        Write-Log "FAIL" "WinGet: 未安装（建议安装 App Installer 以获得 winget）"
        Write-Host "        提示: WinGet 是 Windows 10 1809+/Windows 11 自带的包管理器"
        Write-Host "        如果系统较旧，请通过 Microsoft Store 安装 '应用安装程序'"
    }

    # Git
    if (Test-Command git) {
        $Script:HasGit = $true
        Write-Log "SKIP" "Git: $(Get-ToolVersion git)"
    } else {
        $Script:HasGit = $false
        Write-Log "FAIL" "Git: 未安装"
    }

    # Node.js
    if (Test-Command node) {
        $Script:HasNode = $true
        Write-Log "SKIP" "Node.js: $(Get-ToolVersion node)"
    } else {
        $Script:HasNode = $false
        Write-Log "FAIL" "Node.js: 未安装"
    }

    # npm
    if (Test-Command npm) {
        $Script:HasNpm = $true
        Write-Log "SKIP" "npm: $(Get-ToolVersion npm)"
    } else {
        $Script:HasNpm = $false
        Write-Log "FAIL" "npm: 未安装"
    }

    # pnpm
    if (Test-Command pnpm) {
        $Script:HasPnpm = $true
        Write-Log "SKIP" "pnpm: $(Get-ToolVersion pnpm)"
    } else {
        $Script:HasPnpm = $false
        Write-Log "FAIL" "pnpm: 未安装"
    }

    # Claude Code
    if (Test-Command claude) {
        $Script:HasClaude = $true
        Write-Log "SKIP" "Claude Code: $(Get-ToolVersion claude)"
    } else {
        $Script:HasClaude = $false
        Write-Log "FAIL" "Claude Code: 未安装"
    }

    # OpenClaw
    if (Test-Command openclaw) {
        $Script:HasOpenClaw = $true
        Write-Log "SKIP" "OpenClaw: $(Get-ToolVersion openclaw)"
    } else {
        $Script:HasOpenClaw = $false
        Write-Log "FAIL" "OpenClaw: 未安装"
    }
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
    if ($Script:HasNode) {
        Write-Log "SKIP" "Node.js: 已安装，跳过"
        return
    }
    Write-Log "INFO" "正在安装 Node.js LTS..."
    if (-not $Script:HasWinget) {
        Write-Log "FAIL" "Node.js: 需要 WinGet，但系统中未找到"
        Write-Host "        请手动安装 Node.js: https://nodejs.org/"
        $Script:FailList += "Node.js"
        return
    }
    try {
        $result = Invoke-Expression $NodeInstallWinget 2>&1
        # 刷新 PATH 环境变量
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        if ((Test-Command node)) {
            $Script:HasNode = $true
            $Script:HasNpm = $true
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
            # 备选: corepack
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

    # 优先使用 winget（无交互），其次使用官方 install.ps1
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

    # 回退到官方 install.ps1
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
    Write-Host "  ⚠ 重要提示: Claude Code 安装完成后需要进行首次设置。"
    Write-Host "    请运行 'claude' 命令，按提示完成:"
    Write-Host "      1. 登录 Anthropic 账号"
    Write-Host "      2. 配置 API Key"
    Write-Host "    这些步骤必须由你本人操作，本脚本不会也不能替你完成。"
}

function Install-OpenClaw {
    if ($Script:HasOpenClaw) {
        Write-Log "SKIP" "OpenClaw: 已安装，跳过"
        return
    }
    Write-Log "INFO" "正在通过官方脚本安装 OpenClaw..."
    try {
        $scriptContent = Invoke-RestMethod -Uri $OpenClawInstallUrl
        Invoke-Expression $scriptContent
        if ($LASTEXITCODE -eq 0 -or $?) {
            if (Test-Command openclaw) {
                $Script:HasOpenClaw = $true
                Write-Log "OK" "OpenClaw: 安装成功 ($(Get-ToolVersion openclaw))"
            } else {
                $Script:HasOpenClaw = $true
                Write-Log "OK" "OpenClaw: 安装脚本执行完成（可能需要重新打开终端）"
            }
            Write-Host ""
            Write-Host "  ⚠ 重要提示: OpenClaw 安装完成后需要进行首次配置。"
            Write-Host "    请运行 'openclaw' 命令完成初始设置。"
            Write-Host "    该过程可能涉及登录账号和 Git 集成配置。"
            Write-Host "    这些步骤必须由你本人操作，本脚本不会也不能替你完成。"
        } else {
            throw "安装脚本返回非零退出码"
        }
    } catch {
        Write-Log "FAIL" "OpenClaw: 安装失败"
        $Script:FailList += "OpenClaw"
    }
}

# ============================================================
# 构建安装队列
# ============================================================

function Build-InstallQueue {
    $Script:InstallQueue = @()
    if (-not $Script:HasGit)      { $Script:InstallQueue += "Git" }
    if (-not $Script:HasNode)     { $Script:InstallQueue += "Node.js LTS" }
    if (-not $Script:HasPnpm)     { $Script:InstallQueue += "pnpm" }
    if (-not $Script:HasClaude)   { $Script:InstallQueue += "Claude Code" }
    if (-not $Script:HasOpenClaw) { $Script:InstallQueue += "OpenClaw" }
}

# ============================================================
# 展示安装计划并请求确认
# ============================================================

function Show-PlanAndConfirm {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  安装计划"
    Write-Host "=========================================="
    Append-Report ""
    Append-Report "--- 安装计划 ---"

    if ($Script:InstallQueue.Count -eq 0) {
        Write-Host "所有组件已安装，无需操作。"
        Append-Report "所有组件已安装，无需操作。"
        return $true
    }

    Write-Host "将按以下顺序安装 $($Script:InstallQueue.Count) 个组件:"
    Append-Report "将安装 $($Script:InstallQueue.Count) 个组件:"
    for ($i = 0; $i -lt $Script:InstallQueue.Count; $i++) {
        $num = $i + 1
        Write-Host "  ${num}. $($Script:InstallQueue[$i])"
        Append-Report "  ${num}. $($Script:InstallQueue[$i])"
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
    Write-Host "=========================================="
    Write-Host "  安装摘要"
    Write-Host "=========================================="
    Append-Report ""
    Append-Report "--- 安装摘要 ---"
    $summary = "成功: $SuccessCount, 跳过: $SkipCount, 失败: $FailCount"
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
    Write-Host "完整报告已保存到: $ReportFile"
    Append-Report ""
    Append-Report "=========================================="
    Append-Report "报告结束"
}

# ============================================================
# 后续步骤提示
# ============================================================

function Show-NextSteps {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  后续步骤"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "  以下步骤需要你亲自操作，本脚本不会也不能自动完成:"
    Write-Host ""
    Write-Host "  1. Claude Code 首次设置:"
    Write-Host "     运行: claude"
    Write-Host "     - 登录 Anthropic 账号"
    Write-Host "     - 输入 API Key"
    Write-Host "     - 按提示完成初始化"
    Write-Host ""
    Write-Host "  2. OpenClaw 首次配置:"
    Write-Host "     运行: openclaw"
    Write-Host "     - 按提示完成账号登录和配置"
    Write-Host ""
    Write-Host "  3. 验证安装:"
    Write-Host "     git --version"
    Write-Host "     node --version"
    Write-Host "     npm --version"
    Write-Host "     pnpm --version"
    Write-Host "     claude --version"
    Write-Host "     openclaw --version"
    Write-Host ""
    Write-Host "  4. 如果某个命令提示 '无法识别':"
    Write-Host "     - 尝试关闭并重新打开 PowerShell"
    Write-Host "     - 部分安装需要重启终端才能生效"
    Write-Host ""
    Append-Report ""
    Append-Report "--- 后续步骤 ---"
    Append-Report "用户需手动完成 Claude Code 和 OpenClaw 的首次登录配置"
}

# ============================================================
# 主流程
# ============================================================

function Main {
    Clear-Host
    Write-Host "=========================================="
    Write-Host "  AI Coding Installer v1.0.0"
    Write-Host "  Windows 10/11 安装脚本"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "本脚本将检测你的开发环境，并安装以下工具:"
    Write-Host "  - Git"
    Write-Host "  - Node.js LTS"
    Write-Host "  - pnpm"
    Write-Host "  - Claude Code"
    Write-Host "  - OpenClaw"
    Write-Host ""
    Write-Host "安全声明: 本脚本不会读取或保存你的密码/API Key/Token。"
    Write-Host "登录和配置步骤必须由你本人完成。"
    Write-Host ""

    Init-Report
    Detect-OS
    Detect-Tools
    Build-InstallQueue
    $confirmed = Show-PlanAndConfirm
    if ($confirmed) {
        Execute-Install
    }
    Show-Summary
    Show-NextSteps
}

Main

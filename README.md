# AI Coding Installer v1.3.0

为校园学生远程装机场景设计的 Claude Code + OpenClaw 三档服务套餐安装工具。

**版本**: 1.3.0 — 修复 P0 可执行性问题：命令执行安全化、curl 纳入安装队列、Node 升级交互确认、工作流数量解耦。

## 项目结构

```
ai-coding-installer/
├── install-mac-linux.sh     # macOS / Linux / WSL 安装脚本 (LF)
├── install-windows.ps1      # Windows 10/11 安装脚本
├── README.md                # 本文件
└── service-disclaimer.md    # 服务免责声明
```

## 三档服务套餐

脚本启动后显示套餐菜单，按需选择：

| 套餐 | 价格 | 安装内容 | 交付物 | 售后 |
|------|------|----------|--------|------|
| 基础上手包 | ¥58 | Claude Code **或** OpenClaw (二选一) | 新手教程 | 7 天 |
| 进阶工作流包 | ¥98 | Claude Code **或** OpenClaw (二选一) | 新手教程 + 5 套工作流 | 14 天 |
| 全套效率包 | ¥158/¥198 | Claude Code **+** OpenClaw (两个都装) | 新手教程 + 10 套工作流 | 14 天 |

### 套餐适用人群

- **基础上手包 (¥58)** — 刚接触 AI 编程助手，想体验基本功能。只需一个工具入门，预算敏感。
- **进阶工作流包 (¥98)** — 已有编程基础，想快速掌握 5 套高效工作流。单工具深度使用场景。
- **全套效率包 (¥158/¥198)** — 想同时使用两个工具互补，配合 10 套工作流打通完整开发链路。

### 重要说明

- **第一档和第二档不是默认安装两个软件的。** 服务人员会在菜单中进一步选择安装 Claude Code **还是** OpenClaw。
- 只有第三档（全套效率包）才会两个都安装。
- Git / Node.js / npm / pnpm 作为基础依赖，无论选择哪个套餐都会自动检测并安装。
- 如果 Node.js 版本低于 22.16 且用户选择安装 OpenClaw，脚本会**询问是否升级**，不会静默升级。

## 功能概述

- 脚本启动后展示三档套餐菜单，按需选择
- 第一档/第二档需进一步选择安装 Claude Code 还是 OpenClaw
- 第三档默认 Claude Code + OpenClaw 两个都装
- 环境检测阶段**只检测不安装**，curl 缺失不会在检测时自动安装
- 所有安装动作在用户确认安装计划之后才执行
- Node.js 版本检测：低于 22.16 标记为 WARN (⚠)
- 选 OpenClaw 且 Node 版本过低时：**明确询问**是否升级，用户不同意则记录风险继续
- dry-run 模式：选套餐 → 检测环境 → 展示安装命令预览，不真正安装
- check-only 模式：仅检测环境并生成报告，不进入套餐菜单
- 每步结果写入本地报告 `~/ai-coding-install-report.txt`
- 报告分开记录：「新手教程: 是/否」「指定工作流数量: 0/5/10」「售后天数: 7/14」
- 登录、验证码、API Key 等步骤仅提示用户本人操作

## 覆盖的安装项

| 工具 | macOS | Linux (apt/yum/dnf/pacman) | WSL | Windows |
|------|-------|---------------------------|-----|---------|
| curl | 系统包管理器 | 系统包管理器 | 系统包管理器 | 不需要 |
| Git | brew | 系统包管理器 | 系统包管理器 | winget |
| Node.js LTS | brew | NodeSource / 系统包管理器 | NodeSource | winget |
| pnpm | npm -g | npm -g | npm -g | npm -g |
| Claude Code | 官方 install.sh | 官方 install.sh | 官方 install.sh | winget / 官方 install.ps1 |
| OpenClaw | 官方 install.sh | 官方 install.sh | 官方 install.sh | 官方 install.ps1 |

## 快速开始

### 通用原则：真机服务前必须先跑 dry-run

在远程协助用户正式安装之前，**务必**先使用 `--dry-run` (或 `-DryRun`) 预览：

- 确认套餐选择和安装命令是否正确
- 确认 Node 版本是否满足 OpenClaw 要求
- 确认检测到的操作系统和架构无误
- dry-run / check-only 都不会修改系统，可反复安全运行

### Windows 10/11

```powershell
cd D:\ai-coding-installer
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# 1. 先跑 dry-run 预览
.\install-windows.ps1 -DryRun

# 2. 或仅检测环境
.\install-windows.ps1 -CheckOnly

# 3. 正式安装（显示套餐菜单）
.\install-windows.ps1
```

### macOS / Linux / WSL

```bash
chmod +x install-mac-linux.sh

# 1. 先跑 dry-run 预览
./install-mac-linux.sh --dry-run

# 2. 或仅检测环境
./install-mac-linux.sh --check-only

# 3. 正式安装（显示套餐菜单）
./install-mac-linux.sh
```

## 本地语法与功能测试

### Bash (install-mac-linux.sh)

```bash
# 语法检查
wc -l install-mac-linux.sh
bash -n install-mac-linux.sh

# 功能验证（不会修改系统）
./install-mac-linux.sh --check-only    # 只检测环境，确认 MISSING/WARN 状态
./install-mac-linux.sh --dry-run       # 走完整套餐流程，确认预览不执行安装
```

### PowerShell (install-windows.ps1)

```powershell
# 语法检查
Get-Content .\install-windows.ps1 | Measure-Object -Line

# 功能验证（不会修改系统）
.\install-windows.ps1 -CheckOnly       # 只检测环境
.\install-windows.ps1 -DryRun          # 走完整套餐流程，确认预览不执行安装
```

## 套餐选择流程示例

```
==========================================
  选择服务套餐
==========================================

  1. 基础上手包  ¥58
     ▸ 安装: Claude Code 或 OpenClaw (二选一)
     ▸ 交付: 新手教程
     ▸ 售后: 7 天

  2. 进阶工作流包  ¥98
     ▸ 安装: Claude Code 或 OpenClaw (二选一)
     ▸ 交付: 新手教程 + 5 套指定工作流教程
     ▸ 售后: 14 天

  3. 全套效率包  ¥158/¥198
     ▸ 安装: Claude Code + OpenClaw (两个都装)
     ▸ 交付: 新手教程 + 10 套指定工作流教程
     ▸ 售后: 14 天

  4. 只检测环境 (不安装任何软件)
  5. 退出

==========================================
请输入选项 (1/2/3/4/5):
```

选项 1 或 2 后会继续询问：

```
  请选择要安装的工具:
  A. Claude Code
  B. OpenClaw
请输入 (A/B):
```

## 安装报告

- **Windows**: `C:\Users\<用户名>\ai-coding-install-report.txt`
- **macOS / Linux / WSL**: `~/ai-coding-install-report.txt`

报告记录：套餐名称、价格、售后天数、选择安装的软件、新手教程(是/否)、指定工作流数量、每步执行结果。

## 更新安装命令

所有安装命令集中在脚本顶部：

- `install-mac-linux.sh` 第 48-52 行 (URL) + 安装函数区
- `install-windows.ps1` 第 28-37 行

## 安全边界

- 不读取、不保存、不上传密码/API Key/Token/Cookie
- 不读取 SSH 私钥或其他用户隐私文件
- 不自动登录任何第三方账号
- 不关闭杀毒软件或防火墙
- 不修改系统安全策略
- 不创建任何后门、隐藏进程或后台常驻服务
- 不上传日志到任何服务器
- OpenClaw 默认使用 no-onboard 模式
- 环境检测阶段不安装任何软件
- Node 升级需用户明确确认，不静默升级

详见 [service-disclaimer.md](./service-disclaimer.md)。

## 已知限制 (v1.3.0)

- Linux 下部分发行版（Alpine、Gentoo）未完整测试
- winget 在较旧 Windows 10（< 1809）上不可用，需手动安装
- Node.js 在非 apt/yum/dnf/pacman/zypper 的 Linux 上需要手动安装
- 脚本不处理代理/VPN 环境
- 不支持离线安装
- 不含 GUI 界面，所有交互通过终端菜单完成

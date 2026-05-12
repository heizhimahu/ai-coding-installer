# AI Coding Installer v1.1.0

为校园学生远程装机场景设计的 Claude Code + OpenClaw 自动化安装工具。

**版本**: 1.1.0，含 dry-run / check-only 模式，不含 GUI / 套餐系统 / 自动更新。

## 项目结构

```
ai-coding-installer/
├── install-mac-linux.sh     # macOS / Linux / WSL 安装脚本
├── install-windows.ps1      # Windows 10/11 安装脚本
├── README.md                # 本文件
└── service-disclaimer.md    # 服务免责声明
```

## 功能概述

- 自动检测操作系统类型、版本、CPU 架构
- 检测已有开发工具：Git / Node.js / npm / pnpm / Claude Code / OpenClaw
- Node.js 版本检测：低于 22.16 时提示 OpenClaw 兼容性警告
- 跳过已安装的软件，不重复安装
- 安装前展示完整计划，要求用户确认后才执行
- dry-run 模式：仅检测环境 + 展示安装命令预览，不真正安装
- check-only 模式：仅检测环境并生成报告，不安装任何东西
- 每步成功/失败/缺失均写入本地报告 `~/ai-coding-install-report.txt`
- 登录、验证码、API Key 等步骤仅提示用户本人操作，脚本绝不触碰

## 覆盖的安装项

| 工具 | macOS | Linux (apt/yum/dnf/pacman) | WSL | Windows |
|------|-------|---------------------------|-----|---------|
| Git | brew | 系统包管理器 | 系统包管理器 | winget |
| Node.js LTS | brew | NodeSource / 系统包管理器 | NodeSource | winget |
| pnpm | npm -g | npm -g | npm -g | npm -g |
| Claude Code | 官方 install.sh | 官方 install.sh | 官方 install.sh | winget / 官方 install.ps1 |
| OpenClaw | 官方 install.sh | 官方 install.sh | 官方 install.sh | 官方 install.ps1 |

## 快速开始

### Windows 10/11

```powershell
# 1. 以管理员身份打开 PowerShell
# 2. 进入项目目录
cd D:\ai-coding-installer

# 3. 先跑 dry-run 预览（强烈建议）
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\install-windows.ps1 -DryRun

# 4. 仅检测环境（不显示安装计划）
.\install-windows.ps1 -CheckOnly

# 5. 确认无误后正式安装
.\install-windows.ps1
```

### macOS

```bash
# 1. 打开终端
# 2. 进入项目目录
cd /path/to/ai-coding-installer

# 3. 先跑 dry-run 预览（强烈建议）
chmod +x install-mac-linux.sh
./install-mac-linux.sh --dry-run

# 4. 仅检测环境（不显示安装计划）
./install-mac-linux.sh --check-only

# 5. 确认无误后正式安装
./install-mac-linux.sh
```

### Linux (Ubuntu / Debian / Fedora / Arch 等)

```bash
chmod +x install-mac-linux.sh
./install-mac-linux.sh --dry-run    # 先预览
./install-mac-linux.sh --check-only # 仅检测
./install-mac-linux.sh              # 正式安装
```

### WSL

```bash
chmod +x install-mac-linux.sh
./install-mac-linux.sh --dry-run    # 先预览
./install-mac-linux.sh --check-only # 仅检测
./install-mac-linux.sh              # 正式安装
```

## ⚠ 重要：真实服务前必须先跑 dry-run

在远程协助用户正式安装之前，务必先使用 `--dry-run` (或 `-DryRun`) 预览：

- 确认检测到的操作系统和架构是否正确
- 确认哪些组件已安装、哪些缺失、哪些需要更新版本
- 确认安装命令是否匹配用户的系统环境
- 报告文件名不变，通过报告标题的 `[DRY-RUN]` / `[CHECK-ONLY]` 标记区分

dry-run 和 check-only 都不会修改系统，可以安全地在用户机器上反复运行。

## 安装报告

安装完成后，报告文件生成在用户目录下：

- **Windows**: `C:\Users\<用户名>\ai-coding-install-report.txt`
- **macOS / Linux / WSL**: `~/ai-coding-install-report.txt`

## 更新安装命令

所有安装命令集中在脚本顶部的变量区。需要更新版本号或切换安装源时，只需修改对应变量：

- `install-mac-linux.sh` 第 15-45 行
- `install-windows.ps1` 第 15-35 行

## 安全边界

本脚本严格遵守以下安全原则：

- 不读取、不保存、不上传密码/API Key/Token/Cookie
- 不读取 SSH 私钥或其他用户隐私文件
- 不自动登录任何第三方账号
- 不关闭杀毒软件或防火墙
- 不修改系统安全策略
- 不创建任何后门、隐藏进程或后台常驻服务
- 不上传日志到任何服务器

详见 [service-disclaimer.md](./service-disclaimer.md)。

## 已知限制 (v1.1.0)

- Linux 下部分发行版（Alpine、Gentoo）未完整测试
- winget 在较旧 Windows 10（< 1809）上不可用，需手动安装
- Node.js 在非 apt/yum/dnf/pacman/zypper 的 Linux 上需要手动安装
- 脚本不处理代理/VPN 环境
- 不支持离线安装

# 服务免责声明

**使用本安装工具（"AI Coding Installer"）即表示您已阅读并同意以下条款。**

---

## 1. 关于本工具

AI Coding Installer 是一个开源的环境安装辅助脚本，旨在帮助用户自动检测操作系统环境并安装以下开源/商业软件：

- Git（开源）
- Node.js（开源）
- pnpm（开源）
- Claude Code（Anthropic 商业产品）
- OpenClaw（第三方商业产品）

本工具仅负责执行安装命令，不替代也不隶属于上述任何产品。

## 2. 隐私与数据安全

本脚本**严格遵守**以下约束：

| 约束 | 说明 |
|------|------|
| 不读取密码 | 脚本不包含任何密码获取逻辑 |
| 不保存密码 | 脚本无密码持久化逻辑 |
| 不上传密码 | 脚本无网络上传行为（除官方安装源） |
| 不读取 API Key | 脚本不读取环境变量或文件中的 API Key |
| 不保存 API Key | 脚本不将 API Key 写入任何文件 |
| 不上传 API Key | 脚本无 API Key 外传路径 |
| 不读取 Token | 脚本不访问系统密钥链或 token 存储 |
| 不读取浏览器 Cookie | 脚本不访问浏览器数据 |
| 不读取 SSH 私钥 | 脚本不访问 ~/.ssh 目录 |
| 不读取用户隐私文件 | 脚本仅写入安装报告，不读取其他文件 |

脚本的网络请求**仅限于**从以下官方源下载安装脚本：

- `https://claude.ai/install.sh` — Claude Code 官方
- `https://claude.ai/install.ps1` — Claude Code 官方
- `https://openclaw.ai/install.sh` — OpenClaw 官方
- `https://openclaw.ai/install.ps1` — OpenClaw 官方
- `https://deb.nodesource.com/setup_lts.x` — NodeSource 官方
- `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh` — Homebrew 官方

安装报告 `ai-coding-install-report.txt` 仅保存在用户本地目录，**不上传到任何远程服务器**。

## 3. 账户与 API Key

Claude Code 和 OpenClaw 安装后**需要用户自行完成**：

- Anthropic 账号登录
- API Key 的申请、输入与保管
- OpenClaw 账号登录与配置

这些操作**不在本脚本的自动化范围内**，脚本仅会在安装完成后通过终端文字提示用户手动完成。用户应自行负责：

- API Key 的保密
- API 消费额度的管理
- 账户安全

## 4. 免责条款

- 本工具按"现状"提供，不提供任何明示或默示的担保。
- 使用本工具产生的任何直接或间接损失（包括但不限于数据丢失、系统故障、API 费用），作者不承担责任。
- 安装过程中可能因网络问题、系统环境差异、软件源不可用等原因导致安装失败。用户应具备基本的问题排查能力或寻求技术支持。
- 本工具不会修改系统防火墙、杀毒软件、安全策略。如在安装过程中出现安全软件拦截提示，由用户自行判断并处理。
- 远程协助场景下，登录、验证码、密码、API Key 均由用户本人输入，服务人员不索要、不查看、不记录。

## 5. 第三方软件许可

本工具安装的第三方软件分别受其各自的许可协议约束：

- Git: GNU General Public License v2
- Node.js: MIT License
- pnpm: MIT License
- Claude Code: Anthropic 服务条款
- OpenClaw: 相应商业许可

用户在使用这些软件前应阅读并同意其各自的条款。

## 6. 适用范围

本声明适用于 AI Coding Installer 的所有版本。如有更新，将在项目仓库中体现。

---

*最后更新: 2026-05-12*

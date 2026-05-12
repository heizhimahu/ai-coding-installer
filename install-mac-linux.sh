#!/usr/bin/env bash
# ============================================================
# AI Coding Installer — macOS / Linux / WSL 一键安装脚本
# 版本: 1.0.0 (MVP)
# 用途: 自动检测环境并安装 Claude Code + OpenClaw 所需依赖
# ============================================================
# 安全声明:
#   - 本脚本不读取、不保存、不上传任何密码/API Key/Token/Cookie
#   - 本脚本不修改系统安全策略
#   - 所有安装步骤均在用户确认后执行
#   - 安装报告仅保存在本地用户目录
# ============================================================

# ============================================================
# 安装命令配置区
# 以下所有安装命令集中在此，方便后续更新版本号或切换安装源
# ============================================================

# --- Claude Code (官方安装脚本) ---
CLAUDE_INSTALL_URL="https://claude.ai/install.sh"
CLAUDE_INSTALL_CMD="curl -fsSL ${CLAUDE_INSTALL_URL} | bash"

# --- OpenClaw (官方安装脚本，跳过交互式引导) ---
OPENCLAW_INSTALL_URL="https://openclaw.ai/install.sh"
OPENCLAW_INSTALL_CMD="curl -fsSL ${OPENCLAW_INSTALL_URL} | bash -s -- --no-onboard"

# --- Git ---
GIT_BREW_CMD="brew install git"
GIT_APT_CMD="sudo apt-get update -qq && sudo apt-get install -y git"
GIT_YUM_CMD="sudo yum install -y git"
GIT_DNF_CMD="sudo dnf install -y git"
GIT_PACMAN_CMD="sudo pacman -S --noconfirm git"
GIT_ZYPPER_CMD="sudo zypper install -y git"

# --- Node.js LTS ---
NODE_BREW_CMD="brew install node"
NODE_NODESOURCE_URL="https://deb.nodesource.com/setup_lts.x"
NODE_NODESOURCE_CMD="curl -fsSL ${NODE_NODESOURCE_URL} | sudo -E bash - && sudo apt-get install -y nodejs"

# --- pnpm ---
PNPM_NPM_CMD="npm install -g pnpm"

# --- 必要工具 ---
CURL_INSTALL_APT="sudo apt-get install -y curl"
CURL_INSTALL_YUM="sudo yum install -y curl"
CURL_INSTALL_DNF="sudo dnf install -y curl"

# ============================================================
# 全局变量
# ============================================================
REPORT_FILE="$HOME/ai-coding-install-report.txt"
TIMESTAMP=""
SUCCESS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0
declare -a INSTALL_QUEUE=()    # 待安装项目列表
declare -a FAIL_LIST=()        # 失败项目列表
OS_TYPE=""                     # macos / linux / wsl
OS_NAME=""                     # 发行版名称
PKG_MANAGER=""                # apt / yum / dnf / brew / pacman / zypper / unknown
HAS_CURL=false
HAS_GIT=false
HAS_NODE=false
HAS_NPM=false
HAS_PNPM=false
HAS_CLAUDE=false
HAS_OPENCLAW=false
HAS_HOMEBREW=false

# ============================================================
# 工具函数
# ============================================================

init_report() {
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    cat > "$REPORT_FILE" << EOF
==========================================
  AI Coding Installer — 安装报告
==========================================
生成时间: ${TIMESTAMP}
用户: $(whoami)
主机: $(hostname)

EOF
}

append_report() {
    echo "$1" >> "$REPORT_FILE"
}

log_step() {
    local status="$1"  # OK / SKIP / FAIL
    local message="$2"
    local time_str
    time_str=$(date '+%H:%M:%S')
    local prefix=""
    case "$status" in
        OK)   prefix="[${time_str}] ✓"; SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) ;;
        SKIP) prefix="[${time_str}] ○"; SKIP_COUNT=$((SKIP_COUNT + 1)) ;;
        FAIL) prefix="[${time_str}] ✗"; FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    esac
    local line="${prefix} ${message}"
    echo "$line"
    append_report "$line"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

get_version() {
    local cmd="$1"
    if command_exists "$cmd"; then
        case "$cmd" in
            git)     git --version 2>&1 | head -1 ;;
            node)    node --version 2>&1 ;;
            npm)     npm --version 2>&1 ;;
            pnpm)    pnpm --version 2>&1 ;;
            claude)  claude --version 2>&1 | head -1 || echo "已安装" ;;
            openclaw) openclaw --version 2>&1 | head -1 || echo "已安装" ;;
            brew)    brew --version 2>&1 | head -1 ;;
            *)       $cmd --version 2>&1 | head -1 || echo "已安装" ;;
        esac
    else
        echo "未安装"
    fi
}

# ============================================================
# 操作系统检测
# ============================================================

detect_os() {
    local kernel
    kernel=$(uname -s)
    case "$kernel" in
        Darwin)
            OS_TYPE="macOS"
            OS_NAME="macOS $(sw_vers -productVersion 2>/dev/null || echo 'Unknown')"
            PKG_MANAGER="brew"
            ;;
        Linux)
            # 检测是否为 WSL
            if grep -qi microsoft /proc/version 2>/dev/null; then
                OS_TYPE="WSL"
                OS_NAME="WSL"
            elif [ -f /proc/sys/fs/binfmt_misc/WSL ] 2>/dev/null; then
                OS_TYPE="WSL"
                OS_NAME="WSL (v1)"
            else
                OS_TYPE="Linux"
            fi
            # 检测 Linux 发行版
            if [ -f /etc/os-release ]; then
                local distro
                distro=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
                local version
                version=$(grep "^VERSION_ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
                OS_NAME="${distro} ${version}"
            fi
            # 检测包管理器
            detect_pkg_manager
            ;;
        *)
            echo "错误: 不支持的操作系统: $kernel"
            echo "本脚本仅支持 macOS、Linux 和 WSL"
            exit 1
            ;;
    esac

    local arch
    arch=$(uname -m)
    OS_NAME="${OS_NAME} (${arch})"

    echo "操作系统: ${OS_NAME}"
    append_report "操作系统: ${OS_NAME}"
}

detect_pkg_manager() {
    if command_exists apt-get; then
        PKG_MANAGER="apt"
    elif command_exists dnf; then
        PKG_MANAGER="dnf"
    elif command_exists yum; then
        PKG_MANAGER="yum"
    elif command_exists pacman; then
        PKG_MANAGER="pacman"
    elif command_exists zypper; then
        PKG_MANAGER="zypper"
    elif command_exists brew; then
        PKG_MANAGER="brew"
    else
        PKG_MANAGER="unknown"
    fi
}

# ============================================================
# 环境检测
# ============================================================

detect_tools() {
    echo ""
    echo "--- 环境检测 ---"
    append_report ""
    append_report "--- 环境检测 ---"

    # curl
    if command_exists curl; then
        HAS_CURL=true
        log_step "SKIP" "curl: $(get_version curl)"
    else
        HAS_CURL=false
        # 未安装 curl 时立即尝试安装
        log_step "FAIL" "curl: 未安装（必需工具）"
        echo "        正在尝试安装 curl..."
        install_curl
        if command_exists curl; then
            HAS_CURL=true
            log_step "OK" "curl: 安装成功"
        else
            log_step "FAIL" "curl: 安装失败，无法继续。请手动安装 curl 后重试。"
            exit 1
        fi
    fi

    # Git
    if command_exists git; then
        HAS_GIT=true
        log_step "SKIP" "Git: $(get_version git)"
    else
        HAS_GIT=false
        log_step "FAIL" "Git: 未安装"
    fi

    # Node.js
    if command_exists node; then
        HAS_NODE=true
        log_step "SKIP" "Node.js: $(get_version node)"
    else
        HAS_NODE=false
        log_step "FAIL" "Node.js: 未安装"
    fi

    # npm
    if command_exists npm; then
        HAS_NPM=true
        log_step "SKIP" "npm: $(get_version npm)"
    else
        HAS_NPM=false
        log_step "FAIL" "npm: 未安装"
    fi

    # pnpm
    if command_exists pnpm; then
        HAS_PNPM=true
        log_step "SKIP" "pnpm: $(get_version pnpm)"
    else
        HAS_PNPM=false
        log_step "FAIL" "pnpm: 未安装"
    fi

    # Claude Code
    if command_exists claude; then
        HAS_CLAUDE=true
        log_step "SKIP" "Claude Code: $(get_version claude)"
    else
        HAS_CLAUDE=false
        log_step "FAIL" "Claude Code: 未安装"
    fi

    # OpenClaw
    if command_exists openclaw; then
        HAS_OPENCLAW=true
        log_step "SKIP" "OpenClaw: $(get_version openclaw)"
    else
        HAS_OPENCLAW=false
        log_step "FAIL" "OpenClaw: 未安装"
    fi

    # Homebrew (macOS)
    if [ "$OS_TYPE" = "macOS" ] || [ "$PKG_MANAGER" = "brew" ]; then
        if command_exists brew; then
            HAS_HOMEBREW=true
            log_step "SKIP" "Homebrew: $(get_version brew)"
        else
            HAS_HOMEBREW=false
            log_step "FAIL" "Homebrew: 未安装"
        fi
    fi
}

# ============================================================
# 安装函数
# ============================================================

install_curl() {
    case "$PKG_MANAGER" in
        apt) $CURL_INSTALL_APT ;;
        yum) $CURL_INSTALL_YUM ;;
        dnf) $CURL_INSTALL_DNF ;;
        *)   echo "        请手动安装 curl" ;;
    esac
}

install_homebrew() {
    if [ "$HAS_HOMEBREW" = true ]; then
        log_step "SKIP" "Homebrew: 已安装，跳过"
        return
    fi
    log_step "INFO" "正在安装 Homebrew..."
    echo "        安装 Homebrew（官方脚本）..."
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        # 根据架构添加 Homebrew 到 PATH
        if [ "$(uname -m)" = "arm64" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
        fi
        HAS_HOMEBREW=true
        log_step "OK" "Homebrew: 安装成功 ($(get_version brew))"
    else
        log_step "FAIL" "Homebrew: 安装失败"
        FAIL_LIST+=("Homebrew")
        return 1
    fi
}

install_git() {
    if [ "$HAS_GIT" = true ]; then
        log_step "SKIP" "Git: 已安装，跳过"
        return
    fi
    log_step "INFO" "正在安装 Git..."
    local result=1
    case "$PKG_MANAGER" in
        brew)
            if ! $HAS_HOMEBREW; then
                install_homebrew
            fi
            $GIT_BREW_CMD && result=0
            ;;
        apt)   $GIT_APT_CMD && result=0 ;;
        yum)   $GIT_YUM_CMD && result=0 ;;
        dnf)   $GIT_DNF_CMD && result=0 ;;
        pacman) $GIT_PACMAN_CMD && result=0 ;;
        zypper) $GIT_ZYPPER_CMD && result=0 ;;
        *)
            echo "        无法确定包管理器，请手动安装 Git"
            log_step "FAIL" "Git: 未识别的包管理器"
            FAIL_LIST+=("Git")
            return 1
            ;;
    esac
    if [ $result -eq 0 ] && command_exists git; then
        HAS_GIT=true
        log_step "OK" "Git: 安装成功 ($(get_version git))"
    else
        log_step "FAIL" "Git: 安装失败"
        FAIL_LIST+=("Git")
    fi
}

install_nodejs() {
    if [ "$HAS_NODE" = true ]; then
        log_step "SKIP" "Node.js: 已安装，跳过"
        return
    fi
    log_step "INFO" "正在安装 Node.js LTS..."
    local result=1
    case "$PKG_MANAGER" in
        brew)
            if ! $HAS_HOMEBREW; then
                install_homebrew
            fi
            $NODE_BREW_CMD && result=0
            ;;
        apt)
            # 使用 NodeSource 官方仓库
            $NODE_NODESOURCE_CMD && result=0
            ;;
        yum|dnf)
            # 对于 RHEL/Fedora 系列，尝试 NodeSource 或直接用包管理器
            echo "        尝试通过包管理器安装 Node.js..."
            if [ "$PKG_MANAGER" = "dnf" ]; then
                sudo dnf module install -y nodejs:18/common 2>/dev/null || \
                sudo dnf install -y nodejs 2>/dev/null && result=0
            else
                sudo yum install -y nodejs 2>/dev/null && result=0
            fi
            ;;
        pacman)
            sudo pacman -S --noconfirm nodejs npm && result=0
            ;;
        zypper)
            sudo zypper install -y nodejs npm && result=0
            ;;
        *)
            echo "        无法确定包管理器，请手动安装 Node.js"
            echo "        官方下载: https://nodejs.org/"
            log_step "FAIL" "Node.js: 未识别的包管理器"
            FAIL_LIST+=("Node.js")
            return 1
            ;;
    esac
    if [ $result -eq 0 ] && command_exists node; then
        HAS_NODE=true
        HAS_NPM=true
        log_step "OK" "Node.js: 安装成功 ($(get_version node))"
        log_step "OK" "npm: 附带安装 ($(get_version npm))"
    else
        log_step "FAIL" "Node.js: 安装失败"
        FAIL_LIST+=("Node.js")
    fi
}

install_pnpm() {
    if [ "$HAS_PNPM" = true ]; then
        log_step "SKIP" "pnpm: 已安装，跳过"
        return
    fi
    if ! command_exists npm; then
        log_step "FAIL" "pnpm: 需要先安装 Node.js/npm"
        FAIL_LIST+=("pnpm")
        return
    fi
    log_step "INFO" "正在安装 pnpm..."
    if $PNPM_NPM_CMD; then
        HAS_PNPM=true
        log_step "OK" "pnpm: 安装成功 ($(get_version pnpm))"
    else
        # 尝试使用 corepack 作为备选
        echo "        npm 全局安装失败，尝试 corepack..."
        if corepack enable 2>/dev/null && corepack prepare pnpm@latest --activate 2>/dev/null; then
            HAS_PNPM=true
            log_step "OK" "pnpm: 通过 corepack 安装成功 ($(get_version pnpm))"
        else
            log_step "FAIL" "pnpm: 安装失败"
            FAIL_LIST+=("pnpm")
        fi
    fi
}

install_claude() {
    if [ "$HAS_CLAUDE" = true ]; then
        log_step "SKIP" "Claude Code: 已安装，跳过"
        return
    fi
    if ! command_exists curl; then
        log_step "FAIL" "Claude Code: 需要 curl，但未找到"
        FAIL_LIST+=("Claude Code")
        return
    fi
    log_step "INFO" "正在安装 Claude Code（官方安装脚本）..."
    if $CLAUDE_INSTALL_CMD; then
        if command_exists claude; then
            HAS_CLAUDE=true
            log_step "OK" "Claude Code: 安装成功 ($(get_version claude))"
            echo ""
            echo "  ⚠ 重要提示: Claude Code 安装完成后需要进行首次设置。"
            echo "    请运行 'claude' 命令，按提示完成:"
            echo "      1. 登录 Anthropic 账号"
            echo "      2. 配置 API Key"
            echo "    这些步骤必须由你本人操作，本脚本不会也不能替你完成。"
        else
            # claude 命令可能不在 PATH 中，等 shell 重启后生效
            HAS_CLAUDE=true
            log_step "OK" "Claude Code: 安装脚本执行完成（可能需要重新打开终端）"
        fi
    else
        log_step "FAIL" "Claude Code: 安装脚本执行失败"
        FAIL_LIST+=("Claude Code")
    fi
}

install_openclaw() {
    if [ "$HAS_OPENCLAW" = true ]; then
        log_step "SKIP" "OpenClaw: 已安装，跳过"
        return
    fi
    if ! command_exists curl; then
        log_step "FAIL" "OpenClaw: 需要 curl，但未找到"
        FAIL_LIST+=("OpenClaw")
        return
    fi
    log_step "INFO" "正在安装 OpenClaw（官方安装脚本）..."
    if $OPENCLAW_INSTALL_CMD; then
        if command_exists openclaw; then
            HAS_OPENCLAW=true
            log_step "OK" "OpenClaw: 安装成功 ($(get_version openclaw))"
            echo ""
            echo "  ⚠ 重要提示: OpenClaw 安装完成后需要进行首次配置。"
            echo "    请运行 'openclaw' 命令完成初始设置。"
            echo "    该过程可能涉及:"
            echo "      1. 登录账号"
            echo "      2. 配置 Git 集成"
            echo "    这些步骤必须由你本人操作，本脚本不会也不能替你完成。"
        else
            HAS_OPENCLAW=true
            log_step "OK" "OpenClaw: 安装脚本执行完成（可能需要重新打开终端）"
        fi
    else
        log_step "FAIL" "OpenClaw: 安装脚本执行失败"
        FAIL_LIST+=("OpenClaw")
    fi
}

# ============================================================
# 构建安装队列
# ============================================================

build_install_queue() {
    INSTALL_QUEUE=()
    # 按依赖顺序排列
    [ "$HAS_GIT" = false ] && INSTALL_QUEUE+=("Git")
    [ "$HAS_NODE" = false ] && INSTALL_QUEUE+=("Node.js LTS")
    [ "$HAS_PNPM" = false ] && INSTALL_QUEUE+=("pnpm")
    [ "$HAS_CLAUDE" = false ] && INSTALL_QUEUE+=("Claude Code")
    [ "$HAS_OPENCLAW" = false ] && INSTALL_QUEUE+=("OpenClaw")
}

# ============================================================
# 展示安装计划并请求确认
# ============================================================

show_plan_and_confirm() {
    echo ""
    echo "=========================================="
    echo "  安装计划"
    echo "=========================================="
    append_report ""
    append_report "--- 安装计划 ---"

    if [ ${#INSTALL_QUEUE[@]} -eq 0 ]; then
        echo "所有组件已安装，无需操作。"
        append_report "所有组件已安装，无需操作。"
        return 0
    fi

    echo "将按以下顺序安装 ${#INSTALL_QUEUE[@]} 个组件:"
    append_report "将安装 ${#INSTALL_QUEUE[@]} 个组件:"
    local i=1
    for step in "${INSTALL_QUEUE[@]}"; do
        echo "  ${i}. ${step}"
        append_report "  ${i}. ${step}"
        i=$((i + 1))
    done

    echo ""
    echo "安装报告将保存到: ${REPORT_FILE}"
    echo ""

    # 请求用户确认
    read -r -p "确认开始安装? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "已取消安装。"
        append_report "用户取消安装"
        exit 0
    fi
}

# ============================================================
# 执行安装
# ============================================================

execute_install() {
    echo ""
    echo "=========================================="
    echo "  开始安装"
    echo "=========================================="
    append_report ""
    append_report "--- 安装过程 ---"

    for step in "${INSTALL_QUEUE[@]}"; do
        echo ""
        case "$step" in
            "Git")         install_git ;;
            "Node.js LTS") install_nodejs ;;
            "pnpm")        install_pnpm ;;
            "Claude Code") install_claude ;;
            "OpenClaw")    install_openclaw ;;
        esac
    done
}

# ============================================================
# 安装摘要
# ============================================================

show_summary() {
    echo ""
    echo "=========================================="
    echo "  安装摘要"
    echo "=========================================="
    append_report ""
    append_report "--- 安装摘要 ---"
    local summary="成功: ${SUCCESS_COUNT}, 跳过: ${SKIP_COUNT}, 失败: ${FAIL_COUNT}"
    echo "$summary"
    append_report "$summary"

    if [ ${#FAIL_LIST[@]} -gt 0 ]; then
        echo ""
        echo "以下组件安装失败:"
        append_report "失败组件:"
        for item in "${FAIL_LIST[@]}"; do
            echo "  - ${item}"
            append_report "  - ${item}"
        done
        echo ""
        echo "请手动安装失败的组件后重新运行本脚本。"
    fi

    echo ""
    echo "完整报告已保存到: ${REPORT_FILE}"
    append_report ""
    append_report "=========================================="
    append_report "报告结束"
}

# ============================================================
# 后续步骤提示
# ============================================================

show_next_steps() {
    echo ""
    echo "=========================================="
    echo "  后续步骤"
    echo "=========================================="
    echo ""
    echo "  以下步骤需要你亲自操作，本脚本不会也不能自动完成:"
    echo ""
    echo "  1. Claude Code 首次设置:"
    echo "     运行: claude"
    echo "     - 登录 Anthropic 账号"
    echo "     - 输入 API Key"
    echo "     - 按提示完成初始化"
    echo ""
    echo "  2. OpenClaw 首次配置:"
    echo "     运行: openclaw"
    echo "     - 按提示完成账号登录和配置"
    echo ""
    echo "  3. 验证安装:"
    echo "     git --version"
    echo "     node --version"
    echo "     npm --version"
    echo "     pnpm --version"
    echo "     claude --version"
    echo "     openclaw --version"
    echo ""
    echo "  4. 如果某个命令提示 'command not found':"
    echo "     - 尝试关闭并重新打开终端"
    echo "     - 或运行: source ~/.bashrc (Linux)"
    echo "     - 或运行: source ~/.zshrc (macOS)"
    echo ""
    append_report ""
    append_report "--- 后续步骤 ---"
    append_report "用户需手动完成 Claude Code 和 OpenClaw 的首次登录配置"
}

# ============================================================
# 主流程
# ============================================================

main() {
    clear 2>/dev/null || true
    echo "=========================================="
    echo "  AI Coding Installer v1.0.0"
    echo "  macOS / Linux / WSL 安装脚本"
    echo "=========================================="
    echo ""
    echo "本脚本将检测你的开发环境，并安装以下工具:"
    echo "  - Git"
    echo "  - Node.js LTS"
    echo "  - pnpm"
    echo "  - Claude Code"
    echo "  - OpenClaw"
    echo ""
    echo "安全声明: 本脚本不会读取或保存你的密码/API Key/Token。"
    echo "登录和配置步骤必须由你本人完成。"
    echo ""

    init_report
    detect_os
    detect_tools
    build_install_queue
    show_plan_and_confirm
    execute_install
    show_summary
    show_next_steps
}

main "$@"

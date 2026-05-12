#!/usr/bin/env bash
# ============================================================
# AI Coding Installer — macOS / Linux / WSL 一键安装脚本
# 版本: 1.3.0
# 用途: 三档服务套餐安装 Claude Code + OpenClaw 所需依赖
# ============================================================
# 安全声明:
#   - 本脚本不读取、不保存、不上传任何密码/API Key/Token/Cookie
#   - 本脚本不修改系统安全策略
#   - 所有安装步骤均在用户确认后执行
#   - 安装报告仅保存在本地用户目录
# ============================================================

set -euo pipefail

# ============================================================
# 命令行参数解析
# ============================================================
DRY_RUN=false
CHECK_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --dry-run|-d)    DRY_RUN=true ;;
        --check-only|-c) CHECK_ONLY=true ;;
        --help|-h)
            echo "用法: ./install-mac-linux.sh [选项]"
            echo ""
            echo "选项:"
            echo "  --dry-run, -d     只检测环境、选择套餐、显示安装预览，不真正安装"
            echo "  --check-only, -c  只检测环境并生成报告，不进入套餐菜单"
            echo "  --help, -h        显示此帮助信息"
            exit 0
            ;;
        *)
            echo "未知选项: $arg"
            echo "使用 --help 查看可用选项"
            exit 1
            ;;
    esac
done

if [ "$DRY_RUN" = true ] && [ "$CHECK_ONLY" = true ]; then
    echo "错误: --dry-run 和 --check-only 不能同时使用"
    exit 1
fi

# ============================================================
# 安装命令配置区（URL / 包名）
# 带管道的命令已封装为函数，见下方"安装函数"区
# ============================================================

CLAUDE_INSTALL_URL="https://claude.ai/install.sh"
OPENCLAW_INSTALL_URL="https://openclaw.ai/install.sh"
NODE_NODESOURCE_URL="https://deb.nodesource.com/setup_lts.x"

# ============================================================
# 全局变量
# ============================================================
REPORT_FILE="$HOME/ai-coding-install-report.txt"
TIMESTAMP=""
SUCCESS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0
MISSING_COUNT=0
declare -a INSTALL_QUEUE=()
declare -a FAIL_LIST=()
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
NEED_NODE_UPGRADE=false

# 套餐选择
PLAN_CHOICE=0
PLAN_NAME=""
PLAN_PRICE=""
PLAN_SUPPORT=""
PLAN_TUTORIAL=true
PLAN_WORKFLOW_COUNT=0
INSTALL_CLAUDE=false
INSTALL_OPENCLAW=false
TOOL_CHOICE_NAME=""

# ============================================================
# 工具函数
# ============================================================

init_report() {
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    local title="安装报告"
    if [ "$CHECK_ONLY" = true ]; then
        title="[CHECK-ONLY] 环境检测报告"
    elif [ "$DRY_RUN" = true ]; then
        title="[DRY-RUN] 安装预览报告"
    fi

    cat > "$REPORT_FILE" << EOF
==========================================
  AI Coding Installer — ${title}
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
    local status="$1"
    local message="$2"
    local time_str
    time_str=$(date '+%H:%M:%S')
    local prefix=""
    case "$status" in
        OK)      prefix="[${time_str}] ✓"; SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) ;;
        SKIP)    prefix="[${time_str}] ○"; SKIP_COUNT=$((SKIP_COUNT + 1)) ;;
        FAIL)    prefix="[${time_str}] ✗"; FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
        INFO)    prefix="[${time_str}] ▶" ;;
        MISSING) prefix="[${time_str}] ◇"; MISSING_COUNT=$((MISSING_COUNT + 1)) ;;
        WARN)    prefix="[${time_str}] ⚠" ;;
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

check_node_version() {
    local node_ver
    node_ver=$(node --version 2>/dev/null | sed 's/^v//')
    if [ -z "$node_ver" ]; then
        return 1
    fi
    NODE_VERSION="v${node_ver}"
    local major minor
    major=$(echo "$node_ver" | cut -d. -f1)
    minor=$(echo "$node_ver" | cut -d. -f2)
    if [ "$major" -lt 22 ] 2>/dev/null; then
        NODE_VERSION_LOW=true
        log_step "WARN" "Node.js 版本 ${NODE_VERSION} 低于推荐版本。OpenClaw 推荐 Node 24 或 Node 22.16+"
    elif [ "$major" -eq 22 ] && [ "$minor" -lt 16 ] 2>/dev/null; then
        NODE_VERSION_LOW=true
        log_step "WARN" "Node.js 版本 ${NODE_VERSION} 低于推荐版本。OpenClaw 推荐 Node 24 或 Node 22.16+"
    fi
}

get_install_command() {
    case "$1" in
        "curl")
            case "$PKG_MANAGER" in
                apt) echo "sudo apt-get install -y curl" ;;
                yum) echo "sudo yum install -y curl" ;;
                dnf) echo "sudo dnf install -y curl" ;;
                *)   echo "通过 $PKG_MANAGER 安装 curl" ;;
            esac ;;
        "Git")
            case "$PKG_MANAGER" in
                brew) echo "brew install git" ;;
                apt) echo "sudo apt-get install -y git" ;;
                yum) echo "sudo yum install -y git" ;;
                dnf) echo "sudo dnf install -y git" ;;
                pacman) echo "sudo pacman -S --noconfirm git" ;;
                zypper) echo "sudo zypper install -y git" ;;
                *) echo "通过 $PKG_MANAGER 安装" ;;
            esac ;;
        "Node.js LTS")
            case "$PKG_MANAGER" in
                brew) echo "brew install node" ;;
                apt) echo "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs" ;;
                dnf) echo "sudo dnf install -y nodejs" ;;
                yum) echo "sudo yum install -y nodejs" ;;
                pacman) echo "sudo pacman -S --noconfirm nodejs npm" ;;
                zypper) echo "sudo zypper install -y nodejs npm" ;;
                *) echo "通过 $PKG_MANAGER 安装" ;;
            esac ;;
        "pnpm") echo "npm install -g pnpm (备选: corepack)" ;;
        "Claude Code") echo "curl -fsSL https://claude.ai/install.sh | bash" ;;
        "OpenClaw") echo "curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard" ;;
    esac
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
            if grep -qi microsoft /proc/version 2>/dev/null; then
                OS_TYPE="WSL"
                OS_NAME="WSL"
            elif [ -f /proc/sys/fs/binfmt_misc/WSL ] 2>/dev/null; then
                OS_TYPE="WSL"
                OS_NAME="WSL (v1)"
            else
                OS_TYPE="Linux"
            fi
            if [ -f /etc/os-release ]; then
                local distro version
                distro=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
                version=$(grep "^VERSION_ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
                OS_NAME="${distro} ${version}"
            fi
            detect_pkg_manager
            ;;
        *)
            echo "错误: 不支持的操作系统: $kernel"
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
# 环境检测（只检测，不安装任何东西）
# ============================================================

detect_tools() {
    echo ""
    echo "--- 环境检测 ---"
    append_report ""
    append_report "--- 环境检测 ---"

    # curl — 仅记录缺失，安装动作在确认后的队列中执行
    if command_exists curl; then
        HAS_CURL=true
        log_step "SKIP" "curl: $(get_version curl)"
    else
        HAS_CURL=false
        log_step "MISSING" "curl: 未安装"
    fi

    if command_exists git; then
        HAS_GIT=true
        log_step "SKIP" "Git: $(get_version git)"
    else
        HAS_GIT=false
        log_step "MISSING" "Git: 未安装"
    fi

    if command_exists node; then
        HAS_NODE=true
        log_step "SKIP" "Node.js: $(get_version node)"
        check_node_version
    else
        HAS_NODE=false
        log_step "MISSING" "Node.js: 未安装"
    fi

    if command_exists npm; then
        HAS_NPM=true
        log_step "SKIP" "npm: $(get_version npm)"
    else
        HAS_NPM=false
        log_step "MISSING" "npm: 未安装"
    fi

    if command_exists pnpm; then
        HAS_PNPM=true
        log_step "SKIP" "pnpm: $(get_version pnpm)"
    else
        HAS_PNPM=false
        log_step "MISSING" "pnpm: 未安装"
    fi

    if command_exists claude; then
        HAS_CLAUDE=true
        log_step "SKIP" "Claude Code: $(get_version claude)"
    else
        HAS_CLAUDE=false
        log_step "MISSING" "Claude Code: 未安装"
    fi

    if command_exists openclaw; then
        HAS_OPENCLAW=true
        log_step "SKIP" "OpenClaw: $(get_version openclaw)"
    else
        HAS_OPENCLAW=false
        log_step "MISSING" "OpenClaw: 未安装"
    fi

    if [ "$OS_TYPE" = "macOS" ] || [ "$PKG_MANAGER" = "brew" ]; then
        if command_exists brew; then
            HAS_HOMEBREW=true
            log_step "SKIP" "Homebrew: $(get_version brew)"
        else
            HAS_HOMEBREW=false
            log_step "MISSING" "Homebrew: 未安装"
        fi
    fi
}

# ============================================================
# 套餐菜单
# ============================================================

select_plan() {
    echo ""
    echo "=========================================="
    echo "  选择服务套餐"
    echo "=========================================="
    echo ""
    echo "  1. 基础上手包  ¥58"
    echo "     ▸ 安装: Claude Code 或 OpenClaw (二选一)"
    echo "     ▸ 交付: 新手教程"
    echo "     ▸ 售后: 7 天"
    echo ""
    echo "  2. 进阶工作流包  ¥98"
    echo "     ▸ 安装: Claude Code 或 OpenClaw (二选一)"
    echo "     ▸ 交付: 新手教程 + 5 套指定工作流教程"
    echo "     ▸ 售后: 14 天"
    echo ""
    echo "  3. 全套效率包  ¥158/¥198"
    echo "     ▸ 安装: Claude Code + OpenClaw (两个都装)"
    echo "     ▸ 交付: 新手教程 + 10 套指定工作流教程"
    echo "     ▸ 售后: 14 天"
    echo ""
    echo "  4. 只检测环境 (不安装任何软件)"
    echo ""
    echo "  5. 退出"
    echo ""
    echo "=========================================="

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN 模式: 仅预览，不真正安装]"
        echo ""
    fi

    while true; do
        read -r -p "请输入选项 (1/2/3/4/5): " choice
        case "$choice" in
            1)
                PLAN_CHOICE=1
                PLAN_NAME="基础上手包"
                PLAN_PRICE="¥58"
                PLAN_SUPPORT="7 天"
                PLAN_TUTORIAL=true
                PLAN_WORKFLOW_COUNT=0
                select_tool
                return
                ;;
            2)
                PLAN_CHOICE=2
                PLAN_NAME="进阶工作流包"
                PLAN_PRICE="¥98"
                PLAN_SUPPORT="14 天"
                PLAN_TUTORIAL=true
                PLAN_WORKFLOW_COUNT=5
                select_tool
                return
                ;;
            3)
                PLAN_CHOICE=3
                PLAN_NAME="全套效率包"
                PLAN_PRICE="¥158/¥198"
                PLAN_SUPPORT="14 天"
                PLAN_TUTORIAL=true
                PLAN_WORKFLOW_COUNT=10
                INSTALL_CLAUDE=true
                INSTALL_OPENCLAW=true
                TOOL_CHOICE_NAME="Claude Code + OpenClaw"
                return
                ;;
            4)
                PLAN_CHOICE=4
                PLAN_NAME="仅环境检测"
                PLAN_PRICE="-"
                PLAN_SUPPORT="-"
                PLAN_TUTORIAL=false
                PLAN_WORKFLOW_COUNT=0
                return
                ;;
            5)
                echo "已退出。"
                append_report "用户退出"
                exit 0
                ;;
            *)
                echo "无效选项，请输入 1-5"
                ;;
        esac
    done
}

select_tool() {
    echo ""
    echo "  请选择要安装的工具:"
    echo "  A. Claude Code"
    echo "  B. OpenClaw"
    echo ""

    while true; do
        read -r -p "请输入 (A/B): " tool
        case "$(echo "$tool" | tr '[:lower:]' '[:upper:]')" in
            A)
                INSTALL_CLAUDE=true
                INSTALL_OPENCLAW=false
                TOOL_CHOICE_NAME="Claude Code"
                return
                ;;
            B)
                INSTALL_CLAUDE=false
                INSTALL_OPENCLAW=true
                TOOL_CHOICE_NAME="OpenClaw"
                return
                ;;
            *)
                echo "无效选项，请输入 A 或 B"
                ;;
        esac
    done
}

log_plan_info() {
    append_report ""
    append_report "--- 套餐信息 ---"
    append_report "套餐名称: ${PLAN_NAME}"
    append_report "价格: ${PLAN_PRICE}"
    append_report "售后: ${PLAN_SUPPORT}"
    append_report "选择安装: ${TOOL_CHOICE_NAME}"
    append_report "新手教程: $([ "$PLAN_TUTORIAL" = true ] && echo '是' || echo '否')"
    append_report "指定工作流数量: ${PLAN_WORKFLOW_COUNT}"
}

# ============================================================
# 安装队列（依赖顺序: curl → Git → Node → pnpm → Claude/OpenClaw）
# ============================================================

build_install_queue() {
    INSTALL_QUEUE=()

    if [ "$HAS_CURL" = false ]; then
        INSTALL_QUEUE+=("curl")
    fi
    if [ "$HAS_GIT" = false ]; then
        INSTALL_QUEUE+=("Git")
    fi
    if [ "$HAS_NODE" = false ] || [ "$NEED_NODE_UPGRADE" = true ]; then
        INSTALL_QUEUE+=("Node.js LTS")
    fi
    if [ "$HAS_PNPM" = false ]; then
        INSTALL_QUEUE+=("pnpm")
    fi

    if [ "$INSTALL_CLAUDE" = true ] && [ "$HAS_CLAUDE" = false ]; then
        INSTALL_QUEUE+=("Claude Code")
    fi
    if [ "$INSTALL_OPENCLAW" = true ] && [ "$HAS_OPENCLAW" = false ]; then
        INSTALL_QUEUE+=("OpenClaw")
    fi
}

# ============================================================
# 安装计划展示
# ============================================================

show_plan_and_confirm() {
    echo ""

    if [ "$DRY_RUN" = true ]; then
        echo "=========================================="
        echo "  [DRY-RUN] 安装预览"
        echo "=========================================="
        append_report ""
        append_report "--- [DRY-RUN] 安装预览 ---"
    else
        echo "=========================================="
        echo "  安装计划"
        echo "=========================================="
        append_report ""
        append_report "--- 安装计划 ---"
    fi

    echo "套餐: ${PLAN_NAME} (${PLAN_PRICE})"
    echo "售后: ${PLAN_SUPPORT}"
    echo "安装工具: ${TOOL_CHOICE_NAME}"
    echo "新手教程: $([ "$PLAN_TUTORIAL" = true ] && echo '是' || echo '否')"
    echo "指定工作流: ${PLAN_WORKFLOW_COUNT} 套"
    append_report "套餐: ${PLAN_NAME} (${PLAN_PRICE})"
    append_report "售后: ${PLAN_SUPPORT}"
    append_report "安装工具: ${TOOL_CHOICE_NAME}"
    append_report "新手教程: $([ "$PLAN_TUTORIAL" = true ] && echo '是' || echo '否')"
    append_report "指定工作流数量: ${PLAN_WORKFLOW_COUNT}"

    echo ""

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
        if [ "$DRY_RUN" = true ]; then
            local cmd
            cmd=$(get_install_command "$step")
            echo "      → ${cmd}"
            append_report "      → ${cmd}"
        fi
        i=$((i + 1))
    done

    # Node 版本警告 + 升级询问：选了 OpenClaw 且 Node 已安装但版本过低
    if [ "$INSTALL_OPENCLAW" = true ] && [ "$NODE_VERSION_LOW" = true ] && [ "$HAS_NODE" = true ]; then
        echo ""
        echo "  ⚠ Node.js 版本 ${NODE_VERSION} 低于 OpenClaw 推荐版本 (24 或 22.16+)。"
        if [ "$DRY_RUN" = true ]; then
            echo "    安装计划中不会自动升级 Node。如需升级请手动操作。"
            append_report "⚠ Node 版本过低 (${NODE_VERSION})，OpenClaw 推荐 24 或 22.16+"
        else
            read -r -p "  是否升级 Node.js? (y/N): " UPGRADE_NODE
            if [ "$UPGRADE_NODE" = "y" ] || [ "$UPGRADE_NODE" = "Y" ]; then
                NEED_NODE_UPGRADE=true
                # 重新构建队列以纳入 Node 升级
                build_install_queue
                echo "  已确认升级 Node.js。"
                append_report "用户确认升级 Node.js (${NODE_VERSION} → LTS)"
            else
                echo "  将继续安装 OpenClaw，但报告已记录版本风险。"
                append_report "⚠ 用户选择不升级 Node (${NODE_VERSION})，OpenClaw 可能在低版本下不稳定"
            fi
        fi
    fi

    if [ "$DRY_RUN" = true ]; then
        echo ""
        echo "[DRY-RUN] 以上为预览，未执行任何安装操作。"
        echo "安装报告已保存到: ${REPORT_FILE}"
        append_report "[DRY-RUN] 以上为预览，未执行任何安装操作。"
        return 1
    fi

    echo ""
    echo "安装报告将保存到: ${REPORT_FILE}"
    echo ""

    read -r -p "确认开始安装? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "已取消安装。"
        append_report "用户取消安装"
        exit 0
    fi
}

# ============================================================
# 安装函数（带管道命令已封装为函数，不再用字符串变量）
# ============================================================

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
        log_step "SKIP" "curl: 已安装，跳过"
        return
    fi
    log_step "INFO" "正在安装 curl..."
    case "$PKG_MANAGER" in
        apt) sudo apt-get install -y curl ;;
        yum) sudo yum install -y curl ;;
        dnf) sudo dnf install -y curl ;;
        *)
            echo "        无法确定包管理器，请手动安装 curl"
            log_step "FAIL" "curl: 未识别的包管理器，请手动安装"
            FAIL_LIST+=("curl")
            return 1
            ;;
    esac
    if command_exists curl; then
        HAS_CURL=true
        log_step "OK" "curl: 安装成功 ($(get_version curl))"
    else
        log_step "FAIL" "curl: 安装失败，后续依赖 curl 的步骤也会失败"
        FAIL_LIST+=("curl")
    fi
}

install_homebrew() {
    if [ "$HAS_HOMEBREW" = true ]; then
        log_step "SKIP" "Homebrew: 已安装，跳过"
        return
    fi
    log_step "INFO" "正在安装 Homebrew..."
    echo "        安装 Homebrew（官方脚本）..."
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
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
            brew install git && result=0
            ;;
        apt)   sudo apt-get update -qq && sudo apt-get install -y git && result=0 ;;
        yum)   sudo yum install -y git && result=0 ;;
        dnf)   sudo dnf install -y git && result=0 ;;
        pacman) sudo pacman -S --noconfirm git && result=0 ;;
        zypper) sudo zypper install -y git && result=0 ;;
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
    if [ "$HAS_NODE" = true ] && [ "$NEED_NODE_UPGRADE" != true ]; then
        log_step "SKIP" "Node.js: 已安装，跳过"
        return
    fi
    if [ "$NEED_NODE_UPGRADE" = true ]; then
        log_step "INFO" "正在升级 Node.js (当前: $(get_version node))..."
    else
        log_step "INFO" "正在安装 Node.js LTS..."
    fi
    local result=1
    case "$PKG_MANAGER" in
        brew)
            if ! $HAS_HOMEBREW; then
                install_homebrew
            fi
            brew install node && result=0
            ;;
        apt)
            install_nodejs_nodesource && result=0
            ;;
        yum|dnf)
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
        NEED_NODE_UPGRADE=false
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
    if npm install -g pnpm; then
        HAS_PNPM=true
        log_step "OK" "pnpm: 安装成功 ($(get_version pnpm))"
    else
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
    if install_claude_official; then
        if command_exists claude; then
            HAS_CLAUDE=true
            log_step "OK" "Claude Code: 安装成功 ($(get_version claude))"
        else
            HAS_CLAUDE=true
            log_step "OK" "Claude Code: 安装脚本执行完成（可能需要重新打开终端）"
        fi
        echo ""
        echo "  ⚠ Claude Code 安装完成后需要你本人运行 'claude' 完成首次设置。"
        echo "    登录、验证码、API Key 均由你本人输入。"
        echo "    服务人员不索要、不查看、不记录这些信息。"
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
    log_step "INFO" "正在安装 OpenClaw（官方安装脚本, no-onboard 模式）..."
    if install_openclaw_official; then
        if command_exists openclaw; then
            HAS_OPENCLAW=true
            log_step "OK" "OpenClaw: 安装成功 ($(get_version openclaw))"
        else
            HAS_OPENCLAW=true
            log_step "OK" "OpenClaw: 安装脚本执行完成（可能需要重新打开终端）"
        fi
        echo ""
        echo "  ⚠ OpenClaw 安装完成后需要你本人运行 'openclaw' 完成首次配置。"
        echo "    该过程涉及: onboarding 引导、登录账号、配置 API Key。"
        echo "    登录、验证码、密码、API Key 均由你本人输入。"
        echo "    服务人员不索要、不查看、不记录这些信息。"
    else
        log_step "FAIL" "OpenClaw: 安装脚本执行失败"
        FAIL_LIST+=("OpenClaw")
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
            "curl")        install_curl_step ;;
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

    if [ "$PLAN_CHOICE" -eq 4 ]; then
        echo "=========================================="
        echo "  环境检测摘要"
        echo "=========================================="
        append_report ""
        append_report "--- 环境检测摘要 ---"
        local summary="已就绪: ${SKIP_COUNT}, 缺失: ${MISSING_COUNT}"
        echo "$summary"
        append_report "$summary"
    elif [ "$DRY_RUN" = true ]; then
        echo "=========================================="
        echo "  安装预览摘要"
        echo "=========================================="
        append_report ""
        append_report "--- 安装预览摘要 ---"
        local summary="套餐: ${PLAN_NAME}, 待安装: ${#INSTALL_QUEUE[@]}, 已就绪: ${SKIP_COUNT}, 缺失: ${MISSING_COUNT}"
        echo "$summary"
        append_report "$summary"
        echo ""
        echo "[DRY-RUN] 未执行任何安装操作。"
        append_report "[DRY-RUN] 未执行任何安装操作。"
    else
        echo "=========================================="
        echo "  安装摘要"
        echo "=========================================="
        append_report ""
        append_report "--- 安装摘要 ---"
        local summary="成功: ${SUCCESS_COUNT}, 跳过: ${SKIP_COUNT}, 缺失: ${MISSING_COUNT}, 失败: ${FAIL_COUNT}"
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
        echo "套餐: ${PLAN_NAME} (${PLAN_PRICE}) | 售后: ${PLAN_SUPPORT}"
        echo "新手教程: $([ "$PLAN_TUTORIAL" = true ] && echo '是' || echo '否') | 指定工作流: ${PLAN_WORKFLOW_COUNT} 套"
        append_report "套餐: ${PLAN_NAME} (${PLAN_PRICE}) | 售后: ${PLAN_SUPPORT}"
        append_report "新手教程: $([ "$PLAN_TUTORIAL" = true ] && echo '是' || echo '否') | 指定工作流: ${PLAN_WORKFLOW_COUNT} 套"
    fi

    echo ""
    echo "完整报告已保存到: ${REPORT_FILE}"
    append_report ""
    append_report "=========================================="
    append_report "报告结束"
}

# ============================================================
# 后续步骤
# ============================================================

show_next_steps() {
    if [ "$PLAN_CHOICE" -eq 4 ] || [ "$DRY_RUN" = true ]; then
        return
    fi

    echo ""
    echo "=========================================="
    echo "  后续步骤"
    echo "=========================================="
    echo ""
    echo "  安装完成。以下步骤需要用户亲自操作:"
    echo ""

    if [ "$INSTALL_CLAUDE" = true ]; then
        echo "  ▸ Claude Code 首次设置:"
        echo "    运行: claude"
        echo "    - 登录 Anthropic 账号"
        echo "    - 输入 API Key"
        echo ""
    fi

    if [ "$INSTALL_OPENCLAW" = true ]; then
        echo "  ▸ OpenClaw 首次配置:"
        echo "    运行: openclaw"
        echo "    - 完成 onboarding 引导"
        echo "    - 登录账号并配置 API Key"
        echo ""
    fi

    echo "  ▸ 交付提醒:"
    if [ "$PLAN_TUTORIAL" = true ]; then
        echo "    - 新手教程"
    fi
    if [ "$PLAN_WORKFLOW_COUNT" -gt 0 ]; then
        echo "    - ${PLAN_WORKFLOW_COUNT} 套指定工作流教程"
    fi
    echo "    请在安装完成后向用户交付对应内容。"
    echo ""

    echo "  ▸ 验证安装:"
    echo "     git --version; node --version; npm --version; pnpm --version"
    if [ "$INSTALL_CLAUDE" = true ]; then echo "     claude --version"; fi
    if [ "$INSTALL_OPENCLAW" = true ]; then echo "     openclaw --version"; fi
    echo ""
    echo "  登录、验证码、密码、API Key 均由用户本人输入。"
    echo "  服务人员不索要、不查看、不记录这些信息。"
    echo ""

    append_report ""
    append_report "--- 后续步骤 ---"
    append_report "新手教程: $([ "$PLAN_TUTORIAL" = true ] && echo '是' || echo '否')"
    append_report "指定工作流: ${PLAN_WORKFLOW_COUNT} 套"
    append_report "用户需手动完成首次登录配置"
}

# ============================================================
# 主流程
# ============================================================

main() {
    clear 2>/dev/null || true
    echo "=========================================="
    echo "  AI Coding Installer v1.3.0"
    echo "  macOS / Linux / WSL 安装脚本"
    if [ "$DRY_RUN" = true ]; then
        echo "  模式: DRY-RUN (仅预览，不安装)"
    elif [ "$CHECK_ONLY" = true ]; then
        echo "  模式: CHECK-ONLY (仅检测环境)"
    fi
    echo "=========================================="
    echo ""

    init_report
    detect_os
    detect_tools

    if [ "$CHECK_ONLY" = true ]; then
        PLAN_CHOICE=4
        show_summary
        exit 0
    fi

    select_plan

    if [ "$PLAN_CHOICE" -eq 4 ]; then
        log_plan_info
        show_summary
        exit 0
    fi

    log_plan_info
    build_install_queue
    if show_plan_and_confirm; then
        execute_install
    fi
    show_summary
    show_next_steps
}

main "$@"

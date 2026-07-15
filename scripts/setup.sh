#!/bin/bash
# ============================================================
# 绿联论坛积分监控 - 一键安装脚本
# 支持 Ubuntu / Debian / CentOS / macOS
# ============================================================

set -e

INSTALL_DIR="$HOME/ugnas-credits-monitor"
DATA_DIR="$HOME/.hermes/data/ugnas"
CRON_TAG="# ugnas-credits-monitor"
VENV_DIR="$INSTALL_DIR/venv"

# 国内 pip 镜像源（阿里云）
PIP_INDEX="https://mirrors.aliyun.com/pypi/simple/"
PIP_TRUSTED="mirrors.aliyun.com"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# ─── 检查 Python ────────────────────────────────────
check_python() {
    if command -v python3 &>/dev/null; then
        PYTHON=python3
    elif command -v python &>/dev/null; then
        PYTHON=python
    else
        error "未找到 Python，请先安装 Python 3.7+"
        exit 1
    fi
    PY_VER=$($PYTHON -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    info "Python 版本: $PY_VER"
}

# ─── 创建虚拟环境 ───────────────────────────────────
setup_venv() {
    info "配置虚拟环境..."

    if ! $PYTHON -c "import venv" &>/dev/null; then
        warn "venv 模块不可用，尝试安装..."
        if command -v apt &>/dev/null; then
            PY_SHORT=$($PYTHON -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
            sudo apt install -y "python${PY_SHORT}-venv" 2>/dev/null || {
                error "请手动安装 python${PY_SHORT}-venv: apt install python${PY_SHORT}-venv"
                exit 1
            }
        else
            error "无法自动安装 venv 模块，请手动安装"
            exit 1
        fi
    fi

    if [ ! -d "$VENV_DIR" ]; then
        $PYTHON -m venv "$VENV_DIR"
        info "虚拟环境已创建: $VENV_DIR"
    else
        info "虚拟环境已存在，跳过创建"
    fi

    PYTHON="$VENV_DIR/bin/python"
    PIP="$VENV_DIR/bin/pip"
    info "使用虚拟环境 Python: $PYTHON"
}

# ─── 安装依赖 ────────────────────────────────────────
install_deps() {
    info "安装 Python 依赖（使用阿里云镜像）..."
    $PIP install --quiet --upgrade pip \
        -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED"
    $PIP install --quiet requests pycryptodome \
        -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED"
    info "依赖安装完成"
}

# ─── 释放脚本 ────────────────────────────────────────
install_scripts() {
    # SCRIPT_DIR = setup.sh 所在目录，脚本和 setup.sh 同级
    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

    mkdir -p "$INSTALL_DIR/scripts"
    mkdir -p "$DATA_DIR"

    for f in ugnas_credits.py run_daily.sh; do
        if [ ! -f "$SCRIPT_DIR/$f" ]; then
            error "未找到 $SCRIPT_DIR/$f，请确保三个文件在同一目录"
            exit 1
        fi
        cp "$SCRIPT_DIR/$f" "$INSTALL_DIR/scripts/$f"
    done

    chmod +x "$INSTALL_DIR/scripts/run_daily.sh"
    info "脚本已释放到 $INSTALL_DIR/scripts/"
}

# ─── 交互式配置 ──────────────────────────────────────
configure() {
    # 如果 .env 已存在，询问是否保留
    if [ -f "$INSTALL_DIR/.env" ]; then
        echo ""
        warn "已存在 .env 配置文件"
        read -rp "是否重新配置？(y/N): " RECONFIG
        RECONFIG=${RECONFIG:-N}
        if [[ ! "$RECONFIG" =~ ^[Yy]$ ]]; then
            info "保留现有配置"
            return
        fi
    fi

    echo ""
    echo "═══════════════════════════════════════"
    echo "  绿联论坛积分监控 - 配置向导"
    echo "═══════════════════════════════════════"
    echo ""

    read -rp "绿联论坛手机号: " UG_USER
    read -rsp "绿联论坛密码: " UG_PASS
    echo ""
    read -rp "用户 UID (留空自动获取): " UG_UID

    echo ""
    echo "───────────────────────────────────────"
    echo "Server酱3 推送配置"
    echo "  获取地址: https://sct.ft07.com/"
    echo "───────────────────────────────────────"
    read -rp "Server酱3 SendKey: " SC_KEY

    # 用 Python 安全写入 .env（避免密码中的特殊字符被 shell 转义）
    $PYTHON -c "
import sys, os

lines = [
    f'UGNAS_USERNAME={sys.argv[1]}',
    f'UGNAS_PASSWORD={sys.argv[2]}',
    f'UGNAS_UID={sys.argv[3]}',
    f'SC_KEY={sys.argv[4]}',
]

env_path = sys.argv[5]
os.makedirs(os.path.dirname(env_path), exist_ok=True)
with open(env_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines) + '\n')
os.chmod(env_path, 0o600)
" "$UG_USER" "$UG_PASS" "$UG_UID" "$SC_KEY" "$INSTALL_DIR/.env"

    info ".env 已保存，权限 600"
}

# ─── 设置定时任务 ────────────────────────────────────
setup_cron() {
    echo ""
    read -rp "是否设置每日定时任务？(Y/n): " DO_CRON
    DO_CRON=${DO_CRON:-Y}

    if [[ "$DO_CRON" =~ ^[Yy]$ ]]; then
        read -rp "执行时间 (cron 表达式，默认每天 9:00): " CRON_EXPR
        CRON_EXPR=${CRON_EXPR:-"0 9 * * *"}

        # 校验 cron 表达式格式（5 个字段）
        FIELD_COUNT=$(echo "$CRON_EXPR" | wc -w)
        if [ "$FIELD_COUNT" -ne 5 ]; then
            warn "cron 表达式无效: $CRON_EXPR，使用默认 0 9 * * *"
            CRON_EXPR="0 9 * * *"
        fi

        crontab -l 2>/dev/null | grep -v "$CRON_TAG" | crontab - 2>/dev/null || true
        (crontab -l 2>/dev/null; echo "$CRON_EXPR $INSTALL_DIR/scripts/run_daily.sh $CRON_TAG") | crontab -
        info "定时任务已设置: $CRON_EXPR"
    fi
}

# ─── 测试运行 ────────────────────────────────────────
test_run() {
    echo ""
    read -rp "是否立即测试运行？(Y/n): " DO_TEST
    DO_TEST=${DO_TEST:-Y}

    if [[ "$DO_TEST" =~ ^[Yy]$ ]]; then
        info "正在测试运行..."
        echo ""
        if [ -f "$INSTALL_DIR/.env" ]; then
            set -a
            source "$INSTALL_DIR/.env"
            set +a
        fi
        $PYTHON "$INSTALL_DIR/scripts/ugnas_credits.py"
        echo ""
        # 测试推送
        "$INSTALL_DIR/scripts/run_daily.sh"
    fi
}

# ─── 主流程 ──────────────────────────────────────────
main() {
    echo ""
    echo "🍋 绿联论坛积分监控 - 一键安装"
    echo "═══════════════════════════════════════"
    echo ""

    check_python
    setup_venv
    install_deps
    install_scripts
    configure
    setup_cron
    test_run

    echo ""
    echo "═══════════════════════════════════════"
    info "安装完成！"
    echo ""
    echo "  安装目录: $INSTALL_DIR"
    echo "  虚拟环境: $VENV_DIR"
    echo "  数据目录: $DATA_DIR"
    echo "  配置文件: $INSTALL_DIR/.env"
    echo "  手动运行: $INSTALL_DIR/scripts/run_daily.sh"
    echo "  查看日志: cat $DATA_DIR/cron.log"
    echo ""
    echo "  激活虚拟环境: source $VENV_DIR/bin/activate"
    echo "═══════════════════════════════════════"
    echo ""
}

main "$@"

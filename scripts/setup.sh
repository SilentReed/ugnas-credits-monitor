#!/bin/bash
# ============================================================
# 绿联论坛积分监控 - 一键安装脚本
# 支持 Ubuntu / Debian / CentOS / macOS
# ============================================================

set -e

INSTALL_DIR="$HOME/ugnas-credits-monitor"
DATA_DIR="$HOME/.hermes/data/ugnas"
CRON_TAG="# ugnas-credits-monitor"

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

# ─── 安装依赖 ────────────────────────────────────────
install_deps() {
    info "安装 Python 依赖..."
    $PYTHON -m pip install --quiet requests pycryptodome 2>/dev/null || {
        warn "pip 安装失败，尝试 --user 模式..."
        $PYTHON -m pip install --quiet --user requests pycryptodome
    }
    info "依赖安装完成"
}

# ─── 下载脚本 ────────────────────────────────────────
download_scripts() {
    mkdir -p "$INSTALL_DIR/scripts"
    mkdir -p "$DATA_DIR"

    SCRIPT_URL="https://raw.githubusercontent.com/SilentReed/ugnas-credits-monitor/main/scripts/ugnas_credits.py"
    WRAPPER_URL="https://raw.githubusercontent.com/SilentReed/ugnas-credits-monitor/main/scripts/run_daily.sh"

    info "下载积分查询脚本..."
    curl -sL "$SCRIPT_URL" -o "$INSTALL_DIR/scripts/ugnas_credits.py" || {
        error "下载失败，请检查网络"
        exit 1
    }

    info "下载定时执行脚本..."
    curl -sL "$WRAPPER_URL" -o "$INSTALL_DIR/scripts/run_daily.sh" || {
        warn "run_daily.sh 下载失败，将创建默认版本"
        create_default_wrapper
    }

    chmod +x "$INSTALL_DIR/scripts/run_daily.sh" 2>/dev/null || true
    info "脚本下载完成"
}

# ─── 创建默认 wrapper ────────────────────────────────
create_default_wrapper() {
    cat > "$INSTALL_DIR/scripts/run_daily.sh" << 'WRAPPER'
#!/bin/bash
# 绿联积分日报 - 定时执行 wrapper + Server酱3 推送
export UGNAS_USERNAME="__USERNAME__"
export UGNAS_PASSWORD="__PASSWORD__"
export UGNAS_UID="__UID__"

SENDKEY="__SENDKEY__"
LOG="$HOME/.hermes/data/ugnas/cron.log"

cd "__INSTALL_DIR__"

OUTPUT=$($PYTHON scripts/ugnas_credits.py 2>&1)
EXIT_CODE=$?

echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG"
echo "$OUTPUT" >> "$LOG"

if [ $EXIT_CODE -eq 0 ]; then
    TITLE="绿联积分日报 $(date '+%m-%d')"
else
    TITLE="绿联积分查询失败 $(date '+%m-%d')"
fi

$PYTHON -c "
import json, requests, sys

title = sys.argv[1]
raw = sys.argv[2]
sendkey = sys.argv[3]

lines = raw.strip().split('\n')
data_lines = [line.strip() for line in lines[1:] if line.strip()]
desp = '\n\n'.join(data_lines)

short_desc = ''
for line in data_lines:
    if '当前积分' in line:
        short_desc = line.replace('💰 ', '')
        break

url = f'https://606.push.ft07.com/send/{sendkey}.send'
payload = {'title': title, 'desp': desp, 'tags': '绿联积分日报', 'short': short_desc}
headers = {'Content-Type': 'application/json;charset=utf-8'}

resp = requests.post(url, json=payload, headers=headers)
print(resp.text)
" "$TITLE" "$OUTPUT" "$SENDKEY" >> "$LOG" 2>&1

echo "" >> "$LOG"
WRAPPER
}

# ─── 交互式配置 ──────────────────────────────────────
configure() {
    echo ""
    echo "═══════════════════════════════════════"
    echo "  绿联论坛积分监控 - 配置向导"
    echo "═══════════════════════════════════════"
    echo ""

    read -rp "绿联论坛手机号: " UG_USER
    read -rsp "绿联论坛密码: " UG_PASS
    echo ""
    read -rp "用户 UID (留空自动获取): " UG_UID
    UG_UID=${UG_UID:-164}

    echo ""
    echo "───────────────────────────────────────"
    echo "Server酱3 推送配置"
    echo "  获取地址: https://sct.ft07.com/"
    echo "───────────────────────────────────────"
    read -rp "Server酱3 SendKey: " SC_KEY

    # 写入 .env 文件
    cat > "$INSTALL_DIR/.env" << EOF
UGNAS_USERNAME=$UG_USER
UGNAS_PASSWORD=$UG_PASS
UGNAS_UID=$UG_UID
SC_KEY=$SC_KEY
EOF
    chmod 600 "$INSTALL_DIR/.env"

    # 替换 wrapper 中的占位符
    if [ -f "$INSTALL_DIR/scripts/run_daily.sh" ]; then
        sed -i.bak \
            -e "s|__USERNAME__|$UG_USER|g" \
            -e "s|__PASSWORD__|$UG_PASS|g" \
            -e "s|__UID__|$UG_UID|g" \
            -e "s|__SENDKEY__|$SC_KEY|g" \
            -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" \
            -e "s|__PYTHON__|$PYTHON|g" \
            "$INSTALL_DIR/scripts/run_daily.sh"
        rm -f "$INSTALL_DIR/scripts/run_daily.sh.bak"
        chmod +x "$INSTALL_DIR/scripts/run_daily.sh"
    fi

    info "配置已保存到 $INSTALL_DIR/.env"
}

# ─── 设置定时任务 ────────────────────────────────────
setup_cron() {
    echo ""
    read -rp "是否设置每日定时任务？(Y/n): " DO_CRON
    DO_CRON=${DO_CRON:-Y}

    if [[ "$DO_CRON" =~ ^[Yy]$ ]]; then
        read -rp "执行时间 (cron 表达式，默认每天 9:00): " CRON_EXPR
        CRON_EXPR=${CRON_EXPR:-"0 9 * * *"}

        # 移除旧的
        crontab -l 2>/dev/null | grep -v "$CRON_TAG" | crontab - 2>/dev/null || true

        # 添加新的
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
    fi
}

# ─── 主流程 ──────────────────────────────────────────
main() {
    echo ""
    echo "🍋 绿联论坛积分监控 - 一键安装"
    echo "═══════════════════════════════════════"
    echo ""

    check_python
    install_deps
    download_scripts
    configure
    setup_cron
    test_run

    echo ""
    echo "═══════════════════════════════════════"
    info "安装完成！"
    echo ""
    echo "  安装目录: $INSTALL_DIR"
    echo "  数据目录: $DATA_DIR"
    echo "  手动运行: $INSTALL_DIR/scripts/run_daily.sh"
    echo "  查看日志: cat $DATA_DIR/cron.log"
    echo "═══════════════════════════════════════"
    echo ""
}

main "$@"

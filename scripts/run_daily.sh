#!/bin/bash
# ============================================================
# 绿联积分日报 - 定时执行 wrapper + Server酱3 推送
# 配置从 .env 文件读取
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${INSTALL_DIR}/.env"
VENV_PYTHON="${INSTALL_DIR}/venv/bin/python3"
LOG="${HOME}/.hermes/data/ugnas/cron.log"
mkdir -p "$(dirname "$LOG")"

# ─── 确定 Python ───────────────────────────────────
if [ -x "$VENV_PYTHON" ]; then
    PYTHON="$VENV_PYTHON"
else
    PYTHON="python3"
fi

# ─── 加载 .env ──────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ 未找到配置文件: ${ENV_FILE}" | tee -a "$LOG"
    exit 1
fi

set -a
source "$ENV_FILE"
set +a

# ─── 执行积分脚本 ──────────────────────────────────
OUTPUT=$("$PYTHON" "$SCRIPT_DIR/ugnas_credits.py" 2>&1)
EXIT_CODE=$?

# ─── 写日志 ────────────────────────────────────────
echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG"
echo "$OUTPUT" >> "$LOG"

if [ $EXIT_CODE -eq 0 ]; then
    TITLE="绿联积分日报 $(date '+%m-%d')"
else
    TITLE="绿联积分查询失败 $(date '+%m-%d')"
fi

# ─── Server酱3 推送 ────────────────────────────────
if [ -n "$SC_KEY" ]; then
    "$PYTHON" -c "
import re, requests, sys

title = sys.argv[1]
raw = sys.argv[2]
sendkey = sys.argv[3]

# 从 SendKey 提取 UID: sctp{uid}t...
m = re.match(r'^sctp(\d+)t', sendkey)
if not m:
    print('⚠️ 无法从 SendKey 提取 UID，跳过推送')
    sys.exit(0)

sc_uid = m.group(1)

lines = raw.strip().split('\n')
data_lines = [line.strip() for line in lines[1:] if line.strip()]
desp = '\n\n'.join(data_lines)

short_desc = ''
for line in data_lines:
    if '当前积分' in line:
        short_desc = line.replace('💰 ', '')
        break

url = f'https://{sc_uid}.push.ft07.com/send/{sendkey}.send'
payload = {'title': title, 'desp': desp, 'tags': '绿联积分日报', 'short': short_desc}
headers = {'Content-Type': 'application/json;charset=utf-8'}

try:
    resp = requests.post(url, json=payload, headers=headers, timeout=15)
    print(resp.text)
except Exception as e:
    print(f'⚠️ 推送失败: {e}')
" "$TITLE" "$OUTPUT" "$SC_KEY" >> "$LOG" 2>&1
else
    echo "⚠️ 未配置 Server酱 SendKey（SC_KEY），跳过推送" >> "$LOG"
fi

echo "" >> "$LOG"

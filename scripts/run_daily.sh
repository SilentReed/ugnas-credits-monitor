#!/bin/bash
# ============================================================
# 绿联积分日报 - 定时执行 wrapper + Server酱3 推送
# 所有配置从 config.json 读取
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
LOG="${HOME}/.hermes/data/ugnas/cron.log"
mkdir -p "$(dirname "$LOG")"

# ─── 从 config.json 读取配置 ────────────────────────
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 未找到配置文件: ${CONFIG_FILE}"
    echo "   请复制 config.json.example 为 config.json 并填写配置"
    exit 1
fi

# 用 python 解析 JSON（避免依赖 jq）
eval "$(python3 -c "
import json, sys
with open('${CONFIG_FILE}', 'r', encoding='utf-8') as f:
    cfg = json.load(f)
ugnas = cfg.get('ugnas', {})
sc = cfg.get('serverchan', {})
print(f'export UGNAS_USERNAME=\"{ugnas.get(\"username\", \"\")}\"')
print(f'export UGNAS_PASSWORD=\"{ugnas.get(\"password\", \"\")}\"')
print(f'export UGNAS_UID=\"{ugnas.get(\"uid\", \"\")}\"')
print(f'SENDKEY=\"{sc.get(\"sendkey\", \"\")}\"')
" 2>&1)"

# ─── 执行积分脚本 ──────────────────────────────────
cd "$SCRIPT_DIR/.."
OUTPUT=$(python3 scripts/ugnas_credits.py 2>&1)
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
if [ -n "$SENDKEY" ]; then
    python3 -c "
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
else
    echo "⚠️ 未配置 Server酱 SendKey，跳过推送" >> "$LOG"
fi

echo "" >> "$LOG"

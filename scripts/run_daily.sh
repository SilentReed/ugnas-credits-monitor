#!/bin/bash
# ============================================================
# 绿联积分日报 - 定时执行 wrapper + Server酱3 推送
# 一键安装脚本会自动替换下面的占位符
# ============================================================

# ─── 账号配置（安装时自动填入）──────────────────────
export UGNAS_USERNAME="__USERNAME__"
export UGNAS_PASSWORD="__PASSWORD__"
export UGNAS_UID="__UID__"

# ─── Server酱3 SendKey ──────────────────────────────
SENDKEY="__SENDKEY__"

# ─── 路径 ───────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="${HOME}/.hermes/data/ugnas/cron.log"
mkdir -p "$(dirname "$LOG")"

cd "$SCRIPT_DIR/.."

# ─── 执行积分脚本 ──────────────────────────────────
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
python3 -c "
import json, requests, sys

title = sys.argv[1]
raw = sys.argv[2]
sendkey = sys.argv[3]

lines = raw.strip().split('\n')
# 去掉第一行（标题行含 emoji），保留数据行
data_lines = [line.strip() for line in lines[1:] if line.strip()]
desp = '\n\n'.join(data_lines)

# 从输出中提取简短描述
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

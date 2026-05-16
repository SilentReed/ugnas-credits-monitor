#!/usr/bin/env python3
"""
绿联论坛积分监控脚本 — 独立部署版
每日自动查询积分变动并输出报告

用法：
  python3 ugnas_credits.py

环境变量（或在 config.json 中配置）：
  UGNAS_USERNAME  - 绿联论坛用户名/手机号
  UGNAS_PASSWORD  - 绿联论坛密码
  UGNAS_UID       - 用户 UID（留空自动获取）
"""

import os
import re
import json
import uuid
import base64
import requests
from datetime import datetime
from urllib.parse import quote

# ─── 配置 ───────────────────────────────────────────
# 优先从环境变量读取，其次从 config.json 读取
_config = {}
_config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")
if os.path.exists(_config_path):
    with open(_config_path, "r", encoding="utf-8") as f:
        _config = json.load(f)

USERNAME = os.environ.get("UGNAS_USERNAME", _config.get("username", ""))
PASSWORD = os.environ.get("UGNAS_PASSWORD", _config.get("password", ""))
UID = os.environ.get("UGNAS_UID", _config.get("uid", ""))
BASE_URL = "https://club.ugnas.com"
API_BASE = "https://api-zh.ugnas.com"
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36"

# 数据文件
DATA_DIR = os.path.expanduser("~/.hermes/data/ugnas")
DATA_FILE = os.path.join(DATA_DIR, "credits.json")


def aes_encrypt(text: str, key_str: str, iv_str: str) -> str:
    """AES-128-CBC 加密"""
    from Crypto.Cipher import AES
    from Crypto.Util.Padding import pad

    key = key_str.encode('utf-8')
    iv = iv_str[:16].encode('utf-8')
    cipher = AES.new(key, AES.MODE_CBC, iv)
    padded_data = pad(text.encode('utf-8'), AES.block_size)
    encrypted = cipher.encrypt(padded_data)
    return base64.b64encode(encrypted).decode('utf-8')


def get_encrypt_key(session: requests.Session) -> tuple:
    """获取加密密钥"""
    headers = {
        'User-Agent': UA,
        'Accept': 'application/json, text/plain, */*',
        'Origin': 'https://web.ugnas.com',
        'Referer': 'https://web.ugnas.com/',
    }

    r = session.get(f'{API_BASE}/api/user/v3/sa/encrypt/key', headers=headers, timeout=12)
    data = r.json()
    api_data = data.get('data', {})

    encrypt_key = api_data.get('encryptKey')
    api_uuid = api_data.get('uuid')

    if not encrypt_key or not api_uuid:
        raise Exception("未返回有效密钥")

    return encrypt_key, api_uuid


def get_access_token(session: requests.Session, encrypt_key: str, api_uuid: str) -> str:
    """获取 OAuth Token"""
    form_headers = {
        'User-Agent': UA,
        'Accept': 'application/json;charset=UTF-8',
        'Origin': 'https://web.ugnas.com',
        'Referer': 'https://web.ugnas.com/',
    }

    enc_user = aes_encrypt(USERNAME, encrypt_key, api_uuid)
    enc_pwd = aes_encrypt(PASSWORD, encrypt_key, api_uuid)

    files = {
        'platform': (None, 'PC'),
        'clientType': (None, 'browser'),
        'osVer': (None, '142.0.0.0'),
        'model': (None, 'Edge/142.0.0.0'),
        'bid': (None, uuid.uuid4().hex),
        'alias': (None, 'Edge/142.0.0.0'),
        'grant_type': (None, 'password'),
        'username': (None, enc_user),
        'password': (None, enc_pwd),
        'uuid': (None, api_uuid),
    }

    r = session.post(f'{API_BASE}/api/oauth/token', headers=form_headers, data=files, timeout=12)
    tok = r.json()

    # 支持多种 token 结构
    access_token = tok.get('access_token')
    if not access_token and isinstance(tok.get('data'), dict):
        access_token = tok['data'].get('access_token')
        if not access_token and isinstance(tok['data'].get('accessToken'), dict):
            access_token = tok['data']['accessToken'].get('access_token')

    if not access_token:
        raise Exception(f"未返回有效令牌: {json.dumps(tok, ensure_ascii=False)[:200]}")

    return access_token


def authorize_and_get_cookie(session: requests.Session, access_token: str) -> str:
    """授权并获取 Cookie"""
    headers = {
        'User-Agent': UA,
        'Accept': 'application/json, text/plain, */*',
        'Origin': 'https://web.ugnas.com',
        'Referer': 'https://web.ugnas.com/',
    }

    state = uuid.uuid4().hex[:12]
    authorize_url = (
        f'{API_BASE}/api/oauth/authorize?response_type=code&client_id=discuz-client&scope=user_info'
        f'&state={state}&redirect_uri={quote("https://club.ugnas.com/api/ugreen/callback.php")}&access_token={access_token}'
    )

    r = session.get(authorize_url, headers=headers, allow_redirects=False, timeout=12)
    loc = r.headers.get('location') or r.headers.get('Location')

    if not loc:
        raise Exception("未获取回调地址")

    callback_headers = {
        'User-Agent': UA,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN'
    }

    session.get(loc, headers=callback_headers, timeout=12)
    session.get(f'{BASE_URL}/', headers=callback_headers, timeout=12)

    # 收集 Cookie
    cookie_items = [f"{c.name}={c.value}" for c in session.cookies]

    if not cookie_items:
        raise Exception("未获取到 Cookie")

    ck = '; '.join(cookie_items)
    if '6LQh_2132_BBRules_ok=' not in ck:
        ck += '; 6LQh_2132_BBRules_ok=1'

    if '6LQh_2132_auth=' not in ck:
        raise Exception("未获取到认证 Cookie")

    return ck


def fetch_user_profile(session: requests.Session, cookie: str) -> dict:
    """获取用户资料和积分"""
    headers = {
        'User-Agent': UA,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Cookie': cookie
    }

    # 获取 UID
    uid = UID
    if not uid:
        for url in [f'{BASE_URL}/forum.php?mod=forumdisplay&fid=0', f'{BASE_URL}/home.php']:
            r = session.get(url, headers=headers, timeout=12)
            patterns = [
                r'discuz_uid\s*=\s*\'?(\d+)\'?',
                r'home\.php\?mod=space(?:&|&amp;)uid=(\d+)',
            ]
            for pattern in patterns:
                match = re.search(pattern, r.text)
                if match and match.group(1) != '0':
                    uid = match.group(1)
                    break
            if uid:
                break

    # 获取用户主页
    if uid:
        url = f'{BASE_URL}/home.php?mod=space&uid={uid}'
    else:
        url = f'{BASE_URL}/home.php?mod=space'

    r = session.get(url, headers=headers, timeout=12)
    html = r.text

    # 解析用户信息
    info = {
        'uid': uid,
        'username': USERNAME,
        'points': 0,
        'usergroup': '',
    }

    # 用户名
    t = re.search(r'<li><em>用户名</em>([^<]+)</li>', html)
    if t:
        info['username'] = t.group(1).strip()
    else:
        t2 = re.search(r'class="kmname">([^<]+)</span>', html)
        if t2:
            info['username'] = t2.group(1).strip()

    # 积分
    patterns = [
        r'class="kmjifen kmico09"><span>(\d+)</span>积分',
        r'积分[：:]\s*(\d+)',
        r'class="xg1"[^>]*>积分: (\d+)</a>',
    ]
    for pattern in patterns:
        p = re.search(pattern, html)
        if p:
            info['points'] = int(p.group(1))
            break

    # 用户组
    ug = re.search(r'<li><em>用户组</em>.*?<a[^>]*>([^<]+)</a>', html)
    if ug:
        info['usergroup'] = ug.group(1).strip()

    return info


def load_data() -> dict:
    """加载历史数据"""
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            pass
    return {"records": [], "last_points": 0}


def save_data(data: dict):
    """保存数据"""
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(DATA_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def generate_report(info: dict, change: int, is_first: bool) -> str:
    """生成报告"""
    today = datetime.now().strftime("%Y-%m-%d")

    lines = [
        f"📊 绿联论坛积分日报",
        f"👤 用户：{info['username']} (UID: {info['uid']})",
    ]

    if info['usergroup']:
        lines.append(f"👥 用户组：{info['usergroup']}")

    lines.extend([
        f"📅 日期：{today}",
        f"💰 当前积分：{info['points']}",
    ])

    if is_first:
        lines.append("📌 首次运行，已建立基线")
    else:
        change_str = f"+{change}" if change > 0 else str(change)
        emoji = "📈" if change > 0 else ("➖" if change == 0 else "📉")
        lines.append(f"📈 较上次：{change_str}")

    return "\n".join(lines)


def main():
    """主函数"""
    if not USERNAME or not PASSWORD:
        print("❌ 请设置环境变量 UGNAS_USERNAME 和 UGNAS_PASSWORD，或在 config.json 中配置")
        exit(1)

    try:
        session = requests.Session()

        # 1. 获取加密密钥
        encrypt_key, api_uuid = get_encrypt_key(session)

        # 2. 获取 Token
        access_token = get_access_token(session, encrypt_key, api_uuid)

        # 3. 授权获取 Cookie
        cookie = authorize_and_get_cookie(session, access_token)

        # 4. 获取用户资料
        info = fetch_user_profile(session, cookie)

        # 5. 加载历史数据
        data = load_data()
        last_points = data.get("last_points", 0)

        # 6. 计算变化
        is_first = last_points == 0
        change = info['points'] - last_points if not is_first else 0

        # 7. 保存数据
        today = datetime.now().strftime("%Y-%m-%d")
        data["last_points"] = info['points']
        data["records"].append({
            "date": today,
            "points": info['points'],
            "change": change
        })
        # 只保留最近 30 天
        data["records"] = data["records"][-30:]
        save_data(data)

        # 8. 输出报告
        report = generate_report(info, change, is_first)
        print(report)

    except Exception as e:
        print(f"❌ 绿联论坛积分查询失败: {e}")
        exit(1)


if __name__ == "__main__":
    main()

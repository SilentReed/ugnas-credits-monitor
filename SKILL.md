---
name: ugnas-credits-monitor
description: "绿联论坛积分监控：OAuth API 自动登录，每日定时查询积分变动并推送通知"
tags: [ugnas, credits, monitor, sign-in, 绿联, 积分]
---

# 绿联论坛积分监控

自动登录绿联论坛 (club.ugnas.com)，查询积分变动，推送每日报告。

## 功能

- OAuth API 自动登录（AES 加密 + Token + 回调）
- 积分变动追踪
- 每日汇报推送

## 环境要求

- Python 3.10+
- 依赖：`requests`, `pycryptodome`

```bash
pip install requests pycryptodome
```

## 配置参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| UGNAS_USERNAME | 绿联论坛用户名/手机号 | 必填 |
| UGNAS_PASSWORD | 绿联论坛密码 | 必填 |
| UGNAS_UID | 用户 UID | 164 |

## 使用方式

### 作为 cron 脚本

```bash
python3 ~/scripts/ugnas_credits.py
```

### 输出格式

```
📊 绿联论坛积分日报
👤 用户：默笙 (UID: 164)
📅 日期：2026-05-13
💰 当前积分：1382
📈 较上次：+10
🔥 连续增长：3 天
```

## API 接口

绿联论坛 OAuth 登录流程：

1. `GET /api/user/v3/sa/encrypt/key` — 获取加密密钥
2. AES-128-CBC 加密用户名密码
3. `POST /api/oauth/token` — 获取 access_token
4. `GET /api/oauth/authorize` — 授权回调获取 Cookie
5. `GET /home.php?mod=space` — 获取用户资料和积分

## 注意事项

- OAuth Token 有时效，每次查询需重新获取
- Cookie 中的 `6LQh_2132_auth` 是关键认证字段
- 积分页面在用户主页 HTML 中，需正则提取

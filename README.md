# 🍋 绿联论坛积分监控

每日自动查询绿联论坛 (club.ugnas.com) 积分变动并推送通知。

## ✨ 功能

- 🔐 OAuth API 自动登录（无需手动抓 Cookie）
- 📊 积分变动追踪
- 📱 每日微信推送报告
- 💾 历史记录保存

## 🚀 安装

### 依赖

```bash
pip install requests pycryptodome
```

### 配置

设置环境变量：

```bash
export UGNAS_USERNAME="你的用户名"
export UGNAS_PASSWORD="你的密码"
export UGNAS_UID="你的UID"  # 可选，默认 164
```

或修改脚本中的默认值。

### 运行

```bash
python3 ugnas_credits.py
```

## 📋 输出示例

```
📊 绿联论坛积分日报
👤 用户：默笙 (UID: 164)
📅 日期：2026-05-13
💰 当前积分：1382
📈 较上次：+10
🔥 连续增长：3 天
```

## 🔧 技术原理

绿联论坛 OAuth 登录流程：

1. 获取加密密钥 (`/api/user/v3/sa/encrypt/key`)
2. AES-128-CBC 加密用户名密码
3. 获取 OAuth Token (`/api/oauth/token`)
4. 授权回调获取 Cookie
5. 访问用户主页获取积分

## 📁 文件结构

```
ugnas-credits-monitor/
├── README.md
├── SKILL.md
└── scripts/
    └── ugnas_credits.py
```

## 📄 License

MIT

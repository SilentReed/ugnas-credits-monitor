# 绿联论坛积分日报监控

每日自动查询绿联论坛积分变动，支持青龙面板 / 独立部署两种方式。

## 方式一：青龙面板（推荐）

### 1. 上传脚本

将 `ql/ugnas_credits.py` 上传到青龙面板的 `scripts/` 目录

### 2. 安装依赖

青龙面板 → 订阅管理 → 依赖管理 → 添加：
- `requests`
- `pycryptodome`

### 3. 配置环境变量

青龙面板 → 环境变量 → 添加：

| 变量名 | 值 | 必填 |
|--------|-----|------|
| `UGNAS_USERNAME` | 绿联论坛手机号 | ✅ |
| `UGNAS_PASSWORD` | 绿联论坛密码 | ✅ |
| `UGNAS_UID` | 用户 UID | ❌（留空自动获取） |

### 4. 创建定时任务

青龙面板 → 定时任务 → 新建：

- **命令**：`task ugnas_credits.py`
- **定时**：`0 9 * * *`（每天早上 9 点）

### 5. 配置通知

青龙面板 → 系统设置 → 通知设置，选择你需要的推送方式（TG/Bark/钉钉/微信等）。

脚本只需 `print` 输出，青龙会自动推送通知，**不需要额外配置 Server酱3**。

---

## 方式二：独立部署（无青龙面板）

### 一键安装

```bash
bash scripts/setup.sh
```

跟着提示输入账号信息和 Server酱3 SendKey 即可。

---

## 项目结构

```
ugnas-credits-monitor/
├── README.md
├── .gitignore
├── ql/                          # 青龙面板版
│   └── ugnas_credits.py         # 单文件，丢进青龙就能跑
└── scripts/                     # 独立部署版
    ├── setup.sh                 # 一键安装
    ├── ugnas_credits.py         # 积分查询脚本
    └── config.json      # 配置模板
```

## 输出示例

```
📊 绿联论坛积分日报
👤 用户：张三 (UID: 12345)
👥 用户组：VIP会员
📅 日期：2026-05-15
💰 当前积分：2560
📈 较上次：+15
```

## License

MIT

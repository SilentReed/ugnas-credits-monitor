绿联论坛积分日报监控

每日自动查询绿联论坛积分变动，支持**青龙面板**和**独立部署**两种方式。

## 项目结构

```
ugnas-credits-monitor/
├── README.md
├── setup.sh              # 一键安装（独立部署用）
├── run_daily.sh          # 定时执行 wrapper + Server酱3 推送
├── ugnas_credits.py      # 积分查询脚本（独立部署版）
└── ugnas_credits_ql.py   # 积分查询脚本（青龙面板版）
```

---

## 方式一：青龙面板（推荐）

### 1. 上传脚本

将 `ugnas_credits_ql.py` 上传到青龙面板的 `scripts/` 目录。

### 2. 安装依赖

青龙面板 → 依赖管理 → Python3 → 添加：

```
requests
pycryptodome
```

### 3. 配置环境变量

青龙面板 → 环境变量 → 添加：

| 变量名 | 值 | 必填 |
|---|---|---|
| `UGNAS_USERNAME` | 绿联论坛手机号 | ✅ |
| `UGNAS_PASSWORD` | 绿联论坛密码 | ✅ |
| `UGNAS_UID` | 用户 UID | ❌（留空自动获取） |

### 4. 创建定时任务

青龙面板 → 定时任务 → 新建：

- **命令**：`task ugnas_credits_ql.py`
- **定时**：`0 9 * * *`（每天早上 9 点）

### 5. 配置通知

青龙面板 → 系统设置 → 通知设置，选择你需要的推送方式（TG / Bark / 钉钉 / 微信等）。

脚本只需 `print` 输出，青龙会自动推送通知，不需要额外配置 Server酱。

### 输出示例

```
📊 绿联论坛积分日报
👤 用户：张三 (UID: 12345)
👥 用户组：VIP会员
📅 日期：2026-07-15
💰 当前积分：2560
📈 较上次：+15
```

---

## 方式二：独立部署

适用于没有青龙面板的服务器，通过 `setup.sh` 一键安装，支持 Server酱3 微信推送。

### 1. 上传文件

将以下三个文件上传到服务器同一目录：

```
setup.sh
run_daily.sh
ugnas_credits.py
```

### 2. 一键安装

```bash
bash setup.sh
```

安装向导会依次：

1. 检查 Python 版本（需要 3.7+）
2. 创建虚拟环境，安装 `requests` + `pycryptodome`
3. 释放脚本到 `~/ugnas-credits-monitor/scripts/`
4. 交互式配置账号和 Server酱3 SendKey
5. 设置 crontab 定时任务（默认每天 9:00）
6. 测试运行

### 3. 手动运行

```bash
~/ugnas-credits-monitor/scripts/run_daily.sh
```

### 4. 查看日志

```bash
cat ~/.hermes/data/ugnas/cron.log
```

### 5. Server酱3 推送

安装时会要求输入 Server酱3 SendKey，获取地址：https://sc3.ft07.com/

推送通过 `run_daily.sh` 自动完成，无需额外配置。

### 文件说明

| 文件 | 说明 |
|---|---|
| `setup.sh` | 一键安装脚本（创建 venv、装依赖、写配置、设 cron） |
| `run_daily.sh` | 定时执行 wrapper（加载 `.env`、调用 Python 脚本、Server酱推送） |
| `ugnas_credits.py` | 核心积分查询脚本 |
| `~/ugnas-credits-monitor/.env` | 配置文件（安装时自动生成，权限 600） |
| `~/.hermes/data/ugnas/cron.log` | 运行日志 |
| `~/.hermes/data/ugnas/credits.json` | 积分历史数据（保留最近 30 天） |

### 卸载

```bash
# 删除定时任务
crontab -l | grep -v "ugnas-credits-monitor" | crontab -

# 删除安装目录
rm -rf ~/ugnas-credits-monitor

# 删除数据
rm -rf ~/.hermes/data/ugnas
```

---

## 常见问题

### Q: 积分查询失败 401

检查账号密码是否正确，UID 是否填写（留空会自动获取，但可能失败）。

### Q: Server酱推送失败

确认 SendKey 格式正确（`sctp{uid}t...`），到 https://sc3.ft07.com/ 检查状态。

### Q: `No module named 'Crypto'`

独立部署方式请确保通过 `setup.sh` 安装，不要直接用系统 Python 运行。青龙面板请在依赖管理中添加 `pycryptodome`。

### Q: 论坛改版后脚本失效

脚本依赖 HTML 正则解析积分，绿联论坛改版可能导致匹配失败。关注 [GitHub 仓库](https://github.com/SilentReed/ugnas-credits-monitor) 获取更新。

---

## License

MIT

# agy-codex

一键将 **Google Antigravity (`agy`)** 的账号与模型额度（`Gemini 4 Argon`、`Gemini 3.8 Flash`、`Claude Sonnet 4.6`、`Claude Opus 4.6` 等）通过本地反代接入 **OpenAI Codex CLI / Codex Desktop**，并支持一键注入 **[CC Switch](https://github.com/farion1231/cc-switch)**。

---

## 为什么需要 `agy-codex`？

1. **认证与协议差异**：`agy`（Antigravity CLI）使用 Google 内部 OAuth 会话与专有接口，不提供直接填入 `~/.codex/config.toml` 的 OpenAI API Key。
2. **Codex 要求 `/v1/responses`**：新版 OpenAI Codex CLI 强制要求 `wire_api = "responses"`。
3. **无侵入共存**：`agy-codex` 基于 [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 在本地 `127.0.0.1:8317/v1` 暴露原生兼容 OpenAI Responses API 的服务端点：
   - **直接运行 `agy-codex`**：通过 `codex -c ...` 临时注入当前会话配置，**不改动**你日常由 `cc-switch` 维护的 `~/.codex/config.toml`。
   - **配合 `cc-switch` 使用**：一键向 `~/.cc-switch/cc-switch.db` 注册 `Antigravity (AGY)` 供应商，在系统托盘随时切换。

```
Antigravity OAuth ──► CLIProxyAPI (127.0.0.1:8317/v1) ──┬──► agy-codex (直连 Codex CLI, 免改配置)
                                                       └──► CC Switch (127.0.0.1:15721/v1) ──► Codex CLI / Desktop
```

---

## 快速开始

### 1. 安装

```bash
git clone https://github.com/Dremig/agy-codex.git
cd agy-codex
./install.sh
```

`./install.sh` 会自动完成：
1. 下载对应平台（macOS / Linux，`arm64` / `amd64`）的最新 `CLIProxyAPI` 到 `~/.cli-proxy-api/`
2. 生成默认配置 `~/.cli-proxy-api/config.yaml`（监听 `127.0.0.1:8317`，本地 Key 为 `sk-agy-local`）
3. 将 `agy-codex` 软链接至 `~/.local/bin/agy-codex`
4. 若本机安装了 **CC Switch**，自动将 `Antigravity (AGY)` 供应商及模型目录写入 `~/.cc-switch/cc-switch.db`

> 如果希望开机自动在后台常驻转发服务（macOS LaunchAgent）：
> ```bash
> ./install.sh --launchd
> ```

### 2. 一键启动 Codex

```bash
# 首次运行会自动拉起浏览器完成 Antigravity OAuth 登录，随后后台启动转发并进入 Codex
agy-codex

# 指定 Antigravity 下的其他模型启动 Codex
agy-codex -m claude-sonnet-4-6
agy-codex -m claude-opus-4-6-thinking
agy-codex -m gemini-3.8-flash-high

# 透传任意 Codex 原生参数（如免确认 --yolo）
agy-codex --yolo
```

---

## 命令参考

| 命令 | 说明 |
| :--- | :--- |
| `agy-codex [codex args...]` | 确保后台转发就绪，并使用 Antigravity 后端启动 `codex` |
| `agy-codex start` / `agy-codex proxy` | 仅在后台启动 `http://127.0.0.1:8317/v1` 转发服务（供 CC Switch / Codex Desktop 使用） |
| `agy-codex stop` | 停止后台转发服务 |
| `agy-codex restart` | 重启后台转发服务 |
| `agy-codex status` | 查看 OAuth 授权状态、转发进程状态与当前可用模型列表 |
| `agy-codex login` | 登录或追加多个 Google Antigravity 账号（支持多账号自动轮询） |
| `agy-codex models` | 查询 `http://127.0.0.1:8317/v1/models` 暴露的所有模型 ID |
| `agy-codex cc-switch` | 手动将 `Antigravity (AGY)` 供应商配置写入/更新到 `~/.cc-switch/cc-switch.db` |
| `agy-codex logs` | 实时查看 `~/.cli-proxy-api/proxy.log` 转发日志 |

---

## 配合 CC Switch 使用

1. 运行 `./install.sh`（或 `agy-codex cc-switch`）注入供应商配置。
2. 运行 `agy-codex start`（或 `./install.sh --launchd`）保持本地 `127.0.0.1:8317` 转发在线。
3. 打开 **CC Switch -> Codex**，切换到 **`Antigravity (AGY)`** 即可全局生效。

预置的模型目录包括：
- `gemini-4-argon-high` / `gemini-4-argon-medium` / `gemini-4-argon-low`
- `gemini-3.8-flash-high` / `gemini-3.8-flash-medium` / `gemini-3.8-flash-low`
- `claude-sonnet-4-6`
- `claude-opus-4-6-thinking`
- `gpt-oss-120b-medium`

---

## 环境变量

| 变量名 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `AGY_MODEL` | `gemini-4-argon-high` | `agy-codex` 未传 `-m` 时的默认模型 |
| `AGY_PROXY_HOST` | `127.0.0.1` | 本地转发监听地址 |
| `AGY_PROXY_PORT` | `8317` | 本地转发监听端口 |
| `AGY_PROXY_API_KEY` | `sk-agy-local` | 本地转发鉴权 Key |
| `AGY_CPA_DIR` | `~/.cli-proxy-api` | `CLIProxyAPI` 二进制、配置与 OAuth 凭证目录 |

---

## 目录结构

```
agy-codex/
  bin/
    agy-codex                     # 一键启动转发与 Codex 的主命令
  config/
    config.example.yaml           # CLIProxyAPI v8 默认配置模板
    codex-config.example.toml     # ~/.codex/config.toml 独立配置参考
  scripts/
    register-cc-switch.py         # 向 ~/.cc-switch/cc-switch.db 注入供应商的脚本
  install.sh                      # 自动安装 / LaunchAgent 注册 / 卸载脚本
  LICENSE
  README.md
```

## 卸载

```bash
./install.sh --uninstall
```

## License

MIT
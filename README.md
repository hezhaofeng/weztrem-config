# WezTerm 个人配置

这是一个模块化的 WezTerm 配置，主要面向 Windows 使用，同时保留 macOS/Linux 的基础启动项。入口文件是 `wezterm.lua`，具体配置拆分在 `config/`、事件逻辑拆分在 `events/`，PowerShell 辅助脚本放在 `scripts/`。

## 当前特性

- 默认 Shell：Windows 下使用 PowerShell 7，并加载 `scripts/pwsh-wezterm.ps1`。
- 渲染后端：`WebGpu`，优先使用高性能 GPU，`max_fps = 60`，`animation_fps = 60`。
- 主题配色：`Gruvbox dark, medium (base16)`。
- 背景：使用纯色 `#161A22`，关闭透明和 Windows 背景特效以降低全屏/还原时的合成压力。
- 标签栏：自定义胶囊标签、进程图标、管理员标识、未读输出提示。
- 状态栏：右侧显示日期时间和电池状态。
- 快捷键：禁用默认键盘/鼠标绑定，仅保留本仓库自定义绑定。
- 启动器：集成 PowerShell、cmd、Nushell、Yazi、Codex、Claude、pnpm 更新和 Git Bash。

## 目录结构

```text
.
├── wezterm.lua              # 入口文件
├── config/
│   ├── appearance.lua       # 外观、背景、标签栏、窗口配置
│   ├── bindings.lua         # 键盘和鼠标绑定
│   ├── fonts.lua            # 字体配置
│   ├── general.lua          # 通用行为、链接规则、状态刷新间隔
│   ├── init.lua             # 配置合并辅助
│   └── launch.lua           # 默认 Shell 和启动菜单
├── events/
│   ├── new-tab-button.lua   # 新建标签按钮行为
│   ├── right-status.lua     # 右侧状态栏
│   └── tab-title.lua        # 自定义标签标题
├── scripts/
│   ├── check-env.ps1        # 迁移/环境检测脚本
│   ├── cli-tools.ps1        # Codex、Claude、pnpm 辅助别名
│   └── pwsh-wezterm.ps1     # WezTerm 专用 PowerShell 启动脚本
├── backdrops/               # 背景图片
├── img/                     # 文档图片
└── screenshots/             # 截图
```

## 依赖

### 必需项

- WezTerm
- PowerShell 7：`pwsh`
- Nerd Font：
  - `JetBrainsMono NF`
  - `MesloLGM Nerd Font`
- 系统字体：
  - `Microsoft YaHei`
  - `Segoe UI Emoji`

### 推荐项

- Yazi：`yazi`
- Yazi 插件管理器：`ya`
- Yazi 配套工具：`rg`、`fd`、`fzf`、`zoxide`、`jq`、`ffmpeg`、`7z`、`magick`、`pdftoppm`
- 文本预览增强：`bat`
- 文件类型识别：`file`

### 启动菜单相关可选项

- Nushell：`nu`
- Codex CLI：`codex`
- Claude CLI：`claude`
- pnpm：`pnpm`
- Git Bash：当前配置固定路径为 `D:\software\Git\bin\bash.exe`

如果迁移到新机器，Git Bash 路径要么保持一致，要么修改 `config/launch.lua` 里的 `git_bash`。

## 安装与迁移

将本仓库放到 WezTerm 默认配置目录：

```powershell
C:\Users\<你的用户名>\.config\wezterm
```

启动前建议先运行环境检测：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-env.ps1
```

导出 JSON 报告：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-env.ps1 -Json
```

这个脚本只做检测，不会安装软件，也不会修改系统。它会检查 WezTerm 配置加载、启动项、Yazi 配套工具、AI CLI、字体和背景图片是否就绪。

## 启动项

Windows 下默认启动：

```text
pwsh -NoLogo -NoProfile -NoExit -File scripts\pwsh-wezterm.ps1
```

启动菜单包含：

| 启动项 | 说明 |
| --- | --- |
| 打开 Windows PowerShell | 加载 WezTerm 专用 PowerShell 环境 |
| 打开 PowerShell 7 | 默认推荐 Shell |
| 打开命令提示符 | 使用 UTF-8 代码页启动 cmd |
| 打开 Nushell | 可选 Shell，未安装时显示提示 |
| 打开 Yazi 文件管理器 | 启动 `yazi` |
| cxy：以 YOLO 模式启动 Codex | 调用 `codex --yolo` |
| ccd：启动 Claude 并跳过权限确认 | 调用 `claude --dangerously-skip-permissions` |
| cxu：更新 Codex 版本 | 调用 `pnpm add -g @openai/codex@latest` |
| ccu：更新 Claude 版本 | 调用 `claude update` |
| pnu：更新 pnpm 版本 | 调用 `pnpm self-update` |
| 打开 Git Bash | 使用 `D:\software\Git\bin\bash.exe` |

## PowerShell 辅助命令

`scripts/pwsh-wezterm.ps1` 会设置 UTF-8 环境，并加载 `scripts/cli-tools.ps1`。可用命令包括：

| 命令 | 作用 |
| --- | --- |
| `gitbash` | 从当前 PowerShell 启动 Git Bash |
| `cxy` | 以 YOLO 模式启动 Codex |
| `ccd` | 启动 Claude 并跳过权限确认 |
| `cxu` | 更新 Codex CLI |
| `ccu` | 更新 Claude CLI |

## 常用命令

使用当前配置启动 WezTerm：

```powershell
wezterm start --config-file .\wezterm.lua
```

检查配置能否加载：

```powershell
wezterm --config-file .\wezterm.lua show-keys
```

格式化 Lua 文件：

```powershell
stylua .
```

静态检查 Lua 文件：

```powershell
selene .
```

当前机器没有安装 `stylua` 时，格式化命令会失败，需要先安装对应工具。

## 快捷键

完整快捷键见 [快捷键.md](./快捷键.md)。

最常用的 Windows/Linux 快捷键：

| 快捷键 | 作用 |
| --- | --- |
| `F2` | 打开命令面板 |
| `F3` | 打开启动器 |
| `Alt+t` | 新建标签页 |
| `Alt+[` / `Alt+]` | 切换上一个/下一个标签页 |
| `Alt+Ctrl+/` | 垂直分屏 |
| `Alt+Ctrl+\` | 水平分屏 |
| `Alt+Ctrl+h/j/k/l` | 切换窗格 |
| `Alt+y` | 输入并执行 `yazi` |
| `Ctrl+Shift+R` | 重命名当前标签页 |
| `Ctrl+Shift+Space` 后按 `p` | 进入窗格调整模式 |
| `Ctrl+Shift+Space` 后按 `f` | 进入字体调整模式 |

## 右键菜单参考

如果需要在资源管理器右键菜单中添加 “Open WezTerm Here”，可以在注册表中为目录背景添加命令。命令示例：

```text
"D:\software\WezTerm\wezterm.exe" start --no-auto-connect --cwd "%V\"
```

不同机器上的 WezTerm 安装路径可能不同，请按实际路径调整。

# 仓库指南

## 项目结构与模块组织

本仓库是一个模块化的 WezTerm 配置。`wezterm.lua` 是入口文件，应保持简洁；它从 `events/` 加载事件初始化逻辑，并从 `config/` 组合配置选项。

- `config/`：配置模块，例如 `appearance.lua`、`bindings.lua`、`fonts.lua`、`general.lua` 和 `launch.lua`。
- `events/`：WezTerm 事件处理器，用于状态栏、标签标题和新建标签按钮行为。
- `utils/`：共享辅助函数，目前包含平台判断和数学工具。
- `colors/`：自定义配色方案。
- `backdrops/`、`img/`、`screenshots/`：图片资源和文档截图。

## 构建、测试与开发命令

本项目没有构建步骤。WezTerm 会直接加载 Lua 文件。

- `wezterm start --config-file wezterm.lua`：使用本配置启动 WezTerm。
- `stylua .`：按照 `.stylua.toml` 格式化所有 Lua 文件。
- `selene .`：使用 `selene.toml` 检查 Lua 代码。

请在仓库根目录运行命令：`C:\Users\zhaozhao\.config\wezterm`。

## 代码风格与命名规范

Lua 代码使用 2 空格缩进、LF 换行、UTF-8 编码，并保留文件末尾换行。遵循 `.editorconfig` 和 `.stylua.toml`：120 列宽、空格缩进、可行时优先使用双引号，并显式书写函数调用括号。

模块应保持职责单一，并返回符合现有模式的表或 `setup` 函数，例如 `require("events.tab-title").setup()` 或 `require("config.fonts")`。文件名使用小写且具备描述性；现有模块示例包括 `right-status.lua` 和 `new-tab-button.lua`。

## 测试指南

当前没有自动化测试套件。修改后应执行格式化、静态检查，并使用编辑后的配置启动 WezTerm 进行验证。涉及界面行为时，请手动检查相关功能：标签标题、状态栏内容、快捷键、字体、启动域或背景图渲染。只有在记录可见变化时，才更新 `screenshots/` 中的截图。

## 提交与拉取请求指南

当前环境中无法使用 Git，因此未能检查本仓库的历史提交风格。建议使用简短的祈使句提交信息，例如 `Update tab title formatting` 或 `Add Windows launch domain`。

拉取请求应包含简要说明、受影响模块、手动验证步骤，以及视觉变更对应的截图。如有相关 issue，请添加链接；同时说明任何本地路径假设，例如 Windows 专用的 WezTerm 安装路径或必需的 Nerd Font 版本。

## 安全与配置建议

避免在启动域中提交机器专用的密钥或私有主机名。本地专用路径应记录在 `README.md` 或注释中；当不同行为依赖操作系统时，优先通过 `utils/platform.lua` 做可移植判断。

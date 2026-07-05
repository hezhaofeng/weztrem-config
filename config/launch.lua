local wezterm = require("wezterm")
local platform = require("utils.platform")()
local yazi = "yazi"
local powershell7 = "pwsh"
local git_bash = "D:\\software\\Git\\bin\\bash.exe"
local path_separator = platform.is_win and "\\" or "/"
local scripts_dir = wezterm.config_dir .. path_separator .. "scripts"
local pwsh_wezterm_profile = scripts_dir .. path_separator .. "pwsh-wezterm.ps1"

local function powershell_args(exe)
  return { exe, "-NoLogo", "-NoProfile", "-NoExit", "-File", pwsh_wezterm_profile }
end

local function powershell_quote(value)
  return "'" .. value:gsub("'", "''") .. "'"
end

local function powershell_command_args(command)
  local bootstrap_command = ". " .. powershell_quote(pwsh_wezterm_profile) .. "; " .. command
  return { powershell7, "-NoLogo", "-NoProfile", "-NoExit", "-Command", bootstrap_command }
end

local pnpm_self_update_command =
  "Invoke-RequiredExternalCommand -CommandName 'pnpm' -DisplayName 'pnpm' -CommandArgs @('self-update')"

local options = {
  default_prog = {},
  launch_menu = {},
}

if platform.is_win then
  options.default_prog = powershell_args(powershell7)
  options.set_environment_variables = {
    LANG = "zh_CN.UTF-8",
    LC_ALL = "zh_CN.UTF-8",
    PYTHONUTF8 = "1",
    PYTHONIOENCODING = "utf-8",
  }
  options.launch_menu = {
    { label = " 打开 Windows PowerShell", args = powershell_args("powershell") },
    { label = " 打开 PowerShell 7", args = powershell_args(powershell7) },
    { label = " 打开命令提示符", args = { "cmd", "/k", "chcp 65001 > nul" } },
    {
      label = " 打开 Nushell",
      args = powershell_command_args("Start-OptionalCommand -CommandName 'nu' -DisplayName 'Nushell'"),
    },
    {
      label = " 打开 Yazi 文件管理器",
      args = powershell_command_args("Start-OptionalCommand -CommandName 'yazi' -DisplayName 'Yazi'"),
    },
    { label = "󰚰 cxy：以 YOLO 模式启动 Codex", args = powershell_command_args("cxy") },
    { label = " gwn：创建 Git worktree 并进入目录", args = powershell_command_args("gwn") },
    { label = "󰚰 ccd：启动 Claude 并跳过权限确认", args = powershell_command_args("ccd") },
    { label = "󰚰 cxu：更新 Codex 版本", args = powershell_command_args("cxu") },
    { label = "󰚰 ccu：更新 Claude 版本", args = powershell_command_args("ccu") },
    {
      label = "󰏗 pnu：更新 pnpm 版本",
      args = powershell_command_args(pnpm_self_update_command),
    },
    {
      label = " 打开 Git Bash",
      args = { git_bash, "--login", "-i" },
    },
  }
elseif platform.is_mac then
  options.default_prog = { "zsh", "--login" }
  options.launch_menu = {
    { label = " 打开 Bash", args = { "bash", "--login" } },
    { label = " 打开 Fish", args = { "fish", "--login" } },
    { label = " 打开 Nushell", args = { "nu" } },
    { label = " 打开 Zsh", args = { "zsh", "--login" } },
    { label = " 打开 Yazi 文件管理器", args = { yazi } },
  }
elseif platform.is_linux then
  options.default_prog = { "bash", "--login" }
  options.launch_menu = {
    { label = " 打开 Bash", args = { "bash", "--login" } },
    { label = " 打开 Fish", args = { "fish", "--login" } },
    { label = " 打开 Nushell", args = { "nu" } },
    { label = " 打开 Zsh", args = { "zsh", "--login" } },
    { label = " 打开 Yazi 文件管理器", args = { yazi } },
  }
end

return options

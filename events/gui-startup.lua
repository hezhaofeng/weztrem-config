local wezterm = require("wezterm")

local M = {}

M.setup = function()
  -- 启动时把首个窗口最大化。
  -- 原因：WezTerm 在跨不同 DPI 的显示器切换时会保持行列数并重算窗口像素尺寸，
  -- 从 150% 屏切到 100% 屏会把窗口缩到三分之二，反复切换后越缩越小
  -- （上游问题 wezterm/wezterm#4915、#5022、#7281，主线尚未修复）。
  -- 最大化状态下 WezTerm 不会主动改窗口尺寸，由 Windows 贴合到新屏幕，
  -- 文字仍按各屏的正确 DPI 渲染。
  -- 注意：该事件只在进程启动时触发，Alt+n 等后续新开的窗口不受影响。
  wezterm.on("gui-startup", function(cmd)
    -- 透传 cmd 以保留 `wezterm start --cwd ...` 等启动参数。
    local _, _, window = wezterm.mux.spawn_window(cmd or {})
    window:gui_window():maximize()
  end)
end

return M

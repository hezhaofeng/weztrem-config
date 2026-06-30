local wezterm = require("wezterm")

local font = wezterm.font_with_fallback({
  "JetBrainsMono NF",
  "MesloLGM Nerd Font",
  "Microsoft YaHei",
  "Segoe UI Emoji",
})
local font_size = 13

return {
  font = font,
  font_size = font_size,

  -- ref: https://wezfurlong.org/wezterm/config/lua/config/freetype_pcf_long_family_names.html
  freetype_load_target = "Normal", ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
  freetype_render_target = "Normal", ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
}

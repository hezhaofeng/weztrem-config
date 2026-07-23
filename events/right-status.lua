local wezterm = require("wezterm")
local math = require("utils.math")
local M = {}

M.separator_char = " ~ "
M.discharging_icons = { "󰂃", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹" }
M.charging_icons = { "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅" }

M.colors = {
  date_fg = "#7DCFFF",
  date_bg = "#293241",
  battery_fg = "#9ECE6A",
  battery_bg = "#293241",
  separator_fg = "#3D4658",
  separator_bg = "#293241",
}

M.cells = {} -- wezterm FormatItems (ref: https://wezfurlong.org/wezterm/config/lua/wezterm/format.html)

---@param text string
---@param icon string
---@param fg string
---@param bg string
---@param separate boolean
M.push = function(text, icon, fg, bg, separate)
  table.insert(M.cells, { Foreground = { Color = fg } })
  table.insert(M.cells, { Background = { Color = bg } })
  table.insert(M.cells, { Attribute = { Intensity = "Bold" } })
  table.insert(M.cells, { Text = icon .. " " .. text .. " " })

  if separate then
    table.insert(M.cells, { Foreground = { Color = M.colors.separator_fg } })
    table.insert(M.cells, { Background = { Color = M.colors.separator_bg } })
    table.insert(M.cells, { Text = M.separator_char })
  end

  table.insert(M.cells, "ResetAttributes")
end

M.set_date = function(separate)
  local date = wezterm.strftime(" %a %H:%M")
  M.push(date, "", M.colors.date_fg, M.colors.date_bg, separate)
end

M.get_battery_status = function(battery_info)
  -- ref: https://wezfurlong.org/wezterm/config/lua/wezterm/battery_info.html
  battery_info = battery_info or wezterm.battery_info() or {}
  if #battery_info == 0 then
    return nil
  end

  local status

  for _, b in ipairs(battery_info) do
    local state_of_charge = b.state_of_charge
    if type(state_of_charge) == "number" then
      local idx = math.clamp(math.round(state_of_charge * 10), 1, 10)
      status = {
        charge = string.format("%.0f%%", state_of_charge * 100),
        icon = b.state == "Charging" and M.charging_icons[idx] or M.discharging_icons[idx],
      }
    end
  end

  return status
end

M.setup = function()
  wezterm.on("update-right-status", function(window, _pane)
    M.cells = {}
    local battery_status = M.get_battery_status()
    M.set_date(battery_status ~= nil)
    if battery_status then
      M.push(battery_status.charge, battery_status.icon, M.colors.battery_fg, M.colors.battery_bg, false)
    end

    window:set_right_status(wezterm.format(M.cells))
  end)
end

return M

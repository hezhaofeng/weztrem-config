local wezterm = require("wezterm")

local GLYPH_SEMI_CIRCLE_LEFT = ""
local GLYPH_SEMI_CIRCLE_RIGHT = ""
local GLYPH_CIRCLE = "󰇷 "
local GLYPH_ADMIN = "󰖳 "
local ATTR_BOLD = { Intensity = "Bold" }

local M = {}

M.cells = {}

M.colors = {
  edge = "#1B2029",
  default = {
    bg = "#303846",
    fg = "#C0CAF5",
  },
  is_active = {
    bg = "#7AA2F7",
    fg = "#111827",
  },

  hover = {
    bg = "#424C5F",
    fg = "#E5E7EB",
  },
}

M.set_process_name = function(s)
  s = s or ""
  local a = string.gsub(s, "(.*[/\\])(.*)", "%2")
  return a:gsub("%.exe$", "")
end

M.process_icons = {
  bash = "",
  cmd = "",
  fish = "󰈺",
  git = "󰊢",
  node = "󰎙",
  nvim = "",
  nu = "",
  powershell = "",
  pwsh = "",
  python = "󰌠",
  ssh = "󰣀",
  vim = "",
  yazi = "󰉋",
  zsh = "",
}

M.get_process_icon = function(process_name)
  return M.process_icons[process_name:lower()] or ""
end

M.set_title = function(process_name, static_title, active_title, max_width, inset)
  local title
  process_name = process_name or ""
  static_title = static_title or ""
  active_title = active_title or ""
  max_width = math.max(max_width or 1, 1)
  inset = inset or 6

  if process_name:len() > 0 and static_title:len() == 0 then
    title = M.get_process_icon(process_name) .. "  " .. process_name .. " ~ " .. " "
  elseif static_title:len() > 0 then
    title = "󰌪  " .. static_title .. " ~ " .. " "
  else
    title = "󰌽  " .. active_title .. " ~ " .. " "
  end

  local available_width = math.max(max_width - inset, 1)
  title = wezterm.truncate_right(title, available_width)

  return title
end

M.check_if_admin = function(p)
  p = p or ""
  if p:match("^Administrator: ") then
    return true
  end
  return false
end

---@param fg string
---@param bg string
---@param attribute table
---@param text string
M.push = function(bg, fg, attribute, text)
  table.insert(M.cells, { Background = { Color = bg } })
  table.insert(M.cells, { Foreground = { Color = fg } })
  table.insert(M.cells, { Attribute = attribute })
  table.insert(M.cells, { Text = text })
end

M.setup = function()
  wezterm.on("format-tab-title", function(tab, _, _, _, hover, max_width)
    M.cells = {}

    local bg
    local fg
    local process_name = M.set_process_name(tab.active_pane.foreground_process_name)
    local is_admin = M.check_if_admin(tab.active_pane.title)
    local title = M.set_title(process_name, tab.tab_title, tab.active_pane.title, max_width, (is_admin and 8))

    if tab.is_active then
      bg = M.colors.is_active.bg
      fg = M.colors.is_active.fg
    elseif hover then
      bg = M.colors.hover.bg
      fg = M.colors.hover.fg
    else
      bg = M.colors.default.bg
      fg = M.colors.default.fg
    end

    local has_unseen_output = false
    for _, pane in ipairs(tab.panes) do
      if pane.has_unseen_output then
        has_unseen_output = true
        break
      end
    end

    -- Left semi-circle
    M.push(M.colors.edge, bg, ATTR_BOLD, GLYPH_SEMI_CIRCLE_LEFT)

    -- Admin Icon
    if is_admin then
      M.push(bg, fg, ATTR_BOLD, " " .. GLYPH_ADMIN)
    end

    -- Title
    M.push(bg, fg, ATTR_BOLD, " " .. title)

    -- Unseen output alert
    if has_unseen_output then
      M.push(bg, "#F7768E", ATTR_BOLD, " " .. GLYPH_CIRCLE)
    end

    -- Right padding
    M.push(bg, fg, ATTR_BOLD, " ")

    -- Right semi-circle
    M.push(M.colors.edge, bg, ATTR_BOLD, GLYPH_SEMI_CIRCLE_RIGHT)

    return M.cells
  end)
end

return M

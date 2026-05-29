-- ~ / .config / hypr / configs / modules / visuals / colors.lua

local M = {}

local path = os.getenv("HOME") .. "/.cache/wal/colors-hyprland.conf"
local fallback = {
  foreground = "rgba(195,195,198,1.0)",
  background = "rgba(18,17,27,1.0)",
  color0 = "rgba(18,17,27,1.0)",
  color1 = "rgba(136,121,141,1.0)",
  color2 = "rgba(120,134,164,1.0)",
  color3 = "rgba(141,151,182,1.0)",
  color4 = "rgba(162,154,175,1.0)",
  color5 = "rgba(208,168,158,1.0)",
  color6 = "rgba(157,159,192,1.0)",
  color7 = "rgba(195,195,198,1.0)",
}

for key, value in pairs(fallback) do
  M[key] = value
end

local file = io.open(path, "r")
if file then
  for line in file:lines() do
    local key, value = line:match("^%s*%$([%w_]+)%s*=%s*(.-)%s*$")
    if key and value then
      M[key] = value
    end
  end
  file:close()
end

return M

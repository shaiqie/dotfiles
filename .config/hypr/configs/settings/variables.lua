-- ~ / .config / hypr / configs / settings / variables.lua

local M = {}

M.configHome = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
M.hyprDir = M.configHome .. "/hypr"
M.shellsDir = M.configHome .. "/shells"
M.shellCli = (os.getenv("HOME") or "") .. "/.local/bin/shell"

M.terminal = "kitty"
M.file = "thunar"
M.launcher = "rofi"
M.browser = "firefox"
M.mainMod = "SUPER"

function M.shellsIpc(target, method)
  return "quickshell ipc --path " .. M.shellsDir .. " call " .. target .. " " .. method
end

return M

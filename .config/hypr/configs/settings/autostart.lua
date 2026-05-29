-- ~ / .config / hypr / configs / settings / autostart.lua

local vars = require("configs.settings.variables")

hl.on("hyprland.start", function()
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("quickshell --path " .. vars.shellsDir .. " --no-duplicate")
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("wal -R")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("hyprctl setcursor Win10 24")
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
end)

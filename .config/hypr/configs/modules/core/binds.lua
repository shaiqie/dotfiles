-- ~ / .config / hypr / configs / modules / core / binds.lua

local vars = require("configs.settings.variables")
local mainMod = vars.mainMod
local terminal = vars.terminal
local file = vars.file
local browser = vars.browser
local shellsIpc = vars.shellsIpc

-- Apps
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(file))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + c", hl.dsp.exec_cmd("vesktop"))

-- Quickshell
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(shellsIpc("launcher", "toggle")))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(shellsIpc("clipboard", "toggle")))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(shellsIpc("wallpaper", "toggle")))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd(shellsIpc("emojiPicker", "toggle")))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(shellsIpc("settings", "toggle")))
hl.bind("ALT + Z", hl.dsp.exec_cmd(shellsIpc("recorder", "toggle")))

-- System / Session
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(shellsIpc("powerMenu", "toggle")))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(shellsIpc("lockScreen", "lock")))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(vars.shellCli .. " reload"))

-- Window Actions
hl.bind(mainMod .. " + Backspace", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + W", hl.dsp.window.resize({ x = 1000, y = 600, relative = false }))
hl.bind(mainMod .. " + W", hl.dsp.window.center())

-- Window Focus
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Workspaces
hl.bind(mainMod .. " + A", hl.dsp.focus({ workspace = "-1" }))
hl.bind(mainMod .. " + D", hl.dsp.focus({ workspace = "+1" }))
for i = 1, 6 do
  hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
end
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move Windows To Workspaces
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.window.move({ workspace = "-1" }))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.window.move({ workspace = "+1" }))
for i = 1, 10 do
  local key = i % 10
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Screenshots
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots -f Screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprshot -m output -o ~/Pictures/Screenshots -f Screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"))

-- Mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Hardware Keys
hl.bind("Caps_Lock", hl.dsp.exec_cmd(shellsIpc("osd", "capsLock")), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(shellsIpc("osd", "volumeUp")), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(shellsIpc("osd", "volumeDown")), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(shellsIpc("osd", "volumeMute")), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(shellsIpc("osd", "micMute")), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(shellsIpc("osd", "brightnessUp")), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(shellsIpc("osd", "brightnessDown")), { locked = true, repeating = true })

-- Media Keys
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

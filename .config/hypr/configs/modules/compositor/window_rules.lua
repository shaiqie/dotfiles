-- ~ / .config / hypr / configs / modules / compositor / window_rules.lua

hl.window_rule({
  name = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

hl.window_rule({
  name = "fix-xwayland-drags",
  match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
  no_focus = true,
})

hl.window_rule({ name = "thunar_progress_floating", match = { class = "^(thunar)$", title = "^(File Operation Progress)$" }, float = true, center = true })
hl.window_rule({ name = "thunar_dialogs_floating", match = { class = "^(thunar)$", title = "^(Confirm to replace files|Attention)$" }, float = true, center = true })

hl.window_rule({
  name = "move-hyprland-run",
  match = { class = "hyprland-run" },
  move = "20 monitor_h-120",
  float = true,
})

hl.window_rule({ name = "network-manager-float", match = { class = "nm-connection-editor" }, float = true, center = true, size = { 600, 500 } })
hl.window_rule({ name = "audio-control-float", match = { class = "org.pulseaudio.pavucontrol" }, float = true, center = true, size = { 700, 450 } })
hl.window_rule({ name = "mpv_floating_centered", match = { class = "mpv" }, float = true, center = true, size = { 1280, 720 } })
hl.window_rule({ name = "imv_floating_centered", match = { class = "imv" }, float = true, center = true, size = { 1280, 720 } })
hl.window_rule({ name = "mediaplayer_floating_centered", match = { class = ".*mediaplayer.*" }, float = true, center = true })

hl.window_rule({ name = "media-opaque", match = { class = "mpv|vlc|clapper|plex" }, opacity = "1.0 1.0" })
hl.window_rule({ name = "games-opaque", match = { class = "steam_app_.*|lutris|heroic|Minecraft.*" }, opacity = "1.0 1.0" })
hl.window_rule({ name = "nwg-look-center", match = { class = "nwg-look" }, float = true, center = true })
hl.window_rule({ name = "nwg-displays-center", match = { class = "nwg-displays" }, float = true, center = true })
hl.window_rule({
  name = "global-blur-transparency",
  match = { class = ".*" },
  -- opacity = "0.85 0.75",
})
